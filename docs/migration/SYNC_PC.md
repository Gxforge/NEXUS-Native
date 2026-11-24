# Sincronizar el repositorio con la carpeta del PC

`tools/sync_nexus.py` descarga la rama actualizada de GitHub (autenticada con tu
token) y escribe los archivos en la **raíz del proyecto local**: añade los
nuevos, actualiza los modificados y, si se pide, elimina los retirados. No usa
dependencias externas y funciona en Windows, Linux y macOS con Python 3.9+.

## Uso habitual

Deja el script en la raíz del proyecto (o usa `tools/sync_nexus.py`): **sin
`--target` sincroniza la carpeta donde vive el script**, así que funciona desde
cualquier directorio, incluso con doble clic.

```bat
:: Windows: doble clic en SINCRONIZAR.bat, o desde cmd
set NEXUS_GITHUB_TOKEN=ghp_xxx
python sync_nexus.py
python sync_nexus.py --dry-run          :: solo muestra el plan
```

```bash
# Linux / macOS
export NEXUS_GITHUB_TOKEN=ghp_xxx
python3 tools/sync_nexus.py
```

`SINCRONIZAR.bat` vive en la raíz del repositorio y hace lo mismo con un clic:
pide el token si no está en el entorno y ejecuta el sincronizador sobre esa
carpeta.

Sin `--yes` pide confirmación antes de escribir. Con `--dry-run` solo muestra el
plan (nuevos `+`, actualizados `~`, eliminados `-`).

## Opciones

| Opción | Efecto |
|---|---|
| `--target RUTA` | carpeta raíz del proyecto. Opcional: por defecto la carpeta del propio script (si no hay `project.godot` ahí, el directorio actual). Si está vacía o no existe, se crea |
| `--repo owner/repo` | por defecto `Gxforge/NEXUS-Native` |
| `--branch main` | rama a sincronizar |
| `--mode api\|git` | `api` (zipball HTTPS, por defecto) o clonar con `git` |
| `--archive archivo` | sincroniza desde un `.zip`/`.tar.gz` local, sin red |
| `--token-file ruta` | token desde archivo; si no, `NEXUS_GITHUB_TOKEN`, `GH_TOKEN`, `GITHUB_TOKEN` o consola |
| `--no-token` | fuerza descarga anónima (válido para este repositorio público) |
| `--dry-run` | simula sin escribir nada |
| `--prune` | borra archivos que ya no existen en el repositorio |
| `--force-prune` | borra también los retirados que habías editado en local |
| `--full` | incluye `assets/generated/source-batch` (174 MB, solo pase de fidelidad) |
| `--backup-dir RUTA` / `--no-backup` | dónde guardar el respaldo de lo sobrescrito (por defecto, junto al proyecto) |
| `--keep-download RUTA` | conserva el zip descargado |
| `--force` | permite un destino que no contenga `project.godot` |

## Garantías

- **Manifiesto**: tras cada sincronización se escribe `.nexus-sync-manifest.json`
  con el hash SHA-256 de cada archivo sincronizado. Sirve para detectar cambios
  locales y para saber qué borrar con `--prune`.
- **Nunca toca lo tuyo**: los archivos que no vinieron del repositorio (partidas,
  notas, builds exportadas) se quedan donde están.
- **Respaldo**: antes de sobrescribir, copia las versiones anteriores a
  `nexus-sync-backup-AAAAMMDD-HHMMSS/` junto al proyecto.
- **Protección**: un archivo retirado del repositorio que hayas editado en local
  se conserva salvo que uses `--force-prune`.
- **Nunca escribe el token** en disco ni en el manifiesto, y lo censura en los
  mensajes de error.
- Se ignoran `.git/`, `.godot/`, `__pycache__/`, basura del sistema y, salvo
  `--full`, los GLB fuente pesados.

## Windows rápido

```bat
D:\proyectos\proyecto game\nexus-native> python sync_nexus.py
Destino: D:\proyectos\proyecto game\nexus-native (carpeta del script; usa --target para cambiarla)
```

Si el script se coloca fuera de cualquier proyecto y no se pasa `--target`, avisa
de que falta `project.godot` y recuerda cómo indicar la carpeta.

## Verificación

Probado de extremo a extremo contra `Gxforge/NEXUS-Native` desde una carpeta
vacía: 290 archivos, 12,3 MB, y el proyecto resultante pasa
`qa/run_suite.gd` (148/148) y `qa/validate_zone_traversal.gd` (255/255) sin
tocar nada más. También se probaron los casos de alta, actualización, borrado,
archivo editado en local y simulación.
