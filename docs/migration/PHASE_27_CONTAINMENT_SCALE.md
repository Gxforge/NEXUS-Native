# Fase 27 · C–04 a escala humana y telemetría viva

## Mobiliario

- **Carretilla** (`C04Forklift`) en el muro este: cuerpo de acero con faldón de
  grafito, cabina con barra de protección, cuatro ruedas, mástil inclinado,
  horquillas y baliza verde. Estaba pensada para leerse a distancia, así que se
  separa del anillo y se apoya en el muro (37,5 · 14) girada −2,3 rad.
- **Escalera de pasarela** (`C04Stair`): nueve peldaños con dos zancas, doble
  barandilla y testa ámbar, subiendo en tres metros hasta la cota de la
  pasarela (3,1).
- **Cinco conos de balizamiento** alrededor de la franja de peligro y **tres
  palés** con carga junto al acceso norte.
- **Iluminación**: la nave de C–04 mide 72 × 84 m y sus luminarias iban en una
  sola fila por el eje largo; ahora hay cuatro filas (z = 6, 34, 62 y la central)
  que reparten luz sobre el anillo, el banco de instrumentación y el suelo.

## Telemetría viva en el banco de instrumentación

De las tres pantallas del muro oeste, la primera deja el fósforo sintético y
pasa a **telemetría real**: su `kind` es `"telemetry"` y lleva un
`TelemetryFeed` (`C04Feed`) creado con el mobiliario que muestrea `GameState`
cada frame — carga y temperatura de la red, sujeto, integridad, distancia,
estado e intención. Las otras dos siguen mostrando el estado de la malla
(«CONTENCIÓN C–04 · MALLA ACTIVA · anillo n · tensión nominal»).

```gdscript
var feed := TelemetryFeed.new()
feed.name = "C04Feed"
add_child(feed)
feed.screen = screen      # el feed se engancha en código, no por NodePath
feed.set_process(true)
```

## QA

`validate_dressing` pasa de 110 a **116 checks**: pasarela, pórtico, carretilla,
cinco conos, tres pantallas y el `C04Feed` con su `screen` enlazada. Totales:

```
run_suite 335 · layouts 65 · dressing 116 · files 33 · vault 53 · bench 51
operations 77 · transit 154 · experience 139 · camera 113 · session 95
displays 89 · w01_ai 66 · power_grid 45 · traversal 255 · zone_graph 303
game_state 17 · resume 8          →  2014 checks, 0 fallos
```

Capturas regeneradas (nueve zonas) y hoja `reports/phase27-ingame.png`.

## Pendientes

1. Las otras dos pantallas de C–04 podrían alternar páginas con `cycle_page()`.
2. La carretilla no tiene colisión propia: si el jugador se acerca, la atraviesa
   (todo el atrezzo de `ZoneDressing` es decorativo).
3. El vídeo de CCTV sigue pendiente: el repositorio web no trae ningún fichero
   de vídeo (sólo `public/icon.svg` y los PNG del manifiesto), así que el
   fósforo sintético de `WallScreen` es hoy lo más fiel que hay.
