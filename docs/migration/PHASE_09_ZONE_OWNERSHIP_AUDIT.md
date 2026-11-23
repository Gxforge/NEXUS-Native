# Fase 9A · Auditoría de pertenencia por zona

Se aplicaron directamente los ocho límites espaciales originales de `ZoneCache.ts` sobre las AABB mundiales importadas del laboratorio integral. Este paso no divide todavía el GLB: establece una línea base verificable antes de preservar jerarquías y pivotes.

| Zona | Mallas | Vértices |
|---|---:|---:|
| A-01 | 366 | 273.770 |
| C-04 | 365 | 89.933 |
| Crioteca | 48 | 26.621 |
| Electricidad | 96 | 37.132 |
| Galería | 74 | 25.068 |
| Registros | 132 | 31.560 |
| Turbinas | 212 | 1.258.542 |
| Vigilancia | 267 | 201.262 |
| Compartido/sin asignar | 805 | 308.839 |

La categoría compartida exige clasificación jerárquica adicional; no puede repartirse por centro geométrico sin riesgo de romper mecanismos. El script `qa/audit_zone_partition.gd` regenera `reports/zone-partition-audit.json` y no modifica el GLB fuente.
