# Fase 40 · Panel de instrumentos y sonido del coche

**Fecha:** 24 de noviembre de 2026
**Estado:** cerrada · `run_suite` **406 checks, 0 fallos** · `validate_vehicle_ui` **38 checks**
**Punto de partida:** `cbb9aec` (fase 39)

Con la fase 39 el coche ya se veía y se apoyaba en sus cuatro ruedas, pero el
conductor no tenía instrumentos ni motor audible. Esta fase cierra las dos
piezas que faltaban de `vehicle/*` que no dependen de la cámara:
`Cockpit.ts` y `VehicleAudio.ts`.

## 1. Panel de instrumentos (`scripts/world/cockpit_display.gd`)

La web pinta un lienzo de 384 × 144 con el velocímetro y lo pega en un plano de
0,39 × 0,145 m. Aquí el lienzo se reproduce **en el espacio**: 1 px del lienzo
es 1 mm del plano, así que el plano mide 0,384 × 0,144 m y los rótulos son
`Label3D` con `pixel_size` ajustado a su tamaño de lienzo (todos comparten
`font_size = 96` y cada uno escala con `pixel_size`, que es la única forma de
que el atlas de fuente no mezcle líneas).

| Texto | Contenido |
| --- | --- |
| cabecera | `GT / 14     AXIAL DRIVE` |
| velocidad | tres cifras con ceros (`000`) y `km/h` |
| marcha | `GEAR N` |
| régimen | `850 RPM` |
| energía | `E 100%` y barra de `energía · 3,55` px |

`paint()` sólo reescribe si cambia la clave `velocidad:marcha:energía:régimen`,
igual que `Cockpit.paint`. `sync(physics)` aplica el redondeo de la web:
`|v|·3,6` a entero, energía a entero y régimen a centenas.

### Dónde va

La web lo coloca en `(0,38; 0,966; 0,545)` girado 180°. Con el modelo exportado
eso no se lee: el salpicadero de `vehicle.glb` trae su propia placa justo en esa
posición y el volante queda delante, así que la primera versión aparecía como un
rectángulo con rayas (la placa del modelo por encima). El panel se sube a
**1,03 m**, se adelanta a **0,47 m** y se inclina 12° hacia el conductor: se lee
entero y el volante sólo tapa la fila de la energía.

## 2. Sonido (`scripts/systems/vehicle_audio.gd`)

Port de `VehicleAudio.ts`, que sintetiza todo con `AudioContext`. Aquí cada voz
es un bucle de un periodo exacto (`AudioStreamWAV`) y la frecuencia se cambia con
`pitch_scale`, con las mismas fórmulas:

| Voz | Onda | Frecuencia | Ganancia |
| --- | --- | --- | --- |
| motor | sierra | `30 + rpm/63` | `0,008 + 0,012·\|gas\|` |
| rodadura | triángulo | `240 + \|v\|·18` | `0,035·min(1, deslizamiento + frenada)` |
| turbo | seno | `240 + energía·4` | `0,032` con turbo |
| ruido | ruido rosa | paso bajo `240 + \|v\|·20 + 2700·impacto` | `0,003 + \|v\|·0,0009 + impacto·0,15` |

Las constantes de tiempo de `setTargetAtTime` se reproducen con interpolación
exponencial (`0,06 s` en las voces, `0,04 s` en el filtro, `0,05 s` en el ruido)
y el paso bajo vive en su propio bus (`NEXUS Rodadura`), como el paso banda de
la respiración en la fase 35.

`CapsuleTransit` monta el audio al arrancar y lo actualiza en cada paso:
`update(physics, driving)` conduce el coche sólo cuando el operador va al
volante; con el coche aparcado las cuatro voces se apagan.

## 3. Pruebas y captura

`qa/validate_vehicle_ui.gd` (38 checks): medidas del lienzo y del plano, la
barra con la carga, los cinco rótulos, el repintado sólo al cambiar, el
redondeo de la telemetría, las cuatro voces y sus fórmulas, el paso bajo, el
turbo, la frenada, el impacto, el silencio sin conductor y los bucles de las
ondas (735 muestras para la sierra de 30 Hz, 92 para el triángulo de 240 Hz).

`run_suite` gana `_validate_vehicle_ui()` con 11 checks. Total **406 checks, 0
fallos**.

Captura nueva: `reports/ingame-transit_seat.png`, desde el ojo del conductor
(vista `transit_seat`, que se coloca con `Transit.step`: `(0,38; 1,055;
−0,24)`); se ve el panel con `000 km/h`, `GEAR N`, `850 RPM`, `E 100%` y la
barra de carga.

## 4. Pendiente que arrastra la fase

- `Perspectives.ts`: las cuatro cámaras del coche (conducción en cabina y
  persecución, a pie al hombro y órbita) con su mezcla y el acortado por
  contactos.
- `Cockpit.ts` deja también el mapa de reflejos de las tiras de luz
  (`reflection()`), que en Godot cubre el `WorldEnvironment` de cada zona.
