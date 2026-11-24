extends Node3D
## Captura una secuencia de fotogramas del mobiliario animado (para el GIF).
##
## Desactiva el reloj propio de `ZoneDressing` y avanza la animación a mano para
## que la secuencia sea reproducible aunque el render vaya lento en Xvfb.

const SHOTS := {
	"h01": ["res://zones/zone_h01_hydraulics.tscn",
		Vector3(3.5, 1.75, -49.0), Vector3(-5.5, 2.0, -62.0)],
	"b02": ["res://zones/zone_b02_turbines.tscn",
		Vector3(24.0, 1.9, -3.0), Vector3(22.0, 2.8, -16.6)],
	"c04": ["res://zones/zone_c04_shell.tscn",
		Vector3(12.0, 2.0, 8.0), Vector3(2.0, 1.8, 26.0)],
}
const FRAMES := 16
const STEP := 0.12

var _order: Array = []
var _index := 0
var _frame := 0
var _zone: Node3D
var _dressing: ZoneDressing
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
	add_child(sun)
	_camera = Camera3D.new()
	_camera.fov = 66.0
	add_child(_camera)
	_camera.current = true
	_order = SHOTS.keys()
	_order.sort()
	_load()


func _load() -> void:
	if _zone != null:
		_zone.queue_free()
		_zone = null
	if _index >= _order.size():
		get_tree().quit()
		return
	var id: String = _order[_index]
	var shot: Array = SHOTS[id]
	_zone = (load(shot[0]) as PackedScene).instantiate()
	add_child(_zone)
	for child in _zone.get_children():
		var label := String(child.name)
		if label.begins_with("Portal") or label.begins_with("Pickup"):
			child.visible = false
	_dressing = _zone.get_node_or_null("Dressing") as ZoneDressing
	if _dressing != null:
		_dressing.running = false
	_camera.position = shot[1]
	_camera.look_at(shot[2])
	_frame = 0


func _process(_delta: float) -> void:
	if _zone == null:
		return
	_frame += 1
	# Dos fotogramas de calentamiento antes de empezar la secuencia.
	var shot_index: int = _frame - 2
	if shot_index < 0:
		return
	if shot_index >= FRAMES:
		_index += 1
		_load()
		return
	var id: String = _order[_index]
	if _dressing != null:
		_dressing.animate(float(shot_index) * STEP)
	if shot_index == 0:
		return
	var image := get_viewport().get_texture().get_image()
	var path := "res://reports/frames/%s-%02d.png" % [id, shot_index]
	image.save_png(path)
