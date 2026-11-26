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

## Fase 31 · Guante, instrumentos y mangas en primera persona
- `touch_rig_assets.glb` montado bajo la cámara: seis poses de guante, los tres instrumentos de `Instruments.ts`, el guante de linterna, cuatro mangas y dos codos, con el balanceo, el gesto de alcance y el retroceso de `Touch.ts`.
- `scripts/world/first_person_rig.gd` (nuevo) + `_reach()` en `player.gd` (interactuar, escanear, disparar y señuelo).
- `qa/validate_first_person.gd` (36 checks) y `qa/capture_first_person.tscn` con tres tomas en C–04. Total **2073 checks**, 0 fallos. Detalle en `PHASE_31_FIRST_PERSON_KIT.md`.

## Fase 32 · Luminarias, taquillas, paneles y pantallas originales
- `laboratory_all_sectors.glb` se usa por familia (forma + número de mallas, porque todos los grupos se llaman `Node`): la luminaria de techo de 38 piezas sustituye la barra procedural en las doce zonas, más taquillas de nueve puertas en C–04 y A–01 y panel mural en electricidad y vigilancia.
- `WallScreen` monta el plano original (`display.glb` 1,00 × 0,50 y `telemetry_screen.glb` 2,36 × 1,33).
- Arreglado el consumo de memoria del lote grande (mataba el proceso en la octava zona) y las referencias a nodos liberados en `PropLibrary`. `validate_original_models` 19 → 42 checks. Total **2096 checks**, 0 fallos. Detalle en `PHASE_32_CEILING_AND_SCREENS.md`.

## Fase 33 · Ojos de W–01 y entorno metálico
- `scripts/entities/w01_eyes.gd`: port de `EyeSystem.ts` + `OcularSurface.ts` sobre `w01_eyes.glb` (siete ojos, catorce párpados parametrizados con la rejilla 33 × 8, seguimiento, pupila reactiva, parpadeo y cierre por pulso UV).
- `scripts/entities/w01_materials.gd`: suavizado de los `metallic = 1,0` del exportador; `main.tscn` gana cielo procedural con `reflected_light_source = SKY` para que el metal tenga qué reflejar.
- `qa/validate_w01_eyes.gd` (18 checks) + bloque en `run_suite` (7). Total **343 checks**, 0 fallos. Capturas `reports/eyes-*.png`, hoja `phase33-eyes.png`, `w01-c04-first-look.png` y las diez zonas. Detalle en `PHASE_33_EYES_AND_METALS.md`.

## Fase 34 · Mandíbula y dentadura de W–01
- `scripts/entities/w01_jaw.gd`: port de `Head.ts` sobre `w01_core.glb`; los 26 dientes se mueven entre el ancla de reposo y la abierta (`0,34·sin a`) y la apertura se amortigua a 16 s⁻¹ antes de entrar en el *blend shape* de `Head`/`Gum`/`Throat`.
- `w01_actor.gd`: `jaw` en `_ready` y `_set_mouth(jaw.update(...))`. `qa/validate_w01_jaw.gd` (9 checks) y bloque de 6 en `run_suite`. Total **349 checks**, 0 fallos. Captura `reports/w01-maw.png`. Detalle en `PHASE_34_JAW.md`.

## Fase 35 · Aire y zumbido procedurales
- `scripts/systems/breath_audio.gd`: port de `Breath.ts` sin ningún recurso de audio — ruido de dos segundos con el filtro de un polo de la web a través de un paso banda (540 ↔ 920 Hz, Q 0,64) y triángulo de 100 ciclos exactos de 88 Hz reajustado con `pitch_scale` hasta 120 Hz.
- Enganchado en `SceneExperienceController._process`: fatiga `1 − stamina/100` en primera persona y cercanía a las cuatro acometidas del pasillo eléctrico, con las acometidas caídas en silencio.
- `qa/validate_breath_audio.gd` (21 checks) + bloque de 9 en `run_suite`. Total **358 checks**, 0 fallos. Curvas en `reports/phase35-breath.png` (+ CSV). Detalle en `PHASE_35_BREATH_AUDIO.md`.

## Fase 36 · Veinte brazos (`Tentacles.ts`)
- `scripts/entities/w01_arms.gd`: contrato de movimiento de `Tentacles.ts` sobre los veinte brazos y las 87 ventosas del exportador — fases, estiramiento, giro al operador, alcance de los brazos 2 y 3, `scout`, latigazo del pulso UV y recorte contra suelo y malla de contención.
- `w01_actor.gd`: `arms` en `_ready`, `_update_arms()` en `_process`, `_lash_arms()` en `apply_uv()` y `arms_pin` para capturas. `qa/validate_w01_arms.gd` (19 checks) + bloque de 8 en `run_suite`. Total **366 checks**, 0 fallos. Captura `reports/w01-arms.png`. Detalle en `PHASE_36_ARMS.md`.

## Fase 37 · Puerta de la bóveda, pantalla de carga y arte del menú
- `scripts/world/vault_door_rig.gd`: el grupo `Node2` de `vault.glb` montado en V–03 con la secuencia de `Vault.ts` (pistones 0,8 + i·0,71, cerrojos 4,3 + i·0,58, corona 8,8→13,9, disco 13,6→22) y las piezas localizadas por geometría (disco, corona, 8 cerrojos, 4 pistones, brazos). La puerta pasa de B–02 al fondo de la galería, donde vive `VaultModule`, y esconde el portal de la crioteca.
- `scripts/ui/loading_progress.gd`: barra compuesta (informe · 70, suelo exponencial al 52 %, estados de `ZoneManager` para el último 30 %) y línea de datos reales (módulo, `.tscn`, KB, dependencias, segundos, informe y estado). El título de la carga y el botón del menú salen de `zone_graph.json`.
- `assets/ui/menu_background.png`: ilustración propia para el fondo del menú (velo 0,45) y de la carga (velo 0,62).
- `qa/validate_vault_door.gd` (24 checks) y bloque de 9 en `run_suite`. Total **375 checks**, 0 fallos. Capturas `reports/ui-main-menu.png`, `ui-loading.png`, `vault-opening.png` y `vault-open.png`. Detalle en `PHASE_37_VAULT_UI.md`.

## Fase 38 · Larvas de H–01 (`Larva.ts`)
- Arreglado `_take_larva()`: tomaba la nube de burbujas del exportador (48 vértices) en vez de la criatura y dejaba los vasos sin larva. Ahora identifica el grupo que cuelga tentáculos (`position.y < −0,2`), que es el criterio de la web.
- `scripts/world/larva_rig.gd` (`LarvaRig`): gesto de los 8/9/10 tentáculos (`0,17·sin(t·1,35 + j·0,83)` y `0,18·cos(t·1,26 + j·1,26)`) y del ojo (`0,11·sin(t·0,8 + vaso)`, `0,055·cos(t·1,07)`), con reset limpio. El pivote del corazón pasa a escala 1,0 y conserva latido, vaivén y giro de `Workshop.Pods`.
- `qa/validate_larva.gd` (44 checks) y bloque de 8 en `run_suite`. Total **383 checks**, 0 fallos. Captura `reports/ingame-h01.png`. Detalle en `PHASE_38_LARVA.md`.

## Fase 39 · Coche de vía: suspensión y mallas originales
- `scripts/world/vehicle_rig.gd` (`VehicleRig`): cuerpo y cuatro ruedas de `vehicle.glb` colocados en `(±0,87, 0,355, ±1,38)` y sincronizados con la física (`rotation = (pitch, yaw, roll)`, rueda `y = comY + 0,14 − suspensión`). `PropLibrary.vehicle()` devuelve los cinco grupos en orden de exportación.
- `VehiclePhysics`: solver de cuatro apoyos con las constantes de `tune` (recorrido 0,19 m, rigidez 41, amortiguación 3,4/4,5, tope 18 kN), actitud de la carrocería por aceleración y guiñada, y `wheel_state(i)` con suspensión, dirección, rodadura, contacto y posición. `contacts` es el recuento real.
- `CapsuleTransit._build_car()`: el coche se monta al arrancar y se sincroniza en cada paso (conduciendo o aparcado).
- `qa/validate_vehicle_rig.gd` (51 checks) y bloque de 12 en `run_suite`. Total **395 checks**, 0 fallos. Captura `reports/ingame-transit_car.png`. Detalle en `PHASE_39_VEHICLE.md`.

## Fase 40 · Panel de instrumentos y sonido del coche
- `scripts/world/cockpit_display.gd` (`CockpitDisplay`): lienzo de 384 × 144 reproducido en el espacio (1 px = 1 mm) con `Label3D` y barra de carga, repintado sólo al cambiar la clave y telemetría redondeada como la web. Subido a 1,03 m y 0,47 m con 12° de inclinación porque el salpicadero exportado tapa la posición original.
- `scripts/systems/vehicle_audio.gd` (`VehicleAudio`): motor (sierra `30 + rpm/63`), rodadura (triángulo `240 + |v|·18`), turbo (seno `240 + energía·4`) y ruido con paso bajo `240 + |v|·20 + 2700·impacto`, con las ganancias y constantes de tiempo de `VehicleAudio.ts`; se apaga con el coche aparcado.
- `qa/validate_vehicle_ui.gd` (38 checks) y bloque de 11 en `run_suite`. Total **406 checks**, 0 fallos. Captura `reports/ingame-transit_seat.png`. Detalle en `PHASE_40_COCKPIT_AUDIO.md`.

## Fase 41 · Perspectivas del operador y del coche
- `scripts/world/perspectives.gd` (`Perspectives`): port de `Perspectives.ts` (104 líneas), el último archivo de `vehicle/*` sin equivalente. Dos tablas de modo (`foot`/`car`, 0–2) con ciclo `1 → 2 → 0`; a pie el modo 1 es hombro (`aim.y − 0,32`, 2,9 m) y el 2 es órbita (`−distancia · 0,72`, `+0,55 − 0,8 · pitch`); en coche el 0 es cabina en `COCKPIT (0,38; 1,055; −0,24)` mirando a `COCKPIT_AIM` con `up = car.basis.y`, y el 1/2 giran alrededor de `CAR_PIVOT (0; 0,66; 0,23)` a `DISTANCE 4,8` con `y = pivot.y + max(0,35; height)`. Rueda de 0,4 m entre 2,2 y 9,0 m, amortiguado `e^(−12·Δt)` y mezcla `smoothstep` a 5,0.
- `player.gd`: `perspective` + `_update_perspective()`, `V` cicla a pie y `C` en coche, rueda acerca/aleja, `_hit_distance()` con `intersect_ray` y `max(COLLISION_MIN 0,12, d − COLLISION_MARGIN 0,17)`; modo 0 a pie devuelve el control a `CameraController`.
- `capsule_transit.gd`: el asiento resta `CameraController.EYE_HEIGHT` — estaba anclado por el ojo y dejaba la cabina 1,72 m sobre el techo.
- `qa/validate_perspectives.gd` (39 checks) + bloque de 8 en `run_suite`. Total **414 checks**, 0 fallos. Captura `reports/ingame-transit_chase.png`. Detalle en `PHASE_41_PERSPECTIVES.md`.

## Fase 42 · Recorte por portales (`Visibility.ts`)
- `scripts/world/visibility.gd` (`Visibility`): port de `Visibility.ts` (122 líneas) — cajas envolventes de los props con margen 0,15 m (1,4 m en bandejas), proyección de la silueta sobre el plano de la compuerta a través de la cámara y ocultación sólo cuando la caja queda entera detrás y fuera del vano (lo que cruza el plano se conserva).
- Particiones sacadas de `data/zone_graph.json` con los afinados de la web en las seis paredes opacas (electricidad y vigilancia 2,28 × 4,55 con prueba lateral a |x| > 17,6; galería de B-02 3,35 × 6,1 con la bandera `gallery_open`; bóveda 1,7 × 3,4; H-01 y D-02 2,17 × 4,02 en corredor lateral). Abertura = media × apertura viva del `SectorDoor` emparejado por posición (0,9 m).
- Dos añadidos nativos: `SCENE_OFFSET (9; 14)` para alinear con el montaje de las zonas (comprobado contra `Main.SCENE_OFFSET_2D`) y `probe(world)`, que descarta las particiones sin geometría de muro (dos lados × tres alturas, ≥ 2 impactos).
- `SceneExperienceController`: `zones_path`, reconstrucción al cambiar de zona (`zone_ready`/`zone_unloaded`), aplicación por fotograma con la cámara y restauración sin control. En C-04 oculta 8 de 454 props con los muros de electricidad y vigilancia; A-01, hub y crioteca quedan a cero.
- `qa/validate_visibility.gd` (41 checks) + bloque de 10 en `run_suite`. Total **424 checks**, 0 fallos. Detalle en `PHASE_42_VISIBILITY.md`.

## Fase 43 · Distribución: presets y construcción reproducible
- `export_presets.cfg`: tres destinos — `Linux` (x86_64), `Windows Desktop` (x86_64) y `Android` (arm64-v8a, inmersivo, minSdk 21 / targetSdk 34, `com.gxforge.nexusnative`, versión 43 / 0.43.0) — con PCK incrustado y `qa/`, `reports/`, `docs/` y `tools/` fuera del paquete.
- `tools/build.sh`: importación, puerta de calidad (`run_suite` a cero fallos), exportación de cada destino, firma y verificación del APK con `apksigner`, prueba de humo del binario de Linux y `SHA256SUMS` + `BUILD_REPORT.json`. Reconstrucción de la fase: 149,47 MB (Linux), 177,31 MB (Windows) y 105,38 MB (APK firmado, `arm64-v8a`, firma v1/v2 verificada).
- Ajustes que exigió: `config/version = "0.43.0"` y `import_etc2_astc = true` (sin él el export de Android falla con un mensaje **vacío**), `.gdignore` en `reports/` y `tools/`, y `/build/` fuera de git.
- `qa/validate_distribution.gd` (38 checks) + bloque de 11 en `run_suite`. Total **435 checks**, 0 fallos. Detalle en `PHASE_43_DISTRIBUTION.md`.

## Fase 44 · Pantalla de carga con progreso real
- Diagnosticado el 60 % eterno: `load_threaded_get_status` informa `0` durante toda la precarga y la fase 37 tapaba el hueco con un suelo exponencial que tiende a 60; la línea de datos mostraba el enum interno (`estado IDLE`). El juego entraba en 1,8 s, no había cuelgue.
- `scripts/ui/loading_progress.gd` reescrito: plan por dependencias (`ext_resource` a dos niveles, módulo al final, un recurso en vuelo cada vez), arrastre máximo del 85 % dentro del recurso en curso, techo de precarga en 92 % con el montaje real en el último tramo, línea de datos de operador (`C04 · zone_c04_shell.tscn · 14 de 14 recursos · 3.2 MB · 0:02`), reloj de pared, aviso a los 15 s sin avance y botón **Volver al menú** a los 60 s.
- `tools/gen_load_plan.gd` + `data/load_plan.json` (**12 zonas · 136 recursos · 4,0 MB**): el juego exportado lleva los `.tscn`/`.glb` remapeados a `.scn` y no puede leer dependencias, así que se calculan en la construcción y se versionan. `tools/build.sh` los regenera antes de exportar.
- `main.tscn`: panel de carga más alto, `Content/Hint` y `Content/Cancel`; `main.gd`: `_begin_load_plan`, `_request_next_resource`, `_tick_loading`, `cancel_loading`, y dos fotogramas de pausa para que el 92 % se pinte antes del bloqueo del montaje.
- `qa/run_suite.gd`: bloque de carga de 9 a 25 comprobaciones. Total **455 checks**, 0 fallos. Versión 0.44.0. Medición: 7 % en el primer fotograma, 14 de 14 a los 0,39 s, juego listo en 2,1 s. Detalle en `PHASE_44_LOADING.md`.

## Entrega 0.44.0 (release)
- Primer paquete de producción para Windows y Android: `tools/build.sh windows android` con `--export-release`, APK firmado con clave de release RSA 4096 (v1/v2/v3 verificadas) y artefactos con versión en el nombre.
- Publicado como release `v0.44.0` de GitHub (commit `4eaff3d`): Windows 177 327 120 B `d812a05f…142f0a`, Android 105 393 044 B `427d91cd…188156`. Notas en `docs/releases/v0.44.0.md`, proceso y política de clave en `docs/releases/README.md`.
- El SDK de Android de esta máquina había perdido `build-tools` (sólo quedaba `renderscript`): se reinstalaron build-tools 34.0.0 y platform-tools desde `dl.google.com`. La puerta de calidad ya no exige un informe con dos artefactos cuando se compila un solo destino.

## Siguiente bloque de trabajo
0. Ver `docs/migration/PARITY_WEB_NATIVE.md` para la comparación módulo a módulo con la web v15.1.
1. Verificar y ajustar el HUD/touch y el mapa con el APK en un dispositivo real (checklist en `PHASE_43_DISTRIBUTION.md`).
2. ~~Migrar la bóveda V-03~~ hecho en las fases 15 y 37 (lógica y geometría animada); faltan su audio y la apertura desde el panel de la galería.
3. ~~Sistemas eléctricos/CCTV/archivos~~ hechos en las fases 16 y 17; quedan la geometría, las pantallas y el vídeo de las cámaras.
4. ~~Migrar Transit/cápsula/vehículo con el solver de cuatro apoyos y las perspectivas~~ hecho en las fases 39, 40 y 41; falta el mapa de reflejos de las tiras de luz y el audio de puertas.
5. Particionar el GLB combinado por zona para el pase de alta fidelidad y cerrar IA, deformación, audio y VFX con pruebas A/B.

Ver `PHASE_13_ZONE_MODULES.md` para el detalle de la iteración.
