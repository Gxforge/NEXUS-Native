extends Node
## Captura las zonas **en el juego real** (`main.tscn`, HUD incluido) para
## comparar el aspecto con la versión web.
##
## A diferencia de `capture_dressing.tscn`, aquí se usa la iluminación y el
## `WorldEnvironment` del propio juego, que es lo que ve el jugador.

@onready var main: Node = $Main

const VIEWS := {
	"h01": [Vector3(3.5, 0.0, -49.0), Vector3(-5.5, 2.0, -62.0)],
	"b02": [Vector3(30.0, 0.0, -3.0), Vector3(22.0, 2.8, -17.0)],
	"electrical": [Vector3(35.0, 0.0, 74.5), Vector3(27.0, 1.2, 68.0)],
	"surveillance": [Vector3(-12.0, 0.0, 68.0), Vector3(-25.0, 2.4, 80.0)],
	"d02": [Vector3(36.2, 0.0, -26.0), Vector3(32.2, 1.0, -58.0)],
	"c04": [Vector3(12.0, 0.0, 8.0), Vector3(2.0, 1.8, 26.0)],
	"v03_gallery": [Vector3(27.4, 0.0, -38.0), Vector3(29.9, 1.0, -44.0)],
	"v03_cryo": [Vector3(31.0, 0.0, -84.0), Vector3(26.0, 1.6, -94.0)],
}

var _order: Array = []
var _index := 0
var _frames := 0
var _phase := 0
var _manager: ZoneManager
var _player: NexusPlayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_order = VIEWS.keys()
	_order.sort()


func _process(_delta: float) -> void:
	_frames += 1
	match _phase:
		0:
			if _frames < 8:
				return
			(main.get_node("GameState") as GameState).current_zone = &"c04"
			if not main.start_game():
				print("CAPTURE abortado: start_game falló")
				get_tree().quit(1)
				return
			_manager = main.get_node("ZoneManager") as ZoneManager
			_player = main.get_node("PersistentWorld/Player") as NexusPlayer
			_player.set_controls_enabled(false)
			_start_zone()
			_phase = 1
			_frames = 0
		1:
			if _manager.state != ZoneManager.State.IDLE or _frames < 6:
				return
			_place()
			_phase = 2
			_frames = 0
		2:
			if _frames < 12:
				return
			var id: String = _order[_index]
			var image := get_viewport().get_texture().get_image()
			var path := "res://reports/ingame-%s.png" % id
			var error := image.save_png(path)
			print("CAPTURE %s -> %s" % [path, "ok" if error == OK else str(error)])
			_index += 1
			_frames = 0
			if _index >= _order.size():
				get_tree().quit()
				return
			_start_zone()
			_phase = 1


## Pide la transición a la zona de este paso (si no estamos ya en ella).
func _start_zone() -> void:
	var id: String = _order[_index]
	if _manager.current_zone != null and _manager.current_zone.zone_id == StringName(id):
		return
	if not _manager.transition_to(StringName(id), &"entry"):
		print("CAPTURE %s: transición rechazada" % id)


## Coloca al operador en el punto de vista y lo orienta al objetivo.
func _place() -> void:
	var id: String = _order[_index]
	var view: Array = VIEWS[id]
	var spot: Vector3 = view[0]
	var target: Vector3 = view[1]
	_player.global_position = spot
	_player.velocity = Vector3.ZERO
	var eye := spot + Vector3(0.0, 1.72, 0.0)
	var direction: Vector3 = target - eye
	var flat := Vector2(direction.x, direction.z).length()
	_player.rotation.y = atan2(-direction.x, -direction.z)
	_player.set("_pitch", atan2(direction.y, flat))
	(_player.get_node("Camera3D") as Camera3D).rotation.x = float(_player.get("_pitch"))
