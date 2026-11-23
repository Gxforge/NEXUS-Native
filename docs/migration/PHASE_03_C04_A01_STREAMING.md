# Fase 3A · Corte vertical C-04 ↔ A-01

## Alcance

Integra el portal A/01 reconstruido en las dos zonas sintéticas y valida la secuencia real de aproximación, precarga, apertura, cruce, transferencia y descarga. Las salas siguen siendo bancos sintéticos; no se declaran C-04/A-01 visualmente migradas.

## Sensor original

La lógica fuente abre A/01 cuando el jugador está a menos de 3,4 m en X y 4 m en Z del portal. Se trasladó a un `Area3D` de huella `6,8 × 8,0 m`, altura técnica 3,6 m. El umbral de cruce usa `4,4 × 0,5 m`.

## Flujo implementado

1. Player entra en `ProximitySensor`.
2. `StreamingSectorDoor` solicita apertura y llama `ZoneManager.preload_zone()`.
3. ResourceLoader carga la PackedScene en segundo plano mientras la puerta se abre.
4. Al cruzar `TransitionThreshold`, se reutiliza la solicitud ya cargada/en curso.
5. ZoneManager instancia destino, espera `zone_ready`, mueve Player al socket y activa la zona.
6. Desactiva, desconecta audio local y libera la zona anterior.
7. El mismo flujo funciona desde el lado A-01 hacia C-04.

## Código

- `scripts/zones/streaming_sector_door.gd`
- `scripts/core/zone_manager.gd`: precarga y consulta de estado.
- `zones/synthetic/zone_c04_synthetic.tscn`: instancia `PortalA01`.
- `zones/synthetic/zone_a01_synthetic.tscn`: instancia `PortalC04` rotado 180°.
- `scenes/validation/a01_portal_assembly.tscn`: sensores y umbral.

## QA

38/38 comprobaciones en Godot 4.4.1:

- Sensor `6,8 × 8 m` y umbral de 4,4 m.
- Portal real integrado en C-04 sintético.
- Preload A-01 terminado antes del cruce.
- Apertura solicitada al aproximarse.
- Cruce C-04→A-01 por el portal.
- C-04 descargada y referencia liberada.
- Player persistente, sin duplicación.
- Preload y retorno A-01→C-04 por la puerta gemela.
- Una sola zona activa al terminar.

Prueba headless para lógica/streaming. Las capturas gráficas de la puerta de la fase 2B siguen siendo válidas; esta fase no afirma que las salas sintéticas representen el laboratorio final.