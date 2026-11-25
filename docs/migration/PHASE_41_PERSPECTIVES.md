# Fase 41 · Perspectivas del operador y del coche

**Fecha:** 24 de noviembre de 2026
**Estado:** cerrada · `run_suite` **414 checks, 0 fallos** · `validate_perspectives` **39 checks**
**Punto de partida:** `f9c1041` (fase 40)

La fase 40 dejó el coche con instrumentos y motor, pero la cámara seguía siendo
la única del operador a pie. Con esta fase se porta `Perspectives.ts` (104
líneas), el último archivo de `vehicle/*` que quedaba sin equivalente, y con él
llegan la tercera persona y el hombro para el operador y las tres cámaras del
coche: cabina, persecución y órbita.

## 1. El módulo (`scripts/world/perspectives.gd`)

Dos modos por contexto, igual que la web: `foot` y `car`, cada uno de 0 a 2.
`mode(driving)` elige la tabla, `cycle_foot()` y `cycle_car()` avanzan
`1 → 2 → 0` y `enabled` arranca en `false`, de modo que el modo 0 del operador a
pie no toca la cámara que ya gobernaba `CameraController`.

| Constante | Valor | Para qué |
| --- | --- | --- |
| `ZOOM_MIN` / `ZOOM_MAX` | `2,2` / `9,0` | límites de la rueda |
| `DISTANCE` / `HEIGHT` | `4,8 m` / `1,85 m` | persecución del coche |
| `SHOULDER` | `2,9 m` | hombro del operador a pie |
| `FOOT_ORBIT` / `FOOT_DROP` | `0,72` / `0,32` | órbita a pie (distancia y caída del punto de mira) |
| `BLEND_RATE` / `DAMP` | `5,0` / `12,0` | mezcla y amortiguado |
| `COLLISION_MARGIN` / `COLLISION_MIN` | `0,17` / `0,12` | recorte contra geometría |
| `SIDE_SAMPLES` | `[0; −0,12; 0,12]` | los tres rayos laterales de la web |
| `COCKPIT` / `COCKPIT_AIM` | `(0,38; 1,055; −0,24)` / `(0,38; 1,09; 9)` | asiento del conductor |
| `CAR_PIVOT` | `(0; 0,66; 0,23)` | centro de la persecución |

### Cámaras

- **A pie, modo 0:** la cámara se queda con `CameraController` (primera persona).
- **A pie, modo 1 (hombro):** punto de mira `aim.y − 0,32` y la cámara `2,9 m`
  por detrás del rumbo, con la altura de siempre.
- **A pie, modo 2 (órbita):** la cámara se va `−distancia · 0,72` hacia atrás y
  sube `0,55 − 0,8 · pitch`, girando con el ratón.
- **En coche, modo 0 (cabina):** la cámara sube al asiento en `COCKPIT` mirando
  a `COCKPIT_AIM`, con `up = car.basis.y` para que la cabecera siga el balanceo
  de la suspensión.
- **En coche, modos 1 y 2 (persecución y órbita):** giran alrededor de
  `CAR_PIVOT` a `distance` del coche, con
  `y = pivot.y + max(0,35; height (+ 3 · pitch en modo 2))`.

La rueda del ratón mueve `distance` de 0,4 en 0,4 m entre `ZOOM_MIN` y
`ZOOM_MAX`; el amortiguado es `e^(−12·Δt)` y, si no hay impacto, la posición se
mezcla con la anterior con un `smoothstep` de `5,0`.

### Lo que costó

- **`Camera3D` no tiene `up`** en Godot 4.4 (`Invalid assignment of property
  'up'`): la orientación se construye con `Transform3D(Basis.looking_at(dir, up), at)`
  y, cuando `dir` y `up` son paralelos —la base de la cabina tumbada—, se cae a
  `Vector3.FORWARD`.
- **El amortiguado no puede leer `position` como fuente:** si `_last` sólo se
  actualizaba en `apply()`, los bucles de prueba divergían; si se actualizaba
  siempre, la primera toma partía de `Vector3.ZERO`. Ahora `solve()` fija
  `_last` al calcular y una bandera `_has_last` decide si amortiguar; `reset()`
  la limpia.

## 2. Enganche con el jugador

`player.gd` gana `perspective` (una instancia de `Perspectives`) y
`_update_perspective(delta)`, que se llama al final del paso de física:

- **`V`** cicla la cámara a pie, **`C`** la del coche y la rueda acerca o aleja.
- Cada cambio deja un registro en la bitácora (`Cámara: coche 1`).
- `_hit_distance(origin, destination)` resuelve el recorte con
  `PhysicsDirectSpaceState3D.intersect_ray`, devolviendo
  `max(COLLISION_MIN, distancia − COLLISION_MARGIN)`; se ignoran el propio
  jugador y el coche.
- Si `apply()` devuelve `false` (modo 0 a pie) la cámara vuelve a
  `CameraController` sin dejar estado raro.

### El asiento del conductor

Con la cabina en `COCKPIT` la cámara quedaba 1,72 m por encima del techo: el
`CapsuleTransit` ancla al operador **por el ojo**, mientras que `COCKPIT` está
medido desde los pies. El asiento pasa a
`physics.position + (0; 38; 1,055 − EYE_HEIGHT; −0,24).rotated(...)`, así que los
pies quedan apoyados en el suelo de la cabina y el ojo cae justo en `COCKPIT`.

## 3. Pruebas y captura

`qa/validate_perspectives.gd` (39 checks, geometría medida sólo en XZ con el
ayudante `_flat()` para que la altura no contamine las distancias):

- modo, ciclos `V`/`C` desde 0 y vuelta, y `enabled` inicial;
- límites y paso de la rueda (`zoom(+1) = +0,4 m`);
- hombro: `aim.y − 0,32` y `2,9 m` por detrás;
- órbita a pie: distancia y caída con el pitch;
- cabina: posición, mira, `up` de la carrocería;
- persecución y órbita del coche: detrás, altura y `+3 · pitch`;
- amortiguado: la primera toma no arrastra, la segunda sí y la cámara se queda
  atrás al moverse el coche (`_has_last`, instancia `fresh`);
- recorte: `COLLISION_MIN` cuando hay pared pegada.

`run_suite` suma `_validate_perspectives()` (8 checks) y llega a **414 checks
con `failures: []`** sobre 27 validadores.

Captura `reports/ingame-transit_chase.png` (persecución trasera del coche en el
hub, con el panel encendido y el prompt `Q · Escanear Zona TRANSIT_HUB`),
generada con `cd NEXUS-Native && /tmp/cap.sh qa/capture_zones.tscn transit_chase`
(~11 s): la vista monta el coche aparcado en `(-12; 0,48; 109)`, pone
`perspective.car_mode = 1` y deja correr 60 pasos de `_update_perspective`.
