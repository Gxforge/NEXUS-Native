extends SceneTree
## Valida la IA y la percepción de W–01 frente a `MonsterAI.ts` + `Attention.ts`
## + `FieldSense.ts`.

var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error("QA FAIL: %s" % message)
	else:
		print("QA PASS: ", message)

func _close(a: float, b: float, tolerance := 0.001) -> bool:
	return absf(a - b) <= tolerance

func _run() -> void:
	print("== MonsterAI: estados por distancia ==")
	var ai := MonsterAI.new()
	_check(ai.state == "WATCHING", "arranca observando")
	_check(_close(ai.aggression, 0.2), "la agresividad inicial es 0,2")
	_check(ai.state_for_distance(20.0) == "IDLE", "a 20 m queda inactivo")
	_check(ai.state_for_distance(9.0) == "WATCHING", "a 9 m observa")
	_check(ai.state_for_distance(6.0) == "CURIOUS", "a 6 m tiene curiosidad")
	_check(ai.state_for_distance(4.0) == "AGGRESSIVE", "a 4 m es agresivo")

	print("== MonsterAI: ataque, recarga y recuperación ==")
	ai.update(4.0, 0.1)
	_check(ai.state == "ATTACK", "a menos de 5,45 m ataca")
	_check(_close(ai.attack_cooldown, 6.4), "el ataque fija 6,4 s de recarga")
	ai.update(4.0, 0.4)
	_check(ai.attack_drive() > 0.0, "el empuje del ataque es positivo")
	ai.update(4.0, 0.7)
	_check(ai.state == "ATTACK", "el golpe dura 1,22 s")
	ai.update(4.0, 0.2)
	_check(ai.state == "RECOVERY", "tras el golpe pasa a recuperación")
	var recovered_drive := ai.attack_drive()
	_check(recovered_drive > 0.0 and recovered_drive <= 0.42, "la recuperación decae desde 0,42")
	ai.update(4.0, 2.2)
	_check(ai.state == "AGGRESSIVE", "tras 2,15 s vuelve al estado por distancia")
	_check(ai.aggression > 0.4, "la agresividad sube al volver a agresivo")
	ai.recover()
	_check(ai.state == "RECOVERY" and _close(ai.attack_cooldown, 5.0), "recover fija la recarga de 5 s")
	ai.reset()
	_check(ai.state == "WATCHING" and _close(ai.aggression, 0.2), "reset devuelve al estado inicial")
	var sentinel := ai.state_for_distance(4.0)
	_check(sentinel == "AGGRESSIVE", "la distancia sigue resolviendo tras el reset")

	print("== FieldSense: malla de contención ==")
	var memory := FieldMemory.new()
	_check(memory.risk.size() == 24, "veinticuatro sectores de memoria")
	_check(_close(FieldMemory.apothem(), 15.0 * cos(PI / 24.0), 0.0001),
		"la apotema sale del radio 15 y el paso de 15°")
	var centre := memory.edge(0.0, 22.0)
	_check(float(centre["d"]) < 0.0, "el centro está dentro de la malla")
	_check(int(centre["sector"]) >= 0 and int(centre["sector"]) < 24, "el sector está en rango")
	var outer := memory.edge(0.0, 60.0)
	_check(float(outer["d"]) > 0.0, "un punto lejano queda fuera de la malla")
	var wrapped := memory.edge(0.0, 22.0 - 3.0)
	_check(int(wrapped["sector"]) == 12, "el sector opuesto es el 12")
	_check(memory.sector_risk(0) == 0.0, "sin memoria el riesgo es cero")
	_check(memory.remember(4, 0.1), "recordar cambia el valor visible")
	_check(_close(memory.sector_risk(4), 0.1), "el riesgo suma 0,1")
	_check(not memory.remember(4, 0.0005) or _close(memory.sector_risk(4), 0.1, 0.01),
		"sumas pequeñas no cambian el décimo")
	for _index in 20:
		memory.remember(4, 0.2)
	_check(memory.sector_risk(4) <= 1.0, "el riesgo se satura en 1")
	_check(memory.total_risk() > 0.5, "el riesgo total acumula")
	memory.reset()
	_check(_close(memory.total_risk(), 0.0), "reset limpia la memoria")

	print("== Attention: ver, oír y memoria ==")
	var attention := MonsterAttention.new()
	var monster := Vector3(0.0, 0.0, 22.0)
	var player := Vector3(0.0, 1.72, 28.0)
	var step := attention.update(monster, 0.0, player, 0.1)
	_check(bool(step["seen"]), "de frente y a 6 m lo ve")
	_check(_close(attention.memory, 5.4), "ver fija la memoria en 5,4 s")
	_check(attention.last_known.distance_to(player) < 0.01, "recuerda el último contacto")
	attention.reset()
	var behind := Vector3(0.0, 1.72, 10.0)
	step = attention.update(monster, 0.0, behind, 0.1)
	_check(not bool(step["seen"]), "a su espalda no lo ve")
	_check(attention.memory < 5.4, "sin verlo la memoria no se llena")
	var silent := attention.update(monster, 0.0, behind, 0.1)
	_check(bool(silent["heard"]) == false, "quieto y detrás no lo oye")
	var walker := attention.update(monster, 0.0, Vector3(0.0, 1.72, 20.0), 0.1)
	_check(bool(walker["heard"]) or attention.memory > 0.0, "si se mueve cerca lo registra")
	attention.reset()
	var far := Vector3(0.0, 1.72, 70.0)
	step = attention.update(monster, 0.0, far, 0.1)
	_check(not bool(step["seen"]), "a 20 m y de espaldas no ve")
	_check(attention.intent == "Explora", "sin contacto explora")
	_check(_close(attention.memory, 0.0), "la memoria se queda a cero")

	print("== Attention: contención del perímetro ==")
	attention.reset()
	var inside := Vector3(0.0, 0.0, 35.0)
	var outside_player := Vector3(0.0, 1.72, 60.0)
	step = attention.update(inside, 0.0, outside_player, 0.1)
	_check(attention.intent == "Bordea la malla", "al llegar a la malla la bordea")
	var before_risk := attention.field_memory.total_risk()
	for _step in 40:
		attention.update(inside, 0.0, outside_player, 0.2)
	_check(attention.field_memory.total_risk() > before_risk,
		"bordear deja memoria en el sector")
	var risk_sector := int(attention.field_memory.edge(inside.x, inside.z)["sector"])
	_check(attention.field_memory.sector_risk(risk_sector) > 0.0, "el sector visitado acumula riesgo")

	print("== Attention: movimientos y órdenes ==")
	attention.reset()
	var grab_step := attention.update(monster, 0.0, player, 0.1, null, false, true, false, false)
	_check(attention.intent == "Sujetando", "con agarre activo se queda sujetando")
	_check((grab_step["position"] as Vector3).distance_to(monster) < 0.001, "sujetando no se mueve")
	attention.reset()
	var recover_step := attention.update(monster, 0.0, Vector3(0.0, 1.72, 26.0), 0.5, null, true, false, false, false)
	_check(attention.intent == "Se repliega", "en recuperación se repliega")
	_check(float((recover_step["position"] as Vector3).z) < monster.z, "replegarse lo aleja del jugador")
	attention.reset()
	var bait := Vector3(0.0, 0.0, 14.0)
	var bait_step := attention.update(monster, 0.0, player, 0.5, bait)
	_check(attention.intent == "Investiga el señuelo", "el señuelo cambia el objetivo")
	_check((bait_step["target"] as Vector3).distance_to(bait) < 0.001, "el objetivo es el señuelo")
	_check(float((bait_step["position"] as Vector3).z) < monster.z, "va hacia el señuelo")
	attention.reset()
	var sprint_step := attention.update(monster, 0.0, Vector3(0.0, 1.72, 36.0), 0.1, null, false, false, false, true)
	_check(bool(sprint_step["heard"]), "corriendo lo oye a 14 m")
	attention.reset()
	var quiet_step := attention.update(monster, 0.0, Vector3(0.0, 1.72, 36.0), 0.1, null, false, false, false, false)
	_check(not bool(quiet_step["heard"]), "andando no lo oye a 14 m")

	print("== Attention: no pisa al operador ==")
	attention.reset()
	var close_monster := Vector3(0.0, 0.0, 22.0)
	var close_player := Vector3(0.0, 1.72, 24.0)
	var hold := attention.update(close_monster, 0.0, close_player, 0.5)
	_check((hold["position"] as Vector3).distance_to(close_monster) < 0.001,
		"a menos de 2,8 m no se acerca más")

	print("== Persistencia de la memoria de campo ==")
	var memory_source := FieldMemory.new()
	memory_source.remember(7, 0.4)
	memory_source.remember(8, 0.2)
	var restored := FieldMemory.new()
	_check(restored.from_dict(memory_source.to_dict()), "la memoria de campo se restaura")
	_check(_close(restored.sector_risk(7), 0.4, 0.01), "el sector 7 conserva su riesgo")
	_check(_close(restored.sector_risk(8), 0.2, 0.01), "el sector 8 conserva su riesgo")
	var attention_source := MonsterAttention.new()
	attention_source.memory = 3.1
	attention_source.last_known = Vector3(1.0, 2.0, 3.0)
	attention_source.field_memory.remember(3, 0.3)
	var attention_restored := MonsterAttention.new()
	_check(attention_restored.from_dict(attention_source.to_dict()), "la atención se serializa")
	_check(_close(attention_restored.memory, 3.1), "la memoria breve se conserva")
	_check(_close(attention_restored.field_memory.sector_risk(3), 0.3, 0.01),
		"la memoria de sectores viaja con la atención")

	print("== Actor W–01 con IA conectada ==")
	var packed := load("res://scenes/entities/w01_actor.tscn") as PackedScene
	_check(packed != null, "la escena del actor carga")
	if packed != null:
		var actor := packed.instantiate() as W01Actor
		root.add_child(actor)
		_check(actor.ai != null and actor.attention != null, "el actor trae IA y atención")
		actor.set_process(false)
		actor._process(0.2)
		_check(actor.state == actor.ai.state, "el estado del actor sigue a la IA")
		_check(actor.intent.length() > 0, "el actor publica una intención")
		actor.apply_uv()
		_check(actor.ai.state == "RECOVERY", "el pulso UV lo manda a recuperación")
		actor.apply_cryo()
		_check(actor._cold_remaining > 0.0, "el criogénico lo enfría")
		actor.investigate_lure(Vector3(4.0, 0.0, -20.0))
		_check(actor.intent.contains("señuelo"), "el señuelo se anuncia en la intención")
		actor.queue_free()

	var passed := failures.is_empty()
	print(JSON.stringify({"checks": checks, "failures": failures, "passed": passed}))
	quit(0 if passed else 1)
