class_name SceneExperienceController
extends Node

signal scan_completed(record: Dictionary)
signal contact_emitted(kind: StringName, position: Vector3)

@export var camera_path: NodePath
@export var game_state_path: NodePath

var survey := SurveySystem.new()
var highlighter := SurveyHighlight.new()
var contact_fx := ContactFx3D.new()

@onready var camera: Camera3D = get_node(camera_path) as Camera3D
@onready var game_state: GameState = get_node(game_state_path) as GameState

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

func _on_target_scanned(record: Dictionary) -> void:
	game_state.store_survey_records(survey.snapshot())
	scan_completed.emit(record)
