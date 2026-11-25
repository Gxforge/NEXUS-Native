extends Node
## Captura el equipo de primera persona: instrumentos y guante de linterna.
##
## Usa el juego real (`main.tscn`, HUD incluido) para que la imagen muestre lo
## mismo que verá el operador al entrar: manos, mangas y equipo a la vista.

var main: Node

const SPOT := Vector3(24.0, 0.0, 2.0)
const TARGET := Vector3(0.0, 2.2, 30.0)

var _frames := 0
var _phase := 0
var _player: NexusPlayer
var _manager: ZoneManager
var _shots: Array = []


const SAVE_PATH := "user://nexus_native_save.json"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Sesión limpia: si queda un guardado de otra partida, el HUD mostraría su
	# inventario y no el equipo inicial que se quiere fotografiar.
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
	# `Main` se instancia después de limpiar el guardado: si fuera hijo de la
	# escena, su `_ready` cargaría el inventario viejo antes de borrarlo.
	main = (load("res://main.tscn") as PackedScene).instantiate()
	add_child(main)
	_shots = [
		{"name": "uv", "weapon": 0, "lamp": false},
		{"name": "cryo", "weapon": 2, "lamp": true},
		{"name": "reach", "weapon": 1, "lamp": true, "reach": &"press"},
	]
	# Filtro opcional: `-- uv` captura sólo esas tomas.
	var wanted: Array = []
	for argument in OS.get_cmdline_user_args():
		for shot in _shots:
			if String(shot["name"]) == argument:
				wanted.append(shot)
	if not wanted.is_empty():
		_shots = wanted


func _process(_delta: float) -> void:
	_frames += 1
	match _phase:
		0:
			if _frames < 8:
				return
			(main.get_node("GameState") as GameState).current_zone = &"c04"
			if not main.start_game():
				print("CAPTURE FP abortado: start_game falló")
				get_tree().quit(1)
				return
			_manager = main.get_node("ZoneManager") as ZoneManager
			_player = main.get_node("PersistentWorld/Player") as NexusPlayer
			_player.set_controls_enabled(false)
			_manager.transition_to(&"c04", &"entry")
			_phase = 1
			_frames = 0
		1:
			if _manager.state != ZoneManager.State.IDLE or _frames < 8:
				return
			_place()
			_apply_shot()
			_phase = 2
			_frames = 0
		2:
			if _frames < 14:
				return
			var shot: Dictionary = _shots[0]
			var image := get_viewport().get_texture().get_image()
			var path := "res://reports/first_person-%s.png" % String(shot["name"])
			var error := image.save_png(path)
			print("CAPTURE %s -> %s" % [path, "ok" if error == OK else str(error)])
			_shots.remove_at(0)
			if _shots.is_empty():
				get_tree().quit()
				return
			_place()
			_apply_shot()
			_frames = 0


func _place() -> void:
	_player.global_position = SPOT
	_player.velocity = Vector3.ZERO
	var eye := SPOT + Vector3(0.0, 1.72, 0.0)
	var direction: Vector3 = TARGET - eye
	var flat := Vector2(direction.x, direction.z).length()
	_player.rotation.y = atan2(-direction.x, -direction.z)
	_player.set("_pitch", atan2(direction.y, flat))
	(_player.get_node("Camera3D") as Camera3D).rotation.x = float(_player.get("_pitch"))


func _apply_shot() -> void:
	var shot: Dictionary = _shots[0]
	_player.active_weapon = int(shot["weapon"])
	_player.flashlight_battery = 100.0
	_player.flashlight_enabled = bool(shot["lamp"])
	var light := _player.get_node_or_null("Camera3D/FieldFlashlight") as SpotLight3D
	if light != null:
		light.visible = bool(shot["lamp"])
	if shot.has("reach"):
		_player.rig.play_reach(shot["reach"])
	else:
		_player.rig.play_reach(&"grip")
