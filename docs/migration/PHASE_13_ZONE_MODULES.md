# Fase 13 · Doce módulos enlazados

Se completó la ampliación del juego nativo de las dos zonas del corte vertical a las doce zonas documentadas en `LABORATORY_ZONES.md`: catálogo, conexiones, sockets, geometría estructural, colisión, luces y streaming real en ambas direcciones. Sigue pendiente el contenido interactivo completo de cada módulo (bóveda, lectores, CCTV, archivos, cápsula de Transit, etc.).

## Fuente única de verdad

`tools/generate_zone_modules.py` genera de forma determinista, desde una sola tabla de datos:

1. `manifests/migration/<id>_structural_shell.json` — cajas estructurales, material, huecos de puerta, sockets y bounds esperados.
2. `assets/generated/<id>_structural_shell.glb` — shell visual (reutiliza `tools/export_nexus_geometry.py`).
3. `zones/zone_*.tscn` — escena de las diez zonas nuevas (`ZoneRoot`, `StructuralShell`, portales, `DoorSockets`, luces y pickups).
4. `data/zone_graph.json` — grafo de runtime con las 12 zonas, sus límites y las 11 conexiones con socket de origen y de destino.

`C-04` y `A-01` conservan escenas mantenidas a mano (W-01, linterna, sockets heredados), pero su hull, manifiesto y colisión también se regeneran desde la misma tabla.

```bash
python3 tools/generate_zone_modules.py --scenes
```

## Sistema de coordenadas

Se mantiene el marco del corte anterior: `local = world + (9, 0, 14)`, origen común en el portal A/01 mundial `(-9, 0, -14)`. Los manifiestos y `data/zone_graph.json` guardan coordenadas mundiales de `Environment.ts`; el registro en `ZoneCatalog` las desplaza al marco de escena para que el jugador persistente pueda consultarlas con `ZoneDefinition.contains_position()`.

## Zonas

| Zona | Escena | Límite mundial (x0,z0)-(x1,z1) | Altura | Conexiones |
|---|---|---|---|---|
| `c04` | `zone_c04_shell.tscn` | (-36,-14)-(36,70) | 9,2 m | a01, b02, surveillance, electrical, transit_hub |
| `a01` | `zone_a01_shell.tscn` | (-36,-38)-(0,-14) | 9,2 m | c04 |
| `b02` | `zone_b02_turbines.tscn` | (0,-38)-(36,-14) | 9,2 m | c04, v03_gallery |
| `surveillance` | `zone_surveillance.tscn` | (-36,52,2)-(-17,3,70) | 9,2 m | c04 |
| `electrical` | `zone_electrical.tscn` | (17,3,44,2)-(36,70) | 9,2 m | c04 |
| `transit_hub` | `zone_transit_hub.tscn` | (-36,70)-(36,96) | 9,2 m | c04, transit_road, transit_rail |
| `transit_road` | `zone_transit_road.tscn` | (-21,96)-(6,1,2096) | 6,0 m | transit_hub |
| `transit_rail` | `zone_transit_rail.tscn` | (6,1,96)-(21,2096) | 6,0 m | transit_hub |
| `v03_gallery` | `zone_v03_gallery.tscn` | (14,-96)-(22,-38) | 4,4 m | b02, h01, d02, v03_cryo |
| `h01` | `zone_h01_hydraulics.tscn` | (-36,-96)-(14,-38) | 9,2 m | v03_gallery |
| `d02` | `zone_d02_records.tscn` | (22,-96)-(37,-38) | 9,2 m | v03_gallery |
| `v03_cryo` | `zone_v03_cryotheque.tscn` | (4,-114)-(36,-96) | 7,0 m | v03_gallery |

`surveillance` y `electrical` son salas alojadas dentro del volumen de `c04`; el manifiesto de C-04 incluye los tabiques con sus huecos y el grafo declara esa relación en `hull_of`, que la QA usa como única excepción permitida al test de solapes.

## Puertas y sockets

- Cada umbral es una instancia del ensamblado real `scenes/validation/a01_portal_assembly.tscn` (`StreamingSectorDoor`), con apertura motorizada, sensor de proximidad y umbral de cruce.
- Convención de socket: el socket de la zona X en su puerta hacia Y se llama `from_<Y>`. El portal de X apunta a `from_<X>` dentro de Y. El par heredado C-04/A-01 conserva `to_a01` / `from_c04`.
- El socket queda 1,6 m dentro de la zona y orientado hacia el interior (yaw del portal + 180°), así que al cruzar el jugador aparece dentro del módulo mirando hacia él.
- `ZoneManager` transfiere al jugador al `socket_transform()` del módulo destino y libera el módulo anterior; el paquete `PackedScene` no se retiene en la caché.

## Catálogo y HUD

- `scripts/core/main.gd` registra zonas y conexiones leyendo `data/zone_graph.json`; ya no hay definiciones duplicadas en código.
- `ZoneCatalog` expone `zone_ids()`, `connection_ids()` y `connections_of(zone_id)`.
- `ZoneDefinition` guarda nombre, escena, socket de entrada, vecinos, footprint y altura.
- El panel de mapa del HUD (`scripts/ui/zone_map_view.gd`) dibuja un esquema de los doce módulos, resalta el actual y sus vecinos, y comprime los corredores largos de Transit para que el núcleo siga legible. La cabecera del HUD muestra el nombre del módulo actual.

## Defectos encontrados y corregidos durante la ampliación

- **Umbral perdido**: el cruce se evaluaba solo en `body_entered` del umbral. Un jugador en carrera llegaba antes de que las hojas terminasen de abrir, el evento se consumía y el portal quedaba incruzable desde ese lado. `StreamingSectorDoor` ahora reevalúa el umbral en `_physics_process` mientras haya cuerpos solapados.
- **Suelo atravesable**: las losas estructurales tenían 7 cm y el personaje podía perder el contacto y caer fuera del módulo. Los doce suelos pasan a 40 cm de espesor con la cara superior en `y = 0`.

## Contenido incluido

- Luces locales por módulo, con repetición cada 20/120 m en galería y corredores largos.
- Pickups de proxy sobre la escena `field_flashlight.tscn` con `item_id`/`display_name` propios: celda en B-02, celda de respaldo en Electricidad, muestra V-03 en la galería, bitácora en D-02 y credencial V-03 en la crioteca.
- Colisión generada desde el mismo manifiesto que la malla (`StructuralShell`), sin divergencia visual/física.

## QA

Todo se ejecutó con Godot 4.4.1 en `/home/user/NEXUS-Native`.

| Suite | Resultado |
|---|---|
| `qa/validate_zone_graph.gd` (nueva) | 303/303 — 12 zonas, 11 conexiones, identidad de `ZoneRoot`, manifiesto y colisión por módulo, AABB contra manifiesto, socket de entrada, sockets por conexión, portales en el umbral compartido, socket destino correcto y ausencia de solapes no declarados |
| `qa/validate_zone_traversal.gd` (nueva) | 255/255 — recorrido completo del grafo (22 cruces por los portales reales, ambos sentidos de cada enlace) con llegada al socket, una sola zona activa, liberación del módulo y `PackedScene` fuera de caché, más un cruce físico caminando contra el umbral (sensor de proximidad, apertura de hojas y umbral) |
| `qa/run_suite.gd` | 148/148 — incluye validación estructural de las 12 zonas, panel de mapa con 12 módulos y cruce C-04↔A-01 |
| `qa/validate_zone_ownership.gd` | 13/13 — `ZoneOwnershipPolicy.BOUNDS` es espejo de `data/zone_graph.json` |
| `qa/validate_game_state.gd` / `validate_resume.gd` | 17/17 y 8/8 |
| Resto de validadores (W-01, contactos, efectos, source batch) | pasan |

Las pruebas son headless; no sustituyen una build de plataforma ni una revisión visual de paridad.

Evidencia gráfica (Vulkan Forward Mobile sobre Xvfb, 960×540): `reports/zone-c04.png`, `zone-a01.png`, `zone-b02.png`, `zone-surveillance.png`, `zone-electrical.png`, `zone-transit_hub.png`, `zone-transit_road.png`, `zone-transit_rail.png`, `zone-v03_gallery.png`, `zone-h01.png`, `zone-d02.png` y `zone-v03_cryo.png`. El runner gráfico aislado sigue avisando de un `RefCounted` restante al cerrar, igual que en fases anteriores.

## Pendiente

- Contenido interactivo real por módulo: bóveda V-03 (lector, fases, celdas, analizador), matriz CCTV, cuadro eléctrico con 12 alimentadores y extractores, archivo óptico D-02, vasos y purga de H-01, cápsula/asientos/freno de Transit.
- Sustituir los proxies de pickup por mallas propias (`recorder`, `card`, `sample`, `cell`).
- Condiciones de acceso (credencial V-03, energía, compuertas trabadas) sobre `StreamingSectorDoor`.
- Geometría detallada de mobiliario desde `laboratory_all_sectors.glb`: la partición por zona del GLB combinado sigue siendo la vía prevista para el pase de alta fidelidad.
- Paridad visual, audio, VFX y comparación A/B con la fuente Three.js.
