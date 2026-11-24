class_name VaultStation
extends StaticBody3D
## Puesto de uso de la bóveda (consola, rearme, hidráulica, archivo).
##
## Implementa el mismo contrato que `FieldPickup`: el jugador apunta, ve el
## prompt y pulsa interactuar; la lógica vive en `VaultModule`.

@export var station_id: StringName = &"vault"
@export var display_name: String = "Consola de la bóveda V–03"
@export var vault_path: NodePath

var _vault: VaultModule


func _ready() -> void:
	add_to_group(&"interactable")
	set_meta("survey_id", "vault_" + str(station_id))
	set_meta("survey_name", display_name)
	set_meta("survey_detail", "Puesto de uso de la bóveda V–03")
	if not vault_path.is_empty():
		_vault = get_node_or_null(vault_path) as VaultModule
	if _vault == null:
		_vault = get_tree().get_first_node_in_group(&"vault_module") as VaultModule
	if not collision_layer:
		collision_layer = 1
	_build_visual()


## Puesto visible: pedestal de acero, tablero inclinado, pantalla y testigos.
func _build_visual() -> void:
	var steel := BuildKit.material(BuildKit.STEEL, 0.55, 0.35)
	var graphite := BuildKit.material(BuildKit.GRAPHITE, 0.5, 0.45)
	var bronze := BuildKit.material(BuildKit.BRONZE, 0.7, 0.3)
	BuildKit.block(self, graphite, 0.0, -0.3, 0.0, 0.96, 0.6, 0.52)
	BuildKit.block(self, steel, 0.0, 0.06, 0.02, 1.02, 0.16, 0.58)
	# Tablero inclinado con la pantalla del puesto.
	var panel := Node3D.new()
	panel.name = "Panel"
	panel.position = Vector3(0.0, 0.34, 0.02)
	panel.rotation.x = -0.42
	add_child(panel)
	BuildKit.block(panel, graphite, 0.0, 0.0, 0.0, 0.94, 0.44, 0.1)
	BuildKit.block(panel, BuildKit.emissive(Color("#a9f0fb"), 2.4),
		0.0, 0.02, 0.07, 0.8, 0.32, 0.02)
	BuildKit.block(panel, BuildKit.emissive(Color("#e8fdff"), 2.8),
		0.0, 0.09, 0.08, 0.66, 0.05, 0.01)
	BuildKit.block(panel, BuildKit.emissive(Color("#e8fdff"), 2.2),
		0.0, -0.04, 0.08, 0.5, 0.04, 0.01)
	for index in 3:
		BuildKit.bead(self, BuildKit.emissive(BuildKit.GLOW if index == 0 else BuildKit.AMBER, 1.0),
			-0.3 + float(index) * 0.3, 0.18, 0.31, 0.05, 8)
	BuildKit.block(self, bronze, 0.0, -0.06, 0.3, 0.34, 0.06, 0.06)
	var label := Label3D.new()
	label.text = display_name
	label.font_size = 26
	label.pixel_size = 0.0032
	label.modulate = Color("#bfe6f2")
	label.position = Vector3(0.0, 0.74, 0.0)
	add_child(label)


func get_interaction_prompt() -> String:
	if _vault == null:
		return ""
	match station_id:
		&"vault":
			if _vault.opened_once:
				return "Bóveda V–03 · abierta"
			if _vault.is_opening():
				return "Bóveda V–03 · " + _vault.phase
			return "E · Abrir " + display_name
		_:
			return "E · " + display_name


func interact(actor: NexusPlayer) -> String:
	if _vault == null:
		return "Bóveda no disponible"
	return _vault.use_station(station_id, actor)
