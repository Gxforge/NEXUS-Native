# Fase 2A · Pipeline procedural y pieza patrón

**Alcance:** validar una ruta reproducible TypeScript/manifest → GLB → importación Godot. No constituye migración masiva de A-01.

## Pieza seleccionada

Marco del portal A/01 situado en la fuente en `x=-9`, `z=-14`, definido por `src/scene/Sectors.ts` del commit `f4e1e81`.

Se conservaron ocho cajas fuente: dintel, travesaño, dos postes y cuatro tiras amarillas; tres familias de material: concrete, trim y yellow. El manifest usa coordenadas locales respecto al origen mundial del portal y metros como unidad.

## Archivos

- `manifests/migration/a01_portal_frame.json`: procedencia, dimensiones, materiales y AABB esperada.
- `tools/export_nexus_geometry.py`: exportador GLB 2.0 determinista sin dependencias externas.
- `assets/generated/a01_portal_frame.glb`: pieza generada.
- `scenes/validation/a01_portal_frame_validation.tscn`: escena de importación.
- `reports/export-a01-portal.json`: hash y métricas.

## Reproducibilidad

Dos ejecuciones independientes produjeron bytes idénticos:

`b1064b599127b3be8253844ac1190b134209b4440e9f58982ff6c977c29f468a`

El GLB mide 8.208 bytes, contiene ocho cajas agrupadas en un mesh y tres superficies/materiales.

## Validación Godot 4.4.1

- Importación GLB: OK.
- Escena de validación: OK.
- Un único `MeshInstance3D` agrupado: OK.
- Tres superficies de material: OK.
- AABB importada `Vector3(4.9, 9.2, 1.1)`: coincide con la fuente.
- Suite completa: 22/22 comprobaciones.

La validación ejecutada es estructural/headless. No se afirma todavía paridad gráfica; falta captura en renderer gráfico y comparación contra NEXUS 15.1.

## Próximo corte

Extender el manifest a la puerta móvil A/01 con sus dos hojas y pivotes, añadir colisiones estáticas/animables separadas y realizar la primera comparación gráfica antes de escalar el pipeline al resto de A-01.