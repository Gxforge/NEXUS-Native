class_name W01Jaw
extends Node3D
## Mandíbula y dentadura de W–01 (port de `Head.ts`).
##
## El `.glb` trae la cáscara de la cabeza, la encía y la garganta con su *blend
## shape* de apertura, y las 26 piezas dentales ya colocadas en reposo, pero sin
## morph propio. La web las mueve a mano entre dos anclas de la misma superficie
## paramétrica (`ring(a, 0,65, o)`), así que aquí se reproduce ese desplazamiento:
## al abrirse el morro cada diente baja por el eje Y del hocico una cantidad
## proporcional a `sin(a)` de su posición en el anillo.
##
## El grado de apertura no salta: se amortigua a 16 s⁻¹, igual que
## `MathUtils.damp(drive, w, 16, dt)`.

## Amortiguación de la apertura (`Head.ts`: `damp(..., 16, dt)`).
const DRIVE_RATE := 16.0
## Constantes de la superficie de `Head.ts`.
const START := 0.405
const TILT := -0.38
## `2,04 · up · (0,46 ó 0,44) · sin(start)` = recorrido vertical del ancla abierta.
const SPREAD := 0.34

var drive := 0.0
var _teeth: Array[Dictionary] = []
var _pinned := -1.0


## Recoge las 26 piezas dentales de la cabeza exportada.
func attach(head: Node3D) -> void:
	_teeth.clear()
	var stack: Array[Node] = [head]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		var tooth := node as Node3D
		if tooth != null and String(tooth.name).begins_with("Tooth_"):
			var parts := String(tooth.name).split("_")
			var side := int(parts[1]) if parts.size() > 2 else 0
			var index := int(parts[2]) if parts.size() > 2 else 0
			# Ángulo del diente en el anillo (`Head.ts`).
			var angle := (0.12 + ((float(index) + (0.27 if side == 1 else 0.0)) / 12.7) * 0.92) * PI
			if side == 1:
				angle += PI
			var rest := tooth.position
			var drop := SPREAD * sin(angle)
			_teeth.append({
				"node": tooth,
				"rest": rest,
				"open": rest + Vector3(0.0, -drop, drop * 0.28),
			})
		for child in node.get_children():
			stack.push_back(child)


## Apertura amortiguada hacia `target`; devuelve el valor efectivo. Con `delta`
## cero sólo se aplica la pose (útil para capturas).
func update(delta: float, target: float) -> float:
	var wanted := target if _pinned < 0.0 else _pinned
	if delta > 0.0:
		drive = lerpf(drive, wanted, 1.0 - exp(-DRIVE_RATE * delta))
	else:
		drive = wanted
	for tooth: Dictionary in _teeth:
		var node := tooth["node"] as Node3D
		if node != null:
			node.position = (tooth["rest"] as Vector3).lerp(tooth["open"] as Vector3, drive)
	return drive


## Fija la apertura (sólo para capturas y pruebas; −1 vuelve a la IA).
func pin(value: float) -> void:
	_pinned = value


func tooth_count() -> int:
	return _teeth.size()


## Recorrido vertical que hace un diente al abrirse del todo, por índice.
func travel(index: int) -> float:
	if index < 0 or index >= _teeth.size():
		return 0.0
	return ((_teeth[index]["open"] as Vector3) - (_teeth[index]["rest"] as Vector3)).y
