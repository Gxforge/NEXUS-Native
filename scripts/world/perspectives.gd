class_name Perspectives
extends RefCounted
## Cámaras del operador y del coche (port de `src/vehicle/Perspectives.ts`).
##
## La web separa la **cámara de render** del ojo de juego: V y C sólo mueven la
## vista, nunca el cuerpo ni la colisión. Aquí se reproduce igual, con las mismas
## medidas y la misma mezcla:
##
## | Modo | A pie | En el coche |
## | --- | --- | --- |
## | 0 | primera persona (sin tocar la cámara) | cabina: `(0,38; 1,055; −0,24)` mirando a `(0,38; 1,09; 9)` |
## | 1 | al hombro, `2,9 m` hacia delante | persecución trasera a `distancia` |
## | 2 | órbita a `0,72·distancia` por detrás | órbita delantera con la mirada |
##
## La distancia de la rueda va de 2,2 a 9 m, el acercamiento se amortigua con
## `e^(−12·Δt)` y un rayo desde el objetivo hacia la cámara acorta la toma para no
## atravesar paredes (`0,12` de mínimo y `0,17` de margen), como `contacts.first`.

const ZOOM_MIN := 2.2
const ZOOM_MAX := 9.0
const DISTANCE := 4.8
const HEIGHT := 1.85
const BLEND_RATE := 5.0
const DAMP := 12.0
const COLLISION_MARGIN := 0.17
const COLLISION_MIN := 0.12
const SHOULDER := 2.9
const FOOT_ORBIT := 0.72
const FOOT_DROP := 0.32
const SIDE_SAMPLES: Array[float] = [0.0, -0.12, 0.12]
## Punto de la cabina en coordenadas del coche (`Transit.step`).
const COCKPIT := Vector3(0.38, 1.055, -0.24)
const COCKPIT_AIM := Vector3(0.38, 1.09, 9.0)
const CAR_PIVOT := Vector3(0.0, 0.66, 0.23)

var foot := 0
var car_mode := 0
var distance := DISTANCE
var height := HEIGHT
var blend := 1.0
var key := ""
var enabled := false

var _last := Vector3.ZERO
var _previous := Vector3.ZERO
var _has_last := false


## Modo activo: el del coche si se conduce y el de a pie si no.
func mode(driving: bool) -> int:
	return car_mode if driving else foot


func cycle_foot() -> int:
	foot = (foot + 1) % 3
	return foot


func cycle_car() -> int:
	car_mode = (car_mode + 1) % 3
	return car_mode


## Rueda del ratón: `amount` positivo acerca (contrato de la web).
func zoom(amount: float) -> float:
	distance = clampf(distance + amount * 0.4, ZOOM_MIN, ZOOM_MAX)
	return distance


func reset() -> void:
	foot = 0
	car_mode = 0
	distance = DISTANCE
	height = HEIGHT
	blend = 1.0
	key = ""
	enabled = false
	_last = Vector3.ZERO
	_previous = Vector3.ZERO
	_has_last = false


## Posición, objetivo y «arriba» de la cámara para este instante (función pura
## salvo la amortiguación y la mezcla, que avanzan con `delta`).
func solve(body: Vector3, car: Transform3D, driving: bool, yaw: float, pitch: float,
		delta: float) -> Dictionary:
	var active := mode(driving)
	enabled = active != 0
	var next_key := ("c" if driving else "p") + str(active)
	var change := next_key != key
	if change:
		_previous = _last
		blend = 0.0 if key != "" else 1.0
		key = next_key
	blend = minf(1.0, blend + maxf(delta, 0.0) * BLEND_RATE)
	var at := body
	var aim := body
	var up := Vector3.UP
	if driving:
		at = car * COCKPIT
		aim = car * COCKPIT_AIM
		if active == 0:
			up = car.basis.y.normalized()
		else:
			aim = car * CAR_PIVOT
			var direction := Vector3(0.0, 0.0, -1.0) if active == 1 \
				else Vector3(sin(yaw - PI), 0.0, -cos(yaw - PI))
			direction = car.basis * direction
			direction.y = 0.0
			if direction.length() > 0.001:
				direction = direction.normalized()
			at = aim + direction * distance
			at.y = aim.y + maxf(0.35, height + (pitch * 3.0 if active == 2 else 0.0))
	else:
		if active != 0:
			aim.y -= FOOT_DROP
			var direction := Vector3(sin(yaw), 0.0, -cos(yaw))
			at = aim + direction * (SHOULDER if active == 1 else -distance * FOOT_ORBIT)
			at.y += 0.55 + (-0.8 * pitch if active == 2 else 0.0)
	if active != 0 and not change and _has_last:
		var weight := exp(-maxf(delta, 0.0) * DAMP)
		at = at.lerp(_last, weight)
	if enabled:
		# La amortiguación se apoya en la última toma resuelta; `apply` la
		# reescribe al final con la posición ya acortada por contactos.
		_last = at
		_has_last = true
	return {
		"position": at,
		"aim": aim,
		"up": up,
		"mode": active,
		"enabled": enabled,
		"blend": blend,
		"previous": _previous,
		"changed": change,
	}


## Coloca la cámara. `hit` es `Callable(origen, destino) -> float` (distancia del
## primer impacto, o −1 si no hay); se lanza tres veces, como la web.
func apply(camera: Camera3D, body: Vector3, car: Transform3D, driving: bool, yaw: float,
		pitch: float, hit: Callable, delta: float) -> bool:
	if camera == null:
		return false
	var solved := solve(body, car, driving, yaw, pitch, delta)
	if not bool(solved["enabled"]):
		_last = camera.global_position
		_has_last = true
		return false
	var aim: Vector3 = solved["aim"]
	var at: Vector3 = solved["position"]
	var offset := at - aim
	var length := offset.length()
	if length > 0.001 and hit.is_valid():
		for side in SIDE_SAMPLES:
			var origin := aim + Vector3(side, 0.0, 0.0)
			var candidate := origin + offset
			var found: float = hit.call(origin, candidate)
			if found >= 0.0:
				length = minf(length, maxf(COLLISION_MIN, found - COLLISION_MARGIN))
		if length > 0.001:
			at = aim + offset.normalized() * length
	var previous: Vector3 = solved["previous"]
	if float(solved["blend"]) < 1.0 and not bool(solved["changed"]):
		var weight := 1.0 - smoothstep(0.0, 1.0, float(solved["blend"]))
		var proposed := camera.global_position.lerp(previous, weight)
		var blocked := -1.0
		if hit.is_valid():
			blocked = hit.call(camera.global_position, proposed)
		if blocked < 0.0:
			at = proposed
	camera.top_level = true
	var up: Vector3 = solved["up"]
	var forward := aim - at
	if forward.length() > 0.001:
		# `Camera3D` no tiene «arriba» propio: se construye la base mirando al
		# objetivo con el arriba del coche, como el `cam.up` de la web.
		if absf(forward.normalized().dot(up.normalized())) > 0.995:
			up = Vector3.FORWARD
		camera.global_transform = Transform3D(Basis.looking_at(forward.normalized(), up.normalized()), at)
	else:
		camera.global_position = at
	_last = at
	return true


## Última posición colocada (para pruebas y capturas).
func last_position() -> Vector3:
	return _last
