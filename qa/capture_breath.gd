extends SceneTree
## Vuelca doce segundos de aire y zumbido a `reports/phase35-breath.csv`.

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	await process_frame
	var breath := W01Breath.new()
	root.add_child(breath)
	breath.active = true
	var rows := PackedStringArray(["t,fatiga,ganancia_aire,corte_hz,ganancia_zumbido,hz_zumbido"])
	var step := 1.0 / 60.0
	for i in 12 * 60:
		var t := float(i) * step
		var fatigue := 0.65
		breath.update(step, fatigue)
		breath.machine(1.0, 0.72)
		rows.append("%.3f,%.2f,%.4f,%.0f,%.5f,%.2f" % [t, fatigue, breath.air_gain, breath.air_cutoff, breath.hum_gain, breath.hum_hz])
	var file := FileAccess.open("res://reports/phase35-breath.csv", FileAccess.WRITE)
	file.store_string("\n".join(rows))
	file.close()
	print("CSV ok ", rows.size())
	quit(0)
