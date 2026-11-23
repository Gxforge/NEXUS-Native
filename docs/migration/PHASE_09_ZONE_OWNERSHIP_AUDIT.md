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

La categoría compartida exige clasificación jerárquica adicional; no puede repartirse por centro geométrico sin riesgo de romper mecanismos. El exportador ahora conserva nombres para las raíces funcionales. La segunda auditoría identificó:

- `Transit`: 498 mallas compartidas.
- `ZoneGates`: 56 mallas de conexiones.
- `Vault`: 29 mallas fuera de un único límite.
- `Facility`: 11 mallas comunes.
- `Operations`: 9 mallas comunes.
- 202 mallas todavía anónimas.
- 37 mallas cuya AABB cruza más de una zona.

`Transit` y `ZoneGates` no deben cortarse como estáticos por centro: requieren escenas controladoras con transferencia/estado. Las 37 AABB multizona deben revisarse como conexiones o geometría fronteriza.

La auditoría detallada de las 202 mallas anónimas determinó:

- 169 no intersectan ningún volumen interno: pertenecen a corredores, iluminación longitudinal o infraestructura común.
- 5 tocan únicamente A-01 y 7 únicamente C-04; son candidatas a propiedad local tras revisar su ancestro.
- 4 tocan únicamente Vigilancia.
- 5 cruzan A-01/C-04.
- 4 cruzan Electricidad/Vigilancia.
- 3 cruzan A-01/Vigilancia y 3 C-04/Electricidad.
- 2 abarcan A-01, C-04, Electricidad y Vigilancia.

Cada rama anónima registra ahora AABB, número de mallas y zonas intersectadas en el JSON. El script `qa/audit_zone_partition.gd` regenera `reports/zone-partition-audit.json` y no modifica el GLB fuente.
