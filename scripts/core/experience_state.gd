class_name ExperienceState
extends RefCounted
## Estado de la experiencia y perfiles de calidad.
##
## Port del contrato de `SceneExperience.ts` que no es geometría: el objeto `nx`
## (energía, batería, protocolos, modo, ranuras, armas, frío, señuelo, agarre y
## pérdida), las reglas de `bindSlot`/`selectSlot`/`useSlot`, los costes y
## recargas de `protocols.ts`, los rótulos de piezas, y los perfiles de
## `DisplayQuality.ts` (densidad de render, FOV por modo y tamaño de vídeo).
##
## La escena, el render y el audio no se portan aquí: cada sistema nativo
## (jugador, HUD, zonas, pantallas) consume este estado.

## Coste de energía y recarga de cada protocolo (`protocols.ts`).
const PROTOCOLS := {
	"uv": {"cost": 32.0, "cd": 8.0},
	"gas": {"cost": 24.0, "cd": 12.0},
	"lure": {"cost": 12.0, "cd": 5.0},
}
const SLOT_COUNT := 5
const ACTIVITY_MODES := ["touch", "scan", "lure"]
const QUALITIES := ["low", "medium", "high"]
const ITEMS := ["lamp", "pulse", "cryo", "cell", "recorder", "card", "sample"]
const WEAPONS := {"pulse": 1, "cryo": 2}
const NAMES := {"pulse": "Emisor UV", "cryo": "Criogénico", "lamp": "Linterna"}

## Energía y reservas.
var energy := 100.0
var battery := 100.0
var charged := true
var analyzed := false
var lamp := false
var mode := "touch"
var cold := 0.0
var bait := 0.0
var blackout := 0.0
var grab := 0.0
var lost := false
var notice := 0.0
var message := ""
## Rejillas de protocolo.
var uv := 0.0
var gas := 0.0
var lure := 0.0
var slots: Array = [null, null, null, null, null]
var slot := 0
var weapon := -1
var inventory: Array[StringName] = []
var pending := false
var target := ""
var quality := "high"

var _last_log := ""


func _init(items: Array[StringName] = []) -> void:
	inventory = items.duplicate()


func reset(items: Array[StringName] = []) -> void:
	energy = 100.0
	battery = 100.0
	charged = true
	analyzed = false
	lamp = false
	mode = "touch"
	cold = 0.0
	bait = 0.0
	blackout = 0.0
	grab = 0.0
	lost = false
	notice = 0.0
	message = ""
	uv = 0.0
	gas = 0.0
	lure = 0.0
	slots = [null, null, null, null, null]
	slot = 0
	weapon = -1
	pending = false
	target = ""
	_last_log = ""
	if not items.is_empty():
		inventory = items.duplicate()


## Última línea escrita en la bitácora (`log` de la web).
func last_log() -> String:
	return _last_log


func tell(text: String) -> void:
	message = text
	notice = 4.0
	_last_log = text


# --------------------------------------------------------------------------- #
# protocolos
# --------------------------------------------------------------------------- #
## Descuenta el coste si hay energía y la rejilla está lista (`spend` de la web).
func spend(key: String) -> bool:
	var protocol: Dictionary = PROTOCOLS.get(key, {})
	if protocol.is_empty():
		return false
	var cost := float(protocol["cost"])
	if float(get(key)) > 0.0 or energy < cost:
		_last_log = "Protocolo no disponible · espera la recarga"
		return false
	energy = maxf(0.0, energy - cost)
	set(key, float(protocol["cd"]))
	return true


## Acción de equipo (`action` de la web): linterna, escáner, señuelo y protocolos.
## Devuelve el mensaje que la web escribe en la bitácora ("" si no procede).
func action(key: String) -> String:
	if lost or pending or (grab > 0.0 and key != "uv"):
		return ""
	match key:
		"uv":
			if not spend("uv"):
				return _last_log
			grab = 0.0
			_last_log = "Pulso UV · reflejo ocular inhibido"
			return _last_log
		"gas":
			if not spend("gas"):
				return _last_log
			cold = 7.0
			_last_log = "Niebla criogénica · actividad ralentizada"
			return _last_log
		"lure", "scan":
			mode = "touch" if mode == key else key
			if mode == "scan":
				weapon = -1
			_last_log = "Señuelo armado · toca suelo o pared" if mode == "lure" \
				else ("Escáner óptico activo" if mode == "scan" else "Estímulo directo activo")
			return _last_log
		"lamp":
			if not inventory.has(&"lamp"):
				tell("Sin linterna · equipo de campo en A–01")
				return message
			if battery < 5.0 and not lamp:
				return ""
			lamp = not lamp
			_last_log = "Linterna " + ("encendida" if lamp else "apagada")
			return _last_log
	return ""


## Avance de rejillas, frío y avisos.
func update(delta: float) -> void:
	uv = maxf(0.0, uv - delta)
	gas = maxf(0.0, gas - delta)
	lure = maxf(0.0, lure - delta)
	cold = maxf(0.0, cold - delta)
	bait = maxf(0.0, bait - delta)
	blackout = maxf(0.0, blackout - delta)
	notice = maxf(0.0, notice - delta)
	energy = minf(100.0, energy + delta * 3.2)


# --------------------------------------------------------------------------- #
# ranuras
# --------------------------------------------------------------------------- #
func can_bind(index: int, item: Variant) -> bool:
	if index < 0 or index > SLOT_COUNT - 1:
		return false
	if item == null or item == "" or item == &"":
		return true
	var id := StringName(str(item))
	if id == &"lamp" and not inventory.has(&"lamp"):
		return false
	if id == &"lamp":
		return true
	return inventory.has(id)


## Asigna un objeto a una ranura, moviéndolo si ya estaba en otra (`bindSlot`).
func bind_slot(index: int, item: Variant) -> bool:
	if index < 0 or index > SLOT_COUNT - 1:
		return false
	if item != null and str(item) == "lamp":
		return false
	var id: StringName = &""
	if item != null and not str(item).is_empty():
		id = StringName(str(item))
		if not inventory.has(id):
			return false
	for cursor in SLOT_COUNT:
		if cursor != index and id != &"" and str(slots[cursor]) == str(id):
			slots[cursor] = null
	slots[index] = id if id != &"" else null
	return true


func select_slot(index: int) -> bool:
	if lost or grab > 0.0:
		return false
	if index < 0 or index > SLOT_COUNT - 1:
		return false
	slot = index
	weapon = -1
	if mode == "scan":
		mode = "touch"
	return true


## Uso de la ranura activa o de un objeto concreto (`useSlot` de la web).
func use_slot(chosen: Variant = null) -> String:
	if lost or pending or grab > 0.0:
		return ""
	if chosen == null and mode == "scan":
		return "scan"
	if chosen == null and weapon > 0:
		return "fire"
	var item: Variant = chosen if chosen != null else slots[slot]
	if chosen != null and str(chosen) != "lamp":
		mode = "touch"
		weapon = -1
	if item == null or str(item).is_empty():
		tell("Ranura vacía · busca el equipo en A–01 y B–02")
		return message
	var id := StringName(str(item))
	if not inventory.has(id):
		tell("Equipo en estación")
		return message
	if WEAPONS.has(str(id)):
		weapon = int(WEAPONS[str(id)])
		mode = "touch"
		tell(NAMES.get(str(id), str(id)) + " · listo")
		return message
	if id == &"lamp":
		return action("lamp")
	if id == &"cell":
		if not charged:
			tell("Celda agotada · recárgala en A–01")
			return message
		if energy >= 99.9 and battery >= 99.9:
			tell("Reservas completas · celda sin utilizar")
			return message
		charged = false
		battery = 100.0
		energy = minf(100.0, energy + 50.0)
		tell("Celda conectada · batería restablecida")
		return message
	if id == &"recorder":
		tell("Bitácora 03: el lector de custodia está al fondo de Turbinas.")
		return message
	if id == &"card":
		tell("Credencial V–03 · apunta al lector de B–02")
		return message
	if id == &"sample":
		tell("Informe V–03 completo" if analyzed else "Vial sellado · utiliza el analizador contiguo")
		return message
	return ""


# --------------------------------------------------------------------------- #
# rótulos
# --------------------------------------------------------------------------- #
## Nombre de pieza del sujeto (`partName` de `protocols.ts`).
static func part_name(id: String) -> String:
	if id == "maw":
		return "Fauces"
	if id.begins_with("eye"):
		return "Ojo principal" if id == "eye-0" else "Ojo satélite %s" % id.substr(4)
	return "Tentáculo %d" % (int(id.substr(4)) + 1)


## Nota de campo de cada pieza (`note` de `protocols.ts`).
static func part_note(id: String) -> String:
	if id == "maw":
		return "La mandíbula se despliega antes del agarre. Retrocede al primer espasmo."
	if id == "eye-0":
		return "El iris dominante fija el objetivo. Un pulso UV interrumpe el seguimiento de los siete ojos."
	if id.begins_with("eye"):
		return "Este ojo orienta su pupila de forma independiente. La luz focal provoca una contracción inmediata."
	return "Las ventosas reaccionan al contacto local. Un señuelo desvía la punta hacia el estímulo."


## Texto del aviso de interacción (`prompt` de la web).
static func prompt_for(id: String, done: bool, item: bool, open_state: bool) -> String:
	if id.is_empty():
		return ""
	if id == "charger" or id == "analyzer":
		var tail := "retirar" if done else ("consultar ciclo" if item else "insertar equipo")
		return ("Cargador" if id == "charger" else "Analizador") + " · " + tail
	if id.begins_with("bin"):
		return "Cajón %s · %s" % [id.substr(3), "cerrar" if open_state else "abrir"]
	if id.begins_with("tray"):
		return "Bandeja %s · %s" % [id.substr(4), "cerrar" if open_state else "abrir"]
	return id


## Alcance de cada tipo de puesto (`reachable` de la web).
static func reach_for(id: String) -> float:
	if id.begins_with("rail"):
		return 3.15
	if id.begins_with("page"):
		return 1.65
	return 2.2


# --------------------------------------------------------------------------- #
# calidad y cámara (`DisplayQuality.ts` y `resize` de la escena)
# --------------------------------------------------------------------------- #
## Densidad de render. `touch` refleja la web móvil; en escritorio el tope es
## 0,85/1,15/1,65 y en táctil 1,25/1,8/2,75 con presupuesto de píxeles.
static func render_density(preset: String, width: float, height: float,
		touch := false, device_ratio := 1.0) -> float:
	var caps := {"low": 1.25, "medium": 1.8, "high": 2.75} if touch \
		else {"low": 0.85, "medium": 1.15, "high": 1.65}
	var budget := {"low": 1300000.0, "medium": 2100000.0, "high": 3300000.0} if touch \
		else {"low": INF, "medium": INF, "high": INF}
	var cap := float(caps.get(preset, caps["medium"]))
	var area := maxf(1.0, width * height)
	var limit := minf(cap, float(device_ratio))
	if is_finite(float(budget.get(preset, INF))):
		limit = minf(limit, sqrt(float(budget[preset]) / area))
	return clampf(limit, 0.25, 4.0)


## Campo de visión por modo y proporción de pantalla (`resize` de la web).
static func fov_for(first_person: bool, width: float, height: float) -> float:
	if first_person:
		return 68.0
	return 49.0 if width / maxf(height, 1.0) < 1.1 else 35.0


## Ancho del vídeo de CCTV según perfil y pantalla (`setQuality`).
static func video_width(preset: String, touch := false) -> int:
	if not touch:
		return 448
	return {"low": 448, "medium": 640, "high": 896}.get(preset, 448)


static func shadows_enabled(preset: String) -> bool:
	return preset == "high"


static func bloom_enabled(preset: String) -> bool:
	return preset != "low"


static func bloom_strength(preset: String) -> float:
	return 0.19 if preset == "high" else 0.13


func set_quality(preset: String) -> String:
	quality = preset if QUALITIES.has(preset) else "medium"
	return quality


func next_quality() -> String:
	var index := QUALITIES.find(quality)
	return set_quality(QUALITIES[(index + 1) % QUALITIES.size()])


## Calidad inicial: guardada, o media salvo pantalla estrecha (la web usa
## `localStorage`, táctil y ancho).
static func initial_quality(stored: String, touch := false, width := 1280.0) -> String:
	if QUALITIES.has(stored):
		return stored
	if touch:
		return "medium"
	return "low" if width < 760.0 else "medium"


# --------------------------------------------------------------------------- #
# persistencia
# --------------------------------------------------------------------------- #
func to_dict() -> Dictionary:
	return {
		"energy": energy,
		"battery": battery,
		"charged": charged,
		"analyzed": analyzed,
		"lamp": lamp,
		"mode": mode,
		"uv": uv,
		"gas": gas,
		"lure": lure,
		"slots": slots.map(func(entry: Variant) -> String: return str(entry) if entry != null else ""),
		"slot": slot,
		"weapon": weapon,
		"quality": quality,
	}


func from_dict(data: Dictionary) -> bool:
	if data.is_empty():
		return false
	energy = clampf(float(data.get("energy", energy)), 0.0, 100.0)
	battery = clampf(float(data.get("battery", battery)), 0.0, 100.0)
	charged = bool(data.get("charged", charged))
	analyzed = bool(data.get("analyzed", analyzed))
	lamp = bool(data.get("lamp", lamp))
	var next_mode := str(data.get("mode", mode))
	mode = next_mode if ACTIVITY_MODES.has(next_mode) else "touch"
	uv = maxf(0.0, float(data.get("uv", uv)))
	gas = maxf(0.0, float(data.get("gas", gas)))
	lure = maxf(0.0, float(data.get("lure", lure)))
	var raw_slots: Variant = data.get("slots", [])
	if raw_slots is Array:
		slots = [null, null, null, null, null]
		for index in mini((raw_slots as Array).size(), SLOT_COUNT):
			var entry := str((raw_slots as Array)[index])
			slots[index] = StringName(entry) if not entry.is_empty() else null
	slot = clampi(int(data.get("slot", slot)), 0, SLOT_COUNT - 1)
	weapon = clampi(int(data.get("weapon", weapon)), -1, 2)
	quality = str(data.get("quality", quality)) if QUALITIES.has(str(data.get("quality", quality))) else "medium"
	return true
