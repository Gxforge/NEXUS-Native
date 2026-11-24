extends SceneTree

const TEST_SAVE := "user://nexus-native-resume-qa.json"
var checks: int = 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	checks += 1
	if condition:
		print("QA PASS: ", message)
	else:
		failures.append(message)
		push_error("QA FAIL: %s" % message)

func _run() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))
	var packed := load("res://main.tscn") as PackedScene
	_check(packed != null, "main scene is available for resume test")
	if packed == null:
		_finish()
		return
	var main := packed.instantiate()
	var state := main.get_node("GameState") as GameState
	state.persistence_path = TEST_SAVE
	state.current_zone = &"a01"
	state.player_state = {
		"zone": "a01",
		"position": [0.0, 0.0001, -1.2],
		"yaw": 0.0,
		"pitch": 0.0,
		"stamina": 73.0,
		"energy": 58.0,
	}
	_check(state.save_game(), "A–01 resume checkpoint is prepared")
	root.add_child(main)
	_check(main.start_game(), "startup accepts saved zone")
	var manager := main.get_node("ZoneManager") as ZoneManager
	var finished := false
	for _frame in 480:
		if manager.state == ZoneManager.State.IDLE and manager.current_zone != null:
			finished = true
			break
		await process_frame
	_check(finished, "saved zone finishes threaded startup")
	if finished:
		await process_frame
		var player := main.get_node("PersistentWorld/Player") as NexusPlayer
		_check(manager.current_zone.zone_id == &"a01", "saved A–01 zone is restored")
		_check(manager.current_zone.get_node_or_null("PortalC04") != null, "restored A–01 retains its return portal")
		_check(absf(player.global_position.x) < 0.01 and absf(player.global_position.z + 1.2) < 0.01 and player.global_position.y < 0.1, "saved player transform is applied after zone staging")
		for _frame in 12:
			await physics_frame
		_check(manager.current_zone.zone_id == &"a01", "spawn near a portal does not auto-transition without crossing velocity")
	main.queue_free()
	await process_frame
	_finish()

func _finish() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))
	var report := {"checks": checks, "failures": failures, "passed": failures.is_empty()}
	print(JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
