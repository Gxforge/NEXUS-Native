# Arquitectura propuesta

```text
Main
├── PersistentWorld
│   ├── Player
│   ├── PlayerCameraRig
│   ├── WatcherCoordinator
│   ├── MissionState
│   └── GlobalAudio
├── ZoneManager
│   ├── ZoneRegistry
│   ├── ActiveZones
│   └── TransitionLayer
├── GlobalSystems
│   ├── SaveGame
│   ├── PowerGridState
│   ├── InventoryState
│   └── InteractionRouter
└── UI
```

## Persistencia

Autoloads solo para datos sin representación espacial: `GameState`, `SaveService`, `ZoneCatalog` y, si se justifica, `AudioDirector`. Player, cámaras, W-01 y zonas viven bajo `Main` y no se duplican.

Resources tipados: `ZoneDefinition`, `DoorConnection`, `WatcherState`, `WorldState` y `AssetManifest`. Guardan IDs/datos, nunca referencias Node hacia zonas descargables.

## Subsistemas

- `ZoneManager`: único propietario de instancias.
- `DoorController`: anima y solicita transición; no carga escenas.
- `WatcherCoordinator`: persiste IA/memoria e instancia un único cuerpo.
- `InteractionRouter`: desacopla raycast, UI y acciones.
- `PowerGridService`: 12 alimentadores, carga, temperatura y disparo.
- `TransitService`: estado de cápsula/carro separado de representación.
- `CameraDirector`: primera persona, órbita, CCTV y vehículo con una Camera3D principal activa.

Señales: `transition_requested`, `zone_load_started`, `zone_ready`, `player_transferred`, `zone_unloaded`, `door_state_changed`, `watcher_transfer_requested`, `world_state_changed`.

GDScript será tipado y modular; generación de mesh, IA, persistencia, UI y streaming no se mezclarán en archivos monolíticos.