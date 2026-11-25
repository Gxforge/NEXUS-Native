# Fase 31 · Guante, instrumentos y mangas en primera persona

Hasta ahora el operador era un ojo flotante: la web cuelga de la cámara las
manos, los tres instrumentos ópticos y el guante de la linterna, y aquí no había
nada. Esta fase conecta el rig original (`touch_rig_assets.glb`, 60 mallas)
tal cual, sin reconstruirlo con primitivas.

## Qué trae el exportador

`touch_rig_assets.glb` es la cámara de la web con su equipo colgando:

| Grupo | Contenido | Mallas |
|---|---|---|
| `Camera/Node/Node2…Node7` | seis poses del guante (`press`, `drawer`, `grip`, `flat`, `round`, `box`) | 5 · 5 · 4 · 5 · 5 · 5 |
| `Camera/Node9/Node10…Node12` | los tres instrumentos de `Instruments.ts` | 7 cada uno |
| `Camera/Node13/Node14` | guante de linterna de la mano izquierda | 4 |
| `Camera/Mesh55…Mesh58` | mangas (dos por brazo) | 1 cada una |
| `Camera/Mesh59…Mesh60` | codos | 1 cada uno |

Las geometrías vienen en espacio de empuñadura (la misma AABB que los `.glb`
sueltos `glove_*` e `instrument_*`), así que se colocan con las transformaciones
de `Touch.ts`: mano derecha en (0,185 · −0,152 · −0,50) y guante izquierdo en
(−0,196 · −0,146 · −0,50), con su balanceo senoidal.

## `scripts/world/first_person_rig.gd`

- Monta las piezas bajo `Camera3D/FirstPerson` (`main.tscn`), fuera del árbol de
  zona: el equipo viaja con el jugador entre salas.
- Refresca cada frame `weapon` y `lamp` desde `NexusPlayer`, así que el rig nunca
  se desincroniza del estado real (guardado, reinicio, corte de energía).
- Reproduce el bloque `update()` de `Touch.ts`: balanceo de 0,004 m, alcance de
  1,06 s con la pose elegida, retroceso de 0,032 m al disparar y vuelta al
  agarre.
- Materiales: albedo × 0,78 y 10 % de emisión propia, más una omnis de 0,14 W a
  34 cm. La web usa matcap (siempre legible); así el equipo se lee también en las
  salas a oscuras sin aplanarse.

## Decisiones de encuadre

- **Mangas apagadas por defecto** (`show_sleeves = false`). El lathe exportado es
  un tubo abierto: a 40 cm de la cámara se le ve el interior y parece un agujero.
  El guante ya trae su puño de punto y el antebrazo del propio guante sale del
  encuadre por el borde inferior.
- **Manos más bajas que en la web** (−0,152 en vez de −0,104). Con el HUD
  nativo, que ocupa la franja inferior, la muñeca cortada quedaba a la vista.
- El rig se oculta en vista orbital y cuando no hay protocolo activo, igual que
  `group.visible = fp && (active || tool >= 0)`.

## Enganche con el jugador

`player.gd` gana `_reach(style)` y lo llama en `interact` (press), `scan`
(round), `fire_tool` (grip + retroceso) y `deploy_lure` (flat).

## QA

`qa/validate_first_person.gd` (36 checks): seis poses con su número de mallas,
tres instrumentos de siete mallas, guante de linterna de cuatro, cuatro mangas y
dos codos, transformaciones de la mano, visibilidad por protocolo, guante de
linterna sólo con la linterna encendida, mangas apagadas, gesto de alcance que
se activa y vuelve al agarre, retroceso, emisión en los materiales y luz de vista.

```
run_suite 335 · layouts 65 · dressing 120 · original_models 19 · first_person 36
files 33 · vault 53 · bench 51 · operations 77 · transit 154 · experience 139
camera 113 · session 95 · displays 89 · w01_ai 66 · power_grid 45
traversal 255 · zone_graph 303 · game_state 17 · resume 8
                                            →  2073 checks, 0 fallos
```

## Capturas

`qa/capture_first_person.tscn` arranca el juego limpio (borra el guardado antes
de instanciar `main.tscn`, para que el HUD no muestre el inventario de otra
partida) y toma tres fotos en C–04:

- `reports/first_person-uv.png` — emisor de pulso UV.
- `reports/first_person-cryo.png` — proyector criogénico con el guante de linterna.
- `reports/first_person-reach.png` — gesto de presión con el instrumento morado.

Hoja de contacto: `reports/phase31-first-person.png`.
