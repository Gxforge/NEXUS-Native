class_name W01Eyes
extends Node3D
## Los siete ojos de W–01 con parpadeo, pupila y seguimiento (port de
## `EyeSystem.ts` + `OcularSurface.ts`).
##
## El `.glb` exportado trae por cada ojo su cuenca, el lecho, el globo, el iris,
## la pupila, la córnea y los dos párpados, pero todos congelados en la pose de
## reposo. Aquí se reconstruyen los párpados con la misma fórmula paramétrica de
## la web (`Lid`) y se anima el iris, la pupila y la escala como en `update()`.

const BLINK_DURATION := 0.2
const BLINK_FIRST := 2.7
const BLINK_MIN := 2.2
const BLINK_SPREAD := 3.4
const FLASH_SHUT := 1.1

## Fases por ojo, en el orden del exportador (principal primero).
const PHASES: Array[float] = [0.0, 0.4, 1.1, 2.2, 0.8, 1.9, 2.6]

var eyes: Array[Dictionary] = []
var blink_timer := BLINK_FIRST
var blink_time := 0.0
var blinking := false


## Recoge los siete ojos de un subárbol exportado (`Eyes/W01_Seven_Eyes`).
func attach(eyes_root: Node) -> void:
	eyes.clear()
	for child in eyes_root.get_children():
		var root := child as Node3D
		if root == null:
			continue
		var record := {
			"root": root,
			"is_main": String(root.name).begins_with("primary"),
			"phase": PHASES[eyes.size()] if eyes.size() < PHASES.size() else 0.0,
			"base_scale": root.scale,
			"iris": root.get_node_or_null(_named(root, "Iris")) as Node3D,
			"pupil": root.get_node_or_null(_named(root, "Pupil")) as Node3D,
			"lids": [],
		}
		if record["iris"] != null:
			(record["iris"] as Node3D).set_meta("base_scale", (record["iris"] as Node3D).scale)
		if record["pupil"] != null:
			(record["pupil"] as Node3D).set_meta("base_scale", (record["pupil"] as Node3D).scale)
		var lids: Array = record["lids"]
		for suffix in ["LidTop", "LidBottom"]:
			var lid := root.get_node_or_null(_named(root, suffix)) as MeshInstance3D
			if lid == null:
				continue
			var node := LidNode.new()
			node.top = suffix == "LidTop"
			node.name = String(lid.name) + "_Live"
			node.base_scale = lid.scale
			node.position = lid.position
			var material: Material = lid.get_surface_override_material(0)
			if material == null and lid.mesh != null and lid.mesh.get_surface_count() > 0:
				material = lid.mesh.surface_get_material(0)
			# La web pinta los párpados a doble cara (`mat.side = DoubleSide`):
			# con recorte trasero el párpado reconstruido no se veía.
			if material is BaseMaterial3D:
				var sided := (material as BaseMaterial3D).duplicate() as BaseMaterial3D
				sided.cull_mode = BaseMaterial3D.CULL_DISABLED
				material = sided
			node.material_override = material
			node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			lid.get_parent().add_child(node)
			lid.visible = false
			node.rebuild(0.0)
			lids.append(node)
		record["lids"] = lids
		eyes.append(record)


## Nombre real de una pieza dentro del ojo (`Eye0_Iris`, `Eye3_Pupil`…).
func _named(root: Node3D, suffix: String) -> String:
	for child in root.get_children():
		if String(child.name).ends_with(suffix):
			return String(child.name)
	return ""


func count() -> int:
	return eyes.size()


func lid_count() -> int:
	var total := 0
	for record in eyes:
		total += (record["lids"] as Array).size()
	return total


## Muestra u oculta los párpados reconstruidos (diagnóstico y capturas).
func set_lids_visible(value: bool) -> void:
	for record in eyes:
		for lid in record["lids"]:
			(lid as LidNode).visible = value


## Cierre inmediato de los siete ojos (pulso UV).
func flash() -> void:
	for record in eyes:
		(record["root"] as Node3D).set_meta("shut", FLASH_SHUT)


func shut_of(index: int) -> float:
	if index < 0 or index >= eyes.size():
		return 0.0
	return float((eyes[index]["root"] as Node3D).get_meta("shut", 0.0))


func pupil_scale(index: int) -> float:
	if index < 0 or index >= eyes.size():
		return 0.0
	var pupil := eyes[index]["pupil"] as Node3D
	if pupil == null:
		return 0.0
	var base: Vector3 = pupil.get_meta("base_scale", Vector3.ONE)
	return pupil.scale.y / maxf(base.y, 0.0001)


func iris_yaw(index: int) -> float:
	if index < 0 or index >= eyes.size():
		return 0.0
	var iris := eyes[index]["iris"] as Node3D
	return iris.rotation.y if iris != null else 0.0


func lid_position(index: int, top: bool) -> float:
	if index < 0 or index >= eyes.size():
		return 0.0
	for lid in eyes[index]["lids"]:
		if (lid as LidNode).top == top:
			return (lid as LidNode).edge()
	return 0.0


## Reproduce `EyeSystem.update()`: parpadeo, seguimiento, pupila y escala.
func update(time: float, delta: float, player: Vector3, aggression: float) -> void:
	blink_timer -= delta
	if blink_timer <= 0.0 and blink_time <= 0.0:
		blink_time = BLINK_DURATION
		blink_timer = BLINK_MIN + randf() * BLINK_SPREAD
	var progress := 0.0
	if blink_time > 0.0:
		progress = sin((1.0 - blink_time / BLINK_DURATION) * PI)
	blink_time = maxf(0.0, blink_time - delta)
	blinking = blink_time > 0.0
	for index in eyes.size():
		var record: Dictionary = eyes[index]
		var root := record["root"] as Node3D
		if root == null or not is_instance_valid(root):
			continue
		var is_main: bool = record["is_main"]
		var phase: float = record["phase"]
		var offset := player - (root.global_position if root.is_inside_tree() else root.position)
		var look := 1.0 / maxf(2.6, offset.length())
		var tracking := 1.0 if is_main else 0.55
		var iris := record["iris"] as Node3D
		if iris != null:
			iris.rotation.y = clampf(offset.x * look * 0.46 * tracking, -0.29, 0.29)
			iris.rotation.x = clampf(-offset.y * look * 0.34 * tracking, -0.18, 0.18)
		root.rotation.y = clampf(offset.x * look * 0.13 * tracking, -0.16, 0.16)
		root.rotation.x = clampf(-offset.y * look * 0.1 * tracking, -0.12, 0.12)
		var pupil := record["pupil"] as Node3D
		if pupil != null:
			var base: Vector3 = pupil.get_meta("base_scale", Vector3.ONE)
			var dilation := 0.88 + 0.17 * sin(time * 0.77 + phase) - aggression * 0.12
			var scale := clampf(dilation, 0.64, 1.08)
			pupil.scale = Vector3(base.x * scale * 0.72, base.y * scale, base.z)
			pupil.position.z = 0.05 * (1.0 - scale) * base.z
		var shut := maxf(0.0, float(root.get_meta("shut", 0.0)) - delta)
		root.set_meta("shut", shut)
		var amount := maxf(minf(1.0, shut * 5.0), progress * 0.97)
		for lid in record["lids"]:
			(lid as LidNode).rebuild(amount)
		var twitch := 1.0 if is_main else 0.45
		var base_scale: Vector3 = record["base_scale"]
		root.scale = Vector3(base_scale.x * (1.0 + sin(time * 2.1 + phase) * 0.008 * twitch),
			base_scale.y, base_scale.z)


## Párpado paramétrico de `OcularSurface.ts` (33 × 8 vértices, dos capas).
class LidNode extends MeshInstance3D:
	var top := true
	var base_scale := Vector3.ONE
	var _blink := -1.0

	func edge() -> float:
		var rest := 0.94 if top else -1.1
		var shut := -0.19 + (-0.02 if top else 0.02)
		return lerpf(rest, shut, clampf(_blink, 0.0, 1.0))

	func rebuild(blink: float) -> void:
		if absf(_blink - blink) < 0.002:
			return
		_blink = blink
		var rows := 7
		var columns := 32
		var rest := 0.94 if top else -1.1
		var shut := -0.19 + (-0.02 if top else 0.02)
		var edge_angle := lerpf(rest, shut, clampf(blink, 0.0, 1.0))
		var tool := SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		for j in rows + 1:
			for i in columns + 1:
				var t := 0.006 + (float(i) / float(columns)) * (PI - 0.012)
				var x := -cos(t)
				var h := sin(t)
				var a := lerpf(edge_angle, (1.97 if top else -1.97), float(j) / float(rows))
				tool.add_vertex(Vector3(x * 1.049, 0.768 * h * sin(a), 0.567 * h * cos(a) + 0.023))
		for j in rows:
			for i in columns:
				var n := j * (columns + 1) + i
				var b := n + columns + 1
				if top:
					for index in [n, n + 1, b, b, n + 1, b + 1]:
						tool.add_index(index)
				else:
					for index in [n, b, n + 1, n + 1, b, b + 1]:
						tool.add_index(index)
		tool.generate_normals()
		var mesh := tool.commit()
		mesh.surface_set_material(0, material_override)
		self.mesh = mesh
		scale = base_scale
