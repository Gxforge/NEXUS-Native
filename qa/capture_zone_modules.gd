extends Node

## Renders an arrival frame per migrated module (graphics build, Xvfb).
## Stage machine mirrors qa/capture_startup_flow.gd.

@onready var main: Node = $Main
const ROUTE: Array[StringName] = [&"b02", &"v03_gallery", &"h01", &"d02", &"v03_cryo", &"electrical", &"surveillance", &"transit_hub", &"transit_road", &"transit_rail", &"a01"]

var _stage := 0
var _frames := 0
var _index := 0

func _process(_delta: float) -> void:
	_frames += 1
	match _stage:
		0:
			if _frames >= 8:
				(main.get_node("GameState") as GameState).current_zone = &"c04"
				if not main.start_game():
					push_error("Capture could not start the game")
					get_tree().quit(1)
					return
				_stage = 1
				_frames = 0
		1:
			var manager := main.get_node("ZoneManager") as ZoneManager
			if manager.current_zone != null and manager.state == ZoneManager.State.IDLE:
				_stage = 2
				_frames = 0
		2:
			if _frames >= 8:
				_face_room()
				_stage = 3
				_frames = 0
		3:
			if _frames >= 6:
				_save("res://reports/zone-%s.png" % str(main.get_node("ZoneManager").current_zone.zone_id))
				if _index >= ROUTE.size():
					get_tree().quit()
					return
				var manager := main.get_node("ZoneManager") as ZoneManager
				var next_zone := ROUTE[_index]
				_index += 1
				if not manager.transition_to(next_zone, &"entry"):
					push_error("Capture could not transition to %s" % next_zone)
					get_tree().quit(1)
					return
				_stage = 1
				_frames = 0

func _face_room() -> void:
	var manager := main.get_node("ZoneManager") as ZoneManager
	var player := main.get_node("PersistentWorld/Player") as NexusPlayer
	var entry := manager.current_zone.get_node_or_null("DoorSockets/entry") as Node3D
	if entry == null:
		return
	player.global_position = entry.global_position
	player.velocity = Vector3.ZERO
	var focus := manager.current_zone.global_position
	if manager.current_zone.get_node_or_null("Transit") != null:
		# El andén 01 de la cápsula, no el origen de la zona (queda a la espalda).
		focus = Vector3(CapsuleTransit.AXIS_X, 1.4, CapsuleTransit.STATION_A - 2.0)
	var direction := focus - entry.global_position
	direction.y = 0.0
	if direction.length() > 0.2:
		player.rotation.y = atan2(-direction.x, -direction.z)
	player.camera.rotation.x = 0.03
	player.set_controls_enabled(false)

func _save(path: String) -> void:
	var image := get_viewport().get_texture().get_image()
	if image == null:
		push_error("Capture viewport unavailable")
		return
	var error := image.save_png(path)
	print("CAPTURE %s -> %s" % [path, "ok" if error == OK else str(error)])
