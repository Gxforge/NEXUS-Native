extends Node

@onready var catalog: ZoneCatalog = $ZoneCatalog
@onready var game_state: GameState = $GameState
@onready var zone_manager: ZoneManager = $ZoneManager
@onready var player: NexusPlayer = $PersistentWorld/Player
@onready var main_menu: Control = $UI/MainMenu
@onready var loading_screen: Control = $UI/LoadingScreen
@onready var loading_progress: ProgressBar = $UI/LoadingScreen/Panel/Content/Progress
@onready var loading_status: Label = $UI/LoadingScreen/Panel/Content/Status

var _startup_requested: bool = false
var _transition_requested: bool = false

func _ready() -> void:
	_register_zones()
	zone_manager.configure(catalog, game_state)
	zone_manager.transition_finished.connect(_on_initial_zone_ready)
	$UI/MainMenu/Panel/Content/Start.pressed.connect(start_game)
	$UI/MainMenu/Panel/Content/Quit.pressed.connect(_quit_game)
	player.set_controls_enabled(false)
	main_menu.show()
	loading_screen.hide()
	set_process(false)

func start_game() -> bool:
	if _startup_requested:
		return false
	_startup_requested = true
	main_menu.hide()
	loading_screen.show()
	loading_progress.value = 0.0
	loading_status.text = "Solicitando C-04"
	if not zone_manager.preload_zone(&"c04"):
		loading_status.text = "Error al solicitar C-04"
		_startup_requested = false
		return false
	set_process(true)
	return true

func _process(_delta: float) -> void:
	if not _startup_requested or _transition_requested:
		return
	var progress: Array = []
	var status := ResourceLoader.load_threaded_get_status(
		catalog.zone(&"c04").scene_path, progress
	)
	if not progress.is_empty():
		loading_progress.value = float(progress[0]) * 100.0
	match status:
		ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			loading_status.text = "Precargando geometría y recursos"
		ResourceLoader.THREAD_LOAD_LOADED:
			loading_progress.value = 100.0
			loading_status.text = "Inicializando C-04"
			_transition_requested = zone_manager.transition_to(&"c04", &"entry")
		ResourceLoader.THREAD_LOAD_FAILED, ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			loading_status.text = "No se pudo cargar C-04"
			set_process(false)

func _on_initial_zone_ready(zone_id: StringName) -> void:
	if zone_id != &"c04":
		return
	set_process(false)
	loading_screen.hide()
	player.set_controls_enabled(true)

func _quit_game() -> void:
	get_tree().quit()

func _register_zones() -> void:
	var c04 := ZoneDefinition.new()
	c04.id = &"c04"
	c04.scene_path = "res://zones/zone_c04_shell.tscn"
	c04.display_name = "C-04 · Contención"
	c04.neighbors = [&"a01"]
	catalog.register_zone(c04)
	var a01 := ZoneDefinition.new()
	a01.id = &"a01"
	a01.scene_path = "res://zones/zone_a01_shell.tscn"
	a01.display_name = "A-01 · Archivo"
	a01.neighbors = [&"c04"]
	catalog.register_zone(a01)
	var connection := DoorConnection.new()
	connection.id = &"c04_a01"
	connection.from_zone = &"c04"
	connection.from_socket = &"to_a01"
	connection.to_zone = &"a01"
	connection.to_socket = &"from_c04"
	catalog.register_connection(connection)
