extends SceneTree
## Valida la configuración de distribución: presets de exportación, ajustes de
## proyecto que Godot exige para Android (ETC2/ASTC), versiones, filtros del
## paquete y el script de construcción reproducible.

var checks := 0
var failures: Array[String] = []
var presets: ConfigFile
var project: ConfigFile


func _check(name: String, condition: bool) -> void:
	checks += 1
	if not condition:
		failures.append(name)


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame
	presets = ConfigFile.new()
	project = ConfigFile.new()
	_check("existe export_presets.cfg", presets.load("res://export_presets.cfg") == OK)
	_check("existe project.godot", project.load("res://project.godot") == OK)

	# 1. Los tres destinos y sus nombres de preset.
	var names: Array[String] = []
	var platforms: Array[String] = []
	for index in 3:
		names.append(str(presets.get_value("preset.%d" % index, "name", "")))
		platforms.append(str(presets.get_value("preset.%d" % index, "platform", "")))
	_check("hay tres presets (%s)" % str(names), names == ["Linux", "Windows Desktop", "Android"])
	_check("las plataformas son Linux, Windows Desktop y Android (%s)" % str(platforms),
		platforms == ["Linux", "Windows Desktop", "Android"])
	var paths: Array[String] = []
	for index in 3:
		paths.append(str(presets.get_value("preset.%d" % index, "export_path", "")))
	_check("Linux compila a build/linux (%s)" % paths[0], paths[0].begins_with("build/linux/"))
	_check("Windows compila a build/windows (%s)" % paths[1], paths[1].begins_with("build/windows/"))
	_check("Android compila a build/android (%s)" % paths[2], paths[2].begins_with("build/android/"))
	for index in 3:
		_check("el preset %d ignora qa, reports, docs y tools" % index,
			str(presets.get_value("preset.%d" % index, "exclude_filter", "")).contains("qa/*")
			and str(presets.get_value("preset.%d" % index, "exclude_filter", "")).contains("reports/*")
			and str(presets.get_value("preset.%d" % index, "exclude_filter", "")).contains("docs/*")
			and str(presets.get_value("preset.%d" % index, "exclude_filter", "")).contains("tools/*"))
	_check("los binarios de escritorio llevan el PCK dentro",
		bool(presets.get_value("preset.0.options", "binary_format/embed_pck", false))
		and bool(presets.get_value("preset.1.options", "binary_format/embed_pck", false)))

	# 2. Versión: la del proyecto manda y los presets la repiten.
	var version := str(project.get_value("application", "config/version", ""))
	_check("el proyecto lleva versión (%s)" % version, version == "0.44.0")
	_check("el APK repite la versión del proyecto (%s)"
		% str(presets.get_value("preset.2.options", "version/name", "")),
		str(presets.get_value("preset.2.options", "version/name", "")) == version)
	_check("el código de versión es un entero positivo (%s)"
		% str(presets.get_value("preset.2.options", "version/code", 0)),
		int(presets.get_value("preset.2.options", "version/code", 0)) > 0)
	_check("el nombre de la aplicación es NEXUS Native",
		str(project.get_value("application", "config/name", "")) == "NEXUS Native")
	_check("el nombre del paquete acompaña (%s)"
		% str(presets.get_value("preset.2.options", "package/name", "")),
		str(presets.get_value("preset.2.options", "package/name", "")) == "NEXUS Native")

	# 3. Android: identificador, arquitectura y ETC2/ASTC (el fallo silencioso
	#    que costó media fase).
	var unique := str(presets.get_value("preset.2.options", "package/unique_name", ""))
	var segments := unique.split(".")
	var identifier_ok := segments.size() >= 2
	for segment in segments:
		if segment.is_empty() or not segment[0].is_valid_identifier() or segment.contains("-"):
			identifier_ok = false
	_check("el identificador de paquete es válido (%s)" % unique, identifier_ok)
	_check("se compila para arm64-v8a", bool(presets.get_value("preset.2.options", "architectures/arm64-v8a", false)))
	_check("no se compilan arquitecturas de 32 bits",
		not bool(presets.get_value("preset.2.options", "architectures/armeabi-v7a", true))
		and not bool(presets.get_value("preset.2.options", "architectures/x86", true)))
	_check("la pantalla es inmersiva", bool(presets.get_value("preset.2.options", "screen/immersive_mode", false)))
	_check("el APK se firma fuera de Godot (`package/signed` apagado)",
		not bool(presets.get_value("preset.2.options", "package/signed", true)))
	_check("Godot importa ETC2/ASTC, que es requisito del export de Android",
		bool(project.get_value("rendering", "textures/vram_compression/import_etc2_astc", false)))
	_check("sin compilación por gradle", not bool(presets.get_value("preset.2.options", "gradle_build/use_gradle_build", true)))

	# 4. Script de construcción reproducible.
	var script_path := "res://tools/build.sh"
	_check("existe tools/build.sh", FileAccess.file_exists(script_path))
	var body := ""
	if FileAccess.file_exists(script_path):
		body = FileAccess.get_file_as_string(script_path)
	_check("el script compila los tres destinos",
		body.contains("Linux") and body.contains("Windows Desktop") and body.contains("Android"))
	_check("el script corre la suite antes de empaquetar",
		body.contains("qa/run_suite.gd") and body.contains('"failures":[]'))
	_check("el script deja sumas de verificación", body.contains("sha256sum") and body.contains("SHA256SUMS"))
	_check("el script escribe un informe de construcción", body.contains("BUILD_REPORT.json"))
	_check("el script firma el APK y lo verifica", body.contains("apksigner") and body.contains("verify"))
	_check("el script importa antes de exportar", body.contains("--import"))
	var info := FileAccess.get_file_as_string("res://.gitignore")
	_check("los artefactos de build no entran en git", info.contains("/build/"))

	# 5. Si hay artefactos, que tengan sentido.
	var report := "res://build/BUILD_REPORT.json"
	if FileAccess.file_exists(report):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(report))
		_check("el informe de construcción se lee", parsed is Dictionary)
		if parsed is Dictionary:
			var data := parsed as Dictionary
			_check("el informe dice la versión %s (%s)" % [version, str(data.get("version", ""))],
				str(data.get("version", "")) == version)
			_check("el informe no tiene fallos de suite", (data.get("suite_failures", []) as Array).is_empty())
			var artifacts: Array = data.get("artifacts", [])
			_check("el informe lista artefactos con sha256 (%d)" % artifacts.size(), artifacts.size() > 0)
			for artifact: Dictionary in artifacts:
				_check("el artefacto %s pesa más de 1 MB" % str(artifact.get("path", "?")),
					int(artifact.get("bytes", 0)) > 1048576)
	else:
		_check("sin informe de construcción todavía (se genera con tools/build.sh)", true)

	print(JSON.stringify({"checks": checks, "failures": failures, "passed": failures.is_empty()}))
	quit(0 if failures.is_empty() else 1)
