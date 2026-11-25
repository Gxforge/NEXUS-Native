class_name CockpitDisplay
extends Node3D
## Panel de instrumentos del coche de vía (port de `Cockpit.ts`).
##
## La web pinta un lienzo de 384 × 144 y lo pega en un plano de 0,39 × 0,145 m
## en `(0,38; 0,966; 0,545)` girado 180° para que lo lea el conductor. Aquí el
## lienzo se reproduce con las mismas medidas **en el espacio** (1 px del lienzo
## = 1 mm del plano) para no depender de una textura de render: un `QuadMesh`
## oscuro y encima los rótulos como `Label3D` con `pixel_size = 0,001`.
##
## | Texto | Contenido |
## | --- | --- |
## | cabecera | `GT / 14     AXIAL DRIVE` |
## | velocidad | tres cifras con ceros a la izquierda y `km/h` |
## | marcha | `GEAR N` |
## | régimen | `850 RPM` |
## | energía | `E 100%` y barra de `energía · 3,55` px de ancho |

const WIDTH := 384
const HEIGHT := 144
const FACE_SIZE := Vector2(0.39, 0.145)
## El salpicadero exportado trae su propia placa a 0,545 m y el volante queda
## delante: el panel se sube a 1,03 m, se adelanta a 0,47 m y se inclina 12°
## hacia el conductor para que se lea entero.
const FACE_POSITION := Vector3(0.38, 1.03, 0.47)
const FACE_TILT := -0.21
## 1 px del lienzo en metros del plano.
const PIXEL := 0.001
const BAR_ORIGIN := Vector2(12.0, 126.0)
const BAR_SCALE := 3.55
## Todos los rótulos comparten el mismo tamaño de fuente (96 px) y el tamaño del
## lienzo se recupera con `pixel_size`: con tamaños distintos, `Label3D` comparte
## el atlas y las muestras se mezclan entre líneas.
const FONT_SIZE := 96
const BAR_HEIGHT := 6.0
const INK := Color("#0a1d2a")
const CYAN := Color("#70d3e6")
const WHITE := Color("#e7f3ec")
const BAR := Color("#6cd9ff")

var face: MeshInstance3D
var bar: MeshInstance3D
## Marco del panel: girado 180° para que lo lea el conductor, como en la web.
var screen: Node3D
## Última clave pintada (`velocidad:marcha:energía:régimen`): la web no repinta
## si no cambia, y aquí se cuenta igual.
var key := ""
var paints := 0

var _labels := {}


func _ready() -> void:
	build()
	paint(0, "N", 100, 850)


## Monta el lienzo y los rótulos.
func build() -> void:
	if face != null:
		return
	screen = Node3D.new()
	screen.name = "Screen"
	screen.position = FACE_POSITION
	screen.rotation = Vector3(FACE_TILT, PI, 0.0)
	add_child(screen)
	face = MeshInstance3D.new()
	face.name = "CockpitFace"
	var quad := QuadMesh.new()
	quad.size = FACE_SIZE
	face.mesh = quad
	face.material_override = _ink_material()
	screen.add_child(face)

	bar = MeshInstance3D.new()
	bar.name = "ChargeBar"
	var bar_quad := QuadMesh.new()
	bar_quad.size = Vector2(100.0 * BAR_SCALE * PIXEL, BAR_HEIGHT * PIXEL)
	bar.mesh = bar_quad
	bar.material_override = _flat(BAR)
	bar.position = _local(BAR_ORIGIN.x, BAR_ORIGIN.y + BAR_HEIGHT * 0.5, 0.002)
	screen.add_child(bar)
	_position_bar()

	_label("Title", "GT / 14     AXIAL DRIVE", 13, 6, 21, CYAN)
	_label("Speed", "000", 12, 32, 54, WHITE)
	_label("Unit", "km/h", 115, 58, 20, WHITE)
	_label("Gear", "GEAR N", 250, 52, 20, WHITE)
	_label("Rpm", "850 RPM", 14, 92, 20, WHITE)
	_label("Charge", "E 100%", 251, 92, 20, WHITE)


## Pinta el panel; sólo reescribe si cambia algo, como `Cockpit.paint`.
func paint(speed: int, gear: String, charge: int, rpm: int) -> bool:
	if face == null:
		build()
	var next := "%d:%s:%d:%d" % [speed, gear, charge, rpm]
	if next == key:
		return false
	key = next
	paints += 1
	_write("Speed", str(speed).pad_zeros(3))
	_write("Gear", "GEAR " + gear)
	_write("Rpm", "%d RPM" % rpm)
	_write("Charge", "E %d%%" % charge)
	_position_bar(charge)
	return true


## Copia la telemetría del coche, con el redondeo de la web.
func sync(physics: VehiclePhysics) -> void:
	if physics == null:
		return
	paint(int(round(absf(physics.speed) * 3.6)), physics.gear, int(round(physics.energy)),
		int(round(physics.rpm / 100.0)) * 100)


## Texto del rótulo `name` (para pruebas y capturas).
func text_of(name: String) -> String:
	var label := _labels.get(name) as Label3D
	return label.text if label != null else ""


func bar_width() -> float:
	var quad := bar.mesh as QuadMesh if bar != null else null
	return quad.size.x if quad != null else 0.0


func _write(name: String, text: String) -> void:
	var label := _labels.get(name) as Label3D
	if label != null:
		label.text = text


## La barra de energía crece desde su origen, como `fillRect(12, 126, carga·3,55, 6)`.
func _position_bar(charge := 100) -> void:
	if bar == null:
		return
	var quad := bar.mesh as QuadMesh
	var width := float(charge) * BAR_SCALE * PIXEL
	quad.size = Vector2(width, BAR_HEIGHT * PIXEL)
	bar.position = _local(BAR_ORIGIN.x + float(charge) * BAR_SCALE * 0.5,
		BAR_ORIGIN.y + BAR_HEIGHT * 0.5, 0.002)


## Coordenada del lienzo (origen arriba a la izquierda) en el plano local.
func _local(x: float, y: float, z: float) -> Vector3:
	return Vector3(-FACE_SIZE.x * 0.5 + x * PIXEL, FACE_SIZE.y * 0.5 - y * PIXEL, z)


func _label(name: String, text: String, x: float, y: float, size: int, color: Color) -> Label3D:
	var label := Label3D.new()
	label.name = name
	label.text = text
	label.font = _own_font()
	label.font_size = FONT_SIZE
	label.pixel_size = float(size) * PIXEL / float(FONT_SIZE)
	label.modulate = color
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	label.double_sided = false
	label.no_depth_test = false
	label.shaded = false
	label.position = _local(x, y, 0.003)
	screen.add_child(label)
	_labels[name] = label
	return label


## Cada rótulo lleva su propia instancia de fuente: el atlas compartido de
## `Label3D` mezcla muestras entre líneas cuando hay varios textos pequeños.
func _own_font() -> FontVariation:
	var variation := FontVariation.new()
	variation.base_font = ThemeDB.fallback_font
	return variation


func _ink_material() -> StandardMaterial3D:
	return _flat(INK)


func _flat(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material
