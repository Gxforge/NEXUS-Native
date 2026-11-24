extends SceneTree

## End-to-end traversal of the whole twelve-zone graph: every connection is
## crossed in both directions through its real streaming portal, checking the
## arrival socket, single-zone residency and scene release.

const QA_SAVE_PATH := "user://qa_zone_traversal_save.json"
const LOCAL_OFFSET := Vector3(9.0, 0.0, 14.0)
const ROUTE: Array[Array] = [
	["c04", "b02"], ["b02", "v03_gallery"], ["v03_gallery", "h01"], ["h01", "v03_gallery"],
	["v03_gallery", "d02"], ["d02", "v03_gallery"], ["v03_gallery", "v03_cryo"],
	["v03_cryo", "v03_gallery"], ["v03_gallery", "b02"], ["b02", "c04"],
	["c04", "surveillance"], ["surveillance", "c04"], ["c04", "electrical"],
	["electrical", "c04"], ["c04", "transit_hub"], ["transit_hub", "transit_road"],
	["transit_road", "transit_hub"], ["transit_hub", "transit_rail"],
	["transit_rail", "transit_hub"], ["transit_hub", "c04"], ["c04", "a01"], ["a01", "c04"],
]

var checks: Dictionary = {}
var failures: Array[String] = []

var _finished := false

func _initialize() -> void:
	call_deferred("_run")
	call_deferred("_watchdog")

func _watchdog() -> void:
	for _step in 120:
		await create_timer(1.0).timeout
		if _finished:
			return
	printerr("QA ZONE TRAVERSAL: watchdog timeout")
	quit(124)

func _run() -> void:
	var packed := load("res://main.tscn") as PackedScene
	_check(packed != null, "main scene loads")
	if packed == null:
		_finish()
		return
	var main := packed.instantiate()
	var state := main.get_node("GameState") as GameState
	state.persistence_path = QA_SAVE_PATH
	DirAccess.remove_absolute(ProjectSettings.globalize_path(QA_SAVE_PATH))
	root.add_child(main)
	var manager := main.get_node("ZoneManager") as ZoneManager
	var player := main.get_node("PersistentWorld/Player") as NexusPlayer
	var active := main.get_node("ActiveZones")
	_check(main.start_game(), "startup requests the first module")
	_check(await _wait_idle(manager), "startup transition completes")
	_check(manager.current_zone != null and manager.current_zone.zone_id == &"c04", "boot lands in C-04")
	_check(main.get_node("GameState") is GameState and manager.catalog.has_zone(&"transit_rail"),
		"catalog registers distant modules")

	var visited: Dictionary = {}
	var step_index := 0
	for step: Array in ROUTE:
		step_index += 1
		print("QA STEP %d: %s -> %s" % [step_index, step[0], step[1]])
		var from_zone := StringName(str(step[0]))
		var to_zone := StringName(str(step[1]))
		_check(manager.current_zone.zone_id == from_zone,
			"route is on %s before crossing to %s" % [from_zone, to_zone])
		if manager.current_zone.zone_id != from_zone:
			break
		var door := _portal_toward(manager.current_zone, to_zone)
		_check(door != null, "%s exposes a live portal toward %s" % [from_zone, to_zone])
		if door == null:
			break
		_check(door.begin_approach(player), "%s->%s approach requests the target preload" % [from_zone, to_zone])
		_check(await _wait_preloaded(manager, to_zone), "%s->%s target preload completes" % [from_zone, to_zone])
		var previous: WeakRef = weakref(manager.current_zone)
		var previous_path := manager.catalog.zone(from_zone).scene_path
		var arrival_socket := str(door.target_socket)
		_check(door.commit_crossing(player), "%s->%s crossing is committed" % [from_zone, to_zone])
		_check(await _wait_idle(manager), "%s->%s threaded transition completes" % [from_zone, to_zone])
		await process_frame
		_check(manager.current_zone.zone_id == to_zone, "%s becomes the active module" % to_zone)
		_check(active.get_child_count() == 1, "%s->%s leaves exactly one active zone" % [from_zone, to_zone])
		_check(previous.get_ref() == null, "%s instance is released after leaving" % from_zone)
		_check(not ResourceLoader.has_cached(previous_path), "%s PackedScene is not retained in cache" % from_zone)
		var socket := manager.current_zone.get_node_or_null(
			NodePath("DoorSockets/%s" % arrival_socket)) as Node3D
		_check(socket != null, "%s exposes the %s arrival socket" % [to_zone, arrival_socket])
		if socket != null:
			var distance: float = Vector2(player.global_position.x - socket.global_position.x,
				player.global_position.z - socket.global_position.z).length()
			_check(distance < 0.85, "player lands on the %s socket of %s" % [arrival_socket, to_zone])
		var current_definition := manager.catalog.zone(to_zone)
		_check(current_definition.contains_position(player.global_position),
			"player position is inside the %s footprint" % to_zone)
		visited[to_zone] = true

	_check(visited.size() >= 11, "traversal reaches at least eleven modules (%d)" % visited.size())
	await _validate_physical_crossing(manager, player)
	main.queue_free()
	await process_frame
	_finish()

func _validate_physical_crossing(manager: ZoneManager, player: NexusPlayer) -> void:
	## Walks the persistent player through a real portal instead of committing
	## the transition directly: proximity sensor, leaf opening and threshold.
	var door := _portal_toward(manager.current_zone, &"a01")
	if door == null:
		_check(false, "C-04 still exposes its A-01 portal for the physical crossing")
		return
	var zone := manager.current_zone
	player.global_position = door.global_position + door.global_transform.basis.z * 7.0 + Vector3(0.0, 1.2, 0.0)
	player.rotation.y = door.rotation.y
	player.camera.rotation.x = 0.0
	player.set_controls_enabled(true)
	await physics_frame
	Input.action_press(&"move_forward")
	Input.action_press(&"sprint")
	var crossed := false
	for _frame in 420:
		await physics_frame
		if manager.current_zone != null and manager.current_zone.zone_id == &"a01":
			crossed = true
			break
	Input.action_release(&"move_forward")
	Input.action_release(&"sprint")
	_check(crossed, "walking into an open portal crosses it without scripted teleport")
	if crossed:
		_check(await _wait_idle(manager), "physical crossing settles the manager")
		await process_frame
		_check(manager.current_zone.zone_id == &"a01", "physical crossing lands inside A-01")

func _portal_toward(zone: ZoneRoot, target: StringName) -> StreamingSectorDoor:
	for child: Node in zone.get_children():
		if child is StreamingSectorDoor and (child as StreamingSectorDoor).target_zone == target:
			return child as StreamingSectorDoor
	return null

func _wait_preloaded(manager: ZoneManager, zone_id: StringName) -> bool:
	for _frame in 600:
		if manager.preload_status(zone_id) == ResourceLoader.THREAD_LOAD_LOADED:
			return true
		await process_frame
	return false

func _wait_idle(manager: ZoneManager) -> bool:
	for _frame in 600:
		if manager.state == ZoneManager.State.IDLE and manager.current_zone != null:
			return true
		await process_frame
	return false

func _check(condition: bool, message: String) -> void:
	checks[message] = condition
	if not condition:
		failures.append(message)
		printerr("QA FAIL: %s" % message)

func _finish() -> void:
	_finished = true
	var total := checks.size()
	var passed := total - failures.size()
	print(JSON.stringify({
		"suite": "zone_traversal",
		"total": total,
		"passed": passed,
		"failed": failures.size(),
		"failures": failures,
		"checks": checks,
	}, "  "))
	print("QA ZONE TRAVERSAL: %d/%d" % [passed, total])
	quit(0 if failures.is_empty() else 1)
