extends Node

@onready var main: Node = $Main
var manager: ZoneManager
var camera: Camera3D
var stage := 0
var frames := 0

func _ready() -> void:
	manager = main.get_node("ZoneManager") as ZoneManager
	camera = main.get_node("PersistentWorld/Player/Camera3D") as Camera3D

func _process(_delta: float) -> void:
	if stage == 0 and manager.current_zone != null and manager.state == ZoneManager.State.IDLE:
		if manager.current_zone.zone_id != &"c04":
			manager.transition_to(&"c04", &"to_a01")
			stage = 1
		else:
			_prepare_c04()
	elif stage == 1 and manager.state == ZoneManager.State.IDLE and manager.current_zone.zone_id == &"c04":
		_prepare_c04()
	elif stage == 2:
		frames += 1
		if frames >= 180:
			_capture("res://reports/c04-structural-slice.png")
			manager.transition_to(&"a01", &"from_c04")
			stage = 3
	elif stage == 3 and manager.state == ZoneManager.State.IDLE and manager.current_zone.zone_id == &"a01":
		camera.global_position = Vector3(0.0, 2.1, -4.0)
		camera.look_at(Vector3(0.0, 2.3, -20.0), Vector3.UP)
		(manager.current_zone.get_node("PortalC04") as StreamingSectorDoor).set_streaming_enabled(false)
		frames = 0
		stage = 4
	elif stage == 4:
		frames += 1
		if frames >= 10:
			_capture("res://reports/a01-structural-slice.png")
			frames = 0
			stage = 5
	elif stage == 5:
		frames += 1
		if frames >= 30:
			get_tree().quit()

func _prepare_c04() -> void:
	camera.global_position = Vector3(0.0, 2.1, 10.0)
	camera.look_at(Vector3(0.0, 2.3, 0.0), Vector3.UP)
	var portal := manager.current_zone.get_node("PortalA01") as StreamingSectorDoor
	portal.set_streaming_enabled(false)
	portal.request_open(true)
	frames = 0
	stage = 2

func _capture(path: String) -> void:
	var image := get_viewport().get_texture().get_image()
	var error := image.save_png(path)
	if error != OK:
		push_error("Unable to save vertical-slice capture: %s" % error)
