extends Node

@onready var main: Node = $Main
var frames: int = 0
var prepared: bool = false

func _ready() -> void:
	main.start_game()

func _process(_delta: float) -> void:
	var manager := main.get_node("ZoneManager") as ZoneManager
	if not prepared and manager.current_zone != null and manager.state == ZoneManager.State.IDLE:
		var player := main.get_node("PersistentWorld/Player") as NexusPlayer
		var camera := player.get_node("Camera3D") as Camera3D
		player.global_position = Vector3(0, 0, 31)
		player.rotation = Vector3.ZERO
		camera.rotation = Vector3.ZERO
		camera.global_position = Vector3(0, 2.4, 31)
		camera.look_at(Vector3(0, 2.6, 22), Vector3.UP)
		(manager.current_zone.get_node("PortalA01") as StreamingSectorDoor).set_streaming_enabled(false)
		prepared = true
	if prepared:
		frames += 1
		if frames == 90:
			var image := get_viewport().get_texture().get_image()
			var error := image.save_png("res://reports/w01-c04-first-look.png")
			if error != OK: push_error("W-01 capture failed: %s" % error)
		if frames > 110:
			get_tree().quit()
