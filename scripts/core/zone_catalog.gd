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

func zone_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for id: StringName in _zones:
		ids.append(id)
	ids.sort()
	return ids

func connection_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for id: StringName in _connections:
		ids.append(id)
	ids.sort()
	return ids

func connections_of(zone_id: StringName) -> Array[DoorConnection]:
	var result: Array[DoorConnection] = []
	for id in connection_ids():
		var connection := _connections[id] as DoorConnection
		if connection.from_zone == zone_id or connection.to_zone == zone_id:
			result.append(connection)
	return result
