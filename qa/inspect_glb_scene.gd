extends SceneTree
func _initialize() -> void: call_deferred("_inspect")
func _inspect() -> void:
	var p := load("res://assets/generated/source-batch/laboratory_all_sectors.glb") as PackedScene
	var s := p.get_state()
	print("nodes=", s.get_node_count(), " rootType=", s.get_node_type(0), " rootName=", s.get_node_name(0), " rootPath=", s.get_node_path(0))
	for i in range(0, 30): print("S", i, " path=", s.get_node_path(i), " type=", s.get_node_type(i), " name=", s.get_node_name(i), " parent=", s.get_node_path(i))
	var r := p.instantiate()
	print("INST ", r.name, " class=", r.get_class(), " children=", r.get_child_count())
	_dump(r, 0)
	quit()
func _dump(n: Node, d: int) -> void:
	if d > 2: return
	print(" " .repeat(d), n.name, " type=", n.get_class(), " children=", n.get_child_count())
	for c in n.get_children(): _dump(c, d + 1)
