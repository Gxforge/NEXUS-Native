class_name ZoneCatalog
extends Node

var _zones: Dictionary = {}
var _connections: Dictionary = {}

func register_zone(definition: ZoneDefinition) -> void:
	assert(definition != null and not definition.id.is_empty())
	assert(not definition.scene_path.is_empty())
	_zones[definition.id] = definition

func register_connection(connection: DoorConnection) -> void:
	assert(connection != null and not connection.id.is_empty())
	_connections[connection.id] = connection

func zone(id: StringName) -> ZoneDefinition:
	return _zones.get(id) as ZoneDefinition

func connection(id: StringName) -> DoorConnection:
	return _connections.get(id) as DoorConnection

func has_zone(id: StringName) -> bool:
	return _zones.has(id)
