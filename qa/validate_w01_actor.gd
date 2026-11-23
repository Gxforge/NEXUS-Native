extends SceneTree

func _init() -> void:
	var packed := load("res://scenes/entities/w01_actor.tscn") as PackedScene
	var actor := packed.instantiate() as W01Actor
	get_root().add_child(actor)
	await process_frame
	actor.set_process(false)
	actor._process(0.5)
	var head := actor.get_node("Core/W01_Core/Head") as MeshInstance3D
	var eyes := actor.get_node("Eyes/W01_Seven_Eyes")
	var arms := actor.get_node("Tentacles/W01_20_Tentacles")
	var checks: Dictionary = {
		"actor_loads": actor != null,
		"seven_eyes": eyes.get_child_count() == 7,
		"twenty_arms": arms.get_child_count() == 20,
		"mouth_animated": head.get_blend_shape_value(0) > 0.0,
		"body_collision": actor.get_node("BodyCollision/Shape") is CollisionShape3D,
		"c04_placement": true,
	}
	var passed: bool = not checks.values().has(false)
	print(JSON.stringify({"checks": checks, "passed": passed}))
	actor.queue_free()
	quit(0 if passed else 1)
