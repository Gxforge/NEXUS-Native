# Fase 36 · Los veinte brazos (`Tentacles.ts`)

Tercera pieza de la anatomía. La web construye cada tentáculo como un tubo de
**28 × 9 segmentos** que se reconstruye en cada fotograma sobre una curva de
Catmull-Rom. Aquí no hay nada que reconstruir: el exportador ya trae los veinte
brazos con su malla y sus ventosas separadas (`w01_tentacles.glb`: 20 nodos
`arm-<n>`, cada uno con `arm-<n>-mesh` y 4–5 `arm-<n>-sucker-<k>`). Lo que se
porta es **el contrato de movimiento**, no la geometría.

## Qué se ha portado y con qué sustitución

| `Tentacles.ts` | Nativo | Nota |
| --- | --- | --- |
| `controls[1…4]` desplazados `reach·extension` | escala del brazo sobre su propio eje (`1 + 0,1·agr + 0,34·ataque`) | el brazo rígido se estira, no se curva |
| `sway` + `twitch` sobre el vector `cross` | giro `0,23·sway + 0,065·twitch` | mismos períodos `0,56 + 0,11·(i mod 4)` s⁻¹ |
| balanceo `sin(t·1,65 + fase)` | cabeceo de igual período | |
| `targetPull = 0,05 + 0,15·agr + 0,28·ataque` | mezcla de la base hacia el operador | |
| `strike` en los brazos **2 y 3** | giro completo hacia el operador | `min(1, attackDrive·1,45)` |
| `scout` entre `[0,1,2,3,8,9]` | mismo producto escalar + `0,15·sin(t·0,47+i)` | |
| `edge()` + `max(0,075 + r·(1−along), y)` | recorte de la componente normal y apertura en horizontal | el brazo gira sobre su anclaje |
| pulso de ventosas `1 + 0,08·sin(t·3,1 + fase + along·5)` | escala de cada `arm-<n>-sucker-<k>` con su `along = 0,32 + k·0,115` | 87 ventosas |
| `userData.lash` | `lash_arm()` / `lash_all()`, disparado por el pulso UV | decae solo |
| `outerReach` / `touches` | `outer_reach()` / `touches()` | usados por la IA |

Las fases (`i·1,23`), las velocidades y el reparto de ventosas son idénticos, y
salen solos del nombre de cada nodo: **siete brazos con cinco ventosas y trece con
cuatro** (87 en total), exactamente el reparto de `index % 3 === 0`.

## Dos detalles que costaron

1. **La punta del brazo no está en el nodo.** La malla trae su propia
   transformación, así que la punta se calcula como `mesh.transform · extremo del
   AABB` sobre el eje largo. Sin eso, el giro hacia el operador no acertaba.
2. **El alcance incluye el estiramiento.** El recorte contra la malla de
   contención y el suelo se calcula con `longitud · extension`; con solo la
   longitud base, un brazo estirado al 137 % seguía atravesando el suelo.

## Resultado

| Validador | Checks |
| --- | --- |
| `qa/validate_w01_arms.gd` (nuevo) | 19 |
| `qa/run_suite.gd` (bloque `_validate_w01_arms`) | 8 |
| **Total del proyecto** | **366 checks en `run_suite`, 0 fallos** |

Captura nueva `reports/w01-arms.png` (vista de tres cuartos con `arms_pin =
"strike"`), además de las dos anteriores regeneradas. El gancho `arms_pin` de
`W01Actor` permite fijar la pose (`"strike"`, `"probe"`) sólo para capturas.

## Pendiente

- `Larva.ts`: las larvas de los tres vasos de H–01 siguen sin comportamiento
  (burbujas, latido y giro). Es lo único que queda del bloque de anatomía.
- Los brazos son rígidos: la ondulación por segmentos de la web necesita mallas
  segmentadas, que el `.glb` no trae.
