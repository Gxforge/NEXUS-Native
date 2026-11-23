# Fase 2B · Puerta móvil A/01

## Fuente preservada

Una hoja definida en `src/scene/Sectors.ts` (`f4e1e81`) contiene panel de acero y tres bandas. Se instancia dos veces. Centros cerrados: ±1,10 m; abiertos: ±3,27 m; recorrido por hoja: 2,17 m; altura del centro: 2,15 m.

## Implementación

- `manifests/migration/a01_door_leaf.json`: cuatro cajas, tres materiales, pivote y recorrido.
- `assets/generated/a01_door_leaf.glb`: GLB determinista, 5.296 bytes, SHA-256 `04076072...cef787`.
- `scripts/zones/sector_door.gd`: amortiguación exponencial 5,0 equivalente al `MathUtils.damp` fuente.
- `scenes/validation/a01_portal_assembly.tscn`: marco, dos `AnimatableBody3D`, visuales, colisiones y sockets.
- Colisión de cada hoja: `2.19 × 4.3 × 0.35 m`, sincronizada con su cuerpo móvil.

## QA

30/30 comprobaciones headless: GLB, materiales, AABB, pivotes cerrados, dos colisiones móviles, recorrido 2,17 m, apertura libre de semiancho 2,175 m y regresión de streaming.

Se ejecutó además Godot con pantalla virtual real, Vulkan Forward Mobile y llvmpipe. Se generaron capturas 1280×720:

- `reports/a01-portal-closed.png`
- `reports/a01-portal-open.png`

Las capturas fueron inspeccionadas: dintel, marco, dos hojas, bandas y apertura se renderizan; 189.318 píxeles cambian entre estados. Esto valida render Godot y movimiento, pero **no es todavía comparación visual A/B con Three.js**. La iluminación es exclusiva del laboratorio de validación.

## Pendiente

Añadir sensor de proximidad con las dimensiones originales, integrar esta asamblea en el corte vertical C-04/A-01 y producir una referencia Three.js de la misma cámara antes de declarar paridad gráfica.