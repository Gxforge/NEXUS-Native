class_name ZoneMapView
extends Control

## Schematic 2D map of the laboratory. Zone footprints come from
## `data/zone_graph.json`; long Transit corridors are compressed so the core
## sectors stay readable.

const MARGIN := 12.0
const COMPRESS_ABOVE := 96.0
const COMPRESS_FACTOR := 0.02
const RANGE_MIN_Z := -118.0

var _entries: Array[Dictionary] = []
var _current: StringName = &""

func _ready() -> void:
	custom_minimum_size = Vector2(0, 260)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true

func configure(entries: Array, current: StringName) -> void:
	_entries = []
	for entry: Dictionary in entries:
		_entries.append(entry)
	_current = current
	queue_redraw()

func _compressed_z(value: float) -> float:
	if value <= COMPRESS_ABOVE:
		return value
	return COMPRESS_ABOVE + (value - COMPRESS_ABOVE) * COMPRESS_FACTOR

func _bounds() -> Rect2:
	var min_x := INF
	var max_x := -INF
	var min_z := INF
	var max_z := -INF
	for entry: Dictionary in _entries:
		var low: Vector2 = entry.get("min", Vector2.ZERO)
		var high: Vector2 = entry.get("max", Vector2.ZERO)
		min_x = minf(min_x, low.x)
		max_x = maxf(max_x, high.x)
		min_z = minf(min_z, _compressed_z(low.y))
		max_z = maxf(max_z, _compressed_z(high.y))
	if min_x == INF:
		return Rect2(0, 0, 1, 1)
	return Rect2(min_x, min_z, maxf(1.0, max_x - min_x), maxf(1.0, max_z - min_z))

func _to_canvas(world: Vector2, bounds: Rect2, area: Rect2) -> Vector2:
	var scale := minf(area.size.x / bounds.size.x, area.size.y / bounds.size.y)
	var origin := area.position + (area.size - bounds.size * scale) * 0.5
	return Vector2(
		origin.x + (world.x - bounds.position.x) * scale,
		origin.y + bounds.size.y * scale - (_compressed_z(world.y) - bounds.position.y) * scale
	)

func _draw() -> void:
	var area := Rect2(Vector2(MARGIN, MARGIN), size - Vector2(MARGIN, MARGIN) * 2.0)
	draw_rect(area, Color(0.01, 0.024, 0.03, 0.92), true)
	draw_rect(area, Color(0.16, 0.33, 0.35, 0.9), false, 1.0)
	if _entries.is_empty():
		return
	var bounds := _bounds()
	for entry: Dictionary in _entries:
		var low: Vector2 = entry.get("min", Vector2.ZERO)
		var high: Vector2 = entry.get("max", Vector2.ZERO)
		var top_left := _to_canvas(Vector2(low.x, high.y), bounds, area)
		var bottom_right := _to_canvas(Vector2(high.x, low.y), bounds, area)
		var rect := Rect2(top_left, bottom_right - top_left).abs()
		var zone_id: StringName = entry.get("id", &"")
		var is_current: bool = zone_id == _current
		var is_neighbor: bool = bool(entry.get("neighbor", false))
		var fill := Color(0.06, 0.13, 0.15, 0.95)
		var line := Color(0.3, 0.42, 0.45, 0.9)
		if is_neighbor:
			fill = Color(0.07, 0.19, 0.2, 0.95)
			line = Color(0.36, 0.66, 0.62, 0.95)
		if is_current:
			fill = Color(0.12, 0.42, 0.4, 0.96)
			line = Color(1.0, 0.86, 0.5, 1.0)
		draw_rect(rect, fill, true)
		draw_rect(rect, line, false, 2.0 if is_current else 1.0)
		if rect.size.x > 42.0 and rect.size.y > 14.0:
			var font := get_theme_default_font()
			var label := str(entry.get("label", zone_id)).to_upper()
			draw_string(font, rect.position + Vector2(4, minf(rect.size.y - 4.0, 14.0)), label,
				HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 6.0, 10,
				Color(0.85, 0.95, 0.94, 0.95) if is_current else Color(0.62, 0.78, 0.79, 0.9))
