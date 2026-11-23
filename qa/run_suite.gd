extends SceneTree

var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error("QA FAIL: %s" % message)
	else:
		print("QA PASS: ", message)

func _wait_idle(manager: ZoneManager, max_frames := 300) -> bool:
	for _frame in max_frames:
		if manager.state == ZoneManager.State.IDLE and manager.current_zone != null:
			return true
		await process_frame
	return false

func _wait_preloaded(manager: ZoneManager, zone_id: StringName, max_frames := 300) -> bool:
	for _frame in max_frames:
		if manager.preload_status(zone_id) == ResourceLoader.THREAD_LOAD_LOADED:
			return true
		await process_frame
	return false

func _mesh_instances(node: Node, output: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		output.append(node as MeshInstance3D)
	for child in node.get_children():
		_mesh_instances(child, output)

func _validate_exported_pattern() -> void:
	var packed_pattern := load("res://scenes/validation/a01_portal_frame_validation.tscn") as PackedScene
	_check(packed_pattern != null, "exported portal validation scene loads")
	if packed_pattern == null:
		return
	var pattern := packed_pattern.instantiate()
	root.add_child(pattern)
	var meshes: Array[MeshInstance3D] = []
	_mesh_instances(pattern, meshes)
	_check(meshes.size() == 1, "portal GLB contains one batched mesh node")
	if meshes.size() == 1:
		var mesh := meshes[0].mesh
		_check(mesh.get_surface_count() == 3, "portal preserves three source material groups")
		var size := meshes[0].get_aabb().size
		_check(size.is_equal_approx(Vector3(4.9, 9.2, 1.1)), "portal AABB preserves source dimensions")
	pattern.queue_free()
	await process_frame

func _validate_structural_zone(path: String, expected_id: StringName, expected_collisions: int, expected_size: Vector3) -> void:
	var packed := load(path) as PackedScene
	_check(packed != null, "%s structural scene loads" % expected_id)
	if packed == null:
		return
	var zone := packed.instantiate() as ZoneRoot
	root.add_child(zone)
	await process_frame
	var shell := zone.get_node("StructuralShell") as StructuralShell
	_check(shell.collision_count == expected_collisions, "%s shell builds %d source-box collisions" % [expected_id, expected_collisions])
	var meshes: Array[MeshInstance3D] = []
	_mesh_instances(shell, meshes)
	_check(meshes.size() == 1, "%s shell is batched into one mesh node" % expected_id)
	if meshes.size() == 1:
		_check(meshes[0].get_aabb().size.is_equal_approx(expected_size), "%s shell AABB matches source dimensions" % expected_id)
	zone.queue_free()
	await process_frame

func _validate_portal_assembly() -> void:
	var packed := load("res://scenes/validation/a01_portal_assembly.tscn") as PackedScene
	_check(packed != null, "A-01 movable portal assembly loads")
	if packed == null:
		return
	var portal := packed.instantiate() as SectorDoor
	root.add_child(portal)
	await process_frame
	_check(portal.left_leaf.get_node_or_null("Collision") is CollisionShape3D, "left leaf has moving collision")
	_check(portal.right_leaf.get_node_or_null("Collision") is CollisionShape3D, "right leaf has moving collision")
	_check(is_equal_approx(portal.left_leaf.position.x, -1.1), "left leaf closed pivot matches source")
	_check(is_equal_approx(portal.right_leaf.position.x, 1.1), "right leaf closed pivot matches source")
	portal.request_open(true)
	for _frame in 180:
		await physics_frame
	_check(absf(portal.left_leaf.position.x + 3.27) < 0.005, "left leaf travels 2.17 m")
	_check(absf(portal.right_leaf.position.x - 3.27) < 0.005, "right leaf travels 2.17 m")
	_check(absf(portal.right_leaf.position.x - 1.095 - 2.175) < 0.005, "open clear half-width is 2.175 m")
	portal.queue_free()
	await process_frame

func _run() -> void:
	await _validate_exported_pattern()
	await _validate_portal_assembly()
	await _validate_structural_zone("res://zones/zone_a01_shell.tscn", &"a01", 7, Vector3(36.475, 9.47, 24.55))
	await _validate_structural_zone("res://zones/zone_c04_shell.tscn", &"c04", 10, Vector3(72.6, 9.47, 84.55))
	var packed := load("res://main.tscn") as PackedScene
	_check(packed != null, "main scene loads")
	if packed == null:
		_finish()
		return
	var main := packed.instantiate()
	root.add_child(main)
	var manager := main.get_node("ZoneManager") as ZoneManager
	var active := main.get_node("ActiveZones")
	var player := main.get_node("PersistentWorld/Player") as NexusPlayer
	_check(await _wait_idle(manager), "initial threaded load completes")
	_check(manager.current_zone.zone_id == &"c04", "C-04 is initial zone")
	_check(active.get_child_count() == 1, "one active zone after boot")
	_check(get_nodes_in_group(&"zone_manager").size() == 1, "one ZoneManager")
	_check(player != null, "one persistent player exists")

	var portal_a01 := manager.current_zone.get_node("PortalA01") as StreamingSectorDoor
	_check(portal_a01 != null, "real A-01 portal is integrated into C-04 slice")
	var proximity := portal_a01.proximity_sensor.get_node("Collision") as CollisionShape3D
	var threshold := portal_a01.transition_threshold.get_node("Collision") as CollisionShape3D
	_check((proximity.shape as BoxShape3D).size == Vector3(6.8, 3.6, 8.0), "proximity sensor preserves original 6.8 x 8 m footprint")
	_check((threshold.shape as BoxShape3D).size == Vector3(4.4, 3.6, 0.5), "crossing threshold matches portal width")
	_check(portal_a01.begin_approach(player), "approach starts asynchronous A-01 preload")
	_check(await _wait_preloaded(manager, &"a01"), "A-01 preload completes before crossing")
	_check(portal_a01.target_aperture == 1.0, "approach requests door opening")

	var old_zone: WeakRef = weakref(manager.current_zone)
	_check(portal_a01.commit_crossing(player), "portal crossing commits C-04 to A-01")
	_check(await _wait_idle(manager), "A-01 threaded transition completes")
	await process_frame
	_check(manager.current_zone.zone_id == &"a01", "A-01 becomes current")
	_check(active.get_child_count() == 1, "C-04 unloaded after transfer")
	_check(old_zone.get_ref() == null, "old zone instance is freed")
	_check(player.get_parent().name == &"PersistentWorld", "player was not duplicated or reparented")

	_check(not manager.transition_to(&"missing_zone"), "unknown zone is rejected")
	_check(manager.state == ZoneManager.State.IDLE, "manager recovers after invalid request")
	var portal_c04 := manager.current_zone.get_node("PortalC04") as StreamingSectorDoor
	_check(portal_c04.begin_approach(player), "A-01 side starts asynchronous C-04 preload")
	_check(await _wait_preloaded(manager, &"c04"), "C-04 preload completes before return crossing")
	var return_committed := portal_c04.commit_crossing(player)
	_check(return_committed or manager.state != ZoneManager.State.IDLE, "A-01 portal commits return to C-04 once")
	_check(await _wait_idle(manager), "return transition completes")
	await process_frame
	_check(manager.current_zone.zone_id == &"c04", "returned to C-04")
	_check(active.get_child_count() == 1, "one active zone after round trip")
	_finish()

func _finish() -> void:
	var version: String = str(Engine.get_version_info().get("string", "unknown"))
	var report: Dictionary = {
		"checks": checks,
		"failures": failures,
		"passed": failures.is_empty(),
		"godot": version,
	}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://reports"))
	var file := FileAccess.open("res://reports/qa-phase1.json", FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report, "  "))
		file.close()
	print(JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
