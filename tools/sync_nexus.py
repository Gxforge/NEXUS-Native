#!/usr/bin/env python3
"""Sincroniza el proyecto NEXUS-Native de GitHub con la carpeta local del PC.

Descarga la rama actualizada usando tu token de GitHub y escribe los archivos en
la raíz del proyecto local: añade los nuevos, actualiza los cambiados y, si se
pide, elimina los que ya no existen en el repositorio. No toca archivos que tú
hayas creado y que nunca formaron parte del repositorio.

Ejemplos
--------
    # 1) Lo normal: el script dentro del proyecto, sin --target
    set NEXUS_GITHUB_TOKEN=ghp_xxx            (Windows)
    export NEXUS_GITHUB_TOKEN=ghp_xxx         (Linux/macOS)
    python sync_nexus.py                      # destino = carpeta del propio script
    python sync_nexus.py --target "C:\\dev\\NEXUS-Native"   # destino explícito

    # 2) Ver qué haría, sin escribir nada
    python sync_nexus.py --target "C:\\dev\\NEXUS-Native" --dry-run

    # 3) Aplicar y además borrar los archivos retirados del repositorio
    python sync_nexus.py --target "C:\\dev\\NEXUS-Native" --prune --yes

    # 4) Sincronizar desde el zip ya descargado, sin red
    python sync_nexus.py --target "C:\\dev\\NEXUS-Native" --archive NEXUS-Native-8c0bb8b.zip

    # 5) Incluir los GLB fuente pesados (174 MB, solo para el pase de fidelidad)
    python sync_nexus.py --target "C:\\dev\\NEXUS-Native" --full

El token se pide en este orden: --token-file, NEXUS_GITHUB_TOKEN, GH_TOKEN,
GITHUB_TOKEN y, si no hay ninguno, por consola con getpass. Nunca se imprime ni
se escribe en disco.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import shutil
import stat
import sys
import tarfile
import tempfile
import time
import urllib.error
import urllib.request
import zipfile
from dataclasses import dataclass, field
from pathlib import Path

DEFAULT_REPO = "Gxforge/NEXUS-Native"
DEFAULT_BRANCH = "main"
MANIFEST_NAME = ".nexus-sync-manifest.json"
MANIFEST_VERSION = 1
API_ROOT = "https://api.github.com"
USER_AGENT = "nexus-sync/1.0"

# Nunca se sincronizan: estado local, control de versiones y basura del sistema.
IGNORE_DIRS = {".git", ".godot", "__pycache__", ".import", "node_modules"}
IGNORE_FILES = {".DS_Store", "Thumbs.db", "desktop.ini"}
IGNORE_SUFFIXES = (".tmp", ".part", ".crswap", ".~")

# Carpetas que se omiten salvo con --full (GLB fuente de gran tamaño).
HEAVY_DIRS = ("assets/generated/source-batch",)


# --------------------------------------------------------------------------- #
# utilidades
# --------------------------------------------------------------------------- #
def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 256), b""):
            digest.update(chunk)
    return digest.hexdigest()


def human_size(value: int) -> str:
    units = ("B", "KB", "MB", "GB")
    size = float(value)
    for unit in units:
        if size < 1024.0 or unit == units[-1]:
            return "%.1f %s" % (size, unit)
        size /= 1024.0
    return "%d B" % value


def is_ignored(rel: Path, full: bool) -> bool:
    parts = rel.parts
    if any(part in IGNORE_DIRS for part in parts[:-1]):
        return True
    if rel.name in IGNORE_FILES or rel.name.endswith(IGNORE_SUFFIXES):
        return True
    if not full:
        posix = rel.as_posix()
        for heavy in HEAVY_DIRS:
            if posix == heavy or posix.startswith(heavy + "/"):
                return True
    return False


def default_target() -> Path:
    """Carpeta del proyecto cuando no se indica --target.

    Prioriza la carpeta donde vive el script (así basta con dejarlo en la raíz
    del proyecto y ejecutarlo desde cualquier sitio) y, si ahí no hay
    `project.godot`, prueba el directorio de trabajo actual.
    """
    script_dir = Path(__file__).resolve().parent
    candidates = [script_dir, Path.cwd().resolve()]
    for candidate in candidates:
        if (candidate / "project.godot").is_file():
            return candidate
    return script_dir


def scrub(text: str, token: str | None) -> str:
    if token and token in text:
        text = text.replace(token, "<TOKEN>")
    return text


def fail(message: str) -> None:
    print("ERROR: " + message, file=sys.stderr)


# --------------------------------------------------------------------------- #
# token
# --------------------------------------------------------------------------- #
def resolve_token(args: argparse.Namespace) -> str | None:
    if args.no_token:
        return None
    if args.token_file:
        path = Path(args.token_file).expanduser()
        if not path.is_file():
            fail("no existe el archivo de token: %s" % path)
            raise SystemExit(2)
        token = path.read_text(encoding="utf-8").strip()
        return token or None
    for name in ("NEXUS_GITHUB_TOKEN", "GH_TOKEN", "GITHUB_TOKEN"):
        value = os.environ.get(name, "").strip()
        if value:
            return value
    if args.archive:
        return None
    if args.yes or not sys.stdin.isatty():
        return None
    try:
        import getpass

        value = getpass.getpass("Token de GitHub (vacío si el repo es público): ").strip()
    except (EOFError, KeyboardInterrupt):
        return None
    return value or None


# --------------------------------------------------------------------------- #
# obtención del origen
# --------------------------------------------------------------------------- #
def download_api_archive(repo: str, branch: str, token: str | None, workdir: Path) -> Path:
    url = "%s/repos/%s/zipball/%s" % (API_ROOT, repo, branch)
    request = urllib.request.Request(url, headers={
        "User-Agent": USER_AGENT,
        "Accept": "application/vnd.github+json",
        "X-GitHub-Api-Version": "2022-11-28",
    })
    if token:
        request.add_header("Authorization", "Bearer " + token)
    destination = workdir / "source.zip"
    print("Descargando %s (%s)…" % (repo, branch))
    try:
        with urllib.request.urlopen(request, timeout=60) as response, destination.open("wb") as handle:
            total = int(response.headers.get("Content-Length") or 0)
            read = 0
            last_report = 0.0
            while True:
                chunk = response.read(1024 * 256)
                if not chunk:
                    break
                handle.write(chunk)
                read += len(chunk)
                now = time.monotonic()
                if now - last_report > 1.5:
                    last_report = now
                    if total:
                        print("  %s / %s (%.0f%%)" % (human_size(read), human_size(total), 100.0 * read / total))
                    else:
                        print("  %s" % human_size(read))
    except urllib.error.HTTPError as error:
        message = {
            401: "token no válido o caducado (401).",
            403: "el token no tiene permiso sobre el repositorio o se agotó la cuota (403).",
            404: "repositorio o rama no encontrados (404). Revisa --repo/--branch y el alcance del token.",
        }.get(error.code, "respuesta HTTP %s de GitHub." % error.code)
        fail(message)
        raise SystemExit(3)
    except urllib.error.URLError as error:
        fail("no se pudo conectar con GitHub: %s" % error.reason)
        raise SystemExit(3)
    print("Descarga completa: %s" % human_size(destination.stat().st_size))
    return destination


def clone_with_git(repo: str, branch: str, token: str | None, workdir: Path) -> Path:
    import subprocess

    destination = workdir / "clone"
    env = dict(os.environ)
    env["GIT_TERMINAL_PROMPT"] = "0"
    askpass = None
    url = "https://github.com/%s.git" % repo
    if token:
        askpass = workdir / "askpass.sh"
        askpass.write_text(
            "#!/bin/sh\ncase \"$1\" in\n  *sername*) echo x-access-token ;;\n  *) printf '%s' \"$NEXUS_GIT_TOKEN\" ;;\nesac\n",
            encoding="utf-8",
        )
        askpass.chmod(0o700)
        env["GIT_ASKPASS"] = str(askpass)
        env["NEXUS_GIT_TOKEN"] = token
    command = ["git", "clone", "--depth", "1", "--branch", branch, url, str(destination)]
    print("Clonando %s (%s)…" % (repo, branch))
    result = subprocess.run(command, env=env, capture_output=True, text=True)
    if result.returncode != 0:
        fail("git clone falló: %s" % scrub(result.stderr.strip(), token))
        raise SystemExit(3)
    shutil.rmtree(destination / ".git", ignore_errors=True)
    return destination


def extract_archive(archive: Path, workdir: Path) -> Path:
    destination = workdir / "source"
    destination.mkdir(parents=True, exist_ok=True)
    print("Extrayendo %s…" % archive.name)
    if zipfile.is_zipfile(archive):
        with zipfile.ZipFile(archive) as bundle:
            bundle.extractall(destination)
    elif tarfile.is_tarfile(archive):
        with tarfile.open(archive) as bundle:
            bundle.extractall(destination, filter="data")
    else:
        fail("formato de archivo no soportado (usa .zip o .tar.gz)")
        raise SystemExit(2)
    return locate_project_root(destination)


def locate_project_root(base: Path) -> Path:
    """Encuentra la carpeta del proyecto dentro de lo extraído.

    Los archivos de GitHub vienen envueltos en `repo-sha/`; el zip manual puede
    traer además un LEEME al mismo nivel.
    """
    for candidate in sorted([base] + [path for path in base.iterdir() if path.is_dir()]):
        if (candidate / "project.godot").is_file():
            return candidate
    children = [path for path in base.iterdir() if path.is_dir()]
    if len(children) == 1:
        return children[0]
    return base


# --------------------------------------------------------------------------- #
# planificación
# --------------------------------------------------------------------------- #
@dataclass
class Report:
    added: list[str] = field(default_factory=list)
    updated: list[str] = field(default_factory=list)
    unchanged: int = 0
    removed: list[str] = field(default_factory=list)
    kept_local: list[str] = field(default_factory=list)
    overwritten_local_changes: list[str] = field(default_factory=list)
    bytes_written: int = 0

    def summary(self) -> str:
        return ("nuevos %d · actualizados %d · sin cambios %d · eliminados %d · "
                "locales preservados %d · %s escritos") % (
            len(self.added), len(self.updated), self.unchanged, len(self.removed),
            len(self.kept_local), human_size(self.bytes_written))


def load_manifest(target: Path) -> dict:
    path = target / MANIFEST_NAME
    if not path.is_file():
        return {}
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return {}
    if not isinstance(data, dict) or "files" not in data:
        return {}
    return data


def collect_source(source_root: Path, full: bool) -> dict[str, Path]:
    files: dict[str, Path] = {}
    for path in sorted(source_root.rglob("*")):
        if not path.is_file():
            continue
        rel = path.relative_to(source_root)
        if rel.name == MANIFEST_NAME or is_ignored(rel, full):
            continue
        files[rel.as_posix()] = path
    return files


def copy_file(source: Path, destination: Path) -> int:
    destination.parent.mkdir(parents=True, exist_ok=True)
    temporary = destination.with_name(destination.name + ".nexus-tmp")
    shutil.copy2(source, temporary)
    if destination.exists():
        try:
            os.chmod(destination, stat.S_IWRITE | stat.S_IREAD)
        except OSError:
            pass
    os.replace(temporary, destination)
    return destination.stat().st_size


def backup_files(target: Path, paths: list[str], backup_root: Path) -> None:
    if not paths:
        return
    stamp = time.strftime("%Y%m%d-%H%M%S")
    destination = backup_root / ("nexus-sync-backup-" + stamp)
    for rel in paths:
        origin = target / rel
        if not origin.is_file():
            continue
        copy_to = destination / rel
        copy_to.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(origin, copy_to)
    print("Respaldo de %d archivo(s) en %s" % (len(paths), destination))


def sync(source_root: Path, target: Path, manifest: dict, options: argparse.Namespace) -> Report:
    report = Report()
    previous: dict = manifest.get("files", {})
    current_hashes: dict[str, str] = {}
    retained: list[str] = []
    planned_backup: list[str] = []

    source_files = collect_source(source_root, options.full)
    print("Origen: %d archivo(s) · destino: %s" % (len(source_files), target))

    for rel, source_path in source_files.items():
        destination = target / rel
        source_hash = sha256_file(source_path)
        current_hashes[rel] = source_hash
        if not destination.is_file():
            report.added.append(rel)
            if not options.dry_run:
                report.bytes_written += copy_file(source_path, destination)
            continue
        local_hash = sha256_file(destination)
        if local_hash == source_hash:
            report.unchanged += 1
            continue
        known_hash = previous.get(rel)
        if known_hash and local_hash != known_hash:
            report.overwritten_local_changes.append(rel)
        report.updated.append(rel)
        planned_backup.append(rel)
        if not options.dry_run:
            report.bytes_written += copy_file(source_path, destination)

    if options.prune:
        for rel, known_hash in previous.items():
            if rel in source_files:
                continue
            destination = target / rel
            if not destination.is_file():
                continue
            if is_ignored(Path(rel), options.full):
                continue
            local_hash = sha256_file(destination)
            if local_hash != known_hash and not options.force_prune:
                report.kept_local.append(rel)
                # Se mantiene en el manifiesto para que un --force-prune posterior
                # vuelva a encontrarlo aunque ya no exista en el repositorio.
                current_hashes[rel] = local_hash
                retained.append(rel)
                continue
            report.removed.append(rel)
            if not options.dry_run:
                destination.unlink()
                parent = destination.parent
                while parent != target and parent.is_dir() and not any(parent.iterdir()):
                    parent.rmdir()
                    parent = parent.parent

    if not options.dry_run:
        if planned_backup and not options.no_backup:
            backup_root = Path(options.backup_dir).expanduser() if options.backup_dir else target.parent
            backup_files(target, planned_backup, backup_root)
        payload = {
            "manifest_version": MANIFEST_VERSION,
            "repo": options.repo,
            "branch": options.branch,
            "synced_at": time.strftime("%Y-%m-%dT%H:%M:%S%z"),
            "full": bool(options.full),
            "retired_kept": sorted(retained),
            "files": current_hashes,
        }
        temporary = target / (MANIFEST_NAME + ".tmp")
        temporary.write_text(json.dumps(payload, indent=1, sort_keys=True) + "\n", encoding="utf-8")
        os.replace(temporary, target / MANIFEST_NAME)
    return report


# --------------------------------------------------------------------------- #
# CLI
# --------------------------------------------------------------------------- #
def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Sincroniza el repositorio NEXUS-Native con la carpeta local del proyecto.")
    parser.add_argument("--target",
                        help="carpeta raíz del proyecto en tu PC "
                             "(por defecto, la carpeta donde está este script)")
    parser.add_argument("--repo", default=DEFAULT_REPO, help="owner/repo de GitHub (por defecto %s)" % DEFAULT_REPO)
    parser.add_argument("--branch", default=DEFAULT_BRANCH, help="rama a sincronizar (por defecto %s)" % DEFAULT_BRANCH)
    parser.add_argument("--mode", choices=("api", "git"), default="api",
                        help="api = zipball por HTTPS (por defecto); git = clonar con git")
    parser.add_argument("--archive", help="sincroniza desde un .zip/.tar.gz local en lugar de descargar")
    parser.add_argument("--token-file", help="archivo con el token (si no, variables de entorno)")
    parser.add_argument("--no-token", action="store_true", help="no usar token (repositorio público)")
    parser.add_argument("--dry-run", action="store_true", help="solo muestra el plan, sin escribir")
    parser.add_argument("--prune", action="store_true", help="elimina archivos retirados del repositorio")
    parser.add_argument("--force-prune", action="store_true", help="elimina incluso si el archivo se editó en local")
    parser.add_argument("--full", action="store_true", help="incluye assets/generated/source-batch (174 MB)")
    parser.add_argument("--backup-dir", help="carpeta donde guardar el respaldo (por defecto, junto al proyecto)")
    parser.add_argument("--no-backup", action="store_true", help="no respaldar los archivos sobrescritos")
    parser.add_argument("--keep-download", help="guarda el archivo descargado en esa ruta")
    parser.add_argument("--force", action="store_true", help="permite un destino que no sea un proyecto Godot")
    parser.add_argument("--yes", "-y", action="store_true", help="no pedir confirmación")
    parser.add_argument("--no-pause", action="store_true",
                        help="no esperar a Intro al terminar (por defecto solo pausa en Windows)")
    parser.add_argument("--version", action="version", version="nexus-sync 1.1")
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    try:  # mezcla predecible de mensajes y errores en la consola de Windows
        sys.stdout.reconfigure(line_buffering=True)
        sys.stderr.reconfigure(line_buffering=True)
    except (AttributeError, ValueError):
        pass
    options = parse_args(argv)
    explicit_target = bool(options.target)
    target = Path(options.target).expanduser().resolve() if explicit_target else default_target()
    token = resolve_token(options)
    if explicit_target:
        print("Destino: %s" % target)
    else:
        print("Destino: %s (carpeta del script; usa --target para cambiarla)" % target)
    if not (target / "project.godot").is_file() and not options.force:
        print("Aviso: en %s no hay project.godot todavía." % target)

    target_has_content = target.exists() and any(target.iterdir())
    if target_has_content:
        if not (target / "project.godot").is_file() and not options.force:
            fail("%s no parece la raíz del proyecto (falta project.godot)." % target)
            if not explicit_target:
                fail("copia sync_nexus.py a la raíz del proyecto o indica la carpeta: "
                     "--target \"RUTA\\al\\proyecto\"")
            else:
                fail("revisa la ruta o usa --force si de verdad quieres escribir ahí.")
            return 2
    else:
        print("La carpeta destino no existe; se creará: %s" % target)
        if not options.dry_run:
            target.mkdir(parents=True, exist_ok=True)

    manifest = load_manifest(target)
    print("Manifiesto previo: %s" % ("sí (%d archivos)" % len(manifest.get("files", {}))
                                     if manifest else "no (primera sincronización)"))

    workdir = Path(tempfile.mkdtemp(prefix="nexus-sync-"))
    try:
        if options.archive:
            archive = Path(options.archive).expanduser()
            if not archive.is_file():
                fail("no existe el archivo indicado: %s" % archive)
                return 2
            source_root = extract_archive(archive, workdir)
        elif options.mode == "git":
            source_root = clone_with_git(options.repo, options.branch, token, workdir)
        else:
            archive = download_api_archive(options.repo, options.branch, token, workdir)
            if options.keep_download:
                shutil.copy2(archive, Path(options.keep_download).expanduser())
                print("Descarga conservada en %s" % options.keep_download)
            source_root = extract_archive(archive, workdir)

        print("Proyecto de origen: %s" % source_root)
        if not options.archive and not options.yes:
            answer = input("¿Aplicar los cambios en %s? [s/N] " % target).strip().lower()
            if answer not in ("s", "si", "sí", "y", "yes"):
                print("Cancelado; no se escribió nada.")
                return 1

        report = sync(source_root, target, manifest, options)
        if options.dry_run:
            print("\nSIMULACIÓN (no se escribió nada):")
            for label, items in (("nuevo", report.added), ("actualizado", report.updated),
                                 ("eliminado", report.removed), ("preservado (editado en local)", report.kept_local)):
                for rel in items:
                    print("  [%s] %s" % (label, rel))
        else:
            for rel in report.added:
                print("  + %s" % rel)
            for rel in report.updated:
                print("  ~ %s" % rel)
            for rel in report.removed:
                print("  - %s" % rel)
        print("\nResumen: %s" % report.summary())
        if report.overwritten_local_changes:
            print("Aviso: %d archivo(s) tenían cambios locales y se sobrescribieron (respaldo disponible)."
                  % len(report.overwritten_local_changes))
        if report.kept_local and not options.force_prune:
            print("Aviso: %d archivo(s) retirados del repositorio se conservan porque los editaste; "
                  "usa --force-prune para borrarlos." % len(report.kept_local))
        print("Siguiente paso: abre el proyecto con Godot 4.4.1 (la primera apertura reimporta assets).")
        return 0
    finally:
        shutil.rmtree(workdir, ignore_errors=True)


def _windows_pause() -> None:
    if os.name != "nt" or "--no-pause" in sys.argv:
        return
    try:
        if not sys.stdin.isatty():
            return
        input("\nPulsa Intro para cerrar…")
    except (EOFError, KeyboardInterrupt):
        pass


if __name__ == "__main__":
    try:
        code = main()
    except KeyboardInterrupt:
        print("\nInterrumpido.")
        code = 130
    _windows_pause()
    raise SystemExit(code)
