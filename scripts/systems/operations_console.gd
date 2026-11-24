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
var _screen: MeshInstance3D
var _lever: Node3D


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
	_build_visual()


## Mando visible: cuerpo metálico, placa de fósforo, palanca y rótulo.
func _build_visual() -> void:
	var metal := BuildKit.material(BuildKit.METAL, 0.5, 0.4)
	var graphite := BuildKit.material(BuildKit.GRAPHITE, 0.5, 0.45)
	var bronze := BuildKit.material(BuildKit.BRONZE, 0.7, 0.3)
	BuildKit.block(self, graphite, 0.0, 0.0, 0.0, 1.08, 1.24, 0.34)
	BuildKit.block(self, metal, 0.0, 0.62, 0.01, 1.16, 0.08, 0.4)
	BuildKit.block(self, metal, 0.0, -0.62, 0.01, 1.16, 0.08, 0.4)
	# Placa frontal inclinada con la pantalla del mando.
	_screen = BuildKit.block(self, BuildKit.emissive(Color("#7ef2dd"), 0.9),
		0.0, 0.22, 0.19, 0.82, 0.34, 0.02)
	BuildKit.block(self, graphite, 0.0, 0.22, 0.175, 0.92, 0.44, 0.03)
	BuildKit.block(self, BuildKit.emissive(Color("#9ff7e6"), 1.2),
		0.0, 0.22, 0.2, 0.74, 0.26, 0.01)
	# Palanca (los interruptores) y botón de rearme.
	_lever = Node3D.new()
	_lever.name = "Lever"
	_lever.position = Vector3(0.0, -0.2, 0.2)
	add_child(_lever)
	BuildKit.drum(_lever, bronze, 0.0, 0.0, 0.0, 0.09, 0.08, true, 12)
	BuildKit.bar(_lever, metal, Vector3(0.0, 0.0, 0.02), Vector3(0.0, 0.26, 0.16), 0.05)
	BuildKit.bead(_lever, BuildKit.emissive(BuildKit.AMBER, 1.2), 0.0, 0.28, 0.17, 0.06, 8)
	BuildKit.bead(self, BuildKit.emissive(Color("#ff7a5c"), 1.1), 0.34, -0.36, 0.2, 0.055, 8)
	BuildKit.bead(self, BuildKit.emissive(BuildKit.GLOW, 1.1), 0.18, -0.36, 0.2, 0.055, 8)
	# Rótulo del mando.
	var label := Label3D.new()
	label.text = display_name
	label.font_size = 26
	label.pixel_size = 0.0032
	label.modulate = Color("#bfeee6")
	label.position = Vector3(0.0, 0.82, 0.1)
	add_child(label)


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
