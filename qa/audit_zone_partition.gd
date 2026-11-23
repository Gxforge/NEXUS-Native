extends SceneTree

const ZONES: Array[Dictionary] = [
	{"id": "electricidad", "min": Vector2(-36.0, 52.44), "max": Vector2(-17.46, 70.0)},
	{"id": "vigilancia", "min": Vector2(17.46, 44.44), "max": Vector2(36.0, 70.0)},
	{"id": "turbinas", "min": Vector2(1.0, -70.0), "max": Vector2(13.85, -54.0)},
	{"id": "registros", "min": Vector2(22.15, -90.0), "max": Vector2(37.0, -74.0)},
	{"id": "crioteca", "min": Vector2(9.0, -112.0), "max": Vector2(27.0, -96.16)},
	{"id": "c04", "min": Vector2(-36.0, -38.0), "max": Vector2(-0.25, -14.32)},
	{"id": "a01", "min": Vector2(0.25, -38.0), "max": Vector2(36.0, -14.32)},
	{"id": "galeria", "min": Vector2(14.0, -95.9), "max": Vector2(22.0, -38.2)},
]

func _init() -> void:
	var source: PackedScene = load("res://assets/generated/source-batch/laboratory_all_sectors.glb") as PackedScene
	if source == null:
		printerr("Full sector source failed to load")
		quit(1)
		return
	var root: Node3D = source.instantiate() as Node3D
	get_root().add_child(root)
	await process_frame
	root.force_update_transform()
	var counts: Dictionary = {}
	var vertices: Dictionary = {}
	for zone: Dictionary in ZONES:
		counts[zone.id] = 0
		vertices[zone.id] = 0
	counts["shared_or_unassigned"] = 0
	vertices["shared_or_unassigned"] = 0
	var shared_branches: Dictionary = {}
	var multi_zone_meshes: int = 0
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is MeshInstance3D:
			var instance: MeshInstance3D = node as MeshInstance3D
			var world_box: AABB = instance.global_transform * instance.get_aabb()
			var center: Vector3 = world_box.get_center()
			var zone_id: String = _zone_for(center)
			counts[zone_id] += 1
			var overlaps: Array[String] = _overlapping_zones(world_box)
			if overlaps.size() > 1:
				multi_zone_meshes += 1
			if zone_id == "shared_or_unassigned":
				var branch_name: String = _root_branch(instance, root)
				shared_branches[branch_name] = int(shared_branches.get(branch_name, 0)) + 1
			var mesh_vertices: int = 0
			if instance.mesh != null:
				for surface_index: int in instance.mesh.get_surface_count():
					var arrays: Array = instance.mesh.surface_get_arrays(surface_index)
					var positions: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
					mesh_vertices += positions.size()
			vertices[zone_id] += mesh_vertices
		for child: Node in node.get_children():
			stack.push_back(child)
	var functional_shared: Dictionary = {}
	var anonymous_shared: int = 0
	for branch_name: String in shared_branches:
		if branch_name.begins_with("Node") or branch_name.begins_with("Mesh"):
			anonymous_shared += int(shared_branches[branch_name])
		else:
			functional_shared[branch_name] = shared_branches[branch_name]
	var report: Dictionary = {
		"schema": 1,
		"source": "assets/generated/source-batch/laboratory_all_sectors.glb",
		"source_commit": "f4e1e819a9c783374e79dbc99cde4597099aba11",
		"classification": "world-space AABB center against original ZoneCache bounds",
		"mesh_instances": counts,
		"vertices": vertices,
		"shared_by_root_branch": shared_branches,
		"functional_shared_branches": functional_shared,
		"anonymous_shared_meshes": anonymous_shared,
		"multi_zone_meshes": multi_zone_meshes,
		"warning": "This is an ownership audit only; functional parent hierarchies must be retained during export."
	}
	var file: FileAccess = FileAccess.open("res://reports/zone-partition-audit.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  ") + "\n")
	file.close()
	print(JSON.stringify(report))
	root.queue_free()
	quit(0)

func _root_branch(node: Node, root: Node) -> String:
	var branch: Node = node
	while branch.get_parent() != null and branch.get_parent().get_parent() != root:
		branch = branch.get_parent()
	return str(branch.name)

func _overlapping_zones(box: AABB) -> Array[String]:
	var result: Array[String] = []
	var end: Vector3 = box.end
	for zone: Dictionary in ZONES:
		var lower: Vector2 = zone.min
		var upper: Vector2 = zone.max
		if end.x >= lower.x and box.position.x <= upper.x and end.z >= lower.y and box.position.z <= upper.y:
			result.append(zone.id)
	return result

func _zone_for(point: Vector3) -> String:
	for zone: Dictionary in ZONES:
		var lower: Vector2 = zone.min
		var upper: Vector2 = zone.max
		if point.x >= lower.x and point.x <= upper.x and point.z >= lower.y and point.z <= upper.y:
			return zone.id
	return "shared_or_unassigned"
