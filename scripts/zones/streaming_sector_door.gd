class_name StreamingSectorDoor
extends SectorDoor

@export var target_zone: StringName
@export var target_socket: StringName
var _near_bodies := 0
var _transition_started := false

@onready var proximity_sensor: Area3D = $ProximitySensor
@onready var transition_threshold: Area3D = $TransitionThreshold

func _ready() -> void:
	super()
	proximity_sensor.body_entered.connect(_on_proximity_entered)
	proximity_sensor.body_exited.connect(_on_proximity_exited)
	transition_threshold.body_entered.connect(_on_threshold_entered)
	set_streaming_enabled(false)

func set_streaming_enabled(enabled: bool) -> void:
	proximity_sensor.set_deferred("monitoring", enabled)
	transition_threshold.set_deferred("monitoring", enabled)
	if not enabled:
		_near_bodies = 0
		_transition_started = false
		request_open(false)

func begin_approach(body: Node3D) -> bool:
	if not body is NexusPlayer:
		return false
	_near_bodies += 1
	request_open(true)
	var manager := _manager()
	return manager != null and manager.preload_zone(target_zone)

func end_approach(body: Node3D) -> void:
	if not body is NexusPlayer:
		return
	_near_bodies = maxi(0, _near_bodies - 1)
	if _near_bodies == 0 and not _transition_started:
		request_open(false)

func commit_crossing(body: Node3D) -> bool:
	if _transition_started or not body is NexusPlayer:
		return false
	var manager := _manager()
	if manager == null:
		return false
	_transition_started = manager.transition_to(target_zone, target_socket)
	return _transition_started

func _on_proximity_entered(body: Node3D) -> void:
	begin_approach(body)

func _on_proximity_exited(body: Node3D) -> void:
	end_approach(body)

func _on_threshold_entered(body: Node3D) -> void:
	commit_crossing(body)

func _manager() -> ZoneManager:
	return get_tree().get_first_node_in_group(&"zone_manager") as ZoneManager
