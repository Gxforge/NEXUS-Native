extends SceneTree
func _init() -> void:
	var packed := load("res://assets/generated/w01_eyes.glb") as PackedScene
	if packed == null: quit(1); return
	var root := packed.instantiate()
	var eyes: int = 0
	var meshes: int = 0
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node.name == "primary-eye" or node.name.begins_with("secondary-eye-"): eyes += 1
		if node is MeshInstance3D: meshes += 1
		for child: Node in node.get_children(): stack.push_back(child)
	var passed := eyes == 7 and meshes == 56
	print(JSON.stringify({"eyes": eyes, "meshes": meshes, "passed": passed}))
	root.free(); quit(0 if passed else 1)
