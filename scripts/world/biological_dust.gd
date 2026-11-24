class_name BiologicalDust
extends GPUParticles3D
## Polvo biológico en suspensión (port de `Effects.ts`).
##
## La web mantiene 170 puntos en una caja de 18 × 7,2 × 15 m que suben a
## 0,08–0,26 m/s con una deriva senoidal, dibujados con una textura radial
## aditiva de color `#a88e87`. Aquí la caja viaja con el jugador (`local_coords`)
## para que el polvo siempre rodee la cámara.

const SPREAD := 170
const TINT := Color("#a88e87")


func _ready() -> void:
	name = "BiologicalDust"
	amount = SPREAD
	lifetime = 9.0
	preprocess = 4.0
	local_coords = true
	visibility_aabb = AABB(Vector3(-10.0, -1.0, -9.0), Vector3(20.0, 12.0, 18.0))
	process_material = _process_material()
	draw_pass_1 = _dust_mesh()


func _process_material() -> ParticleProcessMaterial:
	var material := ParticleProcessMaterial.new()
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	material.emission_box_extents = Vector3(9.0, 3.2, 7.5)
	material.direction = Vector3(0.0, 1.0, 0.0)
	material.spread = 12.0
	material.initial_velocity_min = 0.08
	material.initial_velocity_max = 0.26
	material.gravity = Vector3(0.0, 0.02, 0.0)
	material.scale_min = 0.7
	material.scale_max = 1.4
	material.color = TINT
	return material


func _dust_mesh() -> QuadMesh:
	var quad := QuadMesh.new()
	quad.size = Vector2(0.055, 0.055)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.albedo_color = Color(TINT.r, TINT.g, TINT.b, 0.55)
	material.albedo_texture = _sprite()
	material.disable_receive_shadows = true
	quad.material = material
	return quad


## Punto radial suave, como el `CanvasTexture` de 32 px de la web.
func _sprite() -> ImageTexture:
	var size := 32
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in size:
		for x in size:
			var dx := (float(x) + 0.5) / float(size) * 2.0 - 1.0
			var dy := (float(y) + 0.5) / float(size) * 2.0 - 1.0
			var distance := sqrt(dx * dx + dy * dy)
			var alpha := clampf(1.0 - distance, 0.0, 1.0)
			alpha = alpha * alpha * 0.62
			image.set_pixel(x, y, Color(1.0, 0.98, 0.94, alpha))
	return ImageTexture.create_from_image(image)
