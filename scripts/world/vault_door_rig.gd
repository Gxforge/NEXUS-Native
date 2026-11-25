class_name VaultDoorRig
extends Node3D
## Apertura de la bóveda V–03 sobre **la puerta original** (`vault.glb`, `Node2`).
##
## Port de la secuencia de `Vault.update()` de la web, con los mismos tiempos y
## los mismos recorridos. La puerta no se reconstruye: llega entera del
## exportador (131 mallas) y aquí sólo se identifican sus piezas por geometría,
## porque el `.glb` no conserva los grupos con nombre de three.js.
##
## | Pieza | Se reconoce por | Movimiento |
## | --- | --- | --- |
## | disco | hijo con caja de más de 4,5 m en X (5,96 m) | `z = 0,08 + ramp(13,6…16,2)·1,32` y `x = −6,25·ramp(16,3…22)` |
## | corona | dentro del disco, caja de 2,5–3,6 m centrada | `rotation.z = −ramp(8,8…13,9)·2,3π` |
## | pestillos | 8 hijos de 4 mallas y 1,33 m de alto | `y = ramp(4,3 + i·0,58 … 5,9 + i·0,58)·0,96` |
## | pistones | 4 hijos de 7 mallas y 1,97 m de alto | `y = ramp(0,8 + i·0,71 … 3,1 + i·0,71)·1,56` |
##
## La secuencia dura 22 s y la fase es la misma que la de `VaultModule`: el
## módulo manda, el rig sólo pinta el tiempo que le llega.

const SEQUENCE := 22.0
const DISK_HOME_Z := 0.08
const DISK_PUSH := 1.32
const DISK_SLIDE := -6.25
const WHEEL_TURNS := 2.3
const DOG_LIFT := 0.96
const PISTON_LIFT := 1.56

var time := -1.0
var phase := "Sellada"
var opened := false

var disk: Node3D
var wheel: Node3D
var dogs: Array[Node3D] = []
var pistons: Array[Node3D] = []
var arms: Array[Node3D] = []

var _disk_home := Vector3.ZERO
var _dog_home: Array[Vector3] = []
var _piston_home: Array[Vector3] = []
var _arm_home: Array[Vector3] = []


## Identifica las piezas dentro del grupo de la puerta exportada.
func attach(group: Node3D) -> bool:
	if group == null:
		return false
	disk = null
	wheel = null
	dogs.clear()
	pistons.clear()
	arms.clear()
	_dog_home.clear()
	_piston_home.clear()
	_arm_home.clear()
	var widest := 0.0
	for child: Node in group.get_children():
		var node := child as Node3D
		if node == null:
			continue
		var box := _aabb(node)
		var meshes := _mesh_count(node)
		var center := box.get_center()
		if box.size.x > 4.5 and box.size.x > widest and meshes > 20:
			disk = node
			widest = box.size.x
		elif meshes == 4 and box.size.y > 1.0 and box.size.y < 1.7:
			dogs.append(node)
		elif meshes == 7 and box.size.y > 1.7 and box.size.y < 2.2:
			pistons.append(node)
		elif meshes == 1 and center.x < -2.0:
			arms.append(node)
	if disk != null:
		disk.position.z = DISK_HOME_Z
		_disk_home = Vector3(0.0, 0.0, DISK_HOME_Z)
		for child: Node in disk.get_children():
			var node := child as Node3D
			if node == null:
				continue
			var wheel_box := _aabb(node)
			var wheel_center := wheel_box.get_center()
			if wheel_box.size.x > 2.5 and wheel_box.size.x < 3.8 \
					and absf(wheel_center.x) < 0.4 and absf(wheel_center.y) < 0.4:
				wheel = node
				break
	for dog: Node3D in dogs:
		_dog_home.append(dog.position)
	for piston: Node3D in pistons:
		_piston_home.append(piston.position)
	for arm: Node3D in arms:
		_arm_home.append(arm.position)
	reset()
	return disk != null


## El módulo de la bóveda manda el tiempo; −1 significa cerrada.
func sync(seconds: float) -> void:
	if seconds < 0.0:
		reset()
		return
	_apply(minf(seconds, SEQUENCE))


## Posición de la puerta para un instante de la secuencia (función pura).
func _apply(seconds: float) -> void:
	time = seconds
	if disk != null:
		disk.position.z = DISK_HOME_Z + _ramp(seconds, 13.6, 16.2) * DISK_PUSH
		disk.position.x = DISK_SLIDE * _ramp(seconds, 16.3, SEQUENCE)
		disk.position.y = _disk_home.y
	if wheel != null:
		wheel.rotation.z = -_ramp(seconds, 8.8, 13.9) * PI * WHEEL_TURNS
	for index in pistons.size():
		pistons[index].position = _piston_home[index] + Vector3(0.0,
			_ramp(seconds, 0.8 + float(index) * 0.71, 3.1 + float(index) * 0.71) * PISTON_LIFT, 0.0)
	for index in dogs.size():
		dogs[index].position = _dog_home[index] + Vector3(0.0,
			_ramp(seconds, 4.3 + float(index) * 0.58, 5.9 + float(index) * 0.58) * DOG_LIFT, 0.0)
	# Los brazos hidráulicos acompañan al disco mientras sale.
	var slide := absf(disk.position.x) / absf(DISK_SLIDE) if disk != null else 0.0
	for index in arms.size():
		arms[index].position = _arm_home[index] + Vector3(-0.12 * slide * float(index % 6), 0.0, 0.0)
	opened = seconds >= SEQUENCE
	phase = _phase_for(seconds)


## Fases con los mismos umbrales que `Vault.ts` y `VaultModule`.
static func _phase_for(seconds: float) -> String:
	if seconds >= SEQUENCE:
		return "Abierta"
	if seconds < 0.8:
		return "Validando"
	if seconds < 5.2:
		return "Retirando cerrojos"
	if seconds < 9.8:
		return "Liberando pestillos"
	if seconds < 13.9:
		return "Girando corona"
	if seconds < 16.2:
		return "Despresurizando"
	return "Traslado hidráulico"


func reset() -> void:
	time = -1.0
	phase = "Sellada"
	opened = false
	if disk != null:
		disk.position = _disk_home
	if wheel != null:
		wheel.rotation.z = 0.0
	for index in dogs.size():
		dogs[index].position = _dog_home[index]
	for index in pistons.size():
		pistons[index].position = _piston_home[index]
	for index in arms.size():
		arms[index].position = _arm_home[index]


func dog_count() -> int:
	return dogs.size()


func piston_count() -> int:
	return pistons.size()


func has_wheel() -> bool:
	return wheel != null


## Caja envolvente de un subárbol en su propio espacio.
static func _aabb(root: Node3D) -> AABB:
	var box := AABB()
	var first := true
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		var mesh := node as MeshInstance3D
		if mesh != null and mesh.mesh != null:
			var local := Transform3D.IDENTITY
			var walk: Node3D = mesh
			while walk != null and walk != root:
				local = (walk as Node3D).transform * local
				walk = walk.get_parent() as Node3D
			var mesh_box: AABB = local * mesh.get_aabb()
			box = mesh_box if first else box.merge(mesh_box)
			first = false
		for child in node.get_children():
			stack.push_back(child)
	return box


static func _mesh_count(root: Node) -> int:
	var count := 0
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is MeshInstance3D:
			count += 1
		for child in node.get_children():
			stack.push_back(child)
	return count


## `smoothstep` de la web.
static func _ramp(value: float, start: float, end: float) -> float:
	if end <= start:
		return 1.0 if value >= end else 0.0
	var t := clampf((value - start) / (end - start), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)
