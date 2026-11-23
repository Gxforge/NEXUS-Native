# Inventario de migración

## Fuente verificada

- Revisión: `nexus-v15.1`, commit `f4e1e81`.
- Exportación Git: 81 archivos, 863.469 bytes sin dependencias generadas.
- Código: 13.540 líneas TypeScript/TSX y 48 módulos de aplicación.
- Runtime: Three.js 0.187, React 19.2.6, cannon-es 0.20.0, Barlow Condensed, IBM Plex Mono y Lucide.
- Archivos de recursos: iconos PWA y `src/assets/lettering.json`. El contenido 3D, muchas texturas, pantallas y el audio se generan proceduralmente.

## Sistemas

| Dominio | Fuente | Contenido comprobado |
|---|---|---|
| Orquestación | `SceneExperience.ts` | bucle, render, interacción, protocolos y estado |
| Mundo | `Environment`, `Sectors`, `Infrastructure` | laboratorio, particiones, campo C-04, luces y suelo |
| Zonas | `ZoneGates`, `ZoneCache`, `Visibility`, `PortalLight` | puertas, culling y activación |
| W-01 | `Monster`, `Head`, `EyeSystem`, `OcularSurface`, `Tentacles` | cuerpo, 7 ojos, boca/dientes y 20 tentáculos |
| IA | `MonsterAI`, `Attention`, `FieldSense` | estados, visión/oído, memoria y barrera |
| Bóveda | `Vault` | corona, cerrojos, pistones, hoja, lector y estiba |
| Técnica | `Operations`, `Power`, `Workshop`, `BenchCycle` | CCTV, red, instrumentos, análisis/carga |
| Archivo | `Files` | archivadores, gavetas, folios y documentos |
| Transit | `Transit` | L01, carretera, andenes, cápsula y carro |
| Vehículo | `vehicle/*` | modelo procedural, RaycastVehicle, HUD, cámaras y audio |
| Jugador | `CameraController`, `Operator`, `Touch`, `Glove` | primera persona, órbita, cuerpo/manos y fatiga |
| VFX/audio | `Effects`, `Contacts`, `Breath`, `Survey` | polvo, impactos, niebla, respiración y barrido |
| UI | `App`, `DepotMap`, `Joystick`, `VehicleHUD` | HUD, archivo, inventario, mapa, táctil y pausa |

## Contenido confirmado

W-01 con 20 tentáculos y 7 ojos; C-04, A-01, B-02, Vigilancia, Electricidad, Galería V-03, H-01, D-02, Crioteca y Transit; cinco compuertas sectoriales, dos puertas de mamparo, bóveda y L01; diez cámaras y seis monitores; 12 alimentadores y cuatro extractores; UV, criogénico, linterna, tarjeta, celda, bitácora y muestra; cápsula ferroviaria y carro.

El audio de respiración/maquinaria y vehículo es sintetizado con Web Audio; no hay archivos de audio. La física combina colisión XZ especializada, contacto de W-01 con barrera y cannon-es para el carro.

## Destino Godot

`nexus-native.zip` solo contiene `project.godot` (Godot 4.4, renderer Mobile), icono y cachés `.godot`. No contiene `.tscn`, `.gd`, assets 3D, autoloads, InputMap, pruebas ni presets. Estado real: **semilla vacía; todo el juego no migrado**.