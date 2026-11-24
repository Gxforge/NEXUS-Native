class_name MonsterAI
extends RefCounted
## Máquina de estados de W–01.
##
## Port de `src/scene/MonsterAI.ts`: la agresividad persigue un objetivo por
## estado, el ataque dura 1,22 s con 6,4 s de recarga y la recuperación deja al
## sujeto 2,15 s fuera de combate antes de volver al estado por distancia.

signal state_changed(state: String, previous: String)

const IDLE := "IDLE"
const WATCHING := "WATCHING"
const CURIOUS := "CURIOUS"
const AGGRESSIVE := "AGGRESSIVE"
const ATTACK := "ATTACK"
const RECOVERY := "RECOVERY"

const ATTACK_SECONDS := 1.22
const RECOVERY_SECONDS := 2.15
const ATTACK_COOLDOWN := 6.4
const RECOVER_COOLDOWN := 5.0
const ATTACK_RANGE := 5.45

const TARGETS := {
	"IDLE": 0.05,
	"WATCHING": 0.2,
	"CURIOUS": 0.46,
	"AGGRESSIVE": 0.79,
	"ATTACK": 1.0,
	"RECOVERY": 0.31,
}

var state := WATCHING
var aggression := 0.2
var state_elapsed := 0.0
var attack_cooldown := 0.0


## Empuje del ataque: seno durante el golpe, caída exponencial en la recarga.
func attack_drive() -> float:
	if state == ATTACK:
		return sin(clampf(state_elapsed / ATTACK_SECONDS, 0.0, 1.0) * PI)
	if state == RECOVERY:
		return 0.42 * exp(-state_elapsed * 1.15)
	return 0.0


func recover() -> void:
	attack_cooldown = RECOVER_COOLDOWN
	transition(RECOVERY)
	state_elapsed = 0.0


func reset() -> void:
	state = WATCHING
	aggression = 0.2
	state_elapsed = 0.0
	attack_cooldown = 0.0


func update(distance: float, delta: float, blocked := false) -> void:
	state_elapsed += delta
	attack_cooldown = maxf(0.0, attack_cooldown - delta)

	if state == ATTACK:
		if state_elapsed >= ATTACK_SECONDS:
			transition(RECOVERY)
	elif state == RECOVERY:
		if state_elapsed >= RECOVERY_SECONDS and not blocked:
			transition(state_for_distance(distance))
	elif distance < ATTACK_RANGE and attack_cooldown <= 0.0 and not blocked:
		attack_cooldown = ATTACK_COOLDOWN
		transition(ATTACK)
	else:
		transition(state_for_distance(distance))

	aggression = lerpf(aggression, float(TARGETS.get(state, 0.2)),
		1.0 - exp(-1.55 * delta))


func state_for_distance(distance: float) -> String:
	if distance > 11.5:
		return IDLE
	if distance > 7.1:
		return WATCHING
	if distance > 5.05:
		return CURIOUS
	return AGGRESSIVE


func transition(next: String) -> void:
	if next == state:
		return
	var previous := state
	state = next
	state_elapsed = 0.0
	state_changed.emit(state, previous)


func is_hostile() -> bool:
	return state == AGGRESSIVE or state == ATTACK


func to_dict() -> Dictionary:
	return {
		"state": state,
		"aggression": aggression,
		"state_elapsed": state_elapsed,
		"attack_cooldown": attack_cooldown,
	}


func from_dict(data: Dictionary) -> bool:
	if data.is_empty():
		return false
	var next := str(data.get("state", state))
	if TARGETS.has(next):
		state = next
	aggression = clampf(float(data.get("aggression", aggression)), 0.0, 1.0)
	state_elapsed = maxf(0.0, float(data.get("state_elapsed", 0.0)))
	attack_cooldown = maxf(0.0, float(data.get("attack_cooldown", 0.0)))
	return true
