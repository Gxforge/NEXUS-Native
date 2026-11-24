class_name ScreenSurface
extends Control
## Superficie de dibujo de las pantallas (sustituye al canvas 2D de la web).

enum Kind { TELEMETRY, PHOSPHOR }

var kind := Kind.TELEMETRY
var model: TelemetryModel = null
var display: PhosphorDisplay = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _font() -> Font:
	return ThemeDB.fallback_font


func _text(at: Vector2, content: String, size: int, color: Color, bold := false) -> void:
	var font := _font()
	if font == null:
		return
	draw_string(font, at, content, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
	if bold:
		draw_string(font, at + Vector2(1.0, 0.0), content, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


func _draw() -> void:
	if kind == Kind.TELEMETRY and model != null:
		_draw_telemetry()
	elif kind == Kind.PHOSPHOR and display != null:
		_draw_phosphor()


# --------------------------------------------------------------------------- #
func _draw_telemetry() -> void:
	var grid_entries: Array = model.values()
	var size := Vector2(TelemetryModel.WIDTH, TelemetryModel.HEIGHT)
	draw_rect(Rect2(Vector2.ZERO, size), Color("#09191c"))
	draw_rect(Rect2(0.0, 0.0, 1024.0, 64.0), Color("#193438"))
	_text(Vector2(30.0, 44.0), "NEXUS   /   CAM 04", 31, Color("#e2f8e9"), true)
	_text(Vector2(814.0, 42.0), model.status_label(_grid()), 24, TelemetryModel.INK)
	_text(Vector2(30.0, 101.0), model.title(), 23, TelemetryModel.ACCENT, true)
	for index in grid_entries.size():
		var entry: Array = grid_entries[index]
		var x := 30.0 + index * 333.0
		_text(Vector2(x, 143.0), str(entry[0]), 19, Color("#8facaa"))
		_text(Vector2(x, 194.0), str(entry[1]), 43, Color("#eaf2dd"), true)
	for column in 9:
		draw_rect(Rect2(32.0 + column * 118.0, 226.0, 1.0, 139.0), Color("#203a3a"))
	for row in 5:
		draw_rect(Rect2(32.0, 227.0 + row * 34.0, 950.0, 1.0), Color("#203a3a"))
	for series in 3:
		var points: Array[Vector2] = model.series_points(series)
		if points.size() > 1:
			draw_polyline(points, model.series_color(series), 3.0)
	_text(Vector2(31.0, 393.0), model.series_label() + model.buffer_label(), 19, Color("#8facaa"))
	_text(Vector2(32.0, 437.0), model.state_line(), 24, TelemetryModel.INK)
	_text(Vector2(32.0, 478.0), model.track_line(), 24, TelemetryModel.INK)
	_text(Vector2(32.0, 519.0), model.footer_line(), 22, TelemetryModel.ACCENT)
	_text(Vector2(32.0, 556.0), model.time_line(), 18, Color("#84a7a3"))


func _grid() -> Dictionary:
	return model._pending.get("grid", {}) as Dictionary


# --------------------------------------------------------------------------- #
func _draw_phosphor() -> void:
	var size := Vector2(PhosphorDisplay.WIDTH, PhosphorDisplay.HEIGHT)
	draw_rect(Rect2(Vector2.ZERO, size), PhosphorDisplay.BACKGROUND)
	draw_rect(Rect2(0.0, 0.0, 640.0, 52.0), PhosphorDisplay.HEADER)
	_text(Vector2(19.0, 35.0), display.title, 24, display.accent, true)
	_text(Vector2(20.0, 124.0), display.value, 57, PhosphorDisplay.VALUE, true)
	_text(Vector2(22.0, 165.0), display.sub, 24, PhosphorDisplay.SUB)
	for x in display.grid_columns():
		draw_rect(Rect2(x, 187.0, 1.0, 75.0), PhosphorDisplay.GRID)
	for y in display.grid_rows():
		draw_rect(Rect2(20.0, y, 600.0, 1.0), PhosphorDisplay.GRID)
	var points := display.trace_points()
	if points.size() > 1:
		draw_polyline(points, display.accent, 3.0)
	draw_rect(Rect2(20.0, 281.0, 600.0, 12.0), PhosphorDisplay.TRACK)
	draw_rect(Rect2(20.0, 281.0, 600.0 * display.fraction(), 12.0), display.accent)
