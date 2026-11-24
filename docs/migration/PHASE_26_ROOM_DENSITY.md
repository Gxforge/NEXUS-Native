# Fase 26 · Densidad de C–04 y A–01

Las dos salas más vacías de la planta nativa (la de contención, 72 × 84 m, y el
archivo biométrico, 36 × 24 m) tenían cuatro piezas contadas. Esta fase las
equipa sin mover ni una colisión de juego: todo el mobiliario nuevo es
`MeshInstance3D` decorativo, dentro de `ZoneDressing.ROOMS` y con el techo
respetado (lo comprueba `validate_dressing`).

## C–04 · contención

- **Franja de peligro** en el suelo: 24 testas ámbar emisivas a 14,6 m del
  centro del anillo.
- **Pasarela perimetral** (`C04Catwalk`, radio 17,2, cota 3,1): 24 tramos de
  chapa con borde luminoso, dos barandillas por tramo y ocho columnas de apoyo.
- **Balizas de sector** en cuatro diagonales, añadidas a `indicators` para que
  parpadeen con `animate(t)` (escala `0.45 + 0.55·|sin(1.9t + 0.8i)|`).
- **Pórtico de mantenimiento** (`C04Gantry`): dos carriles a cota 8, viga de 41 m,
  carro, cable y gancho de bronce sobre la cuba.
- **Banco de instrumentación** en el muro oeste: cuatro armarios, banda emisiva y
  tres `WallScreen` de fósforo con el estado de la malla («CONTENCIÓN C–04 ·
  MALLA ACTIVA · anillo n · tensión nominal»).
- **Iluminación**: la fila central de `_ceiling_lights` (la sala es la más ancha
  de la planta, así que sólo ponía una hilera a z = 42) dejaba el anillo a
  oscuras; se añaden dos hileras a z = 14 y z = 62.
- Bidones y cajas arrimados a los muros para romper el vacío del suelo.

## A–01 · archivo biométrico / muelle de carga

- **Estanterías de carga** (`A01Rack1/2`) contra el muro oeste: tres niveles con
  banda luminosa, tres montantes y cajas de transporte.
- **Muelle**: plataforma con franja ámbar, topes laterales y línea de guiado.
- **Bancada de carga** (`A01ChargeBay`) con tres alojamientos emisivos, testigo
  ámbar y latiguillos.
- **Carro de transporte** (`A01Cart`) con cuatro ruedas y barra de arrastre, más
  dos bidones con anillo de bronce.
- **Pasillo marcado** con testas ámbar cada 2 m, de la puerta al muelle.
- **Tuberías y bandeja de cables** sobre la nave, baliza del muelle (en
  `indicators`) y rótulo nuevo «MUELLE · A–01 / CARGA DE EQUIPO».

## Rótulo de la galería

El cartel «GALERÍA AXIAL · EJE DE COMUNICACIÓN» estaba en el muro este de V–03 a
la altura de la cámara y se comía el plano en las vistas rasantes: pasa de
6,4 × 1,2 m en (30,6 · 3,4 · −40) a 5,2 × 0,95 m en (30,6 · 3,9 · −76), junto al
extremo de la galería.

## Capturas

`qa/capture_zones.tscn` incorpora la vista de A–01 (nueve zonas), se reencuadran
C–04 y A–01 y se regeneran las nueve imágenes `reports/ingame-*.png`. Hoja de
contacto 3 × 3: `reports/phase26-ingame.png`.

## QA

Sin cambios de contrato: `run_suite` 335, `validate_layouts` 65,
`validate_dressing` 110, `validate_files` 33, `validate_vault` 53,
`validate_bench_cycle` 51, `validate_operations` 77, `validate_transit` 154,
`validate_experience` 139, `validate_camera` 113, `validate_session` 95,
`validate_displays` 89, `validate_w01_ai` 66, `validate_power_grid` 45,
`validate_zone_traversal` 255, `validate_zone_graph` 303,
`validate_game_state` 17, `validate_resume` 8 → **2008 checks, 0 fallos**.

## Pendientes

1. El vídeo de las cámaras de vigilancia sigue siendo fósforo sintético; falta
   el `VideoStreamPlayer` con el material de la web.
2. C–04 necesita mobiliario «de escala humana» (carretillas, escaleras) para que
   los 72 m de nave no lean como un hangar vacío.
3. El banco de instrumentación de C–04 y los monitores de fósforo aún no están
   enganchados a `OperationsPanel` ni a `TelemetryFeed`.
