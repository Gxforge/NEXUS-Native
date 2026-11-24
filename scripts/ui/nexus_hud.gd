class_name NexusHUD
extends Control

signal panel_visibility_changed(open: bool)

var _player: NexusPlayer
var _game_state: GameState
var _zone_catalog: ZoneCatalog
var _title_label: Label
var _prompt_label: Label
var _message_label: Label
var _inventory_label: Label
var _status_label: Label
var _resource_label: Label
var _stamina_bar: ProgressBar
var _hint_label: Label
var _quick_slot_buttons: Array[Button] = []
var _message_timer: Timer
var _panel_root: PanelContainer
var _panel_content: VBoxContainer
var _active_panel: StringName = &""
var _touch_start_position: Vector2 = Vector2.ZERO
var _touch_start_time: int = 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_message_timer = Timer.new()
	_message_timer.one_shot = true
	_message_timer.wait_time = 3.6
	_message_timer.timeout.connect(_clear_message)
	add_child(_message_timer)
	_build_interface()

func bind_player(player: NexusPlayer, state: GameState) -> void:
	_player = player
	_game_state = state
	if player != null:
		if not player.prompt_changed.is_connected(_on_prompt_changed):
			player.prompt_changed.connect(_on_prompt_changed)
		if not player.message_changed.is_connected(_on_message_changed):
			player.message_changed.connect(_on_message_changed)
		if not player.flashlight_changed.is_connected(_on_flashlight_changed):
			player.flashlight_changed.connect(_on_flashlight_changed)
		if not player.stamina_changed.is_connected(_on_stamina_changed):
			player.stamina_changed.connect(_on_stamina_changed)
		if not player.quick_slot_changed.is_connected(_on_quick_slot_changed):
			player.quick_slot_changed.connect(_on_quick_slot_changed)
		if not player.tool_state_changed.is_connected(_on_tool_state_changed):
			player.tool_state_changed.connect(_on_tool_state_changed)
		if not player.panel_requested.is_connected(_on_panel_requested):
			player.panel_requested.connect(_on_panel_requested)
		player.tool_state_changed.emit(player.energy, player.flashlight_battery, player.active_weapon)
		player.stamina_changed.emit(player.stamina)
		player.quick_slot_changed.emit(player.selected_quick_slot, player.game_state.quick_slots[player.selected_quick_slot] if player.game_state != null else &"")
	if state != null:
		if not state.inventory_changed.is_connected(_on_inventory_changed):
			state.inventory_changed.connect(_on_inventory_changed)
		_on_inventory_changed(state.inventory)

func bind_zones(catalog: ZoneCatalog) -> void:
	_zone_catalog = catalog
	on_zone_changed(_game_state.current_zone if _game_state != null else &"")

func on_zone_changed(zone_id: StringName) -> void:
	if _title_label == null:
		return
	var label := "NEXUS  /  MOD–00"
	if _zone_catalog != null and _zone_catalog.has_zone(zone_id):
		label = "NEXUS  /  " + str(_zone_catalog.zone(zone_id).display_name)
	_title_label.text = label
	if _active_panel == &"map" and _panel_root != null and _panel_root.visible:
		_open_panel(&"map")

func _input(event: InputEvent) -> void:
	if _panel_root != null and _panel_root.visible and event.is_action_pressed(&"ui_cancel"):
		_close_panel()
		get_viewport().set_input_as_handled()

func _build_interface() -> void:
	var title := _make_label("Title", "NEXUS  /  CAM–04", 20, Color(0.65, 0.91, 0.91))
	title.position = Vector2(24, 20)
	title.size = Vector2(420, 34)
	_title_label = title

	var crosshair := _make_label("Crosshair", "·", 30, Color(0.7, 0.95, 0.95, 0.9))
	crosshair.anchor_left = 0.5
	crosshair.anchor_right = 0.5
	crosshair.anchor_top = 0.5
	crosshair.anchor_bottom = 0.5
	crosshair.offset_left = -8
	crosshair.offset_right = 8
	crosshair.offset_top = -18
	crosshair.offset_bottom = 18
	crosshair.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	crosshair.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	_prompt_label = _make_label("Prompt", "", 18, Color(0.78, 0.95, 0.91))
	_prompt_label.anchor_left = 0.5
	_prompt_label.anchor_right = 0.5
	_prompt_label.anchor_top = 1.0
	_prompt_label.anchor_bottom = 1.0
	_prompt_label.offset_left = -280
	_prompt_label.offset_right = 280
	_prompt_label.offset_top = -126
	_prompt_label.offset_bottom = -92
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	_message_label = _make_label("Message", "", 16, Color(0.96, 0.78, 0.54))
	_message_label.anchor_left = 0.5
	_message_label.anchor_right = 0.5
	_message_label.anchor_top = 1.0
	_message_label.anchor_bottom = 1.0
	_message_label.offset_left = -320
	_message_label.offset_right = 320
	_message_label.offset_top = -164
	_message_label.offset_bottom = -130
	_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	_inventory_label = _make_label("Inventory", "EQUIPO  ·  UV / CRIO", 14, Color(0.61, 0.76, 0.8))
	_inventory_label.position = Vector2(24, 62)
	_inventory_label.size = Vector2(390, 28)

	_status_label = _make_label("Status", "LINTERNA  APAGADA · 100%", 14, Color(0.61, 0.76, 0.8))
	_status_label.anchor_left = 1.0
	_status_label.anchor_right = 1.0
	_status_label.offset_left = -300
	_status_label.offset_right = -24
	_status_label.offset_top = 22
	_status_label.offset_bottom = 50
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	_resource_label = _make_label("Resources", "ENERGÍA  100%  ·  MANO LIBRE", 14, Color(0.61, 0.76, 0.8))
	_resource_label.anchor_left = 1.0
	_resource_label.anchor_right = 1.0
	_resource_label.offset_left = -380
	_resource_label.offset_right = -24
	_resource_label.offset_top = 48
	_resource_label.offset_bottom = 76
	_resource_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	var stamina_title := _make_label("StaminaTitle", "O₂ / RESISTENCIA", 12, Color(0.45, 0.61, 0.65))
	stamina_title.position = Vector2(24, 98)
	stamina_title.size = Vector2(180, 22)
	_stamina_bar = ProgressBar.new()
	_stamina_bar.name = "Stamina"
	_stamina_bar.position = Vector2(24, 122)
	_stamina_bar.size = Vector2(220, 12)
	_stamina_bar.min_value = 0
	_stamina_bar.max_value = 100
	_stamina_bar.value = 100
	_stamina_bar.show_percentage = false
	_stamina_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_stamina_bar)

	var quickbar := HBoxContainer.new()
	quickbar.name = "QuickBar"
	quickbar.anchor_left = 0.5
	quickbar.anchor_right = 0.5
	quickbar.anchor_top = 1.0
	quickbar.anchor_bottom = 1.0
	quickbar.offset_left = -260
	quickbar.offset_right = 260
	quickbar.offset_top = -60
	quickbar.offset_bottom = -14
	quickbar.add_theme_constant_override("separation", 8)
	quickbar.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(quickbar)
	for index in 5:
		var button := Button.new()
		button.name = "Slot%d" % (index + 1)
		button.custom_minimum_size = Vector2(96, 44)
		button.focus_mode = Control.FOCUS_NONE
		button.mouse_filter = Control.MOUSE_FILTER_STOP
		button.add_theme_font_size_override("font_size", 14)
		button.add_theme_color_override("font_color", Color(0.61, 0.76, 0.8))
		button.pressed.connect(_on_quick_slot_pressed.bind(index))
		quickbar.add_child(button)
		_quick_slot_buttons.append(button)

	_hint_label = _make_label("Hints", "WASD mover · Ratón mirar\nE interactuar · Q escanear · F linterna\n1–5 equipo · R usar · Z cambiar emisor\nEspacio UV · G crio · L señuelo · Mayús correr\nI inventario · B datos · M mapa · P pausa", 12, Color(0.45, 0.61, 0.65))
	_hint_label.anchor_left = 1.0
	_hint_label.anchor_right = 1.0
	_hint_label.anchor_top = 1.0
	_hint_label.anchor_bottom = 1.0
	_hint_label.offset_left = -410
	_hint_label.offset_right = -24
	_hint_label.offset_top = -204
	_hint_label.offset_bottom = -82
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	var navigation := HBoxContainer.new()
	navigation.name = "NavigationButtons"
	navigation.anchor_left = 1.0
	navigation.anchor_right = 1.0
	navigation.offset_left = -250
	navigation.offset_right = -24
	navigation.offset_top = 84
	navigation.offset_bottom = 124
	navigation.add_theme_constant_override("separation", 6)
	add_child(navigation)
	for entry in [["I", &"inventory"], ["B", &"database"], ["M", &"map"], ["Ⅱ", &"pause"]]:
		var nav_button := _make_panel_button(str(entry[0]))
		nav_button.custom_minimum_size = Vector2(48, 36)
		nav_button.tooltip_text = str(entry[1]).capitalize()
		nav_button.pressed.connect(_on_panel_requested.bind(entry[1]))
		navigation.add_child(nav_button)

	_build_touch_controls()

	_panel_root = PanelContainer.new()
	_panel_root.name = "FieldPanel"
	_panel_root.anchor_left = 0.5
	_panel_root.anchor_right = 0.5
	_panel_root.anchor_top = 0.5
	_panel_root.anchor_bottom = 0.5
	_panel_root.offset_left = -320
	_panel_root.offset_right = 320
	_panel_root.offset_top = -240
	_panel_root.offset_bottom = 240
	_panel_root.visible = false
	_panel_root.mouse_filter = Control.MOUSE_FILTER_STOP
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.015, 0.035, 0.043, 0.97)
	panel_style.border_color = Color(0.22, 0.61, 0.59, 0.9)
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(8)
	panel_style.set_content_margin_all(18)
	_panel_root.add_theme_stylebox_override("panel", panel_style)
	add_child(_panel_root)
	_panel_content = VBoxContainer.new()
	_panel_content.add_theme_constant_override("separation", 12)
	_panel_root.add_child(_panel_content)

func _build_touch_controls() -> void:
	var touch_enabled := DisplayServer.is_touchscreen_available()
	var look_area := Control.new()
	look_area.name = "TouchLookArea"
	look_area.anchor_left = 0.51
	look_area.anchor_right = 1.0
	look_area.anchor_top = 0.0
	look_area.anchor_bottom = 1.0
	look_area.offset_top = 128
	look_area.offset_bottom = -238
	look_area.mouse_filter = Control.MOUSE_FILTER_STOP
	look_area.visible = touch_enabled
	look_area.gui_input.connect(_on_touch_look_input)
	add_child(look_area)

	var dpad := GridContainer.new()
	dpad.name = "TouchDPad"
	dpad.columns = 3
	dpad.anchor_top = 1.0
	dpad.anchor_bottom = 1.0
	dpad.offset_left = 24
	dpad.offset_right = 204
	dpad.offset_top = -190
	dpad.offset_bottom = -58
	dpad.add_theme_constant_override("h_separation", 4)
	dpad.add_theme_constant_override("v_separation", 4)
	dpad.visible = touch_enabled
	add_child(dpad)
	var directions: Array = [
		["", ""], ["▲", "move_forward"], ["", ""],
		["◀", "move_left"], ["▼", "move_back"], ["▶", "move_right"],
	]
	for entry in directions:
		if str(entry[1]).is_empty():
			var blank := Control.new()
			blank.custom_minimum_size = Vector2(56, 40)
			dpad.add_child(blank)
		else:
			var direction_button := _make_touch_button(str(entry[0]))
			direction_button.button_down.connect(_touch_action_down.bind(StringName(entry[1])))
			direction_button.button_up.connect(_touch_action_up.bind(StringName(entry[1])))
			dpad.add_child(direction_button)
	var sprint_button := _make_touch_button("CORRER")
	sprint_button.custom_minimum_size = Vector2(176, 38)
	sprint_button.anchor_top = 1.0
	sprint_button.anchor_bottom = 1.0
	sprint_button.offset_left = 24
	sprint_button.offset_right = 204
	sprint_button.offset_top = -52
	sprint_button.offset_bottom = -12
	sprint_button.visible = touch_enabled
	sprint_button.button_down.connect(_touch_action_down.bind(&"sprint"))
	sprint_button.button_up.connect(_touch_action_up.bind(&"sprint"))
	add_child(sprint_button)

	var tools := GridContainer.new()
	tools.name = "TouchTools"
	tools.columns = 3
	tools.anchor_left = 1.0
	tools.anchor_right = 1.0
	tools.anchor_top = 1.0
	tools.anchor_bottom = 1.0
	tools.offset_left = -204
	tools.offset_right = -20
	tools.offset_top = -190
	tools.offset_bottom = -12
	tools.add_theme_constant_override("h_separation", 4)
	tools.add_theme_constant_override("v_separation", 4)
	tools.visible = touch_enabled
	add_child(tools)
	for action_name in [&"interact", &"scan", &"lamp", &"uv", &"cryo", &"lure"]:
		var label := "E"
		match action_name:
			&"scan": label = "Q"
			&"lamp": label = "F"
			&"uv": label = "UV"
			&"cryo": label = "CRIO"
			&"lure": label = "SEÑUELO"
		var action_button := _make_touch_button(label)
		action_button.pressed.connect(_on_touch_action_pressed.bind(action_name))
		tools.add_child(action_button)

func _make_touch_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(56, 40)
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.add_theme_font_size_override("font_size", 12)
	return button

func _touch_action_down(action_name: StringName) -> void:
	Input.action_press(action_name)

func _touch_action_up(action_name: StringName) -> void:
	Input.action_release(action_name)

func _on_touch_action_pressed(action_name: StringName) -> void:
	if _player == null:
		return
	match action_name:
		&"interact": _player.interact()
		&"scan": _player.scan()
		&"lamp": _player.toggle_flashlight()
		&"uv": _player.fire_tool(false)
		&"cryo": _player.fire_tool(true)
		&"lure": _player.deploy_lure()

func _on_touch_look_input(event: InputEvent) -> void:
	if _player == null or not _player.controls_enabled:
		return
	if event is InputEventScreenDrag:
		_player.apply_look((event as InputEventScreenDrag).relative)
	elif event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_touch_start_position = touch.position
			_touch_start_time = Time.get_ticks_msec()
		elif Time.get_ticks_msec() - _touch_start_time < 260 and touch.position.distance_to(_touch_start_position) < 14.0:
			_player.interact()
	
func _make_label(node_name: String, text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.name = node_name
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.9))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label

func _on_prompt_changed(text: String) -> void:
	_prompt_label.text = text
	_prompt_label.visible = not text.is_empty()

func _on_message_changed(text: String) -> void:
	_message_label.text = text
	_message_label.visible = not text.is_empty()
	if text.is_empty():
		_message_timer.stop()
	else:
		_message_timer.start()

func _clear_message() -> void:
	_message_label.text = ""
	_message_label.visible = false

func _on_inventory_changed(items: Array) -> void:
	var names := PackedStringArray()
	for item in items:
		match str(item):
			"pulse": names.append("UV")
			"cryo": names.append("CRIO")
			"lamp": names.append("LINTERNA")
			"card": names.append("V–03")
			"cell": names.append("CELDA")
			"sample": names.append("MUESTRA")
			"recorder": names.append("BITÁCORA")
			_:
				names.append(str(item).to_upper())
	_inventory_label.text = "EQUIPO  ·  " + (" / ".join(names) if not names.is_empty() else "VACÍO")
	_refresh_quick_slots()

func _on_flashlight_changed(enabled: bool, battery: float) -> void:
	var state := "ENCENDIDA" if enabled else "APAGADA"
	_status_label.text = "LINTERNA  %s  ·  %02d%%" % [state, roundi(battery)]

func _on_tool_state_changed(energy: float, battery: float, weapon: int) -> void:
	var weapon_name := "MANO LIBRE"
	if weapon == 1:
		weapon_name = "EMISOR UV"
	elif weapon == 2:
		weapon_name = "PROYECTOR CRIO"
	_resource_label.text = "ENERGÍA  %02d%%  ·  %s  ·  BATERÍA %02d%%" % [roundi(energy), weapon_name, roundi(battery)]

func _on_stamina_changed(value: float) -> void:
	_stamina_bar.value = clampf(value, 0.0, 100.0)

func _on_quick_slot_changed(index: int, _item_id: StringName) -> void:
	for slot_index in _quick_slot_buttons.size():
		var button := _quick_slot_buttons[slot_index]
		var item_id: StringName = &""
		if _game_state != null and slot_index < _game_state.quick_slots.size():
			item_id = _game_state.quick_slots[slot_index]
		button.text = "%d  %s" % [slot_index + 1, _short_item_name(item_id)]
		button.modulate = Color(0.72, 1.0, 0.9) if slot_index == index else Color(0.64, 0.76, 0.8)

func _refresh_quick_slots() -> void:
	var selected := _player.selected_quick_slot if _player != null else 0
	_on_quick_slot_changed(selected, &"")

func _on_quick_slot_pressed(index: int) -> void:
	if _player != null:
		_player.select_quick_slot(index)

func _short_item_name(item_id: StringName) -> String:
	match item_id:
		&"pulse": return "UV"
		&"cryo": return "CRIO"
		&"lamp": return "LAMP"
		&"cell": return "CELDA"
		&"card": return "V–03"
		&"sample": return "MUESTRA"
		&"recorder": return "LOG"
		_: return "—"

func _on_panel_requested(panel_name: StringName) -> void:
	if panel_name.is_empty():
		return
	if _active_panel == panel_name:
		_close_panel()
	else:
		_open_panel(panel_name)

func _open_panel(panel_name: StringName) -> void:
	_active_panel = panel_name
	for child in _panel_content.get_children():
		child.queue_free()
	_panel_content.add_child(_build_panel_header(panel_name))
	match panel_name:
		&"inventory": _populate_inventory()
		&"database": _populate_database()
		&"map": _populate_map()
		&"pause": _populate_pause()
		_: _populate_map()
	_panel_root.visible = true
	get_tree().paused = panel_name == &"pause"
	panel_visibility_changed.emit(true)

func _close_panel() -> void:
	if _active_panel.is_empty():
		return
	_active_panel = &""
	get_tree().paused = false
	_panel_root.visible = false
	panel_visibility_changed.emit(false)

func _build_panel_header(panel_name: StringName) -> Control:
	var row := HBoxContainer.new()
	var title := Label.new()
	match panel_name:
		&"inventory": title.text = "INVENTARIO DE CAMPO"
		&"database": title.text = "BITÁCORA / BASE DE DATOS"
		&"map": title.text = "MAPA DE INSTALACIÓN"
		&"pause": title.text = "PAUSA / SISTEMA"
		_: title.text = "NEXUS"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.65, 0.91, 0.91))
	row.add_child(title)
	var close := _make_panel_button("×")
	close.custom_minimum_size = Vector2(42, 36)
	close.pressed.connect(_close_panel)
	row.add_child(close)
	return row

func _populate_inventory() -> void:
	if _game_state == null or _game_state.inventory.is_empty():
		_add_panel_label("Inventario vacío · explora módulos y recupera equipo.")
		return
	_add_panel_label("Selecciona una ranura para asignar un objeto. Los emisores se activan con espacio o G; R usa el objeto seleccionado.")
	for item_id in _game_state.inventory:
		var row := HBoxContainer.new()
		var name_label := Label.new()
		name_label.text = _full_item_name(item_id)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.add_theme_color_override("font_color", Color(0.8, 0.9, 0.9))
		row.add_child(name_label)
		for slot_index in 5:
			var slot_button := _make_panel_button(str(slot_index + 1))
			slot_button.custom_minimum_size = Vector2(36, 32)
			slot_button.tooltip_text = "Asignar a ranura %d" % (slot_index + 1)
			slot_button.pressed.connect(_assign_item_to_slot.bind(slot_index, item_id))
			row.add_child(slot_button)
		_panel_content.add_child(row)
	_add_panel_label("I o Esc para cerrar · las ranuras rápidas se muestran en la parte inferior.")

func _populate_database() -> void:
	if _game_state == null or _game_state.survey_records.is_empty():
		_add_panel_label("Sin fichas registradas. Apunta a un objetivo o superficie y pulsa Q.")
		return
	for record in _game_state.survey_records:
		var name := str(record.get("name", record.get("id", "Registro")))
		var zone := str(record.get("zone", "desconocida")).to_upper()
		var detail := str(record.get("detail", "Sin observaciones adicionales"))
		_add_panel_label("%s  ·  %s\n%s" % [name, zone, detail])

func _populate_map() -> void:
	var current: StringName = _game_state.current_zone if _game_state != null else &""
	var current_definition: ZoneDefinition = _zone_catalog.zone(current) if _zone_catalog != null else null
	var entries: Array = []
	if _zone_catalog != null:
		var neighbors: Array[StringName] = []
		if current_definition != null:
			neighbors = current_definition.neighbors
		for zone_id: StringName in _zone_catalog.zone_ids():
			var definition := _zone_catalog.zone(zone_id)
			entries.append({
				"id": zone_id,
				"label": str(zone_id).to_upper().replace("_", "-"),
				"min": definition.bounds_min,
				"max": definition.bounds_max,
				"neighbor": neighbors.has(zone_id),
			})
	var view := ZoneMapView.new()
	view.name = "ZoneMap"
	view.configure(entries, current)
	_panel_content.add_child(view)
	if current_definition == null:
		_add_panel_label("Mapa no disponible · catálogo de zonas sin cargar.")
		return
	_add_panel_label("Ubicación actual: %s" % current_definition.display_name)
	var connection_lines := PackedStringArray()
	if _zone_catalog != null:
		for connection in _zone_catalog.connections_of(current):
			var target: StringName = connection.to_zone if connection.from_zone == current else connection.from_zone
			var socket: StringName = connection.from_socket if connection.from_zone == current else connection.to_socket
			var target_definition := _zone_catalog.zone(target)
			var target_name := target_definition.display_name if target_definition != null else str(target)
			connection_lines.append("· %s  (%s)" % [target_name, str(socket)])
	if connection_lines.is_empty():
		_add_panel_label("Sin enlaces de tránsito registrados para este módulo.")
	else:
		_add_panel_label("Tránsitos disponibles:\n" + "\n".join(connection_lines))
	_add_panel_label("12 módulos registrados · C–04, A–01, B–02, Vigilancia, Electricidad, Hub L–01, Carretera, Vía, Galería V–03, H–01, D–02 y Crioteca V–03. El tránsito se realiza cruzando la compuerta física.")

func _populate_pause() -> void:
	_add_panel_label("Partida detenida. El estado se guarda automáticamente y al cambiar de módulo.")
	var resume := _make_panel_button("CONTINUAR")
	resume.pressed.connect(_close_panel)
	_panel_content.add_child(resume)
	var save := _make_panel_button("GUARDAR PARTIDA")
	save.pressed.connect(_save_from_panel)
	_panel_content.add_child(save)
	var quit := _make_panel_button("GUARDAR Y SALIR")
	quit.pressed.connect(_save_and_quit)
	_panel_content.add_child(quit)

func _add_panel_label(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", Color(0.69, 0.82, 0.84))
	_panel_content.add_child(label)

func _make_panel_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.add_theme_color_override("font_color", Color(0.77, 0.94, 0.91))
	button.add_theme_font_size_override("font_size", 14)
	return button

func _assign_item_to_slot(slot_index: int, item_id: StringName) -> void:
	if _game_state != null:
		_game_state.set_quick_slot(slot_index, item_id)

func _save_from_panel() -> void:
	if _game_state != null and _game_state.save_game():
		_show_panel_notice("Partida guardada correctamente.")
	else:
		_show_panel_notice("No se pudo escribir la partida.")

func _save_and_quit() -> void:
	if _game_state != null:
		_game_state.save_game()
	get_tree().quit()

func _show_panel_notice(text: String) -> void:
	_add_panel_label(text)

func _full_item_name(item_id: StringName) -> String:
	match item_id:
		&"pulse": return "Emisor UV"
		&"cryo": return "Proyector criogénico"
		&"lamp": return "Linterna de campo"
		&"card": return "Tarjeta de acceso V–03"
		&"cell": return "Celda de carga"
		&"recorder": return "Bitácora de custodia"
		&"sample": return "Muestra V–03"
		_: return str(item_id)
