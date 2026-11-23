class_name ZoneDefinition
extends Resource

@export var id: StringName
@export_file("*.tscn") var scene_path: String
@export var display_name: String
@export var spawn_socket: StringName = &"entry"
@export var neighbors: Array[StringName] = []
