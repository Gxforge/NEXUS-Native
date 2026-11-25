class_name W01Arms
extends Node3D
## Los veinte brazos de W–01 (port de `Tentacles.ts`).
##
## La web construye cada tentáculo como un tubo de 28 × 9 segmentos que se
## reconstruye en cada fotograma sobre una curva de Catmull-Rom. Aquí los brazos
## son **los del exportador** (`w01_tentacles.glb`: 20 nodos `arm-<n>` con su
## malla y sus 4–5 ventosas ya separadas), así que no hay nada que reconstruir:
## lo que se porta es el contrato de movimiento de `Tentacles.update()`.
##
## | Web | Aquí |
## | --- | --- |
## | `controls[i]` desplazados por `reach·extension` | escala del brazo a lo largo de su eje (`1 + 0,1·agr + 0,34·ataque`) |
## | `sway`/`twitch` sobre el vector `cross` | giro de `0,23·sway + 0,065·twitch` sobre el eje del brazo |
## | balanceo `sin(t·1,65 + fase)` | cabeceo del mismo período |
## | `targetPull` (0,05 + 0,15·agr + 0,28·ataque) | mezcla de la base hacia el jugador |
## | alcance de los brazos 2 y 3 con `strike`/`grab` | giro completo hacia el jugador |
## | `scout` entre los brazos `[0,1,2,3,8,9]` | igual, con el mismo criterio de producto escalar |
## | `edge()` + `Math.max(0,075 + r·(1−along), y)` | empuje fuera de la malla de contención y suelo |
## | pulso de ventosas `1 + 0,08·sin(t·3,1 + fase + along·5)` | escala de `arm-<n>-sucker-<k>` |
## | `userData.lash` | `lash()`, activado por el pulso UV |
##
## Los brazos son rígidos, así que la ondulación que la web reparte por segmentos
## se aplica como giro de la pieza entera. La geometría, los materiales y las
## ventosas son los del `.glb`.

const PHASE_STEP := 1.23
const SPEED_BASE := 0.56
const SPEED_STEP := 0.11
const PULL_BASE := 0.05
const PULL_AGGRESSION := 0.15
const PULL_ATTACK := 0.28
const PULL_MIX := 0.5
const EXTENSION_AGGRESSION := 0.1
const EXTENSION_ATTACK := 0.34
const SWAY := 0.23
const TWITCH := 0.065
const BOB := 0.12
const LASH_RATE := 17.0
const LASH_SWING := 0.55
const LURE_STRETCH := 1.8
const SUCKER_PULSE := 0.08
const SUCKER_RATE := 3.1
const SUCKER_ALONG := 0.32
const SUCKER_STEP := 0.115
const STRIKE_ARMS: Array[int] = [2, 3]
const SCOUT_ARMS: Array[int] = [0, 1, 2, 3, 8, 9]
const TOUCH_RADIUS := 0.48
const WALL_MARGIN := 0.8
const FLOOR_MARGIN := 0.075
const OUTER_PAD := 2.1
const TIP_PAD := 0.2

var arms: Array[Dictionary] = []
var scout := -1
var probing := false
var planting := false
var lure := false
var strike := 0.0
var grab := 0.0

var _parent: Node3D
var _field := FieldMemory.new()
var _lash: Array[float] = []


## Recoge los brazos del `.glb`. `arms_root` es `Tentacles/W01_20_Tentacles`.
func attach(arms_root: Node3D) -> void:
	_parent = arms_root
	arms.clear()
	_lash.clear()
	var found := {}
	for child: Node in arms_root.get_children():
		var order := _arm_index(child)
		if order >= 0:
			found[order] = child
	# El `.glb` envuelve los brazos en `W01_20_Tentacles`: si lo que llega es la
	# raíz del archivo (o un nodo con hermanos) se busca el contenedor.
	if found.is_empty():
		for child: Node in arms_root.get_children():
			var holder := child as Node3D
			if holder == null or holder.get_child_count() == 0:
				continue
			if _arm_index(holder.get_child(0)) >= 0:
				_parent = holder
				for part: Node in holder.get_children():
					var part_order := _arm_index(part)
					if part_order >= 0:
						found[part_order] = part
				break
	var orders: Array = found.keys()
	orders.sort()
	for order: int in orders:
		var node := found[order] as Node3D
		var mesh := node.get_node_or_null("arm-%d-mesh" % order) as MeshInstance3D
		if mesh == null:
			continue
		var box: AABB = mesh.get_aabb()
		var axis := _longest_axis(box)
		var tip := Vector3.ZERO
		tip[axis] = box.end[axis] if absf(box.end[axis]) >= absf(box.position[axis]) else box.position[axis]
		# La malla puede venir girada respecto al nodo del brazo.
		tip = mesh.transform * tip
		var suckers: Array = []
		for part: Node in node.get_children():
			var sucker := part as Node3D
			if sucker == null or not String(sucker.name).begins_with("arm-%d-sucker-" % order):
				continue
			var cup_order := int(String(sucker.name).get_slice("-", 3))
			suckers.append({
				"node": sucker,
				"base_scale": sucker.scale,
				"along": SUCKER_ALONG + float(cup_order) * SUCKER_STEP,
			})
		arms.append({
			"node": node,
			"index": order,
			"base_position": node.position,
			"base_basis": node.transform.basis,
			"base_scale": node.scale,
			"axis": axis,
			"length": box.size[axis],
			"radius": minf(box.size[(axis + 1) % 3], box.size[(axis + 2) % 3]) * 0.5,
			"tip": tip,
			"align": Basis(Quaternion(Vector3(0.0, 0.0, -1.0), tip.normalized())),
			"tip_length": tip.length(),
			"direction": node.position.normalized(),
			"phase": float(arms.size()) * PHASE_STEP,
			"speed": SPEED_BASE + float(arms.size() % 4) * SPEED_STEP,
			"suckers": suckers,
		})
		_lash.append(0.0)


## Mete un latigazo en un brazo (`userData.lash` de la web, que decae solo).
func lash_arm(index: int, value: float = 1.0) -> void:
	if index >= 0 and index < _lash.size():
		_lash[index] = maxf(_lash[index], value)


## Latigazo en los veinte brazos, como después de un pulso UV.
func lash_all(value: float = 1.0) -> void:
	for index in _lash.size():
		_lash[index] = maxf(_lash[index], value)


## Animación de los brazos. `attack_drive` es el de `MonsterAI`.
func update(time: float, delta: float, player_position: Vector3, aggression: float, attack_drive: float) -> void:
	if _parent == null or arms.is_empty():
		return
	for index in _lash.size():
		_lash[index] = maxf(0.0, _lash[index] - delta)
	var reach_drive := maxf(strike, grab)
	scout = -1
	if probing and strike <= 0.0 and grab <= 0.0:
		var best := -INF
		for index in SCOUT_ARMS:
			var arm: Dictionary = arms[index]
			var aim := (player_position - (_parent.global_transform * (arm["base_position"] as Vector3))).normalized()
			var score := (arm["direction"] as Vector3).dot(_parent.global_basis.inverse() * aim) + 0.15 * sin(time * 0.47 + float(index))
			if score > best:
				best = score
				scout = index
	var local_player := _parent.to_local(player_position)
	for target_index in arms.size():
		var arm: Dictionary = arms[target_index]
		var node := arm["node"] as Node3D
		var base_position := arm["base_position"] as Vector3
		var base_basis := arm["base_basis"] as Basis
		var base_scale := arm["base_scale"] as Vector3
		var axis := int(arm["axis"])
		var phase := float(arm["phase"])
		var speed := float(arm["speed"])
		var index := int(arm["index"])

		var aim := (local_player - base_position).normalized()
		var aim_basis := Basis.looking_at(aim, Vector3.UP) * (arm["align"] as Basis).inverse()
		var pull := PULL_BASE + aggression * PULL_AGGRESSION + attack_drive * PULL_ATTACK
		var extension := 1.0 + aggression * EXTENSION_AGGRESSION + attack_drive * EXTENSION_ATTACK
		if lure:
			extension += LURE_STRETCH * 0.5

		var sway := sin(time * speed + phase)
		var twitch := sin(time * (2.4 + speed) + phase * 2.7)
		var yaw := sway * SWAY + twitch * TWITCH
		var pitch := sin(time * 1.65 + phase) * BOB * 0.35
		var lash := _lash[target_index]
		if lash > 0.0:
			yaw += sin(time * LASH_RATE + phase) * LASH_SWING * lash
			pitch += cos(time * LASH_RATE * 0.7 + phase) * LASH_SWING * 0.4 * lash
		var basis := base_basis * Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, pitch)

		# El brazo mira al operador: un poco con la agresión y del todo al atacar.
		if pull > 0.0:
			basis = basis.slerp(aim_basis, clampf(pull * PULL_MIX, 0.0, 0.5)).orthonormalized()
		if reach_drive > 0.0 and STRIKE_ARMS.has(index):
			basis = basis.slerp(aim_basis, clampf(reach_drive, 0.0, 1.0)).orthonormalized()
		if index == scout:
			basis = basis.slerp(aim_basis, 0.42).orthonormalized()

		var scale := base_scale
		scale[axis] = base_scale[axis] * extension

		# Suelo y malla de contención: el brazo gira sobre su anclaje, no se mueve.
		var parent := node.get_parent() as Node3D
		var parent_basis := parent.global_basis if parent != null else Basis.IDENTITY
		var parent_origin := parent.global_position if parent != null else Vector3.ZERO
		var origin_world := parent_origin + parent_basis * base_position
		var tip_vector := arm["tip"] as Vector3
		var tip_length := float(arm["tip_length"])
		var tip_direction := (parent_basis * basis * tip_vector)
		if tip_direction.length() > 0.0001:
			# El alcance real incluye el estiramiento del brazo.
			var reach := tip_length * extension
			var dir_world := tip_direction.normalized()
			var wall := _field.edge(origin_world.x + dir_world.x * reach, origin_world.z + dir_world.z * reach)
			if float(wall["d"]) > -WALL_MARGIN:
				# El brazo se aparta del anillo: la componente normal de la
				# dirección se recorta para que la punta no cruce la malla.
				var nx := float(wall["nx"])
				var nz := float(wall["nz"])
				var origin_normal := (origin_world.x - FieldMemory.CELL_CENTER.x) * nx + (origin_world.z - FieldMemory.CELL_CENTER.y) * nz
				var max_normal := (FieldMemory.apothem() - WALL_MARGIN - origin_normal) / reach
				var normal_comp := dir_world.x * nx + dir_world.z * nz
				if normal_comp > max_normal:
					max_normal = clampf(max_normal, -1.0, 1.0)
					var tangent_comp := dir_world.x * nz - dir_world.z * nx
					var vertical_comp := dir_world.y
					var other := sqrt(tangent_comp * tangent_comp + vertical_comp * vertical_comp)
					var room := sqrt(maxf(1.0 - max_normal * max_normal, 0.0))
					var share := 0.0 if other < 0.00001 else room / other
					dir_world = Vector3(
						nx * max_normal + nz * tangent_comp * share,
						vertical_comp * share,
						nz * max_normal - nx * tangent_comp * share)
			var floor_y := FLOOR_MARGIN + float(arm["radius"])
			if origin_world.y + dir_world.y * reach < floor_y:
				# No se puede bajar más: se abre el brazo en horizontal.
				var need := clampf((floor_y - origin_world.y) / reach, -1.0, 1.0)
				var heading := Vector2(dir_world.x, dir_world.z)
				var flat := heading.length()
				var room_floor := sqrt(maxf(1.0 - need * need, 0.0))
				if flat < 0.00001:
					heading = Vector2(1.0, 0.0)
					flat = 1.0
				heading = heading / flat * room_floor
				dir_world = Vector3(heading.x, need, heading.y)
			if dir_world.distance_to(tip_direction.normalized()) > 0.001:
				var want_parent := (parent_basis.inverse() * dir_world).normalized()
				# Un brazo casi recto arriba o abajo necesita otra referencia:
				# `looking_at` no admite una dirección paralela a `up`.
				var up_ref := Vector3.UP
				if absf(want_parent.dot(Vector3.UP)) > 0.99:
					up_ref = Vector3.FORWARD
				basis = Basis.looking_at(want_parent, up_ref) * (arm["align"] as Basis).inverse()

		node.transform = Transform3D(basis * Basis.from_scale(scale), base_position)

		for sucker: Dictionary in arm["suckers"]:
			var cup := sucker["node"] as Node3D
			var pulse := 1.0 + SUCKER_PULSE * sin(time * SUCKER_RATE + phase + float(sucker["along"]) * 5.0)
			cup.scale = (sucker["base_scale"] as Vector3) * pulse


## Punta del brazo en coordenadas de mundo.
func tip_of(index: int) -> Vector3:
	if index < 0 or index >= arms.size():
		return Vector3.ZERO
	return _tip_global(arms[index])


func _tip_global(arm: Dictionary) -> Vector3:
	var node := arm["node"] as Node3D
	return node.to_global(arm["tip"] as Vector3)


## Alcance exterior de la criatura, como `Tentacles.outerReach`.
func outer_reach(cx: float, cz: float) -> float:
	var root_position := _parent.global_position if _parent != null else Vector3.ZERO
	var best := Vector2(root_position.x - cx, root_position.z - cz).length() + OUTER_PAD
	for index in arms.size():
		var tip := tip_of(index)
		best = maxf(best, Vector2(tip.x - cx, tip.z - cz).length() + TIP_PAD)
	return best


## ¿Tocan los brazos 2 o 3 ese punto? (`Tentacles.touches`)
func touches(point: Vector3) -> bool:
	for index in STRIKE_ARMS:
		if tip_of(index).distance_to(point) < TOUCH_RADIUS:
			return true
	return false


func arm_count() -> int:
	return arms.size()


func sucker_count() -> int:
	var total := 0
	for arm: Dictionary in arms:
		total += (arm["suckers"] as Array).size()
	return total


## Índice de `arm-<n>`; −1 para cualquier otro nodo.
static func _arm_index(node: Node) -> int:
	var name := String(node.name)
	if not name.begins_with("arm-"):
		return -1
	var tail := name.substr(4)
	if not tail.is_valid_int():
		return -1
	return int(tail)


static func _longest_axis(box: AABB) -> int:
	var size := box.size
	if size.x >= size.y and size.x >= size.z:
		return 0
	return 1 if size.y >= size.z else 2
