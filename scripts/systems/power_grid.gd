class_name PowerGrid
extends RefCounted
## Red eléctrica del laboratorio.
##
## Port fiel de `src/scene/Power.ts` de NEXUS Web v15.1: doce alimentadores
## (cuatro limitables), capacidad calculada desde los alimentadores activos,
## carga dependiente de luces, máquinas, extractores, motor de V-03 y picos
## temporales, temperatura con histéresis y disparo del interruptor por estrés
## o por temperatura crítica. El rearme exige capacidad y refrigeración.

signal state_changed(snapshot: Dictionary)
signal breaker_tripped(cause: String)
signal breaker_rearmed(message: String)

const FEED_COUNT := 12
const NOMINAL_KW := 28.0
const LIMITED_KW := 14.0
const BASE_LOAD_KW := 22.0
const MOTOR_KW := 45.0
const FAN_KW := 3.0
const FAN_COUNT := 4
const EFFICIENCY := 0.956
const AMBIENT_TEMP := 28.0
const TRIPPED_TEMP := 31.0
const CRITICAL_TEMP := 84.0
const REARM_MIN_CAPACITY := 84.0
const REARM_MAX_TEMP := 65.0
const REARM_MIN_FANS := 2

## Circuitos declarados por las zonas: {zone, name, kw, on, locked}.
var circuits: Array[Dictionary] = []
## Alimentadores activos (por defecto los cuatro primeros).
var feeds: Array[bool] = []
## Alimentadores limitados a 14 kW en lugar de 28 kW.
var limits: Array[bool] = []
## Extractores de refrigeración.
var fans: Array[bool] = []
## Energía acumulada por alimentador (kWh).
var kwh: Array[float] = []
## Reparto instantáneo por alimentador (kW).
var outputs: Array[float] = []
## Picos temporales: {name, kw, ttl}.
var surges: Array[Dictionary] = []

var load_kw := 0.0
var capacity := 112.0
var delivered := 0.0
var input_kw := 0.0
var light_kw := 0.0
var brightness := 1.0
var machines := 0.0
var temp := 36.0
var stress := 0.0
var tripped := false
var cause := "Estable"

var _last_emit := {}


func _init() -> void:
	reset()


## Vacía el estado eléctrico. Los circuitos declarados se conservan y se
## vuelven a encender, igual que `Power.reset()` en la versión web.
func reset() -> void:
	feeds.clear()
	limits.clear()
	fans.clear()
	kwh.clear()
	outputs.clear()
	for index in FEED_COUNT:
		feeds.append(index < 4)
		limits.append(false)
		kwh.append(0.0)
		outputs.append(0.0)
	for _index in FAN_COUNT:
		fans.append(true)
	surges.clear()
	load_kw = 0.0
	capacity = 112.0
	delivered = 0.0
	input_kw = 0.0
	light_kw = 0.0
	brightness = 1.0
	machines = 0.0
	temp = 36.0
	stress = 0.0
	tripped = false
	cause = "Estable"
	for circuit in circuits:
		circuit["on"] = true
	_recalculate_light_kw()


# --------------------------------------------------------------------------- #
# circuitos
# --------------------------------------------------------------------------- #
func register_circuit(zone: String, name: String, kw: float, locked := false) -> Dictionary:
	var circuit := {"zone": zone, "name": name, "kw": kw, "on": true, "locked": locked}
	circuits.append(circuit)
	return circuit


func named(name: String) -> Dictionary:
	for circuit in circuits:
		if str(circuit.get("name", "")) == name:
			return circuit
	return {}


func set_circuit(name: String, on: bool) -> bool:
	var circuit := named(name)
	if circuit.is_empty() or bool(circuit.get("locked", false)):
		return false
	circuit["on"] = on
	_recalculate_light_kw()
	return true


func circuits_of(zone: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for circuit in circuits:
		if str(circuit.get("zone", "")) == zone:
			result.append(circuit)
	return result


func _recalculate_light_kw() -> void:
	var total := 0.0
	for circuit in circuits:
		if str(circuit.get("zone", "")) == "electrical" and bool(circuit.get("on", true)):
			total += float(circuit.get("kw", 0.0))
	light_kw = total


# --------------------------------------------------------------------------- #
# alimentadores, límites y extractores
# --------------------------------------------------------------------------- #
func set_feed(index: int, on: bool) -> void:
	if index < 0 or index >= feeds.size():
		return
	feeds[index] = on


func cycle_feed(index: int) -> bool:
	if index < 0 or index >= feeds.size():
		return false
	feeds[index] = not feeds[index]
	return feeds[index]


func set_limit(index: int, limited: bool) -> void:
	if index < 0 or index >= limits.size():
		return
	limits[index] = limited


func set_fan(index: int, on: bool) -> void:
	if index < 0 or index >= fans.size():
		return
	fans[index] = on


func cycle_fan(index: int) -> bool:
	if index < 0 or index >= fans.size():
		return false
	fans[index] = not fans[index]
	return fans[index]


func fans_on() -> int:
	var count := 0
	for on in fans:
		if on:
			count += 1
	return count


func feeds_on() -> int:
	var count := 0
	for on in feeds:
		if on:
			count += 1
	return count


func spike(name: String, kw: float, ttl: float) -> void:
	for surge in surges:
		if str(surge.get("name", "")) == name:
			surge["ttl"] = ttl
			surge["kw"] = kw
			return
	surges.append({"name": name, "kw": kw, "ttl": ttl})


# --------------------------------------------------------------------------- #
# simulación
# --------------------------------------------------------------------------- #
## Avanza la red un paso. Devuelve `true` si el interruptor acaba de dispararse.
func update(dt: float, motor: bool, aggression: float) -> bool:
	dt = maxf(dt, 0.0)
	var alive: Array[Dictionary] = []
	for surge in surges:
		surge["ttl"] = float(surge.get("ttl", 0.0)) - dt
		if float(surge["ttl"]) > 0.0:
			alive.append(surge)
	surges = alive

	capacity = 0.0
	for index in FEED_COUNT:
		if not bool(feeds[index]):
			continue
		capacity += LIMITED_KW if bool(limits[index]) else NOMINAL_KW

	var surge_kw := 0.0
	for surge in surges:
		surge_kw += float(surge.get("kw", 0.0))

	if tripped:
		load_kw = 17.0
	else:
		load_kw = roundf(BASE_LOAD_KW + light_kw * brightness + machines
			+ clampf(aggression, 0.0, 1.0) * 14.0 + float(fans_on()) * FAN_KW
			+ (MOTOR_KW if motor else 0.0) + surge_kw)

	delivered = 0.0 if tripped else minf(capacity, load_kw)
	for index in FEED_COUNT:
		if bool(feeds[index]) and capacity > 0.0:
			var share := LIMITED_KW if bool(limits[index]) else NOMINAL_KW
			outputs[index] = delivered * share / capacity
		else:
			outputs[index] = 0.0
	input_kw = delivered / EFFICIENCY
	for index in FEED_COUNT:
		kwh[index] += outputs[index] * dt / (3600.0 * EFFICIENCY)

	var target := TRIPPED_TEMP if tripped else AMBIENT_TEMP + load_kw * 0.24 \
		+ float(FAN_COUNT - fans_on()) * 13.0
	temp += (target - temp) * (1.0 - exp(-dt * 0.17))

	var excess := load_kw - capacity
	var delta := -0.52 if excess <= 0.0 else 0.19 + excess * 0.032
	stress = clampf(stress + dt * delta, 0.0, 1.0)

	var tripped_now := false
	if not tripped and (stress >= 1.0 or temp >= CRITICAL_TEMP):
		tripped = true
		tripped_now = true
		if temp >= CRITICAL_TEMP:
			cause = "Temperatura crítica"
		else:
			var names: Array[String] = []
			for surge in surges:
				names.append(str(surge.get("name", "")))
			var detail := " + ".join(names) if not names.is_empty() else (
				"motor V–03" if motor else "alimentadores insuficientes")
			cause = "Sobrecarga: %d/%d kW · %s" % [int(load_kw), int(capacity), detail]
		breaker_tripped.emit(cause)
	_emit_if_visible_changed()
	return tripped_now


## Intenta rearmar el interruptor. Devuelve el mensaje que vería el jugador.
func rearm() -> String:
	if not tripped:
		return "Red estable · no requiere rearme"
	if capacity < REARM_MIN_CAPACITY:
		return "Restablece al menos %d kW en Electricidad" % int(REARM_MIN_CAPACITY)
	if temp > REARM_MAX_TEMP or fans_on() < REARM_MIN_FANS:
		return "Recupera la refrigeración: dos extractores activos y menos de %d °C" \
			% int(REARM_MAX_TEMP)
	tripped = false
	stress = 0.0
	surges.clear()
	cause = "Rearmada"
	var message := "Red restablecida · aislamiento retirado"
	breaker_rearmed.emit(message)
	state_changed.emit(snapshot())
	return message


func _emit_if_visible_changed() -> void:
	var current := {
		"load": int(load_kw),
		"capacity": int(capacity),
		"temp": int(temp),
		"status": status_line(),
		"fans": fans_on(),
		"feeds": feeds_on(),
	}
	if current == _last_emit:
		return
	_last_emit = current
	state_changed.emit(snapshot())

func is_stable() -> bool:
	return not tripped and stress < 0.35 and temp < 70.0


func load_ratio() -> float:
	return 0.0 if capacity <= 0.0 else load_kw / capacity


func status_line() -> String:
	if tripped:
		return "RED CAÍDA · %s" % cause
	if stress > 0.7 or temp > 76.0:
		return "RED AL LÍMITE · %d/%d kW · %d °C" % [int(load_kw), int(capacity), int(temp)]
	return "RED ESTABLE · %d/%d kW · %d °C" % [int(load_kw), int(capacity), int(temp)]


# --------------------------------------------------------------------------- #
# instantánea y persistencia
# --------------------------------------------------------------------------- #
func snapshot() -> Dictionary:
	return {
		"load_kw": load_kw,
		"capacity": capacity,
		"delivered": delivered,
		"input_kw": input_kw,
		"temp": temp,
		"stress": stress,
		"tripped": tripped,
		"cause": cause,
		"fans_on": fans_on(),
		"feeds_on": feeds_on(),
		"status": status_line(),
	}


func to_dict() -> Dictionary:
	var feed_array: Array[bool] = []
	for on in feeds:
		feed_array.append(on)
	var limit_array: Array[bool] = []
	for limited in limits:
		limit_array.append(limited)
	var fan_array: Array[bool] = []
	for on in fans:
		fan_array.append(on)
	var kwh_array: Array[float] = []
	for value in kwh:
		kwh_array.append(value)
	var circuit_array: Array[Dictionary] = []
	for circuit in circuits:
		circuit_array.append({
			"zone": str(circuit.get("zone", "")),
			"name": str(circuit.get("name", "")),
			"kw": float(circuit.get("kw", 0.0)),
			"on": bool(circuit.get("on", true)),
			"locked": bool(circuit.get("locked", false)),
		})
	var surge_array: Array[Dictionary] = []
	for surge in surges:
		surge_array.append({
			"name": str(surge.get("name", "")),
			"kw": float(surge.get("kw", 0.0)),
			"ttl": float(surge.get("ttl", 0.0)),
		})
	return {
		"circuits": circuit_array,
		"feeds": feed_array,
		"limits": limit_array,
		"fans": fan_array,
		"kwh": kwh_array,
		"surges": surge_array,
		"load_kw": load_kw,
		"capacity": capacity,
		"light_kw": light_kw,
		"brightness": brightness,
		"machines": machines,
		"temp": temp,
		"stress": stress,
		"tripped": tripped,
		"cause": cause,
	}


## Restaura el estado guardado. Tolera archivos viejos sin datos eléctricos.
func from_dict(data: Dictionary) -> bool:
	if data.is_empty():
		return false
	var raw_circuits: Variant = data.get("circuits", [])
	if raw_circuits is Array:
		circuits.clear()
		for raw in raw_circuits:
			if not raw is Dictionary:
				continue
			circuits.append({
				"zone": str(raw.get("zone", "")),
				"name": str(raw.get("name", "")),
				"kw": float(raw.get("kw", 0.0)),
				"on": bool(raw.get("on", true)),
				"locked": bool(raw.get("locked", false)),
			})
	_read_bools(data.get("feeds", []), feeds)
	_read_bools(data.get("limits", []), limits)
	_read_bools(data.get("fans", []), fans)
	var raw_kwh: Variant = data.get("kwh", [])
	if raw_kwh is Array:
		for index in mini(raw_kwh.size(), kwh.size()):
			kwh[index] = float(raw_kwh[index])
	surges.clear()
	var raw_surges: Variant = data.get("surges", [])
	if raw_surges is Array:
		for raw in raw_surges:
			if raw is Dictionary:
				surges.append({
					"name": str(raw.get("name", "")),
					"kw": float(raw.get("kw", 0.0)),
					"ttl": float(raw.get("ttl", 0.0)),
				})
	load_kw = float(data.get("load_kw", 0.0))
	capacity = float(data.get("capacity", 112.0))
	light_kw = float(data.get("light_kw", 0.0))
	brightness = float(data.get("brightness", 1.0))
	machines = float(data.get("machines", 0.0))
	temp = float(data.get("temp", 36.0))
	stress = float(data.get("stress", 0.0))
	tripped = bool(data.get("tripped", false))
	cause = str(data.get("cause", "Estable"))
	state_changed.emit(snapshot())
	return true


func _read_bools(source: Variant, destination: Array) -> void:
	if not source is Array:
		return
	for index in mini(source.size(), destination.size()):
		destination[index] = bool(source[index])


# --------------------------------------------------------------------------- #
# red por defecto del laboratorio
# --------------------------------------------------------------------------- #
## Circuitos de instalación (los que no van por el cuadro técnico).
func apply_laboratory_circuits() -> void:
	var grid := self
	grid.register_circuit("electrical", "Luces de laboratorio", 18.0, true)
	grid.register_circuit("electrical", "Bancos de contención", 12.0)
	grid.register_circuit("c04", "Instrumentación C-04", 6.0, true)
	grid.register_circuit("b02", "Turbinas B-02", 22.0)
	grid.register_circuit("v03_gallery", "Criogenia V-03", 16.0, true)
	grid.register_circuit("surveillance", "CCTV", 4.0, true)
	grid.register_circuit("h01", "Hidráulica H-01", 9.0)
	grid.register_circuit("transit_hub", "Enclave de tránsito", 7.0)
	grid.machines = 6.0
	grid._recalculate_light_kw()

## Red completa de laboratorio para pruebas: circuitos de instalación.
static func for_laboratory() -> PowerGrid:
	var grid := PowerGrid.new()
	grid.apply_laboratory_circuits()
	return grid
