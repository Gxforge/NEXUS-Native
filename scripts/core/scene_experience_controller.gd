class_name SceneExperienceController
extends Node

signal scan_completed(record: Dictionary)
signal contact_emitted(kind: StringName, position: Vector3)

@export var camera_path: NodePath
@export var game_state_path: NodePath
@export var player_path: NodePath
@export var zones_path: NodePath

var survey := SurveySystem.new()
var highlighter := SurveyHighlight.new()
var contact_fx := ContactFx3D.new()
## Recorte por portales (port de `Visibility.ts`): oculta lo que queda entero
## detrás de una compuerta cerrada. Nunca toca la física.
var visibility := Visibility.new()
## Aire y zumbido procedurales (port de `Breath.ts`).
var breath: W01Breath

@onready var camera: Camera3D = get_node(camera_path) as Camera3D
@onready var game_state: GameState = get_node(game_state_path) as GameState
@onready var player: NexusPlayer = get_node_or_null(player_path) as NexusPlayer
var _zones: Node3D
var _doors: Array = []
var _visibility_ready := false
var _visibility_dirty := true
var _known_zones := -1

func _ready() -> void:
	survey.name = "SurveySystem"
	highlighter.name = "SurveyHighlight"
	contact_fx.name = "ContactFx"
	add_child(survey)
	add_child(highlighter)
	add_child(contact_fx)
	survey.range_m = 22.0
	survey.attach_highlighter(highlighter)
	survey.restore(game_state.survey_records)
	survey.target_scanned.connect(_on_target_scanned)
	breath = W01Breath.new()
	breath.name = "Breath"
	add_child(breath)
	_setup_visibility()

func scan_viewport_point(viewport_position: Vector2) -> Dictionary:
	return survey.scan_from_camera(camera, viewport_position)

func emit_contact(hit: Dictionary, gas: bool = false) -> bool:
	if hit.is_empty():
		return false
	var position: Vector3 = ContactQuery3D.contact_position(hit)
	var normal: Vector3 = ContactQuery3D.contact_normal(hit)
	if gas:
		contact_fx.emit_gas(position, normal)
		contact_emitted.emit(&"gas", position)
	else:
		contact_fx.emit_impact(position, normal)
		contact_emitted.emit(&"impact", position)
	return true

## Respiración y zumbido de máquina, con los mismos pesos que la web.
func _process(delta: float) -> void:
	if breath == null:
		return
	if player == null or not player.controls_enabled:
		breath.active = false
		breath.quiet()
		visibility.restore()
		return
	breath.active = true
	_apply_visibility()
	var first_person := player.view.is_first_person()
	breath.update(delta, W01Breath.fatigue_for(player.stamina) if first_person else 0.0)
	var grid := game_state.power
	if grid == null:
		breath.machine(0.0, 0.0)
		return
	for index in grid.feeds.size():
		breath.set_feed(index, grid.feeds[index])
	var near := 0.0
	if first_person and not grid.tripped:
		near = W01Breath.feeds_near(player.global_position)
	breath.machine(near, grid.delivered / 112.0)

func _setup_visibility() -> void:
	_zones = get_node_or_null(zones_path) as Node3D
	var manager := get_tree().get_first_node_in_group(&"zone_manager") as ZoneManager
	if manager != null:
		manager.zone_ready.connect(_on_zones_changed)
		manager.zone_unloaded.connect(_on_zones_changed)

func _on_zones_changed(_zone_id: StringName) -> void:
	_visibility_dirty = true

func _zone_graph() -> Dictionary:
	var file := FileAccess.open("res://data/zone_graph.json", FileAccess.READ)
	if file == null:
		return {}
	var text := file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		return parsed as Dictionary
	return {}

## Reconstruye la lista de cajas y aplica el recorte. Se llama una vez por
## fotograma desde `_process`: la web lo hace en cada cámara.
func _apply_visibility() -> void:
	if _zones == null:
		return
	var zone_count := _zones.get_child_count()
	if not _visibility_ready or _visibility_dirty or zone_count != _known_zones:
		_doors = get_tree().get_nodes_in_group(&"sector_doors")
		visibility.configure(_zones, _zone_graph(), _doors)
		if camera != null:
			visibility.probe(camera.get_world_3d())
		_known_zones = zone_count
		_visibility_dirty = false
		_visibility_ready = true
	visibility.apply(camera.global_position)

func visibility_hidden() -> int:
	return visibility.hidden_count()

func _on_target_scanned(record: Dictionary) -> void:
	game_state.store_survey_records(survey.snapshot())
	scan_completed.emit(record)
