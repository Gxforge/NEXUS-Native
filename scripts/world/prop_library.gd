class_name PropLibrary
extends RefCounted
## Modelos originales de la web (`assets/generated/source-batch/`).
##
## Los `.glb` de `source-batch` son exportaciones directas de la escena de
## three.js: cada grupo conserva la transformación que tenía en el laboratorio
## original, incluidos los vasos de observación (`workshop_pods.glb`), la puerta
## de la bóveda (`vault.glb`) y los puestos de mando (`vault.glb`).
##
## Se cargan una sola vez y se reparten los grupos; la raíz exportada se libera
## para no dejar duplicados en memoria.

const BATCH := "res://assets/generated/source-batch/"

static var _cache := {}


## Grupos de primer nivel de un lote, ya separados de la escena exportada.
## Devuelve `{nombre: Node3D}` con las transformaciones originales intactas.
static func groups(asset: String) -> Dictionary:
	if _cache.has(asset):
		var cached: Dictionary = _cache[asset]
		var alive := true
		for key in cached:
			if not is_instance_valid(cached[key]):
				alive = false
				break
		if alive:
			return cached
	var packed := load(BATCH + asset + ".glb") as PackedScene
	var found := {}
	if packed != null:
		var root: Node = packed.instantiate()
		var wrapper: Node = root.get_child(0) if root.get_child_count() > 0 else root
		for child in wrapper.get_children():
			var node := child as Node3D
			if node == null:
				continue
			wrapper.remove_child(node)
			found[String(node.name)] = node
		root.free()
	_cache[asset] = found
	return found


## Vasos de observación de H–01, en el orden de la web (z = −66,6 / −62 / −57,4).
static func pods() -> Array[Node3D]:
	var result: Array[Node3D] = []
	var found := groups("workshop_pods")
	for key in ["Node2", "Node15", "Node29"]:
		var node := found.get(key) as Node3D
		if node != null:
			result.append(node)
	return result


## Puerta de la bóveda V–03 tal como se modeló en la web (grupo `Node2`).
static func vault_door() -> Node3D:
	var found := groups("vault")
	return found.get("Node2") as Node3D


## Grupo suelto de un lote (`null` si el lote no lo trae).
static func group(asset: String, key: String) -> Node3D:
	return groups(asset).get(key) as Node3D


## Hijos de primer nivel de un lote **en orden de exportación**.
##
## `groups()` indexa por nombre, y en `laboratory_all_sectors.glb` la web agrupa
## todo bajo `Node`: los 195 hijos se llaman igual. Aquí se devuelven en orden y
## se identifican por forma (número de mallas y caja envolvente).
static var _flat := {}


static func children_of(asset: String) -> Array[Node3D]:
	if _flat.has(asset):
		var cached: Array[Node3D] = _flat[asset]
		var alive := true
		for node in cached:
			if not is_instance_valid(node):
				alive = false
				break
		if alive:
			return cached
	var list: Array[Node3D] = []
	var packed := load(BATCH + asset + ".glb") as PackedScene
	if packed != null:
		var root: Node = packed.instantiate()
		var wrapper: Node = root.get_child(0) if root.get_child_count() > 0 else root
		for child in wrapper.get_children():
			var node := child as Node3D
			if node == null:
				continue
			wrapper.remove_child(node)
			list.append(node)
		root.free()
	_flat[asset] = list
	return list


## Mallas de un subárbol.
static func mesh_count(node: Node) -> int:
	var total := 0
	var stack: Array[Node] = [node]
	while not stack.is_empty():
		var current: Node = stack.pop_back()
		if current is MeshInstance3D:
			total += 1
		for child in current.get_children():
			stack.push_back(child)
	return total


## Caja envolvente de las mallas de un subárbol, en su espacio local.
static func bounds(node: Node) -> AABB:
	var box := AABB()
	var first := true
	var stack: Array[Node] = [node]
	while not stack.is_empty():
		var current: Node = stack.pop_back()
		var mesh := current as MeshInstance3D
		if mesh != null and mesh.mesh != null:
			var local: AABB = mesh.get_aabb()
			box = local if first else box.merge(local)
			first = false
		for child in current.get_children():
			stack.push_back(child)
	return box


## Plantilla de una familia del lote: mismo número de mallas y tamaño (±tolerancia).
##
## `laboratory_all_sectors.glb` trae el laboratorio entero (195 grupos, miles de
## mallas). Se busca la pieza, se guarda una copia y **se libera el resto**: si no,
## el lote completo se queda residente y el juego acaba sin memoria al cambiar de
## zona.
static var _templates := {}


static func family(asset: String, meshes: int, size: Vector3, tolerance := 0.25) -> Node3D:
	var key := "%s|%d|%.2f|%.2f|%.2f" % [asset, meshes, size.x, size.y, size.z]
	if _templates.has(key) and is_instance_valid(_templates[key]):
		return _templates[key] as Node3D
	var found: Node3D = null
	var list := children_of(asset)
	for node in list:
		if not is_instance_valid(node):
			continue
		if mesh_count(node) != meshes:
			continue
		var box := bounds(node)
		if absf(box.size.x - size.x) <= tolerance and absf(box.size.y - size.y) <= tolerance \
				and absf(box.size.z - size.z) <= tolerance:
			found = node
			break
	if found == null:
		return null
	var template := found.duplicate() as Node3D
	for node in list:
		if is_instance_valid(node):
			node.free()
	_flat.erase(asset)
	_templates[key] = template
	return template


## Copias independientes de una familia lista para colgar de una zona.
static func instances(asset: String, meshes: int, size: Vector3, count_: int,
		tolerance := 0.25) -> Array[Node3D]:
	var result: Array[Node3D] = []
	var template := family(asset, meshes, size, tolerance)
	if template == null:
		return result
	for index in count_:
		var copy := template.duplicate() as Node3D
		if copy == null:
			continue
		result.append(copy)
	return result


## Luminaria de techo original del laboratorio: 3,20 × 0,30 × 0,35 m, cuatro
## mallas (carcasa, difusor y dos tiras). La web la repite 38 veces.
static func luminaires(count_: int) -> Array[Node3D]:
	return instances("laboratory_all_sectors", 4, Vector3(3.2, 0.3, 0.35), count_)


## Banco de taquillas original: 3,22 m de lado con nueve puertas de 0,79 × 1,25.
static func lockers(count_: int) -> Array[Node3D]:
	return instances("laboratory_all_sectors", 13, Vector3(3.2, 3.2, 1.0), count_)


## Panel mural original: 2,88 × 3,84 m con listón ámbar.
static func wall_panel(count_: int) -> Array[Node3D]:
	return instances("laboratory_all_sectors", 5, Vector3(2.9, 3.8, 0.2), count_)


## Malla del difusor de una luminaria (la única con material sombreado claro).
static func luminaire_diffuser(node: Node) -> MeshInstance3D:
	var stack: Array[Node] = [node]
	while not stack.is_empty():
		var current: Node = stack.pop_back()
		var mesh := current as MeshInstance3D
		if mesh != null and mesh.mesh != null and mesh.mesh.get_surface_count() > 0:
			var material := mesh.mesh.surface_get_material(0) as StandardMaterial3D
			if material != null and material.albedo_color.to_html(false) == "9dd4dd":
				return mesh
		for child in current.get_children():
			stack.push_back(child)
	return null


## Plano original de una pantalla (`display` 1,0 × 0,5 o `telemetry_screen` 2,36 × 1,33).
## Devuelve `{"mesh": Mesh, "size": Vector2}` o un diccionario vacío.
static func screen(asset: String) -> Dictionary:
	var packed := load(BATCH + asset + ".glb") as PackedScene
	if packed == null:
		return {}
	var root: Node = packed.instantiate()
	var mesh_node: MeshInstance3D = null
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var current: Node = stack.pop_back()
		var mesh := current as MeshInstance3D
		if mesh != null and mesh.mesh != null:
			mesh_node = mesh
			break
		for child in current.get_children():
			stack.push_back(child)
	if mesh_node == null:
		root.free()
		return {}
	var box := mesh_node.get_aabb()
	var result := {"mesh": mesh_node.mesh, "size": Vector2(box.size.x, box.size.y)}
	root.free()
	return result


## Una luminaria lista para colgar (copia independiente de la plantilla).
static func luminaire() -> Node3D:
	var template := family("laboratory_all_sectors", 4, Vector3(3.2, 0.3, 0.35))
	return template.duplicate() as Node3D if template != null else null


## Un banco de taquillas de nueve puertas.
static func locker() -> Node3D:
	var template := family("laboratory_all_sectors", 13, Vector3(3.2, 3.2, 1.0))
	return template.duplicate() as Node3D if template != null else null


## Un panel mural de 2,88 × 3,84 m.
static func wall_panel_node() -> Node3D:
	var template := family("laboratory_all_sectors", 5, Vector3(2.9, 3.8, 0.2))
	return template.duplicate() as Node3D if template != null else null


## Coche de vía (`vehicle.glb`): cuerpo y cuatro ruedas en orden de exportación.
##
## El lote exporta cinco grupos sueltos (el cuerpo `Node2` y las ruedas `Node5` a
## `Node8`); se devuelven dentro de un contenedor para poder montarlos de una vez.
static func vehicle() -> Node3D:
	var container := Node3D.new()
	container.name = "Vehicle"
	for node in children_of("vehicle"):
		container.add_child(node)
	return container if container.get_child_count() > 0 else null
