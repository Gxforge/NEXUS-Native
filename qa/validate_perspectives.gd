extends SceneTree
## Valida las cámaras de `Perspectives.ts`: hombro, órbitas, cabina, persecución,
## mezcla y acortado por contactos.

var checks := 0
var failures: Array[String] = []


func _check(name: String, condition: bool) -> void:
	checks += 1
	if not condition:
		failures.append(name)


func _near(name: String, value: float, expected: float, tolerance := 0.001) -> void:
	_check("%s (%.3f ≈ %.3f)" % [name, value, expected], absf(value - expected) <= tolerance)


## Distancia en el plano horizontal (la web sube la toma después).
func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _init_views() -> Perspectives:
	var view := Perspectives.new()
	return view


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame

	# 1. Constantes de la web.
	_near("distancia por defecto", Perspectives.DISTANCE, 4.8)
	_near("altura de la toma", Perspectives.HEIGHT, 1.85)
	_near("límite de acercamiento", Perspectives.ZOOM_MIN, 2.2)
	_near("límite de alejamiento", Perspectives.ZOOM_MAX, 9.0)
	_near("velocidad de mezcla", Perspectives.BLEND_RATE, 5.0)
	_near("amortiguación", Perspectives.DAMP, 12.0)
	_near("margen de contacto", Perspectives.COLLISION_MARGIN, 0.17)
	_near("mínimo de la toma", Perspectives.COLLISION_MIN, 0.12)
	_check("punto de cabina (0,38; 1,055; −0,24)",
		Perspectives.COCKPIT.distance_to(Vector3(0.38, 1.055, -0.24)) < 0.0001)

	# 2. Modo activo y ciclos.
	var view := _init_views()
	view.foot = 1
	view.car_mode = 2
	_check("a pie manda la vista a pie", view.mode(false) == 1)
	_check("al volante manda la del coche", view.mode(true) == 2)
	var foot_order: Array[int] = []
	for i in 4:
		foot_order.append(view.cycle_foot())
	_check("las vistas a pie ciclan 1, 2, 0, 1 (%s)" % str(foot_order), foot_order == [2, 0, 1, 2])
	var car_order: Array[int] = []
	for i in 4:
		car_order.append(view.cycle_car())
	_check("las del coche ciclan igual (%s)" % str(car_order), car_order == [0, 1, 2, 0])

	# 3. Acercamiento acotado.
	view.reset()
	_near("acercar se queda en 2,2", view.zoom(-10.0), Perspectives.ZOOM_MIN)
	_near("alejar se queda en 9", view.zoom(100.0), Perspectives.ZOOM_MAX)
	view.reset()
	_near("un paso de rueda son 0,4 m", view.zoom(1.0), Perspectives.DISTANCE + 0.4)

	# 4. A pie: primera persona no toca la cámara.
	var body := Vector3(3.0, 1.72, 20.0)
	view.reset()
	var idle := view.solve(body, Transform3D.IDENTITY, false, 0.6, 0.1, 1.0 / 60.0)
	_check("el modo 0 no coloca la cámara", not bool(idle["enabled"]))
	_check("el modo 0 deja la cámara en el cuerpo", (idle["position"] as Vector3).is_equal_approx(body))

	# 5. A pie, al hombro y órbita.
	view.reset()
	view.foot = 1
	var shoulder := view.solve(body, Transform3D.IDENTITY, false, 0.0, 0.0, 1.0 / 60.0)
	var aim := body - Vector3(0.0, Perspectives.FOOT_DROP, 0.0)
	_near("al hombro se adelanta 2,9 m", _flat((shoulder["position"] as Vector3), aim),
		Perspectives.SHOULDER, 0.01)
	_check("al hombro mira por delante del operador (yaw 0 → +z)",
		(shoulder["position"] as Vector3).z < aim.z)
	view.reset()
	view.foot = 2
	var orbit := view.solve(body, Transform3D.IDENTITY, false, 0.0, 0.2, 1.0 / 60.0)
	_near("la órbita trasera va a 0,72·distancia", _flat((orbit["position"] as Vector3), aim),
		Perspectives.FOOT_ORBIT * Perspectives.DISTANCE, 0.01)
	_near("la órbita sube con la mirada", (orbit["position"] as Vector3).y,
		aim.y + 0.55 - 0.8 * 0.2, 0.01)

	# 6. En el coche: cabina, persecución y órbita.
	var car := Transform3D(Basis(Vector3.UP, 0.0), Vector3(-12.0, 0.045, 109.0))
	view.reset()
	var cabin := view.solve(body, car, true, 0.0, 0.0, 1.0 / 60.0)
	_check("la cabina no activa la cámara libre", not bool(cabin["enabled"]))
	_check("la cabina va en el puesto del conductor",
		(cabin["position"] as Vector3).distance_to(car * Perspectives.COCKPIT) < 0.0001)
	_check("la cabina mira al frente del coche",
		(cabin["aim"] as Vector3).distance_to(car * Perspectives.COCKPIT_AIM) < 0.0001)
	_check("la cabina usa el «arriba» del coche",
		(cabin["up"] as Vector3).is_equal_approx(car.basis.y.normalized()))

	view.reset()
	view.car_mode = 1
	var chase := view.solve(body, car, true, 0.0, 0.0, 1.0 / 60.0)
	var pivot := car * Perspectives.CAR_PIVOT
	_near("la persecución queda a la distancia pedida",
		(chase["position"] as Vector3).distance_to(Vector3(pivot.x, (chase["position"] as Vector3).y,
			pivot.z)), Perspectives.DISTANCE, 0.01)
	_check("la persecución va por detrás del coche",
		(chase["position"] as Vector3).z < pivot.z)
	_near("la persecución sube a la altura pedida", (chase["position"] as Vector3).y,
		pivot.y + Perspectives.HEIGHT, 0.01)
	_check("la persecución sí coloca la cámara", bool(chase["enabled"]))

	view.reset()
	view.car_mode = 2
	var car_orbit := view.solve(body, car, true, 0.0, 0.3, 1.0 / 60.0)
	_near("la órbita del coche suma la mirada", (car_orbit["position"] as Vector3).y,
		pivot.y + maxf(0.35, Perspectives.HEIGHT + 0.3 * 3.0), 0.01)

	# 7. Mezcla: al cambiar de modo se arranca desde la posición anterior.
	view.reset()
	view.solve(body, car, true, 0.0, 0.0, 1.0 / 60.0)
	view.car_mode = 1
	var first := view.solve(body, car, true, 0.0, 0.0, 1.0 / 60.0)
	_check("tras cambiar de modo la mezcla arranca", bool(first["changed"]))
	var second := view.solve(body, car, true, 0.0, 0.0, 1.0 / 60.0)
	_check("y sube con el tiempo", float(second["blend"]) > float(first["blend"]))
	for i in 40:
		view.solve(body, car, true, 0.0, 0.0, 1.0 / 60.0)
	var settled := view.solve(body, car, true, 0.0, 0.0, 1.0 / 60.0)
	_near("la mezcla termina en 1", float(settled["blend"]), 1.0)

	# 8. Amortiguación: la toma persigue al objetivo en vez de saltar.
	view.reset()
	view.car_mode = 1
	var still := view.solve(body, car, true, 0.0, 0.0, 1.0 / 60.0)
	for i in 30:
		view.solve(body, car, true, 0.0, 0.0, 1.0 / 60.0)
	var moved_car := Transform3D(Basis(Vector3.UP, 0.0), Vector3(-6.0, 0.045, 109.0))
	var lag := view.solve(body, moved_car, true, 0.0, 0.0, 1.0 / 60.0)
	var fresh := Perspectives.new()
	fresh.car_mode = 1
	var target_position: Vector3 = (fresh.solve(body, moved_car, true, 0.0, 0.0, 1.0 / 60.0)
		as Dictionary)["position"]
	var lagged: Vector3 = lag["position"]
	_check("la cámara se queda atrás al moverse el coche",
		lagged.distance_to(target_position) > 0.05)
	for i in 60:
		view.solve(body, moved_car, true, 0.0, 0.0, 1.0 / 60.0)
	_check("y acaba alcanzándolo", view.last_position().distance_to(target_position) < 0.15)

	# 9. Acortado por contactos y colocación de la cámara de verdad.
	var camera := Camera3D.new()
	root.add_child(camera)
	view.reset()
	view.car_mode = 1
	for i in 30:
		view.apply(camera, body, car, true, 0.0, 0.0, Callable(), 1.0 / 60.0)
	var free_position := camera.global_position
	_check("sin obstáculos la cámara va a la distancia pedida",
		free_position.distance_to(car * Perspectives.CAR_PIVOT) > 1.0)
	var wall := func(origin: Vector3, destination: Vector3) -> float:
		return 1.0
	view.reset()
	view.car_mode = 1
	for i in 30:
		view.apply(camera, body, car, true, 0.0, 0.0, wall, 1.0 / 60.0)
	var shortened := camera.global_position.distance_to(car * Perspectives.CAR_PIVOT)
	_check("una pared a 1 m acorta la toma (%.2f m)" % shortened,
		shortened <= 1.0 - Perspectives.COLLISION_MARGIN + 0.02)
	var nothing := func(origin: Vector3, destination: Vector3) -> float:
		return -1.0
	view.reset()
	var before := camera.global_position
	var placed := view.apply(camera, body, car, false, 0.0, 0.0, nothing, 1.0 / 60.0)
	_check("en primera persona la cámara no se toca", not placed
		and camera.global_position.is_equal_approx(before))
	camera.queue_free()

	print(JSON.stringify({"checks": checks, "failures": failures, "passed": failures.is_empty()}))
	quit(0 if failures.is_empty() else 1)
