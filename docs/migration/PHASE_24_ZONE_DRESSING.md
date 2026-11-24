# Fase 24 · Mobiliario y rotulación de las zonas

Fecha: 2026-11-24. Continúa la migración en `/home/user/NEXUS-Native`; la fuente
web (`nexus-w01-versiones`) no se ha modificado.

## Motivo

Las capturas de `zone_c04_shell.tscn` mostraban sólo la cáscara: los volúmenes
estaban portados, pero **ni las zonas ni los modelos** se habían migrado. Las
salas estaban vacías y no se parecían a la versión web.

## Qué se ha añadido

### `scripts/world/build_kit.gd` (`BuildKit`)

Réplica de las primitivas con las que la web monta toda la nave
(`Infrastructure.ts`, `Workshop.ts`):

| Primitiva | Web | Notas |
|---|---|---|
| `block` | `block()` | caja con material de la paleta |
| `drum` | `drum()` | cilindro; `face` lo tumba sobre Z |
| `ring` | `ring()` | toro; por defecto mira a +Z, `flat` lo tumba |
| `bar` | `tube()` | barra entre dos puntos con base compuesta a mano |
| `plaque` | `lettering()` | `Label3D` + chapa de grafito, tamaño ligado a la altura |
| `luminaire` | `luminaire()` | difusor emisivo + `OmniLight3D` opcional |
| `cabinet` | armarios de servicio | puertas, tiradores y testigos GLOW/AMBER |
| `floor_grid` | — | reservado (no se usa: la rejilla inventada no existe en la web) |

Paleta idéntica a la web: `METAL #53686c`, `GRAPHITE #29383d`,
`BRONZE #a16f45`, `WHITE #e6e6db`, `GLOW #72f9e5`, `AMBER #ffae69`,
`SEAL #1a2b30`, `STEEL #8fa4a8`, `WARM #ffe4c1`. Los materiales se cachean por
color/acabado y se comparten entre piezas.

### `scripts/zones/zone_dressing.gd` (`ZoneDressing`)

Nodo `Dressing` instanciado en las diez escenas de zona. Cada rama toma el
**volumen interior real** de la sala (constante `ROOMS`, derivada de
`manifests/migration/*_structural_shell.json`) para que nada quede dentro de las
paredes ni por encima del techo.

| Zona | Contenido |
|---|---|
| H–01 hidráulica | tres vasos de observación (cristal `opacity 0,035` y líquido `0,058` como la web), larva `w01_core` + `w01_tentacles` a escala 0,42, aros emisivos, desagüe de bronce, manómetro, luminaria; cuatro bancos de bombas con voluta, aro y testigo ámbar |
| B–02 turbinas | cuatro turbinas de 3,44 m con ocho aspas, buje y aro ámbar sobre bancos con rejillas; tres armarios; puerta de bóveda de 4,4 m con ocho pestillos, tres brazos y anillos emisivos; rótulos BÓVEDA y TURBINAS |
| Electricidad | ocho armarios del cuadro con puertas, tiradores y testigos, dos pantallas de fósforo con datos vivos y el cuadro principal; rótulo ELECTRICIDAD |
| Vigilancia | muro de seis pantallas CCTV con marco de luz, mesa de operación y dos sillas; rótulo VIGILANCIA |
| D–02 registros | nueve archivadores de cuatro cajones contra el muro este; rótulo REGISTROS |
| C–04 contención | malla de 24 postes con seis anillos emisivos y seis bases de bronce; rótulos CONTENCIÓN y GALERÍA |
| V–03 galería | ocho arcos con banda GLOW superior, bandas ámbar y luminaria por arco; rótulo GALERÍA AXIAL |
| V–03 crioteca | dos hileras de seis vitrinas con cámara de cristal iluminada, testigo frontal y tirador de bronce, más mesa; rótulo CRIOTECA |
| A–01 | taquillas biométricas y mostrador; rótulo ARCHIVO BIOMÉTRICO |
| Tránsito | cápsula con ventanales y banda emisiva, andén con bordillo y guías ámbar; rótulos ANDÉN 01/02 |

Todas las salas reciben además una fila de luminarias de techo (`_ceiling_lights`)
repartida por el eje mayor.

## Correcciones de la fase

- `bar()` usaba `look_at_from_position` con el nodo aún fuera del árbol y dejaba
  las tuberías sueltas en el origen de la zona; ahora compone la base a mano.
  
- `ring()` tenía el toro plano por defecto (los aros se veían de canto).
- El líquido y el cristal de los vasos eran demasiado opacos respecto a la web.
- Se descartó la rejilla de suelo emisiva: no existe en la web y “flotaba” sobre
  el suelo del shell.
- Coordenadas: el primer pase usó las coordenadas globales de la web, que en
  varios módulos caían **fuera** del volumen portado (B–02, D–02, Electricidad,
  Galería, Crioteca). Ahora todo se coloca respecto al rectángulo interior.
- `cabinet()` admite nombre propio para no acabar en `@Node3D@NN` (el validador
  cuenta piezas por nombre).

## Verificación

- `qa/validate_dressing.gd`: **95 checks** — nodo presente y con `zone_id`
  correcto en las diez zonas, recuento de mallas, mobiliario dentro de la sala,
  nada por encima del techo, piezas clave (3 vasos y larva, 4 turbinas y 8
  pestillos, 8 arcos, 12 vitrinas, 6 pantallas, 9 archivadores, armarios, malla),
  los diez rótulos de sector y la paleta del kit.
- `qa/run_suite.gd`: **332/332** (32 checks nuevos de mobiliario).
- Sin regresiones: `zone_graph` 303, `zone_traversal` 255, `transit` 154,
  `displays` 89, `camera` 113, `session` 95, `w01_ai` 66, `vault` 53.
- Capturas (`qa/capture_dressing.tscn`, Xvfb 1280×720) en
  `reports/dressing-{h01,b02,electrical,surveillance,d02,c04,v03_gallery,v03_cryo}.png`.

## Segunda pasada (24b): animación, ambiente y dispositivos

- **Animación del mobiliario** (`ZoneDressing.animate(t)`, con el contrato de
  `Pods.update`): 48 burbujas por vaso que ascienden y reinician a 2,75 m, latido
  y giro de la larva (`sin(t·3,1)`+ desplazamiento en Y y giro), giro de las aspas
  de cada turbina con ritmo propio, respiración de los anillos de contención y
  parpadeo de los testigos. `running=false` permite congelarla para capturas
  reproducibles. GIF de la secuencia en `reports/{h01,b02,c04}-anim.gif`.
- **Ambiente global**: `main.tscn` tenía `ambient_light_source = 3` (SKY) sin
  cielo, así que el ambiente salía **negro** y las caras en sombra se perdían.
  Ahora es `COLOR` con `(0,42, 0,55, 0,68)` a 0,72, más cerca del
  `AmbientLight(0xc1d7ed, 0.85)` de `Environment.ts`.
- **Luminarias**: energía 2,4 → 3,6 y alcance `width·2,8` mínimo 7 m.
- **Dispositivos interactivos recolocados**: las consolas del cuadro eléctrico
  (`ZoneNext`…`Illum`) estaban en `z = 52`, **fuera** de la sala (58,2–84) y las
  de vigilancia en `z = 56` (sala 66,2–84); ahora van contra el muro oeste de su
  módulo con giro que mira al interior. La pantalla de fósforo, junto a ellas.
- **Crioteca**: vitrinas con cuerpo de acero, zócalo, ventana, muestra iluminada
  y placa de bronce; mesa de vigilancia con dos monitores encendidos y sillas
  orientadas al puesto.
- **Capturas en el juego real**: `qa/capture_zones.tscn` arranca `main.tscn`,
  transita por las ocho zonas con `ZoneManager.transition_to`, coloca al operador
  y captura con HUD e iluminación del juego (`reports/ingame-*.png`).

## Pendiente

- Animación del mobiliario: burbujas y latido de los vasos, giro de las aspas,
  parpadeo de testigos y sillas.
- Atrezzo GLB de alta fidelidad, mamparos de `Visibility.ts`, controles táctiles
  de `Touch.ts`, coche y audio.
- **Auditoría de dispositivos pendiente en D–02, B–02 y crioteca**: los módulos
  `Files`/`Vault`/`BenchCycle` siguen colocando sus bandejas y estaciones con las
  coordenadas globales de la web (`files_module.apply_web_layout()` usa
  `(-25, -37,3)`, `(36,6, -86,2)`, `(-35,2, -25,8)`…), que en las cáscaras nativas
  caen fuera de la sala correspondiente. Requiere remapear el layout completo
  (fase 25) y no sólo los nodos de escena.
