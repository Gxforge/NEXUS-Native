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
| `Vault.ts` | 737 | `scripts/zones/vault_module.gd` + `vault_station.gd` | ✅ | Lógica completa (secuencia de 22 s, estaciones, cajones por proximidad, objetos y persistencia; 53 checks). Falta sólo la geometría del disco y los pistones, que llega con el pase de alta fidelidad. |
| `Files.ts` | 173 | `scripts/zones/files_module.gd` + `files_tray.gd` | ✅ | Diez bandejas con giro propio, tope por proximidad, seis expedientes idénticos a la web y lectura a la bitácora sin duplicados; 33 checks. Falta la geometría del folio y el lector a pantalla completa. |
| `Operations.ts` | 943 | `scripts/systems/operations_panel.gd` + `operations_console.gd` | ✅ | Cuadro eléctrico y CCTV: 19 circuitos, selección zona/derivación, interruptores, eco, contadores, informe maestro de cinco páginas, iluminación y las diez cámaras; 77 checks. Falta la geometría, las pantallas y el vídeo real. |
| `Infrastructure.ts` | 440 | `zones/zone_*.tscn` (carcasas) | 🟡 | Volumen y colisión. `light_zone`/`area` del cuadro ya cubren la lectura por zona; faltan pasillos, anexos y rótulos. |
| `Workshop.ts` | 448 | `bench_cycle.gd` (bancos) · pendiente el resto | 🟡 | Los dos bancos técnicos están portados; faltan los tres vasos de observación (`Pods`), instrumentos, tambores y luminarias. |
| `BenchCycle.ts` | 216 | `scripts/systems/bench_cycle.gd` + `bench_station.gd` | ✅ | Cuna (8 s, 18 kW) y analizador (10 s, 9 kW) con la misma elección de equipo, etapas, corte por red y consumo real en `PowerGrid.machines`; 51 checks. Falta la geometría y las pantallas. |
| `Transit.ts` | 669 | shells `transit_hub/road/rail` | ❌ | Cápsula, llamada, carga, freno, postura sentada, `use()` y `step()` del vehículo. |
| `vehicle/*` (5 archivos) | 922 | — | ❌ | Modelo, física de cuatro apoyos, audio, cabina y perspectivas del coche. |
| `Monster.ts` + `MonsterAI.ts` + `Attention.ts` + `FieldSense.ts` | 438 | `monster_ai.gd` + `monster_attention.gd` + `field_memory.gd` + `w01_actor.gd` | ✅ | Estados, agresividad, ataque y recarga, cono de visión, audición por pasos, memoria de 5,4 s, intenciones, patrulla, señuelo, repliegue y malla de contención con memoria por sector; 66 checks. Faltan agarre/daño y la colisión física de la malla. |
| `Tentacles.ts` + `Breath.ts` + `Larva.ts` | 704 | GLB de tentáculos | 🟡 | Los 20 tentáculos se ven, pero no hay dinámica por segmentos, agarre ni larvas con comportamiento. |
| `EyeSystem.ts` + `OcularSurface.ts` + `Head.ts` | 449 | GLB de ojos | 🟡 | Seguimiento ocular limitado. Faltan parpadeo, iris reactivo y orientación de cabeza acoplada a la IA. |
| `Survey.ts` | 168 | `scripts/interaction/survey_system.gd` + `survey_highlight.gd` | ✅ | Raycast, resaltado, registro y bitácora persistente. Falta el contenido de expedientes completo (depende de `Files.ts`). |
| `Contacts.ts` | 176 | `contact_query_3d.gd` + `contact_fx_3d.gd` | ✅ | Consultas y VFX de contacto con el sujeto. |
| `Glove.ts` + `Loadout.ts` + `Instruments.ts` | 590 | `scripts/world/player.gd` | 🟡 | Linterna, energía y ranuras existen. Faltan guante con animación, instrumentos de mano y carga de herramientas como en la web. |
| `Environment.ts` + `Displays.ts` + `TelemetryScreen.ts` + `PortalLight.ts` + `materials.ts` + `protocols.ts` | 874 | — | ❌ | Iluminación por zona, pantallas Canvas (hay que rehacerlas en Godot), telemetría y materiales dinámicos. |
| `Effects.ts` | 80 | `scripts/effects/contact_fx_3d.gd` | 🟡 | Sólo el efecto de contacto. |
| `CameraController.ts` | 364 | `player.gd` | 🟡 | Mouse-look y primera persona. Faltan cámara orbital, cambios de perspectiva y sacudidas. |
| `Visibility.ts` + `DisplayQuality.ts` | 148 | — | ❌ | Perfiles de calidad y visibilidad por distancia. |
| `ZoneCache.ts` | 98 | `zone_manager.gd` + `PHASE_10B` | ✅ | Streaming con precarga, descarga y política de propiedad. |
| `ZoneGates.ts` | 93 | `sector_door.gd`, `streaming_sector_door.gd` | ✅ | Compuertas con umbral y bloqueo durante la transición. |
| `Sectors.ts` | 608 | `zones/` (12 escenas) + `data/zone_graph.json` | 🟡 | Las 12 zonas existen como módulo con colisión y portales; falta el mobiliario y la lógica interior de cada una. |
| `SceneExperience.ts` | 1.443 | `scripts/core/scene_experience_controller.gd` (47) | ❌ | Orquestación: estado por zona, ciclo de vida, eventos y unión entre sistemas. |
| `App.tsx` | 1.683 | `scripts/ui/nexus_hud.gd` (620) | 🟡 | HUD, inventario, ranuras, paneles de bitácora/mapa y controles táctiles. Faltan ajustes, perfiles gráficos, pantalla de recuperación y avisos de calidad. |
| `DepotMap.tsx` | 142 | `scripts/ui/zone_map_view.gd` | 🟡 | Mapa con 12 módulos y conexiones. Falta el estado de puertas/energía en el mapa. |

## 2. Resumen cuantitativo

- **Portado con pruebas:** IA y percepción de W-01, red eléctrica, cuadro eléctrico + CCTV, bóveda V-03 (lógica), archivo D-02, bancos de carga y analizador, encuesta/raycast, contactos, caché de zonas, compuertas, streaming y persistencia de partida.
- **Parcial:** W-01 (dinámica de tentáculos y agarre), jugador y carga, sectores/mobiliario, HUD, mapa, materiales.
- **Sin empezar:** vasos de observación, tránsito/vehículo, pantallas y orquestación/cuadro eléctrico, taller, tránsito y vehículo, IA del sujeto, pantallas y telemetría, perfiles de calidad, orquestación de experiencias y distribución.
- Del total de ~13.400 líneas web, la parte con equivalente nativo verificable ronda el **35 %**; el resto son sistemas por migrar.

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
| **P-7** | Tránsito y vehículo (`Transit.ts`, `vehicle/*`) | P-1 | Cápsula con llamada/carga/freno y coche con solver de cuatro apoyos |
| **P-8** | UI y orquestación (`App.tsx`, `SceneExperience.ts`, `CameraController`, `DisplayQuality`, `Visibility`) | P-2…P-7 | Ajustes, perfiles de calidad, mapa con estado y pantalla de recuperación |
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
