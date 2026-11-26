# Entregas de NEXUS Native

Cada entrega se publica como **release de GitHub con etiqueta `vX.Y.Z`** y los
binarios de producción adjuntos. La versión vive en tres sitios y los tres tienen
que decir lo mismo (`qa/validate_distribution.gd` lo comprueba):

| Sitio | Ejemplo 0.44.0 |
| --- | --- |
| `project.godot` → `application/config/version` | `0.44.0` |
| `export_presets.cfg` → Android `version/name` + `version/code` | `0.44.0` / `44` |
| Etiqueta de git y nombre de la release | `v0.44.0` |

El nombre de los artefactos lleva plataforma y arquitectura:
`NEXUS-Native-<versión>-windows-x86_64.exe` y
`NEXUS-Native-<versión>-android-arm64.apk`, acompañados de `SHA256SUMS.txt` y
`BUILD_REPORT.json` (commit, fecha, motor, checks de la suite y hash de cada
binario).

## Publicar una versión

1. Subir la versión en `project.godot`, en el preset de Android y en
   `qa/validate_distribution.gd` (el check compara con la cadena literal).
2. Construir:

   ```bash
   GODOT=/ruta/Godot_v4.4.1-stable_linux.x86_64 \
   ANDROID_SDK_ROOT=$HOME/android-sdk \
   GODOT_ANDROID_KEYSTORE_RELEASE_PATH=$HOME/release-keys/nexus-release.keystore \
   GODOT_ANDROID_KEYSTORE_RELEASE_USER=nexus \
   GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD=… \
   ./tools/build.sh windows android
   ```

3. Comprobar la firma y el manifiesto:

   ```bash
   $ANDROID_SDK_ROOT/build-tools/34.0.0/apksigner verify --print-certs --verbose build/android/NEXUS-Native.apk
   $ANDROID_SDK_ROOT/build-tools/34.0.0/aapt2 dump badging build/android/NEXUS-Native.apk | head
   ```

4. Renombrar los binarios con versión y plataforma, sacar `SHA256SUMS.txt`.
5. Escribir las notas en `docs/releases/vX.Y.Z.md`, commit, `git tag -a vX.Y.Z`
   y publicar la release con los cuatro archivos (dos binarios, sumas, informe).

## Clave de firma de Android

El APK se firma **fuera** de Godot, con `apksigner`, usando una clave de release
RSA 4096 creada para el proyecto:

- Keystore: `~/release-keys/nexus-release.keystore` (PKCS#12, alias `nexus`).
- Contraseña: `~/release-keys/password.txt` — **fuera del repositorio**, nunca se
  versiona.
- Huella del certificado (SHA-256):
  `96:1E:8B:3B:0E:B1:6D:9D:CD:38:02:F4:CB:76:04:EF:D3:39:1C:14:3D:8D:C1:A4:A9:94:6D:82:E7:26:87:F8`
- Esquemas verificados en 0.44.0: v1 (JAR), v2 y v3.

**Guardar una copia de la clave fuera de esta máquina.** Android identifica la
aplicación por esa clave: si se pierde, las versiones nuevas no se pueden
instalar encima de las antiguas (habría que desinstalar y perder los datos), y
tampoco se podría subir a Google Play con esa identidad. Cuando el juego vaya a
Play, se puede mantener esta clave como upload key y registrar el *app signing
key* de Google.
