class_name BenchStation
extends StaticBody3D
## Cuna de carga o platina del analizador.
##
## Monta el equipo del inventario, avanza el ciclo con la red y lo devuelve al
## inventario cuando termina.

@export var bench_id: StringName = &"charger"
@export var display_name: String = "Cuna de carga"

func _ready() -> void:
	add_to_group(&"interactable")
	set_meta("survey_id", "bench_" + str(bench_id))
	set_meta("survey_name", display_name)
	set_meta("survey_detail", "Banco técnico del laboratorio")
	if not collision_layer:
		collision_layer = 1
	_build_visual()


## Bancada visible: cuerpo, placa de trabajo, cuna y tira de estado.
func _build_visual() -> void:
	var steel := BuildKit.material(BuildKit.STEEL, 0.55, 0.35)
	var graphite := BuildKit.material(BuildKit.GRAPHITE, 0.5, 0.45)
	var bronze := BuildKit.material(BuildKit.BRONZE, 0.7, 0.3)
	BuildKit.block(self, graphite, 0.0, -0.16, 0.0, 1.5, 0.72, 0.86)
	BuildKit.block(self, steel, 0.0, 0.28, 0.0, 1.58, 0.14, 0.92)
	for side in [-1, 1]:
		BuildKit.block(self, bronze, float(side) * 0.62, 0.4, 0.0, 0.1, 0.12, 0.12)
	BuildKit.block(self, BuildKit.emissive(Color("#9be8ff"), 1.0), 0.0, 0.36, 0.0, 1.3, 0.04, 0.6)
	BuildKit.block(self, BuildKit.emissive(BuildKit.GLOW, 1.1), 0.0, -0.02, 0.44, 1.2, 0.06, 0.02)
	for index in 3:
		BuildKit.bead(self, BuildKit.emissive(BuildKit.AMBER, 1.0),
			-0.4 + float(index) * 0.4, 0.18, 0.45, 0.045, 8)
	var label := Label3D.new()
	label.text = display_name
	label.font_size = 26
	label.pixel_size = 0.0032
	label.modulate = Color("#cfe9f2")
	label.position = Vector3(0.0, 0.62, 0.0)
	add_child(label)


func _bench(actor: NexusPlayer) -> BenchCycle:
	var state: GameState = null
	if actor != null and actor.game_state != null:
		state = actor.game_state
	elif is_inside_tree():
		state = get_tree().get_first_node_in_group(&"game_state") as GameState
	return state.bench(bench_id) if state != null else null


func get_interaction_prompt() -> String:
	var player := get_tree().get_first_node_in_group(&"player") as NexusPlayer if is_inside_tree() else null
	var bench := _bench(player)
	if bench == null:
		return ""
	if bench.item.is_empty():
		return "E · Montar equipo en " + display_name
	if bench.done:
		return "E · Retirar equipo · " + bench.stage
	return "%s · %d %%" % [bench.stage.capitalize(), int(bench.progress() * 100.0)]


func interact(actor: NexusPlayer) -> String:
	var bench := _bench(actor)
	if bench == null:
		return "Banco sin alimentación"
	return bench.interact(actor)
