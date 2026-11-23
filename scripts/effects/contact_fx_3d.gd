class_name ContactFx3D
extends Node3D

@export var impact_amount: int = 24
@export var gas_amount: int = 48

var particles := GPUParticles3D.new()
var process_material := ParticleProcessMaterial.new()
var draw_mesh := QuadMesh.new()

func _ready() -> void:
	particles.name = "ContactParticles"
	particles.one_shot = true
	particles.explosiveness = 0.88
	particles.randomness = 0.72
	particles.visibility_aabb = AABB(Vector3(-3, -3, -3), Vector3(6, 6, 6))
	draw_mesh.size = Vector2(0.09, 0.09)
	particles.draw_pass_1 = draw_mesh
	particles.process_material = process_material
	add_child(particles)

func emit_impact(position: Vector3, normal: Vector3) -> void:
	global_position = position
	_configure(false, normal.normalized())
	particles.restart()

func emit_gas(position: Vector3, normal: Vector3) -> void:
	global_position = position
	_configure(true, normal.normalized())
	particles.restart()

func _configure(gas: bool, normal: Vector3) -> void:
	particles.amount = gas_amount if gas else impact_amount
	particles.lifetime = 1.8 if gas else 0.48
	process_material.direction = normal if not normal.is_zero_approx() else Vector3.UP
	process_material.spread = 48.0 if gas else 28.0
	process_material.initial_velocity_min = 0.25 if gas else 1.8
	process_material.initial_velocity_max = 0.8 if gas else 3.6
	process_material.gravity = Vector3(0, 0.32, 0) if gas else Vector3(0, -5.4, 0)
	process_material.scale_min = 0.55 if gas else 0.32
	process_material.scale_max = 1.8 if gas else 0.85
	process_material.color = Color(0.64, 0.72, 0.68, 0.28) if gas else Color(0.92, 0.66, 0.42, 0.9)
