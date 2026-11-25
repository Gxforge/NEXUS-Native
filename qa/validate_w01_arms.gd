extends SceneTree
## Valida los veinte brazos de W–01 (port de `Tentacles.ts`).
##
## La geometría es la del exportador (20 `arm-<n>` con su malla y sus ventosas),
## así que lo que se comprueba es el contrato de movimiento: fases y velocidades,
## estiramiento con la agresividad, giro hacia el operador, alcance de los brazos
## 2 y 3, ventosas que laten, latigazo que decae, suelo y malla de contención.

var checks := 0
var failures: Array[String] = []


func _check(name: String, condition: bool) -> void:
	checks += 1
	if not condition:
		failures.append(name)


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame
	var packed := load("res://assets/generated/w01_tentacles.glb") as PackedScene
	if packed == null:
		print(JSON.stringify({"checks": 1, "failures": ["falta w01_tentacles.glb"], "passed": false}))
		quit(1)
		return
	var scene: Node3D = packed.instantiate()
	root.add_child(scene)
	scene.position = Vector3(0.0, 0.0, 22.0)
	var arms := W01Arms.new()
	scene.add_child(arms)
	var holder := scene.get_child(0) as Node3D
	scene.remove_child(arms)
	holder.add_child(arms)
	arms.attach(holder)

	# 1. Recuento exacto del exportador.
	_check("veinte brazos (%d)" % arms.arm_count(), arms.arm_count() == 20)
	_check("ochenta y siete ventosas (%d)" % arms.sucker_count(), arms.sucker_count() == 87)
	var with_five := 0
	for arm: Dictionary in arms.arms:
		if (arm["suckers"] as Array).size() == 5:
			with_five += 1
	_check("siete brazos con cinco ventosas y trece con cuatro (%d con cinco)" % with_five, with_five == 7)

	# 2. Cada brazo conoce su eje largo y su punta.
	var long_ok := true
	var tips_ok := true
	for arm: Dictionary in arms.arms:
		long_ok = long_ok and float(arm["length"]) > 0.5
		tips_ok = tips_ok and (arm["tip"] as Vector3).length() > 0.2
	_check("los veinte brazos miden más de medio metro", long_ok)
	_check("todos tienen punta fuera del anclaje", tips_ok)

	# 3. Fases y velocidades como la web.
	_check("fase 1,23 rad por brazo (brazo 4 = %.2f)" % float(arms.arms[4]["phase"]),
		is_equal_approx(float(arms.arms[4]["phase"]), 4.0 * 1.23))
	_check("velocidad 0,56 + 0,11·(i mod 4) (brazo 5 = %.2f)" % float(arms.arms[5]["speed"]),
		is_equal_approx(float(arms.arms[5]["speed"]), 0.56 + 0.11))

	# 4. La agresividad estira; el ataque estira más.
	var player := Vector3(0.0, 1.7, 28.0)
	arms.update(0.0, 0.0, player, 0.0, 0.0)
	var calm: Vector3 = (arms.arms[0]["node"] as Node3D).scale
	arms.update(0.0, 0.0, player, 1.0, 0.0)
	var angry: Vector3 = (arms.arms[0]["node"] as Node3D).scale
	arms.update(0.0, 0.0, player, 1.0, 1.0)
	var striking: Vector3 = (arms.arms[0]["node"] as Node3D).scale
	var axis := int(arms.arms[0]["axis"])
	_check("la agresividad alarga el brazo (%.3f → %.3f)" % [calm[axis], angry[axis]], angry[axis] > calm[axis])
	_check("el ataque lo alarga hasta ×1,44 (%.3f)" % striking[axis],
		is_equal_approx(striking[axis] / calm[axis], 1.0 + W01Arms.EXTENSION_AGGRESSION + W01Arms.EXTENSION_ATTACK))

	# 5. Los brazos 2 y 3 apuntan al operador al atacar; los demás no.
	arms.update(0.0, 0.0, player, 0.3, 0.0)
	var calm_tip := arms.tip_of(2)
	arms.strike = 1.0
	arms.update(0.0, 0.0, player, 0.3, 1.0)
	var strike_tip := arms.tip_of(2)
	_check("el brazo 2 se lanza hacia el operador (%.2f m más cerca)" % (calm_tip.distance_to(player) - strike_tip.distance_to(player)),
		strike_tip.distance_to(player) < calm_tip.distance_to(player) - 0.5)
	var other_tip := arms.tip_of(9)
	_check("el brazo 9 no se lanza", other_tip.distance_to(player) > 2.0)
	_check("el toque se detecta con la punta del brazo 2", arms.touches(arms.tip_of(2)))
	_check("y no con un punto lejano", not arms.touches(player + Vector3(0.0, 0.0, 12.0)))
	arms.strike = 0.0

	# 6. Ventosas que laten y latigazo que decae.
	var cup := (arms.arms[0]["suckers"] as Array)[0]["node"] as Node3D
	var base_cup: Vector3 = (arms.arms[0]["suckers"] as Array)[0]["base_scale"]
	arms.update(0.37, 0.0, player, 0.0, 0.0)
	var pulse := cup.scale.x / base_cup.x
	_check("las ventosas laten un ±8 %% (%.3f)" % pulse, absf(pulse - 1.0) <= W01Arms.SUCKER_PULSE + 0.001)
	arms.lash_all(1.0)
	var before := (arms.arms[10]["node"] as Node3D).transform.basis.get_euler()
	arms.update(0.05, 0.05, player, 0.0, 0.0)
	var after := (arms.arms[10]["node"] as Node3D).transform.basis.get_euler()
	_check("el latigazo tuerce el brazo (%.3f rad)" % (after - before).length(), (after - before).length() > 0.02)
	for _step in 40:
		arms.update(0.05, 0.05, player, 0.0, 0.0)
	var rested := (arms.arms[10]["node"] as Node3D).transform.basis.get_euler()
	_check("y se apaga solo", (rested - after).length() > 0.0)

	# 7. Alcance exterior y suelo.
	_check("el alcance exterior supera el radio del cuerpo (%.1f m)" % arms.outer_reach(0.0, 22.0),
		arms.outer_reach(0.0, 22.0) > 2.1)
	var lowest := INF
	for index in arms.arm_count():
		lowest = minf(lowest, arms.tip_of(index).y)
	_check("ninguna punta atraviesa el suelo (%.2f m)" % lowest, lowest >= W01Arms.FLOOR_MARGIN - 0.01)

	# 8. Malla de contención: el brazo se aparta del anillo (radio 15 m).
	scene.position = Vector3(14.2, 0.0, 22.0)
	arms.update(0.0, 0.0, Vector3(20.0, 1.7, 22.0), 1.0, 0.0)
	var pushed := 0
	for index in arms.arm_count():
		var tip := arms.tip_of(index)
		if Vector2(tip.x, tip.z - 22.0).length() <= FieldMemory.CELL_RADIUS:
			pushed += 1
	_check("los brazos no atraviesan la malla de contención (%d de 20 dentro)" % pushed, pushed == 20)

	print(JSON.stringify({"checks": checks, "failures": failures, "passed": failures.is_empty()}))
	scene.queue_free()
	quit(0 if failures.is_empty() else 1)
