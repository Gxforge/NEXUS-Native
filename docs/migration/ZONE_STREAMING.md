# Streaming de zonas

Máquina: `IDLE → VALIDATING → REQUESTING → LOADING → STAGING → TRANSFERRING → RELEASING → IDLE`, con `FAILED` recuperable.

1. Puerta resuelve `DoorConnection`.
2. ZoneManager valida requisitos y evita duplicados.
3. `ResourceLoader.load_threaded_request(path)`.
4. Consulta progreso por frame mientras anima/transiciona.
5. Con `THREAD_LOAD_LOADED`, obtiene PackedScene, instancia en ActiveZones y espera `zone_ready`.
6. Alinea sockets, transfiere un único Player y sincroniza puerta gemela.
7. Conserva origen+destino durante ventana segura.
8. Serializa estado local, desconecta señales, detiene proceso/física/audio y hace `queue_free()` del origen.
9. Confirma liberación y recursos exclusivos sin referencias.

## Reglas

- No ocultar habitaciones completas como sustituto de descarga.
- Assets exclusivos solo referenciados por su zona; compartidos bajo `assets/shared`.
- Persistir IDs/datos, no NodePath hacia zonas descargables.
- Máximo zona actual + destino, salvo prueba explícita de visibilidad simultánea.
- Bóveda: preparar Galería al comenzar secuencia de 22 s.
- L01: precargar hub; carretera/cápsula según ruta.
- A-01/B-02: precarga en volumen de aproximación para vista a través de puerta.

## W-01

`WatcherCoordinator` persiste IA y memoria. Antes de descargar su zona: congelar tick, serializar transform/estado/objetivo, decidir zona lógica, liberar cuerpo y reinstanciar controladamente. Nunca dos cuerpos. Si las reglas originales no permiten atravesar una puerta, W-01 permanece lógicamente en C-04.