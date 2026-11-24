class_name OperationsPanel
extends Node
## Cuadro eléctrico y CCTV del área técnica.
##
## Port de la lógica de `src/scene/Operations.ts` (943 líneas, casi todas
## geometría y pantallas). Aquí viven los contratos que sí son de juego:
## declaración de circuitos, selección de zona/derivación, interruptores,
## límites eco, páginas de contador, informes del panel maestro, niveles de
## iluminación y el selector de las diez cámaras de vigilancia.

signal selection_changed(zone: String, circuit: String)
signal circuit_toggled(circuit: String, on: bool)
signal camera_bank_changed(bank: int)

const INVERTER_COUNT := 12
const EXTRACTOR_COUNT := 4
const CAMERA_COUNT := 10
const CAMERA_WINDOW := 6
const BRIGHTNESS_LEVELS := [1.0, 0.55, 0.2]
const REPORT_PAGES := 5

## Cámaras de la web: nombre, posición y punto de mira.
const CAMERAS := [
	{"name": "OBSERVACIÓN", "position": Vector3(3.8, 6.39, 32.4), "look": Vector3(0, 2.5, 22)},
	{"name": "ARCHIVO", "position": Vector3(-17, 7.85, -23), "look": Vector3(-22, 1, -32)},
	{"name": "TURBINAS", "position": Vector3(11, 7.89, -17), "look": Vector3(20, 3, -34)},
	{"name": "BÓVEDA", "position": Vector3(23.8, 7.92, -29.3), "look": Vector3(17, 2.6, -37.8)},
	{"name": "GALERÍA", "position": Vector3(19, 7.2, -42), "look": Vector3(18, 2, -72)},
	{"name": "HIDRÁULICA", "position": Vector3(10.5, 7.18, -57), "look": Vector3(3.5, 2, -63)},
	{"name": "REGISTROS", "position": Vector3(26.4, 7.18, -77), "look": Vector3(35, 1.3, -82)},
	{"name": "CRIOTECA", "position": Vector3(20, 7.2, -101), "look": Vector3(18, 1.25, -105)},
	{"name": "ELECTRICIDAD", "position": Vector3(24.3, 8.02, 56.2), "look": Vector3(24, 2.5, 67.7)},
	{"name": "VIGILANCIA", "position": Vector3(-31.4, 8.01, 55.4), "look": Vector3(-26, 2.6, 66.8)},
]

var grid: PowerGrid
var zone_index := 0
var device_index := 0
var bank := 0
var light_mode := 0
var report := 0
var pages: Array[int] = []
var limited: Array[bool] = []


func _init(power: PowerGrid = null) -> void:
	grid = power
	pages.resize(INVERTER_COUNT)
	pages.fill(0)
	limited.resize(INVERTER_COUNT)
	limited.fill(false)
	if grid != null:
		declare_circuits()


func _ready() -> void:
	add_to_group(&"operations_panel")


## Circuitos que la web declara al construir el área técnica.
func declare_circuits() -> void:
	if grid == null:
		return
	for index in INVERTER_COUNT:
		grid.register_circuit("Generación", "INV %d" % (index + 1), 0.0)
	for index in EXTRACTOR_COUNT:
		grid.register_circuit("Turbinas", "Extractor %d" % (index + 1), 3.0)
	grid.register_circuit("Archivo", "Cargador", 0.0)
	grid.register_circuit("Crioteca", "Analizador", 0.0)
	grid.register_circuit("Laboratorio 01", "Luz de vía", 5.6)


# --------------------------------------------------------------------------- #
# geografía de la instalación
# --------------------------------------------------------------------------- #
## Zona de iluminación de un punto, tal cual `Operations.lightZone`.
func light_zone(point: Vector3) -> String:
	if point.z > 70.0:
		return "Axial"
	if point.z > 44.0 and point.x > 17.0:
		return "Electricidad"
	if point.z > 52.0 and point.x < -17.0:
		return "Vigilancia"
	if point.z >= -14.0:
		return "Contención"
	if point.z >= -38.0:
		return "Archivo" if point.x < 0.0 else "Turbinas"
	if point.z < -96.0:
		return "Crioteca"
	if point.x < 14.0:
		return "Hidráulica"
	if point.x > 22.0:
		return "Registros"
	return "Galería"


## Sala técnica en la que está el jugador (`Operations.area`).
func area(x: float, z: float) -> String:
	if z <= 44.2 or z >= 70.0 or absf(x) <= 17.4:
		return ""
	if x > 0.0:
		return "Electricidad"
	if z > 52.2:
		return "Vigilancia"
	return ""


# --------------------------------------------------------------------------- #
# selección
# --------------------------------------------------------------------------- #
func zones() -> Array[String]:
	var result: Array[String] = []
	if grid == null:
		return result
	for circuit in grid.circuits:
		var zone := str(circuit.get("zone", ""))
		if not result.has(zone):
			result.append(zone)
	return result


func selected_zone() -> String:
	var list := zones()
	if list.is_empty():
		return ""
	return list[zone_index % list.size()]


func lines_of(zone: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if grid == null:
		return result
	for circuit in grid.circuits:
		if str(circuit.get("zone", "")) == zone:
			result.append(circuit)
	return result


func selected_lines() -> Array[Dictionary]:
	return lines_of(selected_zone())


func selected_circuit() -> Dictionary:
	var lines := selected_lines()
	if lines.is_empty():
		return {}
	return lines[device_index % lines.size()]


# --------------------------------------------------------------------------- #
# interruptores
# --------------------------------------------------------------------------- #
## Enciende o apaga una derivación, arrastrando alimentadores y extractores.
func branch(circuit: Dictionary, on: bool) -> bool:
	if circuit.is_empty() or bool(circuit.get("locked", false)):
		return false
	circuit["on"] = on
	var name := str(circuit.get("name", ""))
	var index := _trailing_number(name) - 1
	if str(circuit.get("zone", "")) == "Generación":
		grid.set_feed(index, on)
	elif name.begins_with("Extractor"):
		grid.set_fan(index, on)
	circuit_toggled.emit(name, on)
	return true


## Mismos identificadores de mando que la web.
func handle(id: StringName) -> bool:
	if grid == null:
		return false
	match id:
		&"zoneNext":
			zone_index += 1
			device_index = 0
			report = 3
			selection_changed.emit(selected_zone(), str(selected_circuit().get("name", "")))
			return true
		&"deviceNext":
			device_index += 1
			report = 4
			selection_changed.emit(selected_zone(), str(selected_circuit().get("name", "")))
			return true
		&"zoneSwitch":
			var lines := selected_lines()
			var any_off := false
			for circuit in lines:
				if not bool(circuit.get("on", true)):
					any_off = true
					break
			for circuit in lines:
				branch(circuit, any_off)
			report = 3
			return true
		&"ecoMaster":
			var selected := selected_circuit()
			if str(selected.get("zone", "")) == "Generación":
				var index := _trailing_number(str(selected.get("name", ""))) - 1
				limited[index] = not limited[index]
				grid.set_limit(index, limited[index])
			report = 4
			return true
		&"branchSwitch":
			var target := selected_circuit()
			if not target.is_empty():
				branch(target, not bool(target.get("on", true)))
			report = 4
			return true
		&"report":
			report = (report + 1) % REPORT_PAGES
			return true
		&"illum":
			light_mode = (light_mode + 1) % BRIGHTNESS_LEVELS.size()
			grid.brightness = float(BRIGHTNESS_LEVELS[light_mode])
			return true
		&"camNext":
			_set_bank(bank + 4)
			return true
		&"camPrev":
			_set_bank(bank + 6)
			return true
	if str(id).begins_with("feed"):
		var feed_index := _trailing_number(str(id)) - 1
		if feed_index >= 0 and feed_index < grid.feeds.size():
			grid.cycle_feed(feed_index)
			return true
		return false
	if str(id).begins_with("limit"):
		var limit_index := _trailing_number(str(id)) - 1
		if limit_index >= 0 and limit_index < limited.size():
			limited[limit_index] = not limited[limit_index]
			grid.set_limit(limit_index, limited[limit_index])
			return true
		return false
	if str(id).begins_with("meter"):
		var meter_index := _trailing_number(str(id)) - 1
		if meter_index >= 0 and meter_index < pages.size():
			pages[meter_index] = (pages[meter_index] + 1) % 4
			return true
		return false
	return false


func _set_bank(value: int) -> void:
	bank = posmod(value, CAMERA_COUNT)
	camera_bank_changed.emit(bank)


func _trailing_number(text: String) -> int:
	var digits := ""
	for index in range(text.length() - 1, -1, -1):
		var character := text[index]
		if character >= "0" and character <= "9":
			digits = character + digits
		else:
			break
	return int(digits) if not digits.is_empty() else 0


# --------------------------------------------------------------------------- #
# sincronización con la red
# --------------------------------------------------------------------------- #
## Refresca los circuitos desde la red, igual que el bucle de `Operations.update`.
func sync_from_grid() -> void:
	if grid == null:
		return
	for circuit in grid.circuits:
		var name := str(circuit.get("name", ""))
		var index := _trailing_number(name) - 1
		if str(circuit.get("zone", "")) == "Generación":
			if index >= 0 and index < grid.outputs.size():
				circuit["kw"] = grid.outputs[index]
			if index >= 0 and index < grid.feeds.size():
				circuit["on"] = grid.feeds[index]
		elif name.begins_with("Extractor"):
			if index >= 0 and index < grid.fans.size():
				circuit["on"] = grid.fans[index]


## Factor de iluminación efectivo: si la red está caída, casi todo a oscuras.
func illumination() -> float:
	if grid == null:
		return 0.0
	return 0.07 if grid.tripped else grid.brightness


func light_kw() -> float:
	var total := 0.0
	if grid == null:
		return total
	for circuit in grid.circuits:
		var name := str(circuit.get("name", ""))
		if name == "INV" or name.begins_with("INV") or name.begins_with("Extractor"):
			continue
		if bool(circuit.get("on", true)):
			total += float(circuit.get("kw", 0.0))
	return total


# --------------------------------------------------------------------------- #
# pantallas
# --------------------------------------------------------------------------- #
## Texto de un contador de inversor (`INV n / ESTADO`, valor, subtítulo, barra).
func meter(index: int) -> Dictionary:
	if grid == null or index < 0 or index >= INVERTER_COUNT:
		return {}
	var kw := float(grid.outputs[index]) if index < grid.outputs.size() else 0.0
	var on := bool(grid.feeds[index]) and not grid.tripped
	var limited_mode := index < limited.size() and limited[index]
	var state := "AISLADO"
	if on:
		state = "ECO" if limited_mode else "EN LÍNEA"
	var values := [
		"%.1f kW" % kw,
		"%.1f A" % (kw * 1000.0 / 400.0),
		"%.1f °C" % grid.temp,
		"%.3f kWh" % (float(grid.kwh[index]) if index < grid.kwh.size() else 0.0),
	]
	var page := pages[index] if index < pages.size() else 0
	var nominal := 14.0 if limited_mode else 28.0
	return {
		"title": "INV %d  /  %s" % [index + 1, state],
		"value": values[page % values.size()],
		"subtitle": "400 V CC  /  %d kW NOM." % int(nominal),
		"ratio": kw / nominal,
		"color": "#9be7ae" if on else "#e59a77",
		"page": page,
	}


## Informe del panel maestro: cinco páginas como en la web.
func master_report() -> Dictionary:
	var selected := selected_circuit()
	var zone := selected_zone()
	var lines := selected_lines()
	var load_on := 0.0
	for circuit in lines:
		if bool(circuit.get("on", true)):
			load_on += float(circuit.get("kw", 0.0))
	var title := ""
	var value := ""
	var detail := ""
	match report % REPORT_PAGES:
		0:
			title = "BARRA PRINCIPAL   /   BALANCE"
			value = "%.1f > %.1f kW" % [grid.input_kw, grid.delivered]
			detail = "%d LUCES: %.1f kW / %d%%" % [
				_count_lamps(), light_kw() * illumination(), int(illumination() * 100.0)]
		1:
			title = "DISTRIBUCIÓN   /   DEMANDA"
			value = "%d kW" % int(grid.load_kw)
			detail = "LAB + CCTV %.1f / EXTR. %d kW" % [grid.machines, grid.fans_on() * 3]
		2:
			title = "CONVERSIÓN   /   PÉRDIDAS"
			value = "%.2f kW" % (grid.input_kw - grid.delivered)
			detail = "ENTRADA %.1f A   /   400 V CC" % (grid.input_kw * 1000.0 / 400.0)
		3:
			title = "ZONA / " + zone
			value = "%.2f kW" % load_on
			detail = "%d DERIVACIONES" % lines.size()
		_:
			title = zone + " / " + str(selected.get("name", "–"))
			value = "%.2f kW" % (float(selected.get("kw", 0.0)) if bool(selected.get("on", true)) else 0.0)
			if str(selected.get("zone", "")) == "Generación":
				var index := _trailing_number(str(selected.get("name", ""))) - 1
				var nominal := 14 if (index >= 0 and index < limited.size() and limited[index]) else 28
				detail = "%s / %d kW NOM." % [
					"EN SERVICIO" if bool(selected.get("on", true)) else "AISLADO", nominal]
			elif bool(selected.get("locked", false)):
				detail = "SERVICIO PROTEGIDO"
			elif bool(selected.get("on", true)):
				detail = "EN SERVICIO"
			else:
				detail = "AISLADO"
	return {
		"title": title,
		"value": value,
		"detail": detail,
		"ratio": clampf(grid.delivered / 336.0, 0.0, 1.0),
	}


func _count_lamps() -> int:
	var count := 0
	if grid == null:
		return count
	for circuit in grid.circuits:
		var name := str(circuit.get("name", ""))
		if name.begins_with("INV") or name.begins_with("Extractor"):
			continue
		count += 1
	return count


# --------------------------------------------------------------------------- #
# CCTV
# --------------------------------------------------------------------------- #
func camera(index: int) -> Dictionary:
	if index < 0 or index >= CAMERAS.size():
		return {}
	return CAMERAS[index] as Dictionary


## Ventana de seis canales que muestra el selector.
func visible_cameras() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for slot in CAMERA_WINDOW:
		result.append(camera((bank + slot) % CAMERA_COUNT))
	return result


## Franja de la cinta de vigilancia: `CAM 07 / REGISTROS`.
func strip_label(slot: int) -> String:
	var index := posmod(bank + slot, CAMERA_COUNT)
	var entry := camera(index)
	return "CAM %02d / %s" % [index + 1, str(entry.get("name", ""))]


func camera_in_area(x: float, z: float) -> bool:
	return area(x, z) == "Vigilancia"


# --------------------------------------------------------------------------- #
# estado y persistencia
# --------------------------------------------------------------------------- #
func reset() -> void:
	zone_index = 0
	device_index = 0
	bank = 0
	light_mode = 0
	report = 0
	pages.fill(0)
	limited.fill(false)
	if grid != null:
		for index in limited.size():
			grid.set_limit(index, false)
		grid.brightness = 1.0


func to_dict() -> Dictionary:
	var page_array: Array[int] = []
	page_array.append_array(pages)
	var limit_array: Array[bool] = []
	limit_array.append_array(limited)
	return {
		"zone_index": zone_index,
		"device_index": device_index,
		"bank": bank,
		"light_mode": light_mode,
		"report": report,
		"pages": page_array,
		"limited": limit_array,
	}


func from_dict(data: Dictionary) -> bool:
	if data.is_empty():
		return false
	zone_index = int(data.get("zone_index", 0))
	device_index = int(data.get("device_index", 0))
	bank = posmod(int(data.get("bank", 0)), CAMERA_COUNT)
	light_mode = clampi(int(data.get("light_mode", 0)), 0, BRIGHTNESS_LEVELS.size() - 1)
	report = clampi(int(data.get("report", 0)), 0, REPORT_PAGES - 1)
	var raw_pages: Variant = data.get("pages", [])
	if raw_pages is Array:
		for index in mini((raw_pages as Array).size(), pages.size()):
			pages[index] = int((raw_pages as Array)[index])
	var raw_limited: Variant = data.get("limited", [])
	if raw_limited is Array:
		for index in mini((raw_limited as Array).size(), limited.size()):
			limited[index] = bool((raw_limited as Array)[index])
			if grid != null:
				grid.set_limit(index, limited[index])
	if grid != null:
		grid.brightness = float(BRIGHTNESS_LEVELS[light_mode])
	return true
