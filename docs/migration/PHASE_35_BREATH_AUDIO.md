# Fase 35 · Aire y zumbido procedurales (`Breath.ts`)

La web no carga ni un solo archivo de sonido: sintetiza el aire del operador y el
zumbido eléctrico en tiempo real. Esta fase trae ese sistema a Godot con dos
`AudioStreamPlayer` y dos buses propios, **sin añadir ningún `.wav` ni `.ogg` al
proyecto**.

## Aire (respiración del operador)

| Pieza de la web | Nativo |
| --- | --- |
| `pink = 0,76·pink + 0,24·(2·random − 1)` | `W01Breath.noise_stream()`: 2 s a 22.050 Hz, normalizado a pico 0,72, en bucle |
| `BiquadFilter` paso banda `Q = 0,64` | bus **NEXUS Aire** con `AudioEffectBandPassFilter` y la misma resonancia |
| `frequency.setTargetAtTime(v > 0 ? 920 : 540, t, 0,09)` | `_approach(cutoff, 920 ó 540, delta, 0,09)` |
| `gain.setTargetAtTime((0,14 + max(0,−v)·0,56)·fatiga·|v|, t, 0,08)` | misma fórmula, misma constante de tiempo |
| `phase += dt·(1,65 + fatiga·2,9)` | idéntico; `fatiga = 1 − stamina/100` sólo en primera persona |

Al exhalar el aire sube a **0,70** de ganancia y el filtro se cierra a 540 Hz; al
inspirar baja a 0,14 y el filtro se abre a 920 Hz. Con la fatiga a 0,65 el ciclo
respira cada **1,78 s**.

## Zumbido de red

| Pieza de la web | Nativo |
| --- | --- |
| `OscillatorNode` triangular a 91 Hz, reajustado a `88 + carga·32` | bucle de **100 ciclos exactos** de triángulo a 88 Hz (8.800 Hz de muestreo, 10.000 muestras) movido con `pitch_scale` |
| `hum.gain.setTargetAtTime(near·(0,05 + 0,055·carga), t, 0,13)` | misma fórmula y constante |
| `rotor.frequency.setTargetAtTime(88 + carga·32, t, 0,25)` | misma rampa sobre `pitch_scale` |
| `near = 1/(1 + 0,17·d²)` sobre las tomas de `Power.ts` en `x = 19,85 · 22,7 · 25,55 · 28,4`, `z = 67,4` | `W01Breath.feeds_near()` con el mismo reparto y **las acometidas caídas en silencio** |

Con la carga al 72 % el rotor queda en **111 Hz** y la ganancia en 0,09; con la
red caída (`tripped`) el zumbido se corta aunque el operador esté pegado a la toma.

## Dónde se engancha

`SceneExperienceController._process` (el equivalente de `SceneExperience.ts`),
que ya tenía la cámara y el estado:

1. En menú o sin control, `breath.active = false` y `quiet()`.
2. En primera persona, `fatigue = 1 − stamina/100`; en órbita, 0 (la web hace
   lo mismo: `fp ? 1 - stamina/100 : 0`).
3. `machine(near, delivered/112)` con la cercanía calculada sobre la posición del
   jugador y el estado real de las cuatro acometidas de `PowerGrid`.

## Resultado

| Validador | Checks |
| --- | --- |
| `qa/validate_breath_audio.gd` (nuevo) | 21 |
| `qa/run_suite.gd` (bloque `_validate_breath_audio`) | 9 |
| **Total del proyecto** | **358 checks en `run_suite`, 0 fallos** |

Prueba de cableado real (C–04 → eléctrico, primera persona, stamina 62, junto a
la acometida 1):

```
t=0   air=0.017 cut=844 hum=0.0043 hz=88.5
t=60  air=0.044 cut=919 hum=0.0817 hz=105.1
t=120 air=0.028 cut=920 hum=0.0829 hz=106.7
t=180 air=0.015 cut=605 hum=0.0829 hz=107.1
```

`reports/phase35-breath.png` dibuja doce segundos de las tres señales (aire,
corte del paso banda y zumbido); los datos crudos están en
`reports/phase35-breath.csv`.

## Pendiente

- Audio tridimensional: el zumbido es hoy un `AudioStreamPlayer` estéreo; para
  que gire con la cabeza toca pasarlo a `AudioStreamPlayer3D` en cada acometida.
- El peso de grito que alimenta `W01Jaw` sigue pendiente; llegará con la voz de
  la criatura.
