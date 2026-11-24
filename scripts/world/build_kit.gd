class_name BuildKit
extends RefCounted
## Piezas de construcción de la web (`Infrastructure.ts` y `Workshop.ts`).
##
## La versión web monta toda la nave con un puñado de primitivas —`block`,
## `bar`, `drum`, `ring`, `tube`, `shell`, `plate`— más rótulos de letras y
## luminarias. Este kit replica esas mismas piezas y la paleta de materiales
## para que el aspecto nativo coincida con el original.

const METAL := Color("#53686c")
const GRAPHITE := Color("#29383d")
const BRONZE := Color("#a16f45")
const WHITE := Color("#e6e6db")
const GLOW := Color("#72f9e5")
const AMBER := Color("#ffae69")
const SEAL := Color("#1a2b30")
const STEEL := Color("#8fa4a8")
const WARM := Color("#ffe4c1")

static var _materials: Dictionary = {}


## Material estándar de la paleta (compartido entre piezas).
static func material(color: Color, metallic := 0.4, roughness := 0.48) -> StandardMaterial3D:
	var key := "%s|%.2f|%.2f" % [color.to_html(), metallic, roughness]
	if _materials.has(key):
		return _materials[key]
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = roughness
	_materials[key] = material
	return material


## Material emisivo plano (tiras, testigos y difusores de la web).
static func emissive(color: Color, energy := 1.0) -> StandardMaterial3D:
	var key := "emissive|%s|%.2f" % [color.to_html(), energy]
	if _materials.has(key):
		return _materials[key]
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	_materials[key] = material
	return material


static func glass(opacity := 0.035) -> StandardMaterial3D:
	var key := "glass|%.2f" % opacity
	if _materials.has(key):
		return _materials[key]
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("#99e5d6")
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color.a = opacity
	material.roughness = 0.09
	material.metallic = 0.0
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_materials[key] = material
	return material


static func liquid(opacity := 0.058) -> StandardMaterial3D:
	var key := "liquid|%.2f" % opacity
	if _materials.has(key):
		return _materials[key]
	var material := StandardMaterial3D.new()
	# `0x42d66d` con `opacity` muy baja: el líquido de los vasos de la web.
	material.albedo_color = Color(0.259, 0.839, 0.427, opacity)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.roughness = 0.22
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	_materials[key] = material
	return material


# --------------------------------------------------------------------------- #
# piezas
# --------------------------------------------------------------------------- #
## Caja (`block` de la web).
static func block(parent: Node3D, material: Material, x: float, y: float, z: float,
		w: float, h: float, d: float, node_name := "") -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(w, h, d)
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = Vector3(x, y, z)
	if not node_name.is_empty():
		instance.name = node_name
	parent.add_child(instance)
	return instance


## Cilindro (`drum` de la web); `face` lo tumba sobre el eje Z.
static func drum(parent: Node3D, material: Material, x: float, y: float, z: float,
		radius: float, height: float, face := false, segments := 32) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = segments
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = Vector3(x, y, z)
	if face:
		instance.rotation.x = PI * 0.5
	parent.add_child(instance)
	return instance


## Esfera pequeña (burbujas del líquido, testigos y remates).
static func bead(parent: Node3D, material: Material, x: float, y: float, z: float,
		radius: float, segments := 8) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = segments
	mesh.rings = maxi(4, segments / 2)
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = Vector3(x, y, z)
	parent.add_child(instance)
	return instance


## Anillo (`ring` de la web).
static func ring(parent: Node3D, material: Material, x: float, y: float, z: float,
		radius: float, thickness: float, flat := false) -> MeshInstance3D:
	var mesh := TorusMesh.new()
	mesh.inner_radius = maxf(radius - thickness, 0.01)
	mesh.outer_radius = radius + thickness
	mesh.rings = 48
	mesh.ring_segments = 8
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = Vector3(x, y, z)
	if not flat:
		instance.rotation.x = PI * 0.5
	parent.add_child(instance)
	return instance


## Barra entre dos puntos (`bar` de la web).
##
## La transformación se compone a mano (sin `look_at_from_position`) para que la
## pieza quede bien colocada aunque el padre aún no esté dentro del árbol.
static func bar(parent: Node3D, material: Material, from: Vector3, to: Vector3,
		thickness: float, height := -1.0) -> MeshInstance3D:
	var length := from.distance_to(to)
	if length <= 0.0001:
		return null
	var h := thickness if height < 0.0 else height
	var instance := block(parent, material, 0.0, 0.0, 0.0, thickness, h, length)
	var direction := (to - from).normalized()
	var up := Vector3.UP if absf(direction.dot(Vector3.UP)) < 0.99 else Vector3.RIGHT
	var right := up.cross(direction).normalized()
	var top := direction.cross(right).normalized()
	instance.transform = Transform3D(Basis(right, top, direction), (from + to) * 0.5)
	return instance


## Rótulo de letras de la fachada (`plaque` / `lettering` de la web).
static func plaque(parent: Node3D, title: String, subtitle: String, width: float,
		height: float, x: float, y: float, z: float, yaw := 0.0,
		tint := WHITE) -> Node3D:
	var root := Node3D.new()
	root.name = "Plaque_" + title.replace(" ", "_").replace("/", "_")
	root.position = Vector3(x, y, z)
	root.rotation.y = yaw
	parent.add_child(root)
	if not subtitle.is_empty():
		block(root, material(GRAPHITE, 0.5, 0.55), 0.0, 0.0, 0.02,
			width * 0.98, height * 0.46, 0.06)
	var letters := Label3D.new()
	letters.text = title
	letters.font_size = 96
	letters.pixel_size = height * (0.34 if not subtitle.is_empty() else 0.5) / 96.0
	letters.modulate = tint
	letters.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	letters.no_depth_test = false
	letters.position = Vector3(0.0, height * 0.17 if not subtitle.is_empty() else 0.0, 0.06)
	root.add_child(letters)
	if not subtitle.is_empty():
		var sub := Label3D.new()
		sub.text = subtitle
		sub.font_size = 48
		sub.pixel_size = height * 0.14 / 48.0
		sub.modulate = Color("#9fd8cf")
		sub.position = Vector3(0.0, -height * 0.22, 0.06)
		root.add_child(sub)
	return root


## Luminaria de techo con difusor y luz real (`luminaire` de la web).
static func luminaire(parent: Node3D, x: float, y: float, z: float, width := 3.2,
		tint := WARM, with_light := true) -> Node3D:
	var root := Node3D.new()
	root.name = "Luminaire"
	root.position = Vector3(x, y, z)
	parent.add_child(root)
	block(root, material(METAL, 0.5, 0.4), 0.0, 0.1, 0.0, width, 0.18, 0.35)
	block(root, emissive(tint, 1.6), 0.0, -0.02, 0.0, width * 0.97, 0.08, 0.33)
	if with_light:
		var light := OmniLight3D.new()
		light.light_color = tint
		light.light_energy = 3.6
		light.omni_range = maxf(7.0, width * 2.8)
		light.position = Vector3(0.0, -0.5, 0.0)
		light.shadow_enabled = false
		root.add_child(light)
	return root


## Armario técnico con puerta, tiradores y testigos (mobiliario base de la web).
static func cabinet(parent: Node3D, x: float, z: float, yaw := 0.0, width := 1.6,
		height := 2.4, depth := 0.8, doors := 2, node_name := "") -> Node3D:
	var root := Node3D.new()
	root.name = node_name if not node_name.is_empty() else "Cabinet"
	root.position = Vector3(x, height * 0.5, z)
	root.rotation.y = yaw
	parent.add_child(root)
	block(root, material(GRAPHITE, 0.55, 0.42), 0.0, 0.0, 0.0, width, height, depth)
	block(root, material(METAL, 0.5, 0.38), 0.0, height * 0.5 - 0.06, 0.0,
		width * 1.02, 0.12, depth * 1.04)
	for index in doors:
		var offset := (float(index) - float(doors - 1) * 0.5) * (width / float(doors))
		block(root, material(STEEL, 0.6, 0.34), offset, 0.0, depth * 0.5 + 0.02,
			width / float(doors) - 0.06, height * 0.82, 0.05)
		block(root, material(BRONZE, 0.7, 0.3), offset + width / float(doors) * 0.28,
			-0.05, depth * 0.5 + 0.08, 0.06, 0.42, 0.06)
		block(root, emissive(GLOW, 1.2), offset - width / float(doors) * 0.26,
			height * 0.3, depth * 0.5 + 0.06, 0.07, 0.07, 0.03)
		block(root, emissive(AMBER, 1.1), offset - width / float(doors) * 0.26,
			height * 0.24, depth * 0.5 + 0.06, 0.05, 0.05, 0.03)
	return root


## Suelo del laboratorio: la textura de `materials.ts` (`createFloorTexture`),
## repetida cada 12 m (la web la repite 6 veces sobre 72 m).
static func floor_material(uv_scale := Vector2.ONE) -> StandardMaterial3D:
	var key := "%.2f_%.2f" % [uv_scale.x, uv_scale.y]
	if _floor_materials.has(key):
		return _floor_materials[key] as StandardMaterial3D
	var material := StandardMaterial3D.new()
	material.albedo_texture = load("res://assets/textures/floor_dark.png")
	material.albedo_color = Color("#ffffff")
	material.roughness = 0.6
	material.metallic = 0.26
	material.metallic_specular = 0.55
	material.uv1_scale = Vector3(uv_scale.x, uv_scale.y, 1.0)
	# El plano se dibuja por ambas caras: la losa se ve desde el interior de la sala.
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	_floor_materials[key] = material
	return material


static var _floor_materials := {}


## Losa de suelo a la medida de la sala, con la textura del laboratorio.
static func floor_slab(parent: Node3D, center: Vector3, size: Vector2,
		height := 0.0) -> MeshInstance3D:
	var plane := PlaneMesh.new()
	plane.size = size
	var instance := MeshInstance3D.new()
	instance.name = "FloorSlab"
	instance.mesh = plane
	instance.material_override = floor_material(Vector2(size.x / 12.0, size.y / 12.0))
	instance.position = Vector3(center.x, height, center.z)
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)
	return instance


## Rejilla de suelo con líneas emisivas (el "grid" del laboratorio de la web).
static func floor_grid(parent: Node3D, center: Vector3, size: Vector2, step := 3.0,
		tint := Color("#20343a"), y := 0.02) -> Node3D:
	var root := Node3D.new()
	root.name = "FloorGrid"
	parent.add_child(root)
	var half := size * 0.5
	var x := -half.x
	while x <= half.x:
		block(root, emissive(tint, 1.0), center.x + x, center.y + y, center.z,
			0.045, 0.01, size.y)
		x += step
	var z := -half.y
	while z <= half.y:
		block(root, emissive(tint, 1.0), center.x, center.y + y, center.z + z,
			size.x, 0.01, 0.045)
		z += step
	return root
