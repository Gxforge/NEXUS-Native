class_name PhosphorDisplay
extends RefCounted
## Pantalla local de fósforo (port de `Display` de `Displays.ts`).
##
## La web pinta en un canvas de 640×320 con una traza de 72 muestras. Aquí se
## reproduce el modelo: el título con acento, el valor grande, el subtítulo, la
## rejilla de 16×4 y la traza; el dibujo lo hace `scripts/ui/phosphor_surface.gd`.

const WIDTH := 640
const HEIGHT := 320
const HISTORY_LIMIT := 72
const BACKGROUND := Color("#06171d")
const HEADER := Color("#19343b")
const GRID := Color("#183136")
const VALUE := Color("#e3efe4")
const SUB := Color("#9fbdc4")
const DEFAULT_ACCENT := Color("#89f2cb")
const TRACK := Color("#263e44")

var history: Array[float] = []
var last := ""
var title := ""
var value := ""
var sub := ""
var accent := DEFAULT_ACCENT


func reset() -> void:
	history = []
	last = ""
	title = ""
	value = ""
	sub = ""
	accent = DEFAULT_ACCENT


## Registra una muestra y deja la pantalla lista para pintar.
func paint(new_title: String, new_value: String, new_sub: String, frac: float,
		new_accent := DEFAULT_ACCENT) -> void:
	history.append(clampf(frac, -1.0, 2.0))
	if history.size() > HISTORY_LIMIT:
		history.pop_front()
	title = new_title
	value = new_value
	sub = new_sub
	accent = new_accent
	last = "%s|%s|%s" % [new_title, new_value, new_sub]


func fraction() -> float:
	return clampf(history[history.size() - 1], 0.0, 1.0) if not history.is_empty() else 0.0


## Puntos de la traza dentro de su marco (x 20..620, y 258 arriba, +66 abajo).
func trace_points() -> Array[Vector2]:
	var points: Array[Vector2] = []
	for index in history.size():
		var x := 620.0 - (history.size() - 1 - index) * 8.4
		var y := 258.0 - 66.0 * clampf(history[index], 0.0, 1.0)
		points.append(Vector2(x, y))
	return points


## Doce divisiones verticales y cuatro horizontales, como el canvas de la web.
func grid_columns() -> Array[float]:
	var columns: Array[float] = []
	var x := 20.0
	while x < 624.0:
		columns.append(x)
		x += 38.0
	return columns


func grid_rows() -> Array[float]:
	var rows: Array[float] = []
	var y := 187.0
	while y < 265.0:
		rows.append(y)
		y += 20.0
	return rows


func to_dict() -> Dictionary:
	return {"history": history.duplicate(), "last": last}


func from_dict(data: Dictionary) -> bool:
	if data.is_empty():
		return false
	var raw: Variant = data.get("history", [])
	history = []
	if raw is Array:
		for entry in raw:
			history.append(float(entry))
		while history.size() > HISTORY_LIMIT:
			history.pop_front()
	last = str(data.get("last", ""))
	return true
