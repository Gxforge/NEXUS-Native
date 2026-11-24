class_name ZoneRoot
extends Node3D

signal zone_ready(zone: ZoneRoot)
signal zone_deactivated(zone_id: StringName)

@export var zone_id: StringName
var is_active := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_DISABLED
	set_meta("zone_id", zone_id)
	set_meta("survey_id", "zone_%s" % str(zone_id))
	set_meta("survey_name", "Zona %s" % str(zone_id).to_upper())
	set_meta("survey_detail", "Módulo NEXUS registrado en el mapa de campo")
	call_deferred("_announce_ready")

func _announce_ready() -> void:
	zone_ready.emit(self)

func activate() -> void:
	is_active = true
	visible = true
	process_mode = Node.PROCESS_MODE_INHERIT
	_set_portals_enabled(true)

func deactivate() -> void:
	is_active = false
	_set_portals_enabled(false)
	process_mode = Node.PROCESS_MODE_DISABLED
	_stop_local_audio(self)
	zone_deactivated.emit(zone_id)

func socket_transform(socket_name: StringName) -> Transform3D:
	var socket := get_node_or_null(NodePath("DoorSockets/%s" % socket_name)) as Node3D
	if socket == null:
		push_error("Zone %s has no socket %s" % [zone_id, socket_name])
		return global_transform
	return socket.global_transform

func _set_portals_enabled(enabled: bool) -> void:
	for node in find_children("*", "", true, false):
		if node.has_method("set_streaming_enabled"):
			node.call("set_streaming_enabled", enabled)

func _stop_local_audio(node: Node) -> void:
	if node is AudioStreamPlayer3D:
		(node as AudioStreamPlayer3D).stop()
	for child in node.get_children():
		_stop_local_audio(child)
