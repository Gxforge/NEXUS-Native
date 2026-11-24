class_name ZoneDefinition
extends Resource

@export var id: StringName
@export_file("*.tscn") var scene_path: String
@export var display_name: String
@export var spawn_socket: StringName = &"entry"
@export var neighbors: Array[StringName] = []
## Footprint in the runtime scene frame (`world + (9, 0, 14)`), which is the
## frame every zone scene and the persistent player live in.
@export var bounds_min: Vector2 = Vector2.ZERO
@export var bounds_max: Vector2 = Vector2.ZERO
@export var height: float = 9.2

func contains_position(point: Vector3) -> bool:
	return point.x >= bounds_min.x and point.x <= bounds_max.x \
		and point.z >= bounds_min.y and point.z <= bounds_max.y

func size_2d() -> Vector2:
	return bounds_max - bounds_min
