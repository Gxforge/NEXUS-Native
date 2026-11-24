extends SceneTree
## Valida la bóveda V–03 frente al contrato de `src/scene/Vault.ts`.

var failures: Array[String] = []
var checks := 0
const SAVE_PATH := "user://nexus_native_vault_qa.json"

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error("QA FAIL: %s" % message)
	else:
		print("QA PASS: ", message)

func _new_vault() -> VaultModule:
	var vault := VaultModule.new()
	vault.apply_web_layout()
	root.add_child(vault)
	return vault

func _run() -> void:
	print("== Bóveda V–03: estado inicial ==")
	var vault := _new_vault()
	_check(vault.phase == "Sellada", "la bóveda arranca sellada")
	_check(vault.timer < 0.0, "sin secuencia activa al inicio")
	_check(not vault.opened_once, "abierta = false al inicio")
	_check(is_zero_approx(vault.progress()), "progreso 0 al inicio")
	_check(vault.stations.size() == 4, "cuatro estaciones de uso declaradas")
	_check(vault.drawers.size() == 5, "cinco cajones declarados")
	_check(vault.items.has(&"card"), "la tarjeta V–03 vive en los cajones")
	_check(vault.station_near(Vector3(24.5, 1.6, -37.0)) == &"rearm",
		"el rearme se detecta a menos de 4 m")
	_check(vault.station_near(Vector3(40.0, 1.6, -37.0)) == &"", "fuera de 4 m no hay estación")

	print("== Bóveda V–03: secuencia de apertura ==")
	_check(vault.begin_opening(), "la apertura arranca")
	_check(not vault.begin_opening(), "no se puede reiniciar una apertura en curso")
	vault.update(0.5, Vector3.INF)
	_check(vault.phase == "Validando", "0,5 s · Validando")
	vault.update(3.0, Vector3.INF)
	_check(vault.phase == "Retirando cerrojos", "3,5 s · Retirando cerrojos")
	vault.update(3.0, Vector3.INF)
	_check(vault.phase == "Liberando pestillos", "6,5 s · Liberando pestillos")
	vault.update(4.0, Vector3.INF)
	_check(vault.phase == "Girando corona", "10,5 s · Girando corona")
	vault.update(4.0, Vector3.INF)
	_check(vault.phase == "Despresurizando", "14,5 s · Despresurizando")
	vault.update(2.5, Vector3.INF)
	_check(vault.phase == "Traslado hidráulico", "17 s · Traslado hidráulico")
	_check(not vault.opened_once, "todavía no está abierta a los 17 s")
	vault.update(6.0, Vector3.INF)
	_check(vault.opened_once, "a los 22 s la bóveda queda abierta")
	_check(vault.phase == "Abierta", "la fase final es Abierta")
	_check(is_equal_approx(vault.timer, 22.0), "el reloj no pasa de 22 s")
	_check(is_equal_approx(vault.progress(), 1.0), "el progreso llega a 1")
	_check(not vault.is_opening(), "terminada la secuencia ya no está en curso")

	print("== Bóveda V–03: cajones por proximidad ==")
	var fresh := _new_vault()
	_check(not fresh.open_drawer(0, true), "sin abrir la bóveda no se abren cajones")
	fresh.begin_opening()
	fresh.update(30.0, Vector3.INF)
	_check(fresh.opened_once, "la bóveda se abre para probar los cajones")
	_check(fresh.open_drawer(0, true), "con la bóveda abierta el cajón acepta apertura")
	var drawer_bx := float(fresh.drawers[0]["bx"])
	var drawer_bz := float(fresh.drawers[0]["bz"])
	# Jugador justo al lado del cajón: apertura máxima.
	# Lejos del cajón: la bandeja sale del todo.
	for _step in 60:
		fresh.update(1.0 / 30.0, Vector3(drawer_bx + 6.0, 1.0, drawer_bz))
	_check(fresh.drawer_factor(0) > 0.95, "abierto y sin nadie delante la bandeja sale del todo")
	_check(fresh.drawer_visible_item(0), "el objeto del cajón se hace visible")
	_check(fresh.drawer_solid(drawer_bx, drawer_bz + 0.5), "el cajón abierto bloquea el paso")
	# De pie justo delante: la bandeja se detiene antes de tocar al jugador.
	for _step in 90:
		fresh.update(1.0 / 30.0, Vector3(drawer_bx, 1.0, drawer_bz + 1.0))
	_check(fresh.drawer_factor(0) < 0.1, "de pie delante la bandeja se detiene sin empujar")
	# Cerrado: vuelve a su sitio y deja de bloquear.
	fresh.open_drawer(0, false)
	for _step in 90:
		fresh.update(1.0 / 30.0, Vector3(drawer_bx, 1.0, drawer_bz + 1.0))
	_check(fresh.drawer_factor(0) < 0.05, "cerrado, la bandeja vuelve a su sitio")
	_check(not fresh.drawer_visible_item(0), "el objeto deja de verse con el cajón cerrado")
	_check(not fresh.drawer_solid(drawer_bx, drawer_bz + 0.5), "el cajón cerrado no bloquea")

	print("== Bóveda V–03: objetos e inventario ==")
	var state: GameState = GameState.new()
	state.add_to_group(&"game_state")
	root.add_child(state)
	state.power_simulation = false
	state.register_vault(fresh)
	var player: NexusPlayer = null
	var closed_pickup := fresh.collect(&"card", player)
	_check(closed_pickup.contains("cerrado"), "no se recoge nada con el cajón cerrado")
	fresh.open_drawer(3, true)
	for _step in 60:
		fresh.update(1.0 / 30.0, Vector3(float(fresh.drawers[3]["bx"]) + 6.0, 1.0, float(fresh.drawers[3]["bz"])))
	var picked := fresh.collect(&"card", player)
	_check(picked.contains("inventario"), "la tarjeta se guarda en el inventario")
	_check(state.has_item(&"card"), "el inventario contiene la tarjeta")
	_check(fresh.collect(&"card", player).contains("ya recogido"), "recoger dos veces no duplica")
	_check(bool(fresh.item_state(&"card").get("collected", false)), "el ítem queda recolectado")
	_check(fresh.use_station(&"rearm", player).length() > 0, "el rearme responde desde la estación")
	_check(fresh.use_station(&"vault", player).contains("ya está abierta"),
		"la consola informa de que ya está abierta")

	print("== Bóveda V–03: persistencia ==")
	var saved: bool = state.save_game(SAVE_PATH)
	_check(saved, "GameState guarda el estado de la bóveda")
	var reloaded: GameState = GameState.new()
	reloaded.add_to_group(&"game_state")
	root.add_child(reloaded)
	reloaded.power_simulation = false
	_check(reloaded.load_game(SAVE_PATH), "GameState relee la partida")
	var restored: VaultModule = _new_vault()
	reloaded.register_vault(restored)
	_check(restored.opened_once, "la bóveda sigue abierta tras cargar")
	_check(bool(restored.item_state(&"card").get("collected", false)),
		"la tarjeta recogida no reaparece tras cargar")
	var restored_phase := restored.phase
	_check(restored_phase == "Abierta", "la fase restaurada es Abierta")
	restored.reset()
	_check(restored.phase == "Sellada" and not restored.opened_once, "reset devuelve la bóveda a sellada")
	_check(not bool(restored.item_state(&"card").get("collected", false)), "reset devuelve los ítems")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))

	print("== Bóveda V–03: zona real ==")
	var packed := load("res://zones/zone_v03_gallery.tscn") as PackedScene
	_check(packed != null, "la zona V–03 carga con la bóveda")
	if packed != null:
		var zone := packed.instantiate()
		root.add_child(zone)
		var module := zone.get_node_or_null("VaultModule") as VaultModule
		_check(module != null, "la zona instancia el módulo de bóveda")
		if module != null:
			var console := module.get_node_or_null("VaultConsole") as VaultStation
			_check(console != null, "la consola de la bóveda existe en la zona")
			if console != null:
				console._vault = module
				_check(console.get_interaction_prompt().contains("Abrir"),
					"la consola ofrece abrir la bóveda")
			var rearm := module.get_node_or_null("RearmConsole") as VaultStation
			_check(rearm != null, "el puesto de rearme existe en la zona")
			_check(module.stations.size() == 4, "el módulo despliega las estaciones de la web")
		zone.queue_free()

	for node in [vault, fresh, restored, state, reloaded]:
		if is_instance_valid(node):
			node.queue_free()

	var passed := failures.is_empty()
	print(JSON.stringify({"checks": checks, "failures": failures, "passed": passed}))
	quit(0 if passed else 1)
