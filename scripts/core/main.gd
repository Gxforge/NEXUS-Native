extends Node

@onready var catalog: ZoneCatalog = $ZoneCatalog
@onready var game_state: GameState = $GameState
@onready var zone_manager: ZoneManager = $ZoneManager

func _ready() -> void:
	_register_zones()
	zone_manager.configure(catalog, game_state)
	zone_manager.transition_to(&"c04", &"entry")

func _register_zones() -> void:
	var c04 := ZoneDefinition.new()
	c04.id = &"c04"
	c04.scene_path = "res://zones/zone_c04_shell.tscn"
	c04.display_name = "C-04 · Contención"
	c04.neighbors = [&"a01"]
	catalog.register_zone(c04)
	var a01 := ZoneDefinition.new()
	a01.id = &"a01"
	a01.scene_path = "res://zones/zone_a01_shell.tscn"
	a01.display_name = "A-01 · Archivo"
	a01.neighbors = [&"c04"]
	catalog.register_zone(a01)
	var connection := DoorConnection.new()
	connection.id = &"c04_a01"
	connection.from_zone = &"c04"
	connection.from_socket = &"to_a01"
	connection.to_zone = &"a01"
	connection.to_socket = &"from_c04"
	catalog.register_connection(connection)
