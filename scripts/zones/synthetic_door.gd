class_name SyntheticDoor
extends Area3D

@export var target_zone: StringName
@export var target_socket: StringName
var _busy := false

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	if _busy or not body is NexusPlayer:
		return
	var manager := get_tree().get_first_node_in_group(&"zone_manager") as ZoneManager
	if manager == null:
		return
	_busy = manager.transition_to(target_zone, target_socket)
