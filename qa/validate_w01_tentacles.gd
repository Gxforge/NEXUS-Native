extends SceneTree
func _init() -> void:
	var packed: PackedScene = load("res://assets/generated/w01_tentacles.glb") as PackedScene
	if packed == null: quit(1); return
	var root: Node = packed.instantiate()
	var arms: int = 0
	var cups: int = 0
	var centers: int = 0
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node.name.begins_with("arm-") and node.name.count("-") == 1: arms += 1
		if node.name.begins_with("cup-"): cups += 1
		if node.name.begins_with("center-"): centers += 1
		for child: Node in node.get_children(): stack.push_back(child)
	var passed: bool = arms == 20 and cups == 87 and centers == 87
	print(JSON.stringify({"arms": arms, "cups": cups, "centers": centers, "passed": passed}))
	root.free(); quit(0 if passed else 1)
