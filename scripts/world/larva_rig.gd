class_name LarvaRig
extends Node
## Movimiento interno de las larvas de H–01 sobre **la larva original** de
## `workshop_pods.glb`.
##
## Port de `Larva.ts` de la web v15.1. El exportador sí conserva aquí los grupos
## con nombre de three.js, así que no hace falta identificar piezas por
## geometría: el grupo de la larva cuelga del vaso en `(0, 2,25, 0)` y tiene
## `8 + índice` tentáculos con posición `(0,44·cos a, −0,33, 0,45·sin a)` y un
## grupo de ojo en `(0, 0,22, 0,6)` con seis mallas.
##
## | Pieza | Movimiento (`Larva.ts`) |
## | --- | --- |
## | tentáculo `j` | `rotation.x = 0,17·sin(t·1,35 + j·0,83)`, `rotation.z = 0,18·cos(t·1,26 + j·1,26)` |
## | ojo | `rotation.y = 0,11·sin(t·0,8 + índice)`, `rotation.x = 0,055·cos(t·1,07)` |
##
## El latido, el vaivén y el giro del conjunto los pone `ZoneDressing.animate()`
## sobre el pivote del vaso, igual que en `Workshop.Pods.update()`.

const FEELER_SWAY := 0.17
const FEELER_ROLL := 0.18
const FEELER_RATE := 1.35
const FEELER_ROLL_RATE := 1.26
const FEELER_PHASE := 0.83
const FEELER_ROLL_PHASE := 1.26
const EYE_YAW := 0.11
const EYE_YAW_RATE := 0.8
const EYE_PITCH := 0.055
const EYE_PITCH_RATE := 1.07

## Índice del vaso: cambia el número de tentáculos y la fase del ojo.
var index := 0
var root: Node3D
var feelers: Array[Node3D] = []
var eye: Node3D
var seconds := 0.0

var _feeler_home: Array[Vector3] = []
var _eye_home := Vector3.ZERO


## Engancha el movimiento a la larva de un vaso y devuelve el rig ya en el árbol.
static func attach(larva: Node3D, larva_index: int) -> LarvaRig:
	if larva == null:
		return null
	var rig := LarvaRig.new()
	rig.name = "LarvaRig"
	rig.index = larva_index
	larva.add_child(rig)
	rig.build(larva)
	return rig


## Localiza tentáculos y ojo dentro del grupo de la larva.
func build(larva: Node3D) -> bool:
	root = larva
	feelers.clear()
	eye = null
	_feeler_home.clear()
	for child: Node in larva.get_children():
		var node := child as Node3D
		if node == null or node is MeshInstance3D:
			continue
		if node.position.y > 0.0:
			if eye == null:
				eye = node
			continue
		feelers.append(node)
		_feeler_home.append(node.rotation)
	if eye != null:
		_eye_home = eye.rotation
	reset()
	return feelers.size() > 0


## Número de tentáculos que la web da a cada vaso (`8 + índice`).
static func expected_feelers(larva_index: int) -> int:
	return 8 + larva_index


## Vuelve al reposo (t = 0 con las fases originales).
func reset() -> void:
	seconds = 0.0
	for i in feelers.size():
		feelers[i].rotation = _feeler_home[i]
	if eye != null:
		eye.rotation = _eye_home


## Avanza el gesto hasta el instante `t` (función pura del tiempo, como la web).
func sync(t: float) -> void:
	seconds = t
	for j in feelers.size():
		var home := _feeler_home[j]
		feelers[j].rotation = Vector3(
			home.x + FEELER_SWAY * sin(t * FEELER_RATE + float(j) * FEELER_PHASE),
			home.y,
			home.z + FEELER_ROLL * cos(t * FEELER_ROLL_RATE + float(j) * FEELER_ROLL_PHASE))
	if eye != null:
		eye.rotation = Vector3(
			_eye_home.x + EYE_PITCH * cos(t * EYE_PITCH_RATE),
			_eye_home.y + EYE_YAW * sin(t * EYE_YAW_RATE + float(index)),
			_eye_home.z)


## Cuántos tentáculos se han encontrado.
func feeler_count() -> int:
	return feelers.size()


## Si el grupo del ojo apareció en el exportador.
func has_eye() -> bool:
	return eye != null
