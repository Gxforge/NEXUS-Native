class_name SectorDoor
extends Node3D

signal aperture_changed(value: float)

const CLOSED_CENTER := 1.1
const TRAVEL := 2.17
const DAMPING := 5.0

@export_range(0.0, 1.0) var target_aperture := 0.0
var aperture := 0.0
var _state_key: String = ""

@onready var left_leaf: AnimatableBody3D = $LeftLeaf
@onready var right_leaf: AnimatableBody3D = $RightLeaf

func _ready() -> void:
	add_to_group(&"sector_doors")
	_state_key = _make_state_key()
	set_meta("survey_id", "door_%s" % _state_key.replace("/", "_"))
	set_meta("survey_name", "Compuerta %s" % name)
	set_meta("survey_detail", "Compuerta segmentada con apertura motorizada")
	aperture_changed.connect(_on_aperture_changed)
	var game_state := get_tree().get_first_node_in_group(&"game_state") as GameState
	if game_state != null and game_state.door_states.has(_state_key):
		snap_aperture(float(game_state.door_states[_state_key]))
	else:
		apply_aperture(aperture)

func _physics_process(delta: float) -> void:
	var next := lerpf(aperture, target_aperture, 1.0 - exp(-DAMPING * delta))
	if is_equal_approx(next, aperture):
		return
	apply_aperture(next)

func request_open(open: bool) -> void:
	target_aperture = 1.0 if open else 0.0

func snap_aperture(value: float) -> void:
	target_aperture = clampf(value, 0.0, 1.0)
	apply_aperture(target_aperture)

func apply_aperture(value: float) -> void:
	aperture = clampf(value, 0.0, 1.0)
	left_leaf.position = Vector3(-(CLOSED_CENTER + TRAVEL * aperture), 2.15, 0.0)
	right_leaf.position = Vector3(CLOSED_CENTER + TRAVEL * aperture, 2.15, 0.0)
	aperture_changed.emit(aperture)

func _make_state_key() -> String:
	var current: Node = get_parent()
	while current != null:
		if current is ZoneRoot:
			return "%s/%s" % [str((current as ZoneRoot).zone_id), str(name)]
		current = current.get_parent()
	return str(name)

func _on_aperture_changed(value: float) -> void:
	if _state_key.is_empty():
		return
	var game_state := get_tree().get_first_node_in_group(&"game_state") as GameState
	if game_state != null:
		game_state.door_states[_state_key] = value
