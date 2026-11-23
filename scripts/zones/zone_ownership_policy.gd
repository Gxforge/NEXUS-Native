class_name ZoneOwnershipPolicy
extends RefCounted

const SHARED: StringName = &"shared_infrastructure"
const CONNECTION: StringName = &"zone_connection"

const BOUNDS: Dictionary = {
	&"electricidad": Rect2(-36.0, 52.44, 18.54, 17.56),
	&"vigilancia": Rect2(17.46, 44.44, 18.54, 25.56),
	&"turbinas": Rect2(1.0, -70.0, 12.85, 16.0),
	&"registros": Rect2(22.15, -90.0, 14.85, 16.0),
	&"crioteca": Rect2(9.0, -112.0, 18.0, 15.84),
	&"c04": Rect2(-36.0, -38.0, 35.75, 23.68),
	&"a01": Rect2(0.25, -38.0, 35.75, 23.68),
	&"galeria": Rect2(14.0, -95.9, 8.0, 57.7),
}

const FUNCTIONAL_SHARED: Dictionary = {
	"Transit": &"transit_controller",
	"ZoneGates": CONNECTION,
	"Facility": SHARED,
	"Operations": &"operations_controller",
	"Vault": &"vault_controller",
}

static func zones_overlapping(box: AABB) -> Array[StringName]:
	var result: Array[StringName] = []
	var footprint := Rect2(box.position.x, box.position.z, box.size.x, box.size.z)
	for zone_id: StringName in BOUNDS:
		var bounds: Rect2 = BOUNDS[zone_id]
		if bounds.intersects(footprint, true):
			result.append(zone_id)
	result.sort()
	return result

static func owner_for(box: AABB, functional_root: String = "") -> StringName:
	if FUNCTIONAL_SHARED.has(functional_root):
		return FUNCTIONAL_SHARED[functional_root]
	var overlaps := zones_overlapping(box)
	if overlaps.size() == 1:
		return overlaps[0]
	if overlaps.size() > 1:
		return CONNECTION
	return SHARED
