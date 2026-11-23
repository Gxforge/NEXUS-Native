class_name SurveySystem
extends Node

signal target_scanned(record: Dictionary)

@export var range_m: float = 8.0
@export_flags_3d_physics var collision_mask: int = 0xFFFFFFFF

var records: Array[Dictionary] = []
var highlighter: SurveyHighlight

func attach_highlighter(value: SurveyHighlight) -> void:
	highlighter = value

func scan_from_camera(camera: Camera3D, viewport_position: Vector2) -> Dictionary:
	if camera == null or camera.get_world_3d() == null:
		return {}
	var origin := camera.project_ray_origin(viewport_position)
	var destination := origin + camera.project_ray_normal(viewport_position) * range_m
	var hit := ContactQuery3D.first_hit(camera.get_world_3d(), origin, destination, [], collision_mask)
	if hit.is_empty():
		return {}
	var collider: Object = hit.get("collider") as Object
	if not collider is Node:
		return {}
	if highlighter != null and collider is GeometryInstance3D:
		highlighter.begin(collider as GeometryInstance3D)
	return register_target(collider as Node, hit.get("position", Vector3.ZERO) as Vector3)

func register_target(target: Node, position: Vector3 = Vector3.ZERO) -> Dictionary:
	if target == null:
		return {}
	var identity: String = str(target.get_meta("survey_id", target.name))
	var record := {
		"id": identity,
		"name": str(target.get_meta("survey_name", target.name)),
		"zone": str(target.get_meta("zone_id", "unknown")),
		"detail": str(target.get_meta("survey_detail", "")),
		"position": position,
	}
	for existing: Dictionary in records:
		if str(existing.get("id", "")) == identity:
			return existing
	records.append(record)
	target_scanned.emit(record)
	return record

func restore(saved_records: Array[Dictionary]) -> void:
	records.assign(saved_records)

func snapshot() -> Array[Dictionary]:
	return records.duplicate(true)
