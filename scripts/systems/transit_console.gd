class_name TransitConsole
extends StaticBody3D
## Mando de andén, asiento o transferencia del eje.
##
## Igual que la web, cada puesto tiene su identificador: `railCallA`/`railCallB`
## (llamada), `railBrake` (freno de retención), `railLoad` (subir/bajar el carro),
## `railCar` (tomar el mando del vehículo) y `railSeat0…4`.

@export var handle_id: StringName = &"railCallA"
@export var display_name: String = "Llamada de cápsula"
@export var survey_detail: String = "Puesto del andén"

var _transit: CapsuleTransit


func _ready() -> void:
	add_to_group(&"interactable")
	set_meta("survey_id", "rail_" + str(handle_id))
	set_meta("survey_name", display_name)
	set_meta("survey_detail", survey_detail)
	if not collision_layer:
		collision_layer = 1
	var state := get_tree().get_first_node_in_group(&"game_state") as GameState
	if state != null:
		_transit = state.transit
	if _transit == null:
		_transit = get_tree().get_first_node_in_group(&"capsule_transit") as CapsuleTransit


func get_interaction_prompt() -> String:
	return "E · " + display_name


func interact(actor: NexusPlayer) -> String:
	if _transit == null and actor != null and actor.game_state != null:
		_transit = actor.game_state.transit
	if _transit == null:
		_transit = get_tree().get_first_node_in_group(&"capsule_transit") as CapsuleTransit
	if _transit == null:
		return "Cápsula sin enlace"
	var position := actor.global_position if actor != null else Vector3.ZERO
	var result := _transit.use(handle_id, position)
	var next: Variant = result.get("position", position)
	if actor != null and next is Vector3 and (next as Vector3) != position:
		actor.global_position = next
		if _transit.driving and actor.camera != null:
			actor.camera.rotation.y = _transit.physics.yaw
	var message := str(result.get("message", ""))
	return message if not message.is_empty() else display_name


func transit_status() -> String:
	if _transit == null:
		return ""
	return _transit.status_line()
