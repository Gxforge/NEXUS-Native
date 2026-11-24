extends SceneTree
## Valida el mobiliario de Fase 24 (`ZoneDressing`) frente a la web.
##
## Comprueba que cada zona tiene su nodo `Dressing`, que el mobiliario cae
## dentro del volumen real del módulo (nunca dentro de las paredes ni por encima
## del techo), que las piezas clave existen y que la rotulación de sector está
## repartida por la nave.

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

## Rótulos de sector que la web reparte por la nave.
const SECTORS := ["HIDRÁULICA", "TURBINAS", "BÓVEDA", "REGISTROS", "CRIOTECA",
	"ELECTRICIDAD", "VIGILANCIA", "CONTENCIÓN", "GALERÍA", "ARCHIVO BIOMÉTRICO"]


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
	var labels: Dictionary = {}
	for id: String in ZONES:
		var packed: PackedScene = load(ZONES[id])
		_check(packed != null, "%s: la zona carga" % id)
		if packed == null:
			continue
		var zone: Node3D = packed.instantiate()
		root.add_child(zone)
		await process_frame
		var dressing: Node3D = zone.get_node_or_null("Dressing") as Node3D
		_check(dressing != null, "%s: tiene nodo Dressing" % id)
		if dressing == null:
			zone.queue_free()
			continue
		_check(String(dressing.get("zone_id")) == id, "%s: zone_id coincide" % id)
		var meshes: int = dressing.call("count_meshes", dressing)
		_check(meshes >= 20, "%s: mobiliario construido (%d mallas)" % [id, meshes])
		_check(dressing.get("built_meshes") == meshes, "%s: recuento cacheado" % id)
		var room: Array = dressing.call("room")
		var ceiling: float = float(room[4])
		var outside := 0
		var above := 0
		var stack: Array[Node] = [dressing]
		while not stack.is_empty():
			var node: Node = stack.pop_back()
			for child in node.get_children():
				stack.append(child)
			var mesh := node as MeshInstance3D
			if mesh == null or mesh.mesh == null:
				continue
			var box: AABB = mesh.global_transform * mesh.get_aabb()
			var center := box.get_center()
			var inside_volume := center.x > float(room[0]) - 0.6 and center.x < float(room[1]) + 0.6 \
				and center.z > float(room[2]) - 0.6 and center.z < float(room[3]) + 0.6
			if not inside_volume:
				outside += 1
			if box.position.y + box.size.y > ceiling + 0.9:
				above += 1
		_check(outside == 0, "%s: todo el mobiliario cae dentro de la sala (%d fuera)" % [id, outside])
		_check(above == 0, "%s: nada atraviesa el techo (%d piezas)" % [id, above])
		for label in _labels(dressing):
			labels[label] = true
		_check_zone_props(id, dressing)
		zone.queue_free()
		await process_frame

	for sector: String in SECTORS:
		_check(labels.has(sector), "rótulo de sector presente: %s" % sector)

	# El kit de construcción comparte materiales entre piezas.
	var kit_checks: Array[String] = []
	var material_a: StandardMaterial3D = BuildKit.material(BuildKit.METAL)
	var material_b: StandardMaterial3D = BuildKit.material(BuildKit.METAL)
	kit_checks.append("material cacheado" if material_a == material_b else "material duplicado")
	_check(kit_checks[0] == "material cacheado", "BuildKit comparte materiales")
	_check(BuildKit.METAL.to_html(false) == "53686c", "paleta METAL igual que la web")
	_check(BuildKit.GLOW.to_html(false) == "72f9e5", "paleta GLOW igual que la web")

	var passed := failures.is_empty()
	print(JSON.stringify({"checks": checks, "failures": failures, "passed": passed}))
	quit(0 if passed else 1)


func _check_zone_props(id: String, dressing: Node3D) -> void:
	var pods: Array = dressing.get("pods")
	var fans: Array = dressing.get("fans")
	var screens: Array = dressing.get("screens")
	match id:
		"h01":
			_check(pods.size() == 3, "H–01: tres vasos de observación")
			_check(_has_child(dressing, "Pods/Pod3/Specimen"), "H–01: larva en el tercer vaso")
		"b02":
			_check(fans.size() == 4, "B–02: cuatro turbinas")
			_check(_has_child(dressing, "VaultDoor"), "B–02: puerta de la bóveda")
			var bolts := 0
			var door: Node = dressing.get_node_or_null("VaultDoor")
			if door != null:
				for child in door.get_children():
					if String(child.name).begins_with("Bolt"):
						bolts += 1
			_check(bolts == 8, "B–02: ocho pestillos en la puerta")
		"v03_gallery":
			_check(_count_prefixed(dressing, "Arch") >= 7, "V–03: al menos siete arcos")
		"v03_cryo":
			_check(_count_prefixed(dressing, "CryoTank") == 12, "V–03: doce vitrinas")
		"surveillance":
			_check(screens.size() == 6, "Vigilancia: seis pantallas de CCTV")
			_check(dressing.get_node_or_null("CameraWall") != null, "Vigilancia: muro de cámaras")
		"d02":
			_check(_count_prefixed(dressing, "Drawer") == 9, "D–02: nueve archivadores")
		"electrical":
			_check(_count_prefixed(dressing, "Cabinet") >= 8, "Electricidad: armarios del cuadro")
		"c04":
			_check(dressing.get_node_or_null("ContainmentMesh") != null, "C–04: malla de contención")


func _has_child(root: Node, path: String) -> bool:
	return root.get_node_or_null(path) != null


func _count_prefixed(root: Node, prefix: String) -> int:
	var total := 0
	for child in root.get_children():
		if String(child.name).begins_with(prefix):
			total += 1
		total += _count_prefixed(child, prefix)
	return total


## Textos de los rótulos (`Label3D`) del mobiliario.
func _labels(root: Node) -> Array[String]:
	var texts: Array[String] = []
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		for child in node.get_children():
			stack.append(child)
		var label := node as Label3D
		if label != null and not label.text.is_empty():
			texts.append(label.text)
	return texts
