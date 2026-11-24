class_name StreamingSectorDoor
extends SectorDoor

@export var target_zone: StringName
@export var target_socket: StringName
var _near_bodies := 0
var _transition_started := false
var _threshold_bodies: Array[Node3D] = []

@onready var proximity_sensor: Area3D = $ProximitySensor
@onready var transition_threshold: Area3D = $TransitionThreshold

func _ready() -> void:
	super()
	proximity_sensor.body_entered.connect(_on_proximity_entered)
	proximity_sensor.body_exited.connect(_on_proximity_exited)
	transition_threshold.body_entered.connect(_on_threshold_entered)
	transition_threshold.body_exited.connect(_on_threshold_exited)
	set_streaming_enabled(false)

func set_streaming_enabled(enabled: bool) -> void:
	proximity_sensor.set_deferred("monitoring", enabled)
	transition_threshold.set_deferred("monitoring", enabled)
	if not enabled:
		_near_bodies = 0
		_transition_started = false
		_threshold_bodies.clear()
		request_open(false)

func begin_approach(body: Node3D) -> bool:
	if not body is NexusPlayer:
		return false
	_near_bodies = maxi(_near_bodies, 1)
	request_open(true)
	var manager := _manager()
	return manager != null and manager.preload_zone(target_zone)

func get_interaction_prompt() -> String:
	var manager := _manager()
	var destination := str(target_zone).to_upper()
	if manager != null and manager.catalog != null:
		var definition := manager.catalog.zone(target_zone)
		if definition != null:
			destination = definition.display_name
	return "E · Preparar tránsito a " + destination

func interact(actor: NexusPlayer) -> String:
	if actor == null:
		return "Operador no identificado"
	if begin_approach(actor):
		return "Portal preparado · cruza el umbral cuando se abra"
	return "Enlace de tránsito no disponible"

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

func _physics_process(delta: float) -> void:
	super(delta)
	_evaluate_threshold()

## The threshold is re-evaluated while a body overlaps it: a sprinting player used
## to reach the door before the leaves finished opening and the single
## `body_entered` event was then lost, leaving the portal uncrossable.
func _evaluate_threshold() -> void:
	if _transition_started or _threshold_bodies.is_empty():
		return
	for index in range(_threshold_bodies.size() - 1, -1, -1):
		var body := _threshold_bodies[index]
		if body == null or not is_instance_valid(body) or not body.is_inside_tree():
			_threshold_bodies.remove_at(index)
			continue
		if not body is NexusPlayer:
			continue
		var player := body as NexusPlayer
		if aperture < 0.9:
			continue
		if player.velocity.dot(-global_transform.basis.z) < 0.4:
			continue
		if commit_crossing(player):
			_threshold_bodies.clear()
			return

func _on_threshold_entered(body: Node3D) -> void:
	if not body is NexusPlayer:
		return
	if not _threshold_bodies.has(body):
		_threshold_bodies.append(body)
	_evaluate_threshold()

func _on_threshold_exited(body: Node3D) -> void:
	_threshold_bodies.erase(body)

func _manager() -> ZoneManager:
	return get_tree().get_first_node_in_group(&"zone_manager") as ZoneManager
