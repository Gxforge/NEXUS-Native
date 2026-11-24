# Fase 25 · Del plano web al plano nativo

La web coloca muebles, bandejas y consolas en coordenadas absolutas de su propia
planta (`Files.ts`, `Vault.ts`). Al portarlas a las salas nativas esas
coordenadas caían fuera del recinto. Esta fase reescribe la disposición de los
módulos para que cada pieza quede anclada a la pared de **su** sala, sin tocar el
contrato de juego (índices, giros y textos siguen siendo los de la web).

## Bandejas del archivo (D–02)

`scripts/zones/files_module.gd`:

```gdscript
const WALL_X := 32.2      # muro oeste de D–02
const SLOT_STEP := 3.78   # separación entre bandejas
z = -28.0 - index * SLOT_STEP   # de −28 a −62
rotation = PI / 2.0             # boca del cajón hacia +X (el pasillo)
```

- Las diez bandejas van en fila sobre el muro oeste, entre la entrada (z = −24)
  y el vano de la galería (z = −68).
- La dirección «hacia fuera» de una bandeja es `(sin(rot), 0, cos(rot))`, no
  `(-sin, 0, cos)`: `local_offset()` calcula `u = dx·cos − dz·sin`, de ahí el
  giro de 90°. El QA `validate_files` usa esa misma fórmula (`_ahead`, `_forward`).
- `zones/zone_d02_records.tscn` instancia ahora **diez** `FilesTray`
  (`Tray0…Tray9`, `rotation_degrees (0,90,0)`), una por bandeja del módulo; antes
  sólo existían tres y las otras siete no se podían ni ver ni abrir.

## Puestos de la bóveda (V–03)

`scripts/zones/vault_module.gd`:

| puesto | x | z |
|---|---|---|
| `vault` | 29.9 (este) | −44.0 |
| `rearm` | 24.4 (oeste) | −44.0 |
| `hydro` | 29.9 (este) | −56.8 |
| `records` | 24.4 (oeste) | −56.8 |

Cajones: `bank_a`/`bank_b` en x = 29.9, z = −31.2 y −37.6; `bank_c`/`bank_d` en
x = 24.4 con las mismas z; `bank_e` en (24.4, −50.4). `zone_v03_gallery.tscn`
acompaña con `VaultConsole (29.9, 0.62, −44)` a `(0,−90,0)` y
`RearmConsole (24.4, 0.62, −44)` a `(0,90,0)`, es decir, enfrentados a lo ancho
de la galería.

## Dispositivos visibles

Hasta esta fase los aparatos interactivos eran **sólo colisión**: se podía
pulsar E sobre un volumen invisible. Ahora cada uno se construye con `BuildKit`
en su `_ready()` y lleva rótulo propio:

| script | qué se ve |
|---|---|
| `scripts/zones/files_tray.gd` | archivador con cajón corredizo que sale 0,62 m según `tray_factor()`, tirador de bronce y folio que asoma sólo al final del recorrido |
| `scripts/zones/vault_station.gd` | pedestal de acero, tablero inclinado con pantalla emisiva y tres testigos |
| `scripts/systems/bench_station.gd` | bancada de 1,5 m con placa de trabajo emisiva, cuna, mordazas y tira de estado |
| `scripts/systems/operations_console.gd` | mando de pared con pantalla, palanca de bronce, testigos rojo/verde y rótulo con el nombre del mando |

Los rótulos se colocan **por encima** del aparato y con `pixel_size` pequeño para
que no se pisen en perspectiva (antes se solapaban a la altura de la vista).

En `zone_b02_turbines.tscn` la platina del analizador estaba en
`(20, 0.6, −32)`, fuera de B–02 (`z −24…0`); pasa a `(13.2, 0.6, −3.2)` junto a
los turbos, girada 180° hacia la sala.

## Auditoría automática

- `qa/validate_layouts.gd` (**65 checks**): recorre el primer nivel de cada zona
  y comprueba que ningún nodo con significado cae fuera de `ZoneDressing.ROOMS`
  (profundidad 2, `global_position`, subárboles `Portal`/`DoorSockets`/
  `StructuralShell`/`Dressing`/dispositivos excluidos), revisa el reparto de
  bandejas y puestos (dentro de la sala, separados > 2 m, boca al pasillo) y
  exige **cuatro mallas o más** por dispositivo interactivo (mallas, no sólo
  colisión).
- `qa/run_suite.gd` incorpora el mismo par de comprobaciones de módulo: **335
  checks**.
- Capturas: `reports/ingame-{h01,b02,c04,d02,v03_gallery,v03_cryo,electrical,
  surveillance}.png` recapturadas con vistas nuevas (D–02 racheado por el muro
  de bandejas, vigilancia con muro de cámaras + mesa + mandos, galería con los
  dos puestos enfrentados) y hoja `reports/phase25-ingame.png`.

## Estado del QA

```
run_suite              335/335
validate_layouts        65/65
validate_dressing      110/110
validate_files          33/33
validate_vault          53/53
validate_bench_cycle    51/51
validate_operations     77/77
validate_transit       154/154
validate_experience    139/139
validate_camera        113/113
validate_session        95/95
validate_displays       89/89
validate_w01_ai         66/66
validate_power_grid     45/45
validate_game_state     17/17
validate_resume          8/8
validate_zone_traversal 255/255
validate_zone_graph    303/303
                       2008 checks
```

## Pendientes

1. C–04 y A–01 siguen con poca densidad de mobiliario respecto a la web.
2. El cartel «EJE DE COMUNICACIÓN» de la galería queda demasiado cerca de la
   cámara en los planos rasantes; hay que reducirlo o subirlo al techo.
3. Falta el vídeo real de las cámaras: los seis monitores de vigilancia usan
   fósforo sintético (`WallScreen.push_phosphor`).
