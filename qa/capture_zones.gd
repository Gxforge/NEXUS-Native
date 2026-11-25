extends Node
## Captura las zonas **en el juego real** (`main.tscn`, HUD incluido) para
## comparar el aspecto con la versión web.
##
## A diferencia de `capture_dressing.tscn`, aquí se usa la iluminación y el
## `WorldEnvironment` del propio juego, que es lo que ve el jugador.

@onready var main: Node = $Main

const VIEWS := {
	"h01": [Vector3(3.5, 0.0, -49.0), Vector3(-5.5, 2.0, -62.0)],
	"b02": [Vector3(24.0, 0.0, -6.0), Vector3(36.0, 2.4, -22.0)],
	"electrical": [Vector3(35.0, 0.0, 74.5), Vector3(27.0, 1.2, 68.0)],
	"surveillance": [Vector3(-12.0, 0.0, 68.0), Vector3(-25.0, 2.4, 80.0)],
	"d02": [Vector3(36.2, 0.0, -26.0), Vector3(32.2, 1.0, -58.0)],
	"c04": [Vector3(24.0, 0.0, 2.0), Vector3(0.0, 2.2, 30.0)],
	"a01": [Vector3(6.0, 0.0, -3.0), Vector3(-16.0, 1.8, -20.0)],
	"v03_gallery": [Vector3(27.2, 0.0, -36.0), Vector3(25.4, 1.4, -54.0)],
	"transit_hub": [Vector3(0.0, 0.0, 86.0), Vector3(16.0, 1.8, 104.0)],
	"transit_car": [Vector3(-6.4, 0.0, 104.2), Vector3(-12.0, 0.7, 109.0)],
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
	# Filtro opcional: `-- b02` captura sólo esas zonas.
	var wanted: Array = []
	for argument in OS.get_cmdline_user_args():
		if VIEWS.has(argument):
			wanted.append(argument)
	if not wanted.is_empty():
		_order = wanted


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
## Las vistas extra (`transit_car`) viven en la zona que indican, no en su nombre.
func _zone_for(id: String) -> String:
	return "transit_hub" if id == "transit_car" else id


func _start_zone() -> void:
	var id: String = _order[_index]
	var zone_id := StringName(_zone_for(id))
	if _manager.current_zone != null and _manager.current_zone.zone_id == zone_id:
		return
	if not _manager.transition_to(zone_id, &"entry"):
		print("CAPTURE %s: transición rechazada" % id)


## Coloca al operador en el punto de vista y lo orienta al objetivo.
func _place() -> void:
	var id: String = _order[_index]
	var view: Array = VIEWS[id]
	var spot: Vector3 = view[0]
	var target: Vector3 = view[1]
	if id == "transit_car":
		# El coche se busca en el árbol: así la toma no depende de la colocación.
		var transit := get_tree().get_first_node_in_group(&"capsule_transit") as Node3D
		var car := transit.get_node_or_null("RailCar") as Node3D if transit != null else null
		if car != null:
			target = car.global_position + Vector3(0.0, 0.7, 0.0)
			spot = car.global_position + Vector3(5.2, 0.0, 0.2)
			print("CAPTURE coche en ", car.global_position, " con ", car.wheel_count(), " ruedas")
			spot = car.global_position + Vector3(5.2, 0.0, 0.2)
			print("CAPTURE coche en ", car.global_position, " con ", car.wheel_count(), " ruedas")
			var shown := 0
			for mesh_node in car.find_children("*", "MeshInstance3D", true, false):
				var mi := mesh_node as MeshInstance3D
				if mi != null and mi.is_visible_in_tree():
					shown += 1
			var sample := car.find_children("*", "MeshInstance3D", true, false).slice(0, 3)
			print("CAPTURE mallas visibles=", shown, " muestra=",
				sample.map(func(m): return [m.name, str(m.global_position.snapped(Vector3(0.01,0.01,0.01))), str(m.get_aabb().size.snapped(Vector3(0.01,0.01,0.01)))]))
	_player.global_position = spot
	_player.velocity = Vector3.ZERO
	var eye := spot + Vector3(0.0, 1.72, 0.0)
	var direction: Vector3 = target - eye
	var flat := Vector2(direction.x, direction.z).length()
	_player.rotation.y = atan2(-direction.x, -direction.z)
	_player.set("_pitch", atan2(direction.y, flat))
	(_player.get_node("Camera3D") as Camera3D).rotation.x = float(_player.get("_pitch"))
