#!/usr/bin/env bash
# Construcción reproducible de NEXUS Native (fase 43).
#
#   tools/build.sh                 # linux y windows
#   tools/build.sh linux windows android
#   GODOT=/ruta/godot tools/build.sh linux
#
# Requisitos:
#   · Plantillas de exportación 4.4.1 (Godot_v4.4.1-stable_export_templates.tpz
#     descomprimido en ~/.local/share/godot/export_templates/4.4.1.stable).
#   · Para android: SDK de Android con platform-tools, build-tools y
#     platforms/android-34, un JDK 17+ y un keystore. Si no se pasa
#     GODOT_ANDROID_KEYSTORE_RELEASE_PATH/USER/PASSWORD se usa el keystore de
#     depuración de Godot (~/.local/share/godot/keystores/debug.keystore).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT="${GODOT:-/tmp/godot-4.4.1/Godot_v4.4.1-stable_linux.x86_64}"
OUT="${OUT:-$ROOT/build}"
PROJECT_VERSION="$(sed -n 's/^config\/version="\(.*\)"/\1/p' "$ROOT/project.godot")"
COMMIT="$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null || echo "sin-git")"
STAMP="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

TARGETS=("$@")
if [ ${#TARGETS[@]} -eq 0 ]; then
	TARGETS=(linux windows)
fi

mkdir -p "$OUT"

echo "== NEXUS Native $PROJECT_VERSION · $COMMIT · $STAMP"
if [ ! -x "$GODOT" ]; then
	echo "No encuentro el binario de Godot en $GODOT (usa GODOT=...)" >&2
	exit 2
fi
echo "-- motor: $("$GODOT" --headless --version 2>/dev/null | tail -1)"

# 1a. Manifiesto de carga: la pantalla de carga necesita saber, ya en el juego
#     exportado, qué recursos componen cada zona y cuánto pesan.
"$GODOT" --headless --path "$ROOT" --script tools/gen_load_plan.gd >"$OUT/load_plan.log" 2>&1 || {
	echo "falló el manifiesto de carga; ver $OUT/load_plan.log" >&2
	exit 1
}
tail -1 "$OUT/load_plan.log"

# 1. Importar recursos: deja .godot y los .import al día (y con ETC2/ASTC,
#    que es lo que exige el export de Android).
"$GODOT" --headless --path "$ROOT" --import >"$OUT/import.log" 2>&1 || {
	echo "falló la importación; ver $OUT/import.log" >&2
	exit 1
}

# 2. Puerta de calidad: la suite completa tiene que quedar a cero fallos.
"$GODOT" --headless --path "$ROOT" --script res://qa/run_suite.gd >"$OUT/suite.log" 2>&1 || true
CHECKS="$(grep -oE '"checks":[0-9]+' "$OUT/suite.log" | tail -1 | cut -d: -f2)"
FAILURES="$(grep -oE '"failures":\[[^]]*\]' "$OUT/suite.log" | tail -1)"
if [ "${FAILURES:-}" != '"failures":[]' ]; then
	echo "la suite no está verde: ${FAILURES:-sin resultado}" >&2
	exit 1
fi
echo "-- suite: $CHECKS checks, 0 fallos"

# 3. Exportar cada destino con su preset.
ARTIFACTS=()
for target in "${TARGETS[@]}"; do
	case "$target" in
		linux)
			preset="Linux"
			path="$OUT/linux/NEXUS-Native.x86_64"
			;;
		windows)
			preset="Windows Desktop"
			path="$OUT/windows/NEXUS-Native.exe"
			;;
		android)
			preset="Android"
			path="$OUT/android/NEXUS-Native.apk"
			unsigned="$OUT/android/NEXUS-Native-unsigned.apk"
			;;
		*)
			echo "destino desconocido: $target" >&2
			exit 4
			;;
	esac
	mkdir -p "$(dirname "$path")"
	if [ "$target" = "android" ]; then
		# El empaquetado del APK trabaja sobre ~200 MB en memoria: en máquinas
		# de 2 GB conviene soltar la caché de disco antes (si hay sudo).
		sudo -n sh -c 'sync; echo 3 > /proc/sys/vm/drop_caches' 2>/dev/null || true
	fi
	echo "-- exportando $preset"
	"$GODOT" --headless --path "$ROOT" --export-release "$preset" "$path" >"$OUT/export-$target.log" 2>&1 || {
		echo "falló el export de $preset; ver $OUT/export-$target.log" >&2
		exit 1
	}
	if [ ! -s "$path" ]; then
		echo "el export de $preset no generó $path" >&2
		exit 1
	fi
	if [ "$target" = "android" ]; then
		# El preset exporta sin firmar (apksigner necesita menos memoria por
		# separado) y aquí se firma con el keystore de depuración.
		APKSIGNER="$(command -v apksigner || true)"
		if [ -z "$APKSIGNER" ]; then
			APKSIGNER="$(ls -1 "${ANDROID_SDK_ROOT:-$HOME/android-sdk}"/build-tools/*/apksigner 2>/dev/null | tail -1)"
		fi
		if [ -z "$APKSIGNER" ] || [ ! -x "$APKSIGNER" ]; then
			echo "android: no encuentro apksigner (instala build-tools del SDK)" >&2
			exit 5
		fi
		keystore="${GODOT_ANDROID_KEYSTORE_RELEASE_PATH:-$HOME/.local/share/godot/keystores/debug.keystore}"
		alias_user="${GODOT_ANDROID_KEYSTORE_RELEASE_USER:-androiddebugkey}"
		alias_pass="${GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD:-android}"
		mv "$path" "$unsigned"
		echo "-- firmando $path"
		"$APKSIGNER" sign --ks "$keystore" --ks-pass "pass:$alias_pass" \
			--ks-key-alias "$alias_user" --v1-signing-enabled true --v2-signing-enabled true \
			--out "$path" "$unsigned" >>"$OUT/export-$target.log" 2>&1
		"$APKSIGNER" verify "$path" >>"$OUT/export-$target.log" 2>&1 || {
			echo "el APK no verifica; ver $OUT/export-$target.log" >&2
			exit 6
		}
		rm -f "$unsigned" "$path.idsig" "$unsigned.idsig"
	fi
	ARTIFACTS+=("$path")
done

# 4. Prueba de humo del binario de Linux: arranca sin ventana y lee el grafo.
for artifact in "${ARTIFACTS[@]}"; do
	case "$artifact" in
		*.x86_64)
			echo "-- prueba de humo: $artifact"
			if ! "$artifact" --headless --quit-after 90 >"$OUT/smoke.log" 2>&1; then
				echo "el binario exportado no arranca; ver $OUT/smoke.log" >&2
				exit 7
			fi
			if ! grep -q "NEXUS zone graph" "$OUT/smoke.log"; then
				echo "el binario no inicializa el grafo de zonas; ver $OUT/smoke.log" >&2
				exit 8
			fi
			;;
	esac
done

# 5. Sumas de verificación e informe.
(
	cd "$OUT"
	for artifact in "${ARTIFACTS[@]}"; do
		sha256sum "${artifact#"$OUT/"}"
	done
) >"$OUT/SHA256SUMS"

ARTIFACTS_JOINED="$(printf '%s\n' "${ARTIFACTS[@]}")" \
CHECKS="$CHECKS" COMMIT="$COMMIT" STAMP="$STAMP" PROJECT_VERSION="$PROJECT_VERSION" \
OUT="$OUT" GODOT="$GODOT" python3 - <<'PY'
import hashlib, json, os, pathlib, subprocess

out = pathlib.Path(os.environ["OUT"])
targets = []
for line in os.environ["ARTIFACTS_JOINED"].splitlines():
    path = pathlib.Path(line)
    if not path.is_file():
        continue
    digest = hashlib.sha256(path.read_bytes()).hexdigest()
    rel = path.relative_to(out)
    targets.append({
        "path": str(rel),
        "bytes": path.stat().st_size,
        "sha256": digest,
    })
report = {
    "project": "NEXUS Native",
    "version": os.environ["PROJECT_VERSION"],
    "commit": os.environ["COMMIT"],
    "built_at": os.environ["STAMP"],
    "engine": subprocess.run([os.environ["GODOT"], "--headless", "--version"],
                             capture_output=True, text=True).stdout.strip().splitlines()[-1],
    "suite_checks": int(os.environ["CHECKS"] or 0),
    "suite_failures": [],
    "artifacts": targets,
}
(out / "BUILD_REPORT.json").write_text(json.dumps(report, indent=2, ensure_ascii=False) + "\n")
print(json.dumps(report, indent=2, ensure_ascii=False))
PY

echo "== listo: $OUT"
