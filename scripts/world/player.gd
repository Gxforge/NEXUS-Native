class_name NexusPlayer
extends CharacterBody3D

signal prompt_changed(text: String)
signal message_changed(text: String)
signal flashlight_changed(enabled: bool, battery: float)
signal stamina_changed(value: float)
signal quick_slot_changed(index: int, item_id: StringName)
signal tool_state_changed(energy: float, battery: float, weapon: int)
signal panel_requested(panel_name: StringName)

const WALK_SPEED := 4.8
const RUN_SPEED := 8.25
const GRAVITY := 9.8
const SCAN_RANGE := 22.0
const UV_COST := 32.0
const CRYO_COST := 24.0
const LURE_COST := 12.0

@export var mouse_sensitivity: float = 0.0022
@export var interaction_range: float = 3.2
@onready var camera: Camera3D = $Camera3D
## Manos y equipo en primera persona (modelos originales de `touch_rig_assets.glb`).
@onready var rig: FirstPersonRig = $Camera3D/FirstPerson

var _pitch: float = 0.0
var controls_enabled: bool = false
var game_state: GameState
var scene_experience: SceneExperienceController
var stamina: float = 100.0
var stamina_recovery_delay: float = 0.0
var energy: float = 100.0
var flashlight_battery: float = 100.0
var flashlight_enabled: bool = false
var cell_charged: bool = true
var selected_quick_slot: int = 0
var active_weapon: int = -1
var tool_cooldowns: Dictionary = {"uv": 0.0, "gas": 0.0, "lure": 0.0}
## Vista del explorador: órbita y primera persona (port de `CameraController.ts`).
var view: CameraController = CameraController.new()
var orbit_drag := false
var _eye_base := Vector3(0.0, 1.72, 0.0)
var _field_light: SpotLight3D
var _prompt_timer: float = 0.0
var _status_timer: float = 0.0
var _last_prompt: String = ""

func _ready() -> void:
	add_to_group(&"player")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_field_light = SpotLight3D.new()
	_field_light.name = "FieldFlashlight"
	_field_light.position = Vector3(-0.19, -0.15, -0.71)
	_field_light.light_color = Color(1.0, 0.94, 0.78)
	_field_light.light_energy = 5.0
	_field_light.spot_range = 22.0
	_field_light.spot_angle = 32.0
	_field_light.visible = false
	camera.add_child(_field_light)
	# El juego nativo arranca en primera persona (la web lo hace en órbita); `V`
	# alterna entre ambas y la órbita sigue disponible como vista de conjunto.
	_eye_base = camera.position
	view.set_mode("first-person")
	view.focal_point = global_position + Vector3(0.0, 1.6, 0.0)
	view.first_position = global_position
	view.yaw = rotation.y
	camera.top_level = false

func configure(state: GameState, experience: SceneExperienceController) -> void:
	game_state = state
	scene_experience = experience
	if game_state != null:
		if not game_state.inventory_changed.is_connected(_on_inventory_changed):
			game_state.inventory_changed.connect(_on_inventory_changed)
		if not game_state.quick_slots_changed.is_connected(_on_quick_slots_changed):
			game_state.quick_slots_changed.connect(_on_quick_slots_changed)
		restore_runtime_state(game_state.player_state)
	else:
		_emit_runtime_status()

func restore_runtime_state(saved: Dictionary) -> void:
	stamina = clampf(float(saved.get("stamina", stamina)), 0.0, 100.0)
	energy = clampf(float(saved.get("energy", energy)), 0.0, 100.0)
	flashlight_battery = clampf(float(saved.get("flashlight_battery", flashlight_battery)), 0.0, 100.0)
	cell_charged = bool(saved.get("cell_charged", cell_charged))
	selected_quick_slot = clampi(int(saved.get("selected_quick_slot", selected_quick_slot)), 0, 4)
	active_weapon = clampi(int(saved.get("active_weapon", active_weapon)), -1, 2)
	var saved_cooldowns: Variant = saved.get("tool_cooldowns", {})
	if saved_cooldowns is Dictionary:
		for key in ["uv", "gas", "lure"]:
			tool_cooldowns[key] = maxf(0.0, float(saved_cooldowns.get(key, 0.0)))
	flashlight_enabled = bool(saved.get("flashlight_enabled", false)) and game_state != null and game_state.has_item(&"lamp") and flashlight_battery > 0.0
	if active_weapon == 1 and (game_state == null or not game_state.has_item(&"pulse")):
		active_weapon = -1
	elif active_weapon == 2 and (game_state == null or not game_state.has_item(&"cryo")):
		active_weapon = -1
	_field_light.visible = flashlight_enabled
	_emit_runtime_status()
	stamina_changed.emit(stamina)
	_emit_selected_slot()

func checkpoint_state() -> Dictionary:
	return {
		"stamina": stamina,
		"energy": energy,
		"flashlight_battery": flashlight_battery,
		"flashlight_enabled": flashlight_enabled,
		"cell_charged": cell_charged,
		"selected_quick_slot": selected_quick_slot,
		"active_weapon": active_weapon,
		"tool_cooldowns": tool_cooldowns.duplicate(true),
	}

func set_controls_enabled(value: bool) -> void:
	controls_enabled = value
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if value else Input.MOUSE_MODE_VISIBLE
	if not value:
		velocity = Vector3.ZERO
		_set_prompt("")

func show_message(text: String) -> void:
	if not text.is_empty():
		message_changed.emit(text)

func _unhandled_input(event: InputEvent) -> void:
	if not controls_enabled:
		return
	if event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		if view.is_first_person() and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			apply_look(motion.relative)
			return
		if not view.is_first_person() and orbit_drag:
			view.orbit_rotate(motion.relative.x * 0.0042, motion.relative.y * 0.0042)
			return
	if event is InputEventMouseButton and not view.is_first_person():
		var button := event as InputEventMouseButton
		if button.button_index == MOUSE_BUTTON_LEFT:
			orbit_drag = button.pressed
			return
		if button.pressed and button.button_index == MOUSE_BUTTON_WHEEL_UP:
			view.orbit_zoom(-0.12)
			return
		if button.pressed and button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			view.orbit_zoom(0.12)
			return
	if event.is_action_pressed(&"toggle_view"):
		toggle_view()
		return
	if event is InputEventMouseButton and event.pressed and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(&"ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(&"interact"):
		interact()
	elif event.is_action_pressed(&"scan"):
		scan()
	elif event.is_action_pressed(&"toggle_flashlight"):
		toggle_flashlight()
	elif event.is_action_pressed(&"use_slot"):
		use_selected_slot()
	elif event.is_action_pressed(&"cycle_weapon"):
		cycle_weapon()
	elif event.is_action_pressed(&"uv_protocol"):
		fire_tool(false)
	elif event.is_action_pressed(&"gas_protocol"):
		fire_tool(true)
	elif event.is_action_pressed(&"lure_protocol"):
		deploy_lure()
	elif event.is_action_pressed(&"open_inventory"):
		panel_requested.emit(&"inventory")
	elif event.is_action_pressed(&"open_database"):
		panel_requested.emit(&"database")
	elif event.is_action_pressed(&"open_map"):
		panel_requested.emit(&"map")
	elif event.is_action_pressed(&"crouch"):
		view.crouch = not view.crouch
	elif event.is_action_pressed(&"pause_game"):
		panel_requested.emit(&"pause")
	elif event.is_action_pressed(&"quick_slot_1"):
		select_quick_slot(0)
	elif event.is_action_pressed(&"quick_slot_2"):
		select_quick_slot(1)
	elif event.is_action_pressed(&"quick_slot_3"):
		select_quick_slot(2)
	elif event.is_action_pressed(&"quick_slot_4"):
		select_quick_slot(3)
	elif event.is_action_pressed(&"quick_slot_5"):
		select_quick_slot(4)
	get_viewport().set_input_as_handled()

func apply_look(relative_motion: Vector2) -> void:
	var scale := 1.0
	if game_state != null and game_state.session != null:
		scale = game_state.session.look_scale()
	rotate_y(-relative_motion.x * mouse_sensitivity * scale)
	_pitch = clampf(_pitch - relative_motion.y * mouse_sensitivity * scale, -1.42, 1.42)
	camera.rotation.x = _pitch
	view.yaw = rotation.y
	view.pitch = -_pitch

## Cambia entre la vista orbital (por defecto en la web) y la primera persona.
func toggle_view() -> String:
	var next := view.toggle_mode()
	if view.is_first_person():
		camera.top_level = false
		camera.position = _eye_base
		camera.rotation = Vector3(_pitch, 0.0, 0.0)
		view.first_position = global_position
		view.yaw = rotation.y
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if controls_enabled else Input.MOUSE_MODE_VISIBLE
	else:
		orbit_drag = false
		view.focal_point = global_position + Vector3(0.0, 1.6, 0.0)
		view.set_mode("orbit")
		camera.top_level = true
		camera.global_position = view.update_orbit(0.0)
		if camera.is_inside_tree():
			camera.look_at(view.focal_point, Vector3.UP)
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	apply_view_fov()
	if game_state != null:
		game_state.log_event("Operador en primera persona" if next == "first-person"
			else "Cámara orbital activa")
	show_message("Vista orbital" if not view.is_first_person() else "Primera persona")
	return next

## Campo de visión según el modo y la proporción de pantalla (web: 68 / 49 / 35).
func apply_view_fov() -> void:
	if camera == null:
		return
	var size := get_viewport().get_visible_rect().size if is_inside_tree() else Vector2(1280.0, 720.0)
	camera.fov = ExperienceState.fov_for(view.is_first_person(), size.x, size.y)

func view_mode() -> String:
	return view.mode

func _process(delta: float) -> void:
	if not controls_enabled:
		return
	if not view.is_first_person():
		_update_orbit(delta)
	_prompt_timer -= delta
	if _prompt_timer <= 0.0:
		_prompt_timer = 0.12
		_refresh_prompt()
	energy = minf(100.0, energy + delta * 3.2)
	for key in ["uv", "gas", "lure"]:
		tool_cooldowns[key] = maxf(0.0, float(tool_cooldowns[key]) - delta)
	if flashlight_enabled:
		flashlight_battery = maxf(0.0, flashlight_battery - delta * 3.0)
		if flashlight_battery <= 0.0:
			flashlight_enabled = false
			_field_light.visible = false
			show_message("Batería agotada · usa una celda o el banco de carga")
			flashlight_changed.emit(false, flashlight_battery)
	_status_timer -= delta
	if _status_timer <= 0.0:
		_status_timer = 0.2
		_emit_runtime_status()

func _physics_process(delta: float) -> void:
	if not controls_enabled:
		velocity = Vector3.ZERO
		return
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var local_direction := Vector3(input.x, 0.0, input.y)
	var world_direction := global_transform.basis * local_direction
	var moving := input.length() > 0.1
	var running := Input.is_action_pressed(&"sprint") and stamina > 0.0 and moving
	view.stamina = stamina
	view.running = running
	view.gait += delta * (CameraController.GAIT_RUN if running else CameraController.GAIT_WALK)
	var speed := RUN_SPEED if running else WALK_SPEED
	velocity.x = lerpf(velocity.x, world_direction.x * speed, 1.0 - exp(-18.0 * delta))
	velocity.z = lerpf(velocity.z, world_direction.z * speed, 1.0 - exp(-18.0 * delta))
	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y -= GRAVITY * delta
	move_and_slide()
	if running:
		stamina = maxf(0.0, stamina - delta * 14.0)
		stamina_recovery_delay = 1.05
	else:
		stamina_recovery_delay = maxf(0.0, stamina_recovery_delay - delta)
		if stamina_recovery_delay <= 0.0:
			stamina = minf(100.0, stamina + delta * (8.0 if moving else 13.0))
	stamina_changed.emit(stamina)
	_apply_eye_height()

## Altura de los ojos: agachado y balanceo de cabeza (contrato de la web).
func _apply_eye_height() -> void:
	if not view.is_first_person():
		return
	camera.position = _eye_base + Vector3(0.0,
		-CameraController.CROUCH_DROP if view.crouch else 0.0, 0.0)
	camera.position.y += view.bob_offset()

func _update_orbit(delta: float) -> void:
	view.focal_point = global_position + Vector3(0.0, 1.6, 0.0)
	camera.global_position = view.update_orbit(delta)
	if camera.is_inside_tree():
		camera.look_at(view.focal_point, Vector3.UP)

func _first_hit(max_distance: float) -> Dictionary:
	var world := get_world_3d()
	if world == null or camera == null:
		return {}
	var origin := camera.global_position
	var destination := origin - camera.global_transform.basis.z * max_distance
	var query := PhysicsRayQueryParameters3D.create(origin, destination, 0xFFFFFFFF, [get_rid()])
	query.collide_with_areas = true
	query.collide_with_bodies = true
	query.hit_from_inside = true
	return world.direct_space_state.intersect_ray(query)

func _refresh_prompt() -> void:
	var hit := _first_hit(SCAN_RANGE)
	if hit.is_empty():
		_set_prompt("")
		return
	var collider: Object = hit.get("collider")
	if not collider is Node:
		_set_prompt("")
		return
	var target := collider as Node
	var distance: float = camera.global_position.distance_to(hit.get("position", camera.global_position) as Vector3)
	var interactable := _find_ancestor_with_method(target, "get_interaction_prompt")
	if interactable != null and distance <= interaction_range:
		_set_prompt(str(interactable.call("get_interaction_prompt")))
	elif _has_survey_identity(target):
		_set_prompt("Q · Escanear " + str(_survey_name(target)))
	else:
		_set_prompt("")

func _find_ancestor_with_method(target: Node, method_name: String) -> Node:
	var current: Node = target
	while current != null:
		if current.has_method(method_name):
			return current
		current = current.get_parent()
	return null

func _has_survey_identity(target: Node) -> bool:
	var current: Node = target
	while current != null:
		if current.has_meta("survey_id"):
			return true
		current = current.get_parent()
	return false

func _survey_name(target: Node) -> String:
	var current: Node = target
	while current != null:
		if current.has_meta("survey_name"):
			return str(current.get_meta("survey_name"))
		current = current.get_parent()
	return target.name

func _set_prompt(text: String) -> void:
	if text == _last_prompt:
		return
	_last_prompt = text
	prompt_changed.emit(text)

## Gesto de la mano derecha al usar el equipo.
func _reach(style: StringName) -> void:
	if rig != null:
		rig.play_reach(style)


func interact() -> void:
	_reach(&"press")
	var hit := _first_hit(interaction_range)
	if hit.is_empty():
		show_message("No hay nada utilizable al alcance")
		return
	var collider: Object = hit.get("collider")
	if collider is Node:
		var interactable := _find_ancestor_with_method(collider as Node, "interact")
		if interactable != null:
			var result: Variant = interactable.call("interact", self)
			if result is String and not result.is_empty():
				show_message(result)
			return
	show_message("Sin respuesta · apunta a un equipo interactivo")

func scan() -> void:
	_reach(&"round")
	if scene_experience == null:
		show_message("Escáner no disponible")
		return
	var viewport_size := get_viewport().get_visible_rect().size
	var record := scene_experience.scan_viewport_point(viewport_size * 0.5)
	if record.is_empty():
		show_message("Sin retorno · apunta a una superficie u objetivo a 22 m")
		return
	if game_state != null:
		game_state.store_survey_records(scene_experience.survey.snapshot())
		game_state.save_game()
	show_message("Ficha registrada · " + str(record.get("name", record.get("id", "Objetivo"))))

func toggle_flashlight() -> void:
	if game_state == null or not game_state.has_item(&"lamp"):
		show_message("Sin linterna · busca el equipo de campo en A–01")
		return
	if flashlight_battery <= 0.0 and not flashlight_enabled:
		show_message("Linterna descargada · usa una celda o el banco de carga")
		return
	flashlight_enabled = not flashlight_enabled
	_field_light.visible = flashlight_enabled
	show_message("Linterna " + ("encendida" if flashlight_enabled else "apagada"))
	flashlight_changed.emit(flashlight_enabled, flashlight_battery)
	_emit_runtime_status()

func select_quick_slot(index: int) -> void:
	if index < 0 or index >= 5:
		return
	selected_quick_slot = index
	_emit_selected_slot()
	var item_id := _selected_item()
	if item_id.is_empty():
		show_message("Ranura %d vacía" % (index + 1))
	else:
		show_message("Ranura %d · %s" % [index + 1, _item_name(item_id)])

func use_selected_slot() -> void:
	var item_id := _selected_item()
	if item_id.is_empty():
		show_message("Ranura vacía · asigna equipo desde el inventario")
		return
	match item_id:
		&"pulse":
			if game_state.has_item(&"pulse"):
				active_weapon = 1
				show_message("Emisor UV · listo · espacio para disparar")
		&"cryo":
			if game_state.has_item(&"cryo"):
				active_weapon = 2
				show_message("Proyector criogénico · listo · G para disparar")
		&"lamp":
			toggle_flashlight()
		&"cell":
			_use_cell()
		&"card":
			show_message("Credencial V–03 · úsala en el lector de seguridad")
		&"recorder":
			show_message("Bitácora 03 · el lector de custodia está en Turbinas")
		&"sample":
			show_message("Muestra V–03 · requiere el analizador")
		_:
			show_message(_item_name(item_id) + " · listo")
	_emit_runtime_status()

func cycle_weapon() -> void:
	if game_state == null:
		return
	if active_weapon == -1:
		active_weapon = 1 if game_state.has_item(&"pulse") else (2 if game_state.has_item(&"cryo") else -1)
	elif active_weapon == 1:
		active_weapon = 2 if game_state.has_item(&"cryo") else -1
	else:
		active_weapon = -1
	match active_weapon:
		1: show_message("Emisor de pulso UV seleccionado")
		2: show_message("Proyector criogénico seleccionado")
		_: show_message("Mano libre")
	_emit_runtime_status()

func fire_tool(gas: bool) -> void:
	if game_state == null or scene_experience == null:
		return
	var item_id: StringName = &"cryo" if gas else &"pulse"
	var key := "gas" if gas else "uv"
	if not game_state.has_item(item_id):
		show_message("Equipo no disponible · " + _item_name(item_id))
		return
	var cooldown := float(tool_cooldowns.get(key, 0.0))
	if cooldown > 0.0:
		show_message("Protocolo en recarga · %.1f s" % cooldown)
		return
	var cost := CRYO_COST if gas else UV_COST
	if energy < cost:
		show_message("Sin reserva · espera la recarga de energía")
		return
	energy -= cost
	tool_cooldowns[key] = 12.0 if gas else 8.0
	_reach(&"grip")
	if rig != null:
		rig.kick(1.0)
	var range_m := 12.0 if gas else SCAN_RANGE
	var hit := _first_hit(range_m)
	if not hit.is_empty():
		scene_experience.emit_contact(hit, gas)
		var collider: Object = hit.get("collider")
		if collider is Node:
			var response := _find_ancestor_with_method(collider as Node, "apply_cryo" if gas else "apply_uv")
			if response != null:
				response.call("apply_cryo" if gas else "apply_uv")
				show_message("Niebla criogénica · actividad ralentizada" if gas else "Pulso UV · seguimiento ocular interrumpido")
			else:
				show_message("Descarga emitida · sin organismo en el punto de impacto")
	else:
		show_message("Descarga emitida · sin retorno")
	_emit_runtime_status()

func deploy_lure() -> void:
	if game_state == null or scene_experience == null:
		return
	if not game_state.has_item(&"pulse"):
		show_message("Sin emisor · no se puede desplegar un señuelo")
		return
	var cooldown := float(tool_cooldowns.get("lure", 0.0))
	if cooldown > 0.0:
		show_message("Señuelo en recarga · %.1f s" % cooldown)
		return
	if energy < LURE_COST:
		show_message("Sin reserva · espera la recarga de energía")
		return
	var hit := _first_hit(SCAN_RANGE)
	if hit.is_empty():
		show_message("Sin superficie válida para fijar el señuelo")
		return
	energy -= LURE_COST
	tool_cooldowns["lure"] = 5.0
	_reach(&"flat")
	scene_experience.emit_contact(hit, false)
	var collider: Object = hit.get("collider")
	if collider is Node:
		var response := _find_ancestor_with_method(collider as Node, "investigate_lure")
		if response != null:
			response.call("investigate_lure", hit.get("position", Vector3.ZERO) as Vector3, 5.4)
	show_message("Señuelo acústico desplegado")
	_emit_runtime_status()

func _use_cell() -> void:
	if game_state == null or not game_state.has_item(&"cell"):
		show_message("Sin celda de carga en el inventario")
		return
	if not cell_charged:
		show_message("Celda agotada · recárgala en A–01")
		return
	if energy >= 99.9 and flashlight_battery >= 99.9:
		show_message("Reservas completas · celda sin utilizar")
		return
	cell_charged = false
	flashlight_battery = 100.0
	energy = minf(100.0, energy + 50.0)
	show_message("Celda conectada · batería y energía restablecidas")
	flashlight_changed.emit(flashlight_enabled, flashlight_battery)
	_emit_runtime_status()

func _selected_item() -> StringName:
	if game_state == null or selected_quick_slot >= game_state.quick_slots.size():
		return &""
	return game_state.quick_slots[selected_quick_slot]

func _emit_selected_slot() -> void:
	quick_slot_changed.emit(selected_quick_slot, _selected_item())

func _emit_runtime_status() -> void:
	tool_state_changed.emit(energy, flashlight_battery, active_weapon)
	flashlight_changed.emit(flashlight_enabled, flashlight_battery)

func _item_name(item_id: StringName) -> String:
	match item_id:
		&"pulse": return "Emisor UV"
		&"cryo": return "Proyector criogénico"
		&"lamp": return "Linterna"
		&"card": return "Tarjeta V–03"
		&"cell": return "Celda de carga"
		&"recorder": return "Bitácora"
		&"sample": return "Muestra V–03"
		_: return str(item_id)

func _on_inventory_changed(_items: Array) -> void:
	if game_state == null:
		return
	if not game_state.has_item(&"lamp"):
		flashlight_enabled = false
		if is_instance_valid(_field_light):
			_field_light.visible = false
	if not game_state.has_item(&"pulse") and active_weapon == 1:
		active_weapon = -1
	if not game_state.has_item(&"cryo") and active_weapon == 2:
		active_weapon = -1
	_emit_runtime_status()
	_emit_selected_slot()

func _on_quick_slots_changed(_slots: Array) -> void:
	_emit_selected_slot()
