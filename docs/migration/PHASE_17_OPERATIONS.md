# Fase 17 — Cuadro eléctrico y CCTV (`Operations.ts`)

**Objetivo:** portar el mando del área técnica de la web: circuitos declarados,
selección por zona y derivación, interruptores, límites eco, contadores, informe
maestro, niveles de iluminación y el selector de las diez cámaras.

## Qué se ha hecho

| Archivo | Cambio |
|---|---|
| `scripts/systems/operations_panel.gd` | Nuevo. Contrato completo de `Operations.ts`: 19 circuitos (12 inversores, 4 extractores, cargador, analizador, luz de vía), `light_zone`, `area`, selección zona/derivación, `branch`, los once mandos (`zoneNext`, `deviceNext`, `zoneSwitch`, `ecoMaster`, `branchSwitch`, `report`, `illum`, `camNext`, `camPrev`, `feedN`, `limitN`, `meterN`), contadores de inversor, informe maestro de cinco páginas y CCTV de diez canales. |
| `scripts/systems/operations_console.gd` | Nuevo. Consola física: apunta y pulsa **E** para emitir un mando; el HUD muestra el resultado. |
| `zones/zone_electrical.tscn` | Cinco mandos: selector de zona, selector de derivación, interruptor de zona, palanca de derivación e iluminación. |
| `zones/zone_surveillance.tscn` | Tres mandos: avanzar/retroceder cinta de cámaras y cambiar página del panel maestro. |
| `scripts/systems/power_grid.gd` | `for_laboratory()` se divide en `apply_laboratory_circuits()` para respetar el orden de la web (inversores primero). |
| `scripts/core/game_state.gd` | El cuadro vive en la partida (`SAVE_VERSION` 5 → 6). |
| `qa/validate_operations.gd` | Nuevo, 77 checks. |
| `qa/run_suite.gd` | +11 checks (186 en total). |

## Contrato portado

- **Zonas de iluminación** (`lightZone`): Axial, Electricidad, Vigilancia,
  Contención, Archivo/Turbinas, Crioteca, Hidráulica, Registros, Galería — mismos
  umbrales de coordenadas que la web.
- **Sala técnica** (`area`): Electricidad en `x>17,4` y Vigilancia en `x<−17,4`,
  con el mismo rango de `z`.
- **Interruptores**: apagar una derivación de `Generación` apaga su alimentador
  (`feeds[i]`); un `Extractor` mueve su ventilador (`fans[i]`); los circuitos
  bloqueados (`locked`) no se tocan — igual que `Operations.branch`.
- **Interruptor de zona**: si alguna derivación está apagada, las enciende todas;
  si están todas, las apaga.
- **Eco**: limita el inversor seleccionado a 14 kW (28 kW nominales).
- **Iluminación**: 100 % → 55 % → 20 %; con la red caída el factor efectivo es
  0,07 (casi a oscuras).
- **Contadores**: `INV n / EN LÍNEA · ECO · AISLADO`, cuatro páginas (kW, A, °C,
  kWh) y subtítulo `400 V CC / 14–28 kW NOM.`
- **Informe maestro**: balance, demanda, pérdidas, zona seleccionada y estado de
  la derivación.
- **CCTV**: diez cámaras con nombre y posición; el selector muestra seis canales;
  avanzar salta cuatro y retroceder seis, con vuelta por módulo 10; el vídeo sólo
  existe en Vigilancia.

## Verificación

```
godot --headless --path . --script res://qa/validate_operations.gd  → 77/77
godot --headless --path . --script res://qa/run_suite.gd            → 186/186
godot --headless --path . --script res://qa/validate_power_grid.gd  → 45/45
godot --headless --path . --script res://qa/validate_vault.gd       → 53/53
godot --headless --path . --script res://qa/validate_files.gd       → 33/33
```

## Lo que queda de la fase

- Geometría del cuadro: paredes, armarios, cables y lámparas con su circuito
  (`bindLights`), incluido el tendido de cables de la web.
- Pantallas reales: los `Display` de canvas de la web hay que rehacerlos con
  `SubViewport`/`TextureRect` en Godot.
- Vídeo de las cámaras: diez `Camera3D` renderizando a `SubViewport` y la
  conmutación por banco cuando el jugador está en Vigilancia (la lógica de
  selección ya está hecha y probada).
