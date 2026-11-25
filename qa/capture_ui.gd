extends Node
## Captura el menú principal, la pantalla de carga real y la apertura de la bóveda.

@onready var main: Node = $Main

var frames := 0
var phase := 0
var manager: ZoneManager
var player: NexusPlayer
var state: GameState


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _snap(path: String) -> void:
	var image := get_viewport().get_texture().get_image()
	var error := image.save_png(path)
	print("CAPTURE %s -> %s" % [path, "ok" if error == OK else str(error)])


func _process(_delta: float) -> void:
	frames += 1
	match phase:
		0:
			# Menú principal con la ilustración de fondo.
			if frames < 12:
				return
			_snap("res://reports/ui-main-menu.png")
			state = main.get_node("GameState") as GameState
			state.current_zone = &"v03_gallery"
			if not main.start_game():
				print("CAPTURE abortado: start_game falló")
				get_tree().quit(1)
				return
			manager = main.get_node("ZoneManager") as ZoneManager
			player = main.get_node("PersistentWorld/Player") as NexusPlayer
			player.set_controls_enabled(false)
			phase = 1
			frames = 0
		1:
			# Pantalla de carga: barra y datos reales a mitad de precarga.
			if frames == 2:
				_snap("res://reports/ui-loading.png")
			if manager.state != ZoneManager.State.IDLE or frames < 10:
				return
			var door := manager.current_zone.find_child("VaultDoor", true, false) as Node3D
			if door == null:
				print("CAPTURE sin VaultDoor en la zona")
				get_tree().quit(1)
				return
			print("CAPTURE puerta en ", door.global_position, " rig=", state.vault != null and state.vault.door != null)
			var spot := door.global_position + Vector3(0.0, -1.7, 8.5)
			player.global_position = spot
			player.rotation = Vector3.ZERO
			var direction := door.global_position - (spot + Vector3(0.0, 1.72, 0.0))
			var flat := Vector2(direction.x, direction.z).length()
			player.rotation.y = atan2(-direction.x, -direction.z)
			player.set("_pitch", atan2(direction.y, flat))
			(player.get_node("Camera3D") as Camera3D).rotation.x = float(player.get("_pitch"))
			# Bóveda a mitad de secuencia: corona girando y disco saliendo.
			if state.vault != null:
				state.vault.timer = 14.6
			phase = 2
			frames = 0
		2:
			if frames < 20:
				return
			_snap("res://reports/vault-opening.png")
			# Y con la puerta ya abierta, para ver el traslado hidráulico.
			if state.vault != null:
				state.vault.timer = 21.5
			phase = 3
			frames = 0
		3:
			if frames < 20:
				return
			_snap("res://reports/vault-open.png")
			phase = 4
			frames = 0
		_:
			if frames > 4:
				get_tree().quit()
