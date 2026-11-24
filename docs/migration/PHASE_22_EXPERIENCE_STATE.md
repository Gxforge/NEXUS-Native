# Fase 22 · Estado de la experiencia y perfiles de calidad (P-8, segundo bloque)

**Fecha:** 24 de noviembre de 2026
**Fuentes web:** `src/scene/SceneExperience.ts` (1.443 líneas), `src/scene/protocols.ts`,
`src/scene/DisplayQuality.ts` y `src/scene/types.ts`.
**Destino:** `scripts/core/experience_state.gd`, `scripts/core/game_state.gd`,
`scripts/core/main.gd`, `scripts/ui/nexus_hud.gd` y `scripts/world/player.gd`.

## 1. Por qué se separa el contrato de la escena

`SceneExperience.ts` es, en su mayoría, montaje de three.js: escena, cámara, renderer,
composer, bloom, luces del entorno, audio del tránsito y bucle de animación. Nada de
eso es portable línea a línea a Godot, y el proyecto nativo ya tiene su propio
equivalente (zona activa, `WorldEnvironment`, cámara del jugador, HUD). Lo que sí es
un contrato verificable —y lo que la web usa para todo lo demás— es el objeto `nx`,
las reglas de las ranuras, los protocolos y los perfiles de calidad. Eso es lo que se
ha portado, y cada sistema nativo lo consume desde `GameState.experience`.

## 2. Contrato portado (`ExperienceState`)

| Web | Nativo |
|---|---|
| `nx.energy`, `battery`, `charged`, `analyzed`, `lamp`, `mode`, `cold`, `bait`, `blackout`, `grab`, `lost`, `notice` | mismos campos |
| `nx.slots[5]`, `slot`, `weapon`, `pending`, `target` | mismos campos |
| `protocols`: uv 32/8 s, gas 24/12 s, lure 12/5 s | `PROTOCOLS` |
| `spend(k)`: rejilla lista y energía suficiente | `spend(key)` |
| `action(k)`: uv (libera el agarre), gas (frío 7 s), lure/scan (modo), lamp | `action(key)` devuelve el mensaje de bitácora |
| `update`: recarga de energía 3,2/s y decaimiento de frío, señuelo y avisos | `update(delta)` |
| `bindSlot`: 0–4, mueve el objeto, rechaza la linterna y lo que no se tiene | `bind_slot` |
| `selectSlot`: guardas por `lost`/`grab`, retira el arma y sale del escáner | `select_slot` |
| `useSlot`: vacío, equipo en estación, armas, linterna, celda (+50 energía, batería 100), grabadora, credencial, vial | `use_slot(chosen)` |
| `partName` / `note` / `prompt()` / `reachable()` | `part_name`, `part_note`, `prompt_for`, `reach_for` |
| `renderDensity`, `setQuality` (sombras en high, brillo 0,13/0,19, vídeo 448/640/896) | `render_density`, `set_quality`, `shadows_enabled`, `bloom_enabled`, `bloom_strength`, `video_width` |
| FOV 68 en primera persona, 49 en vertical, 35 en orbital apaisado | `fov_for(mode, width, height)` |
| `localStorage` y detección de pantalla | `initial_quality(stored, touch, width)` |

## 3. Integración en el juego

- `GameState.experience` (nuevo, serializado en el guardado; `SAVE_VERSION` **9**),
  con `quality()`, `set_quality()` y `experience_snapshot()`.
- `main.gd`: `apply_quality_category()` aplica el perfil al motor —escala de render 3D
  (`low` = 0,85; el resto resolución nativa), sombras sólo en `high`, `glow` apagado en
  `low` con 0,13/0,19— y la acción **F3** recorre los tres perfiles mostrando el
  resultado en el HUD (`PERFIL · LOW/MEDIUM/HIGH`).
- `player.gd`: `apply_view_fov()` fija el FOV según el modo y la proporción, y se
  vuelve a aplicar al alternar la vista (V).

Nota de alcance: los topes de densidad superiores a 1 de la web (1,15/1,65 en
escritorio, 1,8/2,75 en táctil) no se aplican como sobremuestreo porque el objetivo del
proyecto es móvil; se quedan en resolución nativa. `render_density` sí devuelve el
valor exacto de la web y está cubierto por pruebas.

## 4. Pruebas

| Validador | Checks | Estado |
|---|---|---|
| `qa/validate_experience.gd` (nuevo) | **139** | ✅ 0 fallos |
| `qa/run_suite.gd` | **272** | ✅ 0 fallos (×2, más 2 ejecuciones previas) |
| `qa/validate_camera.gd` | 113 | ✅ |
| `qa/validate_displays.gd` | 89 | ✅ |
| `qa/validate_transit.gd` | 154 | ✅ |
| game_state · resume · vault · files · operations · bench · power · w01_ai | 17 · 8 · 53 · 33 · 77 · 51 · 45 · 66 | ✅ |
| `validate_zone_graph` · `validate_zone_traversal` | 303 · 255 | ✅ |

`validate_experience.gd` cubre protocolos (costes, recargas, energía insuficiente,
liberación del agarre, modos, linterna), ranuras (asignación, movimiento entre
ranuras, rechazos, guardas), uso (armas, celda, mensajes de equipo, guardas por
`pending`/`lost`), rótulos de piezas, avisos de interacción, alcances, los tres
perfiles con densidades y FOV, y la persistencia dentro de `GameState`.

También se ha estabilizado una prueba intermitente de la suite: «approach requests
door opening» leía `target_aperture` después de ceder frames, cuando la compuerta ya
podía haberse cerrado por proximidad. Ahora la petición se captura en el mismo instante
de `begin_approach`, sin ceder el control.

## 5. Lo que queda

- `App.tsx` (1.683 líneas): ajustes, perfiles gráficos en UI, pantalla de recuperación,
  avisos de calidad y controles táctiles. El HUD nativo ya tiene paneles de inventario,
  mapa, pausa y bitácora; falta la pantalla de ajustes completa.
- `SceneExperience.ts` en su vertiente de orquestación pura: eventos de zona, unión
  entre sistemas y ciclo de vida de la sesión (hoy lo cubren `main.gd`,
  `ZoneManager` y `SceneExperienceController`).
- `Visibility.ts` (57 líneas): culling por mamparos con geometría de la nave; se
  portará con el pase de geometría de alta fidelidad.
- `Touch.ts`: controles táctiles del HUD.

Paridad estimada tras esta fase: **≈ 52 %**.
