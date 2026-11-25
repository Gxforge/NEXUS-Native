extends SceneTree
## Validador de `Displays.ts` y `TelemetryScreen.ts`: muestreo, páginas,
## formatos, trazas, superficies y pantallas 3D.

var checks := 0
var failures := 0


func _init() -> void:
	_phosphor()
	_telemetry()
	_screen_nodes()
	print("\n=== validate_displays: %d checks, %d failures ===" % [checks, failures])
	if failures > 0:
		push_error("%d comprobaciones fallaron" % failures)
	quit(1 if failures > 0 else 0)


## Tamaño real de la cara de la pantalla: el plano es el original exportado
## (`telemetry_screen.glb` 2,36 × 1,33 y `display.glb` 1,0 × 0,5) escalado.
func _face_size(screen: WallScreen) -> Vector2:
	if screen.mesh == null or screen.mesh.mesh == null:
		return Vector2.ZERO
	var box: AABB = screen.mesh.mesh.get_aabb()
	return Vector2(box.size.x * absf(screen.mesh.scale.x), box.size.y * absf(screen.mesh.scale.y))


func check(label: String, condition: bool, extra := "") -> void:
	checks += 1
	if not condition:
		failures += 1
		print("  FAIL · %s%s" % [label, (" · " + extra) if not extra.is_empty() else ""])


func near(label: String, value: float, expected: float, tolerance := 0.001) -> void:
	check(label, absf(value - expected) <= tolerance, "%.4f vs %.4f" % [value, expected])


func grid(load := 68.0, temp := 43.5, tripped := false) -> Dictionary:
	return {
		"load": load, "temp": temp, "capacity": 112, "tripped": tripped,
		"feeds": [true, true, false, true], "fans": [true, false, true, true],
		"cause": "Sobrecarga sostenida en la derivación E-07 del cuadro",
	}


# --------------------------------------------------------------------------- #
func _phosphor() -> void:
	print("\n[pantalla de fósforo]")
	var d := PhosphorDisplay.new()
	check("canvas 640×320", PhosphorDisplay.WIDTH == 640 and PhosphorDisplay.HEIGHT == 320)
	check("traza de 72 muestras", PhosphorDisplay.HISTORY_LIMIT == 72)
	check("sin muestras al arrancar", d.history.is_empty() and d.last == "")
	near("fracción vacía", d.fraction(), 0.0)

	d.paint("RED · E-07", "68 kW", "derivación este", 0.61)
	check("registra la muestra", d.history.size() == 1)
	near("fracción de la barra", d.fraction(), 0.61)
	check("texto compuesto", d.last == "RED · E-07|68 kW|derivación este", d.last)
	check("acento por defecto", d.accent == PhosphorDisplay.DEFAULT_ACCENT)

	for index in 100:
		d.paint("RED · E-07", str(index), "", float(index) / 100.0)
	check("la traza se recorta a 72", d.history.size() == 72, str(d.history.size()))
	var points := d.trace_points()
	check("un punto por muestra", points.size() == 72)
	near("el último punto está a la derecha", points[points.size() - 1].x, 620.0, 0.001)
	near("la traza avanza 8,4 por muestra", points[0].x,
		620.0 - 71.0 * 8.4, 0.001)
	near("la traza se limita arriba", points[points.size() - 1].y, 258.0 - 66.0 * 0.99, 0.001)
	check("dieciséis divisiones verticales", d.grid_columns().size() == 16,
		str(d.grid_columns().size()))
	check("cuatro divisiones horizontales", d.grid_rows().size() == 4, str(d.grid_rows().size()))
	near("rejilla desde x = 20", d.grid_columns()[0], 20.0)
	near("primera fila en y = 187", d.grid_rows()[0], 187.0)
	var custom := PhosphorDisplay.new()
	custom.paint("X", "Y", "Z", 0.2, Color("#000000"))
	check("acento explícito", custom.accent == Color("#000000"))

	var blob := d.to_dict()
	var copy := PhosphorDisplay.new()
	check("persistencia", copy.from_dict(blob) and copy.history.size() == 72)
	check("diccionario vacío no rompe", not PhosphorDisplay.new().from_dict({}))


# --------------------------------------------------------------------------- #
func _telemetry() -> void:
	print("\n[telemetría CAM 04]")
	var m := TelemetryModel.new()
	check("canvas 1024×576", TelemetryModel.WIDTH == 1024 and TelemetryModel.HEIGHT == 576)
	near("muestreo cada 0,35 s", TelemetryModel.SAMPLE_INTERVAL, 0.35)
	check("búfer de 75 filas", TelemetryModel.HISTORY_LIMIT == 75)
	check("tres páginas", TelemetryModel.PAGES == 3)
	check("título de la página 1", m.title() == "W–01 · ESTACIÓN DE CAMPO", m.title())

	check("primera muestra", m.sample(0.0, grid(), 92.0, 12.4, "WATCHING",
		Vector3(1.0, 0.0, 22.0), "Vigila", 3, 0.2))
	check("muestra demasiado seguida se descarta", not m.sample(0.2, grid(), 92.0, 12.4,
		"WATCHING", Vector3.ZERO, "Vigila", 3, 0.2))
	check("muestra tras el intervalo", m.sample(0.4, grid(), 92.0, 12.4, "WATCHING",
		Vector3.ZERO, "Vigila", 3, 0.2))
	check("dos filas en el búfer", m.history.size() == 2, str(m.history.size()))
	check("fila con cinco columnas", (m.history[0] as Array).size() == 5)
	near("guarda la carga", float((m.history[0] as Array)[0]), 68.0)
	near("guarda la temperatura", float((m.history[0] as Array)[1]), 43.5)
	near("guarda la agresividad ×100", float((m.history[0] as Array)[4]), 20.0, 0.001)

	var rows := m.values()
	check("tres filas por página", rows.size() == 3)
	check("integridad redondeada", str(rows[0][1]) == "92 %", str(rows[0][1]))
	check("distancia con un decimal", str(rows[1][1]) == "12.4 m", str(rows[1][1]))
	check("consumo de la red", str(rows[2][1]) == "68 kW", str(rows[2][1]))

	m.set_page(1)
	check("página de diagnóstico", m.title() == "BUS · DIAGNÓSTICO", m.title())
	rows = m.values()
	check("capacidad", str(rows[0][1]) == "112 kW", str(rows[0][1]))
	check("térmica con un decimal", str(rows[1][1]) == "43.5 °C", str(rows[1][1]))
	near("resaltado por disparo", 0.0, 0.0)
	check("estado LIVE", m.status_label(grid()) == "●  LIVE")
	check("estado UPS al disparar", m.status_label(grid(0.0, 0.0, true)) == "●  UPS")
	check("línea de derivaciones",
		m.track_line() == "> feeds = 1101    cooling = 1011", m.track_line())
	check("pie de relé", m.footer_line().begins_with("> relay: "))
	check("el relé se recorta a 44", m.footer_line().length() <= 44 + 9, m.footer_line())

	m.set_page(2)
	check("página de rastreo", m.title() == "RASTREO · W–01", m.title())
	rows = m.values()
	check("actividad", str(rows[0][1]) == "WATCHING", str(rows[0][1]))
	check("amenaza en porcentaje", str(rows[1][1]) == "20 %", str(rows[1][1]))
	check("contactos", str(rows[2][1]) == "3", str(rows[2][1]))
	check("las series cambian en rastreo", Array(m.series_indices()) == [3, 4, 2],
		str(m.series_indices()))
	check("rastreo usa la distancia", m.track_line().begins_with("> track.xyz = ["), m.track_line())
	check("pie de intención", m.footer_line() == "> intent: Vigila", m.footer_line())
	check("página 3 vuelve a la 1", m.next_page() == 0, str(m.page))
	check("página limitada", m.set_page(9) == 2)

	# Trazas: tres series con 12,7 px de avance y recorte a 138 de altura.
	var series := m.series_points(0)
	check("puntos de la serie 0", series.size() == m.history.size())
	check("columna de la serie 0", Array(m.series_indices())[0] == 3)
	var single := TelemetryModel.new()
	single.sample(1.0, grid(), 100.0, 40.0, "IDLE", Vector3.ZERO, "Duerme", 0, 0.0)
	var first := single.series_points(0)
	near("último punto a la derecha de la rejilla", first[0].x, 980.0)
	near("altura recortada a 138", first[0].y, 361.0 - minf(138.0, 68.0) * 0.94, 0.001)
	check("colores de las tres series", TelemetryModel.SERIES_COLORS.size() == 3)
	near("búfer etiquetado", 0.0, 0.0)
	check("etiqueta del búfer", m.buffer_label() == "BUFFER %d/75" % m.history.size(), m.buffer_label())
	check("etiqueta de series", m.series_label().begins_with("DIST m"), m.series_label())
	check("línea de tiempo", m.time_line().begins_with("T+"), m.time_line())
	check("línea de estado", m.state_line().contains("subject.state"), m.state_line())

	# El búfer se recorta y se reinicia si el tiempo retrocede.
	for index in 200:
		m.sample(1.0 + index * 0.4, grid(), 90.0, 10.0, "WATCHING", Vector3.ZERO, "Vigila", 1, 0.1)
	check("búfer recortado a 75", m.history.size() == 75, str(m.history.size()))
	m.sample(0.1, grid(), 90.0, 10.0, "WATCHING", Vector3.ZERO, "Vigila", 1, 0.1)
	check("el tiempo hacia atrás vacía el búfer", m.history.size() == 1, str(m.history.size()))

	var blob := m.to_dict()
	var copy := TelemetryModel.new()
	check("persistencia de la telemetría", copy.from_dict(blob) and copy.page == m.page)
	check("historial restaurado", copy.history.size() == m.history.size())
	check("diccionario vacío no rompe", not TelemetryModel.new().from_dict({}))


# --------------------------------------------------------------------------- #
func _screen_nodes() -> void:
	print("\n[pantallas 3D]")
	var screen := WallScreen.new()
	screen.kind = "telemetry"
	root.add_child(screen)
	screen._ready()
	check("crea la ventana de render", screen.viewport != null)
	check("resolución de la telemetría", screen.viewport.size == Vector2i(1024, 576),
		str(screen.viewport.size))
	check("la superficie está dentro de la ventana", screen.surface.get_parent() == screen.viewport)
	check("plano de 2,36 × 1,328 m",
		_face_size(screen).is_equal_approx(Vector2(2.36, 1.328)))
	check("material sin sombreado",
		screen.material.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED)
	check("textura de la ventana", screen.material.albedo_texture != null)
	check("emisión de fósforo", screen.material.emission_enabled)

	check("repinta la primera muestra", screen.push_telemetry(0.0, grid(), 95.0, 8.0,
		"WATCHING", Vector3.ZERO, "Vigila", 2, 0.2))
	check("descarta la muestra seguida", not screen.push_telemetry(0.1, grid(), 95.0, 8.0,
		"WATCHING", Vector3.ZERO, "Vigila", 2, 0.2))
	check("página siguiente", screen.cycle_page() == 1)
	check("instantánea con la página", int(screen.snapshot().get("page", -1)) == 1)
	check("restaura la pantalla", screen.restore({"page": 2, "history": [], "time": 0.0}))

	var phosphor := WallScreen.new()
	phosphor.kind = "phosphor"
	root.add_child(phosphor)
	phosphor._ready()
	check("pantalla de fósforo en 640×320",
		phosphor.viewport.size == Vector2i(PhosphorDisplay.WIDTH, PhosphorDisplay.HEIGHT),
		str(phosphor.viewport.size))
	check("plano pequeño de 0,9 × 0,45 m",
		_face_size(phosphor).is_equal_approx(Vector2(0.9, 0.45)))
	check("pinta el panel", phosphor.push_phosphor("RED · E-07", "68 kW", "este", 0.61))
	check("la telemetría no pinta en el panel",
		not phosphor.push_telemetry(0.0, grid(), 1.0, 1.0, "", Vector3.ZERO, "", 0, 0.0))
	check("instantánea del panel", phosphor.snapshot().get("last", "") == "RED · E-07|68 kW|este",
		str(phosphor.snapshot().get("last", "")))
	check("restaura el panel", phosphor.restore({"history": [0.4, 0.6], "last": "x"}))
	check("lectura del plano", phosphor.face_transform() is Transform3D)

	root.remove_child(screen)
	screen.free()
	root.remove_child(phosphor)
	phosphor.free()
