# Fase 1 · Fundación modular y QA sintético

Godot validado: 4.4.1 stable official (`49a5bc7b6`). Infraestructura, no geometría final.

Implementado: Main; PersistentWorld; Player único; ZoneCatalog; GameState; Resources ZoneDefinition/DoorConnection; ZoneManager con carga `ResourceLoader.load_threaded_request`; transferencia por DoorSockets; liberación real de origen; zonas sintéticas C-04/A-01; puerta bidireccional; QA JSON.

Pruebas iniciales: importación, arranque y C-04→A-01→C-04. Se verificaron una zona activa, instancia anterior liberada, Player persistente y recuperación de solicitud inválida. Fue prueba headless y no gráfica.

Gate de streaming sintético superado. Las escenas sintéticas no se declaran contenido migrado.