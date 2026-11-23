class_name W01Actor
extends Node3D

@export var aggression: float = 0.2
@export var look_target_path: NodePath

var _time: float = 0.0
var _head: MeshInstance3D
var _gum: MeshInstance3D
var _throat: MeshInstance3D
var _eye_roots: Array[Node3D] = []
var _arms: Array[Node3D] = []

func _ready() -> void:
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

func _process(delta: float) -> void:
	_time += delta
	var breath := sin(_time * (1.25 + aggression * 0.55)) * 0.018
	var core := get_node("Core/W01_Core") as Node3D
	core.scale = Vector3(1.0 + breath * 0.45, 1.0 + breath, 1.0 + breath * 0.25)
	var opening := clampf(0.035 + aggression * 0.13 + sin(_time * 0.7) * 0.018, 0.025, 1.0)
	_set_mouth(opening)
	_update_eyes(delta)
	for index: int in _arms.size():
		var arm := _arms[index]
		arm.rotation.z = sin(_time * (0.56 + float(index % 4) * 0.11) + index * 1.23) * 0.045
		arm.rotation.y = cos(_time * 0.41 + index * 0.73) * 0.035

func _set_mouth(value: float) -> void:
	for mesh: MeshInstance3D in [_head, _gum, _throat]:
		if mesh != null and mesh.mesh.get_blend_shape_count() > 0:
			mesh.set_blend_shape_value(0, value)

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
