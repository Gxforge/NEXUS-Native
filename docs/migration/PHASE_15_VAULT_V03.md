# Fase 15 — Bóveda V–03 (`Vault.ts`)

**Objetivo:** portar el contrato interactivo de la bóveda de la web: secuencia de
apertura, estaciones de uso, cajones por proximidad, objetos y persistencia.
La geometría se queda para el pase de alta fidelidad; aquí manda la lógica.

## Qué se ha hecho

| Archivo | Cambio |
|---|---|
| `scripts/zones/vault_module.gd` | Nuevo. Secuencia de 22 s con las siete fases de la web, estaciones con radio de 4 m, cinco cajones con apertura por proximidad, caída de objetos, recogida e inventario, y serialización. |
| `scripts/zones/vault_station.gd` | Nuevo. `StaticBody3D` con el mismo contrato que `FieldPickup` (`get_interaction_prompt` / `interact`), de modo que el jugador la usa con **E** apuntando. |
| `zones/zone_v03_gallery.tscn` | Instancia `VaultModule`, la consola de la bóveda y el puesto de rearme con colisión. |
| `scripts/core/game_state.gd` | Guarda la bóveda en la partida (`SAVE_VERSION` 3 → 4). Si el guardado llega antes que la zona, el estado queda pendiente y se aplica al registrarse el módulo. |
| `qa/validate_vault.gd` | Nuevo, 53 checks. |
| `qa/run_suite.gd` | +10 checks de bóveda (167 en total). |

## Contrato portado tal cual

```
sellada  →  Validando (0 s)  →  Retirando cerrojos (0,8 s)  →  Liberando pestillos (5,2 s)
         →  Girando corona (9,8 s)  →  Despresurizando (13,9 s)
         →  Traslado hidráulico (16,2 s)  →  Abierta (22 s)
```

- **Estaciones** (`rearm` 24/−37,64 · `hydro` 7,5/−69,77 · `records` 29,5/−89,77, más
  la consola `vault`): se consideran al alcance a **≤ 4 m** (`distanceSquared < 16`).
- **Cajones**: la bandeja sale 0,85 m amortiguada a 5 s⁻¹; si el jugador está justo
  delante (±0,97 m), **se detiene antes de tocarle** y el objeto no asoma hasta
  que el factor supera 0,22. El cajón abierto bloquea el paso (`drawer_solid`).
- **Objetos**: `lamp`, `cell`, `sample`, `card`, `recorder`. La bóveda **no abre sin
  la tarjeta** `card` en el inventario; recoger guarda y persiste la partida.

## Cómo se usa desde el juego

```gdscript
var vault := $VaultModule as VaultModule
vault.track_player(player.global_position)   # opcional: hay seguimiento automático
vault.begin_opening()                        # arranca la secuencia
vault.use_station(&"vault", player)          # lo que llama la consola al pulsar E
vault.open_drawer(3, true)                   # el cajón de la tarjeta
vault.collect(&"card", player)               # recogerla al alcance
vault.to_dict()                              # estado para el guardado
```

El jugador sólo necesita apuntar y pulsar **E**: `VaultStation` devuelve el prompt
(`E · Abrir Consola de la bóveda V–03`) y el resultado va al HUD como mensaje.

## Verificación

```
godot --headless --path . --script res://qa/validate_vault.gd        → 53/53
godot --headless --path . --script res://qa/run_suite.gd             → 167/167
godot --headless --path . --script res://qa/validate_game_state.gd   → 17/17
godot --headless --path . --script res://qa/validate_power_grid.gd   → 45/45
```

## Lo que queda de la fase

- Geometría real de la bóveda (disco de 32 dientes, ocho cerrojos, pistones y
  brazos hidráulicos) desde el GLB de alta fidelidad, con las mismas cotas.
- Los cinco cajones como cuerpos físicos con animación, en lugar de la consulta
  `drawer_solid`.
- Encadenar la estación `records` con los archivos de D–02 (fase P-3) y `hydro`
  con H–01 (fase P-5), que hoy sólo devuelven su mensaje.
