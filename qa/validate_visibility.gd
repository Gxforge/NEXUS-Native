extends SceneTree
## Valida el recorte por portales de `Visibility.ts`: candidatos y cajas,
## particiones sacadas del grafo, aberturas vivas de las compuertas, el
## criterio conservador (nunca se oculta lo que cruza el plano) y el restaurar.

var checks := 0
var failures: Array[String] = []


class StubDoor extends Node3D:
	var aperture := 0.0
	func apply_aperture(value: float) -> void:
		aperture = value


func _check(name: String, condition: bool) -> void:
	checks += 1
	if not condition:
		failures.append(name)


func _near(name: String, value: float, expected: float, tolerance := 0.001) -> void:
	_check("%s (%.3f ≈ %.3f)" % [name, value, expected], absf(value - expected) <= tolerance)


func _box(parent: Node3D, at: Vector3, size := 1.0, node_name := "Box") -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.name = node_name
	var shape := BoxMesh.new()
	shape.size = Vector3(size, size, size)
	mesh.mesh = shape
	parent.add_child(mesh)
	mesh.global_position = at
	return mesh


func _graph() -> Dictionary:
	return {"connections": [
		{"id": "test_bulkhead", "world_door": [0.0, 0.0], "width": 4.4, "portal_yaw_from": 180.0},
		{"id": "test_side", "world_door": [10.0, 6.0], "width": 4.4, "portal_yaw_from": 90.0},
	]}


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame

	# 1. Particiones: las que la web afina a mano salen del grafo real.
	var graph_file := FileAccess.open("res://data/zone_graph.json", FileAccess.READ)
	_check("el grafo de zonas se puede leer", graph_file != null)
	var real: Dictionary = JSON.parse_string(graph_file.get_as_text()) as Dictionary
	graph_file.close()
	var real_parts := Visibility.partitions_for(real)
	_check("sólo las seis paredes opacas del grafo son particiones (%d)" % real_parts.size(),
		real_parts.size() == 6)
	var by_id := {}
	for part in real_parts:
		by_id[str(part["id"])] = part
	_near("la compuerta de electricidad abre 2,28 m", float(by_id["c04_electrical"]["half"]), 2.28)
	_near("electricidad se prueba a partir de |x| > 17,6", float(by_id["c04_electrical"]["lateral"]), 17.6)
	_near("la compuerta de la bóveda abre 1,7 m", float(by_id["v03_cryo_v03_gallery"]["half"]), 1.7)
	_near("la bóveda recorta a 3,4 m de alto", float(by_id["v03_cryo_v03_gallery"]["height"]), 3.4)
	_check("electricidad y vigilancia son planos perpendiculares a z",
		str(by_id["c04_electrical"]["axis"]) == "z" and str(by_id["c04_surveillance"]["axis"]) == "z")
	_check("los dos laboratorios laterales son planos perpendiculares a x",
		str(by_id["h01_v03_gallery"]["axis"]) == "x" and str(by_id["d02_v03_gallery"]["axis"]) == "x")
	var sideways := 0
	for part in real_parts:
		if str(part["axis"]) == "x":
			sideways += 1
	_check("sólo dos conexiones son laterales (%d)" % sideways, sideways == 2)
	var h01: Array = by_id["h01_v03_gallery"]["span"]
	_near("la galería de H-01 abre entre −70 y −54", float(h01[1]) - float(h01[0]), 16.0)
	var has_a01 := false
	for part in real_parts:
		if str(part["id"]) == "a01_c04":
			has_a01 = true
	_check("el vano abierto de A-01 no se recorta", not has_a01)
	_check("sin el filtro salen las once conexiones del grafo (%d)"
		% Visibility.partitions_for(real, false).size(),
		Visibility.partitions_for(real, false).size() == 11)
	_near("el plano de electricidad se desplaza a z 58,2", float(by_id["c04_electrical"]["plane"]), 58.2)
	_near("el vano de electricidad se desplaza a x 35", float(by_id["c04_electrical"]["center"]), 35.0)
	var main_script := load("res://scripts/core/main.gd") as GDScript
	var constants: Dictionary = main_script.get_script_constant_map() if main_script != null else {}
	_check("el desplazamiento coincide con el de `Main` (%s)" % str(constants.get("SCENE_OFFSET_2D")),
		constants.has("SCENE_OFFSET_2D")
		and (constants["SCENE_OFFSET_2D"] as Vector2).is_equal_approx(Visibility.SCENE_OFFSET))
	_near("la galería de H-01 está del lado negativo", float(by_id["h01_v03_gallery"]["sign"]), -1.0)

	# 2. Candidatos, márgenes y omisión de la malla de contención.
	var world := Node3D.new()
	world.name = "World"
	root.add_child(world)
	var plain := _box(world, Vector3(20, 1, -5), 1.0, "Plain")
	var tray := Node3D.new()
	tray.name = "Tray"
	world.add_child(tray)
	tray.set_meta("use", "tray_2")
	_box(tray, Vector3(20, 1, -5), 1.0, "TrayMesh")
	tray.global_position = Vector3.ZERO
	var hull := Node3D.new()
	hull.name = "Hull"
	world.add_child(hull)
	hull.set_meta("mobile_hull", true)
	_box(hull, Vector3(20, 1, -5), 1.0, "HullMesh")
	var view := Visibility.new()
	view.configure(world, _graph(), [], false, Vector2.ZERO)
	_check("los candidatos son la malla y la bandeja, no la malla de contención (%d)" % view.candidate_count(),
		view.candidate_count() == 2)
	_near("el margen normal es 0,15 m por lado", view.entry_box(plain).size.x, 1.3)
	_near("la bandeja crece 1,4 m por lado", view.entry_box(tray).size.x, 3.8)

	# 3. Abertura abierta: se oculta lo que queda por completo detrás y fuera
	# del vano, y se conserva lo que cruza el plano o está del lado de la cámara.
	var camera := Vector3(0.0, 1.7, 10.0)
	var far_side := _box(world, Vector3(20, 1, -5), 1.0, "FarSide")
	var in_vanes := _box(world, Vector3(0, 1, -5), 1.0, "InVanes")
	var straddle := _box(world, Vector3(20, 1, 0), 1.0, "Straddle")
	var near_side := _box(world, Vector3(20, 1, 5), 1.0, "NearSide")
	var too_high := _box(world, Vector3(0, 7, -5), 1.0, "TooHigh")
	view.configure(world, _graph(), [], false, Vector2.ZERO)
	view.apply(camera)
	_check("lo que queda fuera del vano se oculta", not far_side.visible)
	_check("lo que se ve por el vano se conserva", in_vanes.visible)
	_check("lo que cruza el plano de la compuerta se conserva", straddle.visible)
	_check("lo que está del lado de la cámara se conserva", near_side.visible)
	_check("lo que pasa por encima del vano se oculta", not too_high.visible)
	_check("el recuento coincide con lo oculto (%d)" % view.hidden_count(), view.hidden_count() == 4)
	_check("la malla de contención nunca se toca", hull.get_child(0).visible)

	# 4. Compuerta cerrada y restaurar.
	var door := StubDoor.new()
	door.name = "Door"
	world.add_child(door)
	door.global_position = Vector3(0, 0, 0)
	var center_far := _box(world, Vector3(0, 1, -5), 1.0, "CenterFar")
	view.configure(world, _graph(), [door], false, Vector2.ZERO)
	_near("una compuerta cerrada deja la abertura en cero", view.factor(0), 0.0)
	view.apply(camera)
	_check("con la compuerta cerrada también se oculta lo centrado", not center_far.visible)
	door.apply_aperture(1.0)
	_near("abrir la compuerta sube el factor a 1", view.factor(0), 1.0)
	view.apply(camera)
	_check("con la compuerta abierta vuelve a verse", center_far.visible)
	view.restore()
	var all_visible := true
	for node in world.find_children("*", "MeshInstance3D", true, false):
		if not (node as Node3D).visible:
			all_visible = false
	_check("restaurar devuelve la visibilidad a todo", all_visible and view.hidden_count() == 0)

	# 5. Laboratorio lateral: el vano vive en un plano perpendicular a x.
	var side_far := _box(world, Vector3(5, 1, 12), 1.0, "SideFar")
	var side_near := _box(world, Vector3(5, 1, 6), 1.0, "SideNear")
	view.configure(world, _graph(), [], false, Vector2.ZERO)
	view.apply(Vector3(20.0, 1.7, 6.0))
	_check("en el laboratorio lateral se oculta lo que queda fuera de la galería", not side_far.visible)
	_check("el vano del laboratorio conserva lo que se ve por él", side_near.visible)

	# 6. Bandera de la galería de la bóveda (el `open` del original).
	view.configure(world, real, [])
	var gallery_index := -1
	for index in view.partition_count():
		if str(real_parts[index]["id"]) == "b02_v03_gallery":
			gallery_index = index
	_check("la galería de B-02 está entre las particiones", gallery_index >= 0)
	_near("sin abrir, la galería está cerrada", view.factor(gallery_index), 0.0)
	view.set_gallery_open(true)
	_near("al abrirla, la abertura es de 3,35 m", view.factor(gallery_index), 1.0)
	_check("abrir la galería no altera las demás", is_equal_approx(view.factor(0) + view.factor(1), 2.0))

	# 7. Reconstruir la lista cuando cambian las zonas cargadas.
	var extra := _box(world, Vector3(20, 1, -5), 1.0, "Extra")
	view.configure(world, _graph(), [], false, Vector2.ZERO)
	_check("configurar reconstruye la lista de cajas (%d)" % view.candidate_count(),
		view.candidate_count() == 11)
	view.apply(camera)
	_check("tras reconstruir el recorte sigue funcionando", not extra.visible and center_far.visible)
	view.rebuild()
	_check("una segunda reconstrucción no duplica entradas (%d)" % view.candidate_count(),
		view.candidate_count() == 11)
	view.restore()
	_check("reconstruir no deja nada oculto para siempre", extra.visible and far_side.visible)

	world.queue_free()

	print(JSON.stringify({"checks": checks, "failures": failures, "passed": failures.is_empty()}))
	quit(0 if failures.is_empty() else 1)
