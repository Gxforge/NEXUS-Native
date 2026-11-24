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
