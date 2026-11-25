class_name VehicleRig
extends Node3D
## Carrocería y ruedas del coche de vía sobre **el modelo original**
## (`vehicle.glb`, grupo `Node`).
##
## Port de `VehicleModel.sync()` de la web v15.1. El exportador entrega el cuerpo
## (2,25 × 1,48 × 4,60 m, 16 mallas) y las cuatro ruedas (0,29 × 0,71 × 0,71 m,
## cinco mallas cada una) sin colocar: en la web las ruedas cuelgan del `root` en
## `(±0,87, 0,355, ±1,38)` y su altura y su giro los manda la física.
##
## | Pieza | Movimiento (`VehicleModel.sync`) |
## | --- | --- |
## | conjunto | `position = cuerpo − (0, comY, 0)`, `rotation = (pitch, yaw, roll)` |
## | rueda `i` | `y = comY + 0,14 − suspensión`, `rotation.y = dirección`, `rotation.x = rodadura` |
##
## El orden de las ruedas es el de la web —`for z in [1, −1] for x in [−1, 1]`—
## y coincide con el orden de `VehiclePhysics.WHEEL_OFFSETS`, así que los índices
## valen tal cual.

const COM_Y := VehiclePhysics.COM_Y
const WHEEL_ANCHOR_Y := VehiclePhysics.WHEEL_OFFSETS[0].y
const WHEEL_REST_Y := 0.355
const WHEEL_POSITIONS := [
	Vector3(-0.87, WHEEL_REST_Y, 1.38),
	Vector3(0.87, WHEEL_REST_Y, 1.38),
	Vector3(-0.87, WHEEL_REST_Y, -1.38),
	Vector3(0.87, WHEEL_REST_Y, -1.38),
]

var body: Node3D
var wheels: Array[Node3D] = []
var model: Node3D


## Monta el modelo exportado y separa cuerpo y ruedas.
func attach(exported: Node3D) -> bool:
	if exported == null:
		return false
	model = exported
	if exported.get_parent() == null:
		add_child(exported)
	body = null
	wheels.clear()
	var widest := 0.0
	var small: Array[Node3D] = []
	for child: Node in exported.get_children():
		var node := child as Node3D
		if node == null:
			continue
		var box := _bounds(node)
		if box.size.x > widest and _meshes(node) >= 4:
			body = node
			widest = box.size.x
		elif box.size.x < 1.0 and box.size.y < 1.0 and _meshes(node) >= 3:
			small.append(node)
	# Las ruedas salen en el orden de creación de la web.
	small.sort_custom(func(a: Node3D, b: Node3D) -> bool: return a.name < b.name)
	for node in small.slice(0, 4):
		wheels.append(node)
	for index in wheels.size():
		wheels[index].position = WHEEL_POSITIONS[index]
	if body != null:
		body.position = Vector3.ZERO
	place(Vector3.ZERO, 0.0)
	return body != null and wheels.size() == 4


## Coloca el coche parado (andén, plataforma o vía) sin física.
func place(at: Vector3, heading: float) -> void:
	position = at + Vector3(0.0, COM_Y, 0.0)
	rotation = Vector3(0.0, heading, 0.0)
	for index in wheels.size():
		wheels[index].position = WHEEL_POSITIONS[index]
		wheels[index].rotation = Vector3.ZERO


## Copia el estado de la física: actitud del cuerpo y suspensión y giro de ruedas.
func sync(physics: VehiclePhysics) -> void:
	if physics == null:
		return
	position = physics.position - Vector3(0.0, COM_Y, 0.0)
	rotation = Vector3(physics.pitch, physics.yaw, physics.roll)
	for index in wheels.size():
		var state := physics.wheel_state(index)
		var wheel := wheels[index]
		wheel.position.y = COM_Y + WHEEL_ANCHOR_Y - float(state["suspension"])
		wheel.rotation = Vector3(float(state["rotation"]), float(state["steering"]), 0.0)


## Cuántas ruedas se han montado.
func wheel_count() -> int:
	return wheels.size()


## Altura de la rueda `index` en el marco del cuerpo (para pruebas).
func wheel_y(index: int) -> float:
	return wheels[index].position.y if index < wheels.size() else 0.0


func _bounds(node: Node) -> AABB:
	var out := AABB()
	var first := true
	var stack: Array[Node] = [node]
	while not stack.is_empty():
		var current: Node = stack.pop_back()
		var mesh := current as MeshInstance3D
		if mesh != null and mesh.mesh != null:
			var box: AABB = current.transform * mesh.get_aabb()
			out = box if first else out.merge(box)
			first = false
		for child in current.get_children():
			stack.append(child)
	return out


func _meshes(node: Node) -> int:
	var total := 1 if node is MeshInstance3D else 0
	for child in node.get_children():
		total += _meshes(child)
	return total
