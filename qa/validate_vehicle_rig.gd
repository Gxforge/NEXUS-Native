extends SceneTree
## Valida el coche de vía: suspensión de cuatro apoyos y mallas de `vehicle.glb`.

var checks := 0
var failures: Array[String] = []


func _check(name: String, condition: bool) -> void:
	checks += 1
	if not condition:
		failures.append(name)


func _near(name: String, value: float, expected: float, tolerance := 0.001) -> void:
	_check("%s (%.4f ≈ %.4f)" % [name, value, expected], absf(value - expected) <= tolerance)


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame

	# 1. Constantes de la suspensión, las de `tune` en la web.
	_near("recorrido de suspensión", VehiclePhysics.SUSPENSION_TRAVEL, 0.19)
	_near("rigidez del muelle", VehiclePhysics.SUSPENSION_STIFFNESS, 41.0)
	_near("amortiguación al comprimir", VehiclePhysics.SUSPENSION_COMPRESSION, 3.4)
	_near("amortiguación al extender", VehiclePhysics.SUSPENSION_REBOUND, 4.5)
	_near("tope del muelle", VehiclePhysics.MAX_SUSPENSION_FORCE, 18000.0)
	_near("influencia del vuelco", VehiclePhysics.ROLL_INFLUENCE, 0.12)
	_check("cuatro anclajes", VehiclePhysics.WHEEL_OFFSETS.size() == 4)
	_check("anclajes delanteros en +z y traseros en −z",
		VehiclePhysics.WHEEL_OFFSETS[0].z > 0.0 and VehiclePhysics.WHEEL_OFFSETS[1].z > 0.0
		and VehiclePhysics.WHEEL_OFFSETS[2].z < 0.0 and VehiclePhysics.WHEEL_OFFSETS[3].z < 0.0)
	_near("vía de 1,74 m", VehiclePhysics.WHEEL_OFFSETS[1].x - VehiclePhysics.WHEEL_OFFSETS[0].x, 1.74)

	# 2. Reposo: los cuatro apoyos tocan el suelo a la altura del radio.
	var physics := VehiclePhysics.new()
	physics.reset(-12.0, 109.0, 0.0, true)
	for i in 600:
		physics.step(1.0 / 120.0, 0.0, 0.0, false, false)
	_check("cuatro apoyos en reposo (%d)" % physics.contacts, physics.contacts == 4)
	for index in 4:
		_near("la rueda %d se asienta en el radio" % index,
			physics.wheel_state(index)["position"].y, VehiclePhysics.WHEEL_RADIUS, 0.02)
		_near("suspensión %d en reposo" % index, physics.wheel_suspension[index], 0.31, 0.02)
	_near("actitud nivelada", physics.pitch, 0.0, 0.01)

	# 3. Acelerar levanta el morro y comprime la trasera.
	var fast := VehiclePhysics.new()
	fast.reset(-12.0, 109.0, 0.0, true)
	for i in 240:
		fast.step(1.0 / 120.0, 1.0, 0.0, false, false)
	_check("al acelerar el morro sube (%.3f rad)" % fast.pitch, fast.pitch < -0.005)
	_check("las ruedas delanteras extienden (%s)" % str(fast.wheel_suspension),
		fast.wheel_suspension[0] > fast.wheel_suspension[2])
	_check("las traseras comprimen", fast.wheel_suspension[2] < 0.31)
	var inside := true
	for length in fast.wheel_suspension:
		if length < VehiclePhysics.SUSPENSION_REST - VehiclePhysics.SUSPENSION_TRAVEL - 0.001 \
				or length > VehiclePhysics.SUSPENSION_REST + VehiclePhysics.SUSPENSION_TRAVEL + 0.001:
			inside = false
	_check("ningún muelle se sale de su recorrido (%s)" % str(fast.wheel_suspension), inside)

	# 4. Frenar hunde el morro.
	var braking := VehiclePhysics.new()
	braking.reset(-12.0, 109.0, 0.0, true)
	for i in 240:
		braking.step(1.0 / 120.0, 1.0, 0.0, false, false)
	for i in 90:
		braking.step(1.0 / 120.0, -1.0, 0.0, false, false)
	_check("al frenar el morro baja (%.3f rad)" % braking.pitch, braking.pitch > 0.0)

	# 5. Girar vuelca la carrocería hacia fuera y gira las ruedas delanteras.
	var turning := VehiclePhysics.new()
	turning.reset(-12.0, 109.0, 0.0, true)
	for i in 300:
		turning.step(1.0 / 120.0, 1.0, 1.0, false, false)
	_check("la carrocería balancea al girar (%.3f rad)" % turning.roll, absf(turning.roll) > 0.01)
	_check("sólo las delanteras giran",
		absf(turning.wheel_steering[0]) > 0.01 and absf(turning.wheel_steering[1]) > 0.01
		and absf(turning.wheel_steering[2]) < 0.0001 and absf(turning.wheel_steering[3]) < 0.0001)
	_near("la dirección de la rueda es el volante", turning.wheel_steering[0], turning.steer)
	var degrees := turning.attitude_degrees()
	_near("actitud en grados", degrees.x, rad_to_deg(turning.pitch))

	# 6. La rodadura avanza con la velocidad.
	var roll := VehiclePhysics.new()
	roll.reset(-12.0, 109.0, 0.0, true)
	roll.speed = 10.0
	roll.step(1.0 / 120.0, 0.0, 0.0, false, false)
	_near("la rueda gira v/r·t", roll.wheel_rotation[0],
		fposmod(10.0 / VehiclePhysics.WHEEL_RADIUS / 120.0, TAU), 0.001)

	# 7. Montaje del modelo original dentro del rig.
	var model := PropLibrary.vehicle()
	_check("se carga vehicle.glb", model != null)
	var rig := VehicleRig.new()
	root.add_child(rig)
	_check("el modelo se monta", model != null and rig.attach(model))
	_check("se reconoce el cuerpo (%s)" % (rig.body.name if rig.body != null else "—"),
		rig.body != null)
	_check("cuatro ruedas (%d)" % rig.wheel_count(), rig.wheel_count() == 4)
	_check("las ruedas entran en el árbol", rig.find_children("*", "MeshInstance3D", true, false).size() >= 30)
	for index in 4:
		var wheel := rig.wheels[index]
		_check("la rueda %d ocupa su sitio" % index,
			wheel.position.distance_to(VehicleRig.WHEEL_POSITIONS[index]) < 0.001)
	_near("rueda delantera izquierda en x", rig.wheels[0].position.x, -0.87)
	_near("rueda delantera izquierda en z", rig.wheels[0].position.z, 1.38)

	# 8. `sync` copia la física: cuerpo, actitud y ruedas.
	rig.sync(physics)
	_near("el cuerpo va bajo el centro de masas", rig.position.y,
		physics.position.y - VehiclePhysics.COM_Y, 0.001)
	_near("la rueda va a comY + 0,14 − suspensión", rig.wheel_y(0),
		VehiclePhysics.COM_Y + VehiclePhysics.WHEEL_OFFSETS[0].y - physics.wheel_suspension[0])
	rig.sync(fast)
	_near("la actitud llega al cuerpo", rig.rotation.x, fast.pitch)
	_near("el rumbo llega al cuerpo", rig.rotation.y, fast.yaw)
	_near("el balanceo llega al cuerpo", rig.rotation.z, fast.roll)
	rig.sync(turning)
	_near("la rueda delantera gira con la dirección", rig.wheels[0].rotation.y, turning.steer)
	_near("la rueda trasera no gira", rig.wheels[3].rotation.y, 0.0)
	_near("la rueda rueda", rig.wheels[0].rotation.x, turning.wheel_rotation[0])
	rig.place(Vector3(3.0, 0.0, 20.0), PI * 0.5)
	_near("parado, el cuerpo sube al centro de masas", rig.position.y, VehiclePhysics.COM_Y)
	_near("parado, el rumbo se copia", rig.rotation.y, PI * 0.5)
	_near("parado, las ruedas vuelven a su altura de diseño", rig.wheel_y(0), VehicleRig.WHEEL_REST_Y)

	print(JSON.stringify({"checks": checks, "failures": failures, "passed": failures.is_empty()}))
	quit(0 if failures.is_empty() else 1)
