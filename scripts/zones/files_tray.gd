class_name FilesTray
extends StaticBody3D
## Bandeja de expedientes (D–02). Abre/cierra el cajón y lee el folio.

@export var tray_index: int = 0
@export var display_name: String = "Bandeja de expedientes"
@export var files_path: NodePath

var _files: FilesModule


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
