extends SceneTree
## Valida el aire y el zumbido procedurales de `Breath.ts`.

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
	# 1. Ruido: dos segundos, con el filtro de un polo y sin DC.
	var noise := W01Breath.noise_stream()
	var count := int(W01Breath.NOISE_SECONDS * W01Breath.NOISE_RATE)
	_check("el aire dura 2 s a 22.050 Hz (%d muestras)" % (noise.data.size() / 2), noise.data.size() / 2 == count)
	_check("el aire se repite en bucle", noise.loop_mode == AudioStreamWAV.LOOP_FORWARD and noise.loop_end == count)
	var sum := 0.0
	var energy := 0.0
	var peak := 0.0
	for index in count:
		var value := float(noise.data.decode_s16(index * 2)) / 32767.0
		sum += value
		energy += value * value
		peak = maxf(peak, absf(value))
	var mean := sum / float(count)
	_check("el ruido está centrado y no satura (media %.4f, pico %.2f)" % [mean, peak], absf(mean) < 0.02 and peak > 0.4 and peak <= 0.75)
	_check("el ruido tiene energía (rms %.3f)" % sqrt(energy / float(count)), sqrt(energy / float(count)) > 0.05)

	# 2. Zumbido: 100 ciclos exactos a 88 Hz, de triángulo.
	var rotor := W01Breath.rotor_stream()
	var samples := rotor.data.size() / 2
	_check("el zumbido son 100 ciclos de 88 Hz (%d muestras)" % samples, samples == 100 * (W01Breath.ROTOR_RATE / 88))
	var low := 1.0
	var high := -1.0
	for index in samples:
		var value := float(rotor.data.decode_s16(index * 2)) / 32767.0
		low = minf(low, value)
		high = maxf(high, value)
	var crest := float(rotor.data.decode_s16(0)) / 32767.0
	var trough := float(rotor.data.decode_s16(50 * 2)) / 32767.0
	_check("el zumbido es triangular (pico %.2f, valle %.2f, rango %.2f/%.2f)" % [crest, trough, low, high],
		low < -0.3 and high > 0.3 and absf(crest - high) < 0.01 and absf(trough - low) < 0.01)

	# 3. Sistema montado con sus dos buses y el paso banda.
	var breath := W01Breath.new()
	root.add_child(breath)
	_check("el aire tiene su bus con paso banda",
		AudioServer.get_bus_index(W01Breath.AIR_BUS) != -1 and breath.bus_filter() != null)
	_check("el paso banda arranca en 540 Hz con Q 0,64",
		is_equal_approx(breath.bus_filter().cutoff_hz, W01Breath.CUTOFF_OUT)
		and is_equal_approx(breath.bus_filter().resonance, W01Breath.BAND_RESONANCE))
	breath.active = true

	# 4. La fase late al ritmo de la web y la ganancia sigue a la fatiga.
	breath.update(0.1, 0.0)
	_check("la fase avanza 1,65 rad/s en reposo (%.3f)" % breath.phase, is_equal_approx(breath.phase, 0.165))
	breath.phase = 0.0
	breath.update(0.1, 1.0)
	_check("la fatiga acelera la respiración (%.3f)" % breath.phase, is_equal_approx(breath.phase, 0.455))
	breath.phase = PI * 1.5
	breath.update(0.0, 1.0)
	_check("al exhalar la ganancia sube a 0,70 (%.3f)" % breath.air_gain, absf(breath.air_gain - 0.70) < 0.01)
	_check("la exhalación deja el filtro en 540 Hz (%.0f)" % breath.air_cutoff, breath.air_cutoff < 620.0)
	breath.phase = PI * 0.5
	breath.update(0.0, 1.0)
	_check("al inspirar el filtro se abre a 920 Hz (%.0f)" % breath.air_cutoff, breath.air_cutoff > 900.0)
	var without := 0.0
	for _step in 20:
		breath.update(0.05, without)
	_check("sin fatiga no hay aire (%.4f)" % breath.air_gain, breath.air_gain < 0.001)

	# 5. Zumbido de máquina: cercanía, carga y frecuencia del rotor.
	breath.machine(1.0, 0.0)
	for _step in 40:
		breath.machine(1.0, 0.0)
	_check("la máquina cercana y descargada ronda 0,050 (%.4f)" % breath.hum_gain, absf(breath.hum_gain - 0.05) < 0.006)
	for _step in 140:
		breath.machine(1.0, 1.0)
	_check("con la carga al 100 %% sube a 0,105 y 120 Hz (%.4f / %.1f)" % [breath.hum_gain, breath.hum_hz],
		absf(breath.hum_gain - 0.105) < 0.006 and absf(breath.hum_hz - 120.0) < 1.0)
	_check("la cercanía a la acometida 1 es máxima (%.3f)" % W01Breath.feeds_near(Vector3(19.85, 1.7, 67.4)),
		W01Breath.feeds_near(Vector3(19.85, 1.7, 67.4)) > 0.99)
	_check("a veintitrés metros ya no se oye (%.3f)" % W01Breath.feeds_near(Vector3(19.85, 1.7, 90.0)),
		W01Breath.feeds_near(Vector3(19.85, 1.7, 90.0)) < 0.05)
	breath.set_feed(0, false)
	var after := W01Breath.feeds_near(Vector3(19.85, 1.7, 67.4))
	_check("una acometida caída deja paso a la siguiente (%.3f)" % after, after < 0.5)
	breath.set_feed(0, true)

	# 6. Silencio de menú.
	breath.quiet()
	_check("el silencio apaga las dos voces (%.4f / %.4f)" % [breath.air_gain, breath.hum_gain],
		breath.air_gain == 0.0 and breath.hum_gain == 0.0)
	_check("la fatiga de la web es 1 − stamina/100 (%.2f)" % W01Breath.fatigue_for(38.0),
		is_equal_approx(W01Breath.fatigue_for(38.0), 0.62))

	print(JSON.stringify({"checks": checks, "failures": failures, "passed": failures.is_empty()}))
	breath.queue_free()
	quit(0 if failures.is_empty() else 1)
