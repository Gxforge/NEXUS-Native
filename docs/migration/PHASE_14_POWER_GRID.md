# Fase 14 — Red eléctrica nativa (`Power.ts`)

**Objetivo:** primer sistema de juego de la web que funciona igual en Godot, con
estado persistente, HUD y pruebas numéricas.

## Qué se ha hecho

| Archivo | Cambio |
|---|---|
| `scripts/systems/power_grid.gd` | Nuevo. Port de `src/scene/Power.ts` (106 líneas): doce alimentadores, cuatro activos por defecto, límite de 14 kW por alimentador, capacidad, carga, reparto por alimentador, kWh acumulados, picos temporales, temperatura con histéresis, estrés y disparo/rearme. |
| `scripts/core/game_state.gd` | La red vive en la partida: `power`, `power_simulation`, avance en `_process`, señal `power_state_changed` y serialización en el guardado (`SAVE_VERSION` 2 → 3, tolerante con partidas viejas). |
| `scripts/ui/nexus_hud.gd` | Línea de red bajo los recursos: `RED ESTABLE · 70/112 kW · 41 °C`, en ámbar al límite y en rojo con la causa del disparo. |
| `qa/validate_power_grid.gd` | Nuevo, 45 checks. |
| `qa/run_suite.gd` | +9 checks de red dentro de la suite principal. |

## Constantes portadas tal cual de la web

```
capacidad        = Σ alimentadores activos (28 kW, o 14 kW si están limitados)
carga            = 22 + luces·brillo + máquinas + agresividad·14 + extractores·3
                   + (motor ? 45 : 0) + picos ;  con la red caída: 17
entregada        = min(capacidad, carga) ;  0 si está caída
entrada          = entregada / 0.956
temperatura      → objetivo 28 + carga·0.24 + (4 − extractores)·13, suavizado 0.17
estrés           += dt·(0.19 + exceso·0.032) si hay exceso, dt·(−0.52) si no
disparo          con estrés ≥ 1 o temperatura ≥ 84 °C
rearme           exige capacidad ≥ 84 kW, temperatura ≤ 65 °C y ≥ 2 extractores
```

## Cómo se usa desde el juego

```gdscript
var state := $GameState as GameState
state.power.cycle_feed(4)              # cerrar un alimentador
state.power.set_limit(0, true)          # limitar el primero a 14 kW
state.power.spike("motor V–03", 45.0, 8.0)   # pico temporal de 8 s
state.power.rearm()                     # mensaje listo para el HUD
state.power_snapshot()                  # {load_kw, capacity, temp, stress, status…}
```

`GameState._process` avanza la simulación con el motor desactivado y la
agresividad registrada del sujeto (`watcher_state.aggression`). Las pruebas y las
capturas ponen `power_simulation = false` y avanzan a mano.

## Verificación

```
godot --headless --path . --script res://qa/validate_power_grid.gd   → 45/45
godot --headless --path . --script res://qa/run_suite.gd             → 157/157
godot --headless --path . --script res://qa/validate_game_state.gd   → 17/17
```

## Lo que queda de la fase

- Panel de interruptores en 3D dentro de `electrical` (llega con `Operations.ts`,
  fase P-4) para que el jugador cierre alimentadores sin consola.
- Atar las luces reales de cada zona a `light_kw` y `brightness` en vez de usar
  sólo los circuitos declarados.
- CCTV y telemetría consumiendo de la red cuando existan (fases P-4 y P-8).
