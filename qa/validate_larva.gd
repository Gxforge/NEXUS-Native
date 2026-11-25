extends SceneTree
## Valida el gesto de las larvas de H–01 (`Larva.ts` + `Workshop.Pods`).

const H01 := "res://zones/zone_h01_hydraulics.tscn"

var checks := 0
var failures: Array[String] = []


func _check(name: String, condition: bool) -> void:
	checks += 1
	if not condition:
		failures.append(name)


func _initialize() -> void:
	call_deferred("_run")


func _near(name: String, value: float, expected: float, tolerance := 0.001) -> void:
	_check("%s (%.4f ≈ %.4f)" % [name, value, expected], absf(value - expected) <= tolerance)


func _run() -> void:
	await process_frame
	var packed := load(H01) as PackedScene
	if packed == null:
		print(JSON.stringify({"checks": 1, "failures": ["falta " + H01], "passed": false}))
		quit(1)
		return
	var zone: Node3D = packed.instantiate()
	root.add_child(zone)
	await process_frame
	await process_frame

	var dressing: Node = zone.get_node_or_null("Dressing")
	if dressing == null:
		print(JSON.stringify({"checks": 1, "failures": ["falta el atrezzo de H-01"], "passed": false}))
		zone.queue_free()
		quit(1)
		return
	dressing.set_process(false)

	# 1. Tres vasos con su pivote y su larva original.
	_check("tres vasos de observación (%d)" % dressing.pods.size(), dressing.pods.size() == 3)
	_check("tres larvas con rig (%d)" % dressing.larva_rigs.size(), dressing.larva_rigs.size() == 3)
	var counts: Array[int] = []
	var eyes := 0
	for index in dressing.pods.size():
		var pod: Node3D = dressing.pods[index]
		var specimen := pod.get_node_or_null("Specimen") as Node3D
		_check("el vaso %d tiene pivote de latido" % (index + 1), specimen != null)
		if specimen == null:
			continue
		var larva: Node3D = specimen.get_node_or_null("Larva") if specimen.get_node_or_null("Larva") != null else _larva_child(specimen)
		if larva != null:
			larva.name = "Larva"
		_check("el vaso %d conserva la larva exportada" % (index + 1), larva != null)
		var rig: LarvaRig = dressing.larva_rigs[index] if index < dressing.larva_rigs.size() else null
		_check("el vaso %d tiene rig" % (index + 1), rig != null and rig.root == larva)
		if rig == null:
			continue
		counts.append(rig.feeler_count())
		_check("el vaso %d tiene %d tentáculos (%d)" % [index + 1, LarvaRig.expected_feelers(index), rig.feeler_count()],
			rig.feeler_count() == LarvaRig.expected_feelers(index))
		_check("el vaso %d conserva el ojo" % (index + 1), rig.has_eye())
		if rig.has_eye():
			eyes += 1
		# La nube de burbujas del exportador no puede ser la criatura.
		_check("la larva del vaso %d no es la nube de burbujas" % (index + 1),
			larva != null and not (larva is MeshInstance3D) and larva.get_child_count() >= 8)
		_check("la larva del vaso %d va a escala real" % (index + 1),
			absf(specimen.scale.x - 1.0) < 0.001 or absf(specimen.scale.x - 1.12) < 0.02)
	_check("los tentáculos crecen vaso a vaso (%s)" % str(counts),
		counts.size() == 3 and counts[0] == 8 and counts[1] == 9 and counts[2] == 10)
	_check("tres ojos (%d)" % eyes, eyes == 3)

	# 2. Gesto de los tentáculos, con las constantes de `Larva.ts`.
	var rig: LarvaRig = dressing.larva_rigs[0]
	var t := 7.3
	rig.sync(t)
	for j in [0, 3, rig.feeler_count() - 1]:
		var swing: float = LarvaRig.FEELER_SWAY * sin(t * LarvaRig.FEELER_RATE + float(j) * LarvaRig.FEELER_PHASE)
		var roll: float = LarvaRig.FEELER_ROLL * cos(t * LarvaRig.FEELER_ROLL_RATE + float(j) * LarvaRig.FEELER_ROLL_PHASE)
		_near("tentáculo %d gira en x" % j, rig.feelers[j].rotation.x, swing)
		_near("tentáculo %d gira en z" % j, rig.feelers[j].rotation.z, roll)
	_check("el vaivén de los tentáculos es pequeño",
		absf(rig.feelers[0].rotation.x) <= LarvaRig.FEELER_SWAY + 0.0001)
	_check("ningún tentáculo se queda quieto a 7,3 s",
		rig.feelers.any(func(f: Node3D) -> bool: return absf(f.rotation.x) > 0.001))

	# 3. Ojo: giro lento con la fase del índice.
	_near("el ojo gira en y", rig.eye.rotation.y, LarvaRig.EYE_YAW * sin(t * LarvaRig.EYE_YAW_RATE))
	_near("el ojo cabecea en x", rig.eye.rotation.x, LarvaRig.EYE_PITCH * cos(t * LarvaRig.EYE_PITCH_RATE))
	var rig2: LarvaRig = dressing.larva_rigs[1]
	rig2.sync(t)
	_check("cada vaso tiene su fase de ojo",
		absf(rig2.eye.rotation.y - rig.eye.rotation.y) > 0.001)

	# 4. Reset limpio.
	rig.reset()
	_check("el reset devuelve los tentáculos al reposo",
		absf(rig.feelers[0].rotation.x) < 0.0001 and absf(rig.feelers[0].rotation.z) < 0.0001
		and absf(rig.eye.rotation.y) < 0.0001)

	# 5. Latido sobre el pivote (`Workshop.Pods.update`).
	var specimen: Node3D = dressing.pods[0].get_node("Specimen")
	dressing.animate(5.0)
	var a: float = 5.0 * 3.1
	var pulse: float = pow(maxf(0.0, sin(a)), 5.0)
	_near("el corazón late en x", specimen.scale.x, 1.0 + pulse * 0.12)
	_near("el corazón se aplasta en y", specimen.scale.y, 1.0 - pulse * 0.065)
	_near("el corazón se mece", specimen.position.y, 2.25 + sin(a * 0.4) * 0.07, 0.002)
	_near("el corazón gira", specimen.rotation.y, 1.27 + sin(a * 0.23) * 0.23, 0.002)

	# 6. Burbujas: 48 por vaso, suben y reciclan a 2,75 m.
	var group: Array = dressing.bubbles[0]
	_check("cuarenta y ocho burbujas por vaso (%d)" % group.size(), group.size() == 48)
	dressing.animate(0.0)
	var low: float = (group[0] as Node3D).position.y
	dressing.animate(1.0)
	var up: float = (group[0] as Node3D).position.y
	_check("las burbujas suben (%.3f → %.3f)" % [low, up], up > low)
	dressing.animate(100.0)
	var top: float = -1.0
	for bubble in group:
		top = maxf(top, (bubble as Node3D).position.y)
	_check("las burbujas no salen del vaso (máx %.2f m)" % top, top <= 0.92 + 2.75)

	print(JSON.stringify({"checks": checks, "failures": failures, "passed": failures.is_empty()}))
	zone.queue_free()
	quit(0 if failures.is_empty() else 1)


func _larva_child(specimen: Node) -> Node3D:
	for child in specimen.get_children():
		var node := child as Node3D
		if node != null and not (node is MeshInstance3D):
			return node
	return null
