class_name SectorDoor
extends Node3D

signal aperture_changed(value: float)

const CLOSED_CENTER := 1.1
const TRAVEL := 2.17
const DAMPING := 5.0

@export_range(0.0, 1.0) var target_aperture := 0.0
var aperture := 0.0

@onready var left_leaf: AnimatableBody3D = $LeftLeaf
@onready var right_leaf: AnimatableBody3D = $RightLeaf

func _ready() -> void:
	apply_aperture(aperture)

func _physics_process(delta: float) -> void:
	var next := lerpf(aperture, target_aperture, 1.0 - exp(-DAMPING * delta))
	if is_equal_approx(next, aperture):
		return
	apply_aperture(next)

func request_open(open: bool) -> void:
	target_aperture = 1.0 if open else 0.0

func snap_aperture(value: float) -> void:
	target_aperture = clampf(value, 0.0, 1.0)
	apply_aperture(target_aperture)

func apply_aperture(value: float) -> void:
	aperture = clampf(value, 0.0, 1.0)
	left_leaf.position = Vector3(-(CLOSED_CENTER + TRAVEL * aperture), 2.15, 0.0)
	right_leaf.position = Vector3(CLOSED_CENTER + TRAVEL * aperture, 2.15, 0.0)
	aperture_changed.emit(aperture)
