class_name NexusPlayer
extends CharacterBody3D

const SPEED := 4.0

func _physics_process(delta: float) -> void:
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	velocity.x = input.x * SPEED
	velocity.z = input.y * SPEED
	velocity.y = 0.0 if is_on_floor() else velocity.y - 9.8 * delta
	move_and_slide()
