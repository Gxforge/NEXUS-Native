extends SceneTree
## Valida el panel de instrumentos (`Cockpit.ts`) y el sonido del coche
## (`VehicleAudio.ts`).

var checks := 0
var failures: Array[String] = []


func _check(name: String, condition: bool) -> void:
	checks += 1
	if not condition:
		failures.append(name)


func _near(name: String, value: float, expected: float, tolerance := 0.001) -> void:
	_check("%s (%.4f ≈ %.4f)" % [name, value, expected], absf(value - expected) <= tolerance)


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame

	# 1. Panel: medidas del lienzo de la web.
	var dash := CockpitDisplay.new()
	root.add_child(dash)
	await process_frame
	_check("el panel se monta", dash.face != null)
	_near("ancho del plano", (dash.face.mesh as QuadMesh).size.x, 0.39)
	_near("alto del plano", (dash.face.mesh as QuadMesh).size.y, 0.145)
	_check("lienzo de 384 × 144 px", CockpitDisplay.WIDTH == 384 and CockpitDisplay.HEIGHT == 144)
	_check("un píxel es un milímetro", is_equal_approx(CockpitDisplay.PIXEL, 0.001))
	_near("la barra ocupa carga·3,55 px", dash.bar_width(), 100.0 * 3.55 * CockpitDisplay.PIXEL, 0.0001)

	# 2. Contenido de los rótulos y repintado sólo al cambiar.
	_check("cabecera del panel", dash.text_of("Title") == "GT / 14     AXIAL DRIVE")
	dash.paint(0, "N", 100, 850)
	_check("velocidad a cero con tres cifras", dash.text_of("Speed") == "000")
	_check("marcha neutra", dash.text_of("Gear") == "GEAR N")
	_check("régimen de ralentí", dash.text_of("Rpm") == "850 RPM")
	_check("energía al 100 %", dash.text_of("Charge") == "E 100%")
	_check("barra llena al 100 %", absf(dash.bar_width() - 100.0 * 3.55 * CockpitDisplay.PIXEL) < 0.0001)
	var before := dash.paints
	dash.paint(0, "N", 100, 850)
	_check("no se repinta si nada cambia (%d)" % dash.paints, dash.paints == before)
	dash.paint(74, "3", 42, 3200)
	_check("sí se repinta si cambia", dash.paints == before + 1)
	_check("velocidad nueva", dash.text_of("Speed") == "074")
	_check("marcha nueva", dash.text_of("Gear") == "GEAR 3")
	_check("régimen nuevo", dash.text_of("Rpm") == "3200 RPM")
	_check("energía nueva", dash.text_of("Charge") == "E 42%")
	_near("la barra sigue a la energía", dash.bar_width(), 42.0 * 3.55 * CockpitDisplay.PIXEL, 0.0001)

	# 3. `sync` usa el redondeo de la web: |v|·3,6, energía y régimen a 100.
	var physics := VehiclePhysics.new()
	physics.reset(-12.0, 109.0, 0.0, true)
	physics.speed = 12.4
	physics.energy = 63.4
	physics.rpm = 2750.0
	physics.gear = "2"
	dash.sync(physics)
	_check("velocidad de la telemetría (44,6 km/h → 045)", dash.text_of("Speed") == "045")
	_check("energía redondeada a entero", dash.text_of("Charge") == "E 63%")
	_check("régimen redondeado a 100", dash.text_of("Rpm") == "2800 RPM")

	# 4. Sonido: las tres voces y el ruido filtrado de la web.
	var audio := VehicleAudio.new()
	root.add_child(audio)
	await process_frame
	_check("cuatro voces (motor, rodadura, turbo y ruido)",
		audio.get_node_or_null("Engine") != null and audio.get_node_or_null("Roll") != null
		and audio.get_node_or_null("Turbo") != null and audio.get_node_or_null("Rumble") != null)
	_check("el bus de rodadura tiene paso bajo", audio.bus_filter() != null)
	physics.speed = 10.0
	physics.rpm = 3300.0
	physics.energy = 55.0
	physics.throttle = 1.0
	for i in 40:
		audio._process(1.0 / 60.0)
		audio.update(physics, true)
	_near("motor a 30 + rpm/63", audio.engine_hz, 30.0 + 3300.0 / 63.0)
	_near("rodadura a 240 + |v|·18", audio.roll_hz, 240.0 + 10.0 * 18.0)
	_near("turbo a 240 + energía·4", audio.turbo_hz, 240.0 + 55.0 * 4.0)
	_near("ganancia del motor 0,008 + 0,012·gas", audio.engine_gain, 0.008 + 0.012)
	_check("el ruido sube con la velocidad (%.4f)" % audio.rumble_gain,
		absf(audio.rumble_gain - (0.003 + 10.0 * 0.0009)) < 0.0002)
	_near("paso bajo a 240 + |v|·20", audio.filter_hz, 240.0 + 10.0 * 20.0, 0.5)
	physics.boost = true
	audio.update(physics, true)
	_check("el turbo enciende la voz aguda", audio.turbo_gain > 0.0)
	physics.boost = false
	physics.braking = true
	var quiet_roll := audio.roll_gain
	audio.update(physics, true)
	_check("frenar sube la rodadura (%.4f → %.4f)" % [quiet_roll, audio.roll_gain],
		audio.roll_gain > quiet_roll)
	physics.impact = 0.5
	audio.update(physics, true)
	_check("el impacto abre el filtro", audio.filter_hz > 240.0 + 10.0 * 20.0)
	for i in 60:
		audio._process(1.0 / 60.0)
		audio.update(physics, false)
	_check("sin conductor las voces se apagan (%.5f %.5f %.5f %.5f)" % [audio.engine_gain,
		audio.roll_gain, audio.turbo_gain, audio.rumble_gain],
		audio.engine_gain < 0.0005 and audio.roll_gain < 0.0005
		and audio.turbo_gain < 0.0005 and audio.rumble_gain < 0.0005 and not audio.active)
	audio.quiet()
	_check("quiet deja las voces a cero", audio.engine_gain == 0.0 and not audio.active)

	# 5. Bucles de las ondas: un periodo exacto.
	_near("sierra de 30 Hz", float(audio.saw_stream(30.0).data.size() / 2), 735.0, 0.5)
	_near("triángulo de 240 Hz", float(audio.triangle_stream(240.0).data.size() / 2), 92.0, 0.5)
	_check("el ruido dura dos segundos",
		audio.noise_stream().data.size() / 2 == AudioStreamWAV.new().data.size() + 44100)

	print(JSON.stringify({"checks": checks, "failures": failures, "passed": failures.is_empty()}))
	dash.queue_free()
	audio.queue_free()
	quit(0 if failures.is_empty() else 1)
