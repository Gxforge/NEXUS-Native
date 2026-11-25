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
## Ojos animados (parpadeo, pupila y seguimiento) sobre el `.glb` original.
var eyes: W01Eyes
var _arms: Array[Node3D] = []
var _effect_light: OmniLight3D
var _game_state: GameState
var ai: MonsterAI = MonsterAI.new()
var attention: MonsterAttention = MonsterAttention.new()
var grabbing := false

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
	eyes = W01Eyes.new()
	eyes.name = "EyeSystem"
	add_child(eyes)
	eyes.attach(eyes_root)
	# Los `.glb` traen `metallic = 1.0` en tentáculos y párpados: sin mapa de
	# entorno (la web sí lo tenía) se veían negros.
	W01Materials.soften(self)
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
	if _game_state != null and _game_state.watcher_state.has("attention"):
		var saved: Variant = _game_state.watcher_state.get("attention")
		if saved is Dictionary:
			attention.from_dict(saved)
			memory = attention.memory
			intent = attention.intent
	_effect_light = OmniLight3D.new()
	_effect_light.name = "ResponseLight"
	_effect_light.position = Vector3(0.0, 3.0, 0.55)
	_effect_light.omni_range = 8.0
	_effect_light.light_energy = 0.0
	_effect_light.visible = false
	add_child(_effect_light)

func _process(delta: float) -> void:
	_time += delta
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
			"attention": attention.to_dict(),
		}

## Copia el estado de la IA al actor para que el HUD lo vea al instante.
func _sync_from_ai() -> void:
	state = ai.state
	aggression = ai.aggression

func apply_uv() -> void:
	_uv_flash = 1.1
	if eyes != null:
		eyes.flash()
	_cold_remaining = 0.0
	ai.recover()
	_sync_from_ai()
	aggression = minf(aggression, 0.35)
	behavior_changed.emit(state, aggression, "Pulso UV · recuperación")

func apply_cryo() -> void:
	_cold_remaining = 7.0
	ai.recover()
	_sync_from_ai()
	behavior_changed.emit(state, aggression, "Niebla criogénica · ralentizado")

func investigate_lure(position: Vector3, duration: float = 5.4) -> void:
	_lure_position = position
	_lure_remaining = maxf(0.5, duration)
	_last_known_position = position
	attention.last_known = position
	attention.memory = maxf(attention.memory, duration)
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
	var to_player := player_position - global_position
	var distance := Vector2(to_player.x, to_player.z).length()
	var sprint := target is NexusPlayer and (target as NexusPlayer).velocity.length() > 6.0
	var bait: Variant = null
	if _lure_remaining > 0.0:
		bait = _lure_position
	var cold := _cold_remaining > 0.0
	var blocked := cold or _uv_flash > 0.0 or state == MonsterAI.RECOVERY

	# 1) Percepción y navegación (Attention.ts).
	var step := attention.update(global_position, global_rotation.y, player_position,
		delta, bait, state == MonsterAI.RECOVERY, grabbing, cold, sprint)
	global_rotation.y = float(step.get("yaw", global_rotation.y))
	var next_position: Vector3 = step.get("position", global_position)
	# Envolvente de seguridad de la rebanada actual de C-04.
	global_position.x = clampf(next_position.x, -40.0, 40.0)
	global_position.z = clampf(next_position.z, -40.0, 45.0)
	intent = str(step.get("intent", intent))
	memory = float(step.get("memory", memory))

	# 2) Máquina de estados (MonsterAI.ts).
	ai.update(distance, delta, blocked)
	state = ai.state
	aggression = ai.aggression

	if old_state != state or old_intent != intent:
		behavior_changed.emit(state, aggression, intent)

func _attack_drive() -> float:
	return ai.attack_drive()

func _set_mouth(value: float) -> void:
	for mesh: MeshInstance3D in [_head, _gum, _throat]:
		if mesh != null and mesh.mesh.get_blend_shape_count() > 0:
			mesh.set_blend_shape_value(0, clampf(value, 0.025, 1.0))

## Ojos: parpadeo, pupila y seguimiento (`EyeSystem.ts`).
func _update_eyes(delta: float) -> void:
	if eyes == null:
		return
	var target := get_node_or_null(look_target_path) as Node3D
	if target == null:
		return
	eyes.update(_time, delta, target.global_position, aggression)
