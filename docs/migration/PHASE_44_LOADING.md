# Fase 44 · Pantalla de carga con progreso real

**Fecha:** 24 de noviembre de 2026
**Estado:** cerrada · `run_suite` **455 checks, 0 fallos** · versión 0.44.0
**Punto de partida:** `0a776e5` (fase 43)

La pantalla de carga se quedaba clavada en el **60 %** y su línea de datos
enseñaba enums del motor (`… · 38.2 s · informe 0 % · estado IDLE`). No era un
cuelgue: el juego entraba en 1,8 s. Eran dos cosas mal diseñadas desde la fase
37 —una barra que estimaba el tiempo en vez de contar recursos, y una línea de
diagnóstico interna visible al jugador—. Esta fase las sustituye por progreso
medido.

## 1. Por qué la barra se paraba en 60 %

`ResourceLoader.load_threaded_get_status(scene, progress)` devuelve
`progress[0] = 0` durante toda la precarga de una escena: el motor no reparte
el avance de un `.tscn` entre sus dependencias. La barra de la fase 37 lo
taponaba con un suelo exponencial (`8 + (1 − e^(−1,6·t)) · 52`) que tiende a
**60** y ahí se queda para siempre, mientras la zona seguía cargando por
detrás. De ahí "38,2 s / 72,5 s" y "estado IDLE": el reloj subía, la barra no.

## 2. Plan de carga por dependencias

`scripts/ui/loading_progress.gd` se reescribió alrededor de dos ideas:

- **`plan(module_path)`**: devuelve los recursos que necesita una zona —las
  dependencias `ext_resource` a dos niveles y el módulo **al final**, para que
  lo encuentre todo en caché—. Con tope de 64 recursos y sin repetidos.
- **Un recurso en vuelo cada vez**: `main.gd` pide uno, espera su
  `THREAD_LOAD_LOADED` y pasa al siguiente. Progreso = recursos terminados;
  dentro del recurso en curso la barra se arrastra hasta el 85 % de su tramo
  (nunca lo termina antes de tiempo). Entre el 92 % (techo de precarga) y el
  100 % queda el montaje real de la zona, con los pesos de estado de
  `ZoneManager`.

Con eso la barra sólo puede pararse si un recurso concreto tarda: es honesto.

## 3. Manifiesto generado en la construcción

En el juego exportado los `.tscn` y `.glb` viajan remapeados a `.scn` y su texto
no se puede leer, así que escanear dependencias en tiempo de ejecución sólo
funciona en el editor. `tools/gen_load_plan.gd` recorre las doce zonas y escribe
`data/load_plan.json` (**12 zonas · 136 recursos · 4,0 MB**), que se versiona y
se regenera en `tools/build.sh` antes de cada exportación. `LoadingProgress`
lee el manifiesto primero y cae al escaneo en disco si falta; las
comprobaciones de existencia usan `ResourceLoader.exists`, que respeta los
remapeos (`FileAccess.file_exists` no).

## 4. Línea de datos legible

Antes:

```
A01 · zone_a01_shell.tscn · 2 KB · 6 dependencias · 38.2 s / 72.5 s · informe 0 % · estado IDLE
```

Ahora, en el juego:

```
C04 · zone_c04_shell.tscn · 14 de 14 recursos · 3.2 MB · 0:02
```

Y el estado, en lenguaje de operador: `Cargando recursos · 7 de 14`,
`Montando la zona`, `Zona lista`. Nada de `IDLE`, `informe` ni porcentajes del
motor.

## 5. Cuando algo va lento

- A los **15 s** sin que termine ningún recurso, aparece un aviso en ámbar
  (`Un recurso grande está tardando más de lo normal`).
- A los **60 s**, el aviso ofrece salir y aparece el botón **Volver al menú**
  (`cancel_loading()`), que libera la pantalla y deja el menú utilizable. La
  línea de datos añade `sin avance 1:04`.
- Al terminar la precarga, la pantalla pinta **dos fotogramas** con el 92 % y
  `Montando la zona` antes de lanzar el tránsito: el montaje de la zona ocupa un
  fotograma entero (≈1,7 s en C-04) y, sin esa pausa, la pantalla se quedaba
  diciendo "14 de 14" durante el bloqueo.
- El cronómetro usa `Time.get_ticks_msec()`, no la suma de deltas: un fotograma
  bloqueado ya no congela el reloj.

## 6. Validación

Bloque `_validate_loading_progress` de `qa/run_suite.gd` reescrito: **25 comprobaciones**
(29 ejecutadas por el bucle de dependencias; antes 9). Cubren que la barra avanza sin informe del motor, que cada recurso
terminado la empuja, que el arrastre no infla el total, que el techo y el 100 %
sólo llegan cuando toca, el orden del plan (módulo al final, sin repetidos), que
un módulo inexistente no genera plan, que la línea no filtra enums, el formato
de reloj, los avisos de estancamiento, y que el manifiesto cubre las doce zonas
con todos sus recursos existentes y con el peso anotado.

Medición en la sesión (headless, C-04): `start_game -> true`, primer fotograma
al **7 %**, 14 de 14 a los 0,39 s, `Montando la zona` al 92 %, juego listo en
**2,1 s**. Antes: 19 % en el primer fotograma y la barra inmóvil en 60 %.

## 7. Qué se toca

| Archivo | Cambio |
| --- | --- |
| `scripts/ui/loading_progress.gd` | reescrito: `plan`, `plan_megabytes`, `plan_file_kb`, `manifest_entries`, `has_resource`, `value(done, total, elapsed, state, mounted)`, `step_name(state, done, total, mounted)`, `details(zone, module, done, total, MB, elapsed, stalled)`, `stall_hint`, `format_clock` |
| `scripts/core/main.gd` | `_begin_load_plan`, `_request_next_resource`, `_tick_loading`, `cancel_loading`; `_process` ya no estima progreso |
| `main.tscn` | panel de carga 30 px más alto, `Content/Hint` (aviso ámbar) y `Content/Cancel` (volver al menú) |
| `tools/gen_load_plan.gd`, `data/load_plan.json` | manifiesto de recursos por zona |
| `tools/build.sh` | genera el manifiesto antes de importar/exportar |
| `qa/run_suite.gd` | bloque de carga de 9 → 25 checks; versión 0.44.0 |
| `project.godot`, `export_presets.cfg` | versión 0.44.0 / código 44 |
