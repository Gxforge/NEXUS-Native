# Fase 42 · Recorte por portales (`Visibility.ts`)

**Fecha:** 24 de noviembre de 2026
**Estado:** cerrada · `run_suite` **424 checks, 0 fallos** · `validate_visibility` **41 checks**
**Punto de partida:** `859cdb5` (fase 41)

`Visibility.ts` (122 líneas) es el último módulo de `src/scene` que faltaba por
portar. La web construye de una vez todo el complejo, así que se permite tirar
objetos enteros que quedan detrás de un tabique: cajas envolventes calculadas
una vez, proyectadas sobre el plano de la compuerta a través de la cámara. La
versión nativa hace lo mismo sobre las zonas cargadas, pero adaptando el origen
de las particiones y el criterio de "esto es un muro" a la geometría real.

## 1. El módulo (`scripts/world/visibility.gd`)

| Constante | Valor | De dónde sale |
| --- | --- | --- |
| `MARGIN` | `0,15 m` | `expandByScalar(0.15)` de la web |
| `TRAY_MARGIN` | `1,4 m` | `expandByScalar(1.4)` para las bandejas |
| `DOOR_MATCH` | `0,9 m` | tolerancia para emparejar la compuerta con su vano |
| `DEFAULT_HALF` / `DEFAULT_HEIGHT` | `2,28` / `4,55` | vano y altura de serie |
| `SIDE_SPAN` | `8,0 m` | corredor lateral por defecto |
| `MIN_APERTURE` | `0,012 m` | por debajo la compuerta se considera cerrada |
| `SCENE_OFFSET` | `(9; 14)` | `Main.SCENE_OFFSET_2D`: las zonas nativas se montan desplazadas respecto al plano de la web |

### Candidatos

Se recorren las zonas cargadas y se toma como candidata la primera pieza que sea
`MeshInstance3D` o lleve `use`, `scan` o `survey_id`. La caja es la unión de las
mallas que cuelgan de ella, en espacio de mundo, ampliada por el margen. Se
saltan las ramas con `mobile_hull` (malla de contención) y **la propia
`ZoneRoot`**: su caja abarca el módulo entero y cruzaría todos los planos.

### Particiones

Salen de `data/zone_graph.json`: cada conexión aporta `world_door` y
`portal_yaw_from` (0/180 → plano perpendicular a z; ±90 → perpendicular a x, los
dos laboratorios laterales). Sólo se consideran opacas las seis paredes que la
web afina a mano:

| Conexión | Vano (media anchura) | Alto | Nota |
| --- | --- | --- | --- |
| `c04_electrical` | `2,28` | `4,55` | prueba lateral a partir de `\|x\| > 17,6` |
| `c04_surveillance` | `2,28` | `4,55` | idem |
| `b02_v03_gallery` | `3,35` | `6,10` | el `open` del original |
| `v03_cryo_v03_gallery` | `1,70` | `3,40` | puerta de la bóveda |
| `h01_v03_gallery` | `2,17` | `4,02` | laboratorio lateral, corredor −70 → −54 |
| `d02_v03_gallery` | `2,17` | `4,02` | laboratorio lateral, corredor −90 → −74 |

La abertura viva es `media × apertura` de la compuerta `SectorDoor` más cercana
(emparejada por posición, a menos de 0,9 m). Sin compuerta en la escena el vano
se da por abierto, salvo `b02_v03_gallery`, que sigue la bandera
`gallery_open` — el parámetro `open` de la web.

### El criterio

Idéntico al original: si la caja está **por completo** del otro lado del plano y
su silueta proyectada se sale por la izquierda, por la derecha o por arriba del
vano, se oculta; si cruza el plano, se conserva. En los laboratorios laterales
se usa además el corredor (`span`) y el lado (`sign`) de la galería.

## 2. Dos añadidos que la web no necesitaba

### `probe(world)`

Antes de aplicar, cada partición se comprueba contra la geometría: rayos de 1,8
m que atraviesan el plano a un lado y otro del vano, a 0,8 / 1,6 / 3,0 m de
altura. Con menos de dos impactos la partición se descarta. Es lo que evita
borrar mobiliario visible: en el complejo nativo las zonas se sirven por
streaming (sólo hay una cargada), así que varias de las paredes que la web
necesitaba no existen como geometría. Resultado en las capturas:

| Vista | Props ocultos | Muros que sobreviven a `probe` |
| --- | --- | --- |
| C-04 | `8 de 454` | `c04_electrical`, `c04_surveillance` |
| Vigilancia | `0 de 68` | `c04_surveillance` |
| A-01 | `0 de 179` | — |
| Hub de tránsito | `0 de 102` | — |
| Crioteca / Electricidad | `0 de 189` / `0 de 122` | `v03_cryo`, `c04_electrical` |

### `SCENE_OFFSET`

Las zonas nativas están montadas 9 m en x y 14 m en z respecto al plano del
grafo (el `SCENE_OFFSET_2D` de `main.gd`). Sin corregirlo, las particiones caen
fuera de sitio y el recorte borra lo que no debe; el validador comprueba que las
dos constantes coinciden leyendo el mapa de constantes de `main.gd`.

## 3. Enganche

`SceneExperienceController` gana `zones_path` (`../../ActiveZones`). En `_ready`
se suscribe a `zone_ready` / `zone_unloaded` de `ZoneManager`; en cada
fotograma, si el jugador tiene control, reconstruye la lista cuando cambian las
zonas (y sólo entonces), aplica el recorte con la posición de la cámara y lo
restaura cuando el control se desactiva (menú, carga, capturas). `apply()`
devuelve cuántos props ocultó y `partition_ids()` sirve para depurar; las
capturas imprimen ambos en su línea `CAPTURE recorte:`.

## 4. Lo que costó

- **`survey_id` en la `ZoneRoot`**: el primer recuento dio *un* candidato por
  zona porque el recorrido se paraba en la raíz. Se excluye la raíz y se
  desciende a sus props.
- **El desplazamiento de las zonas**: sin los 9/14 m el recorte borraba
  mobiliario visible (A-01 perdía los ventiladores y la vitrina: 103 de 179
  props ocultos). Se detectó comparando la captura nueva con la publicada.
- **Los vanos abiertos**: recortar en las once conexiones del grafo también
  borraba props de la crioteca y del archivo. De ahí el filtro de las seis
  paredes opacas y la comprobación geométrica.
- **Instancias liberadas**: al transferir, la zona saliente se libera y las
  cajas guardadas apuntan a nodos muertos (`Trying to assign invalid previously
  freed instance`). Se valida con `is_instance_valid` antes de tipar.

## 5. Pruebas y capturas

`qa/validate_visibility.gd` (41 checks): las seis particiones del grafo real con
sus medios vanos, alturas, desplazamiento y corredores; los candidatos y los
márgenes de 0,15 / 1,4 m; el criterio conservador (no se oculta lo que cruza el
plano); la altura del vano; la compuerta cerrada y abierta; el restaurar; el
laboratorio lateral; la bandera de la galería; la reconstrucción de la lista; la
coincidencia de `SCENE_OFFSET` con `Main`.

`run_suite` suma `_validate_visibility()` (10 checks) y llega a **424 checks con
`failures: []`**. Las capturas `ingame-c04`, `ingame-a01`, `ingame-transit_hub`,
`ingame-electrical`, `ingame-surveillance` y `ingame-v03_cryo` se regeneraron y
se compararon píxel a píxel con las publicadas: sólo difieren en el ruido del
render.
