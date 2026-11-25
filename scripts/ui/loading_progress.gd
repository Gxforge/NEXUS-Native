class_name LoadingProgress
extends RefCounted
## Porcentaje y datos reales de la pantalla de carga.
##
## El `ResourceLoader` en hilos devuelve `progress[0]` a 0 durante casi toda la
## precarga de una escena: el hilo principal sólo informa de los recursos que ha
## terminado, así que la barra se quedaba clavada en el 0 % que se veía en el
## juego. Aquí el porcentaje se compone de tres cosas **medibles**:
##
## 1. lo que reporta el cargador (`progress[0]`), si reporta algo;
## 2. un suelo que avanza con el tiempo real transcurrido (asíntota al 60 %),
##    para que la barra siempre se mueva mientras se trabaja;
## 3. el estado real de `ZoneManager` (VALIDANDO, SOLICITANDO, CARGANDO, …), que
##    es lo que de verdad está pasando en cada momento.

## Reparto del 70 % de precarga y del 30 % de montaje de la zona.
const PRELOAD_CEILING := 70.0
const PRELOAD_FLOOR := 8.0
const PRELOAD_FLOOR_SPAN := 52.0
const PRELOAD_FLOOR_RATE := 1.6


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


## Porcentaje a pintar (0–100).
static func value(reported: float, status: ResourceLoader.ThreadLoadStatus, state: int, elapsed: float) -> float:
	match status:
		ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			var floor_value := PRELOAD_FLOOR + (1.0 - exp(-maxf(elapsed, 0.0) * PRELOAD_FLOOR_RATE)) * PRELOAD_FLOOR_SPAN
			return clampf(maxf(reported * PRELOAD_CEILING, floor_value), 0.0, PRELOAD_CEILING - 2.0)
		ResourceLoader.THREAD_LOAD_LOADED:
			var mounted := stage_weight(state)
			if state == ZoneManager.State.IDLE:
				return 100.0
			return clampf(PRELOAD_CEILING + mounted * (100.0 - PRELOAD_CEILING), PRELOAD_CEILING, 99.0)
	return 0.0


## Nombre del paso en curso, tal como lo nombra el `ZoneManager`.
static func step_name(status: ResourceLoader.ThreadLoadStatus, state: int) -> String:
	match status:
		ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			return "Precargando geometría y recursos"
		ResourceLoader.THREAD_LOAD_LOADED:
			match state:
				ZoneManager.State.VALIDATING:
					return "Validando la zona"
				ZoneManager.State.REQUESTING:
					return "Solicitando instancias"
				ZoneManager.State.LOADING:
					return "Montando la escena"
				ZoneManager.State.STAGING:
					return "Colocando el atrezzo original"
				ZoneManager.State.TRANSFERRING:
					return "Trasladando al operador"
				ZoneManager.State.RELEASING:
					return "Liberando la zona anterior"
				ZoneManager.State.IDLE:
					return "Zona lista"
			return "Montando la zona"
		ResourceLoader.THREAD_LOAD_FAILED:
			return "No se pudo cargar la zona"
		ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			return "Recurso de zona no válido"
	return "Esperando solicitud"


## Línea de datos: zona, módulo, tamaño en disco, dependencias, tiempo y estado.
static func details(zone_id: StringName, module_path: String, size_kb: float, elapsed: float,
		reported: float, state: int) -> String:
	var module := module_path.get_file()
	return "%s · %s · %.0f KB · %d dependencias · %.1f s · informe %.0f %% · estado %s" % [
		str(zone_id).to_upper(),
		module,
		size_kb,
		dependencies(module_path),
		maxf(elapsed, 0.0),
		clampf(reported, 0.0, 1.0) * 100.0,
		_state_label(state),
	]


## Recursos externos que declara el módulo de zona (lo que hay que cargar).
static func dependencies(path: String) -> int:
	if not FileAccess.file_exists(path):
		return 0
	var text := FileAccess.get_file_as_string(path)
	return text.count("[ext_resource")


static func _state_label(state: int) -> String:
	var names := ["IDLE", "VALIDANDO", "SOLICITANDO", "CARGANDO", "MONTANDO", "TRASLADANDO",
		"LIBERANDO", "FALLO"]
	if state < 0 or state >= names.size():
		return "—"
	return names[state]


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
