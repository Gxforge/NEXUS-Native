class_name MonsterAttention
extends RefCounted
## Percepción local, audición y memoria breve de W–01.
##
## Port de `src/scene/Attention.ts`: sin red y sin trampas. El sujeto ve dentro
## de su cono de 1,29 rad a 33 m, oye pasos hasta 8 m (16 m si el operador corre),
## recuerda el último contacto 5,4 s, bordea la malla de contención y se detiene
## antes de pisar al jugador.

const MEMORY_SECONDS := 5.4
const SIGHT_RANGE := 33.0
const SIGHT_CONE := 1.29
const HEARING_WALK := 8.0
const HEARING_SPRINT := 16.0
const CONTAINMENT_Z := -13.45
const ATTACK_RANGE := 5.45
const APPROACH_RANGE := 10.0
const MIN_STANDOFF := 2.8
const PATROL_RADIUS := 9.8
const AVOID_BASE := 4.15
const AVOID_LEARNED := 1.65
const SAMPLE_SECONDS := 3.0

var field_memory: FieldMemory = FieldMemory.new()
var memory := 0.0
var intent := "En espera"
var clock := 0.0
var last_known := Vector3(0.0, 1.72, 8.0)
var prior := Vector3(0.0, 1.72, 9.2)
var seen := false
var heard := false

var _sample := 0.0


func reset() -> void:
	memory = 0.0
	clock = 0.0
	_sample = 0.0
	prior = Vector3(0.0, 1.72, 9.2)
	last_known = Vector3(0.0, 1.72, 8.0)
	intent = "En espera"
	seen = false
	heard = false


## Un paso de percepción y navegación. No toca nodos: devuelve lo que hay que
## aplicar al actor (`yaw`, `position`, `intent`, `target`, `speed`).
func update(position: Vector3, yaw: float, player: Vector3, delta: float,
		bait: Variant = null, recover := false, grab := false, cold := false,
		sprint := false) -> Dictionary:
	clock += delta
	var to_player := player - position
	var distance := Vector2(to_player.x, to_player.z).length()
	var bearing := atan2(to_player.x, to_player.z)
	var facing := absf(_wrap(bearing - yaw))
	seen = player.z > CONTAINMENT_Z and distance < SIGHT_RANGE and facing < SIGHT_CONE
	var moving := player.distance_squared_to(prior) > 0.00012
	heard = player.z > CONTAINMENT_Z \
		and distance < (HEARING_SPRINT if sprint else HEARING_WALK) and moving
	prior = player
	if seen or heard:
		memory = MEMORY_SECONDS
		last_known = player
	else:
		memory = maxf(0.0, memory - delta)

	var target: Vector3 = (bait as Vector3) if bait != null else last_known
	var go := target - position
	go.y = 0.0
	var length := go.length()
	if length > 0.0001:
		go /= length

	var speed := 0.0
	var turn := 0.0
	if grab:
		intent = "Sujetando"
		return _result(position, yaw, intent, target, 0.0, speed)
	if recover or cold:
		intent = "Se repliega"
		speed = -0.42 if distance < 6.0 else 0.0
		turn = 0.5
	elif bait != null:
		intent = "Investiga el señuelo"
		turn = 1.9
		speed = 0.45
	elif seen and distance < ATTACK_RANGE:
		intent = "Acecha"
		turn = 2.1
	elif seen or heard:
		if heard and not seen:
			intent = "Escucha pasos"
		else:
			intent = "Se aproxima" if distance < APPROACH_RANGE else "Observa"
		turn = 1.35
		speed = 1.12 if distance < APPROACH_RANGE else 0.84
	elif memory > 0.0:
		intent = "Busca el último contacto"
		turn = 1.1
		speed = 0.68
	else:
		intent = "Explora"
		turn = 0.35
		last_known = Vector3(
			PATROL_RADIUS * sin(clock * 0.18),
			2.0,
			FieldMemory.CELL_CENTER.y + PATROL_RADIUS * cos(clock * 0.18))
		speed = 0.62

	if length < 1.6 and speed > 0.0:
		speed = 0.0

	# Malla de contención: no atravesarla y bordearla por el lado menos recordado.
	var wall := field_memory.edge(position.x, position.z)
	var learned := field_memory.sector_risk(int(wall["sector"]))
	var buffer: float = AVOID_BASE + learned * AVOID_LEARNED
	var nx := float(wall["nx"])
	var nz := float(wall["nz"])
	var wall_distance := float(wall["d"])
	var outward := go.x * nx + go.z * nz
	if wall_distance > -buffer - 1.1 and outward > 0.0 and speed > 0.0:
		var u := smoothstep(-buffer - 1.1, -buffer + 0.55, wall_distance)
		go.x -= nx * outward * u * 1.65
		go.z -= nz * outward * u * 1.65
		var hand := float(field_memory.safer_neighbour(int(wall["sector"])))
		go.x += nz * u * hand * 0.68
		go.z -= nx * u * hand * 0.68
		if go.length() > 0.0001:
			go = go.normalized()
		intent = "Bordea la malla"
		_sample += delta
		if _sample > SAMPLE_SECONDS:
			_sample = 0.0
			field_memory.remember(int(wall["sector"]), 0.1)

	var next_yaw := yaw + clampf(_wrap(atan2(go.x, go.z) - yaw), -turn * delta, turn * delta)
	var next_position := position
	if speed != 0.0:
		var candidate := position + go * speed * delta
		var candidate_distance := Vector2(candidate.x - player.x, candidate.z - player.z).length()
		if speed < 0.0 or candidate_distance > MIN_STANDOFF:
			next_position = candidate
	return _result(next_position, next_yaw, intent, target, distance, speed)


func _result(position: Vector3, yaw: float, next_intent: String, target: Vector3,
		distance: float, speed: float) -> Dictionary:
	return {
		"yaw": yaw,
		"position": position,
		"intent": next_intent,
		"target": target,
		"distance": distance,
		"speed": speed,
		"seen": seen,
		"heard": heard,
		"memory": memory,
	}


func _wrap(angle: float) -> float:
	return atan2(sin(angle), cos(angle))


func to_dict() -> Dictionary:
	return {
		"memory": memory,
		"intent": intent,
		"last_known": [last_known.x, last_known.y, last_known.z],
		"field_memory": field_memory.to_dict(),
	}


func from_dict(data: Dictionary) -> bool:
	if data.is_empty():
		return false
	memory = float(data.get("memory", 0.0))
	intent = str(data.get("intent", intent))
	var raw: Variant = data.get("last_known", [])
	if raw is Array and (raw as Array).size() >= 3:
		last_known = Vector3(float(raw[0]), float(raw[1]), float(raw[2]))
	var memory_data: Variant = data.get("field_memory", {})
	if memory_data is Dictionary:
		field_memory.from_dict(memory_data)
	return true
