class_name FieldMemory
extends RefCounted
## Perímetro de contención de W–01 y su memoria local por sector.
##
## Port de `src/scene/FieldSense.ts`: la malla de contención se modela como un
## anillo de 24 facetas (radio 15 m, apotema calculada) y el sujeto recuerda, en
## 24 sectores, dónde le ha costado más bordear. Esa memoria se guarda con la
## partida, como el `localStorage` de la web.

const SECTORS := 24
const CELL_CENTER := Vector2(0.0, 22.0)
const CELL_RADIUS := 15.0
const STEP := PI / 12.0

var risk: Array[float] = []


func _init() -> void:
	for _index in SECTORS:
		risk.append(0.0)


## Apotema del anillo: distancia del centro a cada faceta.
static func apothem() -> float:
	return CELL_RADIUS * cos(STEP * 0.5)


## Faceta más cercana a un punto: normal, distancia firmada y sector.
func edge(x: float, z: float) -> Dictionary:
	var dx := x - CELL_CENTER.x
	var dz := z - CELL_CENTER.y
	var angle := atan2(dx, dz)
	var sector: int = (int(floor(angle / STEP)) + SECTORS) % SECTORS
	var facet: float = (floor(angle / STEP) + 0.5) * STEP
	var nx := sin(facet)
	var nz := cos(facet)
	return {
		"nx": nx,
		"nz": nz,
		"d": dx * nx + dz * nz - apothem(),
		"sector": sector,
	}


## Suma riesgo a un sector (máximo 1) y avisa si el valor visible cambió.
func remember(sector: int, weight: float) -> bool:
	if sector < 0 or sector >= risk.size():
		return false
	var previous := risk[sector]
	risk[sector] = minf(1.0, previous + weight)
	return int(floor(previous * 10.0)) != int(floor(risk[sector] * 10.0))


func sector_risk(sector: int) -> float:
	if sector < 0 or sector >= risk.size():
		return 0.0
	return risk[sector]


## Sector con menos memoria de los dos vecinos: hacia allí se bordea.
func safer_neighbour(sector: int) -> int:
	var right := posmod(sector + 1, SECTORS)
	var left := posmod(sector + 23, SECTORS)
	return 1 if risk[right] <= risk[left] else -1


func total_risk() -> float:
	var total := 0.0
	for value in risk:
		total += value
	return total


func reset() -> void:
	for index in risk.size():
		risk[index] = 0.0


func to_dict() -> Dictionary:
	var values: Array[float] = []
	values.append_array(risk)
	return {"risk": values}


func from_dict(data: Dictionary) -> bool:
	if data.is_empty():
		return false
	var raw: Variant = data.get("risk", [])
	if not raw is Array:
		return false
	var list := raw as Array
	for index in mini(list.size(), risk.size()):
		risk[index] = clampf(float(list[index]), 0.0, 1.0)
	return true
