extends SceneTree
## Valida la apertura de la bóveda sobre la puerta original (`vault.glb`).

var checks := 0
var failures: Array[String] = []


func _check(name: String, condition: bool) -> void:
	checks += 1
	if not condition:
		failures.append(name)


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame
	var packed := load("res://assets/generated/source-batch/vault.glb") as PackedScene
	if packed == null:
		print(JSON.stringify({"checks": 1, "failures": ["falta vault.glb"], "passed": false}))
		quit(1)
		return
	var root: Node3D = packed.instantiate()
	var door_group := (root.get_child(0) as Node3D).get_node_or_null("Node2") as Node3D
	if door_group == null:
		print(JSON.stringify({"checks": 1, "failures": ["falta Node2"], "passed": false}))
		quit(1)
		return
	var rig := VaultDoorRig.new()
	root.add_child(rig)
	var mounted := rig.attach(door_group)

	# 1. Piezas identificadas en el modelo original.
	_check("la puerta exportada se reconoce", mounted)
	_check("se encuentra el disco de 5,96 m (%s)" % (rig.disk.name if rig.disk != null else "—"), rig.disk != null)
	_check("se encuentra la corona central", rig.has_wheel())
	_check("ocho pestillos (%d)" % rig.dog_count(), rig.dog_count() == 8)
	_check("cuatro pistones (%d)" % rig.piston_count(), rig.piston_count() == 4)

	# 2. Cerrada de entrada.
	_check("arranca sellada (%.2f)" % rig.time, rig.time < 0.0 and rig.phase == "Sellada")
	var disk_z := rig.disk.position.z
	_check("el disco está en su sitio (z = %.2f)" % disk_z, is_equal_approx(disk_z, VaultDoorRig.DISK_HOME_Z))

	# 3. Pistones: suben escalonados entre 0,8 y 8,1 s.
	rig.sync(0.5)
	var early: float = rig.pistons[0].position.y
	rig.sync(3.5)
	var late: float = rig.pistons[0].position.y
	_check("el primer pistón sube 1,56 m (%.2f → %.2f)" % [early, late],
		early < 0.05 and late > 1.3)
	rig.sync(8.2)
	var all_up := true
	for piston: Node3D in rig.pistons:
		all_up = all_up and piston.position.y > 1.5
	_check("los cuatro pistones acaban arriba", all_up)

	# 4. Pestillos: de 4,3 a 9,7 s.
	rig.sync(4.0)
	var dog_early: float = rig.dogs[0].position.y
	rig.sync(6.0)
	var dog_late: float = rig.dogs[0].position.y
	_check("el pestillo 1 se libera (%.2f → %.2f)" % [dog_early, dog_late], dog_early < 0.05 and dog_late > 0.9)

	# 5. Corona: 2,3 vueltas entre 8,8 y 13,9 s.
	rig.sync(9.0)
	var spin_early: float = rig.wheel.rotation.z
	rig.sync(14.0)
	var spin_late: float = rig.wheel.rotation.z
	_check("la corona gira 2,3 vueltas (%.2f rad)" % absf(spin_late - spin_early),
		absf(absf(spin_late) - 2.3 * PI) < 0.2)
	_check("gira en el sentido de la web", spin_late < 0.0)

	# 6. Disco: empuje de 1,32 m y traslado de −6,25 m.
	rig.sync(16.2)
	_check("el disco sale 1,32 m (z = %.2f)" % rig.disk.position.z,
		absf(rig.disk.position.z - (VaultDoorRig.DISK_HOME_Z + VaultDoorRig.DISK_PUSH)) < 0.02)
	_check("aún no se ha trasladado (x = %.2f)" % rig.disk.position.x, absf(rig.disk.position.x) < 0.02)
	rig.sync(22.0)
	_check("el disco se traslada a −6,25 m (x = %.2f)" % rig.disk.position.x,
		absf(rig.disk.position.x - VaultDoorRig.DISK_SLIDE) < 0.02)
	_check("la bóveda queda abierta", rig.opened and rig.phase == "Abierta")

	# 7. Fases con los umbrales de la web.
	_check("fase a los 0,3 s", VaultDoorRig._phase_for(0.3) == "Validando")
	_check("fase a los 3 s", VaultDoorRig._phase_for(3.0) == "Retirando cerrojos")
	_check("fase a los 7 s", VaultDoorRig._phase_for(7.0) == "Liberando pestillos")
	_check("fase a los 11 s", VaultDoorRig._phase_for(11.0) == "Girando corona")
	_check("fase a los 15 s", VaultDoorRig._phase_for(15.0) == "Despresurizando")
	_check("fase a los 18 s", VaultDoorRig._phase_for(18.0) == "Traslado hidráulico")

	# 8. Vuelta atrás limpia.
	rig.reset()
	_check("el reset devuelve todo a cero",
		rig.time < 0.0 and absf(rig.disk.position.z - VaultDoorRig.DISK_HOME_Z) < 0.001
		and absf(rig.disk.position.x) < 0.001 and absf(rig.wheel.rotation.z) < 0.001
		and rig.dogs[0].position.y < 0.001)
	rig.sync(-1.0)
	_check("sync(-1) deja la puerta sellada", rig.phase == "Sellada")

	print(JSON.stringify({"checks": checks, "failures": failures, "passed": failures.is_empty()}))
	root.queue_free()
	quit(0 if failures.is_empty() else 1)
