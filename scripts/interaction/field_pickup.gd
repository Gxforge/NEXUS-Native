class_name FieldPickup
extends StaticBody3D

@export var item_id: StringName = &"lamp"
@export var display_name: String = "Linterna de campo"

func _ready() -> void:
	add_to_group(&"interactable")
	set_meta("survey_id", "pickup_" + str(item_id))
	set_meta("survey_name", display_name)
	set_meta("survey_zone", "a01")
	set_meta("survey_detail", "Equipo de campo recuperable")
	var state := get_tree().get_first_node_in_group(&"game_state") as GameState
	if state != null and state.has_item(item_id):
		queue_free()

func get_interaction_prompt() -> String:
	return "E · Recoger " + display_name

func interact(actor: NexusPlayer) -> String:
	if actor == null or actor.game_state == null:
		return "Inventario no disponible"
	if not actor.game_state.add_item(item_id):
		return display_name + " · ya está en el inventario"
	actor.game_state.save_game()
	queue_free()
	return display_name + " · guardada en el inventario"
