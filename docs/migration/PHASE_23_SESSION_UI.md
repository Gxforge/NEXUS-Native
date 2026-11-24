# Fase 23 · Ajustes, paneles y bitácora de sesión (P-8, tercer bloque)

**Fecha:** 24 de noviembre de 2026
**Fuente web:** `src/App.tsx` (1.683 líneas).
**Destino:** `scripts/core/session_state.gd`, `scripts/ui/nexus_hud.gd`,
`scripts/core/game_state.gd`, `scripts/core/main.gd` y `scripts/world/player.gd`.

## 1. Qué se ha portado

`App.tsx` es React sobre el motor: estado de React, `useEffect`, clases CSS y JSX.
Lo que se ha portado es su **lógica de interfaz**, separada del dibujado y con las
mismas reglas:

| Web | Nativo (`SessionState`) |
|---|---|
| `quality` con `localStorage["nx-quality"]` | `quality` + `set_quality`, persistido en el guardado |
| `sensitivity` (0,35–2,5, paso 0,05, `nx-look`) | `set_sensitivity`, `nudge_sensitivity`, `look_scale()` (aplicado a la mirada) |
| `guides` (`nx-guides`) | `guides` + `set_guides` |
| Detección `Android / Táctil / PC` | `detect_device(android, touch, coarse)` y `device_label()` |
| `panel` (`inventory`, `map`, `database`, `document`, `archive`, `pause`, `cfg`, `log`) | `open_panel`, `close_panel`, `PANELS`, `DATA_PANELS` |
| `pause()` / `resume()` / `reset()` | `pause()`, `resume()`, `reset_session()` |
| `setActive(!paused && !panel)` | `active()` |
| `view(v)` con bitácora | `set_view(first_person)` |
| Consejos de una sola vez (550 ms, 5,95 s, `nx-tip-<id>`) | `tip_id`, `tip_text`, `update(delta, nx)`, `mark_tip`, `dismiss_tip` |
| `log()` con hora y 60 entradas | `log_entry`, `log_lines`, `LOG_LIMIT` |
| Textos de ayuda y manual | `input_hint()`, `manuals()` |
| Error de contexto gráfico | `set_error()` (detiene la simulación) |

## 2. Interfaz nativa

- **Panel de pausa** ampliado: «AJUSTAR CONTROLES» y «BITÁCORA DE SESIÓN», además de
  continuar, guardar y salir.
- **Panel de ajustes** (`cfg`): casilla «Mostrar consejos una sola vez», selector de
  calidad (BAJA / MEDIA / ALTA), etiqueta con el perfil activo y la resolución 3D,
  barra de **sensibilidad de cámara** con su valor, textos de ayuda del dispositivo,
  los tres manuales y «REINICIAR ENCUENTRO».
- **Panel de bitácora** (`log`): las 60 entradas con marca de hora.
- La pausa se mantiene al abrir ajustes o bitácora y, al cerrarlos, se vuelve al panel
  de pausa (como `closePanel()` en la web), no al juego.
- Los ajustes se aplican en vivo: calidad → `main.apply_quality_category()` (escala de
  render, sombras, glow), sensibilidad → `player.apply_look()` y etiqueta del HUD,
  consejos → `dismiss_tip()`.
- **Consejos de una sola vez**: `main._process` los dispara al entrar en primera
  persona (0,55 s de espera, 5,95 s en pantalla, una vez por identificador).
- **Reiniciar encuentro**: estado de la experiencia a cero, sujeto en `WATCHING` con
  agresividad 0,2, guardado y tránsito al módulo actual.
- La vista (V) queda registrada en la bitácora de sesión.

`GameState` gana `session` con `session_snapshot()` y `log_event()`, y el guardado sube a
`SAVE_VERSION` **10** (ajustes, consejos mostrados y dispositivo).

## 3. Pruebas

| Validador | Checks | Estado |
|---|---|---|
| `qa/validate_session.gd` (nuevo) | **95** | ✅ 0 fallos |
| `qa/run_suite.gd` | **300** | ✅ 0 fallos (×2 ejecuciones limpias) |
| `qa/validate_experience.gd` | 139 | ✅ |
| `qa/validate_camera.gd` · `validate_displays.gd` · `validate_transit.gd` | 113 · 89 · 154 | ✅ |
| game_state · resume · vault · files · operations · bench · power · w01_ai | 17 · 8 · 53 · 33 · 77 · 51 · 45 · 66 | ✅ |
| `validate_zone_graph` · `validate_zone_traversal` | 303 · 255 | ✅ |

`validate_session.gd` cubre sensibilidad (recorte, paso, mirada), calidad, consejos
(activados/desactivados), detección de dispositivo, navegación de paneles con sus cinco
casos de cierre, pausa bloqueada por error, reinicio de sesión, consejos (retardo,
duración, una sola vez, aplazados por avisos o paneles), bitácora (60 entradas, orden,
marca de hora) y persistencia dentro de `GameState`.

La suite añade 25 comprobaciones nuevas, entre ellas las del panel real: presencia del
botón de ajustes en la pausa, del deslizador de sensibilidad, de la casilla de consejos,
del botón de reinicio, del panel de bitácora, y que los ajustes mantienen la simulación
detenida y devuelven a la pausa al cerrarse.

## 4. Captura

`reports/panel-settings.png`: panel de ajustes real sobre la partida en C–04, con la
etiqueta «PERFIL · HIGH» del HUD al fondo.

## 5. Lo que queda

- `Touch.ts`: joystick fijo, botón de huellas y los iconos táctiles de escáner, ficha y
  arsenal (el proyecto es móvil, así que es el siguiente bloque natural de UI).
- Pantalla de instalación/PWA y avisos de conexión de `App.tsx` (sin equivalente nativo
  por diseño: aquí no hay service worker).
- `Visibility.ts` y la geometría de alta fidelidad.

Paridad estimada tras esta fase: **≈ 57 %**.
