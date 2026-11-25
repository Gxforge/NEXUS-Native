class_name W01Breath
extends Node
## Respiración y zumbido de máquina (port de `Breath.ts`).
##
## La web no carga ningún sonido: sintetiza el aire con ruido filtrado y el
## zumbido eléctrico con un triángulo. Aquí se hace lo mismo con dos
## `AudioStreamPlayer` y dos buses propios:
##
## * **aire** — ruido con el mismo filtro de un polo (`0,76·pink + 0,24·random`)
##   y un paso banda cuya frecuencia salta entre 920 y 540 Hz según la fase de la
##   respiración (`AudioEffectBandPassFilter` con el mismo Q de 0,64).
## * **máquina** — triángulo a 88 Hz que sube con la carga de la red (hasta
##   120 Hz con la carga al 100 %). Se sintetiza un bucle de 100 ciclos exactos y
##   la frecuencia se cambia con `pitch_scale`, que es equivalente a
##   `rotor.frequency` de la web.
##
## Donde `AudioParam.setTargetAtTime(v, t, τ)` existe en WebAudio, aquí se usa una
## interpolación exponencial con la misma constante de tiempo.

const AIR_BUS := "NEXUS Aire"
const HUM_BUS := "NEXUS Zumbido"
## Fase: `1,65 + fatiga · 2,9` radianes por segundo.
const BREATH_RATE := 1.65
const BREATH_FATIGUE_RATE := 2.9
## Resonancia del paso banda: el parámetro de Godot es lineal (0–1) y `Q = 0,64`
## de WebAudio es una banda muy ancha, así que se usa el mismo 0,64.
const BAND_RESONANCE := 0.64
## Ganancias y constantes de la web.
const AIR_BASE := 0.14
const AIR_PUFF := 0.56
const AIR_TAU := 0.08
const CUTOFF_TAU := 0.09
const HUM_BASE := 0.05
const HUM_LOAD := 0.055
const HUM_TAU := 0.13
const ROTOR_TAU := 0.25
const ROTOR_BASE := 88.0
const ROTOR_LOAD := 32.0
const CUTOFF_IN := 920.0
const CUTOFF_OUT := 540.0
## Tomas de la red en `Power.ts` (x de cada acometida, z del pasillo).
const FEED_X: Array[float] = [19.85, 22.7, 25.55, 28.4]
const FEED_Z := 67.4
## Ruido: `pink = 0,76·pink + 0,24·(2·random − 1)`.
const NOISE_KEEP := 0.76
const NOISE_FEED := 0.24
const NOISE_SECONDS := 2.0
const NOISE_RATE := 22050
## Un ciclo de 88 Hz a 8.800 Hz son 100 muestras exactas: el bucle no chasquea.
const ROTOR_RATE := 8800
const ROTOR_CYCLES := 100

var phase := 0.0
var air_gain := 0.0
var air_cutoff := CUTOFF_OUT
var hum_gain := 0.0
var hum_hz := ROTOR_BASE
## Si es `false` no suena nada (menú, QA de audio desactivada).
var active := false

var _air: AudioStreamPlayer
var _hum: AudioStreamPlayer
var _filter: AudioEffectBandPassFilter


func _ready() -> void:
	_ensure_buses()
	_air = AudioStreamPlayer.new()
	_air.name = "Air"
	_air.bus = AIR_BUS
	_air.stream = noise_stream()
	_air.volume_db = -80.0
	add_child(_air)
	_air.play()
	_hum = AudioStreamPlayer.new()
	_hum.name = "Rotor"
	_hum.bus = HUM_BUS
	_hum.stream = rotor_stream()
	_hum.volume_db = -80.0
	add_child(_hum)
	_hum.play()


## Aire: ruido de dos segundos con el filtro de un polo de la web.
static func noise_stream() -> AudioStreamWAV:
	var rate := NOISE_RATE
	var count := int(float(rate) * NOISE_SECONDS)
	var data := PackedByteArray()
	data.resize(count * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 0x5EED
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
		var value := int(clampf(samples[index] * scale, -1.0, 1.0) * 32767.0)
		data.encode_s16(index * 2, value)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.stereo = false
	stream.data = data
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = count
	return stream


## Zumbido: `ROTOR_CYCLES` ciclos exactos de triángulo a 88 Hz.
static func rotor_stream() -> AudioStreamWAV:
	var period := ROTOR_RATE / int(ROTOR_BASE)
	var count := period * ROTOR_CYCLES
	var data := PackedByteArray()
	data.resize(count * 2)
	for index in count:
		var t := float(index % period) / float(period)
		var triangle := 4.0 * absf(t - 0.5) - 1.0
		data.encode_s16(index * 2, int(triangle * 0.34 * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = ROTOR_RATE
	stream.stereo = false
	stream.data = data
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = count
	return stream


## Crea los dos buses con su paso banda si no existen todavía.
func _ensure_buses() -> void:
	for bus_name in [AIR_BUS, HUM_BUS]:
		if AudioServer.get_bus_index(bus_name) == -1:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus_name)
			AudioServer.set_bus_send(AudioServer.get_bus_index(bus_name), "Master")
	var air_index := AudioServer.get_bus_index(AIR_BUS)
	if AudioServer.get_bus_effect_count(air_index) == 0:
		_filter = AudioEffectBandPassFilter.new()
		_filter.cutoff_hz = CUTOFF_OUT
		_filter.resonance = BAND_RESONANCE
		AudioServer.add_bus_effect(air_index, _filter)
	else:
		_filter = AudioServer.get_bus_effect(air_index, 0) as AudioEffectBandPassFilter


## Aire de la respiración. `fatigue` es 0 en tercera persona y `1 − stamina/100`
## en primera, como en `SceneExperience.ts`.
func update(delta: float, fatigue: float) -> void:
	phase += delta * (BREATH_RATE + fatigue * BREATH_FATIGUE_RATE)
	var wave := sin(phase)
	var target := (AIR_BASE + maxf(0.0, -wave) * AIR_PUFF) * fatigue * absf(wave)
	air_gain = _approach(air_gain, target, delta, AIR_TAU)
	air_cutoff = _approach(air_cutoff, CUTOFF_IN if wave > 0.0 else CUTOFF_OUT, delta, CUTOFF_TAU)
	_apply()


## Zumbido de la red: `near` es la cercanía a la acometida (0–1) y `load` la carga
## entregada sobre 112.
func machine(near: float, load: float) -> void:
	hum_gain = _approach(hum_gain, near * (HUM_BASE + HUM_LOAD * load), _last_delta, HUM_TAU)
	hum_hz = _approach(hum_hz, ROTOR_BASE + load * ROTOR_LOAD, _last_delta, ROTOR_TAU)
	_apply()


## Silencio de menú: apaga las dos voces sin desmontar el sistema.
func quiet() -> void:
	hum_gain = 0.0
	air_gain = 0.0
	_apply()


## Cercanía a las cuatro acometidas de `Power.ts`; devuelve 0–1.
static func feeds_near(position: Vector3) -> float:
	var best := 0.0
	for index in FEED_X.size():
		if index < _feed_on.size() and not _feed_on[index]:
			continue
		var dx := position.x - FEED_X[index]
		var dz := position.z - FEED_Z
		best = maxf(best, 1.0 / (1.0 + 0.17 * (dx * dx + dz * dz)))
	return best


## Acometidas encendidas, para que una toma caída no zumbe.
static var _feed_on: Array[bool] = [true, true, true, true]


## `1 − stamina/100`, la fatiga que usa la web en primera persona.
static func fatigue_for(stamina: float) -> float:
	return clampf(1.0 - stamina / 100.0, 0.0, 1.0)


func set_feed(index: int, on: bool) -> void:
	while _feed_on.size() <= index:
		_feed_on.append(true)
	_feed_on[index] = on


var _last_delta := 0.016


func _process(delta: float) -> void:
	_last_delta = maxf(delta, 0.001)


## `setTargetAtTime(v, t, τ)`: acercarse a `target` con constante de tiempo `tau`.
static func _approach(current: float, target: float, delta: float, tau: float) -> float:
	if delta <= 0.0:
		return target
	if tau <= 0.0:
		return target
	return lerpf(current, target, 1.0 - exp(-delta / tau))


func _apply() -> void:
	if _air != null:
		_air.volume_db = linear_to_db(maxf(air_gain, 0.00001)) if active else -80.0
	if _hum != null:
		_hum.volume_db = linear_to_db(maxf(hum_gain, 0.00001)) if active else -80.0
		_hum.pitch_scale = hum_hz / ROTOR_BASE
	var air_index := AudioServer.get_bus_index(AIR_BUS)
	if _filter != null and air_index != -1:
		_filter.cutoff_hz = clampf(air_cutoff, 20.0, 20000.0)


func bus_filter() -> AudioEffectBandPassFilter:
	return _filter
