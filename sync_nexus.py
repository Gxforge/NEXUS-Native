#!/usr/bin/env python3
"""Lanzador de NEXUS Sync.

La implementación vive en `tools/sync_nexus.py` (una sola fuente de verdad). Este
archivo existe para que `python sync_nexus.py` funcione desde la raíz del
proyecto; si se ejecuta desde otro sitio, se sincroniza esta misma carpeta.

Uso:
    python sync_nexus.py                 # ventana con progreso
    python sync_nexus.py --dry-run       # solo muestra el plan
    python sync_nexus.py --repair        # borra .godot y .import huérfanos
"""

from __future__ import annotations

import runpy
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
REAL = HERE / "tools" / "sync_nexus.py"

if not REAL.is_file():
    sys.stderr.write(
        "No se encontró tools/sync_nexus.py.\n"
        "Ejecuta SINCRONIZAR.bat para restaurarlo desde el repositorio.\n"
    )


def _has_target(argv: list[str]) -> bool:
    return any(arg == "--target" or arg.startswith("--target=") for arg in argv)


def main() -> int:
    argv = list(sys.argv)
    if not _has_target(argv[1:]):
        # Sin --target, sincroniza la carpeta donde está este lanzador.
        argv[1:1] = ["--target", str(HERE)]
    sys.argv = argv
    try:
        runpy.run_path(str(REAL), run_name="__main__")
    except SystemExit as exit_error:
        code = exit_error.code
        return int(code) if isinstance(code, int) else 0
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
