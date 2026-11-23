extends Node

@onready var main: Node = $Main
var stage: int = 0
var frames: int = 0

func _process(_delta: float) -> void:
	frames += 1
	if stage == 0 and frames >= 8:
		_save("res://reports/startup-main-menu.png")
		main.start_game()
		stage = 1
		frames = 0
	elif stage == 1 and frames >= 1:
		_save("res://reports/startup-loading.png")
		stage = 2
	elif stage == 2:
		var manager := main.get_node("ZoneManager") as ZoneManager
		if manager.current_zone != null and manager.state == ZoneManager.State.IDLE:
			frames = 0
			stage = 3
	elif stage == 3 and frames >= 30:
		_save("res://reports/startup-c04-ready.png")
		get_tree().quit()

func _save(path: String) -> void:
	var error := get_viewport().get_texture().get_image().save_png(path)
	if error != OK: push_error("Startup capture failed: %s" % error)
