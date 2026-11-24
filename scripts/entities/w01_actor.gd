class_name W01Actor
extends Node3D

signal behavior_changed(state: String, aggression: float, intent: String)

@export_range(0.0, 1.0) var aggression: float = 0.2
@export var look_target_path: NodePath

const ATTACK_DURATION := 1.22
const ATTACK_COOLDOWN := 6.4
const RECOVERY_DURATION := 2.15

var state: String = "WATCHING"
var intent: String = "Observando"
var memory: float = 0.0
var _time: float = 0.0
var _state_elapsed: float = 0.0
var _attack_cooldown: float = 0.0
var _cold_remaining: float = 0.0
var _uv_flash: float = 0.0
var _persist_timer: float = 0.0
var _reported_state: String = ""
var _reported_intent: String = ""
var _lure_position: Vector3 = Vector3.ZERO
var _lure_remaining: float = 0.0
var _prior_player_position: Vector3 = Vector3.ZERO
var _last_known_position: Vector3 = Vector3.ZERO
var _head: MeshInstance3D
var _gum: MeshInstance3D
var _throat: MeshInstance3D
var _eye_roots: Array[Node3D] = []
var _arms: Array[Node3D] = []
var _effect_light: OmniLight3D
var _game_state: GameState

func _ready() -> void:
	add_to_group(&"w01_actor")
	set_meta("survey_id", "w01")
	set_meta("survey_name", "W–01 · El Observador")
	set_meta("survey_zone", "c04")
	set_meta("survey_detail", "Organismo de contención con percepción local y memoria a corto plazo")
	_head = get_node("Core/W01_Core/Head") as MeshInstance3D
	_gum = _head.get_node("Gum") as MeshInstance3D
	_throat = _head.get_node("Throat") as MeshInstance3D
	var eyes_root := get_node("Eyes/W01_Seven_Eyes")
	for child: Node in eyes_root.get_children():
		if child is Node3D:
			_eye_roots.append(child as Node3D)
	var arms_root := get_node("Tentacles/W01_20_Tentacles")
	for child: Node in arms_root.get_children():
		if child is Node3D and child.name.begins_with("arm-"):
			_arms.append(child as Node3D)
	_game_state = get_tree().get_first_node_in_group(&"game_state") as GameState
	if _game_state != null and str(_game_state.watcher_state.get("zone", "c04")) == "c04":
		state = str(_game_state.watcher_state.get("state", state))
		aggression = clampf(float(_game_state.watcher_state.get("aggression", aggression)), 0.0, 1.0)
		memory = maxf(0.0, float(_game_state.watcher_state.get("memory", memory)))
	var target := get_node_or_null(look_target_path) as Node3D
	if target != null:
		_prior_player_position = target.global_position
		_last_known_position = target.global_position
	_effect_light = OmniLight3D.new()
	_effect_light.name = "ResponseLight"
	_effect_light.position = Vector3(0.0, 3.0, 0.55)
	_effect_light.omni_range = 8.0
	_effect_light.light_energy = 0.0
	_effect_light.visible = false
	add_child(_effect_light)

func _process(delta: float) -> void:
	_time += delta
	_state_elapsed += delta
	_attack_cooldown = maxf(0.0, _attack_cooldown - delta)
	_cold_remaining = maxf(0.0, _cold_remaining - delta)
	_uv_flash = maxf(0.0, _uv_flash - delta)
	_lure_remaining = maxf(0.0, _lure_remaining - delta)
	_update_behavior(delta)
	var breath := sin(_time * (1.25 + aggression * 0.55)) * 0.018
	var core := get_node("Core/W01_Core") as Node3D
	core.scale = Vector3(1.0 + breath * 0.45, 1.0 + breath, 1.0 + breath * 0.25)
	core.position.y = sin(_time * 0.7) * 0.025
	var opening := 0.035 + aggression * 0.13
	if state == "CURIOUS":
		opening = 0.17
	elif state == "AGGRESSIVE":
		opening = 0.33 + sin(_time * 4.1) * 0.09
	elif state == "ATTACK":
		opening = 0.98
	elif state == "RECOVERY":
		opening = 0.08 + _attack_drive() * 0.42
	if _uv_flash > 0.0:
		opening = minf(opening, 0.12)
	_set_mouth(opening)
	_update_eyes(delta)
	for index: int in _arms.size():
		var arm := _arms[index]
		var strike := _attack_drive() if state == "ATTACK" else 0.0
		arm.rotation.z = sin(_time * (0.56 + float(index % 4) * 0.11) + index * 1.23) * (0.045 + aggression * 0.035) + (0.18 * strike if index % 2 == 0 else -0.18 * strike)
		arm.rotation.y = cos(_time * 0.41 + index * 0.73) * 0.035
	if _effect_light != null:
		_effect_light.visible = _uv_flash > 0.0 or _cold_remaining > 0.0
		_effect_light.light_color = Color(0.78, 0.58, 1.0) if _uv_flash > 0.0 else Color(0.38, 0.9, 1.0)
		_effect_light.light_energy = 2.4 if _uv_flash > 0.0 else 1.15
	_persist_timer -= delta
	if _game_state != null and _persist_timer <= 0.0:
		_persist_timer = 0.5
		_game_state.watcher_state = {
			"zone": "c04",
			"state": state,
			"aggression": aggression,
			"memory": memory,
			"intent": intent,
		}

func apply_uv() -> void:
	_attack_cooldown = maxf(_attack_cooldown, 5.0)
	_uv_flash = 1.1
	_cold_remaining = 0.0
	_transition_to("RECOVERY")
	aggression = minf(aggression, 0.35)
	behavior_changed.emit(state, aggression, "Pulso UV · recuperación")

func apply_cryo() -> void:
	_cold_remaining = 7.0
	_transition_to("RECOVERY")
	behavior_changed.emit(state, aggression, "Niebla criogénica · ralentizado")

func investigate_lure(position: Vector3, duration: float = 5.4) -> void:
	_lure_position = position
	_lure_remaining = maxf(0.5, duration)
	_last_known_position = position
	memory = maxf(memory, duration)
	intent = "Investiga el señuelo"
	behavior_changed.emit(state, aggression, intent)

func _update_behavior(delta: float) -> void:
	var old_state := state
	var old_intent := intent
	var target := get_node_or_null(look_target_path) as Node3D
	if target == null:
		return
	var player_position := target.global_position
	var delta_to_player := player_position - global_position
	var distance := Vector2(delta_to_player.x, delta_to_player.z).length()
	var bearing := atan2(delta_to_player.x, delta_to_player.z)
	var facing := absf(wrapf(bearing - global_rotation.y, -PI, PI))
	var seen := distance < 33.0 and facing < 1.29
	var moving := player_position.distance_squared_to(_prior_player_position) > 0.00012
	var running := target is NexusPlayer and (target as NexusPlayer).velocity.length() > 6.0
	var heard := distance < (16.0 if running else 8.0) and moving
	_prior_player_position = player_position
	if seen or heard:
		memory = 5.4
		_last_known_position = player_position
	else:
		memory = maxf(0.0, memory - delta)

	var next_state := _distance_state(distance)
	if state == "ATTACK":
		if _state_elapsed >= ATTACK_DURATION:
			_transition_to("RECOVERY")
	elif state == "RECOVERY":
		if _state_elapsed >= RECOVERY_DURATION and _cold_remaining <= 0.0 and _uv_flash <= 0.0:
			_transition_to(next_state)
	elif distance < 5.45 and _attack_cooldown <= 0.0 and _cold_remaining <= 0.0:
		_attack_cooldown = ATTACK_COOLDOWN
		_transition_to("ATTACK")
	else:
		_transition_to(next_state)

	var desired_aggression := 0.2
	match state:
		"IDLE": desired_aggression = 0.05
		"WATCHING": desired_aggression = 0.2
		"CURIOUS": desired_aggression = 0.46
		"AGGRESSIVE": desired_aggression = 0.79
		"ATTACK": desired_aggression = 1.0
		"RECOVERY": desired_aggression = 0.31
	aggression = lerpf(aggression, desired_aggression, 1.0 - exp(-1.55 * delta))
	if _cold_remaining > 0.0:
		aggression = minf(aggression, 0.4)

	var destination := player_position
	var speed := 0.0
	var turn_speed := 0.35
	if _lure_remaining > 0.0:
		destination = _lure_position
		intent = "Investiga el señuelo"
		speed = 0.45
		turn_speed = 1.9
	elif _cold_remaining > 0.0 or state == "RECOVERY":
		intent = "Se repliega"
		if distance < 6.0:
			destination = global_position - delta_to_player
			speed = 0.42
		turn_speed = 0.5
	elif state == "ATTACK":
		intent = "Ataque"
		destination = player_position
		speed = 1.0
		turn_speed = 2.1
	elif seen or heard:
		if heard and not seen:
			intent = "Escucha pasos"
		else:
			intent = "Se aproxima" if distance < 10.0 else "Observa"
		if distance >= 5.45:
			speed = 1.12 if distance < 10.0 else 0.84
		turn_speed = 1.35
	elif memory > 0.0:
		intent = "Busca el último contacto"
		destination = _last_known_position
		speed = 0.68
		turn_speed = 1.1
	else:
		intent = "Explora"
		destination = global_position + Vector3(9.8 * sin(_time * 0.18), 0.0, 9.8 * cos(_time * 0.18))
		speed = 0.62
		turn_speed = 0.35

	var planar := destination - global_position
	planar.y = 0.0
	var planar_length := planar.length()
	if planar_length > 0.001:
		planar /= planar_length
		var desired_yaw := atan2(planar.x, planar.z)
		global_rotation.y = rotate_toward(global_rotation.y, desired_yaw, turn_speed * delta)
	if planar_length < 1.6 and speed > 0.0 and _lure_remaining <= 0.0:
		speed = 0.0
	if _cold_remaining > 0.0:
		speed *= 0.35
	if speed > 0.0:
		var next_position := global_position + planar * speed * delta
		# Keep W–01 inside the structural envelope used by the current C–04 slice.
		next_position.x = clampf(next_position.x, -31.0, 31.0)
		next_position.z = clampf(next_position.z, -37.0, 37.0)
		global_position.x = next_position.x
		global_position.z = next_position.z
	if old_state != state or old_intent != intent:
		behavior_changed.emit(state, aggression, intent)

func _distance_state(distance: float) -> String:
	if distance > 11.5:
		return "IDLE"
	if distance > 7.1:
		return "WATCHING"
	if distance > 5.05:
		return "CURIOUS"
	return "AGGRESSIVE"

func _transition_to(next_state: String) -> void:
	if next_state == state:
		return
	state = next_state
	_state_elapsed = 0.0

func _attack_drive() -> float:
	if state == "ATTACK":
		return sin(clampf(_state_elapsed / ATTACK_DURATION, 0.0, 1.0) * PI)
	if state == "RECOVERY":
		return 0.42 * exp(-_state_elapsed * 1.15)
	return 0.0

func _set_mouth(value: float) -> void:
	for mesh: MeshInstance3D in [_head, _gum, _throat]:
		if mesh != null and mesh.mesh.get_blend_shape_count() > 0:
			mesh.set_blend_shape_value(0, clampf(value, 0.025, 1.0))

func _update_eyes(delta: float) -> void:
	var target := get_node_or_null(look_target_path) as Node3D
	if target == null:
		return
	for eye: Node3D in _eye_roots:
		var local_direction := eye.global_transform.basis.inverse() * (target.global_position - eye.global_position).normalized()
		var yaw := clampf(atan2(local_direction.x, local_direction.z), -0.16, 0.16)
		var pitch := clampf(-asin(local_direction.y), -0.12, 0.12)
		eye.rotation.y = lerpf(eye.rotation.y, yaw, minf(1.0, delta * 5.0))
		eye.rotation.x = lerpf(eye.rotation.x, pitch, minf(1.0, delta * 5.0))
