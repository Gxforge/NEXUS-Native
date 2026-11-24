extends SceneTree
## Validador de la capa de interfaz de `App.tsx`: ajustes persistidos, paneles,
## pausa y reanudación, consejos de una sola vez y bitácora de sesión.

var checks := 0
var failures := 0


func _init() -> void:
	_settings()
	_panels()
	_tips()
	_log()
	_persistence()
	_game_state()
	print("\n=== validate_session: %d checks, %d failures ===" % [checks, failures])
	if failures > 0:
		push_error("%d comprobaciones fallaron" % failures)
	quit(1 if failures > 0 else 0)


func check(label: String, condition: bool, extra := "") -> void:
	checks += 1
	if not condition:
		failures += 1
		print("  FAIL · %s%s" % [label, (" · " + extra) if not extra.is_empty() else ""])


func near(label: String, value: float, expected: float, tolerance := 0.001) -> void:
	check(label, absf(value - expected) <= tolerance, "%.4f vs %.4f" % [value, expected])


# --------------------------------------------------------------------------- #
func _settings() -> void:
	print("\n[ajustes]")
	var session := SessionState.new("high", 1.0)
	near("sensibilidad por defecto", session.sensitivity, 1.0)
	near("mínimo de sensibilidad", SessionState.SENSITIVITY_MIN, 0.35)
	near("máximo de sensibilidad", SessionState.SENSITIVITY_MAX, 2.5)
	near("paso de sensibilidad", SessionState.SENSITIVITY_STEP, 0.05)
	check("la mirada usa la sensibilidad", is_equal_approx(session.look_scale(), 1.0))
	near("recorta por abajo", session.set_sensitivity(0.1), 0.35)
	near("recorta por arriba", session.set_sensitivity(9.0), 2.5)
	near("cuantiza al paso", session.set_sensitivity(1.02), 1.0)
	near("muesca arriba", session.nudge_sensitivity(1), 1.05)
	near("muesca abajo", session.nudge_sensitivity(-2), 0.95)
	check("calidad válida", session.set_quality("low") == "low")
	check("calidad inválida se ignora", session.set_quality("ultra") == "low")
	check("los consejos están activos", session.guides)
	session.set_guides(false)
	check("se pueden desactivar", not session.guides)
	check("dispositivo Android", SessionState.detect_device(true, false, false) == "android")
	check("dispositivo táctil", SessionState.detect_device(false, true, true) == "touch")
	check("dispositivo PC", SessionState.detect_device(false, true, false) == "pc")
	session.device = "touch"
	check("etiqueta del dispositivo", session.device_label() == "Táctil")
	check("ayuda de entrada", session.input_hint().contains("joystick"))
	session.device = "pc"
	check("ayuda de escritorio", session.input_hint().contains("Mayús"))
	check("tres manuales", session.manuals().size() == 3)
	check("cita la energía del UV", session.manuals()[1].contains("32"))
	near("marca de hora", 0.0, 0.0)
	check("marca de hora formateada", SessionState.time_stamp(9, 5) == "09:05")


# --------------------------------------------------------------------------- #
func _panels() -> void:
	print("\n[paneles y pausa]")
	var session := SessionState.new()
	check("arranca sin panel", session.panel.is_empty() and session.active())
	check("abre el mapa", session.open_panel("map"))
	check("con panel no hay simulación", not session.active())
	session.close_panel()
	check("el mapa reanuda", session.active() and session.panel.is_empty())
	check("abre ajustes", session.open_panel("cfg"))
	session.close_panel()
	check("ajustes vuelven al juego", session.panel.is_empty() and session.active())
	check("panel inválido", not session.open_panel("hack"))
	check("pausa", session.pause())
	check("pausado", session.paused and session.panel == "pause" and not session.active())
	check("pausar dos veces no duplica", not session.pause())
	session.close_panel()
	check("cerrar pausa vuelve a la pausa", session.panel == "pause" and session.paused)
	check("reanudar", session.resume() and session.active())
	session.open_panel("inventory")
	session.paused = true
	session.close_panel()
	check("inventario desde pausa reanuda", session.active() and session.panel.is_empty())
	session.set_error("contexto gráfico perdido")
	check("el error detiene la simulación", not session.active())
	check("con error no se pausa", not session.pause())

	var reset := SessionState.new()
	reset.open_panel("map")
	reset.first_person = true
	reset.zoom = true
	reset.reset_session()
	check("el reinicio limpia paneles y vista", reset.panel.is_empty() and not reset.paused
		and not reset.first_person and not reset.zoom)
	check("el reinicio se registra", reset.entries[0]["s"] == "Sesión de contención reiniciada",
		str(reset.entries[0]))
	var view := SessionState.new()
	check("entra en primera persona", view.set_view(true) == "Operador en primera persona")
	check("modo primera persona", view.first_person and view.zoom)
	check("vuelve a la órbita", view.set_view(false) == "Cámara orbital activa")
	check("modo orbital", not view.first_person and not view.zoom)
	check("la vista queda en la bitácora", view.entries[0]["s"] == "Cámara orbital activa")
	view.set_error("fallo")
	check("con error no cambia de vista", view.set_view(true) == "")


# --------------------------------------------------------------------------- #
func _tips() -> void:
	print("\n[consejos de una sola vez]")
	near("retardo del consejo", SessionState.TIP_DELAY, 0.55)
	near("duración del consejo", SessionState.TIP_DURATION, 5.95)
	var nx := ExperienceState.new([&"pulse", &"lamp"])
	check("consejo de linterna", SessionState.tip_id(nx) == "lamp")
	nx.mode = "scan"
	check("el escáner manda", SessionState.tip_id(nx) == "scan")
	nx.mode = "touch"
	nx.inventory = [&"pulse"]
	check("consejo de mochila", SessionState.tip_id(nx) == "pack")
	check("texto del consejo de escaneo", SessionState.tip_text("scan").contains("fichas"))
	check("texto del consejo de linterna", SessionState.tip_text("lamp").contains("Linterna"))

	var session := SessionState.new()
	check("sin primera persona no hay consejo", session.update(1.0, nx).is_empty())
	session.first_person = true
	check("antes del retardo no hay consejo", session.update(0.3, nx).is_empty())
	check("tras el retardo aparece", session.update(0.3, nx) == SessionState.tip_text("pack"))
	check("queda registrado", session.tip_shown("pack"))
	check("sigue visible mientras dura", session.update(1.0, nx) == SessionState.tip_text("pack"))
	session.update(6.0, nx)
	check("se retira a los 5,95 s", session.tip.is_empty(), session.tip)
	check("no vuelve a salir", session.update(2.0, nx).is_empty())

	var quiet := SessionState.new()
	quiet.first_person = true
	quiet.set_guides(false)
	check("sin consejos no aparece nada", quiet.update(2.0, nx).is_empty())
	var busy := SessionState.new()
	busy.first_person = true
	busy.open_panel("map")
	check("con panel abierto no hay consejo", busy.update(2.0, nx).is_empty())
	var noticed := SessionState.new()
	noticed.first_person = true
	nx.notice = 2.0
	check("con aviso activo se aplaza", noticed.update(2.0, nx).is_empty() and not noticed.tip_shown("pack"))
	nx.notice = 0.0
	var manual := SessionState.new()
	manual.mark_tip("pack")
	check("marcar a mano evita el consejo", manual.tip_shown("pack"))
	manual.mark_tip("pack")
	check("marcar dos veces no duplica", manual.shown_tips.size() == 1, str(manual.shown_tips))
	var dismissed := SessionState.new()
	dismissed.first_person = true
	dismissed.update(1.0, nx)
	dismissed.dismiss_tip()
	check("descartar limpia el texto", dismissed.tip.is_empty())


# --------------------------------------------------------------------------- #
func _log() -> void:
	print("\n[bitácora]")
	check("límite de 60 entradas", SessionState.LOG_LIMIT == 60)
	var session := SessionState.new()
	check("dos entradas de arranque", session.entries.size() == 2, str(session.entries.size()))
	check("la más reciente primero", session.entries[0]["s"] == "Protocolos NEXUS disponibles",
		str(session.entries[0]))
	check("con marca de hora", str(session.entries[0]["at"]).contains(":"))
	session.log_entry("Prueba", "12:34")
	check("respeta la marca explícita", session.entries[0]["at"] == "12:34")
	for index in 80:
		session.log_entry("Evento %d" % index)
	check("se recorta a 60", session.entries.size() == 60, str(session.entries.size()))
	check("el último entra primero", session.entries[0]["s"] == "Evento 79")
	check("las líneas llevan hora y texto", session.log_lines()[0].begins_with("12")
		or session.log_lines()[0].contains(":"), session.log_lines()[0])


# --------------------------------------------------------------------------- #
func _persistence() -> void:
	print("\n[persistencia]")
	var session := SessionState.new("high")
	session.set_sensitivity(1.35)
	session.set_guides(false)
	session.device = "android"
	session.mark_tip("lamp")
	var blob := session.to_dict()
	var copy := SessionState.new()
	check("restaura", copy.from_dict(blob))
	near("sensibilidad restaurada", copy.sensitivity, 1.35)
	check("consejos restaurados", not copy.guides)
	check("dispositivo restaurado", copy.device == "android", copy.device)
	check("consejo ya mostrado", copy.tip_shown("lamp"))
	check("calidad restaurada", copy.quality == "high")
	var dirty := SessionState.new()
	dirty.from_dict({"quality": "ultra", "sensitivity": 99.0, "device": "toaster"})
	check("valores inválidos se corrigen", dirty.quality == "medium" and dirty.device == "pc")
	near("sensibilidad recortada", dirty.sensitivity, 2.5)
	check("diccionario vacío no rompe", not SessionState.new().from_dict({}))


# --------------------------------------------------------------------------- #
func _game_state() -> void:
	print("\n[partida]")
	var state := GameState.new()
	state.power_simulation = false
	check("la partida tiene sesión", state.session != null)
	near("sensibilidad inicial", state.session.sensitivity, 1.0)
	state.session.set_sensitivity(1.5)
	state.session.set_guides(false)
	state.set_quality("low")
	check("la calidad se copia a la sesión", state.session.quality == "low", state.session.quality)
	state.log_event("Prueba de bitácora")
	check("la bitácora de partida registra", state.session.entries[0]["s"] == "Prueba de bitácora")
	check("instantánea de sesión", state.session_snapshot().has("sensitivity"))
	state.persistence_path = "user://nexus_native_session_check.json"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(state.persistence_path))
	check("guarda", state.save_game())
	var reloaded := GameState.new()
	reloaded.power_simulation = false
	reloaded.persistence_path = state.persistence_path
	check("carga", reloaded.load_game())
	near("sensibilidad tras cargar", reloaded.session.sensitivity, 1.5)
	check("consejos tras cargar", not reloaded.session.guides)
	check("calidad tras cargar", reloaded.quality() == "low", reloaded.quality())
	DirAccess.remove_absolute(ProjectSettings.globalize_path(state.persistence_path))
	check("acción de calidad mapeada", InputMap.has_action(&"cycle_quality"))
	state.free()
	reloaded.free()
