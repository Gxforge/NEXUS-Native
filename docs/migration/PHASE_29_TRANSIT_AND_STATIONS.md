# Fase 29 · Tránsito y puestos originales

Segunda tanda de modelos de `source-batch` conectados al juego. La primera
(fase 28) llevó los vasos de H–01 y la puerta de la bóveda.

## `vault.glb` · puesto de control de la galería

| grupo | medida original | uso |
|---|---|---|
| `Node83` | 3,25 × 2,54 × 1,25 | `GalleryDesk`, el mostrador del puesto de V–03 |
| `Node89` | 1,15 × 1,35 × 0,63 | `GalleryTerminal`, la consola sobre el mostrador |

Van a escala 0,62 —la galería tiene 8 m de ancho— arrimados al muro oeste a la
altura de z = −52, girados 90° para mirar al eje.

## `transit.glb` · hub L–01

`transit.glb` no trae una cápsula: trae **la estación entera**, con módulos de
41 × 8,7 × 50 m cada 50 m a lo largo del eje. Del lote se aprovechan las piezas
que sí encajan en la nave nativa:

- `Node4` y `Node9` → `Torno1` y `Torno2`, los dos tornos de acceso de 4,02 ×
  5,36 × 0,56 m, colocados a los lados del andén (10 · 90 y 10 · 104).
- `Node14` → `PlanoEje`, el plano de líneas de 8,55 m que se monta en el muro
  oeste de la nave a escala 1,6.

La cápsula sigue siendo procedural (`CapsuleShell`): no hay modelo de cápsula en
la web, el vehículo del andén se construye en `Transit.ts` con primitivas.

## Vista nueva

`qa/capture_zones.gd` gana la vista de `transit_hub` —(0 · 86) mirando a
(16 · 1,8 · 104), con los tornos a la izquierda y la cápsula al fondo— y la de la
galería se reencuadra para enseñar el eje completo con los dos puestos laterales.

## QA

`validate_dressing` sube de 116 a **120 checks**: tornos, plano del eje, puesto
y terminal. Totales: **2018 checks, 0 fallos**.

```
run_suite 335 · layouts 65 · dressing 120 · files 33 · vault 53 · bench 51
operations 77 · transit 154 · experience 139 · camera 113 · session 95
displays 89 · w01_ai 66 · power_grid 45 · traversal 255 · zone_graph 303
game_state 17 · resume 8
```

Hoja de las diez zonas: `reports/phase29-ingame.png`.

## Siguientes modelos por conectar

1. `vehicle.glb` (2,25 × 1,68 × 4,6) en `transit_road`.
2. Los puestos `Node64`, `Node97`, `Node98`, `Node99` de `vault.glb` (consolas
   de 1–2 m) para la crioteca y el archivo.
3. `instrument_0/1/2.glb` (14–38 cm): son los instrumentos de guante, van con el
   sistema de `Glove.ts`, no con el mobiliario.
4. Un módulo de `transit.glb` a escala 0,5 en el hub para cerrar la estación.
