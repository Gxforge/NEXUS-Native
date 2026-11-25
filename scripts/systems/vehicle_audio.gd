class_name VehicleAudio
extends Node
## Sonido del coche de vía (port de `VehicleAudio.ts`).
##
## La web sintetiza el motor con tres osciladores y el ruido de rodadura con
## ruido blanco filtrado, todo con `AudioContext`:
##
## | Voz | Onda | Frecuencia | Ganancia |
## | --- | --- | --- | --- |
## | motor | sierra | `30 + rpm/63` | `0,008 + 0,012·\|gas\|` |
## | rodadura | triángulo | `240 + \|v\|·18` | `0,035·min(1, deslizamiento + frenada)` |
## | turbo | seno | `240 + energía·4` | `0,032` con turbo |
##
## y el ruido pasa por un paso bajo a `240 + \|v\|·20 + 2700·impacto` con una
## ganancia de `0,003 + \|v\|·0,0009 + impacto·0,15`.
##
## Igual que `W01Breath`, cada voz es un bucle de un periodo exacto y la
## frecuencia se cambia con `pitch_scale`; las constantes de tiempo de
## `setTargetAtTime` se reproducen con interpolación exponencial.

const BUS := "NEXUS Rodadura"
const RATE := 22050
const TAU := 0.06
const FILTER_TAU := 0.04
const RUMBLE_TAU := 0.05
## Bases de las tres voces y del ruido (Hz).
const ENGINE_BASE := 30.0
const ROLL_BASE := 240.0
const TURBO_BASE := 240.0
const NOISE_SECONDS := 2.0
const NOISE_KEEP := 0.76
const NOISE_FEED := 0.24

## Frecuencias y ganancias actuales (para pruebas y telemetría).
var engine_hz := ENGINE_BASE
var engine_gain := 0.0
var roll_hz := ROLL_BASE
var roll_gain := 0.0
var turbo_hz := TURBO_BASE
var turbo_gain := 0.0
var filter_hz := ROLL_BASE
var rumble_gain := 0.0
## Si es `false` no suena nada (el coche está parado y el operador a pie).
var active := false

var _engine: AudioStreamPlayer
var _roll: AudioStreamPlayer
var _turbo: AudioStreamPlayer
var _rumble: AudioStreamPlayer
var _filter: AudioEffectLowPassFilter
var _last_delta := 0.016


func _ready() -> void:
	_ensure_bus()
	_engine = _voice("Engine", BUS, saw_stream(ENGINE_BASE), -80.0)
	_roll = _voice("Roll", BUS, triangle_stream(ROLL_BASE), -80.0)
	_turbo = _voice("Turbo", BUS, sine_stream(TURBO_BASE), -80.0)
	_rumble = _voice("Rumble", BUS, noise_stream(), -80.0)


## Enciende las voces cuando el operador se sienta al volante.
func launch(on: bool) -> void:
	active = on
	_apply()


## Silencio sin desmontar el sistema.
func quiet() -> void:
	active = false
	engine_gain = 0.0
	roll_gain = 0.0
	turbo_gain = 0.0
	rumble_gain = 0.0
	_apply()


## Siguiente estado del sonido para la física del coche (`VehicleAudio.update`).
func update(physics: VehiclePhysics, on := true) -> void:
	if physics == null:
		return
	active = on
	var delta := _last_delta
	var speed := absf(physics.speed)
	engine_hz = ENGINE_BASE + physics.rpm / 63.0
	roll_hz = ROLL_BASE + speed * 18.0
	turbo_hz = TURBO_BASE + physics.energy * 4.0
	var braking := minf(0.5, speed / 50.0) if physics.braking else 0.0
	var slide := minf(1.0, physics.slip + braking)
	engine_gain = _approach(engine_gain, (0.008 + 0.012 * absf(physics.throttle)) if on else 0.0, delta, TAU)
	roll_gain = _approach(roll_gain, (0.035 * slide) if on else 0.0, delta, TAU)
	turbo_gain = _approach(turbo_gain, 0.032 if (on and physics.boost) else 0.0, delta, TAU)
	filter_hz = _approach(filter_hz, ROLL_BASE + speed * 20.0 + 2700.0 * physics.impact,
		delta, FILTER_TAU)
	rumble_gain = _approach(rumble_gain,
		(0.003 + speed * 0.0009 + physics.impact * 0.15) if on else 0.0, delta, RUMBLE_TAU)
	_apply()


func _process(delta: float) -> void:
	_last_delta = maxf(delta, 0.001)


## `1 − e^(−Δ/τ)`, la constante de tiempo de `setTargetAtTime`.
static func _approach(current: float, target: float, delta: float, tau: float) -> float:
	if delta <= 0.0 or tau <= 0.0:
		return target
	return lerpf(current, target, 1.0 - exp(-delta / tau))


func _apply() -> void:
	if _engine != null:
		_engine.volume_db = _db(engine_gain)
		_engine.pitch_scale = clampf(engine_hz / ENGINE_BASE, 0.05, 16.0)
	if _roll != null:
		_roll.volume_db = _db(roll_gain)
		_roll.pitch_scale = clampf(roll_hz / ROLL_BASE, 0.05, 16.0)
	if _turbo != null:
		_turbo.volume_db = _db(turbo_gain)
		_turbo.pitch_scale = clampf(turbo_hz / TURBO_BASE, 0.05, 16.0)
	if _rumble != null:
		_rumble.volume_db = _db(rumble_gain)
	if _filter != null:
		_filter.cutoff_hz = clampf(filter_hz, 40.0, 20000.0)


func _db(gain: float) -> float:
	return linear_to_db(maxf(gain, 0.00001)) if active else -80.0


# --------------------------------------------------------------------------- #
# síntesis
# --------------------------------------------------------------------------- #
## Sierra de un periodo a `hz`.
static func saw_stream(hz: float) -> AudioStreamWAV:
	var period := maxi(2, int(round(float(RATE) / hz)))
	var data := PackedByteArray()
	data.resize(period * 2)
	for index in period:
		var t := float(index) / float(period)
		data.encode_s16(index * 2, int((2.0 * t - 1.0) * 0.55 * 32767.0))
	return _loop(data, period)


## Triángulo de un periodo a `hz`.
static func triangle_stream(hz: float) -> AudioStreamWAV:
	var period := maxi(2, int(round(float(RATE) / hz)))
	var data := PackedByteArray()
	data.resize(period * 2)
	for index in period:
		var t := float(index) / float(period)
		var value := 4.0 * absf(t - 0.5) - 1.0
		data.encode_s16(index * 2, int(value * 0.5 * 32767.0))
	return _loop(data, period)


## Seno de un periodo a `hz`.
static func sine_stream(hz: float) -> AudioStreamWAV:
	var period := maxi(2, int(round(float(RATE) / hz)))
	var data := PackedByteArray()
	data.resize(period * 2)
	for index in period:
		var value := sin(TAU * float(index) / float(period))
		data.encode_s16(index * 2, int(value * 0.5 * 32767.0))
	return _loop(data, period)


## Ruido con el filtro de un polo de la web (`0,76·pink + 0,24·aleatorio`).
static func noise_stream() -> AudioStreamWAV:
	var count := int(float(RATE) * NOISE_SECONDS)
	var data := PackedByteArray()
	data.resize(count * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 0xCAB5
	var pink := 0.0
	var peak := 0.0
	var samples := PackedFloat32Array()
	samples.resize(count)
	for index in count:
		pink = NOISE_KEEP * pink + NOISE_FEED * (2.0 * rng.randf() - 1.0)
		samples[index] = pink
		peak = maxf(peak, absf(pink))
	var scale := 0.72 / maxf(peak, 0.0001)
	for index in count:
		data.encode_s16(index * 2, int(clampf(samples[index] * scale, -1.0, 1.0) * 32767.0))
	return _loop(data, count)


static func _loop(data: PackedByteArray, count: int) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.stereo = false
	stream.data = data
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = count
	return stream


func _voice(name: String, bus: String, stream: AudioStreamWAV, db: float) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.name = name
	player.bus = bus
	player.stream = stream
	player.volume_db = db
	add_child(player)
	player.play()
	return player


## Bus con el paso bajo de la rodadura.
func _ensure_bus() -> void:
	if AudioServer.get_bus_index(BUS) == -1:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, BUS)
		AudioServer.set_bus_send(AudioServer.get_bus_index(BUS), "Master")
	var index := AudioServer.get_bus_index(BUS)
	if index == -1:
		return
	if AudioServer.get_bus_effect_count(index) == 0:
		_filter = AudioEffectLowPassFilter.new()
		_filter.cutoff_hz = ROLL_BASE
		AudioServer.add_bus_effect(index, _filter)
	else:
		_filter = AudioServer.get_bus_effect(index, 0) as AudioEffectLowPassFilter


func bus_filter() -> AudioEffectLowPassFilter:
	return _filter
