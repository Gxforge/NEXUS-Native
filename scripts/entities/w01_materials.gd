class_name W01Materials
extends RefCounted
## Ajuste de los materiales metálicos de W–01.
##
## Los `.glb` exportados de la web traen los tentáculos y los párpados con
## `metallic = 1.0`. La escena de three.js tenía un mapa de entorno que les daba
## reflejo; aquí, sin él, un metal puro se ve negro y el organismo quedaba en
## silueta. Se rebaja el metal a un 22 % y se sube la aspereza mínima para que la
## carne (`#82656c`, `#a5767e`) recupere su color.

const METALLIC_LIMIT := 0.6
const METALLIC_SOFT := 0.22
const ROUGHNESS_FLOOR := 0.42


## Recorre un subárbol y suaviza los materiales metálicos. Devuelve cuántas
## superficies se ajustaron.
static func soften(root_node: Node) -> int:
	var cache := {}
	var changed := 0
	var stack: Array[Node] = [root_node]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		var mesh := node as MeshInstance3D
		if mesh != null and mesh.mesh != null:
			for surface in mesh.mesh.get_surface_count():
				var material := mesh.get_surface_override_material(surface) as BaseMaterial3D
				if material == null:
					material = mesh.mesh.surface_get_material(surface) as BaseMaterial3D
				if material == null or material.metallic <= METALLIC_LIMIT:
					continue
				var key := material.get_instance_id()
				if cache.has(key):
					mesh.set_surface_override_material(surface, cache[key] as Material)
					changed += 1
					continue
				var softened := material.duplicate() as BaseMaterial3D
				softened.metallic = METALLIC_SOFT
				softened.roughness = maxf(softened.roughness, ROUGHNESS_FLOOR)
				cache[key] = softened
				mesh.set_surface_override_material(surface, softened)
				changed += 1
		for child in node.get_children():
			stack.push_back(child)
	return changed
