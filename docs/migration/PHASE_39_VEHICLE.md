# Fase 39 · Coche de vía: suspensión de cuatro apoyos y mallas originales

**Fecha:** 24 de noviembre de 2026
**Estado:** cerrada · `run_suite` **395 checks, 0 fallos** · `validate_vehicle_rig` **51 checks**
**Punto de partida:** `6e45961` (fase 38)

El coche de vía tenía toda su lógica portada desde la fase 15 (masa, motor,
turbo, marchas, integridad y 154 checks en `validate_transit`), pero no existía
en pantalla: el jugador se subía a un coche invisible. Esta fase le pone la
carrocería, las ruedas y la suspensión.

## 1. El modelo

`vehicle.glb` exporta cinco grupos sueltos: el cuerpo (`Node2`, 2,25 × 1,48 ×
4,60 m, 16 mallas) y las cuatro ruedas (`Node5`–`Node8`, 0,29 × 0,71 × 0,71 m,
cinco mallas cada una). `PropLibrary.vehicle()` los devuelve en orden de
exportación dentro de un contenedor.

`VehicleRig` (`scripts/world/vehicle_rig.gd`) separa cuerpo y ruedas por
geometría (el hijo de mayor caja es el cuerpo; los cuatro pequeños de más de
tres mallas son las ruedas) y las coloca donde las pone la web:
`(±0,87, 0,355, ±1,38)`, con las delanteras primero.

| Pieza | Movimiento (`VehicleModel.sync`) |
| --- | --- |
| conjunto | `position = cuerpo − (0, comY, 0)`, `rotation = (pitch, yaw, roll)` |
| rueda `i` | `y = comY + 0,14 − suspensión`, `rotation.y = dirección`, `rotation.x = rodadura` |

## 2. La suspensión

La web lo resuelve con `cannon-es` y un `RaycastVehicle`. En Godot no hay motor
de física para eso, así que `VehiclePhysics` gana un solver propio con **las
mismas constantes** de `tune` y de los cuatro muelles:

| Constante | Valor |
| --- | --- |
| recorrido de suspensión | 0,19 m (reposo a 0,32 m) |
| rigidez | 41 |
| amortiguación al comprimir / al extender | 3,4 / 4,5 |
| tope de fuerza | 18 kN |
| influencia del vuelco | 0,12 |
| anclajes | `(±0,87, 0,14, ±1,38)`, vía 1,74 m, batalla 2,76 m |

Cada apoyo integra su muelle con la frecuencia que sale de la rigidez
(`ω = √41 ≈ 6,4 rad/s`) y un amortiguamiento asimétrico, con el objetivo de
longitud que deja la rueda en el suelo. La actitud de la carrocería sale de lo
que la web siente en el chasis: la aceleración longitudinal (el morro sube al
acelerar y baja al frenar) y el par de guiñada (la carrocería vuelca hacia fuera
del giro), con su propio muelle y su amortiguación.

Medido: en reposo las cuatro ruedas se asientan a 0,355 m (el radio) con 0,31 m
de suspensión; acelerando, las delanteras extienden a 0,353 m y las traseras
comprimen a 0,267 m con el morro 1,8° arriba; girando, el balanceo llega a 3°
y sólo las dos delanteras giran.

`wheel_state(i)` devuelve longitud, dirección, rodadura, contacto y posición en
el mundo; `telemetry()` añade actitud y longitudes; `contacts` pasa a ser el
recuento real de apoyos.

## 3. Enganche

`CapsuleTransit._build_car()` monta el rig como hijo `RailCar` al arrancar y, en
cada paso, lo sincroniza: `sync(physics)` mientras se conduce y
`place(_car_offset, 0)` cuando el coche está aparcado en el andén o subido a la
plataforma.

## 4. Pruebas y capturas

`qa/validate_vehicle_rig.gd` (51 checks): constantes de la suspensión, vía y
batalla; reposo con cuatro apoyos a la altura del radio; morro arriba al
acelerar y abajo al frenar; compresión trasera; recorrido dentro de límites;
balanceo al girar; dirección sólo en las delanteras; rodadura `v/r·t`; montaje
del `.glb` con cuerpo y cuatro ruedas y sus 36 mallas dentro del árbol; y el
contrato de `sync`/`place`.

`run_suite` gana `_validate_vehicle_rig()` con 12 checks. Total **395 checks, 0
fallos**.

Captura nueva: `reports/ingame-transit_car.png` (vista `transit_car` de
`qa/capture_zones.tscn`, que busca el `RailCar` en el árbol para encuadrarlo).
También se rehízo `reports/ingame-transit_hub.png`.

## 5. Pendiente que arrastra la fase

- `Cockpit.ts`: el panel de instrumentos del salpicadero (384 × 144 con
  velocímetro, marcha, energía e integridad) y el mapa de reflejos.
- `VehicleAudio.ts`: los tres osciladores (sierra, triángulo y seno) y el
  ruido de rodadura.
- `Perspectives.ts`: las cuatro cámaras del coche.
