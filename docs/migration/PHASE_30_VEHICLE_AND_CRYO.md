# Fase 30 · Vehículo, calzada y consolas de crioteca

Tercera tanda de modelos originales, y la primera que decora **la calzada**, que
hasta ahora no tenía `ZoneDressing` ninguno.

## `vehicle.glb` en la calzada

`vehicle.glb` trae cinco grupos: el chasis `Node2` (2,25 × 1,48 × 4,60) y las
cuatro ruedas `Node5…Node8` (0,29 × 0,72 × 0,72). Se montan tal cual dentro de
un pivote `Vehicle` aparcado en (1,5 · 132) de `transit_road`.

`zones/zone_transit_road.tscn` gana por fin su nodo `Dressing`
(`zone_id = "transit_road"`), y `_build_transit()` se parte en tres ramas para
que cada tramo del eje reciba lo suyo:

| zona | qué se construye |
|---|---|
| `transit_hub` | cápsula, andén, franjas, tornos `Node4`/`Node9` y plano `Node14` |
| `transit_road` | vehículo, eje discontinuo cada 24 m y balizas a ambos lados del carril |
| `transit_rail` | banda emisiva de guiado cada 24 m |

Antes el andén y la cápsula se construían en las tres zonas, así que en la
calzada (que arranca en z = 110 y mide 2 km) caían fuera del túnel.

## `vault.glb` en la crioteca

- `Node98` (1 × 1 × 1) → `CryoConsole`, panel contra el muro este en (40,4 · −91).
- `Node99` (0,67 × 0,88 × 0,30) → `CryoReader`, lector sobre el banco frío en
  (35,6 · 1,02 · −95,6), a escala 1,4.

## Validador nuevo: `qa/validate_original_models.gd`

19 checks que cargan las zonas y cuentan mallas para que nadie vuelva a cambiar
los modelos originales por cajas sin que salte el QA:

- H–01: tres vasos con ≥ 40 mallas cada uno, tres larvas, el pivote a escala 0,42.
- B–02: puerta de la bóveda con ≥ 40 mallas.
- V–03: mostrador y terminal del puesto de control.
- Crioteca: consola y lector.
- Hub: `Torno1`, `Torno2` y `PlanoEje`.
- Calzada: `Vehicle` con ≥ 30 mallas (chasis + cuatro ruedas).

## QA

```
run_suite 335 · layouts 65 · dressing 120 · original_models 19 · files 33
vault 53 · bench 51 · operations 77 · transit 154 · experience 139 · camera 113
session 95 · displays 89 · w01_ai 66 · power_grid 45 · traversal 255
zone_graph 303 · game_state 17 · resume 8        →  2037 checks, 0 fallos
```

## Pendiente

1. La calzada no está en `capture_zones`: el túnel mide 2 km y renderizarlo en
   software agota el tiempo del pipeline de capturas.
2. `instrument_0/1/2.glb` siguen sin usar: son instrumentos de guante y van con
   `Glove.ts`, no con el mobiliario.
3. Falta un módulo de `transit.glb` a escala 0,5 para cerrar la estación del hub.
