# Fase 12 · Menú y carga real

La ejecución ya no entra automáticamente en C-04. `main.tscn` muestra un menú principal y mantiene jugador/cámara deshabilitados. Al pulsar «ENTRAR EN C-04»:

1. `ZoneManager.preload_zone` inicia `ResourceLoader.load_threaded_request` real.
2. La pantalla de carga consulta `load_threaded_get_status` y su progreso real.
3. Solo con estado `THREAD_LOAD_LOADED` se solicita la transición.
4. La pantalla desaparece tras `transition_finished(c04)`.
5. Se habilitan movimiento, gravedad, captura de cursor y mouse-look.

No hay temporizador ni progreso simulado. La QA acumulada valida menú inicial, inicio de precarga y pantalla visible: 58/58.

Capturas gráficas Forward Mobile 1280×720:

- `startup-main-menu.png`: `902ae731c737292459764a0da5dd47ed8bb422ce2f099be75ed2e40c81c2c158`.
- `startup-loading.png`: `a23fa1159d05ba5581f31870d7962881e8f7c3f06992e9fe10f342e162fa0ffe`.
- `startup-c04-ready.png`: `8c2acc64d4060a1a32cb6704916b96296602c14395585a442d2e254b1bfb2d82`.

La ejecución gráfica volvió a mostrar el aviso conocido de ObjectDB al cierre forzado del harness y audio dummy por bibliotecas ausentes; no se declara audio validado.
