# Fase 18 — Bancos técnicos: cuna de carga y analizador (`BenchCycle.ts`)

**Objetivo:** portar los dos bancos del área técnica y conectarlos a la red, para
que la energía que consume la simulación sea la de verdad.

## Qué se ha hecho

| Archivo | Cambio |
|---|---|
| `scripts/systems/bench_cycle.gd` | Nuevo. Port de `BenchCycle.ts`: cuna (8 s, 18 kW) y platina del analizador (10 s, 9 kW), con la misma elección de objeto, las mismas etapas y el corte por caída de red. |
| `scripts/systems/bench_station.gd` | Nuevo. Cuerpo interactivo del banco: prompt vivo con el porcentaje y el mensaje del ciclo. |
| `zones/zone_h01_hydraulics.tscn` | Cuna de carga en H–01. |
| `zones/zone_b02_turbines.tscn` | Platina del analizador en B–02. |
| `scripts/core/game_state.gd` | Los dos bancos viven en la partida: se actualizan cada frame, inyectan su consumo en `PowerGrid.machines` y se guardan (`SAVE_VERSION` 6 → 7). |
| `qa/validate_bench_cycle.gd` | Nuevo, 51 checks. |
| `qa/run_suite.gd` | +11 checks (197 en total). |

## Contrato portado

- **Cuna (charger)**: admite celda o linterna. Con la ranura seleccionada en la
  celda monta la celda; si no, linterna cuando la batería está por debajo del
  99,9 %, y si no, lo que haya. Nada válido → *«La cuna admite una celda o una
  linterna»*. Celda ya cargada o linterna llena → *«Carga completa · no requiere
  recarga»*.
- **Analizador**: sólo el vial (`sample`); sin él → *«La platina espera el vial»*.
- **Etapas**: `EN ESPERA` → `ACOPLANDO` (1,3 s) → `CARGANDO` (< 83 %) →
  `EQUILIBRADO` / `ENFOQUE` (< 46 %) → `BARRIDO` (< 80 %) → `VERIFICACIÓN` →
  `CARGADO / RETIRAR` · `VERIFICADO / RETIRAR`; con la red caída, `SIN RED` y el
  contador **no avanza**.
- **Consumo**: 18 kW la cuna y 9 kW la platina mientras hay ciclo, que es lo que
  entra en `PowerGrid.machines` (antes era una constante de 6 kW).
- **Resultado**: la cuna deja la energía de la herramienta a 100 y la batería de
  la linterna a 100; el analizador marca la muestra como analizada.

## Verificación

```
godot --headless --path . --script res://qa/validate_bench_cycle.gd   → 51/51
godot --headless --path . --script res://qa/run_suite.gd              → 197/197 (×3 ejecuciones)
godot --headless --path . --script res://qa/validate_operations.gd    → 77/77
godot --headless --path . --script res://qa/validate_power_grid.gd    → 45/45
```

## Lo que queda de la fase

- **Vasos de observación** (`Workshop.Pods`): las tres unidades de H–01 con
  burbujeo, latido de la larva y aro luminoso son hoy sólo geometría pendiente;
  su lógica es puramente visual, sin contrato de juego.
- **Geometría de los bancos**: bandeja, haz del analizador y pantallas.
- Enlazar el resultado del analizador con el expediente «Cadena de custodia»
  (D–02) y con la IA de W-01 cuando exista.
