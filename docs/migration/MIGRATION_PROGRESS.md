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
- [x] Mobiliario y rotulación de las zonas (fase 24: `scripts/world/build_kit.gd` + `scripts/zones/zone_dressing.gd`): vasos, turbinas, puerta de bóveda, armarios, muro CCTV, archivadores, malla de contención, arcos, vitrinas, bancos de bombas, andén y luces de techo, colocados dentro del volumen real de cada módulo; 95 checks + 32 en `run_suite` y ocho capturas en `reports/dressing-*.png`.
- [ ] Contenido interactivo real de esas 10 zonas (bóveda, CCTV, cuadro eléctrico, archivo óptico, hidráulica, cápsula de Transit) y atrezzo GLB de alta fidelidad.
- [ ] Bóveda V-03 completa: lector/tarjeta, fases de apertura, celdas, muestra, analizador y bitácora.
- [x] Grid/energía de instalación (fase 14: `scripts/systems/power_grid.gd`, port de `Power.ts`). Queda el panel 3D, la telemetría y el CCTV interactivo.
- [x] Bóveda V–03 (fase 15: secuencia, estaciones, cajones por proximidad, objetos y persistencia). Falta su geometría animada.
- [x] Archivo D–02 (fase 16: bandejas con giro, expedientes y bitácora). Faltan bancos de carga y el lector a pantalla completa.
- [x] Cuadro eléctrico y CCTV (fase 17: circuitos, mandos, contadores, informe y selector de cámaras). Faltan geometría, pantallas y vídeo.
- [x] Bancos técnicos (fase 18: cuna de carga en H–01 y analizador en B–02, con consumo real de la red).
- [x] IA y percepción de W–01 (fase 19: estados, cono de visión, audición, memoria, malla de contención). Faltan agarre/daño y tentáculos dinámicos.
- [x] Vasos de observación de H–01 (visual, fase 24): tres vasos con cristal, líquido, larva en suspensión, manómetro, desagüe y luminaria.
- [ ] Animación de los vasos (burbujas, latido) y resto de interactuables.
- [ ] Transit: cápsula/carro, asientos, llamadas, carga, freno y solver de cuatro apoyos del vehículo.
- [ ] Paneles de base de datos/mapa con el contenido completo de la web; ahora son una estructura inicial limitada a C-04/A-01.
- [ ] Audio, VFX, feedback fisiológico, settings/gráficos y paridad visual completa.
- [ ] Comparación A/B con Three.js, perfiles de rendimiento, soak tests y builds Android/Windows. No se ha hecho push ni publicación.

## Validación de esta iteración
- Godot 4.4.1 `--headless --editor --path . --quit`: importación/escaneo completado y scripts cargados.
- `qa/validate_zone_graph.gd`: 303 checks, 0 fallos (identidad, manifiestos, colisión, AABB, sockets, portales y solapes de las 12 zonas).
- `qa/validate_zone_traversal.gd`: 255 checks, 0 fallos (22 cruces por los portales con llegada a socket, una sola zona activa, liberación del módulo y un cruce físico caminando contra el umbral).
- `qa/run_suite.gd`: 300 checks, 0 fallos (validación estructural de las 12 zonas, streaming C-04↔A-01, HUD/paneles con mapa de 12 módulos, armas UV/crio, pickup por rayo, linterna y sockets).
- `qa/validate_game_state.gd`: 17 checks, 0 fallos (inventario, slots, puertas y serialización JSON, ahora con la red eléctrica dentro del guardado).
- `qa/validate_power_grid.gd`: 45 checks, 0 fallos (capacidad, carga, reparto, picos, disparo, rearme y persistencia de la red).
- `qa/validate_w01_ai.gd`: 66 checks, 0 fallos (estados, visión, audición, memoria, contención y persistencia).
- `qa/validate_bench_cycle.gd`: 51 checks, 0 fallos (cuna, analizador, corte por red, consumo y guardado).
- `qa/validate_operations.gd`: 77 checks, 0 fallos (circuitos, geografía de zonas, mandos, eco, contadores, CCTV y persistencia).
- `qa/validate_files.gd`: 33 checks, 0 fallos (bandejas giradas, tope por proximidad, expedientes en la bitácora y persistencia).
- `qa/validate_vault.gd`: 53 checks, 0 fallos (secuencia de la bóveda, estaciones a 4 m, cajones por proximidad, objetos, inventario y guardado).
- `qa/validate_resume.gd`: 8 checks, 0 fallos (continúa en A-01 y evita transición accidental al aparecer junto al portal).
- `qa/validate_zone_ownership.gd` (13 checks, política de propiedad espejo del grafo), `validate_contacts_survey.gd`, `validate_contact_fx.gd`, `validate_source_batch.gd`, además de los validadores de núcleo/ojos/tentáculos W-01: pasaron en la ejecución registrada.
- Las pruebas son headless. No prueban renderizado móvil real ni sustituyen builds de plataforma.

## Fase 20 · Tránsito y vehículo (P-7)
- `scripts/systems/capsule_transit.gd`: port de `Transit.ts` — andenes 102/2042 sobre el eje x = 15, cierre de puertas de 1,2 s tras 1,4 s de espera, traslado con smoothstep de 10 s, freno de retención, compuerta por proximidad, cinco asientos a 1,47 m, transferencia del carro en 4 s, `can_stand`/`inside`, carteles y persistencia.
- `scripts/systems/vehicle_physics.gd`: port de `VehiclePhysics.ts` con paso fijo de 1/120 s (masa 1260, motor 4100 N, punta 49 m/s, turbo −24/s con bloqueo de 3,5 s, integridad −(dv − 2,7)·1,65, marchas N/R/1–6).
- `scripts/systems/transit_console.gd`: los diez puestos `railCallA/B`, `railBrake`, `railLoad`, `railCar` y `railSeat0…4`.
- `zones/zone_transit_hub.tscn`: nodo `Transit` con cartel `Label3D` y los diez mandos; `GameState` guarda el bloque `transit` (`SAVE_VERSION` 8).
- `qa/validate_transit.gd`: 154 checks, 0 fallos.

## Fase 21 · Vista, pantallas y telemetría (P-8, primer bloque)
- `scripts/world/camera_controller.gd`: port de `CameraController.ts` — órbita con amortiguación del 6 % por frame y límites 3,1–13 m / polar 0,38–π·0,49, primera persona con aguante (14/s, espera 1,05 s, rearme 26), cadencia, balanceo de cabeza, agachado de −0,44 m, corona de escape y entrada del vehículo; 113 checks.
- `player.gd`: acciones `toggle_view` (V) y `crouch` (Ctrl); la altura base de la cámara se conserva al agacharse.
- Pantallas: `phosphor_display.gd` (640×320, 72 muestras), `telemetry_model.gd` (1024×576, 75 filas, tres páginas), `screen_surface.gd` (dibujo), `wall_screen.gd` (SubViewport + quad) y `telemetry_feed.gd`; montadas en `zone_electrical.tscn`; 89 checks.
- Captura nueva: `reports/displays-cam04.png` (CAM 04 y panel de fósforo con datos de simulación).

## Fase 22 · Estado de la experiencia y perfiles de calidad (P-8, segundo bloque)
- `scripts/core/experience_state.gd`: port del contrato de `SceneExperience.ts` (`nx`, `spend`/`action`, ranuras, rótulos y avisos, alcances) y de `DisplayQuality.ts` (densidad de render, FOV, sombras, brillo, vídeo); 139 checks.
- `GameState.experience` con el perfil gráfico y el estado del equipo en el guardado (`SAVE_VERSION` 9).
- `main.gd`: `apply_quality_category()` aplica el perfil al viewport, sombras y glow; **F3** recorre low/medium/high y el HUD lo muestra.
- `player.gd`: `apply_view_fov()` (68 en primera persona, 49/35 en órbita) al alternar la vista.
- Estabilizada la prueba intermitente «approach requests door opening» de la suite.

## Fase 23 · Ajustes, paneles y bitácora de sesión (P-8, tercer bloque)
- `scripts/core/session_state.gd`: capa de interfaz de `App.tsx` — calidad y sensibilidad persistidas, detección de dispositivo, navegación de paneles con las reglas de cierre de la web, pausa/reanudación/reinicio, consejos de una sola vez (0,55 s / 5,95 s) y bitácora de 60 entradas; 95 checks.
- HUD: paneles `cfg` (consejos, calidad BAJA/MEDIA/ALTA, deslizador de sensibilidad, manuales, reinicio) y `log`; la pausa mantiene la simulación detenida al abrir ajustes y vuelve a ella al cerrarlos.
- `GameState.session` con `log_event()` y guardado (`SAVE_VERSION` 10); `player.apply_look` escala con la sensibilidad; `main.gd` dispara los consejos y reinicia el encuentro.
- Captura nueva: `reports/panel-settings.png`.

## Fase 24b/25 · Atrezzo animado y planos nativos
- Fase 24b: `ZoneDressing.animate(t)` anima burbujas (48 por vaso), larvas, aspas, anillos y testigos; ambiente de `main.tscn` a `ambient_light_source = 2` con (0.42, 0.55, 0.68) y energía 0.72; luminarias a 3,6 de energía y alcance `w*2.8`; capturas `reports/ingame-*.png`.
- Fase 25: `FilesModule.apply_web_layout()` ancla las diez bandejas al muro oeste de D–02 (`WALL_X = 32.2`, paso 3,78, boca a +X) y `zone_d02_records.tscn` instancia las diez; `VaultModule` reparte puestos y cajones entre `EAST_X = 29.9` y `WEST_X = 24.4`; los cuatro tipos de dispositivo interactivo (bandeja, puesto de bóveda, bancada y mando) dejan de ser volumen invisible y se construyen con `BuildKit`; la platina de B–02 se mueve dentro de su sala.
- `qa/validate_layouts.gd` (65 checks) audita la posición de los nodos de las diez zonas contra `ZoneDressing.ROOMS` y exige mallas en los dispositivos; `run_suite` sube a 335. QA total: **2008 checks**. Detalle en `PHASE_25_NATIVE_LAYOUTS.md`.

## Fase 26 · Densidad de C–04 y A–01
- C–04: franja de peligro, pasarela perimetral con barandilla y borde luminoso, balizas de sector animadas, pórtico de mantenimiento, banco de instrumentación con tres pantallas de fósforo y dos hileras extra de luminarias (la fila central dejaba el anillo a oscuras). `reports/ingame-c04.png` reencuadrado.
- A–01: dos estanterías de carga, muelle con franja y topes, bancada de carga de tres alojamientos, carro, bidones, pasillo marcado, tuberías, baliza y rótulo «MUELLE». Vista propia en `qa/capture_zones.tscn` (nueve zonas).
- «GALERÍA AXIAL» reducido y desplazado al extremo de V–03 para que no se coma los planos rasantes. Hoja `reports/phase26-ingame.png`. QA total sin cambios: **2008 checks**. Detalle en `PHASE_26_ROOM_DENSITY.md`.

## Fase 27 · C–04 a escala humana y telemetría viva
- Carretilla, escalera de pasarela, conos, palés y cuatro filas de luminarias en la nave de contención (72 × 84 m): el anillo, el banco de instrumentación y el suelo dejan de estar a oscuras.
- La primera pantalla del banco de C–04 pasa a `kind = "telemetry"` con un `TelemetryFeed` (`C04Feed`) creado con el mobiliario: carga/temperatura de red, sujeto, integridad, distancia e intención en vivo.
- `validate_dressing` 110 → **116 checks** (pasarela, pórtico, carretilla, conos, pantallas y feed enlazado). Total: **2014 checks**, 0 fallos. Hoja `reports/phase27-ingame.png`. Detalle en `PHASE_27_CONTAINMENT_SCALE.md`.

## Fase 28 · Modelos originales y aspecto de la web
- `scripts/world/prop_library.gd` reparte los grupos de `assets/generated/source-batch/`: los tres vasos de H–01 y la larva salen ya de `workshop_pods.glb` y la puerta de la bóveda de B–02 de `vault.glb` (131 mallas), escalada por el disco real de 7,18 m.
- `project.godot` pasa de `rendering_method = "mobile"` a **`forward_plus`**: sin SSAO ni iluminación por píxel decente el laboratorio parecía de plástico.
- `Environment` con ACES + glow + SSAO, `DirectionalLight3D` `#a6caff`, suelo con la textura de `createFloorTexture()` (repetida cada 12 m), relleno de luz por sala con rebote a 0,7 m y polvo biológico de `Effects.ts`.
- Capturas con `--rendering-method mobile` (llvmpipe no da para Forward+): nueve zonas y hoja `reports/phase28-ingame.png`. Detalle en `PHASE_28_ORIGINAL_MODELS.md`.

## Fase 29 · Tránsito y puestos originales
- `vault.glb`: `Node83` y `Node89` son ya el mostrador y el terminal del puesto de control de la galería V–03 (escala 0,62).
- `transit.glb`: `Node4`/`Node9` van a los dos tornos del hub L–01 y `Node14` al plano del eje; la cápsula sigue procedural porque la web la construye con primitivas.
- Vista nueva de `transit_hub` en `qa/capture_zones.gd` (diez zonas) y hoja `reports/phase29-ingame.png`. `validate_dressing` 116 → **120 checks**; total **2018 checks**, 0 fallos. Detalle en `PHASE_29_TRANSIT_AND_STATIONS.md`.

## Fase 30 · Vehículo, calzada y consolas de crioteca
- `vehicle.glb` montado entero (chasis + cuatro ruedas) en la calzada; `zone_transit_road.tscn` gana su `Dressing` y `_build_transit()` se parte por zona para que la cápsula y el andén no se construyan fuera del túnel.
- Calzada con eje discontinuo y balizas cada 24 m; el tramo de vía con banda emisiva de guiado.
- Crioteca con `CryoConsole` (`Node98`) y `CryoReader` (`Node99`) de `vault.glb`.
- Validador nuevo `qa/validate_original_models.gd` (19 checks) que comprueba mallas de vasos, larva, puerta, puesto, consolas, tornos y vehículo. Total **2037 checks**, 0 fallos. Detalle en `PHASE_30_VEHICLE_AND_CRYO.md`.

## Siguiente bloque de trabajo
0. Ver `docs/migration/PARITY_WEB_NATIVE.md` para la comparación módulo a módulo con la web v15.1.
1. Verificar y ajustar el HUD/touch y el mapa en una build visible de Android.
2. ~~Migrar la bóveda V-03~~ hecho en la fase 15; sigue su geometría animada en el pase de alta fidelidad.
3. ~~Sistemas eléctricos/CCTV/archivos~~ hechos en las fases 16 y 17; quedan la geometría, las pantallas y el vídeo de las cámaras.
4. Migrar Transit/cápsula/vehículo con el solver de cuatro apoyos en `transit_hub`, `transit_road` y `transit_rail`.
5. Particionar el GLB combinado por zona para el pase de alta fidelidad y cerrar IA, deformación, audio y VFX con pruebas A/B.

Ver `PHASE_13_ZONE_MODULES.md` para el detalle de la iteración.
