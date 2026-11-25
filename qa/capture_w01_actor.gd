extends Node
## Captura a W–01 en C–04 de frente, para revisar ojos, párpados y metales.

@onready var main: Node = $Main

var frames := 0
var phase := 0
var manager: ZoneManager
var player: NexusPlayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(_delta: float) -> void:
	frames += 1
	match phase:
		0:
			if frames < 8:
				return
			(main.get_node("GameState") as GameState).current_zone = &"c04"
			if not main.start_game():
				print("CAPTURE W-01 abortado: start_game falló")
				get_tree().quit(1)
				return
			manager = main.get_node("ZoneManager") as ZoneManager
			player = main.get_node("PersistentWorld/Player") as NexusPlayer
			player.set_controls_enabled(false)
			phase = 1
			frames = 0
		1:
			if manager.state != ZoneManager.State.IDLE or frames < 8:
				return
			player.global_position = Vector3(0.0, 0.0, 31.0)
			player.rotation = Vector3.ZERO
			player.velocity = Vector3.ZERO
			var camera := player.get_node("Camera3D") as Camera3D
			camera.rotation = Vector3.ZERO
			camera.global_position = Vector3(0.0, 2.4, 31.0)
			camera.look_at(Vector3(0.0, 2.8, 22.0), Vector3.UP)
			phase = 2
			frames = 0
		2:
			if frames < 30:
				return
			var image := get_viewport().get_texture().get_image()
			var error := image.save_png("res://reports/w01-c04-first-look.png")
			print("CAPTURE res://reports/w01-c04-first-look.png -> %s" % ("ok" if error == OK else str(error)))
			# Segunda toma: el morro abierto del todo (`Head.ts`), con la
			# dentadura bajada al ancla abierta.
			var w01 := get_tree().get_first_node_in_group(&"w01_actor")
			if w01 != null and w01.get("jaw") != null:
				(w01.get("jaw") as W01Jaw).pin(1.0)
			phase = 3
			frames = 0
		3:
			if frames < 20:
				return
			var mouth := get_viewport().get_texture().get_image()
			var mouth_error := mouth.save_png("res://reports/w01-maw.png")
			print("CAPTURE res://reports/w01-maw.png -> %s" % ("ok" if mouth_error == OK else str(mouth_error)))
			phase = 4
			frames = 0
		_:
			if frames > 4:
				get_tree().quit()
