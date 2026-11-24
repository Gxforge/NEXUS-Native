extends Node
## Captura el panel de ajustes (`cfg` de `App.tsx`) en Xvfb.

@onready var main: Node = $Main

var _stage := 0
var _frames := 0


func _ready() -> void:
	# El árbol se pausa al abrir el panel: la captura debe seguir contando frames.
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(_delta: float) -> void:
	_frames += 1
	match _stage:
		0:
			if _frames >= 8:
				(main.get_node("GameState") as GameState).current_zone = &"c04"
				if not main.start_game():
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
				var hud := main.get_node("UI/HUD") as NexusHUD
				var player := main.get_node("PersistentWorld/Player") as NexusPlayer
				player.set_controls_enabled(false)
				hud._on_panel_requested(&"pause")
				hud._open_panel(&"cfg")
				_stage = 3
				_frames = 0
		3:
			if _frames >= 10:
				var image := get_viewport().get_texture().get_image()
				var error := image.save_png("res://reports/panel-settings.png")
				print("CAPTURE reports/panel-settings.png -> %s" % ("ok" if error == OK else str(error)))
				get_tree().quit()
