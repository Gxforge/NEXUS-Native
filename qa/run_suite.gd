extends SceneTree

var failures: Array[String] = []
var checks := 0
const QA_SAVE_PATH := "user://nexus_native_run_suite.json"

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

func _validate_structural_zone(zone: Dictionary) -> void:
	var expected_id := StringName(str(zone.get("id", "")))
	var packed := load(str(zone.get("scene", ""))) as PackedScene
	_check(packed != null, "%s structural scene loads" % expected_id)
	if packed == null:
		return
	var instance := packed.instantiate() as ZoneRoot
	root.add_child(instance)
	await process_frame
	var shell := instance.get_node("StructuralShell") as StructuralShell
	var manifest: Dictionary = _read_manifest(shell.manifest_path)
	_check(not manifest.is_empty(), "%s structural manifest is readable" % expected_id)
	var expected_collisions := int(manifest.get("expected_collisions", -1))
	_check(shell.collision_count == expected_collisions, "%s shell builds %d source-box collisions" % [expected_id, expected_collisions])
	var meshes: Array[MeshInstance3D] = []
	_mesh_instances(shell, meshes)
	_check(not meshes.is_empty(), "%s shell contains renderable geometry" % expected_id)
	if not meshes.is_empty():
		var merged := AABB()
		for index in meshes.size():
			merged = meshes[index].get_aabb() if index == 0 else merged.merge(meshes[index].get_aabb())
		var expected_min: Array = manifest.get("expected_bounds", {}).get("min", [])
		var expected_max: Array = manifest.get("expected_bounds", {}).get("max", [])
		if expected_min.size() >= 3 and expected_max.size() >= 3:
			var low := Vector3(float(expected_min[0]), float(expected_min[1]), float(expected_min[2]))
			var high := Vector3(float(expected_max[0]), float(expected_max[1]), float(expected_max[2]))
			_check((merged.position - low).length() < 0.5, "%s shell AABB origin matches manifest" % expected_id)
			_check((merged.end - high).length() < 0.5, "%s shell AABB extent matches manifest" % expected_id)
	instance.queue_free()
	await process_frame

func _find_node_named(node: Node, node_name: String) -> Node:
	if node.name == node_name:
		return node
	for child in node.get_children():
		var found := _find_node_named(child, node_name)
		if found != null:
			return found
	return null

func _read_manifest(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	return parsed as Dictionary if parsed is Dictionary else {}

func _validate_all_structural_zones() -> void:
	var graph_file := FileAccess.open("res://data/zone_graph.json", FileAccess.READ)
	_check(graph_file != null, "zone graph is readable")
	if graph_file == null:
		return
	var parsed: Variant = JSON.parse_string(graph_file.get_as_text())
	graph_file.close()
	var graph := parsed as Dictionary if parsed is Dictionary else {}
	var zones: Array = graph.get("zones", [])
	_check(zones.size() == 12, "zone graph declares twelve modules")
	_check((graph.get("connections", []) as Array).size() == 11, "zone graph declares eleven transit connections")
	for zone: Dictionary in zones:
		await _validate_structural_zone(zone)

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
	await _validate_all_structural_zones()
	var packed := load("res://main.tscn") as PackedScene
	_check(packed != null, "main scene loads")
	if packed == null:
		_finish()
		return
	var main := packed.instantiate()
	var test_state := main.get_node("GameState") as GameState
	test_state.persistence_path = QA_SAVE_PATH
	DirAccess.remove_absolute(ProjectSettings.globalize_path(QA_SAVE_PATH))
	root.add_child(main)
	var manager := main.get_node("ZoneManager") as ZoneManager
	_check(main.get_node("UI/MainMenu").visible, "main menu is visible before loading")
	_check(main.start_game(), "main menu starts real C-04 preload")
	_check(main.get_node("UI/LoadingScreen").visible, "loading screen is visible during preload")
	var active := main.get_node("ActiveZones")
	var player := main.get_node("PersistentWorld/Player") as NexusPlayer
	_check(await _wait_idle(manager), "initial threaded load completes")
	_check(manager.current_zone.zone_id == &"c04", "C-04 is initial zone")
	_check(active.get_child_count() == 1, "one active zone after boot")
	_check(get_nodes_in_group(&"zone_manager").size() == 1, "one ZoneManager")
	_check(player != null, "one persistent player exists")
	var experience := main.get_node("PersistentWorld/SceneExperience") as SceneExperienceController
	_check(experience != null, "one persistent SceneExperience controller exists")
	_check(experience.survey.get_parent() == experience, "survey system is owned by persistent controller")
	_check(experience.contact_fx.get_parent() == experience, "contact effects are owned by persistent controller")
	_check(player.camera != null, "persistent player has mouse-look camera")
	var hud := main.get_node("UI/HUD") as NexusHUD
	_check(hud != null and hud.visible, "in-game HUD becomes visible after startup")
	player.panel_requested.emit(&"inventory")
	_check(hud.get_node("FieldPanel").visible and not player.controls_enabled, "inventory panel pauses player controls")
	hud._close_panel()
	_check(player.controls_enabled, "closing the inventory panel restores player controls")
	hud._on_panel_requested(&"map")
	_check(hud.get_node("FieldPanel").visible, "map panel opens from the HUD")
	var map_view := _find_node_named(hud.get_node("FieldPanel"), "ZoneMap") as ZoneMapView
	_check(map_view != null, "map panel embeds the schematic zone map")
	if map_view != null:
		_check(map_view._entries.size() == 12, "schematic map draws the twelve modules")
		_check(map_view._current == manager.current_zone.zone_id, "schematic map highlights the current module")
	hud._close_panel()
	_check(manager.catalog.has_zone(&"v03_cryo") and manager.catalog.connections_of(&"c04").size() == 5,
		"catalog exposes the twelve-module graph and C-04 five-way junction")
	player.panel_requested.emit(&"pause")
	_check(paused, "pause panel suspends the simulation")
	hud._close_panel()
	_check(not paused and player.controls_enabled, "resuming restores simulation and controls")
	_check(player.game_state == main.get_node("GameState"), "player is connected to persistent game state")
	_check(InputMap.has_action("interact") and InputMap.has_action("quick_slot_5"), "native interaction and five quick-slot actions are mapped")
	var watcher := manager.current_zone.get_node("W01") as W01Actor
	_check(watcher != null, "W-01 actor is integrated into C-04")
	_check(watcher.get_node("Eyes/W01_Seven_Eyes").get_child_count() == 7, "W-01 actor contains seven eyes")
	_check(watcher.get_node("Tentacles/W01_20_Tentacles").get_child_count() == 20, "W-01 actor contains twenty tentacles")
	var original_player_position := player.global_position
	var original_player_yaw := player.rotation.y
	player.global_position = watcher.global_position + Vector3(0.0, 0.0, 8.0)
	player.rotation.y = 0.0
	player.camera.rotation.x = 0.0
	var energy_before_uv := player.energy
	player.fire_tool(false)
	_check(is_equal_approx(player.energy, energy_before_uv - NexusPlayer.UV_COST), "UV protocol spends its native energy cost")
	_check(watcher.state == "RECOVERY", "UV hit forces W-01 into recovery")
	player.fire_tool(true)
	_check(watcher._cold_remaining > 0.0, "cryo hit applies the seven-second slow effect")
	player.global_position = original_player_position
	player.rotation.y = original_player_yaw

	var portal_a01 := manager.current_zone.get_node("PortalA01") as StreamingSectorDoor
	_check(portal_a01 != null, "real A-01 portal is integrated into C-04 slice")
	_check(portal_a01.target_socket == &"from_c04", "A-01 arrival socket is explicitly wired")
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
	var pickup := manager.current_zone.get_node_or_null("FieldFlashlight") as FieldPickup
	_check(pickup != null, "A-01 contains the interactive field flashlight pickup")
	if pickup != null:
		player.global_position = Vector3(0.0, 0.0, -4.5)
		player.rotation.y = 0.0
		player.camera.rotation.x = -0.6
		player._refresh_prompt()
		_check(player._last_prompt.begins_with("E · Recoger"), "ray interaction shows the field pickup prompt")
		player.interact()
		var state := main.get_node("GameState") as GameState
		_check(state.has_item(&"lamp"), "field pickup enters the persistent inventory")
		_check(state.set_quick_slot(2, &"lamp"), "field item can be assigned to a quick slot")
		player.select_quick_slot(2)
		player.use_selected_slot()
		_check(player.flashlight_enabled, "selected flashlight slot turns on the field light")
		player.use_selected_slot()
		_check(not player.flashlight_enabled, "selected flashlight slot can turn the field light off")
		player.camera.rotation.x = 0.0
	_check(active.get_child_count() == 1, "C-04 unloaded after transfer")
	_check(old_zone.get_ref() == null, "old zone instance is freed")
	_check(manager.last_released_zone != null and manager.last_released_zone.get_ref() == null, "manager releases its zone reference")
	_check(not ResourceLoader.has_cached(manager.catalog.zone(&"c04").scene_path), "unloaded zone PackedScene is not retained in resource cache")
	_check(player.get_parent().name == &"PersistentWorld", "player was not duplicated or reparented")

	_check(not manager.transition_to(&"missing_zone"), "unknown zone is rejected")
	_check(manager.state == ZoneManager.State.IDLE, "manager recovers after invalid request")
	var portal_c04 := manager.current_zone.get_node("PortalC04") as StreamingSectorDoor
	_check(portal_c04.target_socket == &"to_a01", "C-04 return socket is explicitly wired")
	_check(portal_c04.begin_approach(player), "A-01 side starts asynchronous C-04 preload")
	_check(await _wait_preloaded(manager, &"c04"), "C-04 preload completes before return crossing")
	var return_committed := portal_c04.commit_crossing(player)
	_check(return_committed or manager.state != ZoneManager.State.IDLE, "A-01 portal commits return to C-04 once")
	_check(await _wait_idle(manager), "return transition completes")
	await process_frame
	_check(manager.current_zone.zone_id == &"c04", "returned to C-04")
	_check(active.get_child_count() == 1, "one active zone after round trip")
	main.queue_free()
	await process_frame
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
	DirAccess.remove_absolute(ProjectSettings.globalize_path(QA_SAVE_PATH))
	print(JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
