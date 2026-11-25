extends SceneTree
## Valida la mandíbula de W–01 (port de `Head.ts`).
##
## El `.glb` trae 26 dientes repartidos en dos arcos; la web los desplaza entre un
## ancla de reposo y una abierta al abrirse el morro, y amortigua la apertura a
## 16 s⁻¹.

var checks := 0
var failures: Array[String] = []


func _check(name: String, condition: bool) -> void:
	checks += 1
	if not condition:
		failures.append(name)


func _init() -> void:
	var packed := load("res://assets/generated/w01_core.glb") as PackedScene
	if packed == null:
		print(JSON.stringify({"checks": 1, "failures": ["falta w01_core.glb"], "passed": false}))
		quit(1)
		return
	var core: Node3D = packed.instantiate()
	var jaw := W01Jaw.new()
	core.add_child(jaw)
	jaw.attach(core)

	# 1. Dentadura completa y con recorrido.
	_check("se recogen los 26 dientes (%d)" % jaw.tooth_count(), jaw.tooth_count() == 26)
	var upper := 0
	var lower := 0
	var spread := 0.0
	for index in jaw.tooth_count():
		var travel := jaw.travel(index)
		if travel < -0.001:
			upper += 1
		elif travel > 0.001:
			lower += 1
		spread = maxf(spread, absf(travel))
	_check("los dos arcos se mueven (%d arriba, %d abajo)" % [upper, lower], upper > 0 and lower > 0)
	_check("el recorrido máximo ronda 0,34 m (%.3f)" % spread, spread > 0.2 and spread <= W01Jaw.SPREAD + 0.001)

	# 2. Amortiguación: nunca salta al valor pedido de golpe.
	jaw.update(0.016, 1.0)
	var first := jaw.drive
	_check("la apertura arranca, no salta (%.3f tras un frame)" % first, first > 0.0 and first < 0.4)
	for _frame in 40:
		jaw.update(0.016, 1.0)
	_check("la apertura alcanza el objetivo (%.3f)" % jaw.drive, jaw.drive > 0.98)
	jaw.update(0.016, 0.0)
	_check("y se cierra igual de suave (%.3f)" % jaw.drive, jaw.drive < 0.81)

	# 3. La malla sigue al valor: con 0,5 los dientes están a mitad de camino.
	jaw.update(0.0, 0.5)
	var mid := jaw.travel(0) * 0.5
	var node := jaw._teeth[0]["node"] as Node3D
	var rest := jaw._teeth[0]["rest"] as Vector3
	_check("los dientes siguen la apertura (%.3f)" % absf(node.position.y - rest.y),
		absf((node.position.y - rest.y) - mid) < 0.01)

	# 4. Fijado para capturas.
	jaw.pin(1.0)
	for _frame in 30:
		jaw.update(0.016, 0.0)
	_check("el fijado de captura manda sobre la IA (%.3f)" % jaw.drive, jaw.drive > 0.95)
	jaw.pin(-1.0)
	jaw.update(0.0, 0.25)
	_check("al soltar vuelve a la IA (0,25)", is_equal_approx(jaw.drive, 0.25))

	print(JSON.stringify({"checks": checks, "failures": failures, "passed": failures.is_empty()}))
	core.free()
	quit(0 if failures.is_empty() else 1)
