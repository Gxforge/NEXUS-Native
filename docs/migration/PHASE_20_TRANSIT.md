# Fase 20 · Tránsito y vehículo (P-7)

**Fecha:** 24 de noviembre de 2026
**Fuente web:** `src/scene/Transit.ts` (669 líneas) y `src/vehicle/VehiclePhysics.ts` (263 líneas).
**Destino:** `scripts/systems/capsule_transit.gd`, `scripts/systems/vehicle_physics.gd`,
`scripts/systems/transit_console.gd`, `zones/zone_transit_hub.tscn` y persistencia en `GameState`.

## 1. Qué se ha portado

### Cápsula (`Transit.ts`)

La web mezcla tres cosas en el mismo archivo: geometría del andén (JSX), un
`use()` para los puestos y un `step()` que mueve la cápsula y al jugador. Aquí
se ha portado el **comportamiento**, no la geometría (que ya existe como GLB en
`transit_hub`, `transit_road` y `transit_rail`).

| Contrato de la web | Implementación nativa |
|---|---|
| Andenes `A = 102`, `B = 2042`, eje `x = 15` | `STATION_A`, `STATION_B`, `AXIS_X` |
| Cierre de puertas 1,2 s dentro de 1,4 s de espera | `door = 1 − smoothstep(0, 1,2, time)` y `DEPART_DELAY` |
| Traslado con `smoothstep((t − 1,4) / 10)` | polinomio de quinto grado `6r⁵ − 15r⁴ + 10r³` |
| Apertura de puertas a 0,86/s | `door += 0,86 · delta` |
| Compuerta a 0,7/s si el jugador está a ±6 de `z = 70` en primera persona | `gate` con `GATE_BAND` |
| `canStand`: franja del delantal, límites ±19,8 y `z ≤ 2069,4`, hueco en `|x − 6,1| < 0,56` | `can_stand(x, z)` |
| `inside`: `|x − 15| < 1,99` y `|z − at + 1,5| < 6,02` | `inside(point)` |
| Transferencia del carro en 4 s con 0,24 m de elevación | `transfer`, `_sx/_sz`, `loaded` |
| Cinco asientos a 1,47 m (`railSeat0…4`) | `SEAT_OFFSETS` |
| Freno de retención (`hold`) y carteles «ANDÉN 01/02», «RETENIDA», «N km/h» | `use(&"railBrake")`, `_set_status`, `Label3D` del andén |
| Iluminación de la nave al 65 % con el jugador al norte | `power(player_z)` |
| Salida del vehículo sólo por debajo de 2,5 m/s | `use(&"railStand")` → `_find_exit()` |

El jugador a bordo se desplaza con la cápsula (`step` devuelve la posición
resultante), y sentado se ancla al asiento, igual que en la web.

### Vehículo (`VehiclePhysics.ts`)

La web usa `cannon-es` con un `RaycastVehicle`. El port **no** introduce un
motor de física distinto: reproduce el mismo contrato numérico con un integrador
de paso fijo de 1/120 s, de modo que el resultado sea determinista y verificable
en headless (`qa/validate_transit.gd`), y expone la telemetría que la web pinta
en pantalla.

| Constante | Valor |
|---|---|
| Masa / centro de masas | 1260 kg / 0,48 m |
| Batalla / vía / radio de rueda | 2,76 / 1,74 / 0,355 m |
| Punta / marcha atrás | 49 m/s (×1,18 con turbo) / 8 m/s |
| Fuerza de motor / respuesta | 4100 N (×1,75 con turbo) / 5 s⁻¹ |
| Giro / caída con la velocidad | 0,54 rad / 0,045 |
| Turbo | −24/s de energía, recarga 9/s, bloqueo 3,5 s al agotar |
| Integridad | `−(dv − 2,7) · 1,65` por impacto por encima de 2,7 m/s |
| Marchas | N, R y 1–6 cada 8 m/s; régimen desde 850 rpm |

Además: `register_impact()`, `telemetry()`, `reset()`, `to_dict()`/`from_dict()`
y `set_train(z)` para que el coche sólo pueda moverse dentro de la cápsula.

### Mandos y persistencia

- `transit_console.gd`: puestos con `handle_id` de la web (`railCallA`,
  `railCallB`, `railBrake`, `railLoad`, `railCar`, `railSeat0…4`); devuelven el
  mensaje del contrato y recolocan al jugador cuando toca.
- `zones/zone_transit_hub.tscn`: nodo `Transit` con su cartel `Label3D` y los
  diez puestos colocados en el andén 01.
- `GameState`: `transit`/`_transit_pending` con el patrón de registro diferido
  de la bóveda y los archivadores; el bloque `transit` entra en el guardado y
  `SAVE_VERSION` sube a **8**.

## 2. Pruebas

| Validador | Checks | Estado |
|---|---|---|
| `qa/validate_transit.gd` | **154** | ✅ 0 fallos |
| `qa/run_suite.gd` | **228** | ✅ 0 fallos (×2 ejecuciones limpias) |
| `qa/validate_game_state.gd` | 17 | ✅ |
| `qa/validate_resume.gd` | 8 | ✅ |
| `qa/validate_vault.gd` · `validate_files.gd` · `validate_operations.gd` | 53 · 33 · 77 | ✅ |
| `qa/validate_bench_cycle.gd` · `validate_power_grid.gd` | 51 · 45 | ✅ |
| `qa/validate_w01_ai.gd` · `validate_w01_actor.gd` | 66 · 6 | ✅ |
| `qa/validate_zone_graph.gd` · `validate_zone_traversal.gd` | 303 · 255 | ✅ |

`validate_transit.gd` cubre, por bloques:

1. **Geometría**: constantes, cartel inicial, delantal con la compuerta cerrada y
   abierta, límites de la vía, hueco de mantenimiento, volumen interior y
   nombres de andén.
2. **Puertas, traslado y retención**: cierre en 1,2 s, arranque a 1,4 s,
   smoothstep, arrastre del jugador a bordo, llegada a los 10 s con señal
   `arrived`, apertura a 0,86/s, freno de retención y compuerta por proximidad.
3. **Asientos y carro**: los cinco asientos, altura 1,47 m, el asiento viaja con
   la cápsula, transferencia de 4 s con la altura intermedia de 0,12 m,
   enclavamiento, descarga y bloqueo por maniobra en curso.
4. **Vehículo**: constantes, marchas N/R/1–6, régimen, daño por impacto con el
   umbral de 2,7 m/s, aceleración, punta, turbo con coste y bloqueo, giro con
   caída, freno de mano, marcha atrás y salida del coche.
5. **Persistencia**: ida y vuelta del diccionario completo (andén, puertas,
   asiento, carro, vehículo) y registro en `GameState`.

## 3. Capturas

`reports/zone-transit_hub.png`, `zone-transit_road.png` y `zone-transit_rail.png`
se han regenerado con la cápsula y los mandos ya en escena. La captura del hub
mira ahora al andén 01 (antes enfocaba el origen de la zona, que queda detrás del
jugador), y en ella se lee el cartel «ANDÉN 01» del `Label3D` de la cápsula.

## 4. Lo que queda en este bloque

- Geometría de la cápsula, asientos y marco ámbar de transferencia (hoy son
  puestos de colisión sobre el GLB de la zona).
- Audio del motor y de la puerta, y perspectiva de cabina (`vehicle/Camera`,
  `vehicle/Audio` de la web).
- Los otros cuatro archivos de `src/vehicle/*` (922 líneas): modelo, cabina y
  perspectivas del coche.
- La vía completa en `transit_rail` (la física ya usa `set_train()` para no
  salirse de la cápsula, pero el trazado fino llega con el pase de geometría).

## 5. Siguiente

**P-8 · UI y orquestación**: `App.tsx` (ajustes, perfiles gráficos, pantalla de
recuperación), `SceneExperience.ts` (estado por zona y unión entre sistemas),
`CameraController.ts` (cámara orbital y sacudidas) y `Displays.ts`/`TelemetryScreen.ts`
(pantallas ya en Godot). Después, `Workshop` (Pods) y el alta fidelidad de
geometría (P-9).
