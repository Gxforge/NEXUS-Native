class_name WallScreen
extends Node3D
## Pantalla de pared: telemetría `CAM 04` o panel de fósforo local.
##
## La web dibuja estas pantallas en un canvas y lo usa como textura de un plano.
## En Godot se usa el mismo patrón con `SubViewport` + `ViewportTexture`, de modo
## que se pueden pintar con `_draw()` sin perder el aspecto de fósforo.

@export_enum("telemetry", "phosphor") var kind: String = "telemetry"
@export var screen_size := Vector2(2.36, 1.328)
@export var pixels := Vector2i(TelemetryModel.WIDTH, TelemetryModel.HEIGHT)
@export var emit_light := true

var model: TelemetryModel = TelemetryModel.new()
var display: PhosphorDisplay = PhosphorDisplay.new()
var viewport: SubViewport
var surface: ScreenSurface
var mesh: MeshInstance3D
var material: StandardMaterial3D


func _ready() -> void:
	if kind == "phosphor":
		pixels = Vector2i(PhosphorDisplay.WIDTH, PhosphorDisplay.HEIGHT)
		screen_size = Vector2(0.9, 0.45) if screen_size == Vector2(2.36, 1.328) else screen_size
	_build()


func _build() -> void:
	if viewport != null:
		return
	viewport = SubViewport.new()
	viewport.name = "Screen"
	viewport.size = pixels
	viewport.disable_3d = true
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	surface = ScreenSurface.new()
	surface.name = "Surface"
	surface.kind = ScreenSurface.Kind.PHOSPHOR if kind == "phosphor" else ScreenSurface.Kind.TELEMETRY
	surface.model = model
	surface.display = display
	surface.size = Vector2(pixels)
	viewport.add_child(surface)
	material = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_texture = viewport.get_texture()
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	material.no_depth_test = false
	if emit_light:
		material.emission_enabled = true
		material.emission_texture = viewport.get_texture()
		material.emission_energy_multiplier = 1.25
	var quad := QuadMesh.new()
	quad.size = screen_size
	mesh = MeshInstance3D.new()
	mesh.name = "Face"
	mesh.mesh = quad
	mesh.material_override = material
	mesh.extra_cull_margin = 1.0
	add_child(mesh)


## Muestra una muestra de telemetría. Devuelve `true` si la pantalla repintó.
func push_telemetry(time: float, grid: Dictionary, hp: float, distance: float,
		state: String, position: Vector3, intent: String, hits: int,
		aggression := 0.0) -> bool:
	if kind != "telemetry":
		return false
	_build()
	var updated := model.sample(time, grid, hp, distance, state, position, intent, hits, aggression)
	if updated:
		surface.queue_redraw()
	return updated


## Pinta un panel de fósforo (título, valor, subtítulo y traza).
func push_phosphor(title: String, value: String, sub: String, frac: float,
		accent := PhosphorDisplay.DEFAULT_ACCENT) -> bool:
	if kind != "phosphor":
		return false
	_build()
	display.paint(title, value, sub, frac, accent)
	surface.queue_redraw()
	return true


func cycle_page() -> int:
	var next := model.next_page()
	surface.queue_redraw()
	return next


func snapshot() -> Dictionary:
	if kind == "phosphor":
		return display.to_dict()
	return model.to_dict()


func restore(data: Dictionary) -> bool:
	if kind == "phosphor":
		return display.from_dict(data)
	return model.from_dict(data)


## Ventana de la pantalla en coordenadas de mundo (para raycasts de encuesta).
func face_transform() -> Transform3D:
	return mesh.global_transform if mesh != null else global_transform
