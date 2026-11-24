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
