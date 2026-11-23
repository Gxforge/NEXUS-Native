extends SceneTree

func _init() -> void:
	var fx := ContactFx3D.new()
	get_root().add_child(fx)
	await process_frame
	fx.emit_impact(Vector3(1, 2, 3), Vector3.FORWARD)
	var impact_ok: bool = fx.particles.amount == fx.impact_amount and is_equal_approx(fx.particles.lifetime, 0.48)
	var impact_position_ok: bool = fx.global_position == Vector3(1, 2, 3)
	fx.emit_gas(Vector3(-2, 1, 4), Vector3.UP)
	var gas_ok: bool = fx.particles.amount == fx.gas_amount and is_equal_approx(fx.particles.lifetime, 1.8)
	var material_ok: bool = fx.particles.process_material == fx.process_material and fx.particles.draw_pass_1 == fx.draw_mesh
	var passed: bool = impact_ok and impact_position_ok and gas_ok and material_ok
	print(JSON.stringify({"impact": impact_ok, "position": impact_position_ok, "gas": gas_ok, "material": material_ok, "passed": passed}))
	fx.queue_free()
	quit(0 if passed else 1)
