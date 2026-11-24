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
