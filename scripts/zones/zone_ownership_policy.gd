class_name ZoneOwnershipPolicy
extends RefCounted

const SHARED: StringName = &"shared_infrastructure"
const CONNECTION: StringName = &"zone_connection"

## Canonical footprints of the twelve laboratory modules, mirrored from
## `data/zone_graph.json` (Environment.ts world meters). `validate_zone_ownership`
## keeps both sources in sync.
const BOUNDS: Dictionary = {
	&"c04": Rect2(-36.0, -14.0, 72.0, 84.0),
	&"a01": Rect2(-36.0, -38.0, 36.0, 24.0),
	&"b02": Rect2(0.0, -38.0, 36.0, 24.0),
	&"surveillance": Rect2(-36.0, 52.2, 18.7, 17.8),
	&"electrical": Rect2(17.3, 44.2, 18.7, 25.8),
	&"transit_hub": Rect2(-36.0, 70.0, 72.0, 26.0),
	&"transit_road": Rect2(-21.0, 96.0, 27.1, 2000.0),
	&"transit_rail": Rect2(6.1, 96.0, 14.9, 2000.0),
	&"v03_gallery": Rect2(14.0, -96.0, 8.0, 58.0),
	&"h01": Rect2(-36.0, -96.0, 50.0, 58.0),
	&"d02": Rect2(22.0, -96.0, 15.0, 58.0),
	&"v03_cryo": Rect2(4.0, -114.0, 32.0, 18.0),
}

const FUNCTIONAL_SHARED: Dictionary = {
	"Transit": &"transit_controller",
	"TransitHub": &"transit_controller",
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
