class_name ZoneManager
extends Node

enum State { IDLE, VALIDATING, REQUESTING, LOADING, STAGING, TRANSFERRING, RELEASING, FAILED }

signal zone_load_started(zone_id: StringName)
signal zone_ready(zone_id: StringName)
signal player_transferred(zone_id: StringName)
signal zone_unloaded(zone_id: StringName)
signal transition_failed(zone_id: StringName, reason: String)
signal transition_finished(zone_id: StringName)

@export var active_zones_path: NodePath
@export var player_path: NodePath
var catalog: ZoneCatalog
var game_state: GameState
var state := State.IDLE
var current_zone: ZoneRoot
var _request_path := ""
var _target_id: StringName
var _target_socket: StringName
var _preloaded_paths: Dictionary = {}

func configure(p_catalog: ZoneCatalog, p_state: GameState) -> void:
	catalog = p_catalog
	game_state = p_state

func preload_zone(zone_id: StringName) -> bool:
	if catalog == null or not catalog.has_zone(zone_id):
		return false
	var path := catalog.zone(zone_id).scene_path
	var status := ResourceLoader.load_threaded_get_status(path)
	if status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		if ResourceLoader.load_threaded_request(path, "PackedScene") != OK:
			return false
	_preloaded_paths[zone_id] = path
	return true

func preload_status(zone_id: StringName) -> ResourceLoader.ThreadLoadStatus:
	if catalog == null or not catalog.has_zone(zone_id):
		return ResourceLoader.THREAD_LOAD_INVALID_RESOURCE
	return ResourceLoader.load_threaded_get_status(catalog.zone(zone_id).scene_path)

func transition_to(zone_id: StringName, socket: StringName = &"entry") -> bool:
	if state != State.IDLE or catalog == null or game_state == null:
		return false
	state = State.VALIDATING
	var definition := catalog.zone(zone_id)
	if definition == null:
		_fail(zone_id, "Unknown zone")
		return false
	_target_id = zone_id
	_target_socket = socket
	_request_path = definition.scene_path
	state = State.REQUESTING
	var status := ResourceLoader.load_threaded_get_status(_request_path)
	if status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		var error := ResourceLoader.load_threaded_request(_request_path, "PackedScene")
		if error != OK:
			_fail(zone_id, "Threaded request failed: %s" % error)
			return false
	elif status == ResourceLoader.THREAD_LOAD_FAILED:
		_fail(zone_id, "Preload failed")
		return false
	state = State.LOADING
	zone_load_started.emit(zone_id)
	set_process(true)
	return true

func _process(_delta: float) -> void:
	if state != State.LOADING:
		return
	var progress: Array = []
	var status := ResourceLoader.load_threaded_get_status(_request_path, progress)
	if status == ResourceLoader.THREAD_LOAD_FAILED or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		_fail(_target_id, "Threaded load failed")
	elif status == ResourceLoader.THREAD_LOAD_LOADED:
		set_process(false)
		_stage_loaded_zone()

func _stage_loaded_zone() -> void:
	state = State.STAGING
	var packed := ResourceLoader.load_threaded_get(_request_path) as PackedScene
	if packed == null:
		_fail(_target_id, "Loaded resource is not a PackedScene")
		return
	var next_zone := packed.instantiate() as ZoneRoot
	if next_zone == null or next_zone.zone_id != _target_id:
		if next_zone != null: next_zone.queue_free()
		_fail(_target_id, "Zone identity mismatch")
		return
	next_zone.zone_ready.connect(_on_staged_zone_ready, Object.CONNECT_ONE_SHOT)
	get_node(active_zones_path).add_child(next_zone)

func _on_staged_zone_ready(next_zone: ZoneRoot) -> void:
	zone_ready.emit(_target_id)
	_transfer(next_zone)

func _transfer(next_zone: ZoneRoot) -> void:
	state = State.TRANSFERRING
	var player := get_node_or_null(player_path) as Node3D
	if player == null:
		next_zone.queue_free()
		_fail(_target_id, "Persistent player missing")
		return
	player.global_transform = next_zone.socket_transform(_target_socket)
	next_zone.activate()
	var previous := current_zone
	current_zone = next_zone
	game_state.commit_zone(_target_id)
	player_transferred.emit(_target_id)
	if previous != null:
		state = State.RELEASING
		var old_id := previous.zone_id
		previous.tree_exited.connect(_on_previous_zone_exited.bind(old_id), Object.CONNECT_ONE_SHOT)
		previous.deactivate()
		previous.queue_free()
		return
	_complete_transition()

func _on_previous_zone_exited(old_id: StringName) -> void:
	zone_unloaded.emit(old_id)
	_complete_transition()

func _complete_transition() -> void:
	state = State.IDLE
	_request_path = ""
	_preloaded_paths.erase(_target_id)
	transition_finished.emit(_target_id)

func _fail(zone_id: StringName, reason: String) -> void:
	state = State.FAILED
	set_process(false)
	transition_failed.emit(zone_id, reason)
	state = State.IDLE
