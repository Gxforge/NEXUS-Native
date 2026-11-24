class_name OperationsConsole
extends StaticBody3D
## Mando del cuadro eléctrico o del selector de CCTV.
##
## Cada consola emite un identificador de mando igual que la web
## (`zoneSwitch`, `branchSwitch`, `illum`, `camNext`…).

@export var handle_id: StringName = &"branchSwitch"
@export var display_name: String = "Cuadro eléctrico"
@export var survey_detail: String = "Mando del área técnica"

var _operations: OperationsPanel


func _ready() -> void:
	add_to_group(&"interactable")
	set_meta("survey_id", "ops_" + str(handle_id))
	set_meta("survey_name", display_name)
	set_meta("survey_detail", survey_detail)
	if not collision_layer:
		collision_layer = 1
	var state := get_tree().get_first_node_in_group(&"game_state") as GameState
	if state != null:
		_operations = state.operations


func get_interaction_prompt() -> String:
	return "E · " + display_name


func interact(actor: NexusPlayer) -> String:
	if _operations == null:
		if actor != null and actor.game_state != null:
			_operations = actor.game_state.operations
		if _operations == null:
			return "Mando sin alimentación"
	if not _operations.handle(handle_id):
		return display_name + " · sin respuesta"
	match handle_id:
		&"zoneNext":
			return "Zona seleccionada · " + _operations.selected_zone()
		&"deviceNext":
			return "Derivación · " + str(_operations.selected_circuit().get("name", ""))
		&"zoneSwitch":
			return "Zona " + _operations.selected_zone() + " conmutada"
		&"branchSwitch":
			var circuit := _operations.selected_circuit()
			return "%s · %s" % [str(circuit.get("name", "")),
				"en servicio" if bool(circuit.get("on", true)) else "aislado"]
		&"ecoMaster":
			return "Modo eco conmutado en la derivación seleccionada"
		&"illum":
			return "Iluminación al %d%%" % int(_operations.illumination() * 100.0)
		&"report":
			return _operations.master_report().get("title", "")
		&"camNext", &"camPrev":
			return _operations.strip_label(0)
		_:
			return display_name + " · conmutado"
