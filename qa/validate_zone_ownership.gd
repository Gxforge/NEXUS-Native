extends SceneTree

func _init() -> void:
	var checks: Dictionary = {
		"a01_local": ZoneOwnershipPolicy.owner_for(AABB(Vector3(5, 0, -30), Vector3(1, 1, 1))) == &"a01",
		"c04_local": ZoneOwnershipPolicy.owner_for(AABB(Vector3(-5, 0, -30), Vector3(1, 1, 1))) == &"c04",
		"portal_connection": ZoneOwnershipPolicy.owner_for(AABB(Vector3(-0.5, 0, -20), Vector3(1, 4, 1))) == ZoneOwnershipPolicy.CONNECTION,
		"corridor_shared": ZoneOwnershipPolicy.owner_for(AABB(Vector3(0, 0, 0), Vector3(1, 1, 1))) == ZoneOwnershipPolicy.SHARED,
		"transit_controller": ZoneOwnershipPolicy.owner_for(AABB(), "Transit") == &"transit_controller",
		"gates_connection": ZoneOwnershipPolicy.owner_for(AABB(), "ZoneGates") == ZoneOwnershipPolicy.CONNECTION,
	}
	var passed: bool = not checks.values().has(false)
	print(JSON.stringify({"checks": checks, "passed": passed}))
	quit(0 if passed else 1)
