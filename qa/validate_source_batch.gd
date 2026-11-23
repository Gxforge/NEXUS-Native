extends SceneTree
const ASSETS: Array[String] = ["workshop_pods", "vault", "transit", "larva_0", "larva_1", "larva_2", "instrument_0", "instrument_1", "instrument_2", "vehicle", "effects", "glove_press", "glove_drawer", "glove_grip", "glove_lamp", "glove_flat", "glove_round", "glove_box", "telemetry_screen", "display", "cockpit", "touch_rig_assets", "laboratory_all_sectors"]
func _init() -> void:
	var results: Dictionary = {}
	var passed: bool = true
	for asset: String in ASSETS:
		var scene: PackedScene = load("res://assets/generated/source-batch/%s.glb" % asset) as PackedScene
		var meshes: int = 0
		if scene != null:
			var root: Node = scene.instantiate()
			var stack: Array[Node] = [root]
			while not stack.is_empty():
				var node: Node = stack.pop_back()
				if node is MeshInstance3D: meshes += 1
				for child: Node in node.get_children(): stack.push_back(child)
			root.free()
		results[asset] = meshes
		passed = passed and meshes > 0
	print(JSON.stringify({"assets": results, "passed": passed}))
	quit(0 if passed else 1)
