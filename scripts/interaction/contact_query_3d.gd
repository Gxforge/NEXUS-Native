class_name ContactQuery3D
extends RefCounted

const DEFAULT_MASK: int = 0xFFFFFFFF

static func first_hit(
	world: World3D,
	from: Vector3,
	to: Vector3,
	exclude: Array[RID] = [],
	collision_mask: int = DEFAULT_MASK,
	collide_with_areas: bool = true,
) -> Dictionary:
	if world == null or from.is_equal_approx(to):
		return {}
	var query := PhysicsRayQueryParameters3D.create(from, to, collision_mask, exclude)
	query.collide_with_areas = collide_with_areas
	query.collide_with_bodies = true
	query.hit_back_faces = true
	return world.direct_space_state.intersect_ray(query)

static func contact_normal(hit: Dictionary) -> Vector3:
	return hit.get("normal", Vector3.ZERO) as Vector3

static func contact_position(hit: Dictionary) -> Vector3:
	return hit.get("position", Vector3.ZERO) as Vector3
