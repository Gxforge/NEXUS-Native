extends SceneTree
## Valida los ojos de W–01: piezas originales + sistema de parpadeo y pupila.
##
## Contrato de `EyeSystem.ts` / `OcularSurface.ts`: siete ojos, dos párpados por
## ojo, parpadeo de 0,2 s cada 2,2–5,6 s, pupila que dilata con la agresividad y
## se achica con el pulso UV, iris que sigue al jugador y ojos que se cierran al
## recibir la descarga.

var checks := 0
var failures: Array[String] = []


func _check(name: String, condition: bool) -> void:
	checks += 1
	if not condition:
		failures.append(name)


func _init() -> void:
	var packed := load("res://assets/generated/w01_eyes.glb") as PackedScene
	if packed == null:
		print(JSON.stringify({"checks": 1, "failures": ["falta w01_eyes.glb"], "passed": false}))
		quit(1)
		return
	var root: Node3D = packed.instantiate()
	var eyes_root: Node = root.get_child(0)
	# 1. Piezas del exportador.
	var eyes := 0
	var meshes := 0
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if String(node.name).begins_with("primary-eye") or String(node.name).begins_with("secondary-eye-"):
			eyes += 1
		if node is MeshInstance3D:
			meshes += 1
		for child in node.get_children():
			stack.push_back(child)
	_check("siete ojos en el .glb (%d)" % eyes, eyes == 7)
	_check("cincuenta y seis mallas (ocho por ojo, %d)" % meshes, meshes == 56)

	# 2. Sistema montado.
	var sys := W01Eyes.new()
	root.add_child(sys)
	sys.attach(eyes_root)
	_check("el sistema recoge los siete ojos", sys.count() == 7)
	_check("dos párpados por ojo, catorce en total (%d)" % sys.lid_count(), sys.lid_count() == 14)
	_check("el ojo principal está marcado como tal", bool(sys.eyes[0]["is_main"]))

	# 3. Seguimiento: el iris mira al jugador y el ojo también, con menos recorrido.
	sys.update(0.0, 0.0, Vector3(6.0, 3.2, 4.0), 0.0)
	var main_iris := sys.iris_yaw(0)
	_check("el iris gira hacia el jugador (%.3f rad)" % main_iris, main_iris > 0.05 and main_iris <= 0.29)
	var secondary_iris := absf(sys.iris_yaw(1))
	_check("el ojo secundario gira menos (%.3f < %.3f)" % [secondary_iris, absf(main_iris)],
		secondary_iris < absf(main_iris))
	_check("el seguimiento está acotado (≤ 0,29 rad)", absf(main_iris) <= 0.2901)

	# 4. Pupila: dilata con la calma y se cierra con la agresividad.
	sys.update(0.0, 0.0, Vector3(0.0, 3.2, 6.0), 0.0)
	var calm := sys.pupil_scale(0)
	sys.update(0.0, 0.0, Vector3(0.0, 3.2, 6.0), 1.0)
	var angry := sys.pupil_scale(0)
	_check("la pupila se achica con la agresividad (%.3f → %.3f)" % [calm, angry], angry < calm)
	sys.update(0.0, 0.0, Vector3(0.0, 3.2, 6.0), 0.0)
	_check("la pupila dilata (≥ 0,64)", calm >= 0.64 and calm <= 1.08)

	# 5. Parpadeo: los párpados se cierran y vuelven a abrirse.
	var open_edge := sys.lid_position(0, true)
	sys.blink_timer = 0.0
	sys.update(0.1, 0.1, Vector3(0.0, 3.2, 6.0), 0.0)
	var blinking := sys.blinking
	sys.update(0.2, 0.05, Vector3(0.0, 3.2, 6.0), 0.0)
	var mid_edge := sys.lid_position(0, true)
	_check("el parpadeo arranca solo", blinking)
	_check("el párpado baja al parpadear (%.3f → %.3f)" % [open_edge, mid_edge], mid_edge < open_edge)
	sys.blink_time = 0.0
	sys.update(0.3, 0.2, Vector3(0.0, 3.2, 6.0), 0.0)
	_check("el párpado vuelve a su sitio", absf(sys.lid_position(0, true) - open_edge) < 0.02)

	# 6. Pulso UV: cierre inmediato de los siete ojos.
	sys.blink_timer = 99.0
	sys.blink_time = 0.0
	sys.flash()
	sys.update(0.3, 0.0, Vector3(0.0, 3.2, 6.0), 0.0)
	var shut := 0
	for index in 7:
		if sys.shut_of(index) > 0.5:
			shut += 1
	_check("el pulso UV cierra los siete ojos (%d)" % shut, shut == 7)
	var closed_edge := sys.lid_position(0, true)
	_check("el párpado llega al cierre (≤ −0,16 rad)", closed_edge <= -0.16)
	sys.update(0.4, 1.2, Vector3(0.0, 3.2, 6.0), 0.0)
	_check("los ojos se reabren tras la descarga", sys.shut_of(0) == 0.0)

	# 7. Metales: sin mapa de entorno, `metallic = 1` deja la carne en negro.
	var softened := W01Materials.soften(root)
	_check("se suavizan los materiales metálicos (%d superficies)" % softened, softened > 0)
	var metals := 0
	var high := 0
	stack = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		var mesh := node as MeshInstance3D
		if mesh != null and mesh.mesh != null:
			for surface in mesh.mesh.get_surface_count():
				var material := mesh.get_surface_override_material(surface) as BaseMaterial3D
				if material == null:
					continue
				metals += 1
				if material.metallic > W01Materials.METALLIC_LIMIT:
					high += 1
				if material.metallic > W01Materials.METALLIC_SOFT:
					failures.append("material sin suavizar en %s" % mesh.name)
					checks += 1
		for child in node.get_children():
			stack.push_back(child)
	_check("ningún metal queda a 1.0 (%d superficies revisadas)" % metals, high == 0)

	print(JSON.stringify({"checks": checks, "failures": failures, "passed": failures.is_empty()}))
	root.free()
	quit(0 if failures.is_empty() else 1)
