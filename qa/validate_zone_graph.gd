extends SceneTree

## Validates the twelve-zone laboratory graph against the generated scenes:
## identity, structural manifest, collisions, door sockets, portal wiring and
## footprint overlap rules.

const GRAPH_PATH := "res://data/zone_graph.json"
const LOCAL_OFFSET := Vector3(9.0, 0.0, 14.0)
const TOLERANCE := 0.05

var checks: Dictionary = {}
var failures: Array[String] = []

func _init() -> void:
	_run()

func _run() -> void:
	var graph := _load_graph()
	if graph.is_empty():
		_finish()
		return
	var zones: Array = graph.get("zones", [])
	var connections: Array = graph.get("connections", [])
	_check(zones.size() == 12, "zone graph declares twelve modules")
	_check(connections.size() == 11, "zone graph declares eleven transit connections")
	var ids: Array[String] = []
	for zone: Dictionary in zones:
		ids.append(str(zone.get("id", "")))
	for expected: String in ["c04", "a01", "b02", "surveillance", "electrical", "transit_hub",
			"transit_road", "transit_rail", "v03_gallery", "h01", "d02", "v03_cryo"]:
		_check(ids.has(expected), "graph contains zone %s" % expected)

	var overlaps := _overlaps(zones, graph)
	_check(overlaps.is_empty(), "zone footprints do not overlap (except declared hulls): %s" % str(overlaps))

	var instances: Dictionary = {}
	for zone: Dictionary in zones:
		var zone_id := str(zone.get("id", ""))
		var packed := load(str(zone.get("scene", ""))) as PackedScene
		_check(packed != null, "%s scene loads" % zone_id)
		if packed == null:
			continue
		var instance := packed.instantiate() as ZoneRoot
		_check(instance != null, "%s scene root is a ZoneRoot" % zone_id)
		if instance == null:
			continue
		instances[zone_id] = instance
		root.add_child(instance)
		await process_frame
		_check(str(instance.zone_id) == zone_id, "%s scene carries its zone id" % zone_id)
		_validate_shell(zone_id, instance, zone)
		_validate_sockets(zone_id, instance, zone, connections, graph)
	for zone_id: String in instances:
		var instance: ZoneRoot = instances[zone_id]
		instance.queue_free()
	await process_frame
	_finish()

func _validate_shell(zone_id: String, instance: ZoneRoot, zone: Dictionary) -> void:
	var shell := instance.get_node_or_null("StructuralShell") as StructuralShell
	_check(shell != null, "%s has a structural shell" % zone_id)
	if shell == null:
		return
	var manifest := _load_json(shell.manifest_path)
	_check(not manifest.is_empty(), "%s structural manifest is readable" % zone_id)
	if manifest.is_empty():
		return
	_check(shell.collision_count == int(manifest.get("expected_collisions", -1)),
		"%s builds %d manifest collisions" % [zone_id, int(manifest.get("expected_collisions", -1))])
	var expected_min: Array = manifest.get("expected_bounds", {}).get("min", [])
	var expected_max: Array = manifest.get("expected_bounds", {}).get("max", [])
	var meshes: Array[MeshInstance3D] = []
	_collect_meshes(shell, meshes)
	_check(meshes.size() >= 1, "%s shell contains renderable geometry" % zone_id)
	if meshes.is_empty() or expected_min.size() < 3 or expected_max.size() < 3:
		return
	var merged := AABB()
	var first := true
	for mesh_instance: MeshInstance3D in meshes:
		var box: AABB = mesh_instance.get_aabb()
		merged = box if first else merged.merge(box)
		first = false
	_check((merged.position - Vector3(expected_min[0], expected_min[1], expected_min[2])).length() < 0.5,
		"%s shell AABB origin matches manifest" % zone_id)
	_check((merged.end - Vector3(expected_max[0], expected_max[1], expected_max[2])).length() < 0.5,
		"%s shell AABB extent matches manifest" % zone_id)
	var rect: Array = manifest.get("world_rect", [])
	_check(rect.size() == 4, "%s manifest declares its world footprint" % zone_id)

func _validate_sockets(zone_id: String, instance: ZoneRoot, zone: Dictionary,
		connections: Array, graph: Dictionary) -> void:
	var sockets := instance.get_node_or_null("DoorSockets") as Node3D
	_check(sockets != null, "%s exposes DoorSockets" % zone_id)
	if sockets == null:
		return
	var entry_socket := str(zone.get("entry_socket", "entry"))
	_check(sockets.get_node_or_null(entry_socket) is Marker3D, "%s exposes its %s socket" % [zone_id, entry_socket])
	var bounds: Dictionary = zone.get("bounds", {})
	var low: Array = bounds.get("min", [0.0, 0.0])
	var high: Array = bounds.get("max", [0.0, 0.0])
	var related := 0
	for connection: Dictionary in connections:
		var from_zone := str(connection.get("from_zone", ""))
		var to_zone := str(connection.get("to_zone", ""))
		if from_zone != zone_id and to_zone != zone_id:
			continue
		related += 1
		var peer := to_zone if from_zone == zone_id else from_zone
		var socket_name := str(connection.get("from_socket" if from_zone == zone_id else "to_socket", ""))
		var peer_socket := str(connection.get("to_socket" if from_zone == zone_id else "from_socket", ""))
		var marker := sockets.get_node_or_null(NodePath(socket_name)) as Marker3D
		_check(marker != null, "%s has socket %s for %s" % [zone_id, socket_name, peer])
		if marker != null and low.size() >= 2 and high.size() >= 2:
			var world := marker.position - LOCAL_OFFSET
			_check(world.x >= float(low[0]) - 2.1 and world.x <= float(high[0]) + 2.1
				and world.z >= float(low[1]) - 2.1 and world.z <= float(high[1]) + 2.1,
				"%s socket %s sits inside the module footprint" % [zone_id, socket_name])
		var portal := _portal_for(instance, peer)
		_check(portal != null, "%s integrates a portal toward %s" % [zone_id, peer])
		if portal != null:
			_check(str(portal.target_zone) == peer, "%s portal %s targets %s" % [zone_id, portal.name, peer])
			_check(str(portal.target_socket) == peer_socket,
				"%s portal %s uses the %s arrival socket" % [zone_id, portal.name, peer_socket])
			var door: Array = connection.get("world_door", [])
			if door.size() == 2:
				var expected := Vector3(float(door[0]), 0.0, float(door[1])) + LOCAL_OFFSET
				_check((portal.position - expected).length() < TOLERANCE,
					"%s portal %s stands on its shared threshold" % [zone_id, portal.name])
	_check(related > 0 or zone_id in ["transit_road", "transit_rail"],
		"%s participates in the transit graph" % zone_id)

func _portal_for(instance: Node, peer: String) -> StreamingSectorDoor:
	for child: Node in instance.get_children():
		if child is StreamingSectorDoor:
			var door := child as StreamingSectorDoor
			if str(door.target_zone) == peer:
				return door
	return null

func _overlaps(zones: Array, graph: Dictionary) -> Array[String]:
	var issues: Array[String] = []
	var allowed: Dictionary = {}
	for zone: Dictionary in zones:
		for child: String in zone.get("hull_of", []):
			allowed["%s|%s" % [zone.get("id", ""), child]] = true
			allowed["%s|%s" % [child, zone.get("id", "")]] = true
	for index in zones.size():
		for other_index in range(index + 1, zones.size()):
			var a: Dictionary = zones[index]
			var b: Dictionary = zones[other_index]
			var a_min: Array = a.get("bounds", {}).get("min", [0, 0])
			var a_max: Array = a.get("bounds", {}).get("max", [0, 0])
			var b_min: Array = b.get("bounds", {}).get("min", [0, 0])
			var b_max: Array = b.get("bounds", {}).get("max", [0, 0])
			var separated: bool = float(a_max[0]) <= float(b_min[0]) or float(b_max[0]) <= float(a_min[0]) \
				or float(a_max[1]) <= float(b_min[1]) or float(b_max[1]) <= float(a_min[1])
			if separated:
				continue
			var key := "%s|%s" % [str(a.get("id", "")), str(b.get("id", ""))]
			if allowed.has(key):
				continue
			issues.append(key)
	return issues

func _collect_meshes(node: Node, output: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		output.append(node as MeshInstance3D)
	for child: Node in node.get_children():
		_collect_meshes(child, output)

func _load_graph() -> Dictionary:
	return _load_json(GRAPH_PATH)

func _load_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		printerr("Cannot read %s" % path)
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	return parsed as Dictionary if parsed is Dictionary else {}

func _check(condition: bool, message: String) -> void:
	checks[message] = condition
	if not condition:
		failures.append(message)

func _finish() -> void:
	var total := checks.size()
	var passed := total - failures.size()
	print(JSON.stringify({
		"suite": "zone_graph",
		"total": total,
		"passed": passed,
		"failed": failures.size(),
		"failures": failures,
		"checks": checks,
	}, "  "))
	quit(0 if failures.is_empty() else 1)
