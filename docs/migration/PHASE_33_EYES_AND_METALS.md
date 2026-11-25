# Fase 33 · Ojos de W–01 y entorno metálico

Puerto de `EyeSystem.ts` y `OcularSurface.ts` sobre el `.glb` original del ojo
(`assets/generated/w01_eyes.glb`, siete ojos de ocho mallas cada uno). Nada se
reconstruye con primitivas: se reutilizan la cuenca, el lecho, el globo, el iris
con su textura, la pupila, la córnea y los dos párpados exportados.

## Lo que se ha portado

| Pieza de la web | Constante | Nativo |
| --- | --- | --- |
| `EyeSystem.update` · seguimiento | yaw `0,29` / `0,16`, pitch `0,18` / `0,12` | `W01Eyes.update`: el ojo principal recorre el doble que los seis secundarios, con interpolación suave |
| Pupila | `0,88 + 0,17·sin(t·0,77 + fase) − agresión·0,12` | acotada a `0,64–1,08`, eje x × `0,72`, × `0,3` si el ojo recibe luz |
| Fases | `[0 · 0,4 · 1,1 · 2,2 · 0,8 · 1,9 · 2,6]` | latido desfasado por ojo |
| Parpadeo | `0,2 s` cada `2,2–5,6 s`, primero a los `2,7 s` | `blink_timer` con reparto aleatorio; cada ojo parpadea por su cuenta |
| Pulso UV | cierre total `1,1 s` | `flash()` desde `apply_uv()`; los siete se cierran y se reabren |
| `OcularSurface.Lid` | rejilla `33 × 8`, reposo `0,94` / `−1,1`, cierre `−0,19 ∓ 0,02` | `W01Eyes.LidNode`: `ArrayMesh` reconstruida con `SurfaceTool` cada vez que el párpado cambia más de 0,002 rad |

## Tres problemas de render resueltos por el camino

1. **Párpados invisibles.** El material exportado trae `cull_mode = CULL_BACK` y la
   rejilla de la web se pinta a doble cara (`mat.side = DoubleSide`). El párpado
   reconstruido se recortaba entero: se duplica el material con
   `CULL_DISABLED`.
2. **Párpados negros.** La malla generada no llevaba normales — sin ellas la
   iluminación no existe. Ahora se construye con `SurfaceTool` y
   `generate_normals()`, y el párpado recupera el gris rosado de la piel.
3. **Carne metálica.** Tentáculos y párpados salen del exportador con
   `metallic = 1,0`; en la web eso funcionaba por el mapa de entorno, aquí dejaba
   el organismo en silueta negra. `scripts/entities/w01_materials.gd`
   (`W01Materials.soften`) rebaja a `0,22` todo metal por encima de `0,6` y pone
   un suelo de aspereza `0,42`, cacheando por material para no duplicar recursos.

Además, `main.tscn` gana un `ProceduralSkyMaterial` con `reflected_light_source
= SKY`: sin cielo, cualquier `metallic` se queda sin nada que reflejar y el arte
del laboratorio (859 mallas a `0,40|0,48` y 392 a `0,00|1,00`) se ve negro.

## Resultado

| Validador | Checks |
| --- | --- |
| `qa/validate_w01_eyes.gd` (nuevo) | 18 |
| `qa/run_suite.gd` (bloque `_validate_w01_eyes`) | 7 |
| **Total del proyecto** | **343 checks en `run_suite`, 0 fallos** |

Capturas regeneradas: `reports/eyes-open.png`, `eyes-blink.png` (parpadeo a
mitad), `eyes-flash.png` (pulso UV con los siete cerrados), `eyes-bare.png` (sin
párpados, para ver el lecho), hoja `reports/phase33-eyes.png`, primer plano
`reports/w01-c04-first-look.png` y las diez vistas `reports/ingame-*.png` con el
cielo nuevo.

## Pendiente de este bloque

- `Head.ts`: cáscara de 80 × 48 con radios `2,02 / 2,04 / 1,99` y la deformación
  `1 + 0,021(1−f)(sin(8su+4c)cos(9sv) + 0,5sin(17c+3sv))`, morfo
  `f = exp(−6(t−0,405))` para el grito.
- `Breath.ts`: aire con paso banda Q `0,64` a 920/540 Hz, ganancia
  `(0,14 + 0,56·max(0,−sin))·fatiga·|sin|` y zumbido triangular de 88 + carga·32 Hz.
- Dinámica por segmentos de `Tentacles.ts` y venas del iris en la córnea.
