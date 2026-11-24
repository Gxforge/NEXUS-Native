extends SceneTree
## Validador del contrato de `SceneExperience.ts` / `protocols.ts` /
## `DisplayQuality.ts`: estado `nx`, costes y recargas, ranuras, avisos,
## rótulos de piezas, perfiles de calidad y persistencia.

var checks := 0
var failures := 0


func _init() -> void:
	_protocols()
	_slots()
	_use_slot()
	_labels()
	_quality()
	_persistence()
	_game_integration()
	print("\n=== validate_experience: %d checks, %d failures ===" % [checks, failures])
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


func kit() -> ExperienceState:
	return ExperienceState.new([&"lamp", &"pulse", &"cryo", &"cell", &"recorder", &"card", &"sample"])


# --------------------------------------------------------------------------- #
func _protocols() -> void:
	print("\n[protocolos]")
	var nx := kit()
	near("energía inicial", nx.energy, 100.0)
	near("batería inicial", nx.battery, 100.0)
	check("celda cargada", nx.charged)
	check("modo táctil", nx.mode == "touch", nx.mode)
	near("coste UV", float(ExperienceState.PROTOCOLS["uv"]["cost"]), 32.0)
	near("recarga UV", float(ExperienceState.PROTOCOLS["uv"]["cd"]), 8.0)
	near("coste criogénico", float(ExperienceState.PROTOCOLS["gas"]["cost"]), 24.0)
	near("recarga criogénico", float(ExperienceState.PROTOCOLS["gas"]["cd"]), 12.0)
	near("coste señuelo", float(ExperienceState.PROTOCOLS["lure"]["cost"]), 12.0)
	near("recarga señuelo", float(ExperienceState.PROTOCOLS["lure"]["cd"]), 5.0)

	check("lanza el pulso UV", nx.action("uv").contains("reflejo ocular"))
	near("energía tras el UV", nx.energy, 68.0)
	near("rejilla del UV", nx.uv, 8.0)
	check("no repite mientras recarga", nx.spend("uv") == false)
	check("aviso de recarga", nx.last_log().contains("recarga"), nx.last_log())
	near("la energía no baja del coste sin lanzar", nx.energy, 68.0)
	nx.update(8.0)
	near("la rejilla se agota", nx.uv, 0.0)
	check("vuelve a estar disponible", nx.spend("uv"))
	near("segunda descarga con la recarga del paso", nx.energy, 93.6 - 32.0, 0.05)

	var cold := kit()
	check("lanza el criogénico", cold.action("gas").contains("criogénica"))
	near("frío de 7 s", cold.cold, 7.0)
	near("energía tras el criogénico", cold.energy, 76.0)
	cold.update(3.0)
	near("el frío decae", cold.cold, 4.0)

	var poor := ExperienceState.new([&"pulse"])
	poor.energy = 20.0
	check("sin energía no hay protocolo", not poor.spend("uv"))
	near("la energía no se descuenta", poor.energy, 20.0)

	var modes := kit()
	near("el señuelo arma el modo", 0.0, 0.0)
	check("arma el señuelo", modes.action("lure").contains("Señuelo armado"))
	check("modo señuelo", modes.mode == "lure", modes.mode)
	check("desarma el señuelo", modes.action("lure") == "Estímulo directo activo")
	check("modo táctil", modes.mode == "touch", modes.mode)
	modes.weapon = 1
	check("activa el escáner", modes.action("scan") == "Escáner óptico activo")
	near("el escáner retira el arma", float(modes.weapon), -1.0)

	var lamp := kit()
	check("enciende la linterna", lamp.action("lamp") == "Linterna encendida")
	check("estado de la linterna", lamp.lamp)
	check("apaga la linterna", lamp.action("lamp") == "Linterna apagada")

	var no_lamp := ExperienceState.new([&"pulse"])
	check("sin linterna no se enciende", no_lamp.action("lamp").contains("Sin linterna"))
	check("la linterna sigue apagada", not no_lamp.lamp)

	var grabbed := kit()
	grabbed.grab = 1.0
	check("con agarre no hay acciones", grabbed.action("lamp") == "")
	check("el UV escapa del agarre", grabbed.action("uv").contains("reflejo"))
	near("el agarre se libera", grabbed.grab, 0.0)

	nx.energy = 50.0
	nx.update(10.0)
	near("la energía se recarga a 3,2/s", nx.energy, 82.0, 0.01)
	nx.energy = 99.0
	nx.update(5.0)
	near("la energía no pasa de 100", nx.energy, 100.0)


# --------------------------------------------------------------------------- #
func _slots() -> void:
	print("\n[ranuras]")
	var nx := kit()
	check("cinco ranuras", ExperienceState.SLOT_COUNT == 5)
	check("sin objetos al arrancar", nx.slots == [null, null, null, null, null])
	check("asigna el emisor", nx.bind_slot(0, "pulse"))
	check("la ranura 1 tiene el emisor", str(nx.slots[0]) == "pulse")
	check("mueve el objeto de ranura", nx.bind_slot(2, "pulse") and nx.slots[0] == null
		and str(nx.slots[2]) == "pulse")
	check("rechaza la linterna en ranuras", not nx.bind_slot(1, "lamp"))
	check("rechaza un objeto que no se tiene", not nx.bind_slot(1, "medkit"))
	check("rechaza índices fuera de rango", not nx.bind_slot(5, "cryo") and not nx.bind_slot(-1, "cryo"))
	check("permite vaciar la ranura", nx.bind_slot(2, null) and nx.slots[2] == null)
	var two := kit()
	two.bind_slot(0, "cryo")
	two.bind_slot(1, "cell")
	check("dos objetos en ranuras distintas", str(two.slots[0]) == "cryo" and str(two.slots[1]) == "cell")

	check("selecciona una ranura", two.select_slot(3) and two.slot == 3)
	check("rechaza índices inválidos", not two.select_slot(6))
	two.weapon = 2
	two.select_slot(0)
	near("cambiar de ranura retira el arma", float(two.weapon), -1.0)
	two.mode = "scan"
	two.select_slot(1)
	check("cambiar de ranura sale del escáner", two.mode == "touch", two.mode)
	two.lost = true
	check("perdido no cambia de ranura", not two.select_slot(2))
	two.lost = false
	two.grab = 1.0
	check("agarrado no cambia de ranura", not two.select_slot(2))


# --------------------------------------------------------------------------- #
func _use_slot() -> void:
	print("\n[uso de ranuras]")
	var nx := kit()
	nx.bind_slot(0, "pulse")
	nx.select_slot(0)
	nx.use_slot()
	near("el emisor UV queda listo", float(nx.weapon), 1.0)
	check("aviso del emisor", nx.message == "Emisor UV · listo", nx.message)
	nx.bind_slot(1, "cryo")
	nx.use_slot("cryo")
	near("el criogénico es el arma 2", float(nx.weapon), 2.0)

	var empty := kit()
	check("ranura vacía avisa", empty.use_slot().contains("Ranura vacía"))
	var scanned := kit()
	scanned.mode = "scan"
	check("en escáner usa el escaneo", scanned.use_slot() == "scan")
	var firing := kit()
	firing.weapon = 1
	check("con arma dispara", firing.use_slot() == "fire")

	var cell := kit()
	cell.energy = 30.0
	cell.battery = 40.0
	check("la celda restablece la batería", cell.use_slot("cell").contains("Celda conectada"))
	near("batería a 100", cell.battery, 100.0)
	near("energía +50", cell.energy, 80.0)
	check("la celda queda agotada", not cell.charged)
	check("celda agotada no se usa", cell.use_slot("cell").contains("agotada"))
	var spent_cell := kit()
	spent_cell.charged = false
	check("sin carga no hay celda", spent_cell.use_slot("cell").contains("agotada"))
	var full := kit()
	full.energy = 100.0
	full.battery = 100.0
	check("reservas llenas no gastan celda", full.use_slot("cell").contains("Reservas completas"))
	check("la celda sigue cargada", full.charged)

	check("la grabadora remite a turbinas", kit().use_slot("recorder").contains("Turbinas"))
	check("la credencial remite a B–02", kit().use_slot("card").contains("B–02"))
	var sealed := kit()
	check("el vial sellado pide analizador", sealed.use_slot("sample").contains("analizador"))
	sealed.analyzed = true
	check("el vial analizado da el informe", sealed.use_slot("sample") == "Informe V–03 completo")
	var station := ExperienceState.new([&"pulse"])
	check("equipo fuera de inventario", station.use_slot("cell").contains("Equipo en estación"))

	var guarded := kit()
	guarded.pending = true
	check("pendiente no usa ranura", guarded.use_slot() == "")
	guarded.pending = false
	guarded.lost = true
	check("perdido no usa ranura", guarded.use_slot() == "")


# --------------------------------------------------------------------------- #
func _labels() -> void:
	print("\n[rótulos y avisos]")
	check("fauces", ExperienceState.part_name("maw") == "Fauces")
	check("ojo principal", ExperienceState.part_name("eye-0") == "Ojo principal")
	check("ojo satélite", ExperienceState.part_name("eye-3") == "Ojo satélite 3")
	check("tentáculo numerado", ExperienceState.part_name("arm-0") == "Tentáculo 1")
	check("nota de las fauces", ExperienceState.part_note("maw").contains("mandíbula"))
	check("nota del ojo principal", ExperienceState.part_note("eye-0").contains("UV"))
	check("nota de ojo satélite", ExperienceState.part_note("eye-5").contains("pupila"))
	check("nota de tentáculo", ExperienceState.part_note("arm-7").contains("ventosas"))

	check("aviso vacío", ExperienceState.prompt_for("", false, false, false) == "")
	check("cargador con equipo", ExperienceState.prompt_for("charger", false, true, false)
		== "Cargador · consultar ciclo")
	check("cargador terminado", ExperienceState.prompt_for("charger", true, false, false)
		== "Cargador · retirar")
	check("analizador libre", ExperienceState.prompt_for("analyzer", false, false, false)
		== "Analizador · insertar equipo")
	check("cajón abierto", ExperienceState.prompt_for("bin2", false, false, true) == "Cajón 2 · cerrar")
	check("bandeja cerrada", ExperienceState.prompt_for("tray4", false, false, false) == "Bandeja 4 · abrir")
	check("otro puesto devuelve el id", ExperienceState.prompt_for("zoneSwitch", false, false, false) == "zoneSwitch")
	near("alcance del andén", ExperienceState.reach_for("railCallA"), 3.15)
	near("alcance de la página", ExperienceState.reach_for("page3"), 1.65)
	near("alcance general", ExperienceState.reach_for("charger"), 2.2)


# --------------------------------------------------------------------------- #
func _quality() -> void:
	print("\n[perfiles de calidad]")
	check("tres perfiles", ExperienceState.QUALITIES == ["low", "medium", "high"])
	near("densidad baja de escritorio", ExperienceState.render_density("low", 1920.0, 1080.0), 0.85)
	near("densidad media de escritorio",
		ExperienceState.render_density("medium", 1920.0, 1080.0, false, 2.0), 1.15)
	near("densidad alta de escritorio",
		ExperienceState.render_density("high", 1920.0, 1080.0, false, 2.0), 1.65)
	near("densidad limitada por el dispositivo",
		ExperienceState.render_density("high", 800.0, 600.0, false, 1.0), 1.0)
	var touch_high := ExperienceState.render_density("high", 1000.0, 800.0, true, 3.0)
	check("en táctil manda el presupuesto de píxeles",
		touch_high <= 2.75 and touch_high <= sqrt(3300000.0 / 800000.0) + 0.001, str(touch_high))
	near("táctil con pantalla pequeña", ExperienceState.render_density("low", 480.0, 320.0, true, 3.0),
		minf(1.25, 3.0))
	near("FOV en primera persona", ExperienceState.fov_for(true, 1920.0, 1080.0), 68.0)
	near("FOV orbital apaisado", ExperienceState.fov_for(false, 1920.0, 1080.0), 35.0)
	near("FOV orbital vertical", ExperienceState.fov_for(false, 720.0, 900.0), 49.0)
	check("vídeo de CCTV en escritorio", ExperienceState.video_width("high") == 448)
	check("vídeo en táctil alto", ExperienceState.video_width("high", true) == 896)
	check("vídeo en táctil medio", ExperienceState.video_width("medium", true) == 640)
	check("sombras sólo en alto", ExperienceState.shadows_enabled("high")
		and not ExperienceState.shadows_enabled("medium") and not ExperienceState.shadows_enabled("low"))
	check("brillo apagado en bajo", not ExperienceState.bloom_enabled("low")
		and ExperienceState.bloom_enabled("medium"))
	near("brillo alto", ExperienceState.bloom_strength("high"), 0.19)
	near("brillo medio", ExperienceState.bloom_strength("medium"), 0.13)
	check("calidad guardada manda", ExperienceState.initial_quality("low") == "low")
	check("pantalla estrecha en bajo", ExperienceState.initial_quality("", false, 600.0) == "low")
	check("calidad en pantalla ancha", ExperienceState.initial_quality("", false, 1280.0) == "medium")
	check("calidad táctil", ExperienceState.initial_quality("", true, 400.0) == "medium")
	var nx := kit()
	check("cambia de perfil", nx.set_quality("low") == "low" and nx.quality == "low")
	check("perfil inválido cae en medio", nx.set_quality("ultra") == "medium")
	check("recorre perfiles", nx.next_quality() == "high" and nx.next_quality() == "low")


# --------------------------------------------------------------------------- #
func _persistence() -> void:
	print("\n[persistencia]")
	var nx := kit()
	nx.action("uv")
	nx.bind_slot(0, "pulse")
	nx.select_slot(0)
	nx.use_slot()
	nx.energy = 55.0
	nx.battery = 77.0
	nx.mode = "lure"
	nx.set_quality("low")
	nx.charged = false
	var blob := nx.to_dict()
	check("guarda las ranuras como texto", blob["slots"] is Array)
	var copy := kit()
	check("restaura", copy.from_dict(blob))
	near("energía restaurada", copy.energy, 55.0)
	near("batería restaurada", copy.battery, 77.0)
	check("modo restaurado", copy.mode == "lure", copy.mode)
	check("ranura restaurada", str(copy.slots[0]) == "pulse", str(copy.slots[0]))
	check("perfil restaurado", copy.quality == "low")
	check("celda restaurada", not copy.charged)
	check("diccionario vacío no rompe", not kit().from_dict({}))
	var dirty := kit()
	dirty.from_dict({"mode": "otro", "quality": "ultra", "slot": 9})
	check("valores inválidos se corrigen", dirty.mode == "touch" and dirty.quality == "medium"
		and dirty.slot == 4, "%s %s %d" % [dirty.mode, dirty.quality, dirty.slot])


# --------------------------------------------------------------------------- #
func _game_integration() -> void:
	print("\n[integración]")
	var state := GameState.new()
	state.power_simulation = false
	check("la partida tiene estado de experiencia", state.experience != null)
	check("perfil por defecto", state.quality() == "high", state.quality())
	check("cambia el perfil", state.set_quality("medium") == "medium")
	check("instantánea disponible", state.experience_snapshot().has("energy"))
	var blob := state.experience.to_dict()
	state.experience.from_dict({"energy": 12.0, "battery": 34.0, "quality": "low"})
	near("el estado se actualiza", state.experience.energy, 12.0)
	check("el perfil se propaga", state.quality() == "low")
	check("restaura el estado previo", state.experience.from_dict(blob))
	check("acción de calidad mapeada", InputMap.has_action(&"cycle_quality"))
	state.free()
