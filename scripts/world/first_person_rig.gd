class_name FirstPersonRig
extends Node3D
## Manos, guantes y equipo en primera persona, con los modelos originales.
##
## Port de `src/scene/Touch.ts`: la web cuelga del cámaras un grupo de guantes
## (seis poses), otro con los tres instrumentos ópticos y un guante de linterna
## en la mano izquierda, más dos mangas y dos codos por brazo. Este script monta
## exactamente esas piezas —exportadas en `touch_rig_assets.glb`, con las mismas
## seis poses y los mismos tres instrumentos que `Glove.ts` e `Instruments.ts`—
## bajo la cámara del jugador, con el mismo balanceo y el mismo gesto de alcance.

const BATCH := "res://assets/generated/source-batch/touch_rig_assets.glb"

## Transformaciones del grupo de mano derecha (metros, espacio de cámara).
const HAND_POSITION := Vector3(0.185, -0.152, -0.5)
const HAND_ROTATION := Vector3(0.245, 0.16, -0.11)
const LAMP_POSITION := Vector3(-0.196, -0.146, -0.5)
const LAMP_ROTATION := Vector3(0.02, -0.4, 0.13)
const SLEEVE_LENGTH_SCALE := 0.302
const SLEEVE_GIRTH := 0.88
const SLEEVE_LENGTH := 0.62
const REACH_DURATION := 1.06
const ARM_REACH := 0.595
const SHOULDER_DROP := 0.23

## Nombre de cada pose en el orden en que `Touch.ts` las construye.
const POSE_NAMES: Array[StringName] = [&"press", &"drawer", &"grip", &"flat", &"round", &"box"]

@export var sway_strength: float = 1.0
@export var view_light_energy: float = 0.14
## Brazos superiores y codos: en cámara quedan casi pegados al plano cercano y
## se leen como un tubo enorme en la esquina; por defecto se muestran sólo las
## mangas del antebrazo, que es lo que la web deja ver en pantalla.
@export var show_uppers: bool = false
## Mangas del antebrazo: el lathe exportado es un tubo abierto y, a 40 cm de la
## cámara, se le ve el interior. Quedan disponibles pero apagadas; el guante ya
## trae su propio puño de punto y se lee solo.
@export var show_sleeves: bool = false

var hand: Node3D
var tools: Node3D
var lamp_glove: Node3D
var poses: Array[Node3D] = []
var devices: Array[Node3D] = []
var sleeves: Array[MeshInstance3D] = []
var pads: Array[MeshInstance3D] = []
## Tapas de las mangas: el lathe original es un tubo abierto y, visto de cerca,
## se le veía el interior. Cada manga lleva una esfera en cada extremo.
var sleeve_caps: Array = []

## Estado visible (lo refresca `_process` desde el jugador).
var weapon: int = -1
var lamp: bool = false
var first_person: bool = true
var pose: StringName = &"grip"

var _player: NexusPlayer
var _travel := 0.0
var _kick := 0.0
var _reach_time := REACH_DURATION
var _reach_pose: StringName = &"grip"
var _built := false
var _view_light: OmniLight3D


func _ready() -> void:
	_build()
	_player = _find_player()
	set_process(true)


## Monta las piezas originales bajo este nodo (que cuelga de la cámara).
func _build() -> void:
	if _built:
		return
	_built = true
	var packed := load(BATCH) as PackedScene
	if packed == null:
		push_warning("FirstPersonRig: falta touch_rig_assets.glb")
		return
	var root: Node = packed.instantiate()
	var holder: Node = root
	if root.get_child_count() > 0:
		holder = root.get_child(0)
	var pose_holder: Node = null
	var device_holder: Node = null
	var lamp_holder: Node = null
	var loose: Array[MeshInstance3D] = []
	for child in holder.get_children():
		var mesh := child as MeshInstance3D
		if mesh != null:
			holder.remove_child(mesh)
			loose.append(mesh)
		elif String(child.name) == "Node":
			pose_holder = child
		elif String(child.name) == "Node9":
			device_holder = child
		elif String(child.name) == "Node13":
			lamp_holder = child
	hand = Node3D.new()
	hand.name = "Hand"
	hand.position = HAND_POSITION
	hand.rotation = HAND_ROTATION
	add_child(hand)
	if pose_holder != null:
		for child in pose_holder.get_children():
			var node := child as Node3D
			if node == null:
				continue
			if _mesh_count(node) == 0:
				node.free()
				continue
			pose_holder.remove_child(node)
			hand.add_child(node)
			poses.append(node)
	tools = Node3D.new()
	tools.name = "Tools"
	tools.position = HAND_POSITION
	tools.rotation = HAND_ROTATION
	add_child(tools)
	if device_holder != null:
		for child in device_holder.get_children():
			var node := child as Node3D
			if node == null:
				continue
			device_holder.remove_child(node)
			tools.add_child(node)
			devices.append(node)
	lamp_glove = Node3D.new()
	lamp_glove.name = "LampGlove"
	lamp_glove.position = LAMP_POSITION
	lamp_glove.rotation = LAMP_ROTATION
	add_child(lamp_glove)
	if lamp_holder != null:
		for child in lamp_holder.get_children():
			var node := child as Node3D
			if node == null:
				continue
			lamp_holder.remove_child(node)
			lamp_glove.add_child(node)
	# Mangas (dos por brazo) y codos, en el orden del exportador.
	for mesh in loose:
		add_child(mesh)
		if String(mesh.name).begins_with("Mesh5") and sleeves.size() < 4:
			sleeves.append(mesh)
		else:
			pads.append(mesh)
	for sleeve in sleeves:
		sleeve.scale = Vector3(1.0, SLEEVE_LENGTH_SCALE, 1.0)
	root.free()
	for sleeve in sleeves:
		sleeve_caps.append([_cap(sleeve), _cap(sleeve)])
	_tint_materials()
	_view_light = OmniLight3D.new()
	_view_light.name = "ViewLight"
	_view_light.position = Vector3(0.14, -0.06, -0.34)
	_view_light.light_color = Color(0.86, 0.9, 0.95)
	_view_light.light_energy = view_light_energy
	_view_light.omni_range = 1.6
	_view_light.shadow_enabled = false
	add_child(_view_light)


## Los materiales originales son matcap en la web (siempre legibles). Aquí se
## les da un 22 % de emisión propia para que las manos se lean también en las
## salas a oscuras, sin aplanarlas del todo.
## Tapa esférica con el mismo material que la manga.
func _cap(sleeve: MeshInstance3D) -> MeshInstance3D:
	var sphere := SphereMesh.new()
	sphere.radius = 0.058
	sphere.height = 0.116
	sphere.radial_segments = 14
	sphere.rings = 7
	var cap := MeshInstance3D.new()
	cap.mesh = sphere
	var material: Material = null
	if sleeve.mesh != null and sleeve.mesh.get_surface_count() > 0:
		material = sleeve.get_surface_override_material(0)
		if material == null:
			material = sleeve.mesh.surface_get_material(0)
	cap.material_override = material
	add_child(cap)
	return cap


func _mesh_count(node: Node) -> int:
	var total := 0
	var stack: Array[Node] = [node]
	while not stack.is_empty():
		var current: Node = stack.pop_back()
		if current is MeshInstance3D:
			total += 1
		for child in current.get_children():
			stack.push_back(child)
	return total


func _tint_materials() -> void:
	var seen := {}
	var stack: Array[Node] = [self]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		var mesh := node as MeshInstance3D
		if mesh != null and mesh.mesh != null:
			for index in mesh.mesh.get_surface_count():
				var material := mesh.mesh.surface_get_material(index) as StandardMaterial3D
				if material == null or seen.has(material):
					continue
				seen[material] = true
				var copy := material.duplicate() as StandardMaterial3D
				# La web oscurece el albedo del equipo un 22 % antes de pintarlo
				# con matcap: así el metal no se quema contra la luz de sala.
				copy.albedo_color = copy.albedo_color * 0.78
				copy.emission_enabled = true
				copy.emission = copy.albedo_color
				copy.emission_energy_multiplier = 0.10
				copy.roughness = minf(copy.roughness, 0.72)
				mesh.set_surface_override_material(index, copy)
		for child in node.get_children():
			stack.push_back(child)


func _find_player() -> NexusPlayer:
	var node: Node = get_parent()
	while node != null:
		var player := node as NexusPlayer
		if player != null:
			return player
		node = node.get_parent()
	return null


## Gesto de alcance (`Touch.ts`): se elige la pose y se lanza la animación.
func play_reach(style: StringName = &"flat") -> void:
	_reach_pose = style if POSE_NAMES.has(style) else &"flat"
	_reach_time = 0.0


## Retroceso al disparar un protocolo.
func kick(amount: float = 1.0) -> void:
	_kick = clampf(_kick + amount, 0.0, 1.0)


func pose_node(name: StringName) -> Node3D:
	var index := POSE_NAMES.find(name)
	return poses[index] if index >= 0 and index < poses.size() else null


func _process(delta: float) -> void:
	if not _built or hand == null:
		return
	_travel += delta
	_kick = maxf(0.0, _kick - delta * 4.0)
	_reach_time = minf(REACH_DURATION, _reach_time + delta)
	if _player != null:
		weapon = _player.active_weapon
		lamp = _player.flashlight_enabled
		first_person = _player.view.is_first_person()
	_animate(delta)


## Reproduce el bloque `update()` de `Touch.ts` en espacio de cámara.
func _animate(_delta: float) -> void:
	var size := get_viewport().get_visible_rect().size
	var aspect := size.x / maxf(1.0, size.y)
	var side := minf(1.0, aspect / 0.95)
	var bob := 0.004 * sin(_travel * 2.0) * sway_strength
	if _player != null and _player.view.is_first_person():
		bob += 0.006 * sin(_player.view.gait) * sway_strength
	var t := clampf(_reach_time / REACH_DURATION, 0.0, 1.0)
	var active := t < 1.0
	var f := sin(PI * t)
	# Mano derecha y equipo comparten transformación base.
	var base := Vector3(HAND_POSITION.x * side, HAND_POSITION.y + bob, HAND_POSITION.z + 0.032 * _kick)
	var rotation := Vector3(HAND_ROTATION.x + 0.13 * _kick, HAND_ROTATION.y, HAND_ROTATION.z)
	if active:
		base += Vector3(-0.04 * f, -0.15 * (1.0 - f), -0.12 * f)
	hand.position = base
	hand.rotation = rotation
	tools.position = base
	tools.rotation = rotation
	hand.visible = first_person and (active or weapon >= 0)
	tools.visible = first_person and weapon >= 0 and not active
	lamp_glove.position = Vector3(LAMP_POSITION.x * side, LAMP_POSITION.y + bob, LAMP_POSITION.z)
	lamp_glove.rotation = LAMP_ROTATION
	lamp_glove.visible = first_person and lamp
	# Pose activa: la del gesto mientras dura, la de agarre el resto del tiempo.
	pose = _reach_pose if active else &"grip"
	for index in poses.size():
		poses[index].visible = POSE_NAMES[index] == pose
	for index in devices.size():
		devices[index].visible = index == weapon
	_update_sleeves(side)
	if _view_light != null:
		_view_light.visible = hand.visible or lamp_glove.visible


## Mangas y codos: cadena hombro–codo–muñeca con el mismo tope de 0,595 m.
func _update_sleeves(side: float) -> void:
	if sleeves.size() < 4 or pads.size() < 2:
		return
	var right := _arm(1.0, hand, side)
	var left := _arm(-1.0, lamp_glove, side)
	_place_arm(sleeves[0], sleeves[1], pads[0], right)
	_place_arm(sleeves[2], sleeves[3], pads[1], left)


func _arm(sign: float, glove: Node3D, side: float) -> Dictionary:
	var shoulder := Vector3(sign * 0.19, -SHOULDER_DROP, 0.015)
	if side < 1.0:
		shoulder.x = sign * 0.19 * side
	var wrist := glove.position + (glove.transform.basis * Vector3(sign * 0.013, -0.024, 0.11))
	var delta := wrist - shoulder
	var length := delta.length()
	if length > ARM_REACH and length > 0.0001:
		wrist = shoulder + delta * (ARM_REACH / length)
		delta = wrist - shoulder
		length = ARM_REACH
	var direction := delta.normalized() if length > 0.0001 else Vector3(sign * 0.4, -0.9, 0.1).normalized()
	var bend := Vector3(sign * 0.62, -1.0, 0.22)
	bend = (bend - direction * bend.dot(direction)).normalized()
	var elbow := shoulder.lerp(wrist, 0.5) + bend * sqrt(maxf(0.0, 0.09 - shoulder.distance_squared_to(wrist) * 0.25))
	return {"shoulder": shoulder, "wrist": wrist, "elbow": elbow, "sign": sign, "active": glove.visible}


func _place_arm(forearm: MeshInstance3D, upper: MeshInstance3D, pad: MeshInstance3D, arm: Dictionary) -> void:
	var active: bool = arm["active"] and show_sleeves
	forearm.visible = active
	upper.visible = active and show_uppers
	pad.visible = active and show_uppers
	if not active:
		_hide_caps(forearm)
		_hide_caps(upper)
		return
	var sign: float = arm["sign"]
	var wrist: Vector3 = arm["wrist"]
	var elbow: Vector3 = arm["elbow"]
	var shoulder: Vector3 = arm["shoulder"]
	pad.position = elbow
	# El antebrazo baja recto hacia el borde inferior del encuadre; así su
	# extremo abierto queda siempre fuera de pantalla.
	var out := Vector3(sign * 0.2, -1.0, -0.35).normalized()
	var length := SLEEVE_LENGTH
	var start := wrist - out * 0.03
	var finish := wrist + out * length
	_segment(forearm, start, finish, length)
	_segment(upper, shoulder, elbow, maxf(0.2, shoulder.distance_to(elbow)))
	_place_caps(forearm, start, finish)


## Tapas esféricas de una manga (el lathe exportado es un tubo sin tapas).
func _place_caps(mesh: MeshInstance3D, start: Vector3, finish: Vector3) -> void:
	var index := sleeves.find(mesh)
	if index < 0 or index >= sleeve_caps.size():
		return
	var caps: Array = sleeve_caps[index]
	if caps.size() != 2:
		return
	(caps[0] as MeshInstance3D).position = start
	(caps[1] as MeshInstance3D).position = finish
	(caps[0] as MeshInstance3D).visible = true
	(caps[1] as MeshInstance3D).visible = true


func _hide_caps(mesh: MeshInstance3D) -> void:
	var index := sleeves.find(mesh)
	if index < 0 or index >= sleeve_caps.size():
		return
	for cap in sleeve_caps[index]:
		(cap as MeshInstance3D).visible = false


func _segment(mesh: MeshInstance3D, from: Vector3, to: Vector3, length: float) -> void:
	var delta := to - from
	mesh.position = from.lerp(to, 0.5)
	mesh.scale = Vector3(SLEEVE_GIRTH, length, SLEEVE_GIRTH)
	if delta.length() < 0.0001:
		return
	var up := Vector3.UP
	var direction := delta.normalized()
	if absf(up.dot(direction)) > 0.9999:
		mesh.quaternion = Quaternion.IDENTITY if direction.y > 0.0 else Quaternion(Vector3.RIGHT, PI)
	else:
		mesh.quaternion = Quaternion(up, direction)
