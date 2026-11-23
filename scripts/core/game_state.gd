class_name GameState
extends Node

var current_zone: StringName = &""
var previous_zone: StringName = &""
var inventory: Array[StringName] = [&"pulse", &"cryo"]
var door_states: Dictionary = {}
var survey_records: Array[Dictionary] = []
var watcher_state: Dictionary = {
	"zone": &"c04", "state": &"WATCHING", "aggression": 0.2, "memory": 0.0,
}

func store_survey_records(records: Array[Dictionary]) -> void:
	survey_records.assign(records.duplicate(true))

func commit_zone(next_zone: StringName) -> void:
	previous_zone = current_zone
	current_zone = next_zone
