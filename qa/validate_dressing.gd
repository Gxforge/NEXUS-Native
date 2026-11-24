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

	await _validate_animation()

	var passed := failures.is_empty()
	print(JSON.stringify({"checks": checks, "failures": failures, "passed": passed}))
	quit(0 if passed else 1)


## La animación del mobiliario replica el contrato de `Pods.update` de la web.
func _validate_animation() -> void:
	var h01 := await _dressing("res://zones/zone_h01_hydraulics.tscn")
	_check(h01 != null, "animación: H–01 cargada")
	if h01 != null:
		var bubbles: Array = h01.get("bubbles")
		var specimens: Array = h01.get("specimens")
		_check(bubbles.size() == 3, "animación: tres grupos de burbujas")
		_check(specimens.size() == 3, "animación: tres larvas animadas")
		if bubbles.size() == 3 and specimens.size() == 3:
			var group: Array = bubbles[0]
			_check(group.size() == 48, "animación: 48 burbujas por vaso")
			h01.call("animate", 0.0)
			var start_y: float = (group[0] as Node3D).position.y
			var start_scale: Vector3 = (specimens[0] as Node3D).scale
			h01.call("animate", 1.0)
			var next_y: float = (group[0] as Node3D).position.y
			_check(absf(next_y - start_y) > 0.05, "animación: las burbujas ascienden")
			var in_range := true
			for bubble in group:
				var y: float = (bubble as Node3D).position.y
				if y < 0.9 or y > 3.7:
					in_range = false
			_check(in_range, "animación: las burbujas no salen del líquido")
			_check((specimens[0] as Node3D).scale != start_scale,
				"animación: la larva late")
			var rotation_a: float = (specimens[0] as Node3D).rotation.y
			h01.call("animate", 2.4)
			_check((specimens[0] as Node3D).rotation.y != rotation_a,
				"animación: la larva gira sobre sí misma")
			h01.call("animate", 1.0)
			_check(is_equal_approx((group[0] as Node3D).position.y, next_y),
				"animación: reproducible para el mismo instante")
		h01.queue_free()

	var b02 := await _dressing("res://zones/zone_b02_turbines.tscn")
	if b02 != null:
		var fans: Array = b02.get("fans")
		var indicators: Array = b02.get("indicators")
		_check(fans.size() == 4, "animación: cuatro aspas giratorias")
		_check(indicators.size() >= 4, "animación: testigos de las turbinas")
		if fans.size() == 4:
			(b02 as Node3D).call("animate", 0.0)
			var first: float = (fans[0] as Node3D).rotation.z
			(b02 as Node3D).call("animate", 1.5)
			_check(absf((fans[0] as Node3D).rotation.z - first) > 0.5,
				"animación: las aspas giran")
			_check(absf((fans[3] as Node3D).rotation.z - (fans[0] as Node3D).rotation.z) > 0.1,
				"animación: cada turbina lleva su ritmo")
		b02.queue_free()

	var c04 := await _dressing("res://zones/zone_c04_shell.tscn")
	if c04 != null:
		var rings: Array = c04.get("rings")
		_check(rings.size() == 6, "animación: seis anillos de contención")
		if rings.size() == 6:
			(c04 as Node3D).call("animate", 0.0)
			var scale_a: float = (rings[0] as MeshInstance3D).scale.x
			(c04 as Node3D).call("animate", 0.98)
			_check(absf((rings[0] as MeshInstance3D).scale.x - scale_a) > 0.0005,
				"animación: la malla respira")
		c04.queue_free()
	await process_frame


func _dressing(path: String) -> Node3D:
	var packed: PackedScene = load(path)
	if packed == null:
		return null
	var zone: Node3D = packed.instantiate()
	root.add_child(zone)
	await process_frame
	return zone.get_node_or_null("Dressing") as Node3D


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
			var door: Node = dressing.get_node_or_null("VaultDoor")
			var door_meshes := 0
			if door != null:
				var stack: Array[Node] = [door]
				while not stack.is_empty():
					var node: Node = stack.pop_back()
					if node is MeshInstance3D:
						door_meshes += 1
					for child in node.get_children():
						stack.push_back(child)
			_check(door_meshes >= 40, "B–02: puerta de la bóveda con su modelo original (%d mallas)" % door_meshes)
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
			_check(dressing.get_node_or_null("C04Catwalk") != null, "C–04: pasarela perimetral")
			_check(dressing.get_node_or_null("C04Gantry") != null, "C–04: pórtico de mantenimiento")
			_check(dressing.get_node_or_null("C04Forklift") != null, "C–04: carretilla de escala humana")
			_check(_count_prefixed(dressing, "C04Cone") == 5, "C–04: cinco conos de balizamiento")
			_check(screens.size() >= 3, "C–04: banco de tres pantallas")
			var feed := dressing.get_node_or_null("C04Feed") as TelemetryFeed
			_check(feed != null and feed.screen != null,
				"C–04: la primera pantalla muestra telemetría viva")


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
