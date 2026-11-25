class_name Visibility
extends RefCounted

## Recorte por portales, port de `Visibility.ts`.
##
## Se rechaza sólo un objeto entero cuando queda por completo detrás de una
## partición opaca. Si su caja cruza el plano de la abertura se conserva. La
## lista de candidatos se reconstruye (nunca la física) cuando cambian las
## zonas cargadas; el resto de la lógica es la de la web: proyectar la silueta
## de la caja sobre el plano de la compuerta a través de la cámara y comparar
## con la abertura viva. Con la compuerta cerrada la abertura mide cero y sólo
## sobrevive lo que ya está del lado de la cámara.

const MARGIN := 0.15
const TRAY_MARGIN := 1.4
const DOOR_MATCH := 0.9
const DEFAULT_HALF := 2.28
const DEFAULT_HEIGHT := 4.55
## Desplazamiento con el que se montan las zonas nativas respecto al plano de
## la web (`Main.SCENE_OFFSET_2D`); sin él las particiones caen 9 m a la
## izquierda y 14 m por detrás. `qa/validate_visibility.gd` comprueba que las
## dos constantes coinciden.
const SCENE_OFFSET := Vector2(9.0, 14.0)
const MIN_APERTURE := 0.012
const SIDE_SPAN := 8.0

## Las cuatro compuertas y los dos laboratorios laterales que la web afina a
## mano sobre el plano del complejo. El resto de conexiones del grafo usa los
## valores por defecto. `lateral` es la prueba de `z === 44.2 || z === 52.2`:
## electricidad y vigilancia viven desplazadas a partir de |x| > 17,6.
const SITE_TUNING := {
	"b02_v03_gallery": {"half": 3.35, "height": 6.1},
	"v03_cryo_v03_gallery": {"half": 1.7, "height": 3.4},
	"c04_electrical": {"half": 2.28, "height": 4.55, "lateral": 17.6},
	"c04_surveillance": {"half": 2.28, "height": 4.55, "lateral": 17.6},
	"h01_v03_gallery": {"half": 2.17, "height": 4.02, "span": [-70.0, -54.0], "sign": -1.0},
	"d02_v03_gallery": {"half": 2.17, "height": 4.02, "span": [-90.0, -74.0], "sign": 1.0},
}

var gallery_open := false
var _partitions: Array[Dictionary] = []
var _entries: Array[Dictionary] = []
var _hidden: Array = []
var _doors: Array[Node3D] = []
var _root: Node3D
var _rebuilds := 0
var _applies := 0

## Las particiones salen del grafo de zonas (`world_door`, `width` y la
## orientación del portal) con los afinados de la web encima. Sólo son opacas
## las seis paredes que la web recorta; el resto de conexiones del complejo son
## vanos abiertos en la malla nativa y recortarlas ahí borraría mobiliario que
## se ve (comprobado en la captura de A-01).
static func partitions_for(graph: Dictionary, opaque_only := true, offset := SCENE_OFFSET) -> Array[Dictionary]:
	var built: Array[Dictionary] = []
	for entry: Dictionary in graph.get("connections", []):
		var door: Array = entry.get("world_door", [])
		if door.size() < 2:
			continue
		var id := str(entry.get("id", ""))
		if opaque_only and not SITE_TUNING.has(id):
			continue
		var tuning: Dictionary = SITE_TUNING.get(id, {})
		var yaw := float(entry.get("portal_yaw_from", 0.0))
		var sideways := absf(yaw - 90.0) < 1.0 or absf(yaw + 90.0) < 1.0
		var x := float(door[0]) + offset.x
		var z := float(door[1]) + offset.y
		var center := z if sideways else x
		var span := Vector2(center - SIDE_SPAN, center + SIDE_SPAN)
		var raw_span: Array = tuning.get("span", [])
		if raw_span.size() == 2:
			span = Vector2(float(raw_span[0]) + offset.y, float(raw_span[1]) + offset.y)
		built.append({
			"id": id,
			"axis": "x" if sideways else "z",
			"plane": x if sideways else z,
			"center": center,
			"half": float(tuning.get("half", DEFAULT_HALF)),
			"height": float(tuning.get("height", DEFAULT_HEIGHT)),
			"lateral": float(tuning.get("lateral", 0.0)),
			"span": [span.x, span.y],
			"sign": float(tuning.get("sign", 1.0)),
		})
	return built

func configure(root: Node3D, graph: Dictionary, doors: Array = [], opaque_only := true,
		offset := SCENE_OFFSET) -> void:
	_root = root
	_partitions = partitions_for(graph, opaque_only, offset)
	_doors.clear()
	for door in doors:
		if door is Node3D:
			_doors.append(door)
	rebuild()

func set_gallery_open(open: bool) -> void:
	gallery_open = open

func rebuild() -> void:
	restore()
	_entries.clear()
	_rebuilds += 1
	if _root == null:
		return
	_walk(_root)

func _walk(node: Node) -> void:
	if node is Node3D and (node as Node3D).has_meta("mobile_hull"):
		return
	if node is Node3D and _is_candidate(node as Node3D):
		var box := _world_bounds(node as Node3D)
		if box.size.length_squared() > 0.0:
			var margin := TRAY_MARGIN if _is_tray(node) else MARGIN
			box = box.grow(margin)
			_entries.append({"node": node as Node3D, "box": box})
		return
	for child in node.get_children():
		_walk(child)

## La zona entera nunca es candidata (su caja cruza todos los planos): se
## desciende hasta sus props, que es lo que hace la web con el grupo del
## complejo.
func _is_candidate(node: Node3D) -> bool:
	if node is ZoneRoot:
		return false
	return node is MeshInstance3D or node.has_meta("use") or node.has_meta("scan") or node.has_meta("survey_id")

func _is_tray(node: Node3D) -> bool:
	var use := str(node.get_meta("use", ""))
	var survey := str(node.get_meta("survey_id", ""))
	return use.begins_with("tray") or survey.contains("tray")

func _world_bounds(node: Node3D) -> AABB:
	var box := AABB()
	var found := false
	if node is MeshInstance3D:
		var mesh := node as MeshInstance3D
		if mesh.mesh != null:
			box = mesh.global_transform * mesh.get_aabb()
			found = true
	for child in node.get_children():
		if not child is Node3D:
			continue
		var inner := _world_bounds(child as Node3D)
		if inner.size.length_squared() <= 0.0:
			continue
		box = inner if not found else box.merge(inner)
		found = true
	return box if found else AABB()

func door_for(index: int) -> Node3D:
	if index < 0 or index >= _partitions.size():
		return null
	var part: Dictionary = _partitions[index]
	var plane := float(part["plane"])
	var center := float(part["center"])
	var sideways := str(part["axis"]) == "x"
	var best: Node3D = null
	var best_distance := DOOR_MATCH
	for door in _doors:
		var point := door.global_position
		var along := absf((point.x if sideways else point.z) - plane)
		var across := absf((point.z if sideways else point.x) - center)
		if along > best_distance or across > best_distance:
			continue
		best = door
		best_distance = maxf(along, across)
	return best

## Abertura viva de la partición: 0 cerrada, 1 abierta. Sin compuerta en la
## escena se considera abierta salvo la galería de la bóveda, que sigue la
## bandera `gallery_open` (el `open` del original).
func factor(index: int) -> float:
	if index < 0 or index >= _partitions.size():
		return 1.0
	var part: Dictionary = _partitions[index]
	var door := door_for(index)
	var raw := 1.0
	if door != null and door.has_method("apply_aperture"):
		raw = clampf(float(door.get("aperture")), 0.0, 1.0)
	elif door == null and str(part["id"]) == "b02_v03_gallery":
		raw = 1.0 if gallery_open else 0.0
	return raw

## Comprueba contra la geometría real que la partición es un muro: lanza rayos
## a través del plano a un lado y otro del vano, a tres alturas. Sin muro la
## partición se descarta (en el complejo nativo muchas conexiones son vanos
## abiertos porque el streaming ya descarga la zona vecina). Devuelve cuántas
## particiones sobreviven.
func probe(world: World3D, min_hits := 2) -> int:
	if world == null:
		return _partitions.size()
	var space := world.direct_space_state
	var kept: Array[Dictionary] = []
	for part in _partitions:
		if _wall_hits(space, part) >= min_hits:
			kept.append(part)
	_partitions = kept
	return _partitions.size()

func _wall_hits(space: PhysicsDirectSpaceState3D, part: Dictionary) -> int:
	var hits := 0
	var plane := float(part["plane"])
	var center := float(part["center"])
	var half := float(part["half"])
	var sideways := str(part["axis"]) == "x"
	for side: float in [-1.0, 1.0]:
		var across: float = center + side * (half + 0.9)
		for height: float in [0.8, 1.6, 3.0]:
			if float(part["height"]) < height:
				continue
			var from: Vector3
			var to: Vector3
			if sideways:
				from = Vector3(plane + 0.9, height, across)
				to = Vector3(plane - 0.9, height, across)
			else:
				from = Vector3(across, height, plane + 0.9)
				to = Vector3(across, height, plane - 0.9)
			var query := PhysicsRayQueryParameters3D.create(from, to, 0xFFFFFFFF, [])
			if not space.intersect_ray(query).is_empty():
				hits += 1
	return hits

## Devuelve cuántos objetos quedaron ocultos en esta pasada.
func apply(camera: Vector3) -> int:
	restore()
	_applies += 1
	for entry in _entries:
		# La zona se libera al transferir: la entrada puede apuntar a un nodo
		# ya liberado hasta la siguiente reconstrucción.
		var raw: Variant = entry["node"]
		if not is_instance_valid(raw):
			continue
		var node := raw as Node3D
		if node == null or not node.visible:
			continue
		var box: AABB = entry["box"]
		if _occluded(box, camera):
			node.visible = false
			_hidden.append(node)
	return _hidden.size()

func _occluded(box: AABB, camera: Vector3) -> bool:
	for index in _partitions.size():
		if _behind_partition(index, box, camera):
			return true
	return false

func _behind_partition(index: int, box: AABB, camera: Vector3) -> bool:
	var part: Dictionary = _partitions[index]
	var sideways := str(part["axis"]) == "x"
	if sideways:
		return _behind_side_lab(part, box, camera)
	return _behind_bulkhead(part, box, camera, float(factor(index)))

func _behind_bulkhead(part: Dictionary, box: AABB, camera: Vector3, factor_value: float) -> bool:
	var plane := float(part["plane"])
	var center := float(part["center"])
	var beyond := camera.z > plane
	if beyond:
		if box.end.z >= plane:
			return false
	else:
		if box.position.z <= plane:
			return false
	var lateral := float(part["lateral"])
	if lateral > 0.0:
		if beyond and not (camera.x > lateral if center > 0.0 else camera.x < -lateral):
			return false
		if not beyond and not (box.position.x > lateral + 0.01 if center > 0.0 else box.end.x < -lateral - 0.01):
			return false
	var width := float(part["half"]) * factor_value
	if width <= 0.0:
		return true
	var low := INF
	var high := -INF
	var low_y := INF
	for zz: float in [box.position.z, box.end.z]:
		var ratio: float = _ratio(plane - camera.z, zz - camera.z)
		for x: float in [box.position.x, box.end.x]:
			var value: float = camera.x + (x - camera.x) * ratio
			low = minf(low, value)
			high = maxf(high, value)
		low_y = minf(low_y, camera.y + (box.position.y - camera.y) * ratio)
	return low > center + width or high < center - width or low_y > float(part["height"])

func _behind_side_lab(part: Dictionary, box: AABB, camera: Vector3) -> bool:
	var plane_x := float(part["plane"])
	var center := float(part["center"])
	var width := float(part["half"]) * _factor_of(part)
	if width < MIN_APERTURE:
		return true
	var span: Array = part["span"]
	var lo := float(span[0])
	var hi := float(span[1])
	var sign_value := float(part["sign"])
	var near := sign_value * (camera.x - plane_x) > 0.0
	if near:
		if camera.z <= lo or camera.z >= hi:
			return false
		if (box.end.x >= plane_x) if sign_value > 0.0 else (box.position.x <= plane_x):
			return false
	else:
		if box.position.z <= lo or box.end.z >= hi:
			return false
		if (box.position.x <= plane_x) if sign_value > 0.0 else (box.end.x >= plane_x):
			return false
	var first := _ratio(plane_x - camera.x, box.position.x - camera.x)
	var second := _ratio(plane_x - camera.x, box.end.x - camera.x)
	var low := camera.z + minf((box.position.z - camera.z) * first, (box.position.z - camera.z) * second)
	var high := camera.z + maxf((box.end.z - camera.z) * first, (box.end.z - camera.z) * second)
	return low > center + width or high < center - width

func _factor_of(part: Dictionary) -> float:
	for index in _partitions.size():
		if _partitions[index] == part:
			return factor(index)
	return 1.0

func _ratio(numerator: float, denominator: float) -> float:
	if absf(denominator) < 0.000001:
		return INF if numerator >= 0.0 else -INF
	return numerator / denominator

func restore() -> void:
	for raw in _hidden:
		if is_instance_valid(raw) and raw is Node3D:
			(raw as Node3D).visible = true
	_hidden.clear()

## Caja (en espacio de mundo) que se usa para decidir; sólo para pruebas y depuración.
func entry_box(node: Node3D) -> AABB:
	for entry in _entries:
		if entry["node"] == node:
			return entry["box"]
	return AABB()

func hidden_count() -> int:
	return _hidden.size()

func candidate_count() -> int:
	return _entries.size()

func partition_ids() -> PackedStringArray:
	var ids := PackedStringArray()
	for part in _partitions:
		ids.append(str(part["id"]))
	return ids

func partition_count() -> int:
	return _partitions.size()

func rebuilds() -> int:
	return _rebuilds

func applies() -> int:
	return _applies
