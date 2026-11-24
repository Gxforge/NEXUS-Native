extends SceneTree

func _init() -> void:
	var checks: Dictionary = {
		"a01_local": ZoneOwnershipPolicy.owner_for(AABB(Vector3(-5, 0, -30), Vector3(1, 1, 1))) == &"a01",
		"c04_local": ZoneOwnershipPolicy.owner_for(AABB(Vector3(0, 0, 20), Vector3(1, 1, 1))) == &"c04",
		"portal_connection": ZoneOwnershipPolicy.owner_for(AABB(Vector3(-0.5, 0, -20), Vector3(1, 4, 1))) == ZoneOwnershipPolicy.CONNECTION,
		"outside_shared": ZoneOwnershipPolicy.owner_for(AABB(Vector3(0, 0, -220), Vector3(1, 1, 1))) == ZoneOwnershipPolicy.SHARED,
		"transit_controller": ZoneOwnershipPolicy.owner_for(AABB(), "Transit") == &"transit_controller",
		"gates_connection": ZoneOwnershipPolicy.owner_for(AABB(), "ZoneGates") == ZoneOwnershipPolicy.CONNECTION,
		"twelve_bounds": ZoneOwnershipPolicy.BOUNDS.size() == 12,
		"graph_mirror": _graph_mirror_matches(),
		"b02_local": ZoneOwnershipPolicy.owner_for(AABB(Vector3(12, 0, -26), Vector3(1, 1, 1))) == &"b02",
		"gallery_local": ZoneOwnershipPolicy.owner_for(AABB(Vector3(18, 0, -60), Vector3(1, 1, 1))) == &"v03_gallery",
		"cryo_local": ZoneOwnershipPolicy.owner_for(AABB(Vector3(20, 0, -104), Vector3(1, 1, 1))) == &"v03_cryo",
		"rail_local": ZoneOwnershipPolicy.owner_for(AABB(Vector3(14, 0, 400), Vector3(1, 1, 1))) == &"transit_rail",
		"hub_local": ZoneOwnershipPolicy.owner_for(AABB(Vector3(0, 0, 80), Vector3(1, 1, 1))) == &"transit_hub",
	}
	var passed: bool = not checks.values().has(false)
	print(JSON.stringify({"checks": checks, "passed": passed}))
	quit(0 if passed else 1)

func _graph_mirror_matches() -> bool:
	var file: FileAccess = FileAccess.open("res://data/zone_graph.json", FileAccess.READ)
	if file == null:
		return false
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not parsed is Dictionary:
		return false
	for zone: Dictionary in (parsed as Dictionary).get("zones", []):
		var zone_id := StringName(str(zone.get("id", "")))
		if not ZoneOwnershipPolicy.BOUNDS.has(zone_id):
			return false
		var bounds: Dictionary = zone.get("bounds", {})
		var low: Array = bounds.get("min", [0.0, 0.0])
		var high: Array = bounds.get("max", [0.0, 0.0])
		var rect: Rect2 = ZoneOwnershipPolicy.BOUNDS[zone_id]
		if absf(rect.position.x - float(low[0])) > 0.01 or absf(rect.position.y - float(low[1])) > 0.01:
			return false
		if absf(rect.size.x - (float(high[0]) - float(low[0]))) > 0.01:
			return false
		if absf(rect.size.y - (float(high[1]) - float(low[1]))) > 0.01:
			return false
	return true
