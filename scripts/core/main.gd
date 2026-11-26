extends Node

@onready var catalog: ZoneCatalog = $ZoneCatalog
@onready var game_state: GameState = $GameState
@onready var zone_manager: ZoneManager = $ZoneManager
@onready var player: NexusPlayer = $PersistentWorld/Player
@onready var experience: SceneExperienceController = $PersistentWorld/SceneExperience
@onready var main_menu: Control = $UI/MainMenu
@onready var loading_screen: Control = $UI/LoadingScreen
@onready var hud: NexusHUD = $UI/HUD
@onready var loading_progress: ProgressBar = $UI/LoadingScreen/Panel/Content/Progress
@onready var loading_status: Label = $UI/LoadingScreen/Panel/Content/Status
@onready var loading_details: Label = $UI/LoadingScreen/Panel/Content/Details
@onready var loading_title: Label = $UI/LoadingScreen/Panel/Content/Title
@onready var loading_hint: Label = $UI/LoadingScreen/Panel/Content/Hint
@onready var loading_cancel: Button = $UI/LoadingScreen/Panel/Content/Cancel

var _startup_requested: bool = false
var _transition_requested: bool = false
var _game_started: bool = false
const ZONE_GRAPH_PATH := "res://data/zone_graph.json"
## Zone scenes are authored in the runtime frame `world + (9, 0, 14)`; the graph
## stores Environment.ts world coordinates, so registered footprints are shifted.
const SCENE_OFFSET_2D := Vector2(9.0, 14.0)
var _startup_zone: StringName = &"c04"
var _autosave_timer: float = 10.0
## Estado real de la pantalla de carga: plan de recursos, cuántos van y cuánto
## lleva el actual sin terminar.
var _load_elapsed: float = 0.0
var _load_plan: PackedStringArray = PackedStringArray()
var _load_total: int = 0
var _load_done: int = 0
var _load_index: int = 0
var _load_requested: String = ""
var _load_megabytes: float = 0.0
var _load_slot_elapsed: float = 0.0
var _load_started_ms: int = 0
var _load_slot_started_ms: int = 0
var _load_stalled: float = 0.0
var _load_last_progress_ms: int = 0
var _load_mounted: bool = false
var _load_preloaded: bool = false
var _load_hold_frames: int = 0

func _ready() -> void:
	_register_zones()
	game_state.add_to_group(&"game_state")
	add_to_group(&"zone_catalog")
	zone_manager.configure(catalog, game_state)
	game_state.load_game()
	experience.survey.restore(game_state.survey_records)
	player.configure(game_state, experience)
	hud.bind_player(player, game_state)
	hud.bind_zones(catalog)
	hud.panel_visibility_changed.connect(_on_panel_visibility_changed)
	hud.quality_changed.connect(_on_quality_changed)
	hud.sensitivity_changed.connect(_on_sensitivity_changed)
	hud.guides_changed.connect(_on_guides_changed)
	hud.reset_requested.connect(restart_encounter)
	zone_manager.transition_finished.connect(_on_zone_transition_finished)
	zone_manager.transition_failed.connect(_on_zone_transition_failed)
	if hud != null:
		hud.update_quality_label(game_state.quality())
	var start_button := $UI/MainMenu/Panel/Content/Start as Button
	start_button.text = "CONTINUAR EN " + _zone_label(game_state.current_zone).to_upper() \
		if catalog.has_zone(game_state.current_zone) else "ENTRAR EN C–04 · CONTENCIÓN"
	start_button.pressed.connect(start_game)
	$UI/MainMenu/Panel/Content/Quit.pressed.connect(_quit_game)
	apply_quality_category()
	player.set_controls_enabled(false)
	main_menu.show()
	loading_screen.hide()
	hud.hide()
	set_process(false)

func start_game() -> bool:
	if _startup_requested:
		return false
	_startup_zone = game_state.current_zone if catalog.has_zone(game_state.current_zone) else &"c04"
	_startup_requested = true
	_transition_requested = false
	main_menu.hide()
	loading_screen.show()
	loading_progress.value = 0.0
	if loading_title != null:
		loading_title.text = _zone_label(_startup_zone).to_upper()
	if loading_hint != null:
		loading_hint.text = ""
	if loading_cancel != null:
		loading_cancel.hide()
	_begin_load_plan(_startup_zone)
	set_process(true)
	return true


## Prepara el plan de recursos de la zona y pide el primero. Cada dependencia
## se pide de una en una: así la barra avanza con hechos y la memoria no se
## dispara en el móvil.
func _begin_load_plan(zone_id: StringName) -> void:
	var definition := catalog.zone(zone_id)
	_load_plan = LoadingProgress.plan(definition.scene_path)
	_load_total = _load_plan.size()
	_load_done = 0
	_load_index = 0
	_load_requested = ""
	_load_megabytes = LoadingProgress.plan_megabytes(_load_plan)
	_load_elapsed = 0.0
	_load_slot_elapsed = 0.0
	_load_stalled = 0.0
	_load_started_ms = Time.get_ticks_msec()
	_load_slot_started_ms = _load_started_ms
	_load_mounted = false
	_load_preloaded = false
	_load_hold_frames = 0
	_load_last_progress_ms = Time.get_ticks_msec()
	loading_progress.value = 0.0
	loading_status.text = LoadingProgress.step_name(zone_manager.state, 0, _load_total, false)
	if loading_details != null:
		loading_details.text = LoadingProgress.details(zone_id, definition.scene_path, 0, _load_total,
			_load_megabytes, 0.0, 0.0)


## Pide el recurso en curso, si no hay ninguno pedido todavía.
func _request_next_resource() -> void:
	while _load_index < _load_total:
		var path := _load_plan[_load_index]
		if not LoadingProgress.has_resource(path):
			_load_index += 1
			_load_done = _load_index
			continue
		if ResourceLoader.load_threaded_request(path, "", true) != OK:
			push_warning("No se pudo pedir %s; se sigue sin él" % path)
			_load_index += 1
			_load_done = _load_index
			continue
		_load_requested = path
		_load_slot_started_ms = Time.get_ticks_msec()
		_load_slot_elapsed = 0.0
		return
	_load_requested = ""


## Un paso de la precarga: estado del recurso en curso y, al terminar todos, el
## tránsito real a la zona.
func _tick_loading(_delta: float) -> void:
	## Reloj de pared, no suma de deltas: un fotograma bloqueado por el montaje
	## no debe hacer que el cronometro de la pantalla se quede parado.
	_load_elapsed = (Time.get_ticks_msec() - _load_started_ms) / 1000.0
	_load_slot_elapsed = (Time.get_ticks_msec() - _load_slot_started_ms) / 1000.0
	if _load_requested.is_empty() and _load_index < _load_total:
		_request_next_resource()
	if not _load_requested.is_empty():
		var status := ResourceLoader.load_threaded_get_status(_load_requested)
		match status:
			ResourceLoader.THREAD_LOAD_LOADED:
				_load_requested = ""
				_load_index += 1
				_load_done = _load_index
				_load_slot_elapsed = 0.0
				_load_slot_started_ms = Time.get_ticks_msec()
				_load_last_progress_ms = Time.get_ticks_msec()
				_load_stalled = 0.0
			ResourceLoader.THREAD_LOAD_FAILED, ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
				push_warning("Recurso no cargado en el plan: %s" % _load_requested)
				_load_requested = ""
				_load_index += 1
				_load_done = _load_index
				_load_last_progress_ms = Time.get_ticks_msec()
				_load_stalled = 0.0
			_:
				_load_stalled = (Time.get_ticks_msec() - _load_last_progress_ms) / 1000.0
	elif _load_index >= _load_total:
		_load_stalled = 0.0
		if not _load_preloaded:
			# Un par de fotogramas con el 92 % ya pintado: el montaje de la zona
			# ocupa un fotograma entero y, sin esto, la pantalla se quedaria
			# diciendo "14 de 14" mientras el motor esta ocupado.
			_load_preloaded = true
			_load_hold_frames = 2
		elif _load_hold_frames > 0:
			_load_hold_frames -= 1
		elif zone_manager.state == ZoneManager.State.IDLE and not _transition_requested:
			_load_mounted = true
			_transition_requested = zone_manager.transition_to(_startup_zone, &"entry")
			if not _transition_requested:
				_on_zone_transition_failed(_startup_zone, "No se pudo iniciar el tránsito")
				return
	var state := zone_manager.state
	loading_progress.value = LoadingProgress.value(_load_done, _load_total, _load_slot_elapsed,
		state, _load_mounted)
	if _load_preloaded and not _load_mounted:
		loading_status.text = "Montando la zona"
	else:
		loading_status.text = LoadingProgress.step_name(state, _load_done, _load_total, _load_mounted)
	if loading_details != null:
		var module_path := catalog.zone(_startup_zone).scene_path
		if _load_total > 0:
			module_path = _load_plan[_load_total - 1]
		loading_details.text = LoadingProgress.details(_startup_zone, module_path, _load_done, _load_total,
			_load_megabytes, _load_elapsed, _load_stalled)
	if loading_hint != null:
		if _load_preloaded and not _load_mounted:
			loading_hint.text = "Un momento · montando la geometría de la zona"
		else:
			loading_hint.text = LoadingProgress.stall_hint(_load_stalled) if not _load_mounted else ""
	if loading_cancel != null:
		loading_cancel.visible = _load_stalled >= LoadingProgress.STALL_ABORT
		if loading_cancel.visible and loading_cancel.pressed.get_connections().is_empty():
			loading_cancel.pressed.connect(cancel_loading)

## Vuelve al menú si la precarga no avanza y el operador decide salir.
func cancel_loading() -> void:
	if not _startup_requested:
		return
	print("NEXUS carga cancelada tras %.1f s sin avance" % _load_stalled)
	_startup_requested = false
	_transition_requested = false
	_load_requested = ""
	_load_mounted = false
	_load_preloaded = false
	loading_screen.hide()
	main_menu.show()
	loading_progress.value = 0.0
	if loading_hint != null:
		loading_hint.text = ""
	if loading_cancel != null:
		loading_cancel.hide()
	set_process(false)

## Nombre legible de una zona, del catálogo (`C-04 · Contención`).
func _zone_label(zone_id: StringName) -> String:
	var definition := catalog.zone(zone_id) if catalog != null else null
	if definition != null:
		return str(definition.display_name)
	return str(zone_id).to_upper().replace("_", " ")


func _process(delta: float) -> void:
	if _game_started:
		_tick_session_tips(delta)
	if _startup_requested and not _game_started:
		_tick_loading(delta)
	if _game_started:
		_autosave_timer -= delta
		if _autosave_timer <= 0.0:
			_autosave_timer = 10.0
		_save_checkpoint()

func _on_zone_transition_failed(zone_id: StringName, reason: String) -> void:
	if not _game_started:
		_startup_requested = false
		_transition_requested = false
		loading_status.text = "No se pudo iniciar %s: %s" % [str(zone_id).to_upper(), reason]
		loading_screen.hide()
		main_menu.show()
		set_process(false)
	else:
		player.show_message("Tránsito bloqueado · " + reason)

func _on_panel_visibility_changed(open: bool) -> void:
	if not _game_started:
		return
	player.set_controls_enabled(not open)
	if not open:
		_save_checkpoint()

func _on_zone_transition_finished(zone_id: StringName) -> void:
	_transition_requested = false
	if not _game_started:
		_game_started = true
		set_process(true)
		loading_screen.hide()
		main_menu.hide()
		_apply_saved_player_state(zone_id)
		player.set_controls_enabled(true)
		hud.show()
	hud.on_zone_changed(zone_id)
	_save_checkpoint()

func _apply_saved_player_state(zone_id: StringName) -> void:
	var saved: Dictionary = game_state.player_state
	if str(saved.get("zone", "")) != str(zone_id):
		return
	var position_value: Variant = saved.get("position", [])
	if position_value is Array and position_value.size() >= 3:
		var saved_position := Vector3(float(position_value[0]), float(position_value[1]), float(position_value[2]))
		if saved_position.is_finite():
			player.global_position = saved_position
	player.rotation.y = float(saved.get("yaw", player.rotation.y))
	player.camera.rotation.x = clampf(float(saved.get("pitch", player.camera.rotation.x)), -1.42, 1.42)
	player.restore_runtime_state(saved)

func _save_checkpoint() -> void:
	if not _game_started:
		return
	var saved := player.checkpoint_state()
	saved["zone"] = str(game_state.current_zone)
	saved["position"] = [player.global_position.x, player.global_position.y, player.global_position.z]
	saved["yaw"] = player.rotation.y
	saved["pitch"] = player.camera.rotation.x
	game_state.player_state = saved
	game_state.save_game()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and _game_started:
		_save_checkpoint()

func _quit_game() -> void:
	_save_checkpoint()
	get_tree().quit()

func _register_zones() -> void:
	var file := FileAccess.open(ZONE_GRAPH_PATH, FileAccess.READ)
	if file == null:
		push_error("Zone graph not readable: %s" % ZONE_GRAPH_PATH)
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not parsed is Dictionary:
		push_error("Zone graph is not a JSON object")
		return
	var graph := parsed as Dictionary
	var neighbor_sets: Dictionary = {}
	for entry: Dictionary in graph.get("zones", []):
		var definition := ZoneDefinition.new()
		definition.id = StringName(str(entry.get("id", "")))
		definition.scene_path = str(entry.get("scene", ""))
		definition.display_name = str(entry.get("display_name", ""))
		definition.spawn_socket = StringName(str(entry.get("entry_socket", "entry")))
		var bounds: Dictionary = entry.get("bounds", {})
		var low: Array = bounds.get("min", [0.0, 0.0])
		var high: Array = bounds.get("max", [0.0, 0.0])
		if low.size() >= 2 and high.size() >= 2:
			definition.bounds_min = Vector2(float(low[0]), float(low[1])) + SCENE_OFFSET_2D
			definition.bounds_max = Vector2(float(high[0]), float(high[1])) + SCENE_OFFSET_2D
		definition.height = float(entry.get("height", 9.2))
		catalog.register_zone(definition)
		neighbor_sets[definition.id] = []
	for entry: Dictionary in graph.get("connections", []):
		var connection := DoorConnection.new()
		connection.id = StringName(str(entry.get("id", "")))
		connection.from_zone = StringName(str(entry.get("from_zone", "")))
		connection.from_socket = StringName(str(entry.get("from_socket", "")))
		connection.to_zone = StringName(str(entry.get("to_zone", "")))
		connection.to_socket = StringName(str(entry.get("to_socket", "")))
		connection.bidirectional = bool(entry.get("bidirectional", true))
		catalog.register_connection(connection)
		if not neighbor_sets.has(connection.from_zone) or not neighbor_sets.has(connection.to_zone):
			push_warning("Connection %s references an unregistered zone" % connection.id)
			continue
		var from_neighbors: Array = neighbor_sets[connection.from_zone]
		if not from_neighbors.has(connection.to_zone):
			from_neighbors.append(connection.to_zone)
		var to_neighbors: Array = neighbor_sets[connection.to_zone]
		if not to_neighbors.has(connection.from_zone):
			to_neighbors.append(connection.from_zone)
	for zone_id: StringName in neighbor_sets:
		var definition := catalog.zone(zone_id)
		if definition == null:
			continue
		definition.neighbors.clear()
		for neighbor: StringName in neighbor_sets[zone_id]:
			definition.neighbors.append(neighbor)
	print("NEXUS zone graph: %d zones, %d connections" % [neighbor_sets.size(), graph.get("connections", []).size()])

## Aplica el perfil gráfico de `DisplayQuality.ts` al motor.
## Densidad de render en el escalado 3D, sombras sólo en `high` y brillo
## (glow) desactivado en `low` con 0,13 / 0,19 de intensidad.
func apply_quality_category(preset := "") -> String:
	var active := game_state.set_quality(preset) if not preset.is_empty() else game_state.quality()
	var size := Vector2(get_viewport().get_visible_rect().size)
	var density := ExperienceState.render_density(active, size.x, size.y,
		DisplayServer.is_touchscreen_available())
	var viewport := get_viewport()
	if viewport != null:
		# Por debajo de 1 se reduce la resolución interna (perfil low). Los topes
		# superiores a 1 de la web se quedan en resolución nativa: el objetivo del
		# proyecto es móvil y el sobremuestreo no compensa el coste.
		viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
		viewport.scaling_3d_scale = minf(density, 1.0)
	var shadows := ExperienceState.shadows_enabled(active)
	_apply_shadows(self, shadows)
	_apply_glow(ExperienceState.bloom_enabled(active), ExperienceState.bloom_strength(active))
	player.apply_view_fov()
	return active

func _apply_shadows(node: Node, enabled: bool) -> void:
	if node is DirectionalLight3D or node is SpotLight3D:
		(node as Light3D).shadow_enabled = enabled
	for child in node.get_children():
		_apply_shadows(child, enabled)

func _apply_glow(enabled: bool, strength: float) -> void:
	var world := get_node_or_null("PersistentWorld/WorldEnvironment") as WorldEnvironment
	if world == null or world.environment == null:
		return
	world.environment.glow_enabled = enabled
	world.environment.glow_intensity = strength

func _on_quality_changed(preset: String) -> void:
	var applied := apply_quality_category(preset)
	game_state.log_event("Perfil gráfico · " + applied.to_upper())
	player.show_message("Perfil gráfico · " + applied.to_upper())
	hud.update_quality_label(applied)

func _on_sensitivity_changed(value: float) -> void:
	game_state.log_event("Sensibilidad de cámara · %.2f×" % value)
	hud.update_sensitivity_label(value)

func _on_guides_changed(enabled: bool) -> void:
	game_state.log_event("Consejos " + ("activados" if enabled else ("mostrados" if enabled else "desactivados")))
	if not enabled and game_state.session != null:
		game_state.session.dismiss_tip()

## Reinicia el encuentro como el botón de la web: estado fresco y módulo inicial.
func restart_encounter() -> bool:
	if game_state.session != null:
		game_state.session.reset_session()
	if game_state.experience != null:
		game_state.experience.reset(game_state.inventory)
	if game_state.watcher_state is Dictionary:
		game_state.watcher_state["state"] = "WATCHING"
		game_state.watcher_state["aggression"] = 0.2
		game_state.watcher_state["memory"] = 0.0
	player.restore_runtime_state({})
	game_state.save_game()
	var zone: StringName = game_state.current_zone if catalog.has_zone(game_state.current_zone) else &"c04"
	player.show_message("Sesión de contención reiniciada")
	hud.update_quality_label(game_state.quality())
	return zone_manager.transition_to(zone, &"entry")

## Consejos de una sola vez (al entrar en primera persona, como en la web).
## Consejos de una sola vez (se llama desde `_process`).
func _tick_session_tips(delta: float) -> void:
	if game_state.session == null:
		return
	var previous := game_state.session.tip
	var next := game_state.session.update(delta, game_state.experience)
	if next != previous and not next.is_empty():
		player.show_message(next)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"cycle_quality"):
		var next := apply_quality_category(ExperienceState.QUALITIES[
			(ExperienceState.QUALITIES.find(game_state.quality()) + 1) % ExperienceState.QUALITIES.size()])
		player.show_message("Perfil gráfico · " + next.to_upper())
		if hud != null:
			hud.update_quality_label(next)
		get_viewport().set_input_as_handled()
