#!/usr/bin/env python3
"""Deterministic NEXUS laboratory zone module generator.

Single source of truth for the twelve laboratory zones: structural shell
manifests, shell GLBs, zone scenes, door sockets and the runtime zone graph.

Everything is authored in world meters (Environment.ts frame) and converted to
the Godot zone frame with `local = world + (9, 0, 14)`, the same convention used
by the first C-04 / A-01 shells.

Socket naming: the socket of zone X at its door to zone Y is `from_<Y>`, so the
portal in X targets `from_<X>` inside Y. The legacy C-04/A-01 pair keeps its
original `to_a01` / `from_c04` names for backward compatibility.
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from export_nexus_geometry import export as export_glb  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
SOURCE_COMMIT = "f4e1e819a9c783374e79dbc99cde4597099aba11"
WORLD_ORIGIN = (9.0, 0.0, 14.0)
WALL = 0.5
DOOR_WIDTH = 4.4
DOOR_TOP = 4.4
DOOR_SOCKET_INSET = 1.6
LEGACY_SOCKETS = {("c04", "a01"): "to_a01"}
GENERATED_SCENES = False  # set from --scenes; C-04/A-01 scenes are hand maintained

MATERIALS = {
    "floor": {"base_color": "#202323", "metallic": 0.18, "roughness": 0.72},
    "concrete": {"base_color": "#515957", "metallic": 0.12, "roughness": 0.70},
    "metal": {"base_color": "#2B3A3E", "metallic": 0.55, "roughness": 0.45},
    "hydraulic": {"base_color": "#3A4A46", "metallic": 0.35, "roughness": 0.55},
    "transit": {"base_color": "#262B30", "metallic": 0.42, "roughness": 0.50},
}

ZONES = [
    {"id": "c04", "scene": "res://zones/zone_c04_shell.tscn", "node": "C04StructuralSlice",
     "name": "C-04 · Contención", "rect": (-36.0, -14.0, 36.0, 70.0), "height": 9.2,
     "wall": "concrete", "light_energy": 12.0, "hull_of": ["surveillance", "electrical"],
     "partitions": [
         {"name": "surveillance_partition", "boundary": 52.2, "axis": "x",
          "from": -36.0, "to": -17.3, "doors": [-26.0]},
         {"name": "electrical_partition", "boundary": 44.2, "axis": "x",
          "from": 17.3, "to": 36.0, "doors": [26.0]},
     ]},
    {"id": "a01", "scene": "res://zones/zone_a01_shell.tscn", "node": "A01StructuralSlice",
     "name": "A-01 · Archivo", "rect": (-36.0, -38.0, 0.0, -14.0), "height": 9.2,
     "wall": "concrete", "light_energy": 10.0},
    {"id": "b02", "scene": "res://zones/zone_b02_turbines.tscn", "node": "B02StructuralSlice",
     "name": "B-02 · Turbinas", "rect": (0.0, -38.0, 36.0, -14.0), "height": 9.2,
     "wall": "concrete", "light_energy": 10.0,
     "lights": [(9.0, 0.0, -26.0, 10.0), (27.0, 0.0, -26.0, 8.0)],
     "pickups": [{"item": "cell", "label": "Celda de carga B-02", "offset": (12.0, -30.0)}]},
    {"id": "surveillance", "scene": "res://zones/zone_surveillance.tscn", "node": "SurveillanceSlice",
     "name": "Vigilancia", "rect": (-36.0, 52.2, -17.3, 70.0), "height": 9.2,
     "wall": "concrete", "light_energy": 7.0},
    {"id": "electrical", "scene": "res://zones/zone_electrical.tscn", "node": "ElectricalSlice",
     "name": "Electricidad", "rect": (17.3, 44.2, 36.0, 70.0), "height": 9.2,
     "wall": "metal", "light_energy": 8.0,
     "pickups": [{"item": "cell", "label": "Celda de respaldo E-07", "offset": (26.0, 60.0)}]},
    {"id": "transit_hub", "scene": "res://zones/zone_transit_hub.tscn", "node": "TransitHubSlice",
     "name": "Transit · Hub L-01", "rect": (-36.0, 70.0, 36.0, 96.0), "height": 9.2,
     "wall": "transit", "light_energy": 9.0},
    {"id": "transit_road", "scene": "res://zones/zone_transit_road.tscn", "node": "TransitRoadSlice",
     "name": "Transit · Carretera", "rect": (-21.0, 96.0, 6.1, 2096.0), "height": 6.0,
     "wall": "transit", "light_energy": 6.0, "light_step": 120.0},
    {"id": "transit_rail", "scene": "res://zones/zone_transit_rail.tscn", "node": "TransitRailSlice",
     "name": "Transit · Vía", "rect": (6.1, 96.0, 21.0, 2096.0), "height": 6.0,
     "wall": "transit", "light_energy": 6.0, "light_step": 120.0},
    {"id": "v03_gallery", "scene": "res://zones/zone_v03_gallery.tscn", "node": "V03GallerySlice",
     "name": "Galería V-03", "rect": (14.0, -96.0, 22.0, -38.0), "height": 4.4,
     "wall": "metal", "light_energy": 6.0, "light_step": 20.0,
     "pickups": [{"item": "sample", "label": "Muestra V-03", "offset": (18.0, -66.0)}]},
    {"id": "h01", "scene": "res://zones/zone_h01_hydraulics.tscn", "node": "H01StructuralSlice",
     "name": "H-01 · Hidráulica", "rect": (-36.0, -96.0, 14.0, -38.0), "height": 9.2,
     "wall": "hydraulic", "light_energy": 9.0,
     "lights": [(-20.0, 0.0, -67.0, 8.0), (0.0, 0.0, -67.0, 8.0), (-20.0, 0.0, -86.0, 8.0)]},
    {"id": "d02", "scene": "res://zones/zone_d02_records.tscn", "node": "D02StructuralSlice",
     "name": "D-02 · Registros", "rect": (22.0, -96.0, 37.0, -38.0), "height": 9.2,
     "wall": "concrete", "light_energy": 8.0,
     "pickups": [{"item": "recorder", "label": "Bitácora de custodia D-02", "offset": (29.5, -72.0)}]},
    {"id": "v03_cryo", "scene": "res://zones/zone_v03_cryotheque.tscn", "node": "V03CryoSlice",
     "name": "Crioteca V-03", "rect": (4.0, -114.0, 36.0, -96.0), "height": 7.0,
     "wall": "metal", "light_energy": 8.0,
     "pickups": [{"item": "card", "label": "Credencial V-03", "offset": (20.0, -110.0)}]},
]

# Perimeter doors: (zone, wall, offset along the wall axis, destination zone)
DOORS = [
    ("c04", "south", -9.0, "a01"),
    ("c04", "south", 9.0, "b02"),
    ("c04", "north", 0.0, "transit_hub"),
    ("a01", "north", -9.0, "c04"),
    ("b02", "north", 9.0, "c04"),
    ("b02", "south", 18.0, "v03_gallery"),
    ("surveillance", "south", -26.0, "c04"),
    ("electrical", "south", 26.0, "c04"),
    ("transit_hub", "south", 0.0, "c04"),
    ("transit_hub", "north", -7.5, "transit_road"),
    ("transit_hub", "north", 13.5, "transit_rail"),
    ("transit_road", "south", -7.5, "transit_hub"),
    ("transit_rail", "south", 13.5, "transit_hub"),
    ("v03_gallery", "north", 18.0, "b02"),
    ("v03_gallery", "west", -62.0, "h01"),
    ("v03_gallery", "east", -82.0, "d02"),
    ("v03_gallery", "south", 18.0, "v03_cryo"),
    ("h01", "east", -62.0, "v03_gallery"),
    ("d02", "west", -82.0, "v03_gallery"),
    ("v03_cryo", "north", 18.0, "v03_gallery"),
]

# Doors hosted by an internal partition of the host hull (C-04 hall):
# (zone, world position, portal yaw, destination zone)
PARTITION_DOORS = [
    ("c04", (-26.0, 52.2), 180.0, "surveillance"),
    ("c04", (26.0, 44.2), 180.0, "electrical"),
]

WALL_ROTATION = {"south": 0.0, "north": 180.0, "west": 90.0, "east": -90.0}


def zone_by_id(zone_id: str) -> dict:
    for zone in ZONES:
        if zone["id"] == zone_id:
            return zone
    raise KeyError(zone_id)


def socket_name(zone_id: str, peer_id: str) -> str:
    return LEGACY_SOCKETS.get((zone_id, peer_id), "from_%s" % peer_id)


def local(value: float, axis: int) -> float:
    return round(value + WORLD_ORIGIN[axis], 4)


def to_local_vector(x: float, y: float, z: float) -> list[float]:
    return [local(x, 0), round(y, 4), local(z, 2)]


def door_table() -> list[dict]:
    """Unified door table with explicit world position, portal yaw and sockets."""
    table: list[dict] = []
    for zone_id, wall, offset, dest in DOORS:
        zone = zone_by_id(zone_id)
        x0, z0, x1, z1 = zone["rect"]
        if wall == "south":
            position = (offset, z0)
        elif wall == "north":
            position = (offset, z1)
        elif wall == "west":
            position = (x0, offset)
        else:
            position = (x1, offset)
        table.append({
            "zone": zone_id, "dest": dest, "wall": wall, "offset": offset,
            "x": position[0], "z": position[1], "rot": WALL_ROTATION[wall],
        })
    for zone_id, position, rotation, dest in PARTITION_DOORS:
        table.append({
            "zone": zone_id, "dest": dest, "wall": None, "offset": position[1],
            "x": position[0], "z": position[1], "rot": rotation,
        })
    return table


def socket_world(door: dict) -> tuple[float, float]:
    """Socket 1.6 m inside the owning zone, opposite to the crossing direction.

    The crossing direction of a portal is its local -Z axis, i.e.
    `(-sin(yaw), -cos(yaw))`, so the inward direction is `(sin(yaw), cos(yaw))`.
    """
    import math
    yaw = math.radians(door["rot"])
    return (door["x"] + math.sin(yaw) * DOOR_SOCKET_INSET,
            door["z"] + math.cos(yaw) * DOOR_SOCKET_INSET)


def wall_segments(start: float, end: float, doors: list[float], width: float) -> list[tuple[float, float]]:
    segments: list[tuple[float, float]] = []
    cursor = start
    for center in sorted(doors):
        low = center - width * 0.5
        high = center + width * 0.5
        if low - cursor > 0.05:
            segments.append((cursor, low))
        cursor = max(cursor, high)
    if end - cursor > 0.05:
        segments.append((cursor, end))
    return segments


def build_manifest(zone: dict) -> dict:
    x0, z0, x1, z1 = zone["rect"]
    height = zone["height"]
    wall_material = zone["wall"]
    cx, cz = (x0 + x1) * 0.5, (z0 + z1) * 0.5
    boxes: list[dict] = []
    doors = [door for door in door_table() if door["zone"] == zone["id"]]
    by_wall: dict[str, list[float]] = {"south": [], "north": [], "west": [], "east": []}
    for door in doors:
        if door["wall"] is not None:
            by_wall[door["wall"]].append(door["offset"])

    def add(name: str, center: tuple[float, float, float], size: tuple[float, float, float], material: str) -> None:
        boxes.append({
            "name": name,
            "center": [round(v, 4) for v in to_local_vector(*center)],
            "size": [round(v, 4) for v in size],
            "material": material,
        })

    add("floor", (cx, -0.2, cz), (x1 - x0, 0.4, z1 - z0), "floor")
    add("ceiling", (cx, height + 0.2, cz), (x1 - x0 + 0.6, 0.4, z1 - z0 + 0.6), wall_material)

    for wall in ("south", "north"):
        boundary = z0 if wall == "south" else z1
        for index, (start, end) in enumerate(wall_segments(x0, x1, by_wall[wall], DOOR_WIDTH)):
            add("%s_wall_%d" % (wall, index), ((start + end) * 0.5, height * 0.5, boundary),
                (end - start, height, WALL), wall_material)
        for index, center in enumerate(sorted(by_wall[wall])):
            add("%s_header_%d" % (wall, index), (center, DOOR_TOP + (height - DOOR_TOP) * 0.5, boundary),
                (DOOR_WIDTH, height - DOOR_TOP, WALL), wall_material)

    for wall in ("west", "east"):
        boundary = x0 if wall == "west" else x1
        for index, (start, end) in enumerate(wall_segments(z0, z1, by_wall[wall], DOOR_WIDTH)):
            add("%s_wall_%d" % (wall, index), (boundary, height * 0.5, (start + end) * 0.5),
                (WALL, height, end - start), wall_material)
        for index, center in enumerate(sorted(by_wall[wall])):
            add("%s_header_%d" % (wall, index), (boundary, DOOR_TOP + (height - DOOR_TOP) * 0.5, center),
                (WALL, height - DOOR_TOP, DOOR_WIDTH), wall_material)

    for partition in zone.get("partitions", []):
        axis = partition["axis"]
        boundary = partition["boundary"]
        span_from = partition["from"]
        span_to = partition["to"]
        for index, (start, end) in enumerate(wall_segments(span_from, span_to, partition.get("doors", []), DOOR_WIDTH)):
            if axis == "x":
                add("%s_%d" % (partition["name"], index), ((start + end) * 0.5, height * 0.5, boundary),
                    (end - start, height, WALL), wall_material)
            else:
                add("%s_%d" % (partition["name"], index), (boundary, height * 0.5, (start + end) * 0.5),
                    (WALL, height, end - start), wall_material)
        for index, center in enumerate(sorted(partition.get("doors", []))):
            if axis == "x":
                add("%s_header_%d" % (partition["name"], index),
                    (center, DOOR_TOP + (height - DOOR_TOP) * 0.5, boundary),
                    (DOOR_WIDTH, height - DOOR_TOP, WALL), wall_material)
            else:
                add("%s_header_%d" % (partition["name"], index),
                    (boundary, DOOR_TOP + (height - DOOR_TOP) * 0.5, center),
                    (WALL, height - DOOR_TOP, DOOR_WIDTH), wall_material)

    door_meta = []
    for door in doors:
        socket_x, socket_z = socket_world(door)
        door_meta.append({
            "name": "%s_to_%s" % (door["zone"], door["dest"]),
            "wall": door["wall"] or "partition",
            "world_position": [round(door["x"], 4), round(door["z"], 4)],
            "portal_yaw": door["rot"],
            "width": DOOR_WIDTH,
            "socket": socket_name(door["zone"], door["dest"]),
            "socket_world": [round(socket_x, 4), round(socket_z, 4)],
            "target_zone": door["dest"],
            "target_socket": socket_name(door["dest"], door["zone"]),
        })

    centers = [box["center"] for box in boxes]
    halves = [[value * 0.5 for value in box["size"]] for box in boxes]
    bounds_min = [round(min(c[i] - h[i] for c, h in zip(centers, halves)), 4) for i in range(3)]
    bounds_max = [round(max(c[i] + h[i] for c, h in zip(centers, halves)), 4) for i in range(3)]

    return {
        "asset_id": "%s_structural_shell" % zone["id"],
        "generator_version": 2,
        "source_commit": SOURCE_COMMIT,
        "source_files": ["src/scene/Environment.ts", "src/scene/Sectors.ts", "src/scene/ZoneGates.ts"],
        "coordinate_frame": {"world_origin": list(WORLD_ORIGIN), "local_from_world": "x+9, y, z+14", "units": "meters"},
        "world_rect": list(zone["rect"]),
        "height": height,
        "doors": door_meta,
        "boxes": boxes,
        "materials": {name: MATERIALS[name] for name in sorted({box["material"] for box in boxes})},
        "expected_bounds": {"min": bounds_min, "max": bounds_max},
        "expected_collisions": len(boxes),
    }


def _num(value: float) -> str:
    text = "%.4f" % float(value)
    text = text.rstrip("0").rstrip(".")
    return "0" if text in ("-0", "") else text


def vec3(values) -> str:
    return "Vector3(%s, %s, %s)" % tuple(_num(value) for value in values)


def zone_lights(zone: dict) -> list[tuple[float, float, float, float]]:
    if "lights" in zone:
        return zone["lights"]
    x0, z0, x1, z1 = zone["rect"]
    cx = (x0 + x1) * 0.5
    step = zone.get("light_step", 0.0)
    if not step:
        return [(cx, 0.0, (z0 + z1) * 0.5, zone["light_energy"])]
    lights = []
    position = z0 + step * 0.5
    while position < z1:
        lights.append((cx, 0.0, position, zone["light_energy"]))
        position += step
    return lights


def scene_text(zone: dict) -> str:
    zone_id = zone["id"]
    doors = [door for door in door_table() if door["zone"] == zone_id]
    resources: list[str] = [
        '[ext_resource type="Script" path="res://scripts/zones/zone_root.gd" id="1"]',
        '[ext_resource type="Script" path="res://scripts/zones/structural_shell.gd" id="2"]',
        '[ext_resource type="PackedScene" path="res://assets/generated/%s_structural_shell.glb" id="3"]' % zone_id,
    ]
    portal_rid = None
    pickup_rid = None
    if doors:
        portal_rid = str(len(resources) + 1)
        resources.append('[ext_resource type="PackedScene" path="res://scenes/validation/a01_portal_assembly.tscn" id="%s"]' % portal_rid)
    pickups = zone.get("pickups", [])
    if pickups:
        pickup_rid = str(len(resources) + 1)
        resources.append('[ext_resource type="PackedScene" path="res://scenes/entities/field_flashlight.tscn" id="%s"]' % pickup_rid)

    lines: list[str] = ["[gd_scene load_steps=%d format=3]" % (len(resources) + 1), ""]
    lines.extend(resources)
    lines.append("")
    lines.append('[node name="%s" type="Node3D"]' % zone["node"])
    lines.append('script = ExtResource("1")')
    lines.append('zone_id = &"%s"' % zone_id)
    lines.append("")
    lines.append('[node name="StructuralShell" type="Node3D" parent="."]')
    lines.append('script = ExtResource("2")')
    lines.append('manifest_path = "res://manifests/migration/%s_structural_shell.json"' % zone_id)
    lines.append('[node name="Visual" parent="StructuralShell" instance=ExtResource("3")]')
    lines.append("")

    for door in doors:
        dest = door["dest"]
        node_name = "Portal" + "".join(part.capitalize() for part in dest.split("_"))
        lines.append('[node name="%s" parent="." instance=ExtResource("%s")]' % (node_name, portal_rid))
        lines.append("position = %s" % vec3((local(door["x"], 0), 0.0, local(door["z"], 2))))
        if abs(door["rot"]) > 0.001:
            lines.append("rotation_degrees = %s" % vec3((0.0, door["rot"], 0.0)))
        lines.append('target_zone = &"%s"' % dest)
        lines.append('target_socket = &"%s"' % socket_name(dest, zone_id))
        lines.append("")

    lines.append('[node name="DoorSockets" type="Node3D" parent="."]')
    x0, z0, _x1, _z1 = zone["rect"]
    lines.append('[node name="entry" type="Marker3D" parent="DoorSockets"]')
    lines.append("position = %s" % vec3(to_local_vector(x0 + 6.0, 1.1, z0 + 6.0)))
    lines.append("")
    for door in doors:
        socket_x, socket_z = socket_world(door)
        rotation = (door["rot"] + 180.0) % 360.0
        lines.append('[node name="%s" type="Marker3D" parent="DoorSockets"]' % socket_name(zone_id, door["dest"]))
        lines.append("position = %s" % vec3((local(socket_x, 0), 1.1, local(socket_z, 2))))
        lines.append("rotation_degrees = %s" % vec3((0.0, rotation, 0.0)))
        lines.append("")

    for index, (light_x, _light_y, light_z, energy) in enumerate(zone_lights(zone)):
        lines.append('[node name="LocalLight%d" type="OmniLight3D" parent="."]' % index)
        lines.append("position = %s" % vec3((local(light_x, 0), max(2.4, zone["height"] - 2.2), local(light_z, 2))))
        lines.append("omni_range = %s" % _num(26.0 if zone.get("light_step") else 32.0))
        lines.append("light_color = Color(0.62, 0.83, 0.87, 1)")
        lines.append("light_energy = %s" % _num(energy))
        lines.append("")

    for index, pickup in enumerate(pickups):
        pickup_x, pickup_z = pickup["offset"]
        lines.append('[node name="Pickup%d" parent="." instance=ExtResource("%s")]' % (index, pickup_rid))
        lines.append("position = %s" % vec3((local(pickup_x, 0), 0.0, local(pickup_z, 2))))
        lines.append('item_id = &"%s"' % pickup["item"])
        lines.append('display_name = "%s"' % pickup["label"])
        lines.append("")

    return "\n".join(lines).rstrip() + "\n"


def build_graph() -> dict:
    zones = []
    for zone in ZONES:
        x0, z0, x1, z1 = zone["rect"]
        zones.append({
            "id": zone["id"],
            "scene": zone["scene"],
            "display_name": zone["name"],
            "bounds": {"min": [x0, z0], "max": [x1, z1]},
            "height": zone["height"],
            "entry_socket": "entry",
            "entry_world": [round(x0 + 6.0, 4), round(z0 + 6.0, 4)],
            "hull_of": zone.get("hull_of", []),
        })
    connections = []
    table = door_table()
    for door in sorted(table, key=lambda item: (item["zone"], item["dest"])):
        if door["zone"] > door["dest"]:
            continue
        peer = next((candidate for candidate in table
                     if candidate["zone"] == door["dest"] and candidate["dest"] == door["zone"]
                     and abs(candidate["x"] - door["x"]) < 0.001 and abs(candidate["z"] - door["z"]) < 0.001), None)
        if peer is None:
            raise SystemExit("unpaired door %s -> %s" % (door["zone"], door["dest"]))
        connections.append({
            "id": "%s_%s" % (door["zone"], door["dest"]),
            "from_zone": door["zone"],
            "from_socket": socket_name(door["zone"], door["dest"]),
            "to_zone": door["dest"],
            "to_socket": socket_name(door["dest"], door["zone"]),
            "world_door": [door["x"], door["z"]],
            "portal_yaw_from": door["rot"],
            "portal_yaw_to": peer["rot"],
            "width": DOOR_WIDTH,
            "bidirectional": True,
        })
    return {
        "schema": 1,
        "source_commit": SOURCE_COMMIT,
        "coordinate_frame": {"world_origin": list(WORLD_ORIGIN), "local_from_world": "x+9, y, z+14", "units": "meters"},
        "zones": zones,
        "connections": connections,
    }


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--scenes", action="store_true", help="also regenerate the ten generated zone scenes")
    parser.add_argument("--graph-only", action="store_true")
    args = parser.parse_args()
    reports = []
    if not args.graph_only:
        for zone in ZONES:
            manifest = build_manifest(zone)
            manifest_path = ROOT / "manifests" / "migration" / ("%s_structural_shell.json" % zone["id"])
            manifest_path.parent.mkdir(parents=True, exist_ok=True)
            manifest_path.write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
            glb_path = ROOT / "assets" / "generated" / ("%s_structural_shell.glb" % zone["id"])
            report = export_glb(manifest_path, glb_path)
            report["zone"] = zone["id"]
            report["collisions"] = manifest["expected_collisions"]
            reports.append(report)
            if args.scenes and zone["id"] not in ("c04", "a01"):
                scene_path = ROOT / zone["scene"].replace("res://", "")
                scene_path.parent.mkdir(parents=True, exist_ok=True)
                scene_path.write_text(scene_text(zone), encoding="utf-8")
    graph = build_graph()
    graph_path = ROOT / "data" / "zone_graph.json"
    graph_path.parent.mkdir(parents=True, exist_ok=True)
    graph_path.write_text(json.dumps(graph, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(json.dumps({
        "zones": len(ZONES),
        "doors": len(door_table()),
        "connections": len(graph["connections"]),
        "glb_bytes": sum(report["bytes"] for report in reports),
        "outputs": reports,
    }, indent=2))


if __name__ == "__main__":
    main()
