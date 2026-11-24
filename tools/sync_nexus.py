#!/usr/bin/env python3
"""NEXUS Native · sincronizador del repositorio con la carpeta del PC.

Doble uso, un solo archivo:

* Sin argumentos abre una **ventana** con barra de progreso real (descarga,
  comparación y copia), registro de lo que hace, comprobación de si hay cambios
  en la rama y opción de actualizar automáticamente al detectarlos.
* Con argumentos funciona como herramienta de consola (lo mismo que hace la
  ventana), útil para scripts y para depurar: --dry-run, --prune, --full, etc.

Descarga la rama con tu token de GitHub y escribe los archivos en la raíz del
proyecto local: añade los nuevos, actualiza los cambiados y, si se pide, elimina
los retirados. No toca archivos que tú hayas creado y que nunca formaron parte
del repositorio.

Ejemplos de consola
-------------------
    python sync_nexus.py                          # abre la ventana
    python sync_nexus.py --dry-run                # consola: solo el plan
    python sync_nexus.py --prune -y               # consola: aplica y limpia
    python sync_nexus.py --watch 120 --auto-sync  # consola: vigila cada 2 min
    python sync_nexus.py --archive NEXUS.zip      # sin red, desde un zip

El token se busca en --token-file, NEXUS_GITHUB_TOKEN, GH_TOKEN, GITHUB_TOKEN o,
si no hay ninguno, se pide por consola/ventana. Nunca se escribe en el manifiesto
ni se imprime en los mensajes.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import queue
import shutil
import stat
import sys
import tarfile
import tempfile
import threading
import time
import urllib.error
import urllib.request
import zipfile
from dataclasses import dataclass, field
from pathlib import Path

DEFAULT_REPO = "Gxforge/NEXUS-Native"
DEFAULT_BRANCH = "main"
MANIFEST_NAME = ".nexus-sync-manifest.json"
MANIFEST_VERSION = 2
SETTINGS_NAME = ".nexus-sync-settings.json"
API_ROOT = "https://api.github.com"
USER_AGENT = "nexus-sync/2.1"

IGNORE_DIRS = {".git", ".godot", "__pycache__", "node_modules", ".import"}
IGNORE_FILES = {".DS_Store", "Thumbs.db", "desktop.ini"}
IGNORE_SUFFIXES = (".tmp", ".part", ".crswap", ".~")
HEAVY_DIRS = ("assets/generated/source-batch",)

ProgressCallback = "object"
LogCallback = "object"


# --------------------------------------------------------------------------- #
# utilidades
# --------------------------------------------------------------------------- #
def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 256), b""):
            digest.update(chunk)
    return digest.hexdigest()


def human_size(value: float) -> str:
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


def scrub(text: str, token: str | None) -> str:
    return text.replace(token, "<TOKEN>") if token and token in text else text


def default_target() -> Path:
    """Carpeta del proyecto cuando no se indica --target.

    Prioriza la carpeta donde vive el script (deja el archivo en la raíz del
    proyecto y funciona desde cualquier sitio) y luego el directorio actual.
    """
    script_dir = Path(__file__).resolve().parent
    for candidate in (script_dir, Path.cwd().resolve()):
        if (candidate / "project.godot").is_file():
            return candidate
    return script_dir


def godot_cache_dir(target: Path) -> Path:
    return target / ".godot"


def orphan_imports(target: Path) -> list[Path]:
    """`.import` cuyo archivo fuente ya no existe (el proyecto los ignora)."""
    result: list[Path] = []
    for import_file in target.rglob("*.import"):
        if any(part in {".godot", ".git"} for part in import_file.parts):
            continue
        try:
            text = import_file.read_text(encoding="utf-8", errors="ignore")
        except OSError:
            continue
        for line in text.splitlines():
            if line.startswith("source_file="):
                source = line.split("=", 1)[1].strip().strip('"')
                if source.startswith("res://"):
                    if not (target / source[len("res://"):]).is_file():
                        result.append(import_file)
                break
    return result


def clean_godot_cache(target: Path, log) -> bool:
    cache = godot_cache_dir(target)
    if not cache.exists():
        return False
    try:
        shutil.rmtree(cache)
    except OSError as error:
        log("warn", "No se pudo borrar la caché .godot: %s" % error)
        return False
    log("warn", "Caché .godot borrada: Godot la reconstruye y reimporta al abrir el proyecto.")
    return True


def repair_project(target: Path, log) -> tuple[int, bool]:
    """Deja el proyecto en estado reimportable: caché fuera y .import huérfanos."""
    removed = 0
    for import_file in orphan_imports(target):
        try:
            import_file.unlink()
            removed += 1
        except OSError:
            pass
    if removed:
        log("warn", "%d archivo(s) .import huérfano(s) retirado(s) (su fuente no está en el proyecto)."
            % removed)
    cleaned = clean_godot_cache(target, log)
    log("info", "Reparación terminada: abre Godot y deja que reimporte (la primera vez tarda).")
    return removed, cleaned


def settings_path() -> Path:
    return Path.home() / SETTINGS_NAME


def load_settings() -> dict:
    path = settings_path()
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return {}
    return data if isinstance(data, dict) else {}


def save_settings(data: dict) -> None:
    try:
        settings_path().write_text(json.dumps(data, indent=1, sort_keys=True) + "\n", encoding="utf-8")
    except OSError:
        pass


# --------------------------------------------------------------------------- #
# token
# --------------------------------------------------------------------------- #
def token_from_environment() -> str | None:
    for name in ("NEXUS_GITHUB_TOKEN", "GH_TOKEN", "GITHUB_TOKEN"):
        value = os.environ.get(name, "").strip()
        if value:
            return value
    return None


def token_from_file(path: str | Path) -> str | None:
    file_path = Path(path).expanduser()
    if not file_path.is_file():
        return None
    return file_path.read_text(encoding="utf-8").strip() or None


# --------------------------------------------------------------------------- #
# GitHub
# --------------------------------------------------------------------------- #
REMOTE_PROBLEM: str | None = None


def remote_commit(repo: str, branch: str, token: str | None, timeout: float = 20.0) -> str | None:
    """SHA del último commit de la rama (None si no hay red o no hay permisos)."""
    global REMOTE_PROBLEM
    REMOTE_PROBLEM = None
    url = "%s/repos/%s/commits/%s" % (API_ROOT, repo, branch)
    request = urllib.request.Request(url, headers={
        "User-Agent": USER_AGENT,
        "Accept": "application/vnd.github+json",
        "X-GitHub-Api-Version": "2022-11-28",
    })
    if token:
        request.add_header("Authorization", "Bearer " + token)
    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:
            payload = json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as error:
        if error.code in (403, 429):
            REMOTE_PROBLEM = ("límite de consultas de GitHub alcanzado (%d). Añade el token en la "
                              "ventana o espera unos minutos." % error.code)
        elif error.code == 401:
            REMOTE_PROBLEM = "el token fue rechazado (401): revísalo o desmárcalo"
        elif error.code == 404:
            REMOTE_PROBLEM = "repositorio o rama no encontrados (404)"
        else:
            REMOTE_PROBLEM = "GitHub respondió %d" % error.code
        return None
    except (urllib.error.URLError, ValueError, OSError) as error:
        REMOTE_PROBLEM = "sin conexión (%s)" % (getattr(error, "reason", None) or error)
        return None
    sha = payload.get("sha") if isinstance(payload, dict) else None
    return sha if isinstance(sha, str) else None


def download_archive(repo: str, branch: str, token: str | None, destination: Path,
                     progress=None, cancel=None) -> Path:
    url = "%s/repos/%s/zipball/%s" % (API_ROOT, repo, branch)
    request = urllib.request.Request(url, headers={
        "User-Agent": USER_AGENT,
        "Accept": "application/vnd.github+json",
        "X-GitHub-Api-Version": "2022-11-28",
    })
    if token:
        request.add_header("Authorization", "Bearer " + token)
    try:
        with urllib.request.urlopen(request, timeout=60) as response, destination.open("wb") as handle:
            total = int(response.headers.get("Content-Length") or 0)
            read = 0
            while True:
                if cancel is not None and cancel():
                    raise SyncCancelled()
                chunk = response.read(1024 * 128)
                if not chunk:
                    break
                handle.write(chunk)
                read += len(chunk)
                if progress is not None:
                    progress(read, total)
    except urllib.error.HTTPError as error:
        message = {
            401: "token no válido o caducado (401).",
            403: "el token no tiene permiso sobre el repositorio o se agotó la cuota (403).",
            404: "repositorio o rama no encontrados (404). Revisa el repositorio y la rama.",
        }.get(error.code, "respuesta HTTP %s de GitHub." % error.code)
        raise SyncError(message) from error
    except urllib.error.URLError as error:
        raise SyncError("no se pudo conectar con GitHub: %s" % error.reason) from error
    return destination


def clone_with_git(repo: str, branch: str, token: str | None, workdir: Path, log=None) -> Path:
    import subprocess

    destination = workdir / "clone"
    env = dict(os.environ)
    env["GIT_TERMINAL_PROMPT"] = "0"
    if token:
        askpass = workdir / "askpass.sh"
        askpass.write_text(
            "#!/bin/sh\ncase \"$1\" in\n  *sername*) echo x-access-token ;;\n"
            "  *) printf '%s' \"$NEXUS_GIT_TOKEN\" ;;\nesac\n", encoding="utf-8")
        askpass.chmod(0o700)
        env["GIT_ASKPASS"] = str(askpass)
        env["NEXUS_GIT_TOKEN"] = token
    command = ["git", "clone", "--depth", "1", "--branch", branch,
               "https://github.com/%s.git" % repo, str(destination)]
    if log is not None:
        log("info", "Clonando %s (%s)…" % (repo, branch))
    result = subprocess.run(command, env=env, capture_output=True, text=True)
    if result.returncode != 0:
        raise SyncError("git clone falló: %s" % scrub(result.stderr.strip(), token))
    shutil.rmtree(destination / ".git", ignore_errors=True)
    return destination


def extract_archive(archive: Path, workdir: Path, log=None) -> Path:
    destination = workdir / "source"
    destination.mkdir(parents=True, exist_ok=True)
    if log is not None:
        log("info", "Extrayendo %s…" % archive.name)
    if zipfile.is_zipfile(archive):
        with zipfile.ZipFile(archive) as bundle:
            bundle.extractall(destination)
    elif tarfile.is_tarfile(archive):
        with tarfile.open(archive) as bundle:
            bundle.extractall(destination, filter="data")
    else:
        raise SyncError("formato de archivo no soportado (usa .zip o .tar.gz)")
    return locate_project_root(destination)


def locate_project_root(base: Path) -> Path:
    for candidate in sorted([base] + [path for path in base.iterdir() if path.is_dir()]):
        if (candidate / "project.godot").is_file():
            return candidate
    children = [path for path in base.iterdir() if path.is_dir()]
    if len(children) == 1:
        return children[0]
    return base


# --------------------------------------------------------------------------- #
# errores y resultado
# --------------------------------------------------------------------------- #
class SyncError(Exception):
    pass


class SyncCancelled(Exception):
    pass


@dataclass
class Report:
    added: list[str] = field(default_factory=list)
    updated: list[str] = field(default_factory=list)
    unchanged: int = 0
    removed: list[str] = field(default_factory=list)
    kept_local: list[str] = field(default_factory=list)
    overwritten_local_changes: list[str] = field(default_factory=list)
    bytes_written: int = 0
    total_files: int = 0
    remote_commit: str | None = None
    elapsed: float = 0.0
    dry_run: bool = False

    @property
    def changed(self) -> int:
        return len(self.added) + len(self.updated) + len(self.removed)

    def summary(self) -> str:
        prefix = "simulación: " if self.dry_run else ""
        return "%snuevos %d · actualizados %d · sin cambios %d · eliminados %d · %s" % (
            prefix, len(self.added), len(self.updated), self.unchanged,
            len(self.removed), human_size(self.bytes_written))


# --------------------------------------------------------------------------- #
# motor de sincronización
# --------------------------------------------------------------------------- #
def load_manifest(target: Path) -> dict:
    path = target / MANIFEST_NAME
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return {}
    return data if isinstance(data, dict) and "files" in data else {}


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


def backup_files(target: Path, paths: list[str], backup_root: Path) -> Path | None:
    if not paths:
        return None
    destination = backup_root / ("nexus-sync-backup-" + time.strftime("%Y%m%d-%H%M%S"))
    count = 0
    for rel in paths:
        origin = target / rel
        if not origin.is_file():
            continue
        copied = destination / rel
        copied.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(origin, copied)
        count += 1
    return destination if count else None


class SyncEngine:
    """Descarga + espejo con progreso real (0.0–1.0) y cancelación."""

    def __init__(self, options: argparse.Namespace, progress=None, log=None, cancel=None,
                 token: str | None = None, target: Path | None = None):
        self.options = options
        self._progress = progress or (lambda fraction, text: None)
        self._log = log or (lambda level, text: None)
        self._cancel = cancel or (lambda: False)
        self.token = token
        self.target = target or (Path(options.target).expanduser().resolve()
                                 if options.target else default_target())

    # -- helpers ---------------------------------------------------------- #
    def _step(self, fraction: float, text: str) -> None:
        self._progress(max(0.0, min(1.0, fraction)), text)
        self._log("info", text)

    def _check_cancel(self) -> None:
        if self._cancel():
            raise SyncCancelled()

    def _download(self, workdir: Path, span: tuple[float, float]) -> Path:
        low, high = span
        state = {"last": 0.0}

        expected = 42.0 * 1024 * 1024  # tamaño típico del zip; GitHub no manda Content-Length
        state["started"] = time.monotonic()

        def on_chunk(read: int, total: int) -> None:
            self._check_cancel()
            elapsed = max(0.001, time.monotonic() - state["started"])
            speed = read / elapsed
            if total:
                fraction = low + (high - low) * min(1.0, read / float(total))
                reference = float(total)
                text = "Descargando %s de %s" % (human_size(read), human_size(total))
            else:
                # sin longitud conocida: curva asintótica para que la barra avance
                fraction = low + (high - low - 0.02) * (1.0 - pow(2.718281828, -read / expected))
                reference = expected
                text = "Descargando %s" % human_size(read)
            remaining = max(0.0, (reference - read) / speed) if speed > 1024 else 0.0
            text += " · %s/s" % human_size(speed)
            if remaining > 1.0:
                text += " · quedan %s" % (("%d:%02d" % (int(remaining) // 60, int(remaining) % 60))
                                          if remaining >= 60 else "%d s" % int(remaining))
            now = time.monotonic()
            if now - state["last"] > 0.12:
                state["last"] = now
                self._progress(fraction, text)

        destination = workdir / "source.zip"
        self._step(low, "Descargando %s (%s)…" % (self.options.repo, self.options.branch))
        download_archive(self.options.repo, self.options.branch, self.token, destination,
                         progress=on_chunk, cancel=self._cancel)
        self._progress(high, "Descarga completa (%s)" % human_size(destination.stat().st_size))
        return destination

    def check_only(self) -> tuple[str | None, str | None]:
        """(commit remoto, commit local del manifiesto)."""
        local = load_manifest(self.target).get("remote_commit")
        remote = remote_commit(self.options.repo, self.options.branch, self.token)
        return remote, local

    # -- ejecución -------------------------------------------------------- #
    def run(self) -> Report:
        started = time.monotonic()
        options = self.options
        report = Report(dry_run=bool(options.dry_run))
        target = self.target
        self._log("info", "Destino: %s" % target)

        manifest = load_manifest(target)
        if not options.archive:
            remote, local = self.check_only()
            report.remote_commit = remote
            self._progress(0.02, "Rama remota comprobada")
            force = bool(getattr(options, "force_download", False))
            same_full = bool(manifest.get("files")) and bool(manifest.get("full")) == bool(options.full)
            if remote and local and remote == local and same_full and not force:
                report.unchanged = len(manifest.get("files", {}))
                report.total_files = report.unchanged
                report.elapsed = time.monotonic() - started
                self._log("ok", "Ya está sincronizado con %s: no hace falta descargar nada." % remote[:7])
                self._progress(1.0, "Al día · %s" % remote[:7])
                return report
            if remote and local:
                if remote == local:
                    self._log("ok", "Sin cambios remotos desde la última sincronización (%s)." % remote[:7])
                else:
                    self._log("warn", "Hay una actualización: %s → %s" % (str(local)[:7], remote[:7]))
            elif remote:
                self._log("info", "Rama remota en %s" % remote[:7])

        workdir = Path(tempfile.mkdtemp(prefix="nexus-sync-"))
        try:
            if options.archive:
                archive = Path(options.archive).expanduser()
                if not archive.is_file():
                    raise SyncError("no existe el archivo indicado: %s" % archive)
                self._progress(0.35, "Extrayendo %s…" % archive.name)
                source_root = extract_archive(archive, workdir, self._log)
            elif options.mode == "git":
                self._progress(0.35, "Clonando con git…")
                source_root = clone_with_git(options.repo, options.branch, self.token, workdir, self._log)
            else:
                archive = self._download(workdir, (0.03, 0.55))
                if options.keep_download:
                    shutil.copy2(archive, Path(options.keep_download).expanduser())
                    self._log("info", "Descarga conservada en %s" % options.keep_download)
                self._step(0.58, "Extrayendo…")
                source_root = extract_archive(archive, workdir, self._log)
            self._check_cancel()
            report = self._sync(source_root, report)
            report.elapsed = time.monotonic() - started
            self._progress(1.0, "Listo · %s" % report.summary())
            return report
        finally:
            shutil.rmtree(workdir, ignore_errors=True)

    def _sync(self, source_root: Path, report: Report) -> Report:
        options = self.options
        target = self.target
        manifest = load_manifest(target)
        previous: dict = manifest.get("files", {})
        current_hashes: dict[str, str] = {}
        retained: list[str] = []
        planned_backup: list[str] = []

        source_files: dict[str, Path] = {}
        for path in sorted(source_root.rglob("*")):
            if path.is_file():
                rel = path.relative_to(source_root)
                if rel.name != MANIFEST_NAME and not is_ignored(rel, options.full):
                    source_files[rel.as_posix()] = path
        report.total_files = len(source_files)
        self._step(0.62, "Origen: %d archivo(s)" % len(source_files))

        total = len(source_files) or 1
        for index, (rel, source_path) in enumerate(source_files.items()):
            self._check_cancel()
            destination = target / rel
            source_hash = sha256_file(source_path)
            current_hashes[rel] = source_hash
            if index % 24 == 0:
                self._progress(0.64 + 0.14 * (index / total), "Comparando %s" % rel)
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
            self._progress(0.8, "Revisando archivos retirados…")
            for rel, known_hash in previous.items():
                if rel in source_files:
                    continue
                destination = target / rel
                if not destination.is_file() or is_ignored(Path(rel), options.full):
                    continue
                local_hash = sha256_file(destination)
                if local_hash != known_hash and not options.force_prune:
                    report.kept_local.append(rel)
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

        self._progress(0.94, "Cerrando…")
        if not options.dry_run:
            if planned_backup and not options.no_backup:
                backup_root = Path(options.backup_dir).expanduser() if options.backup_dir else target.parent
                location = backup_files(target, planned_backup, backup_root)
                if location is not None:
                    self._log("warn", "Respaldo de %d archivo(s) en %s" % (len(planned_backup), location))
            payload = {
                "manifest_version": MANIFEST_VERSION,
                "repo": options.repo,
                "branch": options.branch,
                "synced_at": time.strftime("%Y-%m-%dT%H:%M:%S%z"),
                "remote_commit": report.remote_commit,
                "full": bool(options.full),
                "retired_kept": sorted(retained),
                "files": current_hashes,
            }
            temporary = target / (MANIFEST_NAME + ".tmp")
            temporary.write_text(json.dumps(payload, indent=1, sort_keys=True) + "\n", encoding="utf-8")
            os.replace(temporary, target / MANIFEST_NAME)
            if report.changed:
                if getattr(options, "repair", False) or getattr(options, "clean_cache", False):
                    repair_project(target, self._log)
                elif godot_cache_dir(target).exists():
                    self._log("info", "Si Godot muestra errores de UID, ciérralo y borra la carpeta "
                                      ".godot (o pulsa Reparar): se reimporta limpio.")
        return report


# --------------------------------------------------------------------------- #
# consola
# --------------------------------------------------------------------------- #
def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Sincroniza NEXUS-Native (GitHub) con la carpeta local del proyecto. "
                    "Sin argumentos abre la ventana.")
    parser.add_argument("--target", help="carpeta raíz del proyecto (por defecto, la del script)")
    parser.add_argument("--repo", default=DEFAULT_REPO, help="owner/repo (por defecto %s)" % DEFAULT_REPO)
    parser.add_argument("--branch", default=DEFAULT_BRANCH, help="rama (por defecto %s)" % DEFAULT_BRANCH)
    parser.add_argument("--mode", choices=("api", "git"), default="api")
    parser.add_argument("--archive", help="sincroniza desde un .zip/.tar.gz local")
    parser.add_argument("--token-file", help="archivo con el token")
    parser.add_argument("--no-token", action="store_true", help="descarga anónima")
    parser.add_argument("--dry-run", action="store_true", help="solo muestra el plan")
    parser.add_argument("--prune", action="store_true", help="elimina archivos retirados del repositorio")
    parser.add_argument("--force-prune", action="store_true", help="elimina aunque estén editados en local")
    parser.add_argument("--full", action="store_true", help="incluye assets fuente pesados (174 MB)")
    parser.add_argument("--backup-dir", help="carpeta de respaldo")
    parser.add_argument("--no-backup", action="store_true")
    parser.add_argument("--keep-download", help="guarda el zip descargado en esa ruta")
    parser.add_argument("--force", action="store_true", help="permite un destino sin project.godot")
    parser.add_argument("--yes", "-y", action="store_true", help="sin confirmación")
    parser.add_argument("--watch", type=float, metavar="SEGUNDOS",
                        help="vigila la rama y avisa (o sincroniza con --auto-sync)")
    parser.add_argument("--auto-sync", action="store_true", help="con --watch, aplica los cambios")
    parser.add_argument("--check", action="store_true", help="solo compara commits remotos y sale")
    parser.add_argument("--clean-cache", action="store_true",
                        help="borra la caché .godot después de actualizar (reimporta limpio)")
    parser.add_argument("--repair", action="store_true",
                        help="borra la caché .godot y los .import huérfanos y sale")
    parser.add_argument("--force-download", action="store_true",
                        help="descarga aunque el commit remoto ya esté sincronizado (recupera archivos editados)")
    parser.add_argument("--gui", action="store_true", help="fuerza la ventana")
    parser.add_argument("--no-gui", action="store_true", help="fuerza la consola")
    parser.add_argument("--no-pause", action="store_true")
    parser.add_argument("--version", action="version", version="nexus-sync 2.1")
    return parser


def cli_progress(fraction: float, text: str) -> None:
    bar = int(fraction * 28)
    sys.stdout.write("\r[%-28s] %3d%%  %-52s" % ("#" * bar, int(fraction * 100), text[:52]))
    sys.stdout.flush()
    if fraction >= 1.0:
        sys.stdout.write("\n")


def cli_log(level: str, text: str) -> None:
    marker = {"info": "·", "ok": "OK", "warn": "!", "error": "X"}.get(level, "·")
    sys.stdout.write("\n%s %s\n" % (marker, text))
    sys.stdout.flush()


def resolve_cli_token(args: argparse.Namespace) -> str | None:
    if args.no_token:
        return None
    if args.token_file:
        token = token_from_file(args.token_file)
        if not token:
            raise SyncError("no se pudo leer el token en %s" % args.token_file)
        return token
    token = token_from_environment()
    if token or args.archive or not sys.stdin.isatty():
        return token
    import getpass
    try:
        return getpass.getpass("Token de GitHub (vacío si el repo es público): ").strip() or None
    except (EOFError, KeyboardInterrupt):
        return None


def run_cli(args: argparse.Namespace) -> int:
    target = Path(args.target).expanduser().resolve() if args.target else default_target()
    token = resolve_cli_token(args)
    print("Destino: %s" % target)

    if args.check or args.watch:
        while True:
            remote, local = SyncEngine(args, token=token, target=target).check_only()
            stamp = time.strftime("%H:%M:%S")
            if remote is None:
                print("[%s] No se pudo consultar la rama: %s"
                      % (stamp, REMOTE_PROBLEM or "sin red o sin token"))
            elif local is None:
                print("[%s] Remoto en %s · todavía sin sincronizar" % (stamp, remote[:7]))
            elif remote == local:
                print("[%s] Al día · %s" % (stamp, remote[:7]))
            else:
                print("[%s] Actualización disponible: %s → %s" % (stamp, str(local)[:7], remote[:7]))
                if not args.watch or args.auto_sync:
                    break
            if args.check:
                return 0 if (remote is None or local == remote) else 1
            try:
                time.sleep(max(10.0, args.watch))
            except KeyboardInterrupt:
                return 0
        if not args.auto_sync:
            return 0

    if args.repair and not args.watch and not args.check:
        if not target.is_dir():
            print("ERROR: la carpeta no existe: %s" % target, file=sys.stderr)
            return 2
        repair_project(target, cli_log)
        return 0

    if target.exists() and any(target.iterdir()) and not (target / "project.godot").is_file() and not args.force:
        print("ERROR: %s no parece la raíz del proyecto (falta project.godot)." % target, file=sys.stderr)
        return 2
    if not args.yes and not args.archive and sys.stdin.isatty():
        answer = input("¿Aplicar los cambios en %s? [s/N] " % target).strip().lower()
        if answer not in ("s", "si", "sí", "y", "yes"):
            print("Cancelado; no se escribió nada.")
            return 1

    engine = SyncEngine(args, progress=cli_progress, log=cli_log, token=token, target=target)
    try:
        report = engine.run()
    except SyncCancelled:
        print("Cancelado.")
        return 1
    except SyncError as error:
        print("\nERROR: %s" % scrub(str(error), token), file=sys.stderr)
        return 3
    print()
    for rel in report.added[:40]:
        print("  + %s" % rel)
    for rel in report.updated[:40]:
        print("  ~ %s" % rel)
    for rel in report.removed[:40]:
        print("  - %s" % rel)
    print("Resumen: %s · %.1f s" % (report.summary(), report.elapsed))
    if report.overwritten_local_changes:
        print("Aviso: %d archivo(s) con cambios locales sobrescritos (hay respaldo)."
              % len(report.overwritten_local_changes))
    if report.kept_local:
        print("Aviso: %d archivo(s) retirados del repositorio se conservan por estar editados."
              % len(report.kept_local))
    return 0


# --------------------------------------------------------------------------- #
# ventana
# --------------------------------------------------------------------------- #
def launch_gui(default_options: argparse.Namespace | None = None) -> int:
    import tkinter as tk
    from tkinter import filedialog, messagebox, ttk

    class SyncApp(tk.Tk):
        POLL_MS = 60

        def __init__(self) -> None:
            super().__init__()
            self.title("NEXUS · Sincronizador del proyecto")
            self.geometry("880x640")
            self.minsize(760, 560)
            self.configure(bg="#0b1418")

            self.events: queue.Queue = queue.Queue()
            self.worker: threading.Thread | None = None
            self.cancel_event = threading.Event()
            self.last_check: float = 0.0
            self.settings = load_settings()

            cli_target = getattr(default_options, "target", None) if default_options else None
            cli_repo = getattr(default_options, "repo", None) if default_options else None
            cli_branch = getattr(default_options, "branch", None) if default_options else None
            self.target = tk.StringVar(value=cli_target or self.settings.get("target") or str(default_target()))
            self.repo = tk.StringVar(value=cli_repo or self.settings.get("repo", DEFAULT_REPO))
            self.branch = tk.StringVar(value=cli_branch or self.settings.get("branch", DEFAULT_BRANCH))
            cli_token_file = getattr(default_options, "token_file", None) if default_options else None
            self.cli_token_file = cli_token_file if cli_token_file and Path(cli_token_file).is_file() else None
            self.token = tk.StringVar(value="")
            self.prune = tk.BooleanVar(value=bool(self.settings.get("prune", False)))
            self.full = tk.BooleanVar(value=False)
            self.backup = tk.BooleanVar(value=bool(self.settings.get("backup", True)))
            self.auto_check = tk.BooleanVar(value=bool(self.settings.get("auto_check", True)))
            self.auto_apply = tk.BooleanVar(value=bool(self.settings.get("auto_apply", False)))
            self.remember_token = tk.BooleanVar(value=False)
            self.force_download = tk.BooleanVar(value=False)
            self.clean_cache = tk.BooleanVar(value=bool(self.settings.get("clean_cache", True)))
            self.status = tk.StringVar(value="Listo")
            self.detail = tk.StringVar(value="")
            self.remote_label = tk.StringVar(value="Rama remota: —")

            self._build()
            self.after(self.POLL_MS, self._drain)
            self.after(400, self.check)
            autostart = os.environ.get("NEXUS_SYNC_AUTOSTART", "").strip().lower()
            if autostart:
                self._append("info", "Arranque automático: %s" % autostart)
                self.after(1200, lambda: self.start(dry_run=autostart == "dry"))
            self.after(5000, self._auto_tick)
            self.protocol("WM_DELETE_WINDOW", self._on_close)

        # -- interfaz ---------------------------------------------------- #
        def _build(self) -> None:
            style = ttk.Style(self)
            try:
                style.theme_use("clam")
            except tk.TclError:
                pass
            style.configure(".", background="#0b1418", foreground="#d7ece9", fieldbackground="#101f25")
            style.configure("TFrame", background="#0b1418")
            style.configure("Card.TLabelframe", background="#0d1a1f", foreground="#8fd8d2",
                            bordercolor="#1d3a41", relief="solid")
            style.configure("Card.TLabelframe.Label", background="#0d1a1f", foreground="#8fd8d2")
            style.configure("TLabel", background="#0b1418", foreground="#cfe5e2")
            style.configure("Muted.TLabel", background="#0b1418", foreground="#6f9095")
            style.configure("Title.TLabel", background="#0b1418", foreground="#7ff0e4",
                            font=("Consolas", 17, "bold"))
            style.configure("TButton", background="#123038", foreground="#d7ece9", borderwidth=0)
            style.map("TButton", background=[("active", "#1a4650"), ("disabled", "#152026")])
            style.configure("Accent.TButton", background="#17756c", foreground="#eafffb")
            style.map("Accent.TButton", background=[("active", "#1f9c90"), ("disabled", "#152026")])
            style.configure("TCheckbutton", background="#0b1418", foreground="#bcd7d4")
            style.configure("TEntry", fieldbackground="#101f25", foreground="#e8f6f4")
            style.configure("TProgressbar", background="#25c2b2", troughcolor="#102026",
                            bordercolor="#102026", lightcolor="#25c2b2", darkcolor="#1b9e91",
                            thickness=16, borderwidth=0)

            outer = ttk.Frame(self, padding=14)
            outer.pack(fill="both", expand=True)

            header = ttk.Frame(outer)
            header.pack(fill="x")
            ttk.Label(header, text="NEXUS  ·  sincronizador", style="Title.TLabel").pack(side="left")
            ttk.Label(header, textvariable=self.remote_label, style="Muted.TLabel").pack(side="right")

            repo_box = ttk.LabelFrame(outer, text="Repositorio y destino", style="Card.TLabelframe", padding=10)
            repo_box.pack(fill="x", pady=(10, 8))
            repo_box.columnconfigure(1, weight=3)
            repo_box.columnconfigure(3, weight=2)

            ttk.Label(repo_box, text="Carpeta del proyecto").grid(row=0, column=0, sticky="w")
            ttk.Entry(repo_box, textvariable=self.target).grid(row=0, column=1, sticky="we", padx=6)
            ttk.Button(repo_box, text="Elegir…", command=self._pick_target).grid(row=0, column=2, padx=(0, 12))
            ttk.Label(repo_box, text="Rama").grid(row=0, column=3, sticky="e")
            ttk.Entry(repo_box, textvariable=self.branch, width=12).grid(row=0, column=4, sticky="we")

            ttk.Label(repo_box, text="Repositorio").grid(row=1, column=0, sticky="w", pady=(8, 0))
            ttk.Entry(repo_box, textvariable=self.repo).grid(row=1, column=1, sticky="we", padx=6, pady=(8, 0))
            ttk.Label(repo_box, text="Token").grid(row=1, column=3, sticky="e", pady=(8, 0))
            ttk.Entry(repo_box, textvariable=self.token, show="•").grid(row=1, column=4, sticky="we", pady=(8, 0))

            token_row = ttk.Frame(repo_box)
            token_row.grid(row=2, column=0, columnspan=5, sticky="w", pady=(8, 0))
            ttk.Checkbutton(token_row, text="recordar token en este equipo",
                            variable=self.remember_token).pack(side="left")
            ttk.Label(token_row, textvariable=self._token_hint(), style="Muted.TLabel").pack(side="left", padx=12)

            options = ttk.LabelFrame(outer, text="Opciones", style="Card.TLabelframe", padding=10)
            options.pack(fill="x", pady=(0, 8))
            for column in range(3):
                options.columnconfigure(column, weight=1)
            ttk.Checkbutton(options, text="eliminar retirados",
                            variable=self.prune).grid(row=0, column=0, sticky="w")
            ttk.Checkbutton(options, text="respaldo antes de sobrescribir",
                            variable=self.backup).grid(row=0, column=1, sticky="w", padx=16)
            ttk.Checkbutton(options, text="assets fuente (174 MB)",
                            variable=self.full).grid(row=0, column=2, sticky="w", padx=16)
            ttk.Checkbutton(options, text="comprobar cada 30 s",
                            variable=self.auto_check).grid(row=1, column=0, sticky="w", pady=(6, 0))
            ttk.Checkbutton(options, text="aplicar automático",
                            variable=self.auto_apply).grid(row=1, column=1, sticky="w", padx=16, pady=(6, 0))
            ttk.Checkbutton(options, text="forzar descarga",
                            variable=self.force_download).grid(row=1, column=2, sticky="w", padx=16, pady=(6, 0))
            ttk.Checkbutton(options, text="borrar .godot al actualizar (recomendado)",
                            variable=self.clean_cache).grid(row=2, column=0, columnspan=2,
                                                            sticky="w", pady=(6, 0))

            actions = ttk.Frame(outer)
            actions.pack(fill="x", pady=(0, 10))
            self.check_button = ttk.Button(actions, text="Comprobar actualización", command=self.check)
            self.check_button.pack(side="left")
            self.sync_button = ttk.Button(actions, text="Sincronizar ahora", style="Accent.TButton",
                                          command=lambda: self.start(dry_run=False))
            self.sync_button.pack(side="left", padx=8)
            self.plan_button = ttk.Button(actions, text="Ver plan", command=lambda: self.start(dry_run=True))
            self.plan_button.pack(side="left")
            self.cancel_button = ttk.Button(actions, text="Cancelar", command=self.cancel, state="disabled")
            self.cancel_button.pack(side="left", padx=8)
            ttk.Button(actions, text="Abrir carpeta", command=self._open_target).pack(side="right")
            ttk.Button(actions, text="Reparar", command=self.repair).pack(side="right", padx=8)

            progress_box = ttk.Frame(outer)
            progress_box.pack(fill="x")
            self.progress = ttk.Progressbar(progress_box, maximum=100.0, value=0.0)
            self.progress.pack(fill="x")
            labels = ttk.Frame(progress_box)
            labels.pack(fill="x", pady=(4, 8))
            ttk.Label(labels, textvariable=self.status).pack(side="left")
            ttk.Label(labels, textvariable=self.detail, style="Muted.TLabel").pack(side="right")

            log_box = ttk.LabelFrame(outer, text="Registro", style="Card.TLabelframe", padding=8)
            log_box.pack(fill="both", expand=True)
            self.log_text = tk.Text(log_box, height=12, bg="#081014", fg="#cbe6e2", relief="flat",
                                    insertbackground="#cbe6e2", font=("Consolas", 9), wrap="word")
            scroll = ttk.Scrollbar(log_box, orient="vertical", command=self.log_text.yview)
            self.log_text.configure(yscrollcommand=scroll.set)
            self.log_text.pack(side="left", fill="both", expand=True)
            scroll.pack(side="right", fill="y")
            self.log_text.tag_configure("info", foreground="#9fc4c8")
            self.log_text.tag_configure("ok", foreground="#63e2b7")
            self.log_text.tag_configure("warn", foreground="#f2c46b")
            self.log_text.tag_configure("error", foreground="#ff7b72")
            self.log_text.configure(state="disabled")

            footer = ttk.Frame(outer)
            footer.pack(fill="x", pady=(8, 0))
            ttk.Label(footer, text="El token nunca se escribe en el proyecto; el manifiesto guarda hashes y commit.",
                      style="Muted.TLabel").pack(side="left")

        def _token_hint(self) -> tk.StringVar:
            hint = tk.StringVar()
            if token_from_environment():
                hint.set("(detectado en el entorno)")
            else:
                hint.set("(vacío = repositorio público)")
            return hint

        # -- interacción -------------------------------------------------- #
        def _pick_target(self) -> None:
            chosen = filedialog.askdirectory(title="Carpeta raíz del proyecto Godot",
                                             initialdir=self.target.get() or str(Path.home()))
            if chosen:
                self.target.set(chosen)

        def _open_target(self) -> None:
            path = Path(self.target.get()).expanduser()
            if not path.exists():
                messagebox.showwarning("NEXUS", "La carpeta no existe todavía.")
                return
            try:
                if os.name == "nt":
                    os.startfile(str(path))  # type: ignore[attr-defined]
                elif sys.platform == "darwin":
                    import subprocess
                    subprocess.Popen(["open", str(path)])
                else:
                    import subprocess
                    subprocess.Popen(["xdg-open", str(path)])
            except OSError as error:
                messagebox.showerror("NEXUS", "No se pudo abrir la carpeta: %s" % error)

        def _append(self, level: str, text: str) -> None:
            stamp = time.strftime("%H:%M:%S")
            self.log_text.configure(state="normal")
            self.log_text.insert("end", "[%s] %s\n" % (stamp, text), level)
            self.log_text.see("end")
            self.log_text.configure(state="disabled")

        def _set_running(self, running: bool) -> None:
            state = "disabled" if running else "normal"
            for button in (self.sync_button, self.plan_button, self.check_button):
                button.configure(state=state)
            self.cancel_button.configure(state="normal" if running else "disabled")

        def _build_options(self, dry_run: bool) -> argparse.Namespace:
            return argparse.Namespace(
                target=self.target.get().strip(),
                repo=self.repo.get().strip(),
                branch=self.branch.get().strip(),
                mode="api",
                archive=None,
                token_file=None,
                no_token=False,
                dry_run=dry_run,
                prune=bool(self.prune.get()),
                force_prune=False,
                full=bool(self.full.get()),
                backup_dir=None,
                no_backup=not bool(self.backup.get()),
                keep_download=None,
                force=False,
                force_download=bool(self.force_download.get()),
                clean_cache=bool(self.clean_cache.get()),
                repair=False,
                yes=True,
            )

        def _token(self) -> str | None:
            entered = self.token.get().strip()
            if entered:
                return entered
            if self.cli_token_file:
                return token_from_file(self.cli_token_file)
            remembered = self.settings.get("token")
            return remembered if isinstance(remembered, str) and remembered else token_from_environment()

        def _remember(self) -> None:
            data = {
                "target": self.target.get().strip(),
                "repo": self.repo.get().strip(),
                "branch": self.branch.get().strip(),
                "prune": bool(self.prune.get()),
                "backup": bool(self.backup.get()),
                "auto_check": bool(self.auto_check.get()),
                "auto_apply": bool(self.auto_apply.get()),
                "clean_cache": bool(self.clean_cache.get()),
            }
            if self.remember_token.get() and self.token.get().strip():
                data["token"] = self.token.get().strip()
            self.settings = data
            save_settings(data)

        # -- acciones ----------------------------------------------------- #
        def check(self) -> None:
            if self.worker is not None:
                return
            options = self._build_options(dry_run=True)
            token = self._token()
            self.status.set("Comprobando la rama remota…")
            self.detail.set("")
            self.progress.configure(value=0)

            def work() -> None:
                try:
                    remote, local = SyncEngine(options, token=token,
                                               target=Path(options.target).expanduser()).check_only()
                    self.events.put(("checked", remote, local))
                except Exception as error:  # noqa: BLE001
                    self.events.put(("error", str(error)))

            self.worker = threading.Thread(target=work, daemon=True)
            self.worker.start()

        def start(self, dry_run: bool) -> None:
            if self.worker is not None:
                return
            options = self._build_options(dry_run=dry_run)
            target = Path(options.target).expanduser()
            if target.exists() and any(target.iterdir()) and not (target / "project.godot").is_file():
                if not messagebox.askyesno("NEXUS", "En esa carpeta no hay project.godot.\n¿Sincronizar de todos modos?"):
                    return
                options.force = True
            token = self._token()
            self._remember()
            self.cancel_event.clear()
            self._set_running(True)
            self.progress.configure(value=0)
            self.status.set("Preparando…")
            self.detail.set("")
            self._append("info", "Sincronización %s en %s" % ("simulada" if dry_run else "real", target))

            engine = SyncEngine(
                options,
                progress=lambda fraction, text: self.events.put(("progress", fraction, text)),
                log=lambda level, text: self.events.put(("log", level, text)),
                cancel=self.cancel_event.is_set,
                token=token,
                target=target,
            )

            def work() -> None:
                try:
                    report = engine.run()
                    self.events.put(("done", report))
                except SyncCancelled:
                    self.events.put(("cancelled", None))
                except SyncError as error:
                    self.events.put(("error", scrub(str(error), token)))
                except Exception as error:  # noqa: BLE001
                    self.events.put(("error", scrub(repr(error), token)))

            self.worker = threading.Thread(target=work, daemon=True)
            self.worker.start()

        def repair(self) -> None:
            target = Path(self.target.get()).expanduser()
            if not target.is_dir():
                messagebox.showwarning("NEXUS", "La carpeta no existe.")
                return
            if not messagebox.askyesno("NEXUS · reparar",
                                       "Se borrará la caché .godot (Godot la reconstruye al abrir) "
                                       "y los .import sin archivo fuente.\n\n¿Continuar?"):
                return
            if self.worker is not None:
                return
            self._set_running(True)
            self.status.set("Reparando proyecto…")
            self.progress.configure(value=0)

            def work() -> None:
                try:
                    removed, cleaned = repair_project(
                        target, lambda level, text: self.events.put(("log", level, text)))
                    self.events.put(("repaired", removed, cleaned))
                except Exception as error:  # noqa: BLE001
                    self.events.put(("error", str(error)))

            self.worker = threading.Thread(target=work, daemon=True)
            self.worker.start()

        def cancel(self) -> None:
            self.cancel_event.set()
            self.status.set("Cancelando…")

        def _auto_tick(self) -> None:
            try:
                if self.auto_check.get() and self.worker is None:
                    if time.monotonic() - self.last_check > 30.0:
                        self.last_check = time.monotonic()
                        self.check()
            finally:
                self.after(5000, self._auto_tick)

        # -- bucle de eventos --------------------------------------------- #
        def _drain(self) -> None:
            try:
                while True:
                    event = self.events.get_nowait()
                    kind = event[0]
                    if kind == "progress":
                        fraction, text = event[1], event[2]
                        self.progress.configure(value=fraction * 100.0)
                        self.status.set(text)
                        self.detail.set("%d%%" % int(fraction * 100))
                    elif kind == "log":
                        self._append(event[1], event[2])
                    elif kind == "checked":
                        self._on_checked(event[1], event[2])
                    elif kind == "done":
                        self._on_done(event[1])
                    elif kind == "repaired":
                        self.worker = None
                        self._set_running(False)
                        self.progress.configure(value=0)
                        self.status.set("Proyecto reparado · abre Godot para reimportar")
                        self._append("ok", "Reparación lista: %d .import huérfano(s), caché %s."
                                     % (event[1], "borrada" if event[2] else "intacta"))
                        self.after(300, self.check)
                    elif kind == "cancelled":
                        self.worker = None
                        self._set_running(False)
                        self.progress.configure(value=0)
                        self.status.set("Cancelado")
                        self._append("warn", "Sincronización cancelada por el usuario.")
                    elif kind == "error":
                        self.worker = None
                        self._set_running(False)
                        self.progress.configure(value=0)
                        self.status.set("Error")
                        self._append("error", event[1])
                        messagebox.showerror("NEXUS", event[1])
            except queue.Empty:
                pass
            finally:
                self.after(self.POLL_MS, self._drain)

        def _on_checked(self, remote: str | None, local: str | None) -> None:
            self.worker = None
            if remote is None:
                self.remote_label.set("Rama remota: sin conexión")
                self.status.set("No se pudo consultar la rama")
                self.progress.configure(value=0)
                self._append("warn", "No se pudo consultar la rama remota: %s"
                             % (REMOTE_PROBLEM or "red, token o nombre del repositorio"))
                return
            self.remote_label.set("Rama remota: %s" % remote[:7])
            if local is None:
                self.status.set("Sin sincronizar · remoto %s" % remote[:7])
                self.progress.configure(value=0)
                self._append("info", "Remoto en %s; esta carpeta todavía no tiene manifiesto." % remote[:7])
            elif remote == local:
                self.status.set("Al día · %s" % remote[:7])
                self.progress.configure(value=0)
                self._append("ok", "Al día con la rama %s (%s)." % (self.branch.get(), remote[:7]))
            else:
                self.status.set("Actualización disponible · %s → %s" % (str(local)[:7], remote[:7]))
                self.progress.configure(value=12)
                self._append("warn", "Actualización disponible: %s → %s" % (str(local)[:7], remote[:7]))
                if self.auto_apply.get() and self.worker is None:
                    self._append("info", "Aplicando automáticamente…")
                    self.start(dry_run=False)

        def _on_done(self, report: Report) -> None:
            self.worker = None
            self._set_running(False)
            self.progress.configure(value=100)
            self.status.set("Listo · %s" % report.summary())
            self._append("ok", report.summary() + " · %.1f s" % report.elapsed)
            for rel in report.added[:20]:
                self._append("info", "+ %s" % rel)
            for rel in report.updated[:20]:
                self._append("info", "~ %s" % rel)
            for rel in report.removed[:20]:
                self._append("info", "- %s" % rel)
            if len(report.added) + len(report.updated) + len(report.removed) > 60:
                self._append("info", "… y %d archivo(s) más"
                             % (len(report.added) + len(report.updated) + len(report.removed) - 60))
            if report.overwritten_local_changes:
                self._append("warn", "%d archivo(s) con cambios locales sobrescritos (hay respaldo)."
                             % len(report.overwritten_local_changes))
            if report.kept_local:
                self._append("warn", "%d archivo(s) retirados se conservan por estar editados."
                             % len(report.kept_local))
            if not report.dry_run:
                self.remote_label.set("Sincronizado · %s" % (report.remote_commit[:7]
                                                            if report.remote_commit else "local"))
                self.after(200, self.check)

        def _on_close(self) -> None:
            self._remember()
            if self.worker is not None and not messagebox.askyesno("NEXUS", "Hay una sincronización en curso.\n¿Cerrar igualmente?"):
                return
            self.cancel_event.set()
            self.destroy()

    app = SyncApp()
    app.mainloop()
    return 0


# --------------------------------------------------------------------------- #
# entrada
# --------------------------------------------------------------------------- #
def _windows_pause() -> None:
    if os.name != "nt" or "--no-pause" in sys.argv:
        return
    try:
        if sys.stdin.isatty():
            input("\nPulsa Intro para cerrar…")
    except (EOFError, KeyboardInterrupt):
        pass


def main(argv: list[str] | None = None) -> int:
    try:
        sys.stdout.reconfigure(line_buffering=True)
        sys.stderr.reconfigure(line_buffering=True)
    except (AttributeError, ValueError):
        pass
    arguments = sys.argv[1:] if argv is None else argv
    parser = build_parser()
    args = parser.parse_args(arguments)

    wants_gui = args.gui or (not arguments and not args.no_gui)
    if wants_gui and not args.no_gui:
        try:
            return launch_gui(args)
        except ImportError:
            print("tkinter no está disponible; se usa la consola.", file=sys.stderr)
    try:
        return run_cli(args)
    except SyncError as error:
        print("ERROR: %s" % error, file=sys.stderr)
        return 3


if __name__ == "__main__":
    try:
        exit_code = main()
    except KeyboardInterrupt:
        print("\nInterrumpido.")
        exit_code = 130
    _windows_pause()
    raise SystemExit(exit_code)
