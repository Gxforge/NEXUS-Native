class_name TelemetryFeed
extends Node
## Alimenta una `WallScreen` con el estado vivo de la partida.
##
## La web pinta `CAM 04` desde el bucle de la experiencia con `Power`, la
## integridad del sujeto, su distancia, su estado y su intención. Aquí el mismo
## muestreo sale de `GameState` y del actor W–01 de la zona activa.

@export var screen_path: NodePath = ^"Cam04"
@export var subject_path: NodePath = ^""
@export var clock := 0.0

var screen: WallScreen = null
var _subject: Node = null


func _ready() -> void:
	screen = get_node_or_null(screen_path) as WallScreen
	if not subject_path.is_empty():
		_subject = get_node_or_null(subject_path)
	set_process(screen != null)


func grid_snapshot(state: GameState) -> Dictionary:
	if state == null or state.power == null:
		return {"load": 0, "temp": 0.0, "capacity": 0, "tripped": false,
			"feeds": [], "fans": [], "cause": ""}
	var snapshot := state.power.snapshot()
	return {
		"load": snapshot.get("load_kw", 0.0),
		"temp": snapshot.get("temp", 0.0),
		"capacity": snapshot.get("capacity", 0.0),
		"tripped": snapshot.get("tripped", false),
		"feeds": snapshot.get("feeds_on", []),
		"fans": snapshot.get("fans_on", []),
		"cause": snapshot.get("cause", ""),
	}


## Toma una muestra del sujeto: integridad, distancia, estado e intención.
func subject_snapshot(state: GameState) -> Dictionary:
	var subject := _subject
	if subject == null and is_inside_tree():
		subject = get_tree().get_first_node_in_group(&"w01")
	if subject == null:
		var watcher: Dictionary = state.watcher_state if state != null else {}
		return {
			"hp": 100.0,
			"distance": 0.0,
			"state": str(watcher.get("state", "AUSENTE")),
			"position": Vector3.ZERO,
			"intent": str(watcher.get("intent", "Sin contacto")),
			"hits": int(watcher.get("hits", 0)),
			"aggression": float(watcher.get("aggression", 0.0)),
		}
	var ai: MonsterAI = subject.get("ai") as MonsterAI
	var attention: MonsterAttention = subject.get("attention") as MonsterAttention
	var player := get_tree().get_first_node_in_group(&"player") as Node3D
	var position := (subject as Node3D).global_position
	var distance := position.distance_to(player.global_position) if player != null else 0.0
	return {
		"hp": 100.0 - maxf(0.0, float(ai.aggression) - 0.2) * 55.0 if ai != null else 100.0,
		"distance": distance,
		"state": ai.state if ai != null else str(subject.get("state")),
		"position": position,
		"intent": attention.intent if attention != null else str(subject.get("intent")),
		"hits": int(subject.get("hits")) if subject.get("hits") != null else 0,
		"aggression": ai.aggression if ai != null else 0.0,
	}


func sample(state: GameState) -> bool:
	if screen == null:
		return false
	var subject := subject_snapshot(state)
	return screen.push_telemetry(clock, grid_snapshot(state), float(subject["hp"]),
		float(subject["distance"]), str(subject["state"]), subject["position"] as Vector3,
		str(subject["intent"]), int(subject["hits"]), float(subject["aggression"]))


func _process(delta: float) -> void:
	clock += delta
	var state := get_tree().get_first_node_in_group(&"game_state") as GameState
	if state != null:
		sample(state)


func cycle_page() -> int:
	return screen.cycle_page() if screen != null else 0
