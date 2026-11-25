extends Node3D
## Primer plano de los siete ojos de W–01 para revisar parpadeo y pupila.

var frames := 0
var only := ""
var sys: W01Eyes
var shots: Array = [
	{"name": "open"},
	{"name": "bare", "bare": true},
	{"name": "blink", "blink_time": 0.163},
	{"name": "flash", "flash": true},
]
var index := 0


func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		only = argument
	var packed := load("res://assets/generated/w01_eyes.glb") as PackedScene
	var root: Node3D = packed.instantiate()
	add_child(root)
	var eyes_root: Node = root.get_child(0)
	sys = W01Eyes.new()
	add_child(sys)
	sys.attach(eyes_root)
	W01Materials.soften(root)
	if not only.is_empty():
		var stack: Array[Node] = [root]
		while not stack.is_empty():
			var node: Node = stack.pop_back()
			var mesh := node as MeshInstance3D
			if mesh != null and String(mesh.name).begins_with("Eye0_"):
				mesh.visible = String(mesh.name).ends_with(only)
			for child in node.get_children():
				stack.push_back(child)
	var camera := Camera3D.new()
	camera.position = Vector3(0.0, 3.1, 7.6)
	camera.fov = 45.0
	add_child(camera)
	camera.look_at(Vector3(0.0, 3.0, 1.0), Vector3.UP)
	camera.current = true
	var light := OmniLight3D.new()
	light.position = Vector3(2.2, 4.6, 5.2)
	light.light_energy = 3.0
	light.omni_range = 18.0
	add_child(light)
	var fill := OmniLight3D.new()
	fill.position = Vector3(-3.0, 2.4, 4.4)
	fill.light_energy = 1.4
	fill.omni_range = 16.0
	add_child(fill)
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.05, 0.07, 0.09)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.5, 0.6, 0.7)
	env.ambient_light_energy = 0.7
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.42, 0.56, 0.7)
	sky_material.sky_horizon_color = Color(0.68, 0.76, 0.82)
	var sky := Sky.new()
	sky.sky_material = sky_material
	env.sky = sky
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	environment.environment = env
	add_child(environment)

func _process(_delta: float) -> void:
	frames += 1
	var shot: Dictionary = shots[index]
	var holding := bool(shot.get("hold", false))
	# 1) Aplicar el estado durante tres frames: la imagen del viewport llega un
	#    frame por detrás, así que hay que dejar que se renderice.
	if not holding:
		sys.set_lids_visible(not bool(shot.get("bare", false)))
		sys.blink_timer = 99.0
		sys.blink_time = float(shot.get("blink_time", 0.0))
		if bool(shot.get("flash", false)):
			sys.flash()
		shot["hold"] = true
		shot["hold_frame"] = frames
		sys.update(float(frames) * 0.016, 0.0, Vector3(0.6, 3.2, 6.0), 0.2)
		return
	# 2) Mantener la pose (sin decaer) hasta que el frame esté listo.
	sys.update(float(frames) * 0.016, 0.0, Vector3(0.6, 3.2, 6.0), 0.2)
	if frames - int(shot["hold_frame"]) < 3:
		return
	var image := get_viewport().get_texture().get_image()
	var path := "res://reports/eyes-%s.png" % String(shot["name"])
	print("CAPTURE %s -> %s" % [path, "ok" if image.save_png(path) == OK else "fail"])
	index += 1
	if index >= shots.size():
		get_tree().quit()
