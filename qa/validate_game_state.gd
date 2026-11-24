extends SceneTree

var failures: Array[String] = []
var checks: int = 0
const TEST_SAVE := "user://nexus-native-persistence-qa.json"

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, description: String) -> void:
	checks += 1
	if condition:
		print("QA PASS: ", description)
	else:
		failures.append(description)
		push_error("QA FAIL: %s" % description)

func _run() -> void:
	var state := GameState.new()
	root.add_child(state)
	_check(state.has_item(&"pulse"), "default inventory includes UV pulse tool")
	_check(state.add_item(&"lamp"), "new item can be added")
	_check(not state.add_item(&"lamp"), "duplicate inventory item is rejected")
	_check(state.set_quick_slot(0, &"pulse"), "owned item can be assigned to a quick slot")
	_check(not state.set_quick_slot(1, &"missing"), "unowned item cannot be assigned to a quick slot")
	_check(state.set_quick_slot(1, &"lamp"), "second quick slot can be assigned")
	_check(state.remove_item(&"lamp"), "inventory item can be removed")
	_check(state.quick_slots[1].is_empty(), "removing an item clears its quick slot")

	state.current_zone = &"a01"
	state.previous_zone = &"c04"
	state.door_states = {&"a01/PortalC04": 0.65}
	state.player_state = {"zone": "a01", "position": [2.0, 1.0, -4.0], "yaw": 1.2, "pitch": -0.1}
	state.survey_records = [{
		"id": "sample_01",
		"name": "Muestra 01",
		"zone": "a01",
		"detail": "QA record",
		"position": Vector3(1.5, 2.5, -3.5),
	}]
	_check(state.save_game(TEST_SAVE), "JSON checkpoint writes successfully")

	var restored := GameState.new()
	root.add_child(restored)
	_check(restored.load_game(TEST_SAVE), "checkpoint loads successfully")
	_check(restored.current_zone == &"a01" and restored.previous_zone == &"c04", "zone history survives save and load")
	_check(restored.has_item(&"pulse") and not restored.has_item(&"lamp"), "inventory contents survive save and load")
	_check(restored.quick_slots[0] == &"pulse" and restored.quick_slots[1].is_empty(), "quick slots survive save and load")
	_check(is_equal_approx(float(restored.door_states.get("a01/PortalC04", -1.0)), 0.65), "door aperture survives save and load")
	_check(str(restored.player_state.get("zone", "")) == "a01", "player checkpoint survives save and load")
	_check(restored.survey_records.size() == 1, "survey log survives save and load")
	if restored.survey_records.size() == 1:
		var restored_position: Variant = restored.survey_records[0].get("position")
		_check(restored_position is Vector3 and (restored_position as Vector3).is_equal_approx(Vector3(1.5, 2.5, -3.5)), "survey positions round-trip as Vector3")
	else:
		_check(false, "survey position round-trip can be checked")

	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))
	state.free()
	restored.free()
	var report := {"checks": checks, "failures": failures, "passed": failures.is_empty()}
	print(JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
