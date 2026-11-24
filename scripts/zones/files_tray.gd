class_name FilesTray
extends StaticBody3D
## Bandeja de expedientes (D–02). Abre/cierra el cajón y lee el folio.

@export var tray_index: int = 0
@export var display_name: String = "Bandeja de expedientes"
@export var files_path: NodePath

var _files: FilesModule
var _drawer: Node3D
var _folio: MeshInstance3D
var _open := 0.0


func _ready() -> void:
	add_to_group(&"interactable")
	set_meta("survey_id", "files_tray_%d" % tray_index)
	set_meta("survey_name", display_name)
	set_meta("survey_detail", "Bandeja extraíble del archivo D–02")
	if not files_path.is_empty():
		_files = get_node_or_null(files_path) as FilesModule
	if _files == null:
		_files = get_tree().get_first_node_in_group(&"files_module") as FilesModule
	if not collision_layer:
		collision_layer = 1
	_build_visual()


## Bandeja visible: marco del archivador, cajón corredizo y folio.
func _build_visual() -> void:
	var graphite := BuildKit.material(BuildKit.GRAPHITE, 0.5, 0.45)
	var steel := BuildKit.material(BuildKit.STEEL, 0.55, 0.35)
	var bronze := BuildKit.material(BuildKit.BRONZE, 0.7, 0.3)
	BuildKit.block(self, graphite, 0.0, 0.12, -0.18, 1.72, 0.86, 0.4)
	BuildKit.block(self, steel, 0.0, 0.53, -0.16, 1.78, 0.06, 0.44)
	_drawer = Node3D.new()
	_drawer.name = "Drawer"
	add_child(_drawer)
	BuildKit.block(_drawer, steel, 0.0, 0.1, 0.02, 1.6, 0.62, 0.3)
	BuildKit.block(_drawer, graphite, 0.0, 0.1, 0.19, 1.54, 0.56, 0.04)
	BuildKit.block(_drawer, bronze, 0.0, 0.1, 0.23, 0.46, 0.07, 0.05)
	BuildKit.block(_drawer, BuildKit.emissive(BuildKit.GLOW, 0.9), 0.0, 0.34, 0.22,
		0.1, 0.05, 0.02)
	# Folio: sólo se ve cuando el cajón está fuera del todo.
	_folio = BuildKit.block(_drawer, BuildKit.material(BuildKit.WHITE, 0.15, 0.5),
		0.0, 0.36, 0.02, 1.2, 0.02, 0.24)
	_folio.visible = false
	var label := Label3D.new()
	label.text = display_name
	label.font_size = 22
	label.pixel_size = 0.0026
	label.modulate = Color("#cfe9f2")
	label.position = Vector3(0.0, -0.16, 0.26)
	_drawer.add_child(label)


func _process(delta: float) -> void:
	if _files == null or _drawer == null:
		return
	var factor := _files.tray_factor(tray_index)
	_open = lerpf(_open, factor, clampf(delta * 10.0, 0.0, 1.0))
	_drawer.position = Vector3(0.0, 0.0, _open * 0.62)
	if _folio != null:
		_folio.visible = _open > 0.9
		_folio.position = Vector3(0.0, 0.36 + 0.04 * _open, 0.02)


func get_interaction_prompt() -> String:
	if _files == null:
		return ""
	if _files.tray_open(tray_index) and _files.tray_revealed(tray_index):
		var dossier := _files.dossier_of(tray_index)
		return "E · Leer %s" % str(dossier.get("title", "expediente"))
	if _files.tray_open(tray_index):
		return "E · Cerrar bandeja"
	return "E · Abrir bandeja"


func interact(actor: NexusPlayer) -> String:
	if _files == null:
		return "Archivo no disponible"
	if _files.tray_open(tray_index) and _files.tray_revealed(tray_index):
		return _files.read_tray(tray_index, actor)
	_files.toggle(tray_index)
	if _files.tray_open(tray_index):
		return "Bandeja abierta · el folio sube al sacarla"
	return "Bandeja cerrada · folios protegidos"
