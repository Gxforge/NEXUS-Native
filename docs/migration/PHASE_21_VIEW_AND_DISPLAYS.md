# Fase 21 · Vista, pantallas y telemetría (P-8, primer bloque)

**Fecha:** 24 de noviembre de 2026
**Fuentes web:** `src/scene/CameraController.ts` (364 líneas), `src/scene/Displays.ts` (71) y
`src/scene/TelemetryScreen.ts` (157).
**Destino:** `scripts/world/camera_controller.gd`, `scripts/ui/phosphor_display.gd`,
`scripts/ui/telemetry_model.gd`, `scripts/ui/screen_surface.gd`, `scripts/ui/wall_screen.gd`,
`scripts/ui/telemetry_feed.gd` y `zones/zone_electrical.tscn`.

## 1. Vista del explorador (`CameraController.ts`)

La web tiene dos modos: órbita (por defecto, con `OrbitControls`) y primera persona
con aguante, cadencia y balanceo de cabeza. El port reproduce el contrato numérico
completo sin depender de `OrbitControls`:

| Contrato de la web | Nativo |
|---|---|
| Órbita: objetivo `(0, 2,6, 22)`, cámara `(0,8; 3,25; 32,3)` | `ORBIT_TARGET`, `ORBIT_CAMERA` |
| Amortiguación 0,06 · distancias 3,1–13 · polar 0,38–π·0,49 | `orbit_rotate`/`orbit_zoom` + `update_orbit` (6 % por frame a 60 Hz) |
| Velocidad de giro 0,48 y de zoom 0,7 | `ORBIT_ROTATE_SPEED`, `ORBIT_ZOOM_SPEED` |
| Primera persona en `(1,8; 1,72; 42)` con 0,12 de inclinación | `set_mode("first-person")` |
| Mirada limitada a ±1,45 rad | `PITCH_LIMIT` |
| Marcha 4,8 m/s · carrera 8,25 m/s · amortiguación 18 | `update_walk` |
| Aguante: −14/s, espera 1,05 s, +8/+13 por segundo, rearme a 26 | mismas constantes |
| Cadencia 4/12 y balanceo `0,035` en carrera `+ 0,027·(1−aguante/100)` | `bob_offset()` |
| Agachado −0,44 m · mirada a 10 m | `CROUCH_DROP`, `look_target` |
| `escape()`: corona de 6,8 m en seis ángulos | `escape()` |
| `transitInput()` y `faceRail()` | `transit_input()`, `face_rail()` |

**Integración con el jugador:** `player.gd` gana `view: CameraController`, la acción
`toggle_view` (V) y `crouch` (Ctrl). La primera persona sigue siendo el modo inicial
del proyecto nativo (la web arranca en órbita, que aquí queda como vista de conjunto
al pulsar V, con arrastre para girar y rueda para acercar). El balanceo de cabeza y
el agachado se aplican sobre la altura base de la cámara (1,72 m del nodo), y al
agacharse no se pierde la altura del ojo.

## 2. Pantallas (`Displays.ts` y `TelemetryScreen.ts`)

La web pinta en canvas y usa la textura en un plano; en Godot se hace lo mismo con
`SubViewport` + `ViewportTexture` y `_draw()`:

- `phosphor_display.gd`: modelo del panel local (640×320, título/valor/subtítulo,
  traza de 72 muestras a 8,4 px, rejilla de 16×4 y barra de fracción).
- `telemetry_model.gd`: modelo de `CAM 04` (1024×576, muestreo cada 0,35 s, búfer de
  75 filas de cinco columnas, tres páginas «ESTACIÓN DE CAMPO», «BUS · DIAGNÓSTICO» y
  «RASTREO · W–01», formatos de integridad/distancia/carga, series `[0,1,2]` y `[3,4,2]`,
  líneas de estado, rastreo, intención y tiempo).
- `screen_surface.gd`: dibujo común de ambas pantallas (fondos, textos, rejillas y
  polilíneas de las tres series) con la tipografía por defecto del motor.
- `wall_screen.gd`: nodo 3D que monta ventana, superficie, cuadro de 2,36 × 1,328 m
  (0,9 × 0,45 m en el panel de fósforo) y material emisivo sin sombreado.
- `telemetry_feed.gd`: alimenta la pantalla desde `GameState` (`PowerGrid.snapshot()`
  y el actor W–01: estado, intención, agresividad, distancia y contactos).

`zone_electrical.tscn` monta las dos pantallas (`Displays/Cam04` y `Displays/Phosphor`)
y su `TelemetryFeed`. En la captura `reports/displays-cam04.png` se ven las dos con
datos reales de simulación: búfer `40/75`, `subject.state = AGGRESSIVE`, `hits = 6`,
`track.xyz` e `intent`, más el panel de fósforo a la derecha.

## 3. Pruebas

| Validador | Checks | Estado |
|---|---|---|
| `qa/validate_camera.gd` (nuevo) | **113** | ✅ 0 fallos |
| `qa/validate_displays.gd` (nuevo) | **89** | ✅ 0 fallos |
| `qa/run_suite.gd` | **251** | ✅ 0 fallos (×2 ejecuciones limpias) |
| `qa/validate_transit.gd` | 154 | ✅ |
| game_state · resume · vault · files · operations · bench · power | 17 · 8 · 53 · 33 · 77 · 51 · 45 | ✅ |
| `validate_w01_ai` · `validate_w01_actor` · `validate_contacts_survey` | 66 · 6 · 9 | ✅ |
| `validate_zone_graph` · `validate_zone_traversal` | 303 · 255 | ✅ |

`validate_camera.gd` comprueba constantes, posición inicial de la órbita, la
amortiguación del 6 % por frame, los topes de distancia y de ángulo polar, el giro
que conserva la distancia, el seguimiento del objetivo, el modo primera persona
(posición, inclinación, límites de mirada, dirección y `look_target`), agachado,
balanceo por fatiga y por carrera, gasto/espera/recarga/rearme del aguante, la
colisión por pasos de 0,12 m, la corona de escape, la entrada del vehículo, la
persistencia y la integración con `NexusPlayer`.

`validate_displays.gd` cubre los dos modelos (historiales de 72 y 75, muestreo,
páginas, formatos, series, búfer, reinicio al retroceder el tiempo, persistencia) y
los nodos 3D (resolución de ventana, tamaño del cuadro, material sin sombreado y
emisivo, repintado, cambio de página, instantáneas).

## 4. Lo que queda de P-8

- `SceneExperience.ts` (1.443 líneas): orquestación por zona, ciclo de vida y unión
  entre sistemas; hoy sólo existe un controlador de 47 líneas.
- `App.tsx` (1.683): ajustes, perfiles gráficos, pantalla de recuperación y avisos.
- `DisplayQuality.ts` + `Visibility.ts` (148): perfiles de calidad y visibilidad por
  distancia.
- `CameraController`: sacudidas y transiciones de cámara entre zonas.

Siguiente bloque recomendado: **`SceneExperience.ts` + `App.tsx`** (ajustes y
orquestación), que es lo único que impide cerrar la paridad de interfaz.
