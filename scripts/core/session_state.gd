class_name SessionState
extends RefCounted
## Estado de sesión de la interfaz.
##
## Port de la capa de `App.tsx` que no es React: ajustes persistidos (calidad,
## sensibilidad, consejos), detección de dispositivo, navegación de paneles con
## las mismas reglas que la web (pausa, reanudación, cierre de paneles de datos),
## avisos de una sola vez y bitácora de sesión de 60 entradas con marca de hora.

const PANELS := ["", "inventory", "map", "database", "document", "archive", "pause", "cfg", "log"]
const DATA_PANELS := ["map", "document", "database", "inventory"]
const SENSITIVITY_MIN := 0.35
const SENSITIVITY_MAX := 2.5
const SENSITIVITY_STEP := 0.05
const LOG_LIMIT := 60
const TIP_DELAY := 0.55
const TIP_DURATION := 5.95
const TIP_COOLDOWN := 6.0
const PART_IDS := ["eye-0", "maw", "eye-1", "eye-2", "eye-3", "eye-4", "eye-5", "eye-6"]

## Ajustes.
var quality := "high"
var sensitivity := 1.0
var guides := true
var device := "pc"

## Paneles y pausa.
var panel := ""
var paused := false
var first_person := false
var zoom := false
var quick := false
var tools_open := false
var error := ""

## Avisos de una sola vez y bitácora.
var shown_tips: Array[String] = []
var entries: Array[Dictionary] = []
var tip := ""
var _tip_timer := 0.0
var _tip_remaining := 0.0
var _tip_cooldown := 0.0

func _init(preset := "medium", initial_sensitivity := 1.0) -> void:
	quality = preset
	sensitivity = clamp_sensitivity(initial_sensitivity)
	log_entry("Enlace CAM-04 establecido")
	log_entry("Protocolos NEXUS disponibles")


# --------------------------------------------------------------------------- #
# ajustes
# --------------------------------------------------------------------------- #
## Dispositivo como en la web: Android, Táctil o PC.
static func detect_device(android := false, touch := false, coarse := false) -> String:
	if android:
		return "android"
	if touch and coarse:
		return "touch"
	return "pc"


func device_label() -> String:
	return {"android": "Android", "touch": "Táctil", "pc": "PC"}.get(device, "PC")


static func clamp_sensitivity(value: float) -> float:
	var clamped := clampf(value, SENSITIVITY_MIN, SENSITIVITY_MAX)
	return snappedf(clamped, SENSITIVITY_STEP)


func set_sensitivity(value: float) -> float:
	sensitivity = clamp_sensitivity(value)
	return sensitivity


## Paso de la barra de ajustes (0,05 por muesca).
func nudge_sensitivity(steps: int) -> float:
	return set_sensitivity(sensitivity + steps * SENSITIVITY_STEP)


func set_guides(enabled: bool) -> void:
	guides = enabled


func set_quality(preset: String) -> String:
	quality = preset if ExperienceState.QUALITIES.has(preset) else quality
	return quality


## Multiplicador aplicado a la mirada del jugador (1× por defecto).
func look_scale() -> float:
	return sensitivity


## Texto de ayuda según el dispositivo (`cfg` de la web).
func input_hint() -> String:
	if device == "pc":
		return "Mayús + WASD para correr. WASD para caminar, ratón para mirar y clic para " \
			+ "interactuar con la retícula. Esc o P abre la pausa. Si el navegador bloquea " \
			+ "la captura, arrastra para girar."
	return "Botón de huellas para alternar carrera. Pulgar izquierdo en el joystick fijo " \
		+ "para caminar. Arrastra con la derecha sobre la escena para mirar; toca sin " \
		+ "arrastrar para interactuar."


func manuals() -> Array[String]:
	return [
		"A–01: linterna y estación de carga. B–02: tarjeta de acceso y bóveda V–03. " \
			+ "E o la mano recoge e interactúa; usa 1–5 para seleccionar o abre la mochila (I) " \
			+ "para configurar los accesos. R o el icono de objeto lo usa. Q activa el escáner. " \
			+ "Las puertas exteriores se abren al acercarte.",
		"Reserva 32 de energía para escapar de un agarre. El pulso tarda 8 s en recargar. " \
			+ "Los apagones solo ocurren en primera persona.",
		"Q saca el escáner y registra el objeto situado en la retícula. Con el escáner " \
			+ "equipado, R repite la lectura. B abre la base de datos. Z alterna emisor UV, " \
			+ "proyector criogénico y mano libre; R o clic emite un pulso. F controla la linterna.",
	]


# --------------------------------------------------------------------------- #
# paneles
# --------------------------------------------------------------------------- #
func set_panel(name: String) -> bool:
	if not PANELS.has(name):
		return false
	panel = name
	return true


func open_panel(name: String) -> bool:
	if not set_panel(name):
		return false
	if panel == "pause":
		paused = true
	return true


## Cierre como en la web: los paneles de datos reanudan; el resto vuelve a la pausa.
func close_panel() -> String:
	if DATA_PANELS.has(panel):
		resume()
		return panel
	if paused:
		panel = "pause"
	else:
		panel = ""
	return panel


func pause() -> bool:
	if not error.is_empty() or paused:
		return false
	paused = true
	panel = "pause"
	first_person = first_person
	return true


func resume() -> bool:
	panel = ""
	paused = false
	zoom = false
	return true


func reset_session() -> void:
	panel = ""
	paused = false
	first_person = false
	zoom = false
	quick = false
	tools_open = false
	log_entry("Sesión de contención reiniciada")


## Cambio de vista: registra el modo y devuelve si la simulación sigue activa.
func set_view(next_first_person: bool) -> String:
	if not error.is_empty():
		return ""
	first_person = next_first_person
	zoom = next_first_person
	tools_open = false
	quick = false
	var message := "Operador en primera persona" if next_first_person else "Cámara orbital activa"
	log_entry(message)
	return message


## Simulación activa (`setActive(!paused && !panel)` de la web).
func active() -> bool:
	return not paused and panel.is_empty() and error.is_empty()


func set_error(text: String) -> void:
	error = text
	paused = true


# --------------------------------------------------------------------------- #
# bitácora
# --------------------------------------------------------------------------- #
func log_entry(text: String, stamp := "") -> void:
	var entry := {"s": text, "at": stamp if not stamp.is_empty() else time_stamp()}
	entries.push_front(entry)
	while entries.size() > LOG_LIMIT:
		entries.pop_back()


static func time_stamp(hour := 0, minute := 0) -> String:
	return "%02d:%02d" % [hour, minute]


func log_lines() -> Array[String]:
	var lines: Array[String] = []
	for entry in entries:
		lines.append("%s  %s" % [str(entry.get("at", "")), str(entry.get("s", ""))])
	return lines


# --------------------------------------------------------------------------- #
# consejos de una sola vez
# --------------------------------------------------------------------------- #
## Identificador del consejo pendiente (`n.mode`, linterna o mochila).
static func tip_id(nx: ExperienceState) -> String:
	if nx == null:
		return "pack"
	if nx.mode == "scan":
		return "scan"
	if nx.inventory.has(&"lamp"):
		return "lamp"
	return "pack"


static func tip_text(id: String) -> String:
	match id:
		"scan":
			return "Escanear: R o toque · fichas en B"
		"lamp":
			return "Linterna izquierda: F o botón de luz"
		_:
			return "Inventario: I o mochila · 1–5 selecciona, R usa"


func tip_shown(id: String) -> bool:
	return shown_tips.has(id)


## Avanza el reloj de los consejos: programa el texto tras 0,55 s y lo retira a
## los 5,95 s (`useEffect` de la web).
func update(delta: float, nx: ExperienceState) -> String:
	_tip_cooldown = maxf(0.0, _tip_cooldown - delta)
	if not _tip_remaining <= 0.0:
		_tip_remaining = maxf(0.0, _tip_remaining - delta)
		if _tip_remaining == 0.0:
			tip = ""
		return tip
	if not guides or not first_person or not panel.is_empty() or not tip.is_empty():
		_tip_timer = 0.0
		return tip
	var id := tip_id(nx)
	if tip_shown(id) or _tip_cooldown > 0.0:
		return tip
	_tip_timer += delta
	if _tip_timer < TIP_DELAY:
		return tip
	_tip_timer = 0.0
	if nx != null and nx.notice > 0.0:
		return tip
	shown_tips.append(id)
	tip = tip_text(id)
	_tip_remaining = TIP_DURATION
	return tip


## Marca el consejo como mostrado sin esperar al temporizador (pruebas).
func mark_tip(id: String) -> void:
	if not shown_tips.has(id):
		shown_tips.append(id)


func dismiss_tip() -> void:
	tip = ""
	_tip_remaining = 0.0
	_tip_cooldown = TIP_COOLDOWN


# --------------------------------------------------------------------------- #
# persistencia
# --------------------------------------------------------------------------- #
func to_dict() -> Dictionary:
	return {
		"quality": quality,
		"sensitivity": sensitivity,
		"guides": guides,
		"device": device,
		"tips": shown_tips.duplicate(),
	}


func from_dict(data: Dictionary) -> bool:
	if data.is_empty():
		return false
	quality = str(data.get("quality", quality))
	if not ExperienceState.QUALITIES.has(quality):
		quality = "medium"
	sensitivity = clamp_sensitivity(float(data.get("sensitivity", sensitivity)))
	guides = bool(data.get("guides", guides))
	var next_device := str(data.get("device", device))
	device = next_device if ["pc", "touch", "android"].has(next_device) else "pc"
	shown_tips = []
	var raw: Variant = data.get("tips", [])
	if raw is Array:
		for entry in raw:
			shown_tips.append(str(entry))
	return true
