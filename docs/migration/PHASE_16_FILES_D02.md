# Fase 16 — Archivadores D–02 (`Files.ts`)

**Objetivo:** portar el archivo de expedientes de la web: diez bandejas con
orientación propia, apertura con tope por proximidad, folio legible y lectura que
alimenta la bitácora de campo.

## Qué se ha hecho

| Archivo | Cambio |
|---|---|
| `scripts/zones/files_module.gd` | Nuevo. Diez bandejas en las coordenadas y giros de la web, apertura amortiguada a 7 s⁻¹ con tope frontal, colisión por bandeja, seis expedientes con su texto original y lectura a la bitácora sin duplicados. |
| `scripts/zones/files_tray.gd` | Nuevo. `StaticBody3D` interactivo: abre, cierra y lee según el estado de la bandeja. |
| `zones/zone_d02_records.tscn` | Instancia el módulo y tres bandejas con colisión. |
| `scripts/core/game_state.gd` | Guarda el archivo en la partida (`SAVE_VERSION` 4 → 5), con estado pendiente si la zona aún no existe. |
| `qa/validate_files.gd` | Nuevo, 33 checks. |
| `qa/run_suite.gd` | +8 checks (175 en total). |

## Contrato portado

- Coordenadas locales a la bandeja (`u`, `v`) a partir de su giro, igual que
  `Files.update`: por eso las bandejas giradas 90° se comportan como las frontales.
- Si el jugador está delante (`|u| < 1,73` y `v > 0`), la bandeja **se detiene a
  1,24 m** de él en lugar de empujarle.
- El folio sólo es legible cuando la bandeja ha salido más del **65 %**.
- Cada expediente entra en la bitácora como `dossier_N` en la zona `d02`, con
  categoría y texto; releerlo **no duplica** el registro.
- `solid(x, z)` reproduce el volumen de la web: `|u| < 1,82` y
  `−0,72 < v < 1,24 + 0,86·f`.

## Expedientes incluidos

Ciclo de retorno (Hidráulica), Memoria del perímetro (Observación),
Transferencia de carga (Turbinas), Cadena de custodia (Crioteca),
Inventario de turno (Archivo) y Parte de inspección (Registros) — el texto es el
de la web, sin reescribir.

## Verificación

```
godot --headless --path . --script res://qa/validate_files.gd         → 33/33
godot --headless --path . --script res://qa/run_suite.gd              → 175/175
godot --headless --path . --script res://qa/validate_vault.gd         → 53/53
godot --headless --path . --script res://qa/validate_power_grid.gd    → 45/45
```

## Lo que queda de la fase

- Geometría de las bandejas y del folio elevado (hoy es sólo estado y colisión).
- Lector de expedientes a pantalla completa en el panel de bitácora del HUD.
- Enlazar la estación `records` de la bóveda con este archivo (ya comparten zona
  `d02` en el grafo).
