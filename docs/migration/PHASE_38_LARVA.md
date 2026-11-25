# Fase 38 · Larvas de H–01 (`Larva.ts`)

**Fecha:** 24 de noviembre de 2026
**Estado:** cerrada · `run_suite` **383 checks, 0 fallos** · `validate_larva` **44 checks**
**Punto de partida:** `f46f7fb` (fase 37)

Este era el último bloque de anatomía de W–01 que quedaba abierto: `Tentacles.ts`
y `Breath.ts` ya estaban portados en las fases 35 y 36, pero las larvas de los
tres vasos de observación de H–01 seguían sin gesto propio.

## 1. Un fallo de identificación previo

`zone_dressing.gd::_take_larva()` buscaba la criatura con una caja de 2,0–2,6 m
en X. En `workshop_pods.glb` esa caja no es la larva: es **la nube de burbujas**
del líquido (una sola malla de 48 vértices, `#9acead` al 52 %). El atrezzo
estaba descolgando esa nube dentro del pivote del corazón, escalándola 0,42 y
bajándola 5,38 m, y dejando a los vasos sin criatura.

Ahora el criterio es el de la web: el grupo de la larva es el hijo del vaso que
cuelga **grupos de tentáculos**, es decir, hijos `Node3D` por debajo del eje del
cuerpo (`position.y < −0,2`, que en el exportador son `−0,33`).

## 2. Lo que sí conserva el exportador

A diferencia de `vault.glb`, el lote de los vasos conserva la jerarquía de
three.js, así que el port es directo:

| Grupo | Posición | Contenido |
| --- | --- | --- |
| larva | `(0, 2,25, 0)` | cuerpo, branquias y membrana + tentáculos + ojo |
| tentáculo `j` | `(0,44·cos a, −0,33, 0,45·sin a)` | filamento (`#e5b2aa`) y cinco sedas (`#b98c79`) |
| ojo | `(0, 0,22, 0,6)` | párpado (`#673a4c`), esclerótica (`#d5b795`), iris, pupila y brillo |

Se cumple lo que dice la web: **8 + índice** tentáculos, o sea 8, 9 y 10 en los
tres vasos (medido: 8, 9 y 10).

## 3. `scripts/world/larva_rig.gd`

`LarvaRig.attach(larva, índice)` se cuelga del grupo de la larva y guarda la
rotación de reposo de cada tentáculo y del ojo. El gesto es una función pura del
tiempo, con las constantes exactas de `Larva.ts`:

| Pieza | Fórmula |
| --- | --- |
| tentáculo `j` | `x = 0,17·sin(t·1,35 + j·0,83)` · `z = 0,18·cos(t·1,26 + j·1,26)` |
| ojo | `y = 0,11·sin(t·0,8 + índice)` · `x = 0,055·cos(t·1,07)` |

`reset()` devuelve tentáculos y ojo al reposo. El latido, el vaivén y el giro del
conjunto siguen donde estaban, en `ZoneDressing.animate()`, copiados de
`Workshop.Pods.update()`:

| Pieza | Fórmula (`a = t·3,1 + índice·1,62`) |
| --- | --- |
| corazón (escala) | `p = max(0, sin a)^5` → `(1 + 0,12p, 1 − 0,065p, 1 + 0,1p)` |
| corazón (posición) | `y = 2,25 + 0,07·sin(a·0,4)` |
| corazón (giro) | `y = 1,27 + 0,23·sin(a·0,23)` |
| burbujas | `y = 0,92 + (t·(0,1 + (j mod 3)·0,023) + j·0,149 + vaso·0,69) mod 2,75`, 48 por vaso |

El pivote del corazón ya no escala 0,42: la larva exportada viene a tamaño real
(1,7 m de cuerpo dentro de un vaso de 3,2 m), así que el latido se aplica a
escala 1,0, como en la web.

## 4. Pruebas

`qa/validate_larva.gd` monta la zona H–01 completa y comprueba 44 cosas:

- tres vasos, tres rigs, tres ojos y tres larvas que **no** son la nube de
  burbujas (más de 8 hijos, no una `MeshInstance3D` suelta) y que van a escala
  real;
- 8, 9 y 10 tentáculos, en ese orden;
- las fórmulas del tentáculo 0, 3 y último a `t = 7,3 s`, y que ninguno se queda
  quieto;
- el ojo con su fase por vaso y el cabeceo;
- el reset limpio;
- el latido (escala, posición y giro) y las 48 burbujas que ascienden sin salir
  del vaso.

`run_suite` gana un bloque `_validate_larva()` con 8 checks (instancia H–01,
cuenta tentáculos y ojos, comprueba fórmulas, latido y burbujas). Total **383
checks, 0 fallos**.

Captura: `reports/ingame-h01.png` rehecha desde el juego real; se ven las tres
larvas dentro del líquido, con sus tentáculos y sus burbujas.

## 5. Pendiente que arrastra la fase

- El iris del exportador es una malla blanca sin textura (`#ffffff`): la web le
  pinta `createIrisTexture()`. Falta generar esa textura y aplicarla.
- El reflejo de las ventosas y la refracción del líquido dependen de los
  materiales del pase de alta fidelidad.
