# Progreso de migración web → Godot

Actualizado: 2026-11-24. La migración continúa en `/home/user/NEXUS-Native`; la fuente web no se ha modificado. Esto es un corte funcional parcial, no una declaración de paridad completa.

## Auditoría, fundación y pipeline ya existentes
- [x] Auditoría de los repositorios Web (`nexus-v15.1`) y Godot (`NEXUS-Native`).
- [x] Godot 4.4.1, jugador persistente, catálogo, estado, `ZoneManager`, carga threaded, transferencia por sockets y descarga real de zonas.
- [x] C-04 y A-01 con shells estructurales, colisiones, portal móvil y pruebas de streaming.
- [x] Doce módulos enlazados: grafo `data/zone_graph.json`, generador determinista de manifiestos/GLB/escenas, mapa esquemático en el HUD y recorrido automatizado de los 22 cruces.
- [x] Pipeline e inventario de assets de procedencia web; 23 recursos GLB validados con mallas en la pasada anterior.
- [x] W-01 nativo con núcleo, siete ojos y veinte tentáculos; validadores de geometría anteriores.

## Corte jugable nativo añadido
- [x] Movimiento WASD, cámara ratón/captura, carrera y resistencia; mapa de acciones para teclado.
- [x] Interacción por rayo con prompts y búsqueda de interactuables en la jerarquía; puertas de tránsito preparan precarga y solo transfieren al cruzar en la dirección correcta.
- [x] Inventario persistente, cinco quick slots, selección 1–5, asignación desde panel I y uso con R.
- [x] Recogida de linterna de campo en A-01, luz focal, batería y guardado/carga JSON.
- [x] Escaneo Q con fichas deduplicadas y persistencia de identificador, zona, detalles y posición.
- [x] Emisor UV y proyector criogénico con costes/recargas básicos; señuelo local L; recuperación y efecto frío en W-01.
- [x] HUD con estado, resistencia, barra rápida y paneles de inventario, base de datos, mapa de los dos módulos implementados y pausa/guardado.
- [~] Controles táctiles (D-pad, carrera, mirar por arrastre y acciones) añadidos al HUD; falta verificación en un dispositivo Android/iOS.
- [x] Continuación desde el último módulo y checkpoint de posición, cámara, energía, batería, ranuras, estados de puerta, fichas y memoria de W-01.
- [x] Se corrigieron ambos sockets del portal y el umbral ya no provoca un tránsito al aparecer junto a la puerta sin velocidad de cruce.

## W-01: progreso y límite actual
- [x] Estados IDLE/WATCHING/CURIOUS/AGGRESSIVE/ATTACK/RECOVERY y umbrales de distancia de la web; agresividad suavizada.
- [x] Memoria breve de jugador, percepción de movimiento simplificada, desplazamiento acotado al shell C-04 y reacción a UV/crio/señuelo.
- [ ] Todavía no hay paridad de `FieldSense` completa (visión/oído/24 sectores de riesgo), daño/agarre del jugador, sonido, recuperación visual completa ni deformación orgánica dinámica de tentáculos.

## Sistemas Web todavía pendientes de migrar
- [x] 10 zonas restantes de las 12 documentadas: registro, sockets, portales, hull estructural, colisión, luces y streaming real en ambos sentidos (fase 13).
- [ ] Contenido interactivo real de esas 10 zonas (bóveda, CCTV, cuadro eléctrico, archivo óptico, hidráulica, cápsula de Transit) y mobiliario detallado desde el GLB combinado.
- [ ] Bóveda V-03 completa: lector/tarjeta, fases de apertura, celdas, muestra, analizador y bitácora.
- [x] Grid/energía de instalación (fase 14: `scripts/systems/power_grid.gd`, port de `Power.ts`). Queda el panel 3D, la telemetría y el CCTV interactivo.
- [x] Bóveda V–03 (fase 15: secuencia, estaciones, cajones por proximidad, objetos y persistencia). Falta su geometría animada.
- [ ] Archivos, bandejas/documentos, bancos de carga y el resto de pickups/interactuables.
- [ ] Transit: cápsula/carro, asientos, llamadas, carga, freno y solver de cuatro apoyos del vehículo.
- [ ] Paneles de base de datos/mapa con el contenido completo de la web; ahora son una estructura inicial limitada a C-04/A-01.
- [ ] Audio, VFX, feedback fisiológico, settings/gráficos y paridad visual completa.
- [ ] Comparación A/B con Three.js, perfiles de rendimiento, soak tests y builds Android/Windows. No se ha hecho push ni publicación.

## Validación de esta iteración
- Godot 4.4.1 `--headless --editor --path . --quit`: importación/escaneo completado y scripts cargados.
- `qa/validate_zone_graph.gd`: 303 checks, 0 fallos (identidad, manifiestos, colisión, AABB, sockets, portales y solapes de las 12 zonas).
- `qa/validate_zone_traversal.gd`: 255 checks, 0 fallos (22 cruces por los portales con llegada a socket, una sola zona activa, liberación del módulo y un cruce físico caminando contra el umbral).
- `qa/run_suite.gd`: 167 checks, 0 fallos (validación estructural de las 12 zonas, streaming C-04↔A-01, HUD/paneles con mapa de 12 módulos, armas UV/crio, pickup por rayo, linterna y sockets).
- `qa/validate_game_state.gd`: 17 checks, 0 fallos (inventario, slots, puertas y serialización JSON, ahora con la red eléctrica dentro del guardado).
- `qa/validate_power_grid.gd`: 45 checks, 0 fallos (capacidad, carga, reparto, picos, disparo, rearme y persistencia de la red).
- `qa/validate_vault.gd`: 53 checks, 0 fallos (secuencia de la bóveda, estaciones a 4 m, cajones por proximidad, objetos, inventario y guardado).
- `qa/validate_resume.gd`: 8 checks, 0 fallos (continúa en A-01 y evita transición accidental al aparecer junto al portal).
- `qa/validate_zone_ownership.gd` (13 checks, política de propiedad espejo del grafo), `validate_contacts_survey.gd`, `validate_contact_fx.gd`, `validate_source_batch.gd`, además de los validadores de núcleo/ojos/tentáculos W-01: pasaron en la ejecución registrada.
- Las pruebas son headless. No prueban renderizado móvil real ni sustituyen builds de plataforma.

## Siguiente bloque de trabajo
0. Ver `docs/migration/PARITY_WEB_NATIVE.md` para la comparación módulo a módulo con la web v15.1.
1. Verificar y ajustar el HUD/touch y el mapa en una build visible de Android.
2. ~~Migrar la bóveda V-03~~ hecho en la fase 15; sigue su geometría animada en el pase de alta fidelidad.
3. Incorporar los sistemas eléctricos/CCTV/archivos y su estado persistente en `electrical`, `surveillance` y `d02`.
4. Migrar Transit/cápsula/vehículo con el solver de cuatro apoyos en `transit_hub`, `transit_road` y `transit_rail`.
5. Particionar el GLB combinado por zona para el pase de alta fidelidad y cerrar IA, deformación, audio y VFX con pruebas A/B.

Ver `PHASE_13_ZONE_MODULES.md` para el detalle de la iteración.
