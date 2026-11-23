extends SceneTree

func _init() -> void:
	var survey := SurveySystem.new()
	var target := Node3D.new()
	target.name = "VaultReader"
	target.set_meta("survey_id", "reader")
	target.set_meta("survey_name", "Lector de proximidad")
	target.set_meta("zone_id", "a01")
	target.set_meta("survey_detail", "Autentica la credencial V-03")
	var first := survey.register_target(target, Vector3(18, 1, -38))
	var duplicate := survey.register_target(target, Vector3.ZERO)
	var state := GameState.new()
	state.store_survey_records(survey.snapshot())
	var restored := SurveySystem.new()
	restored.restore(state.survey_records)
	var highlighter := SurveyHighlight.new()
	var visual := MeshInstance3D.new()
	visual.mesh = BoxMesh.new()
	var original_overlay := StandardMaterial3D.new()
	visual.material_overlay = original_overlay
	var highlight_started: bool = highlighter.begin(visual)
	var temporary_overlay: bool = visual.material_overlay != original_overlay
	highlighter.advance(highlighter.duration_s)
	var overlay_restored: bool = visual.material_overlay == original_overlay and highlighter.target == null
	var checks: Dictionary = {
		"contact_zero_length_rejected": ContactQuery3D.first_hit(null, Vector3.ZERO, Vector3.ZERO).is_empty(),
		"record_identity": first.get("id") == "reader",
		"record_zone": first.get("zone") == "a01",
		"duplicate_returns_existing": duplicate.get("position") == Vector3(18, 1, -38),
		"single_record": survey.records.size() == 1,
		"persistent_restore": restored.records.size() == 1 and restored.records[0].get("name") == "Lector de proximidad",
		"highlight_started": highlight_started,
		"temporary_overlay": temporary_overlay,
		"overlay_restored": overlay_restored,
	}
	var passed: bool = not checks.values().has(false)
	print(JSON.stringify({"checks": checks, "passed": passed}))
	target.free()
	survey.free()
	state.free()
	restored.free()
	highlighter.free()
	visual.free()
	quit(0 if passed else 1)
