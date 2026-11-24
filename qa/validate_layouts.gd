extends SceneTree
## Auditoría de disposición (fase 25).
##
## Los módulos portados de la web (`Files.ts`, `Vault.ts`, `BenchCycle.ts`)
## colocaban sus bandejas, estaciones y cajones con las **coordenadas globales
## de la planta web**, que no coinciden con los volúmenes de las cáscaras
## nativas: había bandejas dentro de las paredes de otra sala.
##
## Este validador comprueba que:
##  1. Todo nodo posicionado de cada zona cae dentro de su rectángulo interior.
##  2. Los layouts de `FilesModule` y `VaultModule` caen dentro de la zona que
##     los hospeda.
##  3. Los puntos interactivos no se solapan entre sí.

var failures: Array[String] = []
var checks := 0

const ZONES := {
	"h01": "res://zones/zone_h01_hydraulics.tscn",
	"b02": "res://zones/zone_b02_turbines.tscn",
	"electrical": "res://zones/zone_electrical.tscn",
	"surveillance": "res://zones/zone_surveillance.tscn",
	"d02": "res://zones/zone_d02_records.tscn",
	"c04": "res://zones/zone_c04_shell.tscn",
	"v03_gallery": "res://zones/zone_v03_gallery.tscn",
	"v03_cryo": "res://zones/zone_v03_cryotheque.tscn",
	"a01": "res://zones/zone_a01_shell.tscn",
	"transit_hub": "res://zones/zone_transit_hub.tscn",
}

## Subárboles que no se auditan aquí: viven sobre una pared o en un vano
## (portales, sockets) o se validan en sus propios ficheros (mobiliario y
## módulos de contenido).
const SKIP_SUBTREES := ["Portal", "DoorSockets", "StructuralShell", "Dressing",
	"FilesModule", "VaultModule", "W01", "Displays"]

## Margen de tolerancia respecto al rectángulo interior (m).
const MARGIN := 1.2


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error("QA FAIL: %s" % message)
	else:
		print("QA PASS: ", message)


func _run() -> void:
	await _audit_zone_scenes()
	await _audit_files_layout()
	await _audit_vault_layout()
	await _audit_device_visuals()
	var passed := failures.is_empty()
	print(JSON.stringify({"checks": checks, "failures": failures, "passed": passed}))
	quit(0 if passed else 1)


## Los dispositivos interactivos tienen que verse: mallas, no sólo colisión.
func _audit_device_visuals() -> void:
	var cases := {
		"res://zones/zone_electrical.tscn": ["OperationsRoom"],
		"res://zones/zone_surveillance.tscn": ["OperationsRoom"],
		"res://zones/zone_d02_records.tscn": ["FilesModule"],
		"res://zones/zone_v03_gallery.tscn": ["VaultModule"],
		"res://zones/zone_b02_turbines.tscn": ["Bench"],
		"res://zones/zone_h01_hydraulics.tscn": ["Bench"],
	}
	for path: String in cases:
		var packed: PackedScene = load(path)
		if packed == null:
			_check(false, "%s: escena para auditar dispositivos" % path)
			continue
		var zone: Node3D = packed.instantiate()
		root.add_child(zone)
		await process_frame
		for group_name: String in cases[path]:
			var group := zone.get_node_or_null(group_name)
			_check(group != null, "%s: grupo %s" % [path.get_file(), group_name])
			if group == null:
				continue
			for child in group.get_children():
				var meshes := _mesh_count(child)
				_check(meshes >= 4, "%s/%s: dispositivo visible (%d mallas)"
					% [path.get_file(), child.name, meshes])
		zone.queue_free()
		await process_frame


## Mallas visibles bajo un nodo (incluidos sus hijos).
func _mesh_count(node: Node) -> int:
	var total := 1 if node is MeshInstance3D else 0
	for child in node.get_children():
		total += _mesh_count(child)
	return total


func _room(zone: String) -> Array:
	return ZoneDressing.ROOMS.get(StringName(zone), [-20.0, 20.0, -20.0, 20.0, 9.4])


## Un punto (x, z) cae dentro del rectángulo de la zona.
func _inside(zone: String, x: float, z: float, margin := MARGIN) -> bool:
	var room := _room(zone)
	return x > float(room[0]) - margin and x < float(room[1]) + margin \
 and z > float(room[2]) - margin and z < float(room[3]) + margin


func _audit_zone_scenes() -> void:
	for zone: String in ZONES:
		var packed: PackedScene = load(ZONES[zone])
		_check(packed != null, "%s: escena cargable" % zone)
		if packed == null:
			continue
		var instance: Node3D = packed.instantiate()
		root.add_child(instance)
		await process_frame
		var outside: Array[String] = []
		_scan(instance, zone, outside, 0)
		_check(outside.is_empty(), "%s: nodos de zona dentro de la sala (%d fuera)%s" % [
			zone, outside.size(), "" if outside.is_empty() else " → " + ", ".join(outside)])
		instance.queue_free()
		await process_frame


## Recorre la zona (dos niveles) buscando nodos fuera de la sala por su
## posición global; los contenedores se recorren, el mobiliario no.
func _scan(node: Node, zone: String, outside: Array[String], depth: int) -> void:
	if depth > 2:
		return
	for child in node.get_children():
		var spatial := child as Node3D
		if spatial == null or _skip(String(spatial.name)):
			continue
		var position := spatial.global_position if spatial.is_inside_tree() else spatial.position
		if position != Vector3.ZERO and not _inside(zone, position.x, position.z):
			if outside.size() < 6:
				outside.append("%s%s" % [spatial.name, position])
			else:
				outside.append("…")
		_scan(spatial, zone, outside, depth + 1)


func _skip(label: String) -> bool:
	for prefix in SKIP_SUBTREES:
		if label.begins_with(prefix):
			return true
	return false


func _audit_files_layout() -> void:
	var files := FilesModule.new()
	files.apply_web_layout()
	root.add_child(files)
	await process_frame
	_check(files.tray_count() == 10, "archivo: diez bandejas en el layout")
	var outside := 0
	var closest := 1.0e9
	for index in files.tray_count():
		var home: Vector3 = files.trays[index]["home"]
		if not _inside("d02", home.x, home.z):
			outside += 1
		for other in index:
			var other_home: Vector3 = files.trays[other]["home"]
			closest = minf(closest, home.distance_to(other_home))
	_check(outside == 0, "archivo: las diez bandejas caen dentro de D–02")
	_check(closest > 2.0, "archivo: bandejas separadas (mínimo %.2f m)" % closest)
	for index in files.tray_count():
		var rotation: float = files.trays[index]["rotation"]
		var forward := Vector3(sin(rotation), 0.0, cos(rotation))
		var home: Vector3 = files.trays[index]["home"]
		var front: Vector3 = home + forward * 1.5
		_check(_inside("d02", front.x, front.z, 0.0),
			"archivo: la boca de la bandeja %d mira al pasillo" % index)
	files.queue_free()
	await process_frame


func _audit_vault_layout() -> void:
	var vault := VaultModule.new()
	vault.apply_web_layout()
	root.add_child(vault)
	await process_frame
	_check(vault.stations.size() == 4, "bóveda: cuatro estaciones")
	var outside := 0
	for station in vault.stations:
		var point: Vector3 = station["position"]
		if not _inside("v03_gallery", point.x, point.z):
			outside += 1
	_check(outside == 0, "bóveda: las estaciones caen dentro de la galería V–03")
	var outside_drawers := 0
	for drawer in vault.drawers:
		if not _inside("v03_gallery", float(drawer["bx"]), float(drawer["bz"])):
			outside_drawers += 1
	_check(outside_drawers == 0, "bóveda: los cajones caen dentro de la galería V–03")
	# Los puestos no se pisan entre sí ni con los cajones.
	var points: Array[Vector3] = []
	for station in vault.stations:
		points.append(station["position"])
	for drawer in vault.drawers:
		points.append(Vector3(float(drawer["bx"]), 1.64, float(drawer["bz"])))
	var closest := 1.0e9
	for index in points.size():
		for other in range(index + 1, points.size()):
			closest = minf(closest, points[index].distance_to(points[other]))
	_check(closest > 2.0, "bóveda: puestos separados (mínimo %.2f m)" % closest)
	vault.queue_free()
	await process_frame
