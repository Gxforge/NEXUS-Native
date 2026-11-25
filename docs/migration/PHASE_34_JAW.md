# Fase 34 · Mandíbula y dentadura de W–01

Segunda mitad del bloque de anatomía: `Head.ts` sobre el `.glb` original. La
cáscara, la encía y la garganta ya venían del exportador **con su morph de
apertura**, y las 26 piezas dentales venían colocadas en la pose de reposo, pero
sin ninguna animación. Lo que faltaba era el movimiento de los dientes y la
amortiguación de la apertura.

## Lo portado

| Pieza de la web | Constante | Nativo |
| --- | --- | --- |
| `Head.update` · amortiguación | `MathUtils.damp(drive, w, 16, dt)` | `W01Jaw.DRIVE_RATE = 16`: la apertura arranca suave y tarda ~0,3 s en llegar |
| Ancla de reposo / abierta | `ring(a, 0,65, o)` con `height = 0,26 + o·(0,46 ó 0,7)` | `open = rest + (0, −0,34·sin a, +0,095·sin a)` |
| Ángulo de cada diente | `a = (0,12 + (i + 0,27·lado)/12,7 · 0,92)·π + lado·π` | mismo cálculo a partir del nombre `Tooth_<lado>_<i>` del `.glb` |
| Morph de la cabeza | `morphTargetInfluences[0] = drive` | `_set_mouth(jaw.update(delta, opening))` sobre `Head`, `Gum` y `Throat` |
| Reparto | 13 dientes por arco, dos arcos | 26 piezas `Tooth_0_00…12` y `Tooth_1_00…12` localizadas en `Core/W01_Core` |

Los dientes de las comisuras apenas se mueven (`sin a ≈ 0`), que es justo lo que
hace la web: el arco se abre en el centro del morro y no en las esquinas.

## Resultado

| Validador | Checks |
| --- | --- |
| `qa/validate_w01_jaw.gd` (nuevo) | 9 |
| `qa/run_suite.gd` (bloque `_validate_w01_jaw`) | 6 |
| **Total del proyecto** | **349 checks en `run_suite`, 0 fallos** |

Capturas: `reports/w01-maw.png` (morro abierto al 100 % con `jaw.pin(1.0)`) y
`reports/w01-c04-first-look.png` regenerada, ambas en C–04 con el HUD real.

## Pendiente

- Ondulación de la cáscara: `1 + 0,021(1−f)(sin(8su+4c)cos(9sv) + 0,5sin(17c+3sv))`
  con `f = exp(−6(t−0,405))`, que hoy aplica el propio morph del `.glb`.
- El peso de grito que alimenta `drive` llega con `Breath.ts` (fase siguiente):
  aire con paso banda Q `0,64` a 920/540 Hz, ganancia
  `(0,14 + 0,56·max(0,−sin))·fatiga·|sin|` y zumbido triangular de 88 + carga·32 Hz.
