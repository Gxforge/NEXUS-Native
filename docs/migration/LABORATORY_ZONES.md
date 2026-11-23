# Laboratorio modular por zonas

División derivada de `Sectors.zone()`, `ZoneGates`, `PortalLight` y la geometría fuente.

| ID / escena | Límite | Contenido exclusivo |
|---|---|---|
| `c04/zone_c04_containment.tscn` | `z>-14`, núcleo | campo de 24 lados, W-01 cuando corresponda, luces |
| `a01/zone_a01_archive.tscn` | `-38<z<-14`, `x<0` | archivos, gavetas, folios y banco |
| `b02/zone_b02_turbines.tscn` | `-38<z<-14`, `x>=0` | turbinas, lector V-03, diagnóstico/rearme |
| `surveillance/zone_surveillance.tscn` | `x<-17.3`, `z>52.2` | matriz de seis monitores y controles |
| `electrical/zone_electrical.tscn` | `x>17.3`, `z>44.2` | 12 alimentadores, medidores y 4 extractores |
| `v03_gallery/zone_v03_gallery.tscn` | `-96<z<-38`, `14<=x<=22` | corredor axial y conexiones |
| `h01/zone_h01_hydraulics.tscn` | `-96<z<-38`, `x<14` | tres vasos, larvas y purga |
| `d02/zone_d02_records.tscn` | `-96<z<-38`, `x>22` | archivo óptico e incidencias |
| `v03_cryo/zone_v03_cryotheque.tscn` | `z<-96` | custodia, módulos, analizador y muestra |
| `transit_hub/zone_transit_hub.tscn` | umbral `z=70` | L01, andén y transferencia |
| `transit_road/zone_transit_road.tscn` | `z>70`, `x<=6.1` | carretera 2000 m y muro terminal |
| `transit_rail/zone_transit_rail.tscn` | `z>70`, `x>6.1` | vía, andenes, cápsula y asientos |

Transit puede agruparse durante el primer puerto de fidelidad, pero mantendrá subescenas descargables para Android.

## Conexiones comprobadas

```mermaid
graph TD
 C04[C-04] -- "A/01 z=-14 x=-9" --> A01[A-01]
 C04 -- "B/02 z=-14 x=9" --> B02[B-02]
 C04 -- "(-26,52.2)" --> SUR[Vigilancia]
 C04 -- "(26,44.2)" --> ELE[Electricidad]
 B02 -- "bóveda z=-38 x=18" --> GAL[Galería V-03]
 GAL -- "(14,-62)" --> H01[H-01]
 GAL -- "(22,-82)" --> D02[D-02]
 GAL -- "(18,-96)" --> CRY[Crioteca]
 C04 -- "L01 z=70" --> HUB[Transit hub]
 HUB --> ROAD[Carretera]
 HUB --> RAIL[Cápsula]
```

Cada zona contiene `ZoneRoot`, visuales, StaticBody3D, luces/audio local, InteractionRegistry y DoorSockets. Nunca Player, cámara global, GameState o ZoneManager.