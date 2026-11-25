extends SceneTree
## Valida el equipo de primera persona: piezas originales, poses, visibilidad
## por protocolo y animación de alcance.
##
## El contrato viene de `src/scene/Touch.ts`: seis poses de guante, tres
## instrumentos ópticos, un guante de linterna y dos mangas por brazo, todo
## colgado de la cámara.

var _checks := 0
var _failures: Array[String] = []


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


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


func _init() -> void:
	var main: Node = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	for index in 8:
		await process_frame
	var player: Node = main.get_node("PersistentWorld/Player")
	var camera: Camera3D = main.get_node("PersistentWorld/Player/Camera3D")
	var rig: FirstPersonRig = main.get_node("PersistentWorld/Player/Camera3D/FirstPerson")

	# 1. El rig cuelga de la cámara y está montado con el modelo original.
	_check(rig != null, "falta el nodo FirstPerson bajo Camera3D")
	_check(rig.get_parent() == camera, "FirstPerson no cuelga de Camera3D")
	_check(rig._built, "el rig no se construyó")
	_check(player.rig == rig, "NexusPlayer.rig no apunta al rig")

	# 2. Seis poses de guante con las mallas del exportador.
	_check(rig.poses.size() == 6, "se esperaban 6 poses de guante, hay %d" % rig.poses.size())
	var expected: Array = [5, 5, 4, 5, 5, 5]
	for index in min(rig.poses.size(), expected.size()):
		var count := _mesh_count(rig.poses[index])
		_check(count == int(expected[index]),
			"pose %s con %d mallas (esperadas %d)" % [FirstPersonRig.POSE_NAMES[index], count, expected[index]])
	# 3. Tres instrumentos de siete mallas cada uno.
	_check(rig.devices.size() == 3, "se esperaban 3 instrumentos, hay %d" % rig.devices.size())
	for index in rig.devices.size():
		_check(_mesh_count(rig.devices[index]) == 7,
			"instrumento %d con %d mallas (esperadas 7)" % [index, _mesh_count(rig.devices[index])])
	# 4. Guante de linterna, mangas y codos.
	_check(rig.lamp_glove != null and _mesh_count(rig.lamp_glove) == 4, "el guante de linterna no tiene 4 mallas")
	_check(rig.sleeves.size() == 4, "se esperaban 4 mangas, hay %d" % rig.sleeves.size())
	_check(rig.pads.size() == 2, "se esperaban 2 codos, hay %d" % rig.pads.size())

	# 5. Transformaciones de la web (mano derecha, guante izquierdo).
	_check(rig.hand.position.distance_to(FirstPersonRig.HAND_POSITION) < 0.02,
		"la mano no está en la posición del contrato")
	_check(rig.tools.position.distance_to(rig.hand.position) < 0.001,
		"el equipo no comparte la transformación de la mano")

	# 6. Visibilidad según el protocolo activo.
	player.active_weapon = 0
	player.flashlight_enabled = false
	for index in 4:
		await process_frame
	_check(rig.tools.visible, "el equipo no se ve con un protocolo activo")
	_check(rig.devices[0].visible and not rig.devices[1].visible and not rig.devices[2].visible,
		"la visibilidad de los instrumentos no sigue al protocolo 0")
	_check(not rig.lamp_glove.visible, "el guante de linterna se ve con la linterna apagada")
	player.active_weapon = 2
	player.flashlight_enabled = true
	for index in 4:
		await process_frame
	_check(rig.devices[2].visible and not rig.devices[0].visible, "el protocolo 2 no muestra su instrumento")
	_check(rig.lamp_glove.visible, "el guante de linterna no aparece con la linterna encendida")
	player.active_weapon = -1
	for index in 4:
		await process_frame
	_check(not rig.tools.visible, "el equipo sigue a la vista sin protocolo activo")
	_check(not rig.hand.visible, "la mano sigue a la vista sin protocolo activo")

	# 7. Mangas apagadas por defecto: el tubo exportado se ve hueco de cerca.
	var hidden := true
	for sleeve in rig.sleeves:
		hidden = hidden and not sleeve.visible
	_check(rig.show_sleeves == false and hidden, "las mangas deberían estar apagadas por defecto")

	# 8. Gesto de alcance: pose elegida durante la animación y vuelta al agarre.
	player.active_weapon = 1
	for index in 3:
		await process_frame
	_check(rig.pose_node(&"grip") != null and rig.pose_node(&"grip").visible,
		"la pose de agarre no está activa en reposo")
	rig.play_reach(&"press")
	for index in 2:
		await process_frame
	_check(rig.pose_node(&"press").visible, "el gesto de presión no se activa")
	_check(not rig.pose_node(&"grip").visible, "la pose de agarre sigue visible durante el gesto")
	var travelled := rig.hand.position.distance_to(Vector3(
		FirstPersonRig.HAND_POSITION.x * 1.0, FirstPersonRig.HAND_POSITION.y, FirstPersonRig.HAND_POSITION.z))
	_check(travelled > 0.01, "la mano no se desplaza durante el gesto")
	rig._reach_time = FirstPersonRig.REACH_DURATION
	for index in 2:
		await process_frame
	_check(rig.pose_node(&"grip").visible, "la mano no vuelve al agarre al acabar el gesto")

	# 9. Retroceso y materiales legibles.
	rig.kick(1.0)
	for index in 2:
		await process_frame
	var kick_lift := rig.hand.position.z - FirstPersonRig.HAND_POSITION.z
	_check(kick_lift > 0.005, "el retroceso no desplaza la mano hacia la cámara")
	var emissive := 0
	var stack: Array[Node] = [rig]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		var mesh := node as MeshInstance3D
		if mesh != null and mesh.mesh != null:
			for surface in mesh.mesh.get_surface_count():
				var material := mesh.get_surface_override_material(surface) as StandardMaterial3D
				if material != null and material.emission_enabled:
					emissive += 1
		for child in node.get_children():
			stack.push_back(child)
	_check(emissive > 0, "ningún material del equipo tiene emisión propia")
	_check(rig.get_node_or_null("ViewLight") != null, "falta la luz de vista del equipo")

	print(JSON.stringify({"checks": _checks, "failures": _failures}))
	quit(0 if _failures.is_empty() else 1)
