# Fase 32 · Luminarias, taquillas, paneles y pantallas originales

Cuarta tanda de modelos originales, y la primera que cambia **todas las salas a
la vez**: el techo deja de ser una barra de dos bloques y pasa a ser la luminaria
que la web repite 38 veces.

## `laboratory_all_sectors.glb`, el lote grande

Este `.glb` es el laboratorio entero: 195 grupos de primer nivel, miles de
mallas. Todos los hijos se llaman `Node`, así que `PropLibrary.groups()` (que
indexa por nombre) no sirve: se añadió `children_of()` en orden de exportación y
una búsqueda por **forma** (número de mallas + caja envolvente).

| Familia | Forma | Piezas | Uso |
|---|---|---|---|
| Luminaria | 4 mallas, 3,20 × 0,30 × 0,35 m | 38 | techo de las doce zonas |
| Taquillas | 13 mallas, 3,22 × 3,22 × 1,01 m (9 puertas) | 4 | C–04 y A–01 |
| Panel mural | 5 mallas, 2,88 × 3,84 × 0,19 m | 4 | electricidad y vigilancia |

La luminaria es carcasa metálica `#53686c`, cuerpo oscuro `#131e23`, difusor
`#9dd4dd` y una tira `#29383d`. Como el exportador no guarda emisión, se le pone
un `material_override` por zona con la tinta del techo (`#cfe9f2` en C–04,
`#bfe0e6` en vigilancia, `WARM` en el resto) y una omnis de 3,6 W, igual que
antes.

## Un fallo de memoria que valió la fase

La primera versión pedía 96 luminarias y dejaba el lote entero cacheado. Al
cambiar de zona el proceso moría con `Killed` (exit 137) en la octava captura:
2.000 mallas residentes más 96 clones por sala. Ahora `family()` guarda **una**
copia de la pieza y libera el resto del lote, y cada luminaria se clona bajo
demanda. Además `groups()` y `children_of()` descartan las entradas liberadas
(antes, al instanciar dos veces la misma zona, saltaba «Trying to cast a freed
object»).

## Pantallas con el plano exportado

`WallScreen` ya no genera un `QuadMesh`: usa el plano original, `display.glb`
(1,00 × 0,50 m) para los paneles de fósforo y `telemetry_screen.glb`
(2,36 × 1,33 m) para el `CAM 04`, escalado al tamaño pedido. Se conservan UV y
proporción, y el validador comprueba que la cara tiene **cuatro vértices**.

## Lo que se dejó fuera, y por qué

- `effects.glb` — es el campo de polvo de 170 puntos. Ya está portado como
  `GPUParticles3D` con el mismo número, la misma caja de 18 × 7,2 × 15 m y el
  mismo `#a88e87`; montar el `.glb` lo duplicaría congelado.
- `cockpit.glb` — cuadrilátero de 0,39 × 0,14 m para la vista de conducción. No
  hay modo cabina nativo todavía; entra cuando se porte el coche.

## QA

`qa/validate_original_models.gd` sube de 19 a **42 checks**: familia de la
luminaria, difusor localizado, clones independientes, cada luminaria con su luz
y sus cuatro mallas en tres zonas, dos bancos de nueve puertas en C–04 y A–01,
panel mural en electricidad y vigilancia, y las dos pantallas con su plano
original de cuatro vértices.

```
run_suite 335 · layouts 65 · dressing 120 · original_models 42 · first_person 36
files 33 · vault 53 · bench 51 · operations 77 · transit 154 · experience 139
camera 113 · session 95 · displays 89 · w01_ai 66 · power_grid 45
traversal 255 · zone_graph 303 · game_state 17 · resume 8
                                            →  2096 checks, 0 fallos
```

Capturas nuevas de las diez zonas en `reports/ingame-*.png`; hoja de contacto en
`reports/phase32-tech-dressing.png`.
