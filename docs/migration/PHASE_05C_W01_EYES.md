# Fase 5C · Sistema ocular W-01

Se exportó `w01_eyes.glb` con los siete ojos y 56 instancias visibles: cuenca, lecho, globo, iris, pupila, córnea y dos párpados por ojo. Las ocho mallas se comparten entre las siete jerarquías y el iris procedural está embebido.

El exportador conserva posiciones, escalas y cálculo de profundidad de los ojos secundarios desde `EyeSystem.ts`; las superficies de iris/pupila y párpados proceden de `OcularSurface.ts`. La pose de párpados exportada es abierta. Las venas tubulares, deformación de parpadeo y seguimiento ocular siguen pendientes como rig dinámico Godot y no se declaran terminados.

- Exportador: `tools/export_w01_eyes.py`
- Informe: `reports/export-w01-eyes.json`
- SHA-256: `deae609e2528c64dc1c8a6280456d5da84349d82253e9b636ff556e4b116c40e`
- Godot QA: 7 jerarquías oculares y 56 MeshInstance3D.
- Reproducibilidad: dos exportaciones idénticas byte a byte.
