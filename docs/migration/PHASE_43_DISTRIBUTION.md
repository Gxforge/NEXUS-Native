# Fase 43 · Distribución: presets y construcción reproducible

**Fecha:** 24 de noviembre de 2026
**Estado:** cerrada · `run_suite` **435 checks, 0 fallos** · `validate_distribution` **38 checks**
**Punto de partida:** `32ecb8b` (fase 42)

Hasta aquí el proyecto sólo se ejecutaba desde el editor. Esta fase deja los
tres destinos configurados, un script que construye de una pasada y un informe
con tamaño y suma SHA-256 de cada binario, para que dos máquinas que partan del
mismo commit produzcan el mismo paquete.

## 1. Presets (`export_presets.cfg`)

| Preset | Plataforma | Destino | Notas |
| --- | --- | --- | --- |
| `Linux` | Linux | `build/linux/NEXUS-Native.x86_64` | x86_64, PCK incrustado |
| `Windows Desktop` | Windows Desktop | `build/windows/NEXUS-Native.exe` | x86_64, PCK incrustado, consola de depuración |
| `Android` | Android | `build/android/NEXUS-Native.apk` | arm64-v8a, pantalla inmersiva, minSdk 21 / targetSdk 34 |

Los tres excluyen del paquete `qa/`, `reports/`, `docs/` y `tools/`: las
capturas y la suite no viajan al jugador. El nombre del paquete es
`com.gxforge.nexusnative`, el rótulo `NEXUS Native`, el código de versión **43**
y el nombre **0.43.0**, que es el mismo `application/config/version` del
proyecto (el validador comprueba que no se separen).

El APK se exporta **sin firmar** y el script lo firma después con `apksigner`:
así el empaquetado de Godot y la firma no coinciden en memoria, que es lo que
rompía la exportación en máquinas pequeñas.

## 2. Ajustes de proyecto que trajo la fase

- `application/config/version = "0.43.0"`.
- `rendering/textures/vram_compression/import_etc2_astc = true`. **Es un
  requisito del export de Android** y su ausencia se manifiesta como un
  `Cannot export project with preset "Android" due to configuration errors:`
  con el mensaje **vacío**: Godot devuelve `false` desde
  `has_valid_project_configuration` sin añadir texto. Se localizó leyendo
  `export_plugin.cpp` de la 4.4.1.
- `reports/.gdignore` y `tools/.gdignore`: las 40 MB de capturas ya no se
  importan como texturas. Además de no viajar al paquete, el import dejó de
  necesitar memoria para ellas.
- `.gitignore`: `/build/`, `*.idsig` y `*.keystore` fuera del repositorio.

## 3. `tools/build.sh`

```
tools/build.sh                 # linux y windows
tools/build.sh linux windows android
GODOT=/ruta/godot tools/build.sh linux
```

1. **Importa** los recursos (`--headless --import`), que con ETC2 activo es lo
   que deja los `.ctex` listos para móvil.
2. **Puerta de calidad**: corre `qa/run_suite.gd` y aborta si `failures` no está
   vacío. Un build nunca sale con la suite en rojo.
3. **Exporta** cada destino con su preset.
4. **Firma y verifica** el APK con el `apksigner` del SDK
   (`GODOT_ANDROID_KEYSTORE_RELEASE_{PATH,USER,PASSWORD}` para usar otro
   keystore; por defecto el de depuración de Godot).
5. **Prueba de humo** del binario de Linux: lo arranca sin ventana y exige que
   escriba `NEXUS zone graph` en el log.
6. **Sumas e informe**: `build/SHA256SUMS` y `build/BUILD_REPORT.json` con
   versión, commit, motor, checks de la suite y tamaño/SHA-256 de cada artefacto.

## 4. Construcción de esta fase

```
== NEXUS Native 0.43.0 · 32ecb8b · 2026-11-25T20:03:10Z
-- motor: 4.4.1.stable.official.49a5bc7b6
-- suite: 424 checks, 0 fallos
```

| Artefacto | Bytes | SHA-256 |
| --- | --- | --- |
| `linux/NEXUS-Native.x86_64` | 149.472.960 | `1545484b31bf2370f193c14f2f8d49a5809d0971562894921b453be3c59682eb` |
| `windows/NEXUS-Native.exe` | 177.305.072 | `78e52a8ad9adaf7781f985d470f1cc676613ba8013c1ec8cdac1f89cedc6daa6` |
| `android/NEXUS-Native.apk` | 105.380.614 | `1b6d49849ba574fa4bb85b741673ecc8200bac88be8886814636631d464ba395` |

El APK firmado se verificó con `apksigner verify` (firma v1/v2 correcta) y con
`aapt2 dump badging`:

```
package: name='com.gxforge.nexusnative' versionCode='43' versionName='0.43.0'
sdkVersion:'21'  targetSdkVersion:'34'  native-code: 'arm64-v8a'
application-label:'NEXUS Native'
```

## 5. Lo que costó

- **El error silencioso de ETC2.** Media fase perdida en un mensaje vacío.
- **Memoria.** El empaquetado de Android trabaja con ~700 MB y la máquina de
  trabajo tiene 2 GB: el proceso moría por OOM. La causa real era que `/tmp`
  (tmpfs) acumulaba 945 MB de restos de exportaciones anteriores, que cuentan
  como memoria del contenedor; vaciarlo devolvió la mitad de la RAM y el build
  completo pasó a la primera.
- **Caché de import corrupta.** Una exportación interrumpida dejó `.godot` a
  medias y los binarios exportados salían con el PCK roto (`Corrupted header in
  binary project.binary (not ECFG)`). Se arregló borrando `.godot` y
  reimportando **por lotes**: con todos los `.glb` fuera del proyecto, e ir
  devolviendo uno a uno los 42 modelos, importando tras cada uno. Los dos
  últimos (`workshop_pods.glb`, 39 MB, y `laboratory_all_sectors.glb`, 71 MB)
  necesitaron la memoria libre del punto anterior.

## 6. Lo que queda para cerrar P-8/P-9

El paquete está construido, pero los controles táctiles de `Touch.ts` siguen sin
verificarse en un dispositivo real. Checklist con el APK en mano:

1. `adb install -r build/android/NEXUS-Native.apk` (arm64, API 21+).
2. Comprobar que el HUD táctil aparece: D-pad, correr, mirar por arrastre y los
   botones de acción; que el gesto de mirar no se coma los toques del D-pad.
3. Medir fotogramas con el perfil `low` en el arranque (el `render_density` se
   calcula con `DisplayServer.is_touchscreen_available()`).
4. Repetir el escaneo, el inventario y el tránsito con guantes táctiles para
   confirmar que los rayos de interacción no dependen del ratón.

Con eso verificado, P-8 y P-9 quedan cerrados; la distribución ya está hecha.
