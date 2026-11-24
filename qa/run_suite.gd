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

func _find_button_named(node: Node, text: String) -> Button:
	if node == null:
		return null
	if node is Button and (node as Button).text == text:
		return node as Button
	for child in node.get_children():
		var found := _find_button_named(child, text)
		if found != null:
			return found
	return null

func _find_slider(node: Node) -> HSlider:
	if node == null:
		return null
	if node is HSlider:
		return node as HSlider
	for child in node.get_children():
		var found := _find_slider(child)
		if found != null:
			return found
	return null

func _find_checkbox(node: Node) -> CheckBox:
	if node == null:
		return null
	if node is CheckBox:
		return node as CheckBox
	for child in node.get_children():
		var found := _find_checkbox(child)
		if found != null:
			return found
	return null

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

## Fase 24: cada zona lleva su mobiliario (`ZoneDressing`) dentro del volumen.
func _validate_zone_dressing() -> void:
	var zones := ["h01", "b02", "electrical", "surveillance", "d02", "c04",
		"v03_gallery", "v03_cryo"]
	for id: String in zones:
		var layer := root.get_node_or_null("PersistentWorld")
		var zone_path := "res://zones/zone_%s" % id
		var packed: PackedScene = null
		for candidate in [zone_path + ".tscn", zone_path + "_shell.tscn",
				zone_path + "_hydraulics.tscn", zone_path + "_turbines.tscn",
				zone_path + "_records.tscn", "res://zones/zone_v03_cryotheque.tscn",
				"res://zones/zone_v03_gallery.tscn"]:
			if ResourceLoader.exists(candidate):
				packed = load(candidate)
				break
		_check(packed != null, "%s: zona con mobiliario cargable" % id)
		if packed == null:
			continue
		var instance := packed.instantiate() as Node3D
		root.add_child(instance)
		await process_frame
		var dressing := instance.get_node_or_null("Dressing") as ZoneDressing
		_check(dressing != null, "%s: nodo Dressing presente" % id)
		if dressing != null:
			_check(dressing.built_meshes >= 20, "%s: %d mallas de mobiliario" % [id, dressing.built_meshes])
			var room: Array = dressing.room()
			var outside := 0
			var stack: Array[Node] = [dressing]
			while not stack.is_empty():
				var node: Node = stack.pop_back()
				for child in node.get_children():
					stack.append(child)
				var mesh := node as MeshInstance3D
				if mesh == null or mesh.mesh == null:
					continue
				var center: Vector3 = (mesh.global_transform * mesh.get_aabb()).get_center()
				if center.x < float(room[0]) - 0.6 or center.x > float(room[1]) + 0.6 \
						or center.z < float(room[2]) - 0.6 or center.z > float(room[3]) + 0.6:
					outside += 1
			_check(outside == 0, "%s: mobiliario dentro de las paredes" % id)
		instance.queue_free()
		await process_frame
		if layer == null:
			continue


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

func _validate_power_grid() -> void:
	var grid: PowerGrid = PowerGrid.for_laboratory()
	grid.reset()
	grid.machines = 6.0
	grid.update(0.0, false, 0.0)
	_check(grid.feeds.size() == 12, "power grid declares twelve feeds")
	_check(is_equal_approx(grid.capacity, 112.0), "power grid capacity matches web (112 kW)")
	_check(is_equal_approx(grid.load_kw, 70.0), "power grid steady load matches web (70 kW)")
	_check(is_equal_approx(grid.outputs[0], 17.5), "power grid splits load per feed")
	grid.spike("qa surge", 60.0, 6.0)
	var tripped := false
	for _step in 20:
		if grid.update(0.5, false, 0.0):
			tripped = true
			break
	_check(tripped, "power grid trips on sustained overload")
	grid.update(0.0, false, 0.0)
	_check(is_equal_approx(grid.load_kw, 17.0) and is_zero_approx(grid.delivered),
		"tripped grid keeps only residual load")
	for _index in 4:
		grid.set_fan(_index, true)
	for _step in 400:
		grid.update(0.25, false, 0.0)
		if grid.temp < 60.0:
			break
	_check(grid.rearm().contains("Red restablecida"), "power grid rearm restores the breaker")
	var restored: PowerGrid = PowerGrid.for_laboratory()
	_check(restored.from_dict(grid.to_dict()), "power grid state round-trips through a dictionary")
	_check(is_equal_approx(restored.capacity, grid.capacity), "restored grid keeps its capacity")

func _validate_vault_module() -> void:
	var vault: VaultModule = VaultModule.new()
	vault.apply_web_layout()
	root.add_child(vault)
	_check(vault.phase == "Sellada" and not vault.opened_once, "vault starts sealed")
	_check(vault.stations.size() == 4, "vault declares four use stations")
	_check(vault.drawers.size() == 5, "vault declares five drawers")
	_check(vault.station_near(Vector3(24.5, 1.6, -37.0)) == &"rearm", "vault detects the rearm station")
	_check(vault.begin_opening(), "vault opening starts")
	vault.update(6.0, Vector3.INF)
	_check(vault.phase == "Liberando pestillos", "vault phase follows the web timeline")
	vault.update(16.0, Vector3.INF)
	_check(vault.opened_once and vault.phase == "Abierta", "vault opens after 22 seconds")
	_check(vault.open_drawer(0, true), "opened vault lets drawers slide out")
	for _step in 60:
		vault.update(1.0 / 30.0, Vector3(float(vault.drawers[0]["bx"]) + 6.0, 1.0, float(vault.drawers[0]["bz"])))
	_check(vault.drawer_visible_item(0), "drawer contents become visible")
	var state: GameState = GameState.new()
	state.register_vault(vault)
	var saved: bool = state.save_game(QA_SAVE_PATH)
	_check(saved and not state.vault_snapshot().is_empty(), "game state stores the vault")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(QA_SAVE_PATH))
	state.queue_free()
	vault.queue_free()

func _validate_files_module() -> void:
	var files: FilesModule = FilesModule.new()
	files.apply_web_layout()
	root.add_child(files)
	_check(files.tray_count() == 10, "files module declares ten trays")
	_check(files.DOSSIERS.size() == 6, "files module ships the six web dossiers")
	var home: Vector3 = files.trays[0]["home"]
	_check(files.toggle(0), "files tray toggles open")
	for _step in 90:
		files.update(1.0 / 30.0, home + Vector3(6.0, 0.0, 0.0))
	_check(files.tray_revealed(0), "files tray slides out and reveals its sheet")
	var state: GameState = GameState.new()
	state.power_simulation = false
	state.add_to_group(&"game_state")
	root.add_child(state)
	state.register_files(files)
	_check(files.read_tray(0, null).contains("Ciclo de retorno"), "files dossier reads with its title")
	_check(state.survey_records.size() == 1, "read dossier lands in the field log")
	files.read_tray(0, null)
	_check(state.survey_records.size() == 1, "reading twice does not duplicate the log entry")
	_check(state.save_game(QA_SAVE_PATH), "game state saves the file cabinet")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(QA_SAVE_PATH))
	state.remove_from_group(&"game_state")
	state.queue_free()
	files.queue_free()

func _validate_operations_panel() -> void:
	var grid: PowerGrid = PowerGrid.new()
	var operations: OperationsPanel = OperationsPanel.new(grid)
	grid.apply_laboratory_circuits()
	root.add_child(operations)
	_check(operations.zones()[0] == "Generación", "operations panel starts on the generator group")
	_check(str(operations.selected_circuit().get("name", "")) == "INV 1", "operations panel starts on INV 1")
	_check(operations.light_zone(Vector3(24, 0, 56)) == "Electricidad", "operations panel maps the electrical room")
	_check(operations.area(-24, 56) == "Vigilancia", "operations panel maps the surveillance room")
	operations.handle(&"branchSwitch")
	_check(not grid.feeds[0], "switching INV 1 isolates its feeder")
	operations.handle(&"branchSwitch")
	_check(grid.feeds[0], "switching again restores the feeder")
	operations.handle(&"ecoMaster")
	_check(grid.limits[0], "eco mode limits the selected feeder to 14 kW")
	_check(str(operations.meter(0).get("title", "")).contains("ECO"), "meter shows eco state")
	operations.handle(&"illum")
	_check(is_equal_approx(grid.brightness, 0.55), "illumination steps down")
	_check(operations.strip_label(0) == "CAM 01 / OBSERVACIÓN", "camera strip labels the first channel")
	operations.handle(&"camNext")
	_check(operations.bank == 4, "camera bank advances four channels")
	operations.queue_free()

func _validate_bench_cycle() -> void:
	var state: GameState = GameState.new()
	state.power_simulation = false
	state.add_to_group(&"game_state")
	root.add_child(state)
	var player: NexusPlayer = load("res://scripts/world/player.gd").new()
	var camera := Camera3D.new()
	camera.name = "Camera3D"
	player.add_child(camera)
	root.add_child(player)
	player.game_state = state
	state.inventory.assign([&"lamp", &"cell", &"sample"] as Array[StringName])
	state.quick_slots.assign([&"cell", &"lamp", &"", &"", &""] as Array[StringName])
	player.flashlight_battery = 40.0
	player.energy = 20.0
	player.selected_quick_slot = 0
	var charger := state.bench(BenchCycle.CHARGER)
	var analyzer := state.bench(BenchCycle.ANALYZER)
	_check(charger != null and analyzer != null, "both technical benches exist")
	_check(is_equal_approx(charger.duration(), 8.0) and is_equal_approx(analyzer.duration(), 10.0),
		"bench durations match the web (8 s and 10 s)")
	_check(charger.interact(player).contains("Acoplando"), "charger mounts the cell")
	_check(is_equal_approx(charger.kw(), 18.0), "charger draws 18 kW while running")
	charger.update(2.0, player, true)
	_check(charger.stage == "SIN RED", "bench stalls when the grid trips")
	charger.update(9.0, player, false)
	_check(charger.done and is_equal_approx(player.energy, 100.0), "charger completes and refills energy")
	_check(charger.interact(player) == "Equipo retirado", "finished bench returns the item")
	check_bench_analyzer(analyzer, player, state)
	state.remove_from_group(&"game_state")
	player.free()
	state.queue_free()

func check_bench_analyzer(analyzer: BenchCycle, player: NexusPlayer, state: GameState) -> void:
	_check(state.has_item(&"sample"), "sample is in the inventory")
	_check(analyzer.interact(player).contains("Vial"), "analyzer takes the vial")
	analyzer.update(10.0, player, false)
	_check(analyzer.done and bool(state.bench_state.get("analyzed", false)),
		"analyzer marks the sample as analyzed")
	_check(analyzer.stage == "VERIFICADO / RETIRAR", "analyzer screen asks to remove the vial")

func _validate_w01_perception() -> void:
	var ai: MonsterAI = MonsterAI.new()
	_check(ai.state == "WATCHING" and is_equal_approx(ai.aggression, 0.2),
		"W-01 starts watching with the web aggression")
	_check(ai.state_for_distance(20.0) == "IDLE" and ai.state_for_distance(4.0) == "AGGRESSIVE",
		"W-01 maps distance to states like the web")
	ai.update(4.0, 0.1)
	_check(ai.state == "ATTACK" and is_equal_approx(ai.attack_cooldown, 6.4),
		"W-01 attacks inside 5,45 m with a 6,4 s cooldown")
	ai.update(4.0, 1.4)
	_check(ai.state == "RECOVERY", "W-01 recovers after the 1,22 s strike")
	ai.update(4.0, 2.2)
	_check(ai.state == "AGGRESSIVE", "W-01 returns to distance state after recovery")
	var attention: MonsterAttention = MonsterAttention.new()
	var monster := Vector3(0.0, 0.0, 22.0)
	var seen_step := attention.update(monster, 0.0, Vector3(0.0, 1.72, 28.0), 0.1)
	_check(bool(seen_step["seen"]) and is_equal_approx(attention.memory, 5.4),
		"W-01 sees inside its 1,29 rad cone and remembers for 5,4 s")
	attention.reset()
	var mem_step := attention.update(monster, 0.0, Vector3(0.0, 1.72, 10.0), 0.1)
	_check(not bool(mem_step["seen"]) and attention.memory < 5.4,
		"W-01 ignores what is behind it and far away")
	attention.reset()
	attention.update(Vector3(0.0, 0.0, 35.0), 0.0, Vector3(0.0, 1.72, 60.0), 0.2)
	_check(attention.intent == "Bordea la malla", "W-01 skirts the containment mesh")
	var field: FieldMemory = FieldMemory.new()
	_check(field.remember(5, 0.1) and is_equal_approx(field.sector_risk(5), 0.1),
		"field memory records risk per sector")
	var restored_field: FieldMemory = FieldMemory.new()
	_check(restored_field.from_dict(field.to_dict()) and is_equal_approx(restored_field.sector_risk(5), 0.1),
		"field memory survives serialisation")

func _validate_transit() -> void:
	var transit: CapsuleTransit = CapsuleTransit.new()
	transit.simulation = false
	transit.reset()
	_check(is_equal_approx(transit.at, 102.0) and transit.status == "ANDÉN 01",
		"capsule waits at platform 01 with the web placard")
	_check(not transit.can_stand(0.0, 68.0), "closed apron gate blocks the platform")
	transit.gate = 1.0
	_check(transit.can_stand(3.0, 68.0) and not transit.can_stand(3.6, 68.0),
		"open gate restores the source walking band")
	_check(transit.inside(Vector3(15.0, 1.7, 100.0)) and not transit.inside(Vector3(13.0, 1.7, 100.0)),
		"capsule volume matches the web bounds")
	var player := Vector3(15.0, 1.7, 100.0)
	var call := transit.use(&"railCallB", player)
	_check(str(call.get("message", "")).contains("Cierre"), "platform call authorises departure")
	transit.step(0.6, player, true, 0.0, 0.0)
	_check(transit.door < 0.6, "doors close during the 1,4 s seal")
	transit.step(0.9, player, true, 0.0, 0.0)
	_check(transit.at > 102.0 and transit.status.ends_with("km/h"),
		"capsule departs after the seal and shows its speed")
	var riding := transit.step(5.0, player, true, 0.0, 0.0)
	_check(riding.z > player.z + 100.0, "rider is carried along the axis")
	transit.step(10.0, player, true, 0.0, 0.0)
	_check(is_equal_approx(transit.at, 2042.0) and transit.status == "ANDÉN 02",
		"capsule reaches platform 02 in ten seconds")
	transit.use(&"railCallA", player)
	transit.step(0.4, player, true, 0.0, 0.0)
	transit.use(&"railBrake", player)
	var held := transit.at
	transit.step(2.0, player, true, 0.0, 0.0)
	_check(transit.status == "RETENIDA" and is_equal_approx(transit.at, held),
		"retention brake holds the capsule")
	transit.use(&"railBrake", player)
	transit.use(&"railSeat1", player)
	_check(is_equal_approx(transit.step(0.016, player, true, 0.0, 0.0).y, 1.47),
		"seats sit at the web height")
	_check(not transit.use(&"railStand", player).get("position", Vector3.ZERO) == player,
		"standing up clears the seat")

	var car: CapsuleTransit = CapsuleTransit.new()
	car.simulation = false
	car.reset()
	car._car_offset = Vector3(-12.0, 0.0, 109.0)
	_check(str(car.use(&"railLoad", player).get("message", "")).contains("embarcando"),
		"car transfer starts inside the amber frame")
	car.step(2.0, player, true, 0.0, 0.0)
	_check(car.car_position().x > -12.0 and car.car_position().x < 15.0,
		"car travels towards the axis during the four seconds")
	car.step(2.1, player, true, 0.0, 0.0)
	_check(car.loaded and is_equal_approx(car.car_position().x, 15.0), "car locks onto the capsule")

	var vehicle: VehiclePhysics = VehiclePhysics.new()
	vehicle.reset(-12.0, 109.0, 0.0, true)
	for _i in 240:
		vehicle.step(1.0 / 120.0, 1.0, 0.0, false, false)
	_check(vehicle.speed > 5.0 and vehicle.position.z > 109.0,
		"rail car accelerates forwards with the web motor force")
	_check(vehicle.kmh() > 18.0 and vehicle.gear != "N", "rail car reports speed and gear")
	for _i in 120 * 3:
		vehicle.step(1.0 / 120.0, 1.0, 0.0, false, true)
	_check(vehicle.boost and vehicle.energy < 40.0, "turbo drains the capacitor at 24 per second")
	vehicle.register_impact(6.7)
	_check(is_equal_approx(vehicle.integrity, 93.4), "impact costs integrity like the web")
	var restored := VehiclePhysics.new()
	restored.from_dict(vehicle.to_dict())
	_check(is_equal_approx(restored.energy, vehicle.energy), "rail car state survives a save round-trip")

	var state := GameState.new()
	state.power_simulation = false
	state.register_transit(car)
	_check(state.transit_snapshot().has("vehicle"), "game state stores the capsule snapshot")

func _validate_camera() -> void:
	var view: CameraController = CameraController.new()
	_check(view.mode == "orbit" and is_equal_approx(view.stamina, 100.0),
		"camera controller starts in orbit with full stamina")
	_check(view.orbit_position().distance_to(CameraController.ORBIT_CAMERA) < 0.001,
		"orbit starts where the web places the camera")
	for _i in 240:
		view.orbit_zoom(1.0)
		view.update_orbit(1.0 / 60.0)
	_check(is_equal_approx(view.orbit_distance(), CameraController.ORBIT_MAX_DISTANCE),
		"orbit zoom stops at the web distance limit")
	view.set_mode("first-person")
	_check(view.is_first_person() and view.first_position.distance_to(Vector3(1.8, 1.72, 42.0)) < 0.001,
		"first person starts at the web eye position")
	view.look(0.0, -100000.0, 0.0021)
	_check(is_equal_approx(view.pitch, CameraController.PITCH_LIMIT),
		"first person pitch clamps like the web")
	view.crouch = true
	_check(is_equal_approx(view.eye_position().y, 1.72 - 0.44), "crouch lowers the eyes 44 cm")
	view.crouch = false
	view.stamina = 50.0
	view.gait = PI * 0.5
	_check(is_equal_approx(view.bob_offset(), 0.027 * 0.5), "head bob scales with fatigue")
	var walker: CameraController = CameraController.new()
	walker.set_mode("first-person")
	walker.first_position = Vector3(0.0, 1.72, 0.0)
	for _i in 60 * 8:
		walker.update_walk(1.0 / 60.0, Vector2(0.0, 1.0), true)
	_check(walker.spent and walker.stamina < 1.0,
		"sprinting drains 14 stamina per second and marks the runner spent")
	var car: CameraController = CameraController.new()
	car.move("w", true)
	car.move("d", true)
	_check(car.transit_input().is_equal_approx(Vector2(1.0, 1.0)),
		"keyboard drives the rail car like the web bindings")
	_check(InputMap.has_action(&"toggle_view") and InputMap.has_action(&"crouch"),
		"view toggle and crouch are mapped")

func _validate_displays() -> void:
	var model: TelemetryModel = TelemetryModel.new()
	var bus := {"load": 68.0, "temp": 43.5, "capacity": 112, "tripped": false,
		"feeds": [true, false], "fans": [true, true], "cause": "Estable"}
	_check(model.sample(0.0, bus, 95.0, 9.0, "WATCHING", Vector3.ZERO, "Vigila", 2, 0.2),
		"telemetry takes the first sample")
	_check(not model.sample(0.1, bus, 95.0, 9.0, "WATCHING", Vector3.ZERO, "Vigila", 2, 0.2),
		"telemetry throttles samples to 0,35 s")
	_check(str(model.values()[0][1]) == "95 %" and str(model.values()[1][1]) == "9.0 m",
		"telemetry formats integrity and distance")
	model.set_page(1)
	_check(str(model.values()[0][1]) == "112 kW" and model.track_line() == "> feeds = 10    cooling = 11",
		"telemetry diagnostic page mirrors the web values")
	model.set_page(2)
	_check(model.series_indices() == [3, 4, 2] and str(model.values()[1][1]) == "20 %",
		"telemetry tracking page plots distance, threat and integrity")
	var panel: PhosphorDisplay = PhosphorDisplay.new()
	for _i in 100:
		panel.paint("RED · E-07", "68 kW", "este", 0.61)
	_check(panel.history.size() == 72 and panel.trace_points().size() == 72,
		"phosphor display keeps a 72 sample trace")
	_check(panel.trace_points()[71].x > panel.trace_points()[0].x, "phosphor trace advances")
	var screen: WallScreen = WallScreen.new()
	screen.kind = "telemetry"
	root.add_child(screen)
	screen._ready()
	_check(screen.viewport.size == Vector2i(1024, 576)
		and (screen.mesh.mesh as QuadMesh).size == Vector2(2.36, 1.328),
		"CAM 04 renders 1024x576 onto a 2,36 x 1,328 m quad")
	_check(screen.push_telemetry(0.0, bus, 90.0, 5.0, "AGGRESSIVE", Vector3.ZERO, "Carga", 1, 0.6),
		"CAM 04 accepts a live sample")
	var state := GameState.new()
	state.power_simulation = false
	var feed := TelemetryFeed.new()
	feed.screen = screen
	var sampled := feed.grid_snapshot(state)
	_check(sampled.has("load") and sampled.has("feeds"), "telemetry feed reads the power grid")
	feed.clock = 1.0
	_check(feed.sample(state), "telemetry feed pushes a frame to the screen")
	root.remove_child(screen)
	screen.free()
	feed.free()
	var electrical := load("res://zones/zone_electrical.tscn") as PackedScene
	var zone := electrical.instantiate()
	var cam := zone.get_node_or_null("Displays/Cam04") as WallScreen
	_check(cam != null and cam.kind == "telemetry", "electrical zone mounts the CAM 04 screen")
	_check(zone.get_node_or_null("Displays/TelemetryFeed") != null,
		"electrical zone feeds the screen from the game state")
	zone.free()

func _validate_experience() -> void:
	var nx := ExperienceState.new([&"lamp", &"pulse", &"cryo", &"cell"])
	_check(is_equal_approx(float(ExperienceState.PROTOCOLS["uv"]["cost"]), 32.0)
		and is_equal_approx(float(ExperienceState.PROTOCOLS["gas"]["cd"]), 12.0),
		"protocol costs and cooldowns match the web")
	_check(nx.action("uv").contains("reflejo") and is_equal_approx(nx.energy, 68.0)
		and is_equal_approx(nx.uv, 8.0), "UV pulse costs 32 energy and locks the grid for 8 s")
	_check(not nx.spend("uv"), "protocol is unavailable while recharging")
	_check(nx.action("gas").contains("criogénica") and is_equal_approx(nx.cold, 7.0),
		"cryogenic fog slows the subject for 7 s")
	_check(nx.bind_slot(0, "pulse") and str(nx.slots[0]) == "pulse", "slot binding works")
	_check(nx.bind_slot(2, "pulse") and nx.slots[0] == null, "binding moves an item between slots")
	_check(not nx.bind_slot(1, "lamp") and not nx.bind_slot(1, "medkit"),
		"the lamp and unknown items are rejected from slots")
	nx.bind_slot(3, "cell")
	nx.energy = 40.0
	nx.battery = 20.0
	_check(nx.use_slot("cell").contains("Celda conectada") and is_equal_approx(nx.energy, 90.0)
		and is_equal_approx(nx.battery, 100.0) and not nx.charged,
		"the field cell restores the battery and adds 50 energy")
	_check(nx.use_slot("cell").contains("agotada"), "a drained cell cannot be reused")
	_check(ExperienceState.prompt_for("bin2", false, false, true) == "Cajón 2 · cerrar",
		"drawer prompts follow the web wording")
	_check(ExperienceState.part_name("eye-3") == "Ojo satélite 3"
		and ExperienceState.part_note("maw").contains("mandíbula"), "subject part labels match")
	var density := ExperienceState.render_density("high", 1920.0, 1080.0, false, 2.0)
	_check(is_equal_approx(density, 1.65), "render density follows the web desktop caps")
	_check(is_equal_approx(ExperienceState.fov_for(true, 1920.0, 1080.0), 68.0)
		and is_equal_approx(ExperienceState.fov_for(false, 600.0, 900.0), 49.0),
		"field of view depends on mode and aspect")
	_check(ExperienceState.shadows_enabled("high") and not ExperienceState.bloom_enabled("low")
		and is_equal_approx(ExperienceState.bloom_strength("medium"), 0.13),
		"quality presets drive shadows and bloom")
	var state := GameState.new()
	state.power_simulation = false
	state.persistence_path = "user://nexus_native_quality_check.json"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(state.persistence_path))
	state.set_quality("low")
	state.experience.bind_slot(0, &"pulse")
	_check(state.save_game(), "quality profile is written to the save")
	var reloaded := GameState.new()
	reloaded.power_simulation = false
	reloaded.persistence_path = state.persistence_path
	_check(reloaded.load_game(), "quality profile is read back")
	_check(reloaded.quality() == "low" and str(reloaded.experience.slots[0]) == "pulse",
		"experience state survives a save round-trip")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(state.persistence_path))
	_check(InputMap.has_action(&"cycle_quality"), "quality cycling is mapped")
	state.free()
	reloaded.free()

func _validate_session() -> void:
	var session: SessionState = SessionState.new("high")
	_check(is_equal_approx(session.set_sensitivity(0.1), 0.35)
		and is_equal_approx(session.set_sensitivity(9.0), 2.5),
		"camera sensitivity clamps to the web range 0,35-2,5")
	_check(is_equal_approx(session.nudge_sensitivity(-1), 2.45),
		"sensitivity moves in 0,05 steps")
	_check(session.set_quality("low") == "low" and session.set_quality("ultra") == "low",
		"session quality accepts only the three presets")
	_check(SessionState.detect_device(true, false, false) == "android"
		and SessionState.detect_device(false, true, true) == "touch"
		and SessionState.detect_device(false, false, false) == "pc",
		"device detection mirrors the web")
	_check(session.open_panel("map") and not session.active(), "data panels pause the simulation")
	session.close_panel()
	_check(session.active(), "closing a data panel resumes the game")
	_check(session.pause() and session.panel == "pause" and not session.active(),
		"pause opens the pause panel")
	session.close_panel()
	_check(session.panel == "pause", "closing the pause panel keeps the pause")
	_check(session.resume() and session.active(), "resume returns to the game")
	_check(session.set_view(true) == "Operador en primera persona"
		and session.first_person and session.zoom, "view switch is logged")
	var nx := ExperienceState.new([&"lamp"])
	_check(SessionState.tip_id(nx) == "lamp", "tip id follows the lamp inventory")
	var tip_state := SessionState.new()
	tip_state.first_person = true
	_check(tip_state.update(0.3, nx).is_empty(), "tips wait 0,55 s")
	_check(tip_state.update(0.3, nx) == SessionState.tip_text("lamp"), "tips appear once")
	_check(tip_state.update(6.0, nx).is_empty() and tip_state.tip.is_empty(),
		"tips disappear after 5,95 s")
	_check(tip_state.update(2.0, nx).is_empty(), "a shown tip never returns")
	for _i in 80:
		session.log_entry("evento")
	_check(session.entries.size() == 60, "session log keeps the last 60 entries")
	_check(session.log_lines()[0].contains("evento"), "session log lines carry stamp and text")
	var state := GameState.new()
	state.power_simulation = false
	state.persistence_path = "user://nexus_native_session_suite.json"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(state.persistence_path))
	state.session.set_sensitivity(1.5)
	state.session.set_guides(false)
	state.save_game()
	var reloaded := GameState.new()
	reloaded.power_simulation = false
	reloaded.persistence_path = state.persistence_path
	_check(reloaded.load_game() and is_equal_approx(reloaded.session.sensitivity, 1.5)
		and not reloaded.session.guides, "session settings survive a save round-trip")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(state.persistence_path))
	state.free()
	reloaded.free()

func _run() -> void:
	await _validate_exported_pattern()
	await _validate_portal_assembly()
	await _validate_all_structural_zones()
	await _validate_zone_dressing()
	var packed := load("res://main.tscn") as PackedScene
	_check(packed != null, "main scene loads")
	if packed == null:
		_finish()
		return
	_validate_power_grid()
	_validate_vault_module()
	_validate_files_module()
	_validate_operations_panel()
	_validate_bench_cycle()
	_validate_w01_perception()
	_validate_transit()
	_validate_camera()
	_validate_displays()
	_validate_experience()
	_validate_session()
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
	hud._on_panel_requested(&"pause")
	var cfg_button := _find_button_named(hud.get_node("FieldPanel"), "AJUSTAR CONTROLES")
	_check(cfg_button != null, "pause panel offers the controls settings")
	if cfg_button != null:
		cfg_button.pressed.emit()
		_check(_find_slider(hud.get_node("FieldPanel")) != null,
			"settings panel exposes the camera sensitivity slider")
		_check(_find_checkbox(hud.get_node("FieldPanel")) != null,
			"settings panel exposes the once-only tips toggle")
		_check(_find_button_named(hud.get_node("FieldPanel"), "REINICIAR ENCUENTRO") != null,
			"settings panel offers the encounter reset")
		var slider := _find_slider(hud.get_node("FieldPanel"))
		if slider != null:
			slider.value = 1.75
			_check(is_equal_approx(main.game_state.session.sensitivity, 1.75),
				"slider updates the camera sensitivity")
	hud._on_panel_requested(&"pause")
	var log_button := _find_button_named(hud.get_node("FieldPanel"), "BITÁCORA DE SESIÓN")
	_check(log_button != null, "pause panel opens the session log")
	if log_button != null:
		log_button.pressed.emit()
		_check(main.game_state.session.entries.size() >= 2, "session log keeps its entries")
	_check(paused, "settings keep the simulation paused while open")
	hud._close_panel()
	_check(paused and hud._active_panel == &"pause",
		"closing the settings returns to the pause panel")
	hud._close_panel()
	_check(not paused, "closing the pause panel resumes the game")
	_check(main.apply_quality_category("low") == "low", "F3 applies the low profile at runtime")
	_check(is_equal_approx(main.get_viewport().scaling_3d_scale, 0.85),
		"low profile lowers the 3D render scale to the web density")
	_check(main.apply_quality_category("high") == "high"
		and is_equal_approx(main.get_viewport().scaling_3d_scale, 1.0),
		"high profile restores native resolution")
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
	# La petición de apertura es síncrona: se lee antes de ceder frames, porque la
	# compuerta vuelve a su estado por proximidad en cuanto el jugador se aleja.
	var approach_requested := portal_a01.begin_approach(player)
	var requested_aperture := portal_a01.target_aperture
	_check(approach_requested, "approach starts asynchronous A-01 preload")
	_check(await _wait_preloaded(manager, &"a01"), "A-01 preload completes before crossing")
	_check(requested_aperture == 1.0, "approach requests door opening")

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
