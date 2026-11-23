class_name StructuralShell
extends Node3D

@export_file("*.json") var manifest_path: String
var collision_count := 0

func _ready() -> void:
	_build_collisions()

func _build_collisions() -> void:
	var file := FileAccess.open(manifest_path, FileAccess.READ)
	if file == null:
		push_error("Cannot read structural manifest: %s" % manifest_path)
		return
	var data: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not data is Dictionary:
		push_error("Invalid structural manifest: %s" % manifest_path)
		return
	var body := StaticBody3D.new()
	body.name = "GeneratedCollision"
	add_child(body)
	for box_data: Dictionary in data.get("boxes", []):
		var shape := BoxShape3D.new()
		shape.size = _vec3(box_data["size"])
		var collision := CollisionShape3D.new()
		collision.name = str(box_data["name"])
		collision.position = _vec3(box_data["center"])
		collision.shape = shape
		body.add_child(collision)
		collision_count += 1

func _vec3(values: Array) -> Vector3:
	return Vector3(float(values[0]), float(values[1]), float(values[2]))
