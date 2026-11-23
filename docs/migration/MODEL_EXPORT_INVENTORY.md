# Inventario procedural de modelos NEXUS 15.1

Fuente inmutable: `f4e1e819a9c783374e79dbc99cde4597099aba11`. Este documento se genera; el JSON conserva hashes y líneas de procedencia.

## Regla de exportación

Cada familia se exportará a GLB con materiales PBR, texturas PNG deterministas, pivotes y jerarquía. Las piezas dinámicas conservarán malla base y datos necesarios para reconstruir morphs, skin/spline o instancing en Godot; no se congelarán como una aproximación estática.

| Archivo fuente | Constructores geométricos | BufferGeometry custom | Texturas | Riesgo |
|---|---:|---:|---:|---|
| `src/scene/BenchCycle.ts` | custom/indirect | 0 | — | static |
| `src/scene/Contacts.ts` | custom/indirect | 0 | CanvasTexture×1 | dynamic, random |
| `src/scene/Displays.ts` | PlaneGeometry×1 | 0 | CanvasTexture×1 | static |
| `src/scene/Effects.ts` | BufferGeometry×1 | 1 | CanvasTexture×1 | dynamic, random |
| `src/scene/Environment.ts` | BoxGeometry×1, PlaneGeometry×1 | 0 | — | static |
| `src/scene/EyeSystem.ts` | SphereGeometry×3, TorusGeometry×1, TubeGeometry×1 | 0 | — | dynamic, random |
| `src/scene/Glove.ts` | BufferGeometry×1, CylinderGeometry×1, SphereGeometry×1 | 1 | — | dynamic |
| `src/scene/Head.ts` | BufferGeometry×1, ConeGeometry×1 | 1 | — | dynamic |
| `src/scene/Infrastructure.ts` | BoxGeometry×1, BufferGeometry×1, TextGeometry×1 | 1 | — | dynamic |
| `src/scene/Instruments.ts` | CylinderGeometry×1, PlaneGeometry×1, RoundedBoxGeometry×1 | 0 | CanvasTexture×1 | static |
| `src/scene/Larva.ts` | BufferGeometry×1, CircleGeometry×1, SphereGeometry×2, TubeGeometry×1 | 1 | — | dynamic |
| `src/scene/Monster.ts` | CircleGeometry×1, SphereGeometry×1 | 0 | CanvasTexture×1 | dynamic |
| `src/scene/OcularSurface.ts` | BufferGeometry×1, PlaneGeometry×1 | 1 | — | dynamic |
| `src/scene/Operations.ts` | PlaneGeometry×3 | 0 | CanvasTexture×2 | static |
| `src/scene/Operator.ts` | SphereGeometry×1 | 0 | — | static |
| `src/scene/SceneExperience.ts` | SphereGeometry×2 | 0 | — | static |
| `src/scene/Sectors.ts` | BoxGeometry×1, CylinderGeometry×2, ExtrudeGeometry×1, TorusGeometry×1 | 0 | — | dynamic |
| `src/scene/Survey.ts` | custom/indirect | 0 | — | static |
| `src/scene/TelemetryScreen.ts` | PlaneGeometry×1 | 0 | CanvasTexture×1 | static |
| `src/scene/Tentacles.ts` | BufferGeometry×1, SphereGeometry×1, TorusGeometry×1 | 1 | — | dynamic |
| `src/scene/Touch.ts` | LatheGeometry×1, SphereGeometry×1 | 0 | CanvasTexture×1 | static |
| `src/scene/Transit.ts` | BufferGeometry×2, PlaneGeometry×1 | 2 | CanvasTexture×1 | dynamic |
| `src/scene/Vault.ts` | BoxGeometry×1, CylinderGeometry×1, ExtrudeGeometry×2, PlaneGeometry×1, TorusGeometry×2 | 0 | CanvasTexture×1 | dynamic |
| `src/scene/Workshop.ts` | BufferGeometry×1, CylinderGeometry×1, ExtrudeGeometry×1, TorusGeometry×2, TubeGeometry×1 | 1 | — | dynamic |
| `src/scene/ZoneCache.ts` | custom/indirect | 0 | — | static |
| `src/scene/materials.ts` | custom/indirect | 0 | CanvasTexture×3 | dynamic, random |
| `src/vehicle/Cockpit.ts` | PlaneGeometry×1 | 0 | CanvasTexture×2 | static |
| `src/vehicle/VehicleModel.ts` | BufferGeometry×1, ConeGeometry×1, CylinderGeometry×2, TorusGeometry×2 | 1 | — | dynamic |

## Bloques de trabajo

1. Arquitectura estática por zona: Sectors, Infrastructure, Workshop y Vault.
2. Utilería funcional: Instruments, Files, Transit y VehicleModel.
3. Entidades orgánicas: Operator, Larva y THE WATCHER.
4. W-01 dinámico: Head/OcularSurface morphs, siete ojos y veinte tentáculos con ventosas.
5. Texturas procedurales: piel, iris, suelo y canvases funcionales, usando semillas registradas durante exportación.

Los conteos son sitios constructores del código, no el número final de instancias en runtime. Ese número se registrará en el manifest de cada familia.
