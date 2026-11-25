extends SceneTree
## Comprueba que el mobiliario que viene de la web se monta de verdad.
##
## Las fases 28 y 29 conectaron las exportaciones de `assets/generated/
## source-batch/` (vasos, larva, puerta de la bóveda, tornos, plano del eje,
## puesto de control, vehículo). Este validador carga las zonas y cuenta mallas
## para que nadie vuelva a sustituirlas por cajas sin que salte el QA.

var checks := 0
var failures: Array[String] = []


func _init() -> void:
	await process_frame
	await _check_h01()
	await _check_b02()
	await _check_gallery()
	await _check_cryo()
	await _check_hub()
	await _check_road()
	await _check_ceiling()
	await _check_lockers()
	await _check_panels()
	_check_screens()
	var passed := failures.is_empty()
	print(JSON.stringify({"checks": checks, "failures": failures, "passed": passed}))
	quit(0 if passed else 1)


func _check(name: String, condition: bool) -> void:
	checks += 1
	if not condition:
		failures.append(name)


func _load(path: String) -> Node3D:
	return (load(path) as PackedScene).instantiate() as Node3D


func _meshes(node: Node) -> int:
	var total := 1 if node is MeshInstance3D else 0
	for child in node.get_children():
		total += _meshes(child)
	return total


## Vasos de H–01: los tres grupos exportados, cada uno con su cristal y su larva.
func _check_h01() -> void:
	var zone := _load("res://zones/zone_h01_hydraulics.tscn")
	root.add_child(zone)
	await process_frame
	var dressing := zone.get_node_or_null("Dressing")
	_check("H–01: mobiliario presente", dressing != null)
	if dressing != null:
		var pods: Array = dressing.get("pods")
		_check("H–01: tres vasos", pods.size() == 3)
		for index in pods.size():
			var pod := pods[index] as Node3D
			_check("H–01: vaso %d con mallas del modelo original (%d)" % [index + 1, _meshes(pod)],
				_meshes(pod) >= 40)
		var specimens: Array = dressing.get("specimens")
		_check("H–01: tres larvas", specimens.size() == 3)
		if specimens.size() == 3:
			var larva := specimens[2] as Node3D
			_check("H–01: la larva sale de la exportación", _meshes(larva) >= 1)
			_check("H–01: el pivote de la larva escala a 0,42",
				is_equal_approx(larva.scale.x, 0.42))
	zone.queue_free()
	await process_frame


## Puerta de la bóveda de B–02.
func _check_b02() -> void:
	var zone := _load("res://zones/zone_b02_turbines.tscn")
	root.add_child(zone)
	await process_frame
	var door := zone.get_node_or_null("Dressing/VaultDoor")
	_check("B–02: puerta de la bóveda", door != null)
	if door != null:
		_check("B–02: puerta con el modelo original (%d mallas)" % _meshes(door),
			_meshes(door) >= 40)
	zone.queue_free()
	await process_frame


## Puesto de control de la galería V–03.
func _check_gallery() -> void:
	var zone := _load("res://zones/zone_v03_gallery.tscn")
	root.add_child(zone)
	await process_frame
	var dressing := zone.get_node_or_null("Dressing")
	var desk := dressing.get_node_or_null("GalleryDesk") if dressing != null else null
	var terminal := dressing.get_node_or_null("GalleryTerminal") if dressing != null else null
	_check("V–03: mostrador original", desk != null and _meshes(desk) >= 7)
	_check("V–03: terminal original", terminal != null and _meshes(terminal) >= 6)
	zone.queue_free()
	await process_frame


## Consolas de la crioteca.
func _check_cryo() -> void:
	var zone := _load("res://zones/zone_v03_cryotheque.tscn")
	root.add_child(zone)
	await process_frame
	var dressing := zone.get_node_or_null("Dressing")
	var panel := dressing.get_node_or_null("CryoConsole") if dressing != null else null
	var reader := dressing.get_node_or_null("CryoReader") if dressing != null else null
	_check("V–03 crioteca: consola original", panel != null and _meshes(panel) >= 10)
	_check("V–03 crioteca: lector original", reader != null and _meshes(reader) >= 4)
	zone.queue_free()
	await process_frame


## Tornos y plano del eje en el hub.
func _check_hub() -> void:
	var zone := _load("res://zones/zone_transit_hub.tscn")
	root.add_child(zone)
	await process_frame
	var dressing := zone.get_node_or_null("Dressing")
	for key in ["Torno1", "Torno2", "PlanoEje"]:
		var node := dressing.get_node_or_null(key) if dressing != null else null
		_check("Hub L–01: %s original" % key, node != null and _meshes(node) >= 1)
	zone.queue_free()
	await process_frame


## Vehículo en la calzada.
func _check_road() -> void:
	var zone := _load("res://zones/zone_transit_road.tscn")
	root.add_child(zone)
	await process_frame
	var vehicle := zone.get_node_or_null("Dressing/Vehicle")
	_check("Calzada: vehículo original", vehicle != null)
	if vehicle != null:
		_check("Calzada: chasis y cuatro ruedas (%d mallas)" % _meshes(vehicle),
			_meshes(vehicle) >= 30)
	zone.queue_free()
	await process_frame


## Luminarias originales: la web repite 38 veces la misma pieza de techo.
func _check_ceiling() -> void:
	var family := PropLibrary.family("laboratory_all_sectors", 4, Vector3(3.2, 0.3, 0.35))
	_check("Luminaria: pieza original del laboratorio", family != null)
	if family != null:
		_check("Luminaria: carcasa, difusor y dos tiras (%d mallas)" % PropLibrary.mesh_count(family),
			PropLibrary.mesh_count(family) == 4)
		_check("Luminaria: difusor localizado", PropLibrary.luminaire_diffuser(family) != null)
	var bank := PropLibrary.luminaires(4)
	_check("Luminaria: se clona sin compartir nodos", bank.size() == 4 and bank[0] != bank[1])
	var zones := {
		"c04": "res://zones/zone_c04_shell.tscn",
		"a01": "res://zones/zone_a01_shell.tscn",
		"h01": "res://zones/zone_h01_hydraulics.tscn",
	}
	for id in zones:
		var zone := _load(zones[id])
		root.add_child(zone)
		await process_frame
		var dressing := zone.get_node_or_null("Dressing")
		var lamps: Array[Node] = []
		if dressing != null:
			for child in dressing.get_children():
				if String(child.name).begins_with("Luminaire"):
					lamps.append(child)
		_check("%s: luminarias originales colocadas (%d)" % [id, lamps.size()], lamps.size() >= 2)
		var with_light := 0
		var with_meshes := 0
		for lamp in lamps:
			if lamp.get_node_or_null("Light") != null:
				with_light += 1
			if _meshes(lamp) >= 4:
				with_meshes += 1
		_check("%s: cada luminaria lleva su luz (%d/%d)" % [id, with_light, lamps.size()],
			with_light == lamps.size())
		_check("%s: cada luminaria mantiene sus cuatro mallas (%d/%d)" % [id, with_meshes, lamps.size()],
			with_meshes == lamps.size())
		zone.queue_free()
		await process_frame


## Taquillas originales (nueve puertas por banco) en C–04 y A–01.
func _check_lockers() -> void:
	var locker_zones := {"c04": "res://zones/zone_c04_shell.tscn", "a01": "res://zones/zone_a01_shell.tscn"}
	for id in locker_zones:
		var zone := _load(String(locker_zones[id]))
		root.add_child(zone)
		await process_frame
		var body := zone.get_node_or_null("Dressing/Lockers")
		_check("%s: bancos de taquillas originales" % id, body != null)
		if body != null:
			_check("%s: dos bancos de nueve puertas" % id, body.get_child_count() == 2)
			var bank := body.get_child(0)
			_check("%s: banco con trece mallas (%d)" % [id, _meshes(bank)], _meshes(bank) == 13)
		zone.queue_free()
		await process_frame


## Panel mural original en electricidad y vigilancia.
func _check_panels() -> void:
	var panel_zones := {"electrical": "res://zones/zone_electrical.tscn",
		"surveillance": "res://zones/zone_surveillance.tscn"}
	for id in panel_zones:
		var zone := _load(String(panel_zones[id]))
		root.add_child(zone)
		await process_frame
		var panel := zone.get_node_or_null("Dressing/WallPanel")
		_check("%s: panel mural original" % id, panel != null and _meshes(panel) == 5)
		zone.queue_free()
		await process_frame


## Las pantallas usan el plano exportado, no un cuadrilátero generado.
func _check_screens() -> void:
	for pair in [["display", "phosphor"], ["telemetry_screen", "telemetry"]]:
		var original := PropLibrary.screen(String(pair[0]))
		_check("Pantalla %s: plano original" % String(pair[0]), not original.is_empty())
		if not original.is_empty():
			var expected: Vector2 = Vector2(1.0, 0.5) if String(pair[0]) == "display" else Vector2(2.36, 1.33)
			var size: Vector2 = original["size"]
			_check("Pantalla %s: %.2f × %.2f m" % [String(pair[0]), size.x, size.y],
				absf(size.x - expected.x) < 0.02 and absf(size.y - expected.y) < 0.02)
		var screen := WallScreen.new()
		screen.kind = String(pair[1])
		root.add_child(screen)
		await process_frame
		var face := screen.get_node_or_null("Face") as MeshInstance3D
		_check("Pantalla %s: cara con el plano original" % String(pair[1]),
			face != null and face.mesh != null and face.mesh.get_surface_count() > 0)
		if face != null and face.mesh != null:
			var vertices: PackedVector3Array = face.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
			_check("Pantalla %s: plano de cuatro vértices (%d)" % [String(pair[1]), vertices.size()],
				vertices.size() == 4)
		screen.queue_free()
		await process_frame
