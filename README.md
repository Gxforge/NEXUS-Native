# NEXUS Native

Migración nativa y modular de NEXUS 15.1 a **Godot 4.4** para Windows y Android.

> Estado actual: fundación técnica y primer corte vertical parcial C-04 ↔ A-01. No es todavía el juego completo ni una versión distribuible.

## Abrir en Godot

1. Instala Godot **4.4.1 stable**.
2. Clona o descarga este repositorio.
3. Importa `project.godot` desde el Project Manager.
4. Espera a que Godot importe los GLB.
5. Ejecuta `main.tscn`.

El renderer configurado es **Mobile**, coherente con el objetivo Android. Las carpetas `.godot/` y `android/` no se versionan.

## Implementado

- Arquitectura modular por zonas.
- Player persistente y estado global separado.
- `ZoneManager` con `ResourceLoader.load_threaded_request()`.
- Precarga, transferencia por sockets y descarga de zona anterior.
- Portal A/01 procedural con dos hojas, colisiones, sensor y movimiento.
- Primeras estructuras reales de C-04 y A-01 derivadas de NEXUS 15.1.
- Exportador determinista manifest → GLB sin dependencias Python externas.
- NEXUS QA LAB inicial con 46 comprobaciones.
- Capturas gráficas de validación bajo Vulkan Forward Mobile.

## QA

Con Godot disponible como `godot`:

```bash
godot --headless --editor --path . --quit
godot --headless --path . --script res://qa/run_suite.gd
```

La suite lógica actual debe terminar con `46` comprobaciones y cero fallos. Las pruebas headless no sustituyen las capturas gráficas.

## Estructura

- `assets/generated/`: GLB generados de forma reproducible.
- `manifests/migration/`: procedencia y dimensiones fuente.
- `scripts/core/`: estado, catálogo y streaming.
- `scripts/zones/`: ciclo de vida, puertas y estructura.
- `zones/`: escenas independientes.
- `qa/`: pruebas y captura gráfica.
- `reports/`: resultados y evidencias.
- `docs/migration/`: auditoría, arquitectura y progreso detallado.

Consulta [docs/migration/README.md](docs/migration/README.md) antes de continuar la migración.

## Fuente preservada

La referencia auditada es NEXUS 15.1, commit `f4e1e819a9c783374e79dbc99cde4597099aba11`. El proyecto web permanece independiente y no forma parte de este repositorio.
