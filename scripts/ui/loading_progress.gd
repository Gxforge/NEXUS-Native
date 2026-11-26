class_name LoadingProgress
extends RefCounted
## Porcentaje y datos reales de la pantalla de carga.
##
## El `ResourceLoader` en hilos devuelve `progress[0]` a 0 durante casi toda la
## precarga de una escena, así que una barra basada en él se queda clavada y la
## pantalla parece colgada. Aquí el plan de carga son **los propios recursos**:
## se leen las dependencias del módulo de zona (`ext_resource`), se piden en
## hilos una a una y la barra avanza con las que ya están cargadas. Dentro de
## cada recurso la barra se arrastra hacia el 85 % de su tramo, nunca más, para
## que un modelo grande no deje el indicador quieto sin mentir sobre el total.
##
## El reloj y la detección de estancamiento son parte del contrato: si pasan
## segundos sin que termine ningún recurso, la pantalla lo dice y ofrece volver
## al menú en vez de quedarse girando para siempre.

## Tramo de precarga (hasta 92 %) y el resto para montar y trasladar.
const PRELOAD_CEILING := 92.0
## Avance máximo dentro del tramo de un recurso aún sin terminar.
const CREEP_LIMIT := 0.85
## Segundos que tarda la barra en recorrer ese margen interno.
const CREEP_SECONDS := 30.0
## A partir de aquí la pantalla avisa; y a partir de `STALL_ABORT`, se puede salir.
const STALL_HINT := 15.0
const STALL_ABORT := 60.0
## Tope de recursos que se piden en un plan (por seguridad).
const PLAN_LIMIT := 64
## Manifiesto generado en la construcción (`tools/gen_load_plan.gd`). En el
## juego exportado los `.tscn` y `.glb` van remapeados y no se puede leer su
## texto, así que las dependencias y los tamaños se sacan de aquí.
const MANIFEST_PATH := "res://data/load_plan.json"

static var _manifest_zones: Dictionary = {}
static var _manifest_kb: Dictionary = {}
static var _manifest_loaded := false


## Carga (una sola vez) el manifiesto de planes de carga.
static func _load_manifest() -> void:
	if _manifest_loaded:
		return
	_manifest_loaded = true
	if not FileAccess.file_exists(MANIFEST_PATH):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var zones: Variant = (parsed as Dictionary).get("zones", {})
	if typeof(zones) != TYPE_DICTIONARY:
		return
	for module_path: String in (zones as Dictionary):
		var entry: Variant = (zones as Dictionary)[module_path]
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var paths := PackedStringArray()
		for item: Variant in (entry as Dictionary).get("files", []):
			if typeof(item) != TYPE_DICTIONARY:
				continue
			var path := str((item as Dictionary).get("path", ""))
			if path.is_empty():
				continue
			paths.append(path)
			_manifest_kb[path] = float((item as Dictionary).get("kb", 0.0))
		if not paths.is_empty():
			_manifest_zones[module_path] = paths


## Recursos del manifiesto para un módulo (vacío si no está listado).
static func manifest_entries(module_path: String) -> PackedStringArray:
	_load_manifest()
	var listed: Variant = _manifest_zones.get(module_path)
	if typeof(listed) == TYPE_PACKED_STRING_ARRAY:
		return listed
	return PackedStringArray()


## Zonas que cubre el manifiesto (para la validación).
static func manifest_modules() -> PackedStringArray:
	_load_manifest()
	var modules := PackedStringArray()
	for module_path: String in _manifest_zones:
		modules.append(module_path)
	modules.sort()
	return modules


## ¿Se puede pedir este recurso? `ResourceLoader.exists` tiene en cuenta los
## remapeos del juego exportado; `FileAccess` no.
static func has_resource(path: String) -> bool:
	return ResourceLoader.exists(path) or FileAccess.file_exists(path)


## Rutas que hay que cargar para montar un módulo: sus dependencias primero y
## el módulo al final, para que lo encuentre todo en caché.
static func plan(module_path: String, depth := 2, from_manifest := true) -> PackedStringArray:
	if from_manifest:
		var listed := manifest_entries(module_path)
		if not listed.is_empty():
			return listed
	var order: Array[String] = []
	var seen := {}
	var frontier: Array[String] = [module_path]
	var level := 0
	while not frontier.is_empty() and level <= depth and order.size() < PLAN_LIMIT:
		var next: Array[String] = []
		for path: String in frontier:
			if seen.has(path) or not has_resource(path):
				continue
			seen[path] = true
			order.append(path)
			for dependency: String in references(path):
				if not seen.has(dependency):
					next.append(dependency)
		frontier = next
		level += 1
	if not seen.has(module_path):
		return PackedStringArray()
	order.erase(module_path)
	order.append(module_path)
	return PackedStringArray(order)


## Rutas externas que declara un `.tscn`/`.tres` (vacío para otros formatos).
static func references(path: String) -> PackedStringArray:
	var found := PackedStringArray()
	if not path.ends_with(".tscn") and not path.ends_with(".tres"):
		return found
	if not FileAccess.file_exists(path):
		return found
	for line: String in FileAccess.get_file_as_string(path).split("\n"):
		var marker := line.find("path=\"res://")
		if marker < 0:
			continue
		var start := marker + 6
		var end := line.find("\"", start)
		if end <= start:
			continue
		var resource := line.substr(start, end - start)
		if not found.has(resource):
			found.append(resource)
	return found


## Recursos externos que declara el módulo (lo que hay que cargar).
static func dependencies(path: String) -> int:
	return references(path).size()


## Tamaño en disco de un recurso del proyecto (0 si no existe).
static func file_kb(path: String) -> float:
	if not FileAccess.file_exists(path):
		return 0.0
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return 0.0
	var size := file.get_length()
	file.close()
	return float(size) / 1024.0


## Tamaño de un recurso del plan: manifiesto primero, disco después.
static func plan_file_kb(path: String) -> float:
	_load_manifest()
	if _manifest_kb.has(path):
		return float(_manifest_kb[path])
	return file_kb(path)


## Megabytes totales del plan.
static func plan_megabytes(paths: PackedStringArray) -> float:
	var kilobytes := 0.0
	for path: String in paths:
		kilobytes += plan_file_kb(path)
	return kilobytes / 1024.0


## Porcentaje a pintar: recursos terminados, arrastre dentro del actual y el
## peso del estado del `ZoneManager` cuando ya se está montando la zona.
static func value(done: int, total: int, elapsed: float, state := ZoneManager.State.IDLE,
		mounted := false) -> float:
	if mounted:
		var weight := stage_weight(state)
		if state == ZoneManager.State.IDLE:
			return 100.0
		return clampf(PRELOAD_CEILING + weight * (100.0 - PRELOAD_CEILING), PRELOAD_CEILING, 99.0)
	var slots := maxi(total, 1)
	var creep := clampf(elapsed / CREEP_SECONDS, 0.0, 1.0) * CREEP_LIMIT
	var fraction := (float(clampi(done, 0, slots)) + creep) / float(slots)
	return clampf(fraction * PRELOAD_CEILING, 0.0, PRELOAD_CEILING)


## Peso del estado del `ZoneManager` dentro del tramo de montaje.
static func stage_weight(state: int) -> float:
	match state:
		ZoneManager.State.VALIDATING:
			return 0.05
		ZoneManager.State.REQUESTING:
			return 0.15
		ZoneManager.State.LOADING:
			return 0.35
		ZoneManager.State.STAGING:
			return 0.72
		ZoneManager.State.TRANSFERRING:
			return 0.88
		ZoneManager.State.RELEASING:
			return 0.96
		ZoneManager.State.IDLE:
			return 1.0
	return 0.0


## Paso en curso, en lenguaje del operador.
static func step_name(state: int, done := 0, total := 0, mounted := false) -> String:
	if not mounted:
		if total > 0:
			return "Cargando recursos · %d de %d" % [clampi(done, 0, total), total]
		return "Preparando la zona"
	match state:
		ZoneManager.State.IDLE:
			return "Zona lista"
		ZoneManager.State.RELEASING:
			return "Liberando la zona anterior"
		ZoneManager.State.TRANSFERRING:
			return "Trasladando al operador"
		ZoneManager.State.STAGING:
			return "Colocando el atrezzo original"
	return "Montando la zona"


## Reloj en `m:ss` (o `h:mm:ss` si hiciera falta).
static func format_clock(seconds: float) -> String:
	var whole := int(maxf(seconds, 0.0))
	var hours := whole / 3600
	var minutes := (whole % 3600) / 60
	var secs := whole % 60
	if hours > 0:
		return "%d:%02d:%02d" % [hours, minutes, secs]
	return "%d:%02d" % [minutes, secs]


## Línea de datos: zona, recursos, peso y tiempo. Sin enums del motor.
static func details(zone_id: StringName, module_path: String, done: int, total: int,
		megabytes: float, elapsed: float, stalled := 0.0) -> String:
	var zone := str(zone_id).to_upper().replace("_", " ")
	var line := "%s · %s · %d de %d recursos · %.1f MB · %s" % [
		zone,
		module_path.get_file(),
		clampi(done, 0, maxi(total, 0)),
		maxi(total, 0),
		maxf(megabytes, 0.0),
		format_clock(elapsed),
	]
	if stalled >= 1.0:
		line += " · sin avance %s" % format_clock(stalled)
	return line


## Aviso de estancamiento, o cadena vacía mientras todo va bien.
static func stall_hint(stalled: float) -> String:
	if stalled < STALL_HINT:
		return ""
	if stalled < STALL_ABORT:
		return "Un recurso grande está tardando más de lo normal."
	return "La carga no avanza. Puedes volver al menú y reintentarlo."
