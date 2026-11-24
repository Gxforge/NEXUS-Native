class_name ZoneDressing
extends Node3D
## Mobiliario y rotulación de cada módulo, portado de la web.
##
## La web construye la nave en `Infrastructure.ts`, `Sectors.ts`, `Vault.ts`,
## `Workshop.ts` y `Operations.ts` con las primitivas de `BuildKit`. Este nodo
## reproduce esas piezas **dentro del volumen real de cada zona portada** (los
## `*_structural_shell.json`): vasos de observación de H–01, turbinas y puerta
## de la bóveda de B–02, armarios del cuadro eléctrico, muro de cámaras de
## Vigilancia, archivadores de D–02, malla de contención de C–04, arcos de la
## galería y vitrinas de la crioteca de V–03.
##
## Cada rama toma las medidas de la sala de `ROOMS` para que nada quede fuera de
## las paredes ni atravesando el techo.

@export var zone_id: StringName = &"c04"

var built_meshes := 0
var pods: Array[Node3D] = []
var fans: Array[Node3D] = []
var screens: Array[Node3D] = []
var specimens: Array[Node3D] = []
var bubbles: Array = []
var rings: Array[MeshInstance3D] = []
var indicators: Array[MeshInstance3D] = []

## Ciclo de animación del mobiliario (mismo contrato que `Pods.update` de la web).
var time := 0.0
var running := true

const W01_CORE := "res://assets/generated/w01_core.glb"
const W01_TENTACLES := "res://assets/generated/w01_tentacles.glb"

## Interiores reales de cada módulo: `x0, x1, z0, z1, altura`.
const ROOMS := {
	&"h01": [-27.0, 23.0, -82.0, -24.0, 9.4],
	&"b02": [9.0, 45.0, -24.0, 0.0, 9.4],
	&"c04": [-27.0, 45.0, 0.0, 84.0, 9.4],
	&"d02": [31.0, 46.0, -82.0, -24.0, 9.4],
	&"electrical": [26.3, 45.0, 58.2, 84.0, 9.4],
	&"surveillance": [-27.0, -8.3, 66.2, 84.0, 9.4],
	&"v03_gallery": [23.0, 31.0, -82.0, -24.0, 4.6],
	&"v03_cryo": [13.0, 45.0, -100.0, -82.0, 7.2],
	&"a01": [-27.0, 9.0, -24.0, 0.0, 9.4],
	&"transit_hub": [-27.0, 45.0, 84.0, 110.0, 9.4],
}


func _ready() -> void:
	build()
	set_process(not bubbles.is_empty() or not fans.is_empty() or not specimens.is_empty())


func build() -> void:
	name = "Dressing"
	match zone_id:
		&"h01":
			_build_h01()
		&"b02":
			_build_b02()
		&"electrical":
			_build_electrical()
		&"surveillance":
			_build_surveillance()
		&"d02":
			_build_d02()
		&"c04":
			_build_c04()
		&"v03_gallery":
			_build_gallery()
		&"v03_cryo":
			_build_cryo()
		&"a01":
			_build_a01()
		&"transit_hub", &"transit_road", &"transit_rail":
			_build_transit()
	built_meshes = count_meshes(self)


func _process(delta: float) -> void:
	if not running:
		return
	time += delta
	animate(time)


## Avanza la animación del mobiliario hasta el instante `t`.
func animate(t: float) -> void:
	# Burbujas del líquido de los vasos (`Workshop.ts`: 48 puntos por vaso).
	for index in bubbles.size():
		var group: Array = bubbles[index]
		for j in group.size():
			var bubble: Node3D = group[j]
			var speed: float = 0.1 + float(j % 3) * 0.023
			bubble.position.y = 0.92 + fmod(t * speed + float(j) * 0.149 + float(index) * 0.69, 2.75)
	# Latido de la larva en suspensión.
	for index in specimens.size():
		var specimen: Node3D = specimens[index]
		var a: float = t * 3.1 + float(index) * 1.62
		var pulse: float = pow(maxf(0.0, sin(a)), 5.0)
		specimen.scale = Vector3(0.42 * (1.0 + pulse * 0.12),
			0.42 * (1.0 - pulse * 0.065), 0.42 * (1.0 + pulse * 0.1))
		specimen.position.y = 2.25 + sin(a * 0.4) * 0.07
		specimen.rotation.y = 1.27 + sin(a * 0.23) * 0.23
	# Aspas de las turbinas; giran más despacio cuanto menor es el índice.
	for index in fans.size():
		var fan: Node3D = fans[index]
		fan.rotation.z = t * (1.35 + 0.12 * float(index))
	# Anillos de la malla de contención: respiración lenta.
	for index in rings.size():
		var ring := rings[index]
		var wave: float = 1.0 + sin(t * 1.6 - float(index) * 0.55) * 0.012
		ring.scale = Vector3(wave, 1.0, wave)
	# Testigos intermitentes.
	for index in indicators.size():
		var led := indicators[index]
		var blink: float = 0.45 + 0.55 * absf(sin(t * 1.9 + float(index) * 0.8))
		led.scale = Vector3.ONE * blink


func count_meshes(node: Node) -> int:
	var total := 1 if node is MeshInstance3D else 0
	for child in node.get_children():
		total += count_meshes(child)
	return total


## Rectángulo interior `[x0, x1, z0, z1]` de la zona (o un pasillo por defecto).
func room() -> Array:
	return ROOMS.get(zone_id, [-20.0, 20.0, -20.0, 20.0, 9.4])


func ceiling() -> float:
	return room()[4]


## Centro del rectángulo interior.
func center() -> Vector2:
	var r := room()
	return Vector2((r[0] + r[1]) * 0.5, (r[2] + r[3]) * 0.5)


# --------------------------------------------------------------------------- #
# Luces de techo repartidas por la sala (las `luminaire` de la web)
# --------------------------------------------------------------------------- #
func _ceiling_lights(tint: Color, spacing := 9.0, inset := 1.1) -> void:
	var r := room()
	var y: float = ceiling() - inset
	var along_x: bool = (r[1] - r[0]) >= (r[3] - r[2])
	var index := 0
	if along_x:
		var z: float = (r[2] + r[3]) * 0.5
		var x: float = r[0] + 5.0
		while x <= r[1] - 4.0:
			var lamp := BuildKit.luminaire(self, x, y, z, 3.2, tint)
			lamp.name = "Luminaire%d" % index
			index += 1
			x += spacing
	else:
		var x: float = (r[0] + r[1]) * 0.5
		var z: float = r[2] + 5.0
		while z <= r[3] - 4.0:
			var lamp := BuildKit.luminaire(self, x, y, z, 3.2, tint)
			lamp.name = "Luminaire%d" % index
			index += 1
			z += spacing


# --------------------------------------------------------------------------- #
# H–01 · hidráulica: los tres vasos de observación (`Pods` de `Workshop.ts`)
# --------------------------------------------------------------------------- #
func _build_h01() -> void:
	var metal := BuildKit.material(BuildKit.METAL)
	var graphite := BuildKit.material(BuildKit.GRAPHITE)
	var bronze := BuildKit.material(BuildKit.BRONZE)
	var body := Node3D.new()
	body.name = "Pods"
	add_child(body)
	for index in 3:
		var z: float = [-66.6, -62.0, -57.4][index]
		var pod := Node3D.new()
		pod.name = "Pod%d" % (index + 1)
		pod.position = Vector3(-5.5, 0.0, z)
		pod.set_meta("survey_id", "pod_%d" % index)
		body.add_child(pod)
		pods.append(pod)
		for y: float in [0.25, 0.71, 4.22]:
			BuildKit.drum(pod, graphite, 0.0, y, 0.0, 1.64, 0.36)
			BuildKit.ring(pod, bronze, 0.0, y + 0.13, 0.0, 1.61, 0.055, true)
		BuildKit.drum(pod, metal, 0.0, 0.53, 0.0, 1.44, 0.4)
		BuildKit.drum(pod, BuildKit.glass(), 0.0, 2.46, 0.0, 1.55, 3.17)
		BuildKit.drum(pod, BuildKit.liquid(), 0.0, 2.3, 0.0, 1.49, 2.88)
		BuildKit.ring(pod, BuildKit.emissive(BuildKit.GLOW, 1.4), 0.0, 3.74, 0.0, 1.46, 0.021, true)
		for k in 8:
			var a: float = k * PI / 4.0
			BuildKit.drum(pod, bronze, 1.47 * cos(a), 4.45, 1.47 * sin(a), 0.068, 0.13)
			if k % 2 == 1:
				BuildKit.drum(pod, metal, 1.56 * cos(a), 2.49, 1.56 * sin(a), 0.052, 3.16)
		# Larva en suspensión: el cuerpo de W–01 a escala de vaso.
		var creature := Node3D.new()
		creature.name = "Specimen"
		creature.position = Vector3(0.0, 2.2, 0.0)
		creature.rotation.y = 1.27
		creature.scale = Vector3(0.42, 0.42, 0.42)
		pod.add_child(creature)
		var core := (load(W01_CORE) as PackedScene).instantiate()
		core.name = "Core"
		creature.add_child(core)
		var tentacles := (load(W01_TENTACLES) as PackedScene).instantiate()
		tentacles.name = "Tentacles"
		creature.add_child(tentacles)
		specimens.append(creature)
		# Burbujas ascendentes del líquido (48 por vaso, como la web).
		var group: Array = []
		var bubble_material := BuildKit.emissive(Color(0.6, 0.81, 0.68), 0.35)
		for j in 48:
			var angle: float = float(j) * 2.399
			var radius: float = 0.78 + 0.54 * float(j % 7) / 7.0
			var bubble := BuildKit.bead(pod, bubble_material, cos(angle) * radius,
				0.92 + 2.74 * float(j) / 48.0, sin(angle) * radius, 0.021, 6)
			group.append(bubble)
		bubbles.append(group)
		# Boca de desagüe superior y manómetro.
		BuildKit.bar(pod, bronze, Vector3(0.0, 4.41, 0.0), Vector3(0.0, 4.87, 0.0), 0.117)
		BuildKit.bar(pod, bronze, Vector3(0.0, 4.87, 0.0), Vector3(-0.3, 5.12, 0.0), 0.117)
		BuildKit.bar(pod, bronze, Vector3(-0.3, 5.12, 0.0), Vector3(-2.36, 5.12, 0.0), 0.117)
		var gauge := Node3D.new()
		gauge.position = Vector3(1.64, 0.7, 0.0)
		gauge.rotation.y = PI * 0.5
		pod.add_child(gauge)
		BuildKit.drum(gauge, bronze, 0.0, 0.0, 0.045, 0.086, 0.15, true)
		BuildKit.block(gauge, graphite, 0.0, 0.0, 0.115, 0.49, 0.48, 0.11)
		BuildKit.drum(gauge, BuildKit.material(BuildKit.WHITE, 0.2, 0.3),
			0.0, 0.0, 0.242, 0.194, 0.03, true)
	# Bancos de bombas hidráulicas contra el muro oeste.
	for index in 4:
		var z: float = -74.0 + float(index) * 7.0
		var pump := Node3D.new()
		pump.name = "Pump%d" % (index + 1)
		pump.position = Vector3(-22.0, 0.0, z)
		add_child(pump)
		BuildKit.block(pump, metal, 0.0, 0.65, 0.0, 3.2, 1.3, 1.6)
		BuildKit.drum(pump, graphite, 0.0, 1.55, 0.0, 0.78, 1.7, true, 28)
		BuildKit.ring(pump, bronze, 0.0, 1.55, 0.86, 0.62, 0.06)
		BuildKit.bar(pump, metal, Vector3(0.0, 1.9, 0.0), Vector3(0.0, 3.4, 0.0), 0.24)
		indicators.append(BuildKit.block(pump, BuildKit.emissive(BuildKit.AMBER, 1.0),
			0.0, 1.02, 0.82, 0.5, 0.12, 0.05))
		BuildKit.luminaire(pump, 0.0, 4.4, 0.0, 2.2, BuildKit.WARM, false)
	BuildKit.plaque(self, "HIDRÁULICA", "H–01   /   VASOS DE OBSERVACIÓN", 9.0, 1.6,
		18.0, 6.6, -62.0, -PI * 0.5)
	_ceiling_lights(Color("#c3f4ec"))


# --------------------------------------------------------------------------- #
# B–02 · turbinas, armarios y puerta de la bóveda
# --------------------------------------------------------------------------- #
func _build_b02() -> void:
	var metal := BuildKit.material(BuildKit.METAL)
	var graphite := BuildKit.material(BuildKit.GRAPHITE)
	var bronze := BuildKit.material(BuildKit.BRONZE)
	var steel := BuildKit.material(BuildKit.STEEL, 0.5, 0.4)
	var machines := Node3D.new()
	machines.name = "Turbines"
	add_child(machines)
	for index in 4:
		var x: float = 16.0 + float(index) * 5.4
		var fan := Node3D.new()
		fan.name = "Turbine%d" % (index + 1)
		fan.position = Vector3(x, 3.1, -16.6)
		fan.set_meta("survey_id", "turbine_%d" % index)
		machines.add_child(fan)
		fans.append(fan)
		# Carcasa circular con aspas y buje, como el ventilador de la web.
		BuildKit.drum(fan, graphite, 0.0, 0.0, 0.0, 1.72, 0.62, true, 40)
		BuildKit.ring(fan, bronze, 0.0, 0.0, 0.34, 1.66, 0.07)
		BuildKit.ring(fan, metal, 0.0, 0.0, 0.36, 1.34, 0.05)
		for blade in 8:
			var angle: float = blade * TAU / 8.0
			var piece := BuildKit.block(fan, metal, 0.0, 0.0, 0.38, 0.9, 0.14, 0.05)
			piece.position = Vector3(cos(angle) * 0.72, sin(angle) * 0.72, 0.38)
			piece.rotation.z = angle
		BuildKit.drum(fan, bronze, 0.0, 0.0, 0.42, 0.28, 0.16, true)
		BuildKit.ring(fan, BuildKit.emissive(BuildKit.AMBER, 1.2), 0.0, 0.0, 0.46, 0.16, 0.02)
		# Banco de la turbina con sus rejillas de ventilación.
		BuildKit.block(machines, steel, x, 0.9, -16.0, 3.6, 1.8, 1.4)
		BuildKit.block(machines, graphite, x, 1.86, -16.0, 3.4, 0.14, 1.3)
		for vent in 4:
			BuildKit.block(machines, BuildKit.emissive(Color("#1b2a2e"), 1.0),
				x - 1.2 + vent * 0.8, 1.1, -15.28, 0.55, 0.5, 0.03)
		indicators.append(BuildKit.block(machines, BuildKit.emissive(BuildKit.GLOW, 1.2),
			x + 1.5, 1.45, -15.28, 0.14, 0.14, 0.05))
	# Armarios de servicio contra el muro este.
	for index in 3:
		BuildKit.cabinet(self, 42.6, -18.0 + float(index) * 2.4, -PI * 0.5, 1.6, 2.4, 0.8, 1,
			"Cabinet%d" % (index + 1))
	# Puerta circular de la bóveda en el muro sur, junto al vano de paso.
	_vault_door(Vector3(38.0, 2.4, -23.4), 2.2)
	BuildKit.plaque(self, "BÓVEDA", "V–03   /   ACCESO RESTRINGIDO", 5.4, 1.4,
		38.0, 7.0, -23.2, 0.0)
	BuildKit.plaque(self, "TURBINAS", "B–02   /   PLANTA DE TURBINAS", 8.0, 1.6,
		40.0, 7.2, -12.0, -PI * 0.5)
	_ceiling_lights(BuildKit.WARM)


## Puerta circular de la bóveda con pestillos, brazos y aros emisivos.
func _vault_door(center: Vector3, radius: float) -> Node3D:
	var metal := BuildKit.material(BuildKit.METAL)
	var graphite := BuildKit.material(BuildKit.GRAPHITE)
	var bronze := BuildKit.material(BuildKit.BRONZE)
	var door := Node3D.new()
	door.name = "VaultDoor"
	door.position = center
	add_child(door)
	BuildKit.block(door, graphite, 0.0, 0.0, -0.28, radius * 2.6, radius * 2.6, 0.5)
	BuildKit.drum(door, metal, 0.0, 0.0, 0.1, radius, 0.55, true, 48)
	BuildKit.ring(door, bronze, 0.0, 0.0, 0.42, radius * 0.92, 0.09)
	BuildKit.ring(door, BuildKit.emissive(BuildKit.AMBER, 1.15), 0.0, 0.0, 0.45,
		radius * 0.74, 0.035)
	BuildKit.ring(door, metal, 0.0, 0.0, 0.47, radius * 0.66, 0.11)
	BuildKit.ring(door, BuildKit.material(BuildKit.STEEL, 0.6, 0.36), 0.0, 0.0, 0.5,
		radius * 0.42, 0.12)
	BuildKit.drum(door, BuildKit.emissive(Color("#cfe9ee"), 1.4), 0.0, 0.0, 0.52,
		radius * 0.19, 0.06, true, 32)
	# Ocho pestillos radiales y sus brazos hidráulicos.
	for index in 8:
		var angle := index * TAU / 8.0
		var bolt := Node3D.new()
		bolt.name = "Bolt%d" % index
		bolt.position = Vector3(-cos(angle) * radius * 0.78, sin(angle) * radius * 0.78, 0.22)
		bolt.rotation.z = -angle + PI * 0.5
		door.add_child(bolt)
		BuildKit.block(bolt, bronze, 0.0, 0.0, 0.0, 0.3, radius * 0.34, 0.3)
		BuildKit.block(bolt, metal, 0.0, -radius * 0.22, 0.02, 0.18, radius * 0.16, 0.22)
	for arm in 3:
		var angle := arm * TAU / 3.0
		var grip := Node3D.new()
		grip.name = "Arm%d" % arm
		grip.position = Vector3(-radius * 0.95, 0.0, -0.1)
		grip.rotation.z = angle
		door.add_child(grip)
		BuildKit.drum(grip, metal, 0.0, 0.0, 0.0, 0.11, radius * 1.9, true, 16)
		BuildKit.drum(grip, bronze, 0.0, radius * 0.95, 0.0, 0.18, 0.36, false, 16)
	return door


# --------------------------------------------------------------------------- #
# Electricidad · armarios del cuadro con sus pantallas
# --------------------------------------------------------------------------- #
func _build_electrical() -> void:
	for index in 8:
		var z: float = 62.0 + float(index) * 2.3
		BuildKit.cabinet(self, 43.4, z, -PI * 0.5, 1.9, 2.6, 1.0, 2,
			"Cabinet%d" % (index + 1))
		if index % 2 == 0:
			var screen := WallScreen.new()
			screen.kind = "phosphor"
			screen.screen_size = Vector2(0.62, 0.31)
			screen.position = Vector3(42.86, 1.55, z - 0.4)
			screen.rotation.y = -PI * 0.5
			add_child(screen)
			screens.append(screen)
			screen.push_phosphor("E–%02d" % (index + 1), "%d kW" % (6 + index),
				"derivación este", 0.35 + index * 0.06)
	BuildKit.cabinet(self, 40.0, 82.4, PI, 3.0, 2.6, 1.1, 3, "Switchboard")
	BuildKit.plaque(self, "ELECTRICIDAD", "BARRA PRINCIPAL   /   BALANCE", 9.0, 1.5,
		35.5, 7.4, 58.7, 0.0)
	_ceiling_lights(BuildKit.WARM)


# --------------------------------------------------------------------------- #
# Vigilancia · muro de seis cámaras, mesa y sillas
# --------------------------------------------------------------------------- #
func _build_surveillance() -> void:
	var metal := BuildKit.material(BuildKit.METAL)
	var graphite := BuildKit.material(BuildKit.GRAPHITE)
	# Muro de pantallas sobre el muro norte de la sala.
	var wall := Node3D.new()
	wall.name = "CameraWall"
	wall.position = Vector3(-17.6, 0.0, 83.4)
	wall.rotation.y = PI
	add_child(wall)
	BuildKit.block(wall, graphite, 0.0, 4.0, -0.16, 9.6, 4.4, 0.32)
	var labels := ["CAM 01 · OBSERVACIÓN", "CAM 02 · ARCHIVO", "CAM 03 · TURBINAS",
		"CAM 04 · BÓVEDA", "CAM 05 · GALERÍA", "CAM 06 · HIDRÁULICA"]
	for index in 6:
		var column: int = index % 3
		var row: int = index / 3
		var screen := WallScreen.new()
		screen.kind = "phosphor"
		screen.screen_size = Vector2(2.4, 1.35)
		screen.position = Vector3(-2.9 + column * 2.9, 4.9 - row * 1.7, 0.06)
		wall.add_child(screen)
		screens.append(screen)
		screen.push_phosphor(labels[index], "EN VIVO", "señal CAM 0%d" % (index + 1),
			0.4 + index * 0.05)
		_screen_frame(wall, screen.position, Vector2(2.4, 1.35))
	# Mesa de operación con dos sillas, delante del muro.
	BuildKit.block(self, metal, -17.6, 0.95, 75.6, 7.2, 0.16, 1.9)
	BuildKit.block(self, graphite, -17.6, 0.43, 75.6, 6.0, 0.86, 1.4)
	BuildKit.block(self, BuildKit.material(BuildKit.BRONZE, 0.7, 0.3),
		-17.6, 0.9, 74.66, 7.2, 0.06, 0.06)
	for side in [-1, 1]:
		BuildKit.block(self, graphite, -17.6 + float(side) * 2.6, 1.12, 75.0,
			0.9, 0.36, 0.07)
		BuildKit.block(self, BuildKit.emissive(Color("#8fe6d8"), 1.1),
			-17.6 + float(side) * 2.6, 1.12, 74.95, 0.78, 0.26, 0.02)
	for side in [-1, 1]:
		var seat := Node3D.new()
		seat.name = "Chair%d" % (side + 1)
		seat.position = Vector3(-17.6 + float(side) * 1.9, 0.0, 73.4)
		add_child(seat)
		BuildKit.drum(seat, metal, 0.0, 0.12, 0.0, 0.3, 0.06, false, 20)
		BuildKit.drum(seat, metal, 0.0, 0.26, 0.0, 0.07, 0.3, false, 12)
		BuildKit.drum(seat, graphite, 0.0, 0.48, 0.0, 0.36, 0.12, false, 24)
		BuildKit.block(seat, graphite, 0.0, 0.86, -0.32, 0.72, 0.72, 0.1)
		BuildKit.block(seat, BuildKit.emissive(BuildKit.GLOW, 0.5),
			0.0, 0.62, -0.34, 0.5, 0.04, 0.02)
	BuildKit.plaque(self, "VIGILANCIA", "CCTV   /   LAB 09", 6.6, 1.4,
		-17.6, 7.2, 83.2, PI)
	_ceiling_lights(Color("#bfe0e6"), 8.0)


## Marco cuadrado de luz alrededor de una pantalla del muro CCTV.
func _screen_frame(parent: Node3D, at: Vector3, size: Vector2) -> void:
	var glow := BuildKit.emissive(BuildKit.GLOW, 0.9)
	var half := size * 0.5
	BuildKit.block(parent, glow, at.x, at.y + half.y, at.z, size.x + 0.14, 0.05, 0.04)
	BuildKit.block(parent, glow, at.x, at.y - half.y, at.z, size.x + 0.14, 0.05, 0.04)
	BuildKit.block(parent, glow, at.x - half.x, at.y, at.z, 0.05, size.y + 0.14, 0.04)
	BuildKit.block(parent, glow, at.x + half.x, at.y, at.z, 0.05, size.y + 0.14, 0.04)


# --------------------------------------------------------------------------- #
# D–02 · archivadores y rótulos
# --------------------------------------------------------------------------- #
func _build_d02() -> void:
	var steel := BuildKit.material(BuildKit.STEEL, 0.55, 0.35)
	var bronze := BuildKit.material(BuildKit.BRONZE, 0.7, 0.3)
	var metal := BuildKit.material(BuildKit.METAL, 0.5, 0.4)
	var graphite := BuildKit.material(BuildKit.GRAPHITE, 0.5, 0.45)
	for index in 9:
		var z: float = -78.0 + float(index) * 6.2
		var cabinet := Node3D.new()
		cabinet.name = "Drawer%d" % (index + 1)
		cabinet.position = Vector3(44.6, 0.0, z)
		cabinet.rotation.y = -PI * 0.5
		add_child(cabinet)
		BuildKit.block(cabinet, graphite, 0.0, 0.65, 0.0, 3.6, 1.3, 1.1)
		for drawer in 4:
			BuildKit.block(cabinet, steel, 0.0, 0.25 + drawer * 0.32, 0.58, 3.3, 0.26, 0.06)
			BuildKit.block(cabinet, bronze, 0.0, 0.25 + drawer * 0.32, 0.63, 1.1, 0.06, 0.05)
		BuildKit.block(cabinet, metal, 0.0, 1.36, 0.0, 3.7, 0.1, 1.2)
	BuildKit.plaque(self, "REGISTROS", "ARCHIVO ÓPTICO   /   D–02", 8.0, 1.6,
		44.4, 6.6, -53.0, -PI * 0.5)
	_ceiling_lights(BuildKit.WARM, 10.0)


# --------------------------------------------------------------------------- #
# C–04 · malla de contención y rótulos de la nave
# --------------------------------------------------------------------------- #
func _build_c04() -> void:
	var steel := BuildKit.material(BuildKit.STEEL, 0.5, 0.4)
	var metal := steel
	var graphite := BuildKit.material(BuildKit.GRAPHITE, 0.5, 0.45)
	var bronze := BuildKit.material(BuildKit.BRONZE)
	var hazard := BuildKit.emissive(BuildKit.AMBER, 0.95)
	var fence := Node3D.new()
	fence.name = "ContainmentMesh"
	fence.position = Vector3(2.0, 0.0, 26.0)
	add_child(fence)
	var radius := 13.0
	for index in 24:
		var angle: float = float(index) * TAU / 24.0
		BuildKit.drum(fence, metal, cos(angle) * radius, 2.4, sin(angle) * radius,
			0.16, 4.8, false, 8)
	for level in 6:
		var y: float = 0.7 + float(level) * 0.72
		var ring_mesh := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = radius - 0.05
		torus.outer_radius = radius + 0.05
		torus.rings = 64
		torus.ring_segments = 6
		ring_mesh.mesh = torus
		ring_mesh.material_override = BuildKit.emissive(BuildKit.GLOW, 1.0)
		ring_mesh.position = Vector3(0.0, y, 0.0)
		fence.add_child(ring_mesh)
		rings.append(ring_mesh)
	for index in 6:
		var angle: float = float(index) * TAU / 6.0
		BuildKit.block(fence, bronze, cos(angle) * radius, 0.0, sin(angle) * radius,
			0.6, 0.5, 0.6)
	# Franja de peligro en el suelo, por fuera de la malla.
	for index in 24:
		var angle: float = float(index) * TAU / 24.0
		var dash := BuildKit.block(self, hazard, 2.0 + cos(angle) * 14.6, 0.035,
			26.0 + sin(angle) * 14.6, 0.86, 0.03, 0.4)
		dash.rotation.y = -angle
	# Pasarela perimetral con barandilla y borde luminoso.
	var catwalk := Node3D.new()
	catwalk.name = "C04Catwalk"
	add_child(catwalk)
	for index in 24:
		var angle: float = float(index) * TAU / 24.0
		var segment := Node3D.new()
		segment.name = "Walk%d" % index
		segment.position = Vector3(2.0 + cos(angle) * 17.2, 3.1, 26.0 + sin(angle) * 17.2)
		segment.rotation.y = -angle
		catwalk.add_child(segment)
		BuildKit.block(segment, metal, 0.0, 0.0, 0.0, 1.7, 0.14, 4.6)
		BuildKit.block(segment, BuildKit.emissive(BuildKit.GLOW, 0.9),
			0.8, 0.1, 0.0, 0.07, 0.05, 4.5)
		BuildKit.block(segment, graphite, 0.82, 0.62, 0.0, 0.06, 1.1, 0.06)
		BuildKit.bar(segment, metal, Vector3(0.82, 1.16, -2.2), Vector3(0.82, 1.16, 2.2), 0.06)
		BuildKit.bar(segment, metal, Vector3(0.82, 0.72, -2.2), Vector3(0.82, 0.72, 2.2), 0.04)
		if index % 3 == 0:
			BuildKit.drum(catwalk, graphite, 2.0 + cos(angle) * 17.2, 1.55,
				26.0 + sin(angle) * 17.2, 0.18, 3.0, false, 10)
	# Balizas de sector sobre la pasarela.
	for index in 4:
		var angle: float = float(index) * TAU / 4.0 + TAU * 0.125
		BuildKit.drum(self, graphite, 2.0 + cos(angle) * 15.4, 0.9,
			26.0 + sin(angle) * 15.4, 0.11, 1.8, false, 10)
		indicators.append(BuildKit.bead(self, BuildKit.emissive(BuildKit.AMBER, 1.2),
			2.0 + cos(angle) * 15.4, 1.86, 26.0 + sin(angle) * 15.4, 0.13, 10))
	# Pórtico de mantenimiento sobre la cuba.
	var gantry := Node3D.new()
	gantry.name = "C04Gantry"
	add_child(gantry)
	for side in [-1, 1]:
		BuildKit.bar(gantry, metal, Vector3(-19.0, 8.0, 26.0 + float(side) * 13.6),
			Vector3(23.0, 8.0, 26.0 + float(side) * 13.6), 0.22)
	BuildKit.block(gantry, graphite, 2.0, 7.86, 26.0, 41.0, 0.34, 0.6)
	BuildKit.block(gantry, metal, 2.0, 7.4, 26.0, 1.5, 0.6, 1.5)
	BuildKit.bar(gantry, BuildKit.emissive(BuildKit.GLOW, 0.8),
		Vector3(2.0, 7.2, 26.0), Vector3(2.0, 5.9, 26.0), 0.05)
	BuildKit.drum(gantry, bronze, 2.0, 5.8, 26.0, 0.16, 0.24, false, 12)
	# Banco de instrumentación contra el muro oeste.
	for index in 4:
		BuildKit.cabinet(self, -25.9, 18.0 + float(index) * 4.2, PI * 0.5,
			1.9, 2.4, 0.7, 2, "C04Rack%d" % (index + 1))
	BuildKit.block(self, metal, -25.4, 2.9, 26.6, 0.9, 0.16, 15.4)
	BuildKit.block(self, BuildKit.emissive(Color("#9fe8ff"), 1.4), -25.0, 2.98, 26.6,
		0.06, 0.05, 15.0)
	for index in 3:
		var screen := WallScreen.new()
		# La primera muestra telemetría viva (red y sujeto); las otras dos, estado.
		screen.kind = "telemetry" if index == 0 else "phosphor"
		screen.screen_size = Vector2(2.2, 1.24)
		screen.position = Vector3(-25.1, 5.4, 20.0 + float(index) * 6.2)
		screen.rotation.y = PI * 0.5
		add_child(screen)
		screens.append(screen)
		if screen.kind == "phosphor":
			screen.push_phosphor("CONTENCIÓN C–04", "MALLA ACTIVA",
				"anillo %d · tensión nominal" % (index + 1), 0.5 + float(index) * 0.07)
		else:
			# El feed vive con el mobiliario: toma muestras de GameState cada frame.
			var feed := TelemetryFeed.new()
			feed.name = "C04Feed"
			add_child(feed)
			feed.screen = screen
			feed.set_process(true)
	# Cajas de utillaje junto al acceso norte.
	for index in 3:
		BuildKit.block(self, graphite, -20.0 + float(index) * 1.5, 0.42, 6.4, 1.2, 0.84, 1.2)
		BuildKit.block(self, BuildKit.emissive(BuildKit.AMBER, 0.8),
			-20.0 + float(index) * 1.5, 0.86, 6.4, 1.0, 0.04, 0.06)
	BuildKit.plaque(self, "CONTENCIÓN", "C–04   /   MALLA ACTIVA", 9.0, 1.6,
		44.6, 7.2, 26.0, -PI * 0.5)
	BuildKit.plaque(self, "GALERÍA", "V–03   /   EJE NORTE", 7.0, 1.4,
		-26.6, 7.2, 12.0, PI * 0.5)
	# Mobiliario de escala humana: carretilla, escalera de pasarela, conos y palés.
	var forklift := Node3D.new()
	forklift.name = "C04Forklift"
	forklift.position = Vector3(37.5, 0.0, 14.0)
	forklift.rotation.y = -2.3
	add_child(forklift)
	BuildKit.block(forklift, steel, 0.0, 0.72, 0.0, 1.5, 1.0, 2.3)
	BuildKit.block(forklift, graphite, 0.0, 0.3, 0.0, 1.56, 0.36, 2.4)
	BuildKit.block(forklift, steel, 0.0, 1.34, 0.2, 1.3, 0.24, 1.5)
	BuildKit.block(forklift, BuildKit.emissive(BuildKit.AMBER, 0.9), 0.0, 1.4, -0.62,
		0.9, 0.08, 0.12)
	BuildKit.bar(forklift, metal, Vector3(0.0, 1.3, 1.1), Vector3(0.0, 2.5, 0.85), 0.1)
	BuildKit.block(forklift, graphite, 0.0, 2.56, 0.82, 0.9, 0.14, 0.8)
	for wheel in 4:
		var wx: float = -0.74 + float(wheel % 2) * 1.48
		var wz: float = -0.72 + float(wheel / 2) * 1.44
		BuildKit.drum(forklift, graphite, wx, 0.3, wz, 0.3, 0.22, true, 14)
	for side in [-1, 1]:
		BuildKit.block(forklift, metal, float(side) * 0.42, 0.14, -2.1, 0.14, 0.08, 1.2)
		BuildKit.block(forklift, metal, float(side) * 0.42, 0.5, -1.5, 0.14, 0.7, 0.12)
	BuildKit.bead(forklift, BuildKit.emissive(BuildKit.GLOW, 1.2), 0.0, 2.66, 0.82, 0.1, 8)
	# Escalera de la pasarela.
	var stair := Node3D.new()
	stair.name = "C04Stair"
	stair.position = Vector3(19.4, 0.0, 43.0)
	add_child(stair)
	for step in 9:
		BuildKit.block(stair, steel, 0.0, 0.2 + float(step) * 0.32,
			-float(step) * 0.34, 1.3, 0.08, 0.32)
	for side in [-1, 1]:
		BuildKit.bar(stair, metal, Vector3(float(side) * 0.68, 0.0, 0.0),
			Vector3(float(side) * 0.68, 3.0, -3.0), 0.1)
		BuildKit.bar(stair, metal, Vector3(float(side) * 0.68, 1.2, 0.0),
			Vector3(float(side) * 0.68, 4.1, -3.0), 0.06)
	BuildKit.block(stair, BuildKit.emissive(BuildKit.AMBER, 0.8), 0.0, 3.1, -3.05,
		1.4, 0.06, 0.1)
	# Conos de balizamiento y palés junto a la puerta.
	for index in 5:
		var angle: float = 0.6 + float(index) * 1.1
		var cone := Node3D.new()
		cone.name = "C04Cone%d" % index
		cone.position = Vector3(2.0 + cos(angle) * 15.6, 0.0, 26.0 + sin(angle) * 15.6)
		add_child(cone)
		BuildKit.drum(cone, graphite, 0.0, 0.03, 0.0, 0.24, 0.06, false, 10)
		BuildKit.drum(cone, BuildKit.emissive(BuildKit.AMBER, 0.9), 0.0, 0.34, 0.0,
			0.14, 0.62, false, 10)
	for index in 3:
		BuildKit.block(self, bronze, -18.0 + float(index) * 1.6, 0.09, 12.0, 1.4, 0.18, 1.2)
		BuildKit.block(self, graphite, -18.0 + float(index) * 1.6, 0.42, 12.0, 1.2, 0.5, 1.0)
	# Dos hileras más de luminarias sobre la cuba: la sala es muy ancha y la fila
	# central de `_ceiling_lights` dejaba el anillo a oscuras.
	for row in 3:
		var light_z: float = 6.0 + float(row) * 28.0
		var light_x: float = -22.0
		while light_x <= 42.0:
			BuildKit.luminaire(self, light_x, ceiling() - 1.1, light_z, 3.2,
				Color("#cfe9f2"))
			light_x += 12.0
	# Utillaje y bidones arrimados a los muros para romper el vacío del suelo.
	for index in 6:
		var side: float = -1.0 if index % 2 == 0 else 1.0
		var bx: float = 2.0 + side * 21.0
		var bz: float = 8.0 + float(index) * 2.0
		BuildKit.drum(self, metal, bx, 0.6, bz, 0.55, 1.2, false, 16)
		BuildKit.ring(self, bronze, bx, 0.9, bz, 0.56, 0.04, true)
	for index in 4:
		var side: float = -1.0 if index % 2 == 0 else 1.0
		BuildKit.block(self, graphite, 2.0 + side * 24.0, 0.5,
			46.0 + float(index) * 2.4, 1.4, 1.0, 1.4)
		BuildKit.block(self, BuildKit.emissive(BuildKit.AMBER, 0.7), 2.0 + side * 24.0,
			1.02, 46.0 + float(index) * 2.4, 1.2, 0.04, 0.06)
	_ceiling_lights(Color("#cfe9f2"), 12.0)


# --------------------------------------------------------------------------- #
# V–03 · galería axial (arcos) y crioteca
# --------------------------------------------------------------------------- #
func _build_gallery() -> void:
	var graphite := BuildKit.material(BuildKit.GRAPHITE, 0.5, 0.45)
	var z: float = -28.0
	while z >= -78.0:
		var arch := Node3D.new()
		arch.name = "Arch%d" % int(absf(z))
		arch.position = Vector3(27.0, 0.0, z)
		add_child(arch)
		for side in [-1, 1]:
			BuildKit.block(arch, graphite, float(side) * 3.3, 2.1, 0.0, 0.3, 4.2, 0.3)
			BuildKit.block(arch, BuildKit.emissive(BuildKit.AMBER, 0.8),
				float(side) * 3.2, 1.2, 0.0, 0.06, 2.0, 0.08)
		BuildKit.block(arch, graphite, 0.0, 4.2, 0.0, 7.0, 0.3, 0.3)
		BuildKit.block(arch, BuildKit.emissive(BuildKit.GLOW, 1.0), 0.0, 4.0, 0.0, 6.4, 0.06, 0.1)
		BuildKit.luminaire(arch, 0.0, 4.3, 0.0, 1.6, Color("#cfe9f2"), false)
		z -= 6.4
	BuildKit.plaque(self, "GALERÍA AXIAL", "V–03   /   EJE DE COMUNICACIÓN", 5.2, 0.95,
		30.6, 3.9, -76.0, -PI * 0.5)


func _build_cryo() -> void:
	var metal := BuildKit.material(BuildKit.METAL)
	var graphite := BuildKit.material(BuildKit.GRAPHITE)
	var steel := BuildKit.material(BuildKit.STEEL, 0.55, 0.35)
	var bronze_plate := BuildKit.material(BuildKit.BRONZE, 0.7, 0.3)
	# Dos hileras de vitrinas de criopreservación.
	for row in 2:
		var z: float = -95.0 + float(row) * 7.0
		for index in 6:
			var x: float = 16.5 + float(index) * 5.2
			var tank := Node3D.new()
			tank.name = "CryoTank_%d_%d" % [row, index]
			tank.position = Vector3(x, 0.0, z)
			add_child(tank)
			BuildKit.block(tank, graphite, 0.0, 0.16, 0.0, 2.2, 0.32, 1.6)
			BuildKit.block(tank, steel, 0.0, 0.95, 0.0, 2.2, 1.42, 1.6)
			BuildKit.block(tank, graphite, 0.0, 1.12, 0.0, 2.24, 0.06, 1.64)
			BuildKit.block(tank, BuildKit.glass(), 0.0, 0.92, 0.0, 1.5, 0.72, 0.06)
			BuildKit.block(tank, BuildKit.emissive(Color("#dff6ff"), 1.3),
				0.0, 0.92, 0.02, 1.2, 0.5, 0.02)
			BuildKit.block(tank, bronze_plate, 0.0, 0.92, 0.05, 0.5, 0.5, 0.03)
			BuildKit.block(tank, BuildKit.glass(), 0.0, 2.25, 0.0, 2.0, 1.0, 1.4)
			BuildKit.block(tank, BuildKit.emissive(Color("#cdeff8"), 1.1),
				0.0, 2.74, 0.0, 1.7, 0.04, 1.1)
			BuildKit.block(tank, metal, 0.0, 2.82, 0.0, 2.2, 0.18, 1.6)
			BuildKit.block(tank, BuildKit.emissive(Color("#a9e6f5"), 1.2),
				0.0, 1.84, 0.0, 2.1, 0.06, 1.5)
			# Vitrina iluminada: testigo frontal y lámpara interior.
			BuildKit.block(tank, BuildKit.emissive(Color("#d8f4fb"), 1.6),
				0.0, 2.7, 0.72, 1.8, 0.05, 0.04)
			BuildKit.block(tank, BuildKit.emissive(Color("#8fd7ea"), 0.9),
				0.0, 1.0, 0.82, 1.9, 0.04, 0.03)
			BuildKit.block(tank, BuildKit.material(BuildKit.BRONZE, 0.7, 0.3),
				0.0, 1.6, 0.83, 0.34, 0.1, 0.04)
	BuildKit.block(self, metal, 29.0, 1.0, -83.4, 4.6, 0.16, 1.6)
	BuildKit.block(self, graphite, 29.0, 0.5, -83.4, 4.0, 0.9, 1.3)
	BuildKit.plaque(self, "CRIOTECA", "V–03   /   CRIOPRESERVACIÓN", 8.0, 1.5,
		29.0, 5.4, -82.6, PI)
	_ceiling_lights(Color("#bfe6f2"), 9.0)


# --------------------------------------------------------------------------- #
# A–01 · archivo biométrico y estación
# --------------------------------------------------------------------------- #
func _build_a01() -> void:
	var metal := BuildKit.material(BuildKit.METAL, 0.5, 0.4)
	var graphite := BuildKit.material(BuildKit.GRAPHITE, 0.5, 0.45)
	var steel := BuildKit.material(BuildKit.STEEL, 0.6, 0.34)
	var bronze := BuildKit.material(BuildKit.BRONZE, 0.7, 0.3)
	# Taquillas del vestuario, junto al muro sur.
	for index in 4:
		var x: float = -14.0 + float(index) * 4.4
		BuildKit.cabinet(self, x, -23.2, 0.0, 3.4, 1.4, 1.0, 3, "Locker%d" % (index + 1))
	# Estantería de carga a lo largo del muro oeste.
	for bank in 2:
		var z: float = -6.0 - float(bank) * 8.4
		var rack := Node3D.new()
		rack.name = "A01Rack%d" % (bank + 1)
		rack.position = Vector3(-24.6, 0.0, z)
		add_child(rack)
		for level in 3:
			var y: float = 0.7 + float(level) * 1.1
			BuildKit.block(rack, steel, 0.0, y, 0.0, 1.5, 0.12, 7.4)
			BuildKit.block(rack, BuildKit.emissive(BuildKit.GLOW, 0.7),
				0.76, y + 0.1, 0.0, 0.05, 0.04, 7.2)
		for upright in 3:
			BuildKit.block(rack, metal, 0.0, 1.7, -3.6 + float(upright) * 3.6, 0.1, 3.4, 0.1)
		for crate in 3:
			BuildKit.block(rack, graphite, 0.0, 1.1, -2.2 + float(crate) * 2.2,
				1.1, 0.66, 1.5)
			BuildKit.block(rack, bronze, 0.0, 1.1, -1.44 + float(crate) * 2.2,
				0.3, 0.06, 0.05)
	# Muelle de carga: plataforma, topes y rampa de acceso.
	BuildKit.block(self, graphite, 2.0, 0.12, -14.0, 7.4, 0.24, 2.6)
	BuildKit.block(self, BuildKit.emissive(BuildKit.AMBER, 0.9), 2.0, 0.26, -12.68,
		7.2, 0.05, 0.08)
	for side in [-1, 1]:
		BuildKit.block(self, metal, 2.0 + float(side) * 3.6, 0.6, -14.0, 0.16, 1.2, 2.4)
	BuildKit.bar(self, BuildKit.emissive(BuildKit.GLOW, 0.8),
		Vector3(-1.3, 0.3, -14.0), Vector3(5.3, 0.3, -14.0), 0.06)
	# Bancada de carga de equipo con tres alojamientos.
	var bay := Node3D.new()
	bay.name = "A01ChargeBay"
	bay.position = Vector3(4.6, 0.0, -5.2)
	add_child(bay)
	BuildKit.block(bay, graphite, 0.0, 0.5, 0.0, 1.0, 1.0, 3.4)
	BuildKit.block(bay, steel, 0.0, 1.02, 0.0, 1.1, 0.1, 3.6)
	for slot in 3:
		var z: float = -1.2 + float(slot) * 1.2
		BuildKit.block(bay, BuildKit.emissive(BuildKit.GLOW, 1.1), -0.5, 0.62, z,
			0.06, 0.5, 0.9)
		BuildKit.bead(bay, BuildKit.emissive(BuildKit.AMBER, 1.0), -0.52, 1.12, z, 0.05, 8)
		BuildKit.bar(bay, metal, Vector3(0.5, 0.98, z), Vector3(0.5, 0.6, z + 0.4), 0.04)
	# Carro de transporte y bidones.
	var cart := Node3D.new()
	cart.name = "A01Cart"
	cart.position = Vector3(-14.0, 0.0, -18.0)
	add_child(cart)
	BuildKit.block(cart, steel, 0.0, 0.62, 0.0, 1.6, 0.12, 2.6)
	for corner in 4:
		BuildKit.drum(cart, graphite, -0.62 + float(corner % 2) * 1.24, 0.16,
			-1.06 + float(corner / 2) * 2.12, 0.16, 0.12, true, 10)
	BuildKit.bar(cart, metal, Vector3(0.0, 0.7, 1.3), Vector3(0.0, 1.3, 1.3), 0.06)
	BuildKit.block(cart, graphite, 0.0, 1.0, 0.0, 1.2, 0.6, 1.8)
	for index in 2:
		BuildKit.drum(self, metal, -9.4 + float(index) * 1.4, 0.6, -20.6, 0.55, 1.2, false, 16)
		BuildKit.ring(self, bronze, -9.4 + float(index) * 1.4, 0.9, -20.6, 0.56, 0.04, true)
	# Pasillo marcado en el suelo, del muelle a la puerta.
	var dash_index := 0
	var z: float = -22.0
	while z <= -2.0:
		BuildKit.block(self, BuildKit.emissive(BuildKit.AMBER, 0.55), -6.0, 0.03, z,
			0.9, 0.02, 0.5)
		dash_index += 1
		z += 2.0
	# Tuberías y bandejas de cables sobre la nave.
	for run in 3:
		BuildKit.bar(self, metal, Vector3(-26.0, 8.7 - float(run) * 0.34, -4.0 - float(run) * 6.0),
			Vector3(8.0, 8.7 - float(run) * 0.34, -4.0 - float(run) * 6.0), 0.14)
	BuildKit.block(self, graphite, -6.0, 8.9, -13.0, 33.0, 0.12, 0.9)
	# Baliza del muelle.
	BuildKit.drum(self, graphite, 6.4, 1.1, -9.0, 0.1, 2.2, false, 10)
	indicators.append(BuildKit.bead(self, BuildKit.emissive(BuildKit.AMBER, 1.2),
		6.4, 2.28, -9.0, 0.12, 10))
	BuildKit.block(self, metal, 2.0, 0.95, -14.0, 5.0, 0.16, 1.8)
	BuildKit.block(self, graphite, 2.0, 0.45, -14.0, 4.6, 0.9, 1.5)
	BuildKit.plaque(self, "ARCHIVO BIOMÉTRICO", "A–01   /   ESTACIÓN DE CARGA", 9.0, 1.5,
		2.0, 5.6, -23.0, 0.0)
	BuildKit.plaque(self, "MUELLE", "A–01   /   CARGA DE EQUIPO", 6.4, 1.3,
		-26.6, 4.6, -12.0, PI * 0.5)
	_ceiling_lights(BuildKit.WARM)


# --------------------------------------------------------------------------- #
# Tránsito · andén, cápsula y rótulos del eje
# --------------------------------------------------------------------------- #
func _build_transit() -> void:
	var metal := BuildKit.material(BuildKit.METAL)
	var graphite := BuildKit.material(BuildKit.GRAPHITE)
	var capsule := Node3D.new()
	capsule.name = "CapsuleShell"
	capsule.position = Vector3(15.0, 0.0, 99.0)
	add_child(capsule)
	BuildKit.block(capsule, graphite, 0.0, 1.5, 0.0, 3.9, 2.9, 12.0)
	BuildKit.block(capsule, metal, 0.0, 2.98, 0.0, 3.7, 0.2, 11.8)
	for side in [-1, 1]:
		BuildKit.block(capsule, BuildKit.glass(0.22), float(side) * 1.96, 1.9, 0.0,
			0.06, 1.2, 9.6)
		BuildKit.block(capsule, BuildKit.emissive(BuildKit.GLOW, 0.9),
			float(side) * 1.98, 1.2, 0.0, 0.04, 0.08, 9.2)
	BuildKit.block(capsule, BuildKit.emissive(Color("#bfe9f2"), 1.3),
		0.0, 2.62, 0.0, 3.4, 0.05, 11.2)
	# Andén: bordillo, bancos y barandilla.
	BuildKit.block(self, metal, 15.0, 0.06, 99.0, 6.4, 0.12, 14.0)
	for side in [-1, 1]:
		BuildKit.block(self, BuildKit.emissive(BuildKit.AMBER, 0.9),
			15.0 + float(side) * 3.2, 0.14, 99.0, 0.08, 0.04, 13.6)
	BuildKit.plaque(self, "ANDÉN 01", "EJE L–01   /   CÁPSULA", 6.4, 1.4,
		15.0, 5.4, 92.6, 0.0)
	BuildKit.plaque(self, "ANDÉN 02", "EJE L–01", 6.0, 1.3, 15.0, 5.4, 105.4, PI)
	_ceiling_lights(Color("#cfe9f2"), 8.0)
