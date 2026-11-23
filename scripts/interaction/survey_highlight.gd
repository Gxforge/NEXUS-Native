class_name SurveyHighlight
extends Node

signal scan_finished(target: GeometryInstance3D)

@export var duration_s: float = 1.1
var target: GeometryInstance3D
var progress: float = 0.0
var _previous_overlay: Material
var _material := ShaderMaterial.new()

func _init() -> void:
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_add;
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform vec4 scan_color : source_color = vec4(0.06, 0.72, 1.0, 0.55);
void fragment() {
	float band = exp(-abs(UV.y - progress) * 28.0);
	float grid = step(0.92, fract(UV.x * 28.0)) + step(0.92, fract(UV.y * 28.0));
	ALBEDO = scan_color.rgb;
	EMISSION = scan_color.rgb * (0.35 + band * 1.8);
	ALPHA = scan_color.a * (0.16 + band * 0.72 + min(grid, 1.0) * 0.1);
}
"""
	_material.shader = shader
	set_process(false)

func begin(instance: GeometryInstance3D) -> bool:
	if instance == null:
		return false
	clear()
	target = instance
	progress = 0.0
	_previous_overlay = target.material_overlay
	target.material_overlay = _material
	_material.set_shader_parameter("progress", progress)
	set_process(true)
	return true

func _process(delta: float) -> void:
	advance(delta)

func advance(delta: float) -> void:
	if target == null:
		return
	progress = minf(1.0, progress + delta / maxf(duration_s, 0.001))
	_material.set_shader_parameter("progress", progress)
	if progress >= 1.0:
		var completed := target
		clear()
		scan_finished.emit(completed)

func clear() -> void:
	if target != null and is_instance_valid(target):
		target.material_overlay = _previous_overlay
	target = null
	_previous_overlay = null
	set_process(false)
