# Paridad Web v15.1 → NEXUS Native: qué falta

**Fecha:** 24 de noviembre de 2026
**Fuente web:** `Gxforge/nexus-w01-versiones`, etiqueta `nexus-v15.1` (`1ae0401`), 13.407 líneas en `src/scene`, `src/vehicle`, `App.tsx` y `DepotMap.tsx`.
**Destino:** `Gxforge/NEXUS-Native`, Godot 4.4.1, 12 zonas modulares y 2.690 líneas de GDScript de juego.

Este documento compara módulo a módulo lo que existe en la web con lo que existe
en Godot, marca lo que falta y ordena el trabajo restante. Se apoya en el código
de los dos repositorios, no en la documentación de fases (que va por detrás).

## Leyenda

| Marca | Significado |
|---|---|
| ✅ | portado con pruebas automáticas |
| 🟡 | parcial: hay una pieza nativa, pero el contrato de la web no está completo |
| ❌ | no existe todavía en Godot |

## 1. Sistemas de juego

| Módulo web | Líneas | Equivalente nativo | Estado | Qué falta concretamente |
|---|---|---|---|---|
| `Power.ts` | 106 | `scripts/systems/power_grid.gd` | ✅ | Nada funcional. Doce alimentadores, límites de 14/28 kW, picos, temperatura, estrés, disparo y rearme con las mismas constantes; 44 checks en `qa/validate_power_grid.gd`. Falta sólo el panel de interruptores en 3D (va con `Operations.ts`). |
| `Vault.ts` | 737 | `scripts/zones/vault_module.gd` + `vault_station.gd` + `scripts/world/vault_door_rig.gd` | ✅ | Lógica completa (secuencia de 22 s, estaciones, cajones por proximidad, objetos y persistencia; 53 checks) y geometría animada: el disco, la corona, los ocho cerrojos, los cuatro pistones y los brazos de `vault.glb`, identificados por geometría y movidos con las mismas fases que la web (24 checks en `qa/validate_vault_door.gd`). Falta el audio de la secuencia. |
| `Files.ts` | 173 | `scripts/zones/files_module.gd` + `files_tray.gd` | ✅ | Diez bandejas con giro propio, tope por proximidad, seis expedientes idénticos a la web y lectura a la bitácora sin duplicados; 33 checks. Falta la geometría del folio y el lector a pantalla completa. |
| `Operations.ts` | 943 | `scripts/systems/operations_panel.gd` + `operations_console.gd` | ✅ | Cuadro eléctrico y CCTV: 19 circuitos, selección zona/derivación, interruptores, eco, contadores, informe maestro de cinco páginas, iluminación y las diez cámaras; 77 checks. Falta la geometría, las pantallas y el vídeo real. |
| `Infrastructure.ts` | 440 | `zones/zone_*.tscn` (carcasas) | 🟡 | Volumen y colisión. `light_zone`/`area` del cuadro ya cubren la lectura por zona; faltan pasillos, anexos y rótulos. |
| `Workshop.ts` | 448 | `bench_cycle.gd` (bancos) · pendiente el resto | 🟡 | Los dos bancos técnicos están portados; faltan los tres vasos de observación (`Pods`), instrumentos, tambores y luminarias. |
| `BenchCycle.ts` | 216 | `scripts/systems/bench_cycle.gd` + `bench_station.gd` | ✅ | Cuna (8 s, 18 kW) y analizador (10 s, 9 kW) con la misma elección de equipo, etapas, corte por red y consumo real en `PowerGrid.machines`; 51 checks. Falta la geometría y las pantallas. |
| `Transit.ts` | 669 | `scripts/systems/capsule_transit.gd` + `transit_console.gd` | ✅ | Andenes 102/2042 sobre el eje 15, cierre de puertas, traslado con smoothstep de 10 s, freno de retención, compuerta por proximidad, cinco asientos, transferencia del carro en 4 s, `canStand`/`inside`, carteles y persistencia; 154 checks en `qa/validate_transit.gd`. El coche de vía ya tiene su geometría (`vehicle.glb`) y la suspensión de cuatro apoyos (fase 39, 51 checks). Falta el audio de puertas. |
| `vehicle/VehiclePhysics.ts` | 263 | `scripts/systems/vehicle_physics.gd` | ✅ | Mismo contrato numérico (masa 1260, 4100 N de motor, punta 49, turbo −24/s, integridad por impacto, marchas 1–6, paso fijo 1/120 s) con integrador propio en vez de cannon-es; incluido en los 154 checks. |
| `vehicle/*` (otros 4 archivos, 659 líneas) | 659 | `scripts/world/vehicle_rig.gd` + `vehicle_physics.gd` + `cockpit_display.gd` + `vehicle_audio.gd` | 🟡 | `VehicleModel.ts`: cuerpo y cuatro ruedas de `vehicle.glb` con suspensión, actitud y rodadura (51 checks). `Cockpit.ts`: panel de 384 × 144 en el salpicadero con velocidad, marcha, régimen, energía y barra, repintado sólo al cambiar (fase 40). `VehicleAudio.ts`: motor de sierra, rodadura de triángulo, turbo de seno y ruido con paso bajo, con las ganancias de la web. Falta `Perspectives.ts` (las cuatro cámaras) y el mapa de reflejos de las tiras de luz. |
| `Monster.ts` + `MonsterAI.ts` + `Attention.ts` + `FieldSense.ts` | 438 | `monster_ai.gd` + `monster_attention.gd` + `field_memory.gd` + `w01_actor.gd` | ✅ | Estados, agresividad, ataque y recarga, cono de visión, audición por pasos, memoria de 5,4 s, intenciones, patrulla, señuelo, repliegue y malla de contención con memoria por sector; 66 checks. Faltan agarre/daño y la colisión física de la malla. |
| `Tentacles.ts` + `Breath.ts` + `Larva.ts` | 704 | `scripts/entities/w01_arms.gd`, `scripts/systems/breath_audio.gd` | 🟡 | `Tentacles`: los veinte brazos del `.glb` con fases `i·1,23`, velocidad `0,56 + 0,11·(i mod 4)`, estiramiento `1 + 0,1·agr + 0,34·ataque`, giro hacia el operador, alcance de los brazos 2 y 3, `scout` entre seis brazos, latigazo del pulso UV, pulso de las 87 ventosas y recorte contra suelo y malla de contención. `Breath`: aire y zumbido sintetizados (540 ↔ 920 Hz, 88 + 32·carga Hz). `Larva`: la larva original de `workshop_pods.glb` con sus 8/9/10 tentáculos y su ojo animados con las fórmulas de la web, el latido del corazón y las 48 burbujas por vaso (44 checks en `qa/validate_larva.gd`). Falta la textura de iris. |
| `EyeSystem.ts` + `OcularSurface.ts` + `Head.ts` | 449 | `scripts/entities/w01_eyes.gd`, `scripts/entities/w01_jaw.gd` | 🟢 | `EyeSystem`: siete ojos con seguimiento (yaw 0,29 / 0,16 · pitch 0,18 / 0,12), pupila `0,88 + 0,17·sin(t·0,77 + fase) − agresión·0,12` acotada a 0,64–1,08, escala de reposo y cierre por pulso UV (1,1 s). `OcularSurface`: los catorce párpados se reconstruyen con la rejilla 33 × 8 (reposo 0,94 / −1,1; cierre −0,19 ∓ 0,02) y parpadeo de 0,2 s cada 2,2–5,6 s. `Head`: cáscara, encía y garganta del `.glb` con su *blend shape* de apertura amortiguada a 16 s⁻¹ y los 26 dientes desplazados entre el ancla de reposo y la abierta (`0,34·sin a`). Falta la ondulación de la cáscara ligada al grito y el peso de grito que la mueve (`Breath.ts`). |
| `Survey.ts` | 168 | `scripts/interaction/survey_system.gd` + `survey_highlight.gd` | ✅ | Raycast, resaltado, registro y bitácora persistente. Falta el contenido de expedientes completo (depende de `Files.ts`). |
| `Contacts.ts` | 176 | `contact_query_3d.gd` + `contact_fx_3d.gd` | ✅ | Consultas y VFX de contacto con el sujeto. |
| `Glove.ts` + `Loadout.ts` + `Instruments.ts` | 590 | `scripts/world/first_person_rig.gd` + `player.gd` | ✅ | Rig original de `touch_rig_assets.glb` colgado de la cámara: seis poses de guante (`press`/`drawer`/`grip`/`flat`/`round`/`box`), los tres instrumentos ópticos, el guante de linterna de la mano izquierda, cuatro mangas y dos codos, con balanceo, alcance de 1,06 s, retroceso y encendido por protocolo; 36 checks en `qa/validate_first_person.gd`. Falta el agarre de objetos reales (depende de `Touch.ts`). |
| `Displays.ts` + `TelemetryScreen.ts` + `SceneExperience`-feed | 228 | `phosphor_display.gd` + `telemetry_model.gd` + `screen_surface.gd` + `wall_screen.gd` + `telemetry_feed.gd` | ✅ | Panel de fósforo 640×320 con traza de 72 muestras y `CAM 04` 1024×576 con búfer de 75 filas, tres páginas, series y pies de estado; montadas en `zone_electrical` con datos vivos de `PowerGrid` y W–01; 89 checks. Falta el vídeo real de CCTV. |
| `Environment.ts` + `PortalLight.ts` + `materials.ts` + `protocols.ts` | 646 | `OperationsPanel` (iluminación) | 🟡 | Iluminación por zona y protocolos básicos. Faltan materiales dinámicos. |
| `Effects.ts` | 80 | `scripts/effects/contact_fx_3d.gd` | 🟡 | Sólo el efecto de contacto. |
| `CameraController.ts` | 364 | `scripts/world/camera_controller.gd` + `player.gd` | ✅ | Órbita con amortiguación del 6 % por frame, límites 3,1–13 m y polar 0,38–π·0,49, primera persona con aguante (14/s, espera 1,05 s, rearme 26), cadencia, balanceo de cabeza, agachado de −0,44 m, corona de escape y entrada del vehículo; 113 checks. Faltan las sacudidas y las transiciones entre zonas. |
| `DisplayQuality.ts` | 34 | `experience_state.gd` + `main.gd` | ✅ | Presets low/medium/high con densidad de render, sombras, glow y tamaño de vídeo; aplicados al viewport (F3). |
| `Visibility.ts` | 57 | — | ❌ | Culling por mamparos; se portará con la geometría de alta fidelidad. |
| `ZoneCache.ts` | 98 | `zone_manager.gd` + `PHASE_10B` | ✅ | Streaming con precarga, descarga y política de propiedad. |
| `ZoneGates.ts` | 93 | `sector_door.gd`, `streaming_sector_door.gd` | ✅ | Compuertas con umbral y bloqueo durante la transición. |
| `Sectors.ts` | 608 | `zones/` (12 escenas) + `data/zone_graph.json` + `scripts/zones/zone_dressing.gd` | 🟡 | Las 12 zonas existen como módulo con colisión y portales y, desde la fase 24, con mobiliario y rótulos de sector dentro del volumen real de cada módulo (95 checks). Faltan la lógica interior de cada zona y el atrezzo GLB de alta fidelidad. |
| `Infrastructure.ts` (primitivas) + `Workshop.ts` (`Pods`, `drum`, `ring`, `luminaire`, `cabinet`) | 1.173 | `scripts/world/build_kit.gd` + `scripts/zones/zone_dressing.gd` | 🟡 | Portadas las primitivas `block`/`drum`/`ring`/`bar`/`plaque`/`luminaire`/`cabinet` con la paleta exacta (`METAL #53686c`, `GLOW #72f9e5`, `AMBER #ffae69`, `BRONZE #a16f45`), los tres vasos de observación con larvas, las cuatro turbinas con aspas y rejillas, la puerta de la bóveda con ocho pestillos, el muro CCTV de seis cámaras, los nueve archivadores, la malla de contención de C–04, los arcos de la galería y las doce vitrinas de la crioteca. Faltan las animaciones (burbujas, latido de la larva, giro de aspas) y el atrezzo restante. |
| `SceneExperience.ts` (escena y render) | ~1.180 | `main.gd` + `zone_manager.gd` + `scene_experience_controller.gd` + `experience_state.gd` | 🟡 | Su contrato de estado está portado (fila anterior); lo que queda es el montaje de escena/render, que en Godot ya lo cubren la zona activa y `WorldEnvironment`. Faltan los eventos de sesión y el ciclo de vida unificado. |
| Contrato de `SceneExperience.ts` + `protocols.ts` + `DisplayQuality.ts` | ~260 (lógica) | `scripts/core/experience_state.gd` | ✅ | Estado `nx` completo (energía, batería, protocolos, modos, ranuras, armas, frío, señuelo, agarre, pérdida), `spend`/`action`, `bindSlot`/`selectSlot`/`useSlot`, rótulos y notas de piezas, avisos y alcances, y perfiles de calidad (densidad, FOV, sombras, brillo, vídeo); 139 checks. Aplicado al motor desde `main.gd` (F3) y persistido en el guardado (`SAVE_VERSION` 9). |
| `App.tsx` | 1.683 | `scripts/core/session_state.gd` + `scripts/ui/nexus_hud.gd` + `scripts/ui/loading_progress.gd` | 🟡 | Portada la lógica de interfaz: ajustes persistidos (calidad, sensibilidad 0,35–2,5, consejos), detección de dispositivo, navegación de paneles con las reglas de cierre de la web, pausa/reanudación/reinicio, consejos de una sola vez, bitácora de 60 entradas y textos de ayuda; el HUD incorpora los paneles `cfg` y `log` con selector de calidad, deslizador, manuales y reinicio (95 checks); el arranque tiene portada con arte propio y pantalla de carga con progreso compuesto y datos reales del módulo (9 checks). Faltan los controles táctiles de `Touch.ts` y la pantalla de instalación/PWA, que no tiene equivalente nativo. |
| `DepotMap.tsx` | 142 | `scripts/ui/zone_map_view.gd` | 🟡 | Mapa con 12 módulos y conexiones. Falta el estado de puertas/energía en el mapa. |

## 2. Resumen cuantitativo

- **Portado con pruebas:** IA y percepción de W-01, red eléctrica, cuadro eléctrico + CCTV, bóveda V-03 (lógica), archivo D-02, bancos de carga y analizador, encuesta/raycast, contactos, caché de zonas, compuertas, streaming y persistencia de partida.
- **Parcial:** W-01 (dinámica de tentáculos y agarre), sectores/mobiliario, HUD, mapa, materiales.
- Desde la fase 32 el techo de las doce zonas, las taquillas, los paneles murales y las pantallas son piezas originales de `laboratory_all_sectors.glb`, `display.glb` y `telemetry_screen.glb`.
- **Sin empezar:** perspectivas de cámara del coche, `Visibility.ts`, `Touch.ts` en dispositivo real, audio ambiental y distribución.
- Desde la fase 37 la bóveda V–03 tiene su geometría animada y el arranque (menú + carga) muestra arte e información propios; desde la 38 la anatomía de W–01 (`EyeSystem`, `OcularSurface`, `Head`, `Tentacles`, `Breath`, `Larva`) está completa, desde la 39 el coche de vía se ve y se apoya en sus cuatro ruedas y desde la 40 lleva instrumentos y motor sonoro.
- Del total de ~13.400 líneas web, la parte con equivalente nativo verificable ronda el **84 %**; el resto son sistemas por migrar.

## 3. Hoja de ruta propuesta

Cada fase termina con validador headless propio y una entrada en
`docs/migration/`; ninguna se marca como hecha sin pruebas en `qa/`.

| Fase | Contenido | Depende de | Criterio de aceptación |
|---|---|---|---|
| **P-1** ✅ | Red eléctrica (`Power.ts`) | — | `validate_power_grid.gd` 44/44 · hecho |
| **P-2** ✅ | Bóveda V-03 (`Vault.ts`): cerradura, estaciones, cajones, objetos | P-1 | `validate_vault.gd` 53/53 + 10 checks en la suite · hecho |
| **P-3** ✅ | Archivos D-02 (`Files.ts`): gavetas, expedientes, lector | P-2 | `validate_files.gd` 33/33 + 8 checks en la suite · hecho |
| **P-4** ✅ | Cuadro eléctrico + CCTV (`Operations.ts`, `Infrastructure.ts`) | P-1 | `validate_operations.gd` 77/77 + 11 checks en la suite · hecho |
| **P-5** ✅ | Bancos de H-01 y B-02 (`BenchCycle.ts`, `Workshop.ts`) | P-1 | `validate_bench_cycle.gd` 51/51 + 11 checks en la suite · hecho (faltan los vasos, que son visuales) |
| **P-6** ✅ | IA de W-01 (`MonsterAI`, `Attention`, `FieldSense`) | — | `validate_w01_ai.gd` 66/66 + 10 checks en la suite · hecho (falta agarre/daño y tentáculos dinámicos) |
| **P-7** ✅ | Tránsito y vehículo (`Transit.ts`, `vehicle/VehiclePhysics.ts`) | — | `validate_transit.gd` 154/154 + 21 checks en la suite · hecho (faltan geometría, cabina y audio) |
| **P-8** 🟡 | UI y orquestación (`App.tsx`, `SceneExperience.ts`, `CameraController`, `DisplayQuality`, `Visibility`) | — | Vista (113), pantallas (89), estado/perfiles (139) y ajustes/paneles/bitácora (95) hechos · faltan los controles táctiles y `Visibility` |
| **P-9** | Distribución | P-8 | Presets Windows/Android, builds reproducibles y QA en dispositivo real |

## 4. Orden recomendado y por qué

1. **V-03 primero**: es el único módulo que en la web combina cerradura, inventario,
   cajones y consumo eléctrico; al cerrarlo se valida el patrón de "módulo
   interactivo completo" que después se repite en H-01, B-02 y D-02.
2. ~~**D-02 después**~~ hecho en la fase 16: mismas estaciones y expedientes en
   la bitácora; sigue el lector a pantalla completa.
3. ~~**Cuadro eléctrico + CCTV**~~ hecho en la fase 17: la red ya se opera desde
   la zona técnica y el selector de cámaras funciona.
4. ~~**IA de W-01**~~ hecha en la fase 19: el sujeto percibe, recuerda y ataca;
   quedan agarre/daño, tentáculos dinámicos y respiración sonora.

## 5. Estado de las pruebas hoy

| Prueba | Resultado |
|---|---|
| `qa/run_suite.gd` | **207/207** (175 archivo → 186 cuadro → 197 bancos → 207 IA) |
| `qa/validate_zone_graph.gd` | 303/303 |
| `qa/validate_zone_traversal.gd` | 255/255 |
| `qa/validate_power_grid.gd` | 45/45 |
| `qa/validate_vault.gd` | 53/53 |
| `qa/validate_files.gd` | 33/33 |
| `qa/validate_operations.gd` | 77/77 |
| `qa/validate_bench_cycle.gd` | 51/51 |
| `qa/validate_w01_ai.gd` | 66/66 (nuevo) |
| `qa/validate_game_state.gd` | 17/17 (incluye la red en el guardado) |
| `qa/validate_resume.gd` | 8/8 |
| `qa/validate_contacts_survey.gd` | 9/9 |
