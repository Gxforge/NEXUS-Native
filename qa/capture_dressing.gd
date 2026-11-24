extends Node3D
## Captura el mobiliario de cada zona (`ZoneDressing`) en Xvfb.
##
## Encuadra automáticamente el AABB de las mallas construidas por el nodo
## `Dressing` de cada zona para comprobar el aspecto contra la versión web.

const SCENES := {
	"h01": "res://zones/zone_h01_hydraulics.tscn",
	"b02": "res://zones/zone_b02_turbines.tscn",
	"c04": "res://zones/zone_c04_shell.tscn",
	"electrical": "res://zones/zone_electrical.tscn",
	"surveillance": "res://zones/zone_surveillance.tscn",
	"d02": "res://zones/zone_d02_records.tscn",
	"v03_gallery": "res://zones/zone_v03_gallery.tscn",
	"v03_cryo": "res://zones/zone_v03_cryotheque.tscn",
}
## Vistas a la altura de los ojos (1,75 m) hacia el mobiliario de cada zona.
const VIEWS := {
	"h01": [Vector3(3.5, 1.75, -49.0), Vector3(-5.5, 2.0, -62.0)],
	"b02": [Vector3(30.0, 1.8, -2.0), Vector3(22.0, 2.8, -17.0)],
	"c04": [Vector3(12.0, 2.0, 8.0), Vector3(2.0, 1.8, 26.0)],
	"electrical": [Vector3(33.0, 1.75, 79.0), Vector3(43.0, 1.9, 70.0)],
	"surveillance": [Vector3(-17.6, 1.7, 69.0), Vector3(-17.6, 3.4, 83.4)],
	"d02": [Vector3(33.0, 1.75, -30.0), Vector3(44.0, 1.6, -56.0)],
	"v03_gallery": [Vector3(27.0, 1.75, -26.0), Vector3(27.0, 2.0, -52.0)],
	"v03_cryo": [Vector3(31.0, 1.75, -83.5), Vector3(26.0, 1.6, -94.0)],
}

var _order: Array = []
var _index := 0
var _frames := 0
var _zone: Node3D
var _camera: Camera3D


func _ready() -> void:
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.03, 0.05, 0.06)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.68, 0.72)
	env.ambient_light_energy = 0.32
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.environment = env
	add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-58.0, 132.0, 0.0)
	sun.light_energy = 0.35
	sun.shadow_enabled = true
	add_child(sun)
	_camera = Camera3D.new()
	_camera.fov = 66.0
	add_child(_camera)
	_camera.current = true
	_order = SCENES.keys()
	_order.sort()
	_load_next()


func _load_next() -> void:
	if _zone != null:
		_zone.queue_free()
		_zone = null
	if _index >= _order.size():
		get_tree().quit()
		return
	var id: String = _order[_index]
	var packed: PackedScene = load(SCENES[id])
	_zone = packed.instantiate()
	add_child(_zone)
	for child in _zone.get_children():
		var label := String(child.name)
		if label.begins_with("Portal") or label.begins_with("Pickup"):
			child.visible = false
	_frames = 0


func _process(_delta: float) -> void:
	if _zone == null:
		return
	_frames += 1
	if _frames == 4:
		_frame_camera()
	elif _frames == 12:
		var id: String = _order[_index]
		var image := get_viewport().get_texture().get_image()
		var path := "res://reports/dressing-%s.png" % id
		var error := image.save_png(path)
		var dressing: Node = _zone.get_node_or_null("Dressing")
		var count := 0
		if dressing != null and dressing.has_method("count_meshes"):
			count = dressing.count_meshes(dressing)
		print("CAPTURE %s -> %s meshes=%d" % [path, "ok" if error == OK else str(error), count])
		_index += 1
		_load_next()


func _frame_camera() -> void:
	var dressing: Node3D = _zone.get_node_or_null("Dressing")
	var boxes := _aabb(dressing if dressing != null else _zone)
	if boxes.size == Vector3.ZERO:
		_camera.position = Vector3(6.0, 4.0, 8.0)
		_camera.look_at(Vector3.ZERO)
		return
	var id: String = _order[_index]
	var view: Array = VIEWS.get(id, [])
	if view.size() == 2:
		_camera.position = view[0]
		_camera.look_at(view[1])
		return
	var entry := _zone.get_node_or_null("DoorSockets/entry") as Node3D
	if entry != null:
		var target := boxes.get_center()
		target.y = 1.9
		_camera.position = entry.global_position + Vector3(0.0, 1.68, 0.0)
		if _camera.position.distance_to(target) > 2.0:
			_camera.look_at(target)
			return
	var radius: float = boxes.size.length() * 0.5
	var distance: float = radius / sin(deg_to_rad(_camera.fov * 0.5)) * 0.72
	_camera.position = boxes.get_center() + Vector3(1.0, 0.45, 1.0).normalized() * distance
	_camera.look_at(boxes.get_center())
	_camera.far = distance * 6.0


func _has_ancestor(node: Node, label: String) -> bool:
	var current := node
	while current != null:
		if String(current.name) == label:
			return true
		current = current.get_parent()
	return false


func _aabb(root: Node) -> AABB:
	var result := AABB()
	var first := true
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		for child in node.get_children():
			stack.append(child)
		var mesh := node as MeshInstance3D
		if mesh == null or mesh.mesh == null:
			continue
		if _has_ancestor(node, "FloorGrid"):
			continue
		var box: AABB = mesh.global_transform * mesh.get_aabb()
		if first:
			result = box
			first = false
		else:
			result = result.merge(box)
	return result
