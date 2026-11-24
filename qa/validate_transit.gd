extends SceneTree
## Validador del tránsito de la web (`Transit.ts`) y del vehículo de vía
## (`VehiclePhysics.ts`): geografía del andén, compuerta, puertas, traslado de
## 10 s, asientos, embarque del carro en 4 s, física del coche, persistencia.

var checks := 0
var failures := 0


func _init() -> void:
	_geometry()
	_doors_and_travel()
	_seats_and_controls()
	_vehicle()
	_vehicle_drive()
	_persistence()
	print("\n=== validate_transit: %d checks, %d failures ===" % [checks, failures])
	if failures > 0:
		push_error("%d comprobaciones fallaron" % failures)
	quit(1 if failures > 0 else 0)


func check(label: String, condition: bool, extra := "") -> void:
	checks += 1
	if not condition:
		failures += 1
		print("  FAIL · %s%s" % [label, (" · " + extra) if not extra.is_empty() else ""])


func near(label: String, value: float, expected: float, tolerance := 0.001, extra := "") -> void:
	check(label, absf(value - expected) <= tolerance,
		"%.4f vs %.4f %s" % [value, expected, extra])


func fresh() -> CapsuleTransit:
	var transit := CapsuleTransit.new()
	transit.simulation = false
	transit.reset()
	return transit


# --------------------------------------------------------------------------- #
func _geometry() -> void:
	print("\n[geometría del andén]")
	var t := fresh()
	check("constantes de la web", CapsuleTransit.STATION_A == 102.0
		and CapsuleTransit.STATION_B == 2042.0 and CapsuleTransit.AXIS_X == 15.0)
	near("traslado 10 s", CapsuleTransit.TRAVEL_SECONDS, 10.0)
	near("cierre de puertas 1,4 s", CapsuleTransit.DEPART_DELAY, 1.4)
	check("arranca en el andén 01", is_equal_approx(t.at, 102.0))
	check("cartel ANDÉN 01", t.status == "ANDÉN 01", t.status)
	near("puertas abiertas al inicio", t.door, 1.0)
	near("compuerta cerrada", t.gate, 0.0)

	# Con la compuerta cerrada el andén sólo deja pasar una franja estrecha.
	near("compuerta cerrada · |x| límite", 3.94 * 0.0 - 0.34, -0.34)
	check("compuerta cerrada bloquea x = 0", not t.can_stand(0.0, 68.0))
	check("compuerta cerrada bloquea x = 2", not t.can_stand(2.0, 68.0))
	t.gate = 1.0
	check("compuerta abierta permite x = 3", t.can_stand(3.0, 68.0))
	check("compuerta abierta permite x = -3", t.can_stand(-3.0, 68.0))
	check("fuera de límite x = 3,6", not t.can_stand(3.6, 68.0))
	check("el delantal sur acaba en z 70,65", not fresh().can_stand(0.0, 70.5)
		and t.can_stand(0.0, 70.7))
	check("vía · límite |x| 19,8", not t.can_stand(19.85, 200.0))
	check("vía · dentro |x| 19,7", t.can_stand(19.7, 200.0))
	check("vía · límite z 2069,4", not t.can_stand(0.0, 2069.5))
	check("vía · dentro z 2060", t.can_stand(0.0, 2060.0))
	check("hueco de mantenimiento bloquea", not t.can_stand(6.1, 500.0))
	check("hueco · borde 6,66 libre", t.can_stand(6.7, 500.0))
	check("hueco no aplica al andén", t.can_stand(6.1, 100.0))

	check("dentro de la cápsula", t.inside(Vector3(15.0, 1.7, 100.0)))
	check("fuera por eje x", not t.inside(Vector3(13.0, 1.7, 100.0)))
	check("fuera por eje z", not t.inside(Vector3(15.0, 1.7, 91.0)))
	check("nombre de andén A", t.station_name(102.0) == "ANDÉN 01")
	check("nombre de andén B", t.station_name(2042.0) == "ANDÉN 02")
	check("nombre por defecto", t.station_name() == "ANDÉN 01")

	# Iluminación de la nave.
	near("luz al norte", t.power(90.0), 1.0)
	near("sin luz al sur", t.power(40.0), 0.0)
	check("carro en la plataforma", t.car_position() == Vector3(-12.0, 0.0, 109.0),
		str(t.car_position()))


# --------------------------------------------------------------------------- #
func _doors_and_travel() -> void:
	print("\n[puertas, traslado y retención]")
	var t := fresh()
	var player := Vector3(15.0, 1.7, 100.0)

	var result := t.use(&"railCallB", player)
	check("llamada al andén 02", str(result.get("message", "")).contains("Cierre"), str(result))
	near("inicia el cierre", t.time, 0.0)
	check("destino andén 02", is_equal_approx(t.target, 2042.0))

	var next := t.step(0.6, player, true, 0.0, 0.0)
	near("puertas cerrando a 0,6 s", t.door, 0.5, 0.02)
	check("jugador a bordo sigue quieto", next == player, str(next))
	check("cartel en marcha", t.status.ends_with("km/h"), t.status)

	t.step(0.6, player, true, 0.0, 0.0)
	near("puertas cerradas a 1,2 s", t.door, 0.0, 0.001)
	t.step(0.5, player, true, 0.0, 0.0)  # 1,7 s: ya arrancó
	check("arranca tras 1,4 s", t.at > 102.0, str(t.at))
	var moved_at := t.at
	var ratio := 0.03
	var eased := ratio * ratio * ratio * (ratio * (ratio * 6.0 - 15.0) + 10.0)
	near("smoothstep del 3 % del trayecto", moved_at - 102.0, (2042.0 - 102.0) * eased, 0.01)

	# A mitad del traslado el jugador a bordo viaja con la cápsula.
	var z_before := player.z
	next = t.step(5.0, player, true, 0.0, 0.0)
	check("jugador a bordo se desplaza", next.z > z_before + 100.0,
		"%.2f → %.2f" % [z_before, next.z])
	near("desplazamiento = cápsula", next.z - z_before, t.at - moved_at, 0.02)
	check("cartel durante el trayecto", t.status.ends_with("km/h"), t.status)

	# Alguien fuera de la cápsula no se mueve.
	var outside := Vector3(0.0, 1.7, 80.0)
	check("jugador fuera no viaja", t.step(0.5, outside, true, 0.0, 0.0) == outside)

	var arrived := []
	t.arrived.connect(func(station: String) -> void: arrived.append(station))
	t.step(5.0, player, true, 0.0, 0.0)
	near("llega al andén 02", t.at, 2042.0)
	check("señal de llegada", arrived.size() >= 1 and arrived[0] == "ANDÉN 02", str(arrived))
	near("traslado terminado", t.time, -1.0)
	check("cartel ANDÉN 02", t.status == "ANDÉN 02", t.status)
	next = t.step(1.5, player, true, 0.0, 0.0)
	near("puertas abren a 0,86/s", t.door, 1.0, 0.001)

	# Freno de retención.
	t.use(&"railCallB", player)
	check("llamada en el mismo andén no arranca", t.time < 0.0, str(t.time))
	t.use(&"railCallA", player)
	t.step(0.5, player, true, 0.0, 0.0)
	var brake := t.use(&"railBrake", player)
	check("freno de retención", str(brake.get("message", "")).contains("retención"), str(brake))
	var held_at := t.at
	t.step(2.0, player, true, 0.0, 0.0)
	near("retenida no avanza", t.at, held_at)
	check("cartel RETENIDA", t.status == "RETENIDA", t.status)
	check("freno no cambia destino", is_equal_approx(t.target, 102.0))
	t.use(&"railBrake", player)
	check("marcha restablecida", not t.hold)
	t.step(0.2, player, true, 0.0, 0.0)
	check("vuelve a avanzar", t.status.ends_with("km/h"), t.status)

	# Compuerta: sólo abre con el jugador de pie junto a ella.
	var g := fresh()
	g.step(1.0, Vector3(2.0, 1.7, 68.0), true, 0.0, 0.0)
	check("compuerta se abre cerca", g.gate > 0.6, str(g.gate))
	g.step(1.0, Vector3(2.0, 1.7, 40.0), true, 0.0, 0.0)
	check("compuerta se cierra al alejarse", g.gate < 0.4, str(g.gate))
	g.gate = 0.0
	g.step(1.0, Vector3(2.0, 1.7, 68.0), false, 0.0, 0.0)
	check("sin primera persona no abre", g.gate == 0.0, str(g.gate))


# --------------------------------------------------------------------------- #
func _seats_and_controls() -> void:
	print("\n[asientos y mando del carro]")
	var t := fresh()
	check("cinco asientos", CapsuleTransit.SEAT_OFFSETS.size() == 5)
	near("altura de asiento", CapsuleTransit.SEAT_OFFSETS[0].y, 1.47)
	near("asiento 1 en x", CapsuleTransit.SEAT_OFFSETS[0].x, 0.95)
	near("asiento 3 en x", CapsuleTransit.SEAT_OFFSETS[2].x, -0.98)
	near("asiento 5 en z", CapsuleTransit.SEAT_OFFSETS[4].z, -4.25)

	var seat := t.use(&"railSeat1", Vector3(0.0, 1.7, 80.0))
	check("toma el asiento 2", t.seat == 1, str(t.seat))
	check("mensaje de asiento", str(seat.get("message", "")).contains("Asiento"), str(seat))
	var next := t.step(0.016, Vector3(0.0, 1.7, 80.0), true, 0.0, 0.0)
	near("sentado en el eje", next.x, 15.0 + 0.95)
	near("sentado a la altura del banco", next.y, 1.47)
	near("sentado en el andén", next.z, 102.0 + 2.8)
	check("asiento inválido", t.use(&"railSeat9", Vector3.ZERO).get("message", "") == "Asiento no disponible")
	var up := t.use(&"railStand", next)
	check("se levanta", t.seat == -1)
	var stand_at: Vector3 = up.get("position", Vector3.ZERO)
	check("queda de pie en el andén", is_equal_approx(stand_at.y, 1.72), str(stand_at))

	# El asiento viaja con la cápsula.
	t.use(&"railSeat0", Vector3.ZERO)
	t.use(&"railCallB", Vector3.ZERO)
	t.step(0.5, Vector3.ZERO, true, 0.0, 0.0)
	var seat_next := t.step(6.0, Vector3(15.0, 1.7, 100.0), true, 0.0, 0.0)
	check("el asiento acompaña el traslado", seat_next.z > 1000.0, str(seat_next))

	# Transferencia del carro: 4 s, sube 0,24 y sube al eje x = 15.
	var c := fresh()
	c._car_offset = Vector3(-12.0, 0.0, 300.0)
	var message := str(c.use(&"railLoad", Vector3(0.0, 1.7, 100.0)).get("message", ""))
	check("embarque rechazado lejos", message.contains("Aparca"), message)
	c._car_offset = Vector3(-12.0, 0.0, 109.0)
	c.physics.reset(-12.0, 109.0, 0.0)
	var near_message := str(c.use(&"railLoad", Vector3(-12.0, 1.7, 100.0)).get("message", ""))
	check("embarque aceptado en el marco", near_message.contains("embarcando"), near_message)
	check("transferencia en marcha", c.transfer >= 0.0)
	var start := c.car_position()
	c.step(2.0, Vector3(15.0, 1.7, 100.0), true, 0.0, 0.0)
	var half := c.car_position()
	check("carro a medio camino", half.x > start.x and half.x < 15.0, str(half))
	near("altura intermedia 0,12", half.y, 0.12, 0.02)
	c.step(2.1, Vector3(15.0, 1.7, 100.0), true, 0.0, 0.0)
	check("carro embarcado", c.loaded)
	near("carro en el eje", c.car_position().x, 15.0)
	near("carro en la plataforma", c.car_position().z, 108.7, 0.01)
	c.step(0.5, Vector3(15.0, 1.7, 100.0), true, 0.0, 0.0)
	near("carro sube al piso de carga", c.car_position().y, 0.32)
	check("embarque bloqueado con carga", str(c.use(&"railCar", Vector3.ZERO)
		.get("message", "")).contains("enclavado"))
	c.step(0.1, Vector3(15.0, 1.7, 100.0), true, 0.0, 0.0)
	var down := c.use(&"railLoad", Vector3(15.0, 1.7, 100.0))
	check("descarga autorizada", str(down.get("message", "")).contains("Descargando"), str(down))
	var busy := c.use(&"railLoad", Vector3(15.0, 1.7, 100.0))
	check("maniobra en curso", str(busy.get("message", "")).contains("Maniobra"), str(busy))

	# Telemetría de la pantalla.
	var d := fresh()
	d.use(&"railSeat1", Vector3.ZERO)
	check("línea de asiento", d.status_line() == "ANDÉN 01", d.status_line())


# --------------------------------------------------------------------------- #
func _vehicle() -> void:
	print("\n[vehículo · constantes y contrato]")
	var v := VehiclePhysics.new()
	near("masa", VehiclePhysics.MASS, 1260.0)
	near("centro de masas", VehiclePhysics.COM_Y, 0.48)
	near("batalla", VehiclePhysics.WHEELBASE, 2.76)
	near("vía", VehiclePhysics.TRACK, 1.74)
	near("radio de rueda", VehiclePhysics.WHEEL_RADIUS, 0.355)
	near("velocidad punta", VehiclePhysics.TOP_SPEED, 49.0)
	near("marcha atrás", VehiclePhysics.REVERSE_SPEED, 8.0)
	near("paso fijo 1/120", VehiclePhysics.STEP, 1.0 / 120.0, 1e-9)
	near("umbral de impacto", VehiclePhysics.IMPACT_THRESHOLD, 2.7)
	near("turbo ×1,18", 49.0 * 1.18, 57.82, 0.01)
	near("motor con turbo ×1,75", 4100.0 * 1.75, 7175.0)
	near("energía inicial", v.energy, 100.0)
	near("integridad inicial", v.integrity, 100.0)
	near("cuatro apoyos", float(v.contacts), 4.0)
	check("marcha N detenido", v.gear == "N", v.gear)
	near("régimen de ralentí", v.rpm, 850.0)

	v.speed = 7.9
	v.step(1.0 / 120.0, 0.0, 0.0, false, false)
	check("marcha 1 hasta 8 m/s", v.gear == "1", v.gear)
	v.speed = 24.0
	v.step(1.0 / 120.0, 0.0, 0.0, false, false)
	check("marcha 4 a 24 m/s", v.gear == "4", v.gear)
	v.speed = 60.0
	v.step(1.0 / 120.0, 0.0, 0.0, false, false)
	check("tope de marchas en 6", v.gear == "6", v.gear)
	v.speed = -3.0
	v.step(1.0 / 120.0, 0.0, 0.0, false, false)
	check("marcha atrás", v.gear == "R", v.gear)
	check("el régimen sube con la velocidad", v.rpm >= 850.0, str(v.rpm))

	# Integridad por impacto.
	var w := VehiclePhysics.new()
	w.register_impact(2.0)
	near("impacto leve no daña", w.integrity, 100.0)
	w.register_impact(6.7)
	near("integridad (6,7−2,7)·1,65", w.integrity, 100.0 - 4.0 * 1.65, 0.001)
	check("marca de impacto", w.impact > 0.0, str(w.impact))
	w.register_impact(40.0)
	near("integridad al 0 mínima", maxf(0.0, w.integrity), 100.0 - 4.0 * 1.65 - 37.3 * 1.65)
	var x := VehiclePhysics.new()
	x.register_impact(100.0)
	near("integridad no baja de 0", x.integrity, 0.0)


# --------------------------------------------------------------------------- #
func _vehicle_drive() -> void:
	print("\n[vehículo · conducción]")
	var v := VehiclePhysics.new()
	v.reset(-12.0, 109.0, 0.0, true)
	check("posición de rearme", v.position.distance_to(Vector3(-12.0, 0.525, 109.0)) < 0.001,
		str(v.position))

	for i in 240:
		v.step(1.0 / 120.0, 1.0, 0.0, false, false)
	check("acelera con el pedal", v.speed > 5.0, str(v.speed))
	check("avanza en el sentido del morro", v.position.z > 109.5, str(v.position.z))
	check("telemetría en km/h", v.kmh() > 18.0, str(v.kmh()))
	near("km/h = m/s · 3,6", v.kmh(), v.speed * 3.6, 0.001)

	var top := VehiclePhysics.new()
	for i in 120 * 40:
		top.step(1.0 / 120.0, 1.0, 0.0, false, false)
	check("no pasa de la punta", top.speed <= VehiclePhysics.TOP_SPEED + 0.5, str(top.speed))
	check("llega cerca de la punta", top.speed > 40.0, str(top.speed))

	var turbo := VehiclePhysics.new()
	for i in 120 * 3:
		turbo.step(1.0 / 120.0, 1.0, 0.0, false, true)
	check("el turbo consume energía", turbo.energy < 100.0, str(turbo.energy))
	check("el turbo se marca", turbo.boost)
	near("consumo 24/s", turbo.energy, 100.0 - 72.0, 1.0)
	for i in 120 * 5:
		turbo.step(1.0 / 120.0, 1.0, 0.0, false, true)
	near("energía agotada", turbo.energy, 0.0, 0.001)
	check("bloqueo tras agotar", turbo.cooldown > 0.0, str(turbo.cooldown))
	turbo.step(1.0 / 120.0, 1.0, 0.0, false, true)
	check("sin turbo durante el bloqueo", not turbo.boost)
	for i in 120 * 4:
		turbo.step(1.0 / 120.0, 0.0, 0.0, false, false)
	check("recarga 9/s tras el bloqueo", turbo.energy > 0.0, str(turbo.energy))

	var steering := VehiclePhysics.new()
	for i in 120:
		steering.step(1.0 / 120.0, 1.0, 1.0, false, false)
	check("el volante gira el rumbo", absf(steering.yaw) > 0.02, str(steering.yaw))
	check("la caída de dirección limita el ángulo", absf(steering.steer)
		< VehiclePhysics.STEER_LIMIT, str(steering.steer))

	var brake := VehiclePhysics.new()
	for i in 120 * 6:
		brake.step(1.0 / 120.0, 1.0, 0.0, false, false)
	var fast := brake.speed
	for i in 120 * 3:
		brake.step(1.0 / 120.0, 0.0, 0.0, true, false)
	check("el freno de mano reduce la velocidad", brake.speed < fast, "%f → %f" % [fast, brake.speed])
	check("frenada marcada", brake.braking)

	var reverse := VehiclePhysics.new()
	for i in 120 * 3:
		reverse.step(1.0 / 120.0, -1.0, 0.0, false, false)
	check("marcha atrás", reverse.speed < -0.5, str(reverse.speed))
	check("marcha R", reverse.gear == "R", reverse.gear)
	check("no pasa la marcha atrás", reverse.speed >= -VehiclePhysics.REVERSE_SPEED - 0.5,
		str(reverse.speed))

	var standstill := VehiclePhysics.new()
	for i in 120 * 2:
		standstill.step(1.0 / 120.0, 0.0, 0.0, false, false)
	near("no se mueve sin pedal", standstill.speed, 0.0, 0.001)

	# La cápsula conduce el carro: la posición del jugador sale del coche.
	var t := fresh()
	t.physics.reset(-12.0, 109.0, 0.0)
	var drive := t.use(&"railCar", Vector3(-12.0, 1.7, 109.0))
	check("toma el mando del carro", t.driving, str(drive))
	check("mensaje de mando", str(drive.get("message", "")).contains("Carro"), str(drive))
	var cabin := t.step(0.5, Vector3(-12.0, 1.7, 109.0), true, 0.0, 0.0)
	check("cámara en el puesto de conducción", cabin.y > 1.0 and cabin.z > 108.0, str(cabin))
	t.physics.speed = 6.0
	var off := t.use(&"railStand", cabin)
	check("no se baja en marcha", str(off.get("message", "")).contains("Frena"), str(off))
	t.physics.speed = 0.0
	t.step(0.02, cabin, true, 0.0, 0.0)
	var exit := t.use(&"railStand", cabin)
	check("baja con el coche parado", not t.driving, str(exit))
	var exit_position: Vector3 = exit.get("position", Vector3.ZERO)
	check("punto de salida caminable", t.can_stand(exit_position.x, exit_position.z),
		str(exit_position))


# --------------------------------------------------------------------------- #
func _persistence() -> void:
	print("\n[persistencia]")
	var t := fresh()
	t.use(&"railSeat1", Vector3.ZERO)
	t.use(&"railCallB", Vector3.ZERO)
	t.step(0.4, Vector3.ZERO, true, 0.0, 0.0)
	t.physics.energy = 42.0
	t.physics.integrity = 71.0
	var blob := t.to_dict()
	check("guarda el andén", blob.has("at"))
	check("guarda el carro", blob.has("car"))
	check("guarda el vehículo", blob.has("vehicle"))

	var other := fresh()
	check("restaura", other.from_dict(blob))
	near("andén restaurado", other.at, t.at)
	near("destino restaurado", other.target, t.target)
	near("puertas restauradas", other.door, t.door)
	check("asiento restaurado", other.seat == 1, str(other.seat))
	near("energía restaurada", other.physics.energy, 42.0)
	near("integridad restaurada", other.physics.integrity, 71.0)
	check("carro restaurado", other.car_position() == t.car_position(), str(other.car_position()))
	check("diccionario vacío no rompe", not fresh().from_dict({}))

	# Integración con GameState: registro diferido y guardado en partida.
	var state := GameState.new()
	state.power_simulation = false
	state.transit = null
	var module := fresh()
	state.register_transit(module)
	check("registro de la cápsula", state.transit == module)
	check("instantánea disponible", state.transit_snapshot().has("at"))
	var empty_state := GameState.new()
	empty_state.power_simulation = false
	check("sin cápsula la instantánea está vacía", empty_state.transit_snapshot().is_empty())
