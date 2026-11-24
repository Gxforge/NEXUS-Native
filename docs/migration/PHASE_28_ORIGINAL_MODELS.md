# Fase 28 · Modelos originales y aspecto de la web

El usuario tenía razón en lo de fondo: las salas no se parecían a la web. La
causa no era una sola. Eran **tres** cosas a la vez.

## 1 · Los modelos

`assets/generated/source-batch/` guarda las exportaciones directas de la escena
de three.js (`workshop_pods.glb` 40 MB, `vault.glb` 5,3 MB, `transit.glb` 7,4 MB,
`larva_0…2.glb`, `vehicle.glb`, instrumentos…). Estaban ahí, sin usar: el
mobiliario se estaba reconstruyendo a mano con `BuildKit`.

`scripts/world/prop_library.gd` carga esos lotes una vez, separa sus grupos de
primer nivel —conservan la transformación original de la web— y los reparte:

| grupo | dónde se usa |
|---|---|
| `workshop_pods.glb` · `Node2/Node15/Node29` | los tres vasos de H–01 (base, cristal, anillos, pestillos, manómetros y la larva exportada) |
| `vault.glb` · `Node2` | la puerta de la bóveda de B–02 (aros, pestillos, brazos hidráulicos) |
| `transit.glb` · `Node15` | cápsula del andén (pendiente de colocar) |

La larva exportada se cuelga de un pivote `Specimen` (escala 2,381 para que el
latido de `animate()` —0,42 ± 12 %— deje la criatura a tamaño nativo) y así sigue
respirando con el resto del mobiliario. Las 48 burbujas por vaso se añaden al
grupo original.

La puerta de la bóveda se escala con la medida real del disco exportado
(7,18 m), no con la caja del grupo entero (que incluye el marco de obra):
`factor = 2·radio / 7,18`.

## 2 · El renderizador

`project.godot` estaba en **`rendering_method = "mobile"`**. En móvil no hay
SSAO, la iluminación por píxel es más tosca y el tonemap se aplana: de ahí la
sensación de plástico. Ahora:

```
renderer/rendering_method = "forward_plus"
```

## 3 · El ambiente y la losa

- `Environment` con **ACES** (`tonemap_mode 3`, exposición 0,95), **glow**
  (intensidad 0,30, umbral HDR 1,5) y **SSAO** (radio 1,1, intensidad 1,6).
- **`DirectionalLight3D`** `#a6caff` a 0,6 (el `main` de `Environment.ts`), sin
  sombra para que no se la coma el techo.
- **Suelo texturizado**: `assets/textures/floor_dark.png` reproduce el
  `createFloorTexture()` de la web (hormigón moteado + 9 juntas), repetido cada
  12 m con `uv1_scale` por sala. Estaba mal por dos motivos: la textura era
  casi negra en espacio lineal y, además, la textura importada seguía siendo la
  versión antigua (hacía falta `--import`). Ahora el suelo se lee como una losa
  de laboratorio con sus juntas.
- **Relleno de luz** por sala (`_build_fill`): tres omnis a media altura y tres
  «rebotes» a 0,7 m — el `floorBounce` de la web — porque las luminarias de
  techo están a 8 m y su atenuación no llega al suelo.
- **Polvo biológico** (`scripts/world/biological_dust.gd`): port de `Effects.ts`,
  170 partículas aditivas de 5,5 cm que suben y viajan con la cámara.

## Capturas

El sandbox renderiza por software (llvmpipe): Forward+ tarda minutos por zona y
en H–01 no llega a terminar. Las capturas de QA se hacen, por eso, con
`--rendering-method mobile` **solo para el PNG**; el proyecto sigue en Forward+.

```
xvfb-run -a --server-args="-screen 0 1280x720x24" \
  godot --rendering-method mobile --path . res://qa/capture_zones.tscn [-- h01 b02 …]
```

`qa/capture_zones.gd` acepta ahora una lista de zonas por línea de órdenes y se
regeneraron las nueve imágenes y la hoja `reports/phase28-ingame.png`.

## QA

`validate_dressing` cambia una comprobación: la puerta de B–02 ya no se valida
por sus ocho `Bolt*` procedurales sino por las **131 mallas del modelo original**.
Totales: **2014 checks, 0 fallos** (`run_suite` 335, `layouts` 65, `dressing` 116,
`files` 33, `vault` 53, `bench` 51, `operations` 77, `transit` 154,
`experience` 139, `camera` 113, `session` 95, `displays` 89, `w01_ai` 66,
`power_grid` 45, `traversal` 255, `zone_graph` 303, `game_state` 17, `resume` 8).

## Pendientes

1. Colocar la cápsula de `transit.glb` en el andén y el `vehicle.glb` en su zona.
2. Los puestos de `vault.glb` (`Node64…Node100`) y los `instrument_*.glb` siguen
   sin usar: son los siguientes candidatos.
3. Revisar el equilibrio de luces en H–01 y C–04 con una GPU real; el relleno se
   calibró a ojo sobre capturas en móvil.
