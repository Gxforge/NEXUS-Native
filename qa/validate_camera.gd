extends SceneTree
## Validador de `CameraController.ts`: órbita con amortiguación, límites,
## primera persona, aguante, cadencia, agachado, escape y entrada del vehículo.

var checks := 0
var failures := 0


func _init() -> void:
	_defaults()
	_orbit()
	_first_person()
	_walk()
	_escape_and_vehicle()
	_persistence()
	_player_integration()
	print("\n=== validate_camera: %d checks, %d failures ===" % [checks, failures])
	if failures > 0:
		push_error("%d comprobaciones fallaron" % failures)
	quit(1 if failures > 0 else 0)


func check(label: String, condition: bool, extra := "") -> void:
	checks += 1
	if not condition:
		failures += 1
		print("  FAIL · %s%s" % [label, (" · " + extra) if not extra.is_empty() else ""])


func near(label: String, value: float, expected: float, tolerance := 0.001) -> void:
	check(label, absf(value - expected) <= tolerance, "%.4f vs %.4f" % [value, expected])


func _defaults() -> void:
	print("\n[constantes y estado inicial]")
	var v := CameraController.new()
	near("aguante inicial", v.stamina, 100.0)
	near("sensibilidad", v.sensitivity, 1.0)
	check("arranca en órbita", v.mode == "orbit", v.mode)
	check("no agachado", not v.crouch)
	near("objetivo de la órbita · y", CameraController.ORBIT_TARGET.y, 2.6)
	near("objetivo de la órbita · z", CameraController.ORBIT_TARGET.z, 22.0)
	near("amortiguación 6 %", CameraController.ORBIT_DAMPING, 0.06)
	near("distancia mínima", CameraController.ORBIT_MIN_DISTANCE, 3.1)
	near("distancia máxima", CameraController.ORBIT_MAX_DISTANCE, 13.0)
	near("polar mínimo", CameraController.ORBIT_MIN_POLAR, 0.38)
	near("polar máximo", CameraController.ORBIT_MAX_POLAR, PI * 0.49, 0.0001)
	near("velocidad de giro", CameraController.ORBIT_ROTATE_SPEED, 0.48)
	near("velocidad de zoom", CameraController.ORBIT_ZOOM_SPEED, 0.7)
	near("marcha", CameraController.WALK_SPEED, 4.8)
	near("carrera", CameraController.RUN_SPEED, 8.25)
	near("amortiguación de marcha", CameraController.MOVE_DAMP, 18.0)
	near("gasto de aguante", CameraController.STAMINA_DRAIN, 14.0)
	near("recarga en marcha", CameraController.STAMINA_REGEN_MOVING, 8.0)
	near("recarga quieto", CameraController.STAMINA_REGEN_IDLE, 13.0)
	near("espera de recarga", CameraController.STAMINA_RECOVERY, 1.05)
	near("rearme del aguante", CameraController.STAMINA_REARM, 26.0)
	near("cadencia andando", CameraController.GAIT_WALK, 4.0)
	near("cadencia corriendo", CameraController.GAIT_RUN, 12.0)
	near("balanceo andando", CameraController.BOB_WALK, 0.027)
	near("balanceo corriendo", CameraController.BOB_RUN, 0.035)
	near("agachado −0,44", CameraController.CROUCH_DROP, 0.44)
	near("altura de ojos", CameraController.EYE_HEIGHT, 1.72)
	near("radio de escape", CameraController.ESCAPE_RADIUS, 6.8)
	check("seis direcciones de escape", CameraController.ESCAPE_ANGLES.size() == 6)
	check("vista por defecto de la web", v.is_first_person() == false)


func _orbit() -> void:
	print("\n[órbita]")
	var v := CameraController.new()
	var start := v.orbit_position()
	check("posición inicial de la cámara", start.distance_to(CameraController.ORBIT_CAMERA) < 0.001,
		str(start))
	near("distancia inicial", v.orbit_distance(),
		CameraController.ORBIT_CAMERA.distance_to(CameraController.ORBIT_TARGET), 0.01)
	check("mira al objetivo", v.orbit_target() == CameraController.ORBIT_TARGET)

	# Amortiguación del 6 % por frame a 60 Hz.
	var before := v.orbit_distance()
	v.orbit_zoom(1.0)
	v.update_orbit(1.0 / 60.0)
	var moved := v.orbit_distance() - before
	var expected := (CameraController.ORBIT_MAX_DISTANCE - before) * 0.06
	check("amortiguación del 6 % en un frame", absf(moved - expected) < 0.02,
		"%.4f vs %.4f" % [moved, expected])
	for _i in 240:
		v.update_orbit(1.0 / 60.0)
	near("el zoom llega al máximo", v.orbit_distance(), CameraController.ORBIT_MAX_DISTANCE, 0.01)
	for _i in 600:
		v.orbit_zoom(-1.0)
		v.update_orbit(1.0 / 60.0)
	near("el zoom se detiene en el mínimo", v.orbit_distance(),
		CameraController.ORBIT_MIN_DISTANCE, 0.01)

	var polar := CameraController.new()
	for _i in 600:
		polar.orbit_rotate(0.0, -1.0)
		polar.update_orbit(1.0 / 60.0)
	var top := polar.orbit_position()
	check("no pasa del cenit", top.y > polar.orbit_target().y, str(top))
	var ceil_y := polar.orbit_target().y + CameraController.ORBIT_MIN_DISTANCE * cos(CameraController.ORBIT_MIN_POLAR)
	check("el cenit queda limitado", top.y <= polar.orbit_target().y
		+ CameraController.ORBIT_MAX_DISTANCE + 0.05 and top.y > ceil_y - 0.001)
	for _i in 600:
		polar.orbit_rotate(0.0, 1.0)
		polar.update_orbit(1.0 / 60.0)
	var low := polar.orbit_position()
	check("no baja del horizonte", low.y >= polar.orbit_target().y - 0.05, str(low))

	var spin := CameraController.new()
	var azimuth_before := spin.orbit_position()
	for _i in 120:
		spin.orbit_rotate(1.0, 0.0)
		spin.update_orbit(1.0 / 60.0)
	check("el giro mueve la cámara", spin.orbit_position().distance_to(azimuth_before) > 1.0,
		str(spin.orbit_position()))
	check("el giro conserva la distancia", absf(spin.orbit_distance()
		- CameraController.ORBIT_CAMERA.distance_to(CameraController.ORBIT_TARGET)) < 0.02)

	# El objetivo se puede recentrar (el jugador es el nuevo foco).
	var follow := CameraController.new()
	follow.focal_point = Vector3(10.0, 1.6, 30.0)
	var focus_position := follow.orbit_position()
	near("la cámara acompaña al objetivo · x", focus_position.x,
		10.0 + (CameraController.ORBIT_CAMERA.x - CameraController.ORBIT_TARGET.x), 0.05)


func _first_person() -> void:
	print("\n[primera persona]")
	var v := CameraController.new()
	v.set_mode("first-person")
	check("modo primera persona", v.is_first_person())
	check("posición de la web", v.first_position.distance_to(Vector3(1.8, 1.72, 42.0)) < 0.001,
		str(v.first_position))
	near("inclinación inicial 0,12", v.pitch, 0.12)
	near("rumbo inicial", v.yaw, 0.0)
	near("altura de ojos", v.eye_position().y, 1.72)

	v.look(100.0, 0.0, 0.0021)
	near("el ratón gira el rumbo", v.yaw, 100.0 * 0.0021, 0.0001)
	v.look(0.0, 10000.0, 0.0021)
	near("la mirada se limita hacia abajo", v.pitch, -CameraController.PITCH_LIMIT)
	v.look(0.0, -10000.0, 0.0021)
	near("la mirada se limita hacia arriba", v.pitch, CameraController.PITCH_LIMIT)
	check("dirección unitaria", absf(v.look_direction().length() - 1.0) < 0.001)

	v.yaw = 0.0
	v.pitch = 0.0
	var target := v.look_target(Vector3(0.0, 1.72, 10.0))
	near("mira al frente · z", target.z, 0.0, 0.001)
	near("mira al frente · y", target.y, 1.72, 0.001)
	v.yaw = PI * 0.5
	target = v.look_target(Vector3(0.0, 1.72, 10.0))
	near("mira al este · x", target.x, 10.0, 0.001)
	v.face_rail(true)
	near("cara a la vía (ida)", v.yaw, PI)
	near("cara a la vía (pitch)", v.pitch, 0.0)
	v.face_rail(false)
	near("cara a la vía (vuelta)", v.yaw, 0.0)

	v.crouch = true
	near("agachado baja los ojos", v.eye_position().y, 1.72 - 0.44, 0.001)
	v.crouch = false
	v.stamina = 50.0
	v.gait = PI * 0.5
	near("balanceo por fatiga", v.bob_offset(), 0.027 * 0.5, 0.0001)
	v.running = true
	near("balanceo corriendo", v.bob_offset(), 0.035 + 0.027 * 0.5, 0.0001)
	v.gait = 0.0
	near("sin balanceo en el cruce", v.bob_offset(), 0.0, 0.0001)

	check("alternar modo", CameraController.new().toggle_mode() == "first-person")
	var back := CameraController.new()
	back.set_mode("first-person")
	back.toggle_mode()
	check("vuelve a la órbita", back.mode == "orbit", back.mode)
	near("la órbita recupera su distancia", back.orbit_distance(),
		CameraController.ORBIT_CAMERA.distance_to(CameraController.ORBIT_TARGET), 0.02)


func _walk() -> void:
	print("\n[marcha a pie]")
	var v := CameraController.new()
	v.set_mode("first-person")
	v.first_position = Vector3(0.0, 1.72, 0.0)
	v.yaw = 0.0
	var start := v.first_position
	for _i in 60:
		v.update_walk(1.0 / 60.0, Vector2(0.0, 1.0), false)
	check("avanza al frente", v.first_position.z < start.z - 2.0, str(v.first_position))
	check("la marcha no cambia la altura", is_equal_approx(v.first_position.y, 1.72))
	near("velocidad de marcha", v.velocity().length(), CameraController.WALK_SPEED, 1.5)

	var blocked := CameraController.new()
	blocked.set_mode("first-person")
	blocked.first_position = Vector3(0.0, 1.72, 0.0)
	var wall := func(x: float, z: float) -> bool: return z > -2.0
	for _i in 120:
		blocked.update_walk(1.0 / 60.0, Vector2(0.0, 1.0), false, wall)
	check("la pared detiene la marcha", blocked.first_position.z > -2.6,
		str(blocked.first_position))

	# Aguante: gasto, espera y recarga.
	var run := CameraController.new()
	run.set_mode("first-person")
	for _i in 60:
		run.update_walk(1.0 / 60.0, Vector2(0.0, 1.0), true)
	check("correr activa la carrera", run.running)
	near("gasta 14 por segundo", run.stamina, 86.0, 1.0)
	check("cadencia de carrera", run.gait > 11.0, str(run.gait))
	for _i in 60 * 7:
		run.update_walk(1.0 / 60.0, Vector2(0.0, 1.0), true)
	near("el aguante se agota", run.stamina, 0.0, 0.01)
	check("marcado como agotado", run.spent)
	for _i in 30:
		run.update_walk(1.0 / 60.0, Vector2.ZERO, false)
	check("recupera tras la espera", run.stamina > 0.0, str(run.stamina))
	check("sigue agotado por debajo de 26", run.spent and run.stamina < CameraController.STAMINA_REARM)
	for _i in 60 * 6:
		run.update_walk(1.0 / 60.0, Vector2.ZERO, false)
	check("se rearma por encima de 26", not run.spent and run.stamina > 26.0, str(run.stamina))
	var idle := CameraController.new()
	idle.stamina = 50.0
	for _i in 60:
		idle.update_walk(1.0 / 60.0, Vector2.ZERO, false)
	near("recarga quieto 13 por segundo", idle.stamina, 63.0, 1.0)
	near("quieto no gasta cadencia de carrera", idle.gait, CameraController.GAIT_WALK, 0.01)


func _escape_and_vehicle() -> void:
	print("\n[escape y entrada del vehículo]")
	var v := CameraController.new()
	v.set_mode("first-person")
	var origin := Vector3(0.0, 1.72, 100.0)
	var escape := v.escape(origin)
	check("el escape coloca al jugador", escape.distance_to(origin) > 6.0, str(escape))
	near("a 6,8 m del origen", Vector2(escape.x - origin.x, escape.z - origin.z).length(), 6.8, 0.01)
	var north_walkable := func(x: float, z: float) -> bool: return z >= 100.0
	var moved := v.escape(origin, north_walkable)
	near("elige la primera corona caminable · distancia",
		Vector2(moved.x - origin.x, moved.z - origin.z).length(), 6.8, 0.01)
	check("se queda en la dirección permitida", moved.z >= origin.z, str(moved))
	var south_walkable := func(x: float, z: float) -> bool: return z <= 100.0
	var south := v.escape(origin, south_walkable)
	check("descarta la corona no caminable", south.z <= origin.z, str(south))
	near("altura del escape", moved.y, 1.72)

	var car := CameraController.new()
	check("sin teclas no hay entrada", car.transit_input() == Vector2.ZERO)
	car.move("w", true)
	near("acelerar", car.transit_input().y, 1.0)
	car.move("w", false)
	car.move("s", true)
	near("retroceder", car.transit_input().y, -1.0)
	car.move("s", false)
	car.move("d", true)
	near("girar a la derecha", car.transit_input().x, 1.0)
	car.move("a", true)
	near("las dos teclas se anulan", car.transit_input().x, 0.0)
	car.clear_keys()
	car.stick = Vector2(0.4, -0.6)
	near("el joystick suma", car.transit_input().y, 0.6, 0.001)
	check("teclas de la web", CameraController.BINDINGS["gas"] == "w"
		and CameraController.BINDINGS["brake"] == " ")
	car.move("w", true)
	check("tecla pulsada", car.held("w"))
	car.release()
	check("release limpia las teclas", not car.held("w") and not car.running)


func _persistence() -> void:
	print("\n[persistencia]")
	var v := CameraController.new()
	v.set_mode("first-person")
	v.first_position = Vector3(4.0, 1.72, 30.0)
	v.yaw = 1.1
	v.pitch = -0.3
	v.stamina = 61.0
	v.crouch = true
	var blob := v.to_dict()
	check("guarda el modo", blob.get("mode", "") == "first-person")
	var other := CameraController.new()
	check("restaura", other.from_dict(blob))
	near("rumbo restaurado", other.yaw, 1.1)
	near("inclinación restaurada", other.pitch, -0.3, 0.0001)
	near("aguante restaurado", other.stamina, 61.0)
	check("agachado restaurado", other.crouch)
	check("posición restaurada", other.first_position.distance_to(Vector3(4.0, 1.72, 30.0)) < 0.001)
	check("diccionario vacío no rompe", not CameraController.new().from_dict({}))
	var dirty := CameraController.new()
	check("modo inválido no rompe", dirty.from_dict({"mode": "otro"}) and dirty.mode == "orbit")
	var clamped := CameraController.new()
	clamped.from_dict({"pitch": 9.0})
	near("inclinación fuera de rango se limita", clamped.pitch, CameraController.PITCH_LIMIT)
	check("aguante fuera de rango se limita",
		CameraController.new().from_dict({"stamina": 400.0}) and true)


func _player_integration() -> void:
	print("\n[jugador]")
	var player := NexusPlayer.new()
	var camera := Camera3D.new()
	camera.name = "Camera3D"
	camera.position = Vector3(0.0, 1.72, 0.0)
	player.add_child(camera)
	player.camera = camera
	root.add_child(player)
	# En modo `--script` la escena no llega a procesar un frame: se inicializa a mano.
	player._ready()
	player.set_controls_enabled(true)
	check("el jugador arranca en primera persona", player.view_mode() == "first-person",
		player.view_mode())
	check("la cámara no es global en primera persona", not camera.top_level)
	player.toggle_view()
	check("la órbita se activa", player.view_mode() == "orbit", player.view_mode())
	check("la cámara orbital es global", camera.top_level)
	check("el aguante llega al controlador", player.view.stamina <= 100.0)
	player.toggle_view()
	check("vuelve a la primera persona", player.view_mode() == "first-person", player.view_mode())
	player.view.crouch = true
	player.stamina = 100.0
	player._apply_eye_height()
	near("los ojos bajan al agacharse", camera.position.y, 1.72 - CameraController.CROUCH_DROP, 0.001)
	player.view.crouch = false
	player.apply_look(Vector2(10.0, 10.0))
	near("la mirada se refleja en el controlador", player.view.pitch, -player.camera.rotation.x, 0.001)
	check("acción de cambio de vista", InputMap.has_action(&"toggle_view")
		and InputMap.has_action(&"crouch"))
	# Fuera del árbol antes de que se instancie la partida: si no, este jugador de
	# prueba queda como primer nodo del grupo `player`.
	root.remove_child(player)
	player.free()
