# Fase 19 — IA y percepción de W–01 (`MonsterAI`, `Attention`, `FieldSense`)

**Objetivo:** que el sujeto deje de ser decorado: percibe, recuerda, bordea la
malla de contención y ataca con el mismo contrato que la web.

## Qué se ha hecho

| Archivo | Cambio |
|---|---|
| `scripts/entities/monster_ai.gd` | Nuevo. Port de `MonsterAI.ts`: seis estados, agresividad amortiguada por estado, ataque de 1,22 s, recarga de 6,4 s, recuperación de 2,15 s y empuje de golpe (`sin` en ataque, exponencial en recarga). |
| `scripts/entities/monster_attention.gd` | Nuevo. Port de `Attention.ts`: cono de visión de 1,29 rad a 33 m, audición de 8 m (16 m corriendo), memoria de 5,4 s, intenciones, patrulla, repliegue, señuelo y tope de 2,8 m para no pisar al operador. |
| `scripts/entities/field_memory.gd` | Nuevo. Port de `FieldSense.ts`: malla de contención de 24 facetas (radio 15, apotema 14,86), sector más cercano y memoria de riesgo por sector con persistencia. |
| `scripts/entities/w01_actor.gd` | La IA interna se sustituye por los tres módulos; el actor conserva toda la parte visual (respiración, boca, ojos, tentáculos) y ahora delega estado, movimiento y percepción. |
| `qa/validate_w01_ai.gd` | Nuevo, 66 checks. |
| `qa/run_suite.gd` | +10 checks (207 en total). |

## Contrato portado

- **Visión**: `p.z > −13,45`, distancia < 33 m y `|ángulo − rumbo| < 1,29 rad`.
  El mamparo es el límite de contención: al otro lado no te ve.
- **Audición**: pasos hasta 8 m, **16 m si corres**, y sólo si te has movido de
  verdad (`distanceSquared > 0,00012`).
- **Memoria**: 5,4 s desde el último contacto visto u oído; mientras dura, «Busca
  el último contacto».
- **Intenciones**: `Sujetando`, `Se repliega`, `Investiga el señuelo`, `Acecha`,
  `Escucha pasos`, `Se aproxima`, `Observa`, `Busca el último contacto`,
  `Explora`, `Bordea la malla`.
- **Malla**: al acercarse a una faceta se desvía por el lado con menos riesgo
  recordado y acumula `+0,1` de riesgo cada 3 s en ese sector (24 sectores, se
  guardan con la partida).
- **Estados**: `IDLE` (>11,5 m), `WATCHING` (>7,1), `CURIOUS` (>5,05),
  `AGGRESSIVE`, `ATTACK` (<5,45 m y recarga lista) y `RECOVERY`.
- **Herramientas**: el pulso UV fuerza recuperación con 5 s de recarga; el
  criogénico lo enfría 7 s, lo repliega y lo frena; el señuelo pasa a ser su
  objetivo durante el tiempo indicado.

## Verificación

```
godot --headless --path . --script res://qa/validate_w01_ai.gd        → 66/66
godot --headless --path . --script res://qa/run_suite.gd              → 207/207 (×2)
godot --headless --path . --script res://qa/validate_w01_actor.gd     → 6/6
godot --headless --path . --script res://qa/validate_w01_tentacles.gd → ok
```

## Lo que queda de la fase

- **Dinámica de tentáculos** (`Tentacles.ts`, 406 líneas): hoy son 20 brazos con
  oscilación procedural; falta la deformación por contacto y el agarre real.
- **Agarre y daño**: el estado `Sujetando` está previsto (`grabbing`) pero no hay
  sistema de captura, daño fisiológico ni escape.
- **Respiración sonora** (`Breath.ts`): es WebAudio; en Godot pide
  `AudioStreamGenerator` y un bus propio.
- **Colisión real con la malla**: la contención se resuelve por intención, no por
  física; falta el volumen de las 24 facetas.
