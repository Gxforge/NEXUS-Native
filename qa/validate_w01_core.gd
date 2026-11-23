extends SceneTree

func _init() -> void:
	var packed: PackedScene = load("res://assets/generated/w01_core.glb") as PackedScene
	if packed == null:
		printerr("W01 core GLB did not load")
		quit(1)
		return
	var root: Node = packed.instantiate()
	var mesh_count: int = 0
	var tooth_count: int = 0
	var morph_mesh_count: int = 0
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is MeshInstance3D:
			mesh_count += 1
			var instance: MeshInstance3D = node as MeshInstance3D
			if instance.name.begins_with("Tooth_"):
				tooth_count += 1
			if instance.mesh != null and instance.mesh.get_blend_shape_count() > 0:
				morph_mesh_count += 1
		for child: Node in node.get_children():
			stack.push_back(child)
	var passed: bool = mesh_count == 32 and tooth_count == 26 and morph_mesh_count == 3
	print(JSON.stringify({"meshes": mesh_count, "teeth": tooth_count, "morph_meshes": morph_mesh_count, "passed": passed}))
	root.free()
	quit(0 if passed else 1)
