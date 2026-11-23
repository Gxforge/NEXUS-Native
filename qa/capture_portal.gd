extends Node3D

@onready var portal: SectorDoor = $A01PortalAssembly

func _ready() -> void:
	$Camera3D.look_at(Vector3(0.0, 4.4, 0.0), Vector3.UP)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	_capture("res://reports/a01-portal-closed.png")
	portal.request_open(true)
	for _frame in 180:
		await get_tree().physics_frame
	await RenderingServer.frame_post_draw
	_capture("res://reports/a01-portal-open.png")
	get_tree().quit()

func _capture(path: String) -> void:
	var image := get_viewport().get_texture().get_image()
	var error := image.save_png(path)
	if error != OK:
		push_error("Unable to save graphical QA capture: %s" % error)
