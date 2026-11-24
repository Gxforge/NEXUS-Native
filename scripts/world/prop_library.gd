class_name PropLibrary
extends RefCounted
## Modelos originales de la web (`assets/generated/source-batch/`).
##
## Los `.glb` de `source-batch` son exportaciones directas de la escena de
## three.js: cada grupo conserva la transformación que tenía en el laboratorio
## original, incluidos los vasos de observación (`workshop_pods.glb`), la puerta
## de la bóveda (`vault.glb`) y los puestos de mando (`vault.glb`).
##
## Se cargan una sola vez y se reparten los grupos; la raíz exportada se libera
## para no dejar duplicados en memoria.

const BATCH := "res://assets/generated/source-batch/"

static var _cache := {}


## Grupos de primer nivel de un lote, ya separados de la escena exportada.
## Devuelve `{nombre: Node3D}` con las transformaciones originales intactas.
static func groups(asset: String) -> Dictionary:
	if _cache.has(asset):
		return _cache[asset] as Dictionary
	var packed := load(BATCH + asset + ".glb") as PackedScene
	var found := {}
	if packed != null:
		var root: Node = packed.instantiate()
		var wrapper: Node = root.get_child(0) if root.get_child_count() > 0 else root
		for child in wrapper.get_children():
			var node := child as Node3D
			if node == null:
				continue
			wrapper.remove_child(node)
			found[String(node.name)] = node
		root.free()
	_cache[asset] = found
	return found


## Vasos de observación de H–01, en el orden de la web (z = −66,6 / −62 / −57,4).
static func pods() -> Array[Node3D]:
	var result: Array[Node3D] = []
	var found := groups("workshop_pods")
	for key in ["Node2", "Node15", "Node29"]:
		var node := found.get(key) as Node3D
		if node != null:
			result.append(node)
	return result


## Puerta de la bóveda V–03 tal como se modeló en la web (grupo `Node2`).
static func vault_door() -> Node3D:
	var found := groups("vault")
	return found.get("Node2") as Node3D


## Grupo suelto de un lote (`null` si el lote no lo trae).
static func group(asset: String, key: String) -> Node3D:
	return groups(asset).get(key) as Node3D
