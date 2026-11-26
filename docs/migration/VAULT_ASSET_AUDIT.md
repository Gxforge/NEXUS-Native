# Auditoría de los modelos de `vault.glb`

**Fecha:** 24 de noviembre de 2026 · verificado en el juego real (`main.tscn` →
`start_game()` → V–03) con Godot 4.4.1 headless.

`assets/generated/source-batch/vault.glb` (5,1 MB) es la exportación directa del
grupo de la bóveda de la web: **23 grupos de primer nivel y 284 mallas**. Se
carga en tiempo de ejecución con `PropLibrary`, que reparte los grupos entre
zonas; la raíz exportada se libera para no duplicar memoria.

## 1. La puerta de la bóveda: sí, entera

| Pieza | Grupo | Mallas | Medidas | Dónde |
| --- | --- | --- | --- | --- |
| Puerta completa (marco, disco, corona, brazos) | `Node2` | **131** | 14,8 × 7,6 × 2,6 m | Galería V–03, `(28,0 · 2,6 · −78,6)` a escala 1,8 |

No se reconstruye nada: llega entera del exportador y `VaultDoorRig` identifica
sus piezas por geometría (el `.glb` no conserva los grupos con nombre de
three.js). En el juego cargado se comprueba que el rig encuentra **disco, corona,
8 pestillos y 4 pistones** y que el grupo de la puerta tiene **las 131 mallas**.

## 2. La animación de apertura: sí, y medida en el juego

Secuencia de 22 s con las siete fases de `Vault.ts`, disparada por el puesto de
uso (raycast + E). Medición real en `main.tscn` con la zona cargada:

```
prompt sin tarjeta:  E · Abrir Consola de la bóveda V–03
interact sin tarjeta → Bóveda V–03 · falta la tarjeta de acceso
interact con tarjeta → Bóveda V–03 · Validando
```

| t | fase | disco z | disco x | corona |
| --- | --- | --- | --- | --- |
| 0 s | Validando | 0,08 | 0,00 | 0,00 |
| 1 s | Retirando cerrojos | 0,08 | 0,00 | 0,00 |
| 6 s | Liberando pestillos | 0,08 | 0,00 | 0,00 |
| 10 s | Girando corona | 0,08 | 0,00 | −0,99 |
| 13 s | Girando corona | 0,08 | 0,00 | −6,61 |
| 14 s | Despresurizando | 0,16 | 0,00 | −7,23 |
| 16 s | Despresurizando | 1,37 | 0,00 | −7,23 |
| 17 s | Traslado hidráulico | 1,40 | −0,25 | −7,23 |
| 22 s | **Abierta** | 1,40 | **−6,25** | −7,23 |

En el mismo seguimiento: los cuatro pistones suben 1,56 m entre 0,8 y 8,1 s y
los ocho pestillos 0,96 m entre 4,3 y 9,7 s. La corona da 2,3 vueltas
(−7,23 rad ≈ −2,3π). Al final el puesto responde `Bóveda V–03 · abierta`.

La puerta viaja al APK: `assets/.godot/imported/vault.glb-…scn` (1,87 MB) está
dentro de `NEXUS-Native.apk`, así que la animación también funciona en Android.

## 3. El resto del lote: se usa un 20 % de los grupos

| Grupo | Mallas | Medidas | Estado | Nombre en el juego |
| --- | --- | --- | --- | --- |
| `Node2` | 131 | 14,8 × 7,6 × 2,6 | ✅ usado | puerta de la bóveda |
| `Node83` | 7 | 3,2 × 2,5 × 1,2 | ✅ usado | `GalleryDesk` (galería) |
| `Node89` | 6 | 1,1 × 1,3 × 0,6 | ✅ usado | `GalleryTerminal` (galería) |
| `Node98` | 10 | 1,0 × 1,0 × 1,0 | ✅ usado | `CryoConsole` (crioteca) |
| `Node99` | 4 | 0,7 × 0,9 × 0,3 | ✅ usado | `CryoReader` (crioteca) |
| `Node65` | 7 | 3,2 × 2,5 × 1,2 | ❌ sin colocar | mesa de puesto de trabajo |
| `Node67` | 13 | 1,5 × 1,0 × 1,2 | ❌ | pantalla de ese puesto |
| `Node71` | 12 | 1,5 × 1,0 × 1,2 | ❌ | segunda pantalla |
| `Node74` | 7 | 3,2 × 2,5 × 1,2 | ❌ | mesa del segundo puesto |
| `Node76` | 12 | 1,5 × 1,0 × 1,2 | ❌ | pantalla |
| `Node80` | 10 | 1,5 × 1,0 × 1,2 | ❌ | segunda pantalla |
| `Node85` | 13 | 1,5 × 1,0 × 1,2 | ❌ | pantalla pareja del puesto de archivo |
| `Node88` | 8 | 1,3 × 0,6 × 0,6 | ❌ | terminal pequeño |
| `Node97` | 7 | 1,0 × 1,0 × 1,0 | ❌ | terminal |
| `Node64` | 9 | 2,0 × 1,0 × 2,0 | ❌ | consola junto al acceso |
| `Node90` | 5 | 2,2 × 8,1 × 2,0 | ❌ | armario alto (8,1 m) |
| `Node91` | 5 | 2,2 × 8,1 × 2,0 | ❌ | armario alto |
| `Node92` | 5 | 2,2 × 8,1 × 2,0 | ❌ | armario alto |
| `Node93` | 7 | 3,2 × 3,1 × 1,3 | ❌ | consola con tres objetos |
| `Node94` | 2 | 0,3 × 0,1 × 0,3 | ❌ | objeto pequeño |
| `Node95` | 2 | 0,3 × 0,1 × 0,3 | ❌ | objeto pequeño |
| `Node96` | 2 | 0,3 × 0,1 × 0,3 | ❌ | objeto pequeño |
| `Node100` | 0 | — | — | grupo vacío del exportador |

**Total: 5 de 23 grupos, 158 de 284 mallas (56 %).** Los 18 grupos restantes
(126 mallas) están en el `.glb` y en el APK, pero ninguna zona los instancia.

Los que más falta se nota que están: los **dos puestos de trabajo completos**
(`Node65/67/71` y `Node74/76/80`), los **tres armarios de 8,1 m** (`Node90/91/92`,
que encajarían en el archivo D–02) y los **terminales** `Node88`, `Node97` y
`Node64`.

## 4. Nota sobre el tamaño del paquete

El APK de 0.44.0 pesa 105 MB y dentro lleva escenas importadas que se usan poco:
`laboratory_all_sectors.scn` **27,3 MB** (el lote combinado de 71 MB, del que
sólo se toman algunos props), `workshop_pods.scn` 17,1 MB y las tres larvas
16,5 MB. Recortar el lote combinado a los grupos que realmente se usan es la vía
más directa para bajar de 100 MB sin tocar contenido.
