extends Node3D
## Captura las pantallas nuevas (telemetría CAM 04 y panel de fósforo) en Xvfb.

var _frames := 0
var _telemetry: WallScreen
var _phosphor: WallScreen


func _ready() -> void:
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.02, 0.04, 0.05)
	env.ambient_light_color = Color(0.4, 0.6, 0.65)
	env.ambient_light_energy = 0.5
	environment.environment = env
	add_child(environment)
	var light := OmniLight3D.new()
	light.position = Vector3(0.0, 1.2, 2.4)
	light.omni_range = 8.0
	light.light_energy = 2.0
	add_child(light)
	_telemetry = WallScreen.new()
	_telemetry.kind = "telemetry"
	_telemetry.position = Vector3(-1.5, 1.6, 0.0)
	add_child(_telemetry)
	_phosphor = WallScreen.new()
	_phosphor.kind = "phosphor"
	_phosphor.position = Vector3(1.1, 1.6, 0.0)
	add_child(_phosphor)
	var camera := Camera3D.new()
	camera.position = Vector3(-0.1, 1.55, 2.6)
	camera.fov = 62.0
	add_child(camera)
	camera.current = true


func _process(_delta: float) -> void:
	_frames += 1
	if _frames == 3:
		var bus := {"load": 68.0, "temp": 43.5, "capacity": 112, "tripped": false,
			"feeds": [true, true, false, true], "fans": [true, false, true, true],
			"cause": "Sobrecarga sostenida en la derivación E-07 del cuadro"}
		for step in 40:
			var time := step * 0.4
			_telemetry.push_telemetry(time, bus, 96.0 - fmod(time * 3.0, 14.0),
				4.0 + sin(time * 0.6) * 3.4, "AGGRESSIVE" if step > 18 else "WATCHING",
				Vector3(1.4, 0.0, 24.2 - time), "Carga" if step > 18 else "Vigila", step / 6, 0.62)
			_phosphor.push_phosphor("RED · E-07", "68 kW", "derivación este",
				0.61 + sin(time) * 0.12)
	if _frames == 12:
		var image := get_viewport().get_texture().get_image()
		var error := image.save_png("res://reports/displays-cam04.png")
		print("CAPTURE reports/displays-cam04.png -> %s" % ("ok" if error == OK else str(error)))
		get_tree().quit()
