class_name TelemetryModel
extends RefCounted
## Modelo de la pantalla de telemetría `CAM 04`.
##
## Port de `src/scene/TelemetryScreen.ts`: la web pinta en un canvas de 1024×576
## y muestrea el estado cada 0,35 s guardando 75 filas. Aquí se separa el modelo
## (qué se escribe, en qué página y con qué serie) del dibujo, que hace
## `scripts/ui/telemetry_surface.gd` con `_draw()`.

const WIDTH := 1024
const HEIGHT := 576
const SAMPLE_INTERVAL := 0.35
const HISTORY_LIMIT := 75
const PAGES := 3
const INK := Color("#a6e8da")
const ACCENT := Color("#e7ac6a")
const TITLES := ["W–01 · ESTACIÓN DE CAMPO", "BUS · DIAGNÓSTICO", "RASTREO · W–01"]
const SERIES_COLORS := [Color("#a6e8da"), Color("#e7ac6a"), Color("#94b0ff")]
const SERIES_LABELS := ["kW  /  °C  /  HP     ", "DIST m  /  AMENAZA %  /  HP     "]

var page := 0
var history: Array = []
var last_time := -1.0


func reset() -> void:
	page = 0
	history = []
	last_time = -1.0


func set_page(value: int) -> int:
	page = clampi(value, 0, PAGES - 1)
	return page


func next_page() -> int:
	return set_page((page + 1) % PAGES)


## Registra una muestra. Devuelve `false` si el paso se ha descartado por llegar
## antes de 0,35 s (la web no repinta la pantalla más rápido que eso).
func sample(time: float, grid: Dictionary, hp: float, distance: float, state: String,
		position: Vector3, intent: String, hits: int, aggression := 0.0) -> bool:
	if last_time >= 0.0 and time >= last_time and time - last_time < SAMPLE_INTERVAL:
		return false
	if time < last_time:
		history = []
	last_time = time
	history.append([
		float(grid.get("load", 0.0)),
		float(grid.get("temp", 0.0)),
		hp,
		distance,
		aggression * 100.0,
	])
	if history.size() > HISTORY_LIMIT:
		history.pop_front()
	_pending = {
		"time": time,
		"grid": grid,
		"hp": hp,
		"distance": distance,
		"state": state,
		"position": position,
		"intent": intent,
		"hits": hits,
		"aggression": aggression,
	}
	return true

var _pending: Dictionary = {}


## Filas `[clave, valor]` de la página activa (contrato de la web).
func values() -> Array:
	var grid: Dictionary = _pending.get("grid", {})
	if page == 2:
		return [
			["ACTIVIDAD", str(_pending.get("state", ""))],
			["AMENAZA", "%d %%" % int(round(float(_pending.get("aggression", 0.0)) * 100.0))],
			["CONTACTOS", str(_pending.get("hits", 0))],
		]
	if page == 1:
		return [
			["CAPACIDAD", "%d kW" % int(grid.get("capacity", 0))],
			["TÉRMICA", "%.1f °C" % float(grid.get("temp", 0.0))],
			["CARGA", "%d kW" % int(grid.get("load", 0))],
		]
	return [
		["INTEGRIDAD", "%d %%" % int(round(float(_pending.get("hp", 0.0))))],
		["DISTANCIA", "%.1f m" % float(_pending.get("distance", 0.0))],
		["CONSUMO", "%d kW" % int(grid.get("load", 0))],
	]


func title() -> String:
	return TITLES[clampi(page, 0, TITLES.size() - 1)]


## Índices de las tres series de la gráfica según la página.
func series_indices() -> Array:
	return [3, 4, 2] if page == 2 else ([0, 1, 2] if page == 1 or page == 0 else [0, 1, 2])


func series_color(index: int) -> Color:
	return SERIES_COLORS[clampi(index, 0, SERIES_COLORS.size() - 1)]


## Puntos `[x, y]` del canvas para la serie `index` (contrato de la web).
func series_points(index: int) -> Array[Vector2]:
	var points: Array[Vector2] = []
	var column := int(Array(series_indices())[index])
	for row in history.size():
		var value: float = float((history[row] as Array)[column])
		var x := 980.0 - (history.size() - 1 - row) * 12.7
		var y := 361.0 - minf(138.0, value) * 0.94
		points.append(Vector2(x, y))
	return points


func status_label(grid: Dictionary) -> String:
	return "●  UPS" if bool(grid.get("tripped", false)) else "●  LIVE"


func buffer_label() -> String:
	return "BUFFER %d/%d" % [history.size(), HISTORY_LIMIT]


func series_label() -> String:
	return SERIES_LABELS[1] if page == 2 else SERIES_LABELS[0]


func state_line() -> String:
	return "> subject.state = %s    hits = %d" % [str(_pending.get("state", "")), int(_pending.get("hits", 0))]


func track_line() -> String:
	var grid: Dictionary = _pending.get("grid", {})
	if page == 1:
		var feeds := ""
		var fans := ""
		for value in grid.get("feeds", []):
			feeds += "1" if bool(value) else "0"
		for value in grid.get("fans", []):
			fans += "1" if bool(value) else "0"
		return "> feeds = %s    cooling = %s" % [feeds, fans]
	var position: Vector3 = _pending.get("position", Vector3.ZERO)
	return "> track.xyz = [%.1f, %.1f, %.1f]" % [position.x, position.y, position.z]


func footer_line() -> String:
	var grid: Dictionary = _pending.get("grid", {})
	var tail := ("> relay: " + str(grid.get("cause", "")).left(44)) if page == 1 \
		else ("> intent: " + str(_pending.get("intent", "")))
	return tail


func time_line() -> String:
	return "T+%.1f s     /     REGISTRO CONTINUO" % float(_pending.get("time", 0.0))


func to_dict() -> Dictionary:
	return {"page": page, "history": history.duplicate(true), "time": last_time}


func from_dict(data: Dictionary) -> bool:
	if data.is_empty():
		return false
	set_page(int(data.get("page", 0)))
	history = []
	var raw: Variant = data.get("history", [])
	if raw is Array:
		for row in raw:
			if row is Array:
				history.append((row as Array).duplicate())
		while history.size() > HISTORY_LIMIT:
			history.pop_front()
	last_time = float(data.get("time", -1.0))
	return true
