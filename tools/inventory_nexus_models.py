#!/usr/bin/env python3
"""Inventory procedural NEXUS 15.1 geometry/texture producers without modifying source."""
from __future__ import annotations
import argparse, hashlib, json, re
from collections import Counter
from pathlib import Path

GEOMETRY = re.compile(r"new\s+(?:(?:THREE|T)\.)?([A-Za-z]+Geometry)\s*\(")
CUSTOM = re.compile(r"new\s+(?:(?:THREE|T)\.)?BufferGeometry\s*\(")
TEXTURE = re.compile(r"new\s+(?:(?:THREE|T)\.)?(CanvasTexture|DataTexture|TextureLoader)\s*\(")
MATERIAL = re.compile(r"new\s+(?:(?:THREE|T)\.)?((?:Mesh|Points|Line)[A-Za-z]*Material)\s*\(")
MESH = re.compile(r"new\s+(?:(?:THREE|T)\.)?(Mesh|InstancedMesh|Points|Line|LineSegments)\s*\(")
PROCEDURAL = re.compile(r"\b(Math\.random|morphAttributes|setAttribute|mergeGeometries|computeVertexNormals|TubeGeometry|ExtrudeGeometry|TextGeometry)\b")


def line_numbers(pattern: re.Pattern[str], text: str) -> list[int]:
    return [text.count("\n", 0, match.start()) + 1 for match in pattern.finditer(text)]


def inventory(source: Path) -> dict:
    files = []
    totals: Counter[str] = Counter()
    for path in sorted([*source.glob("src/**/*.ts"), *source.glob("src/**/*.tsx")]):
        text = path.read_text(encoding="utf-8")
        geometries = Counter(GEOMETRY.findall(text))
        textures = Counter(TEXTURE.findall(text))
        materials = Counter(MATERIAL.findall(text))
        meshes = Counter(MESH.findall(text))
        if not (geometries or textures or materials or meshes or CUSTOM.search(text)):
            continue
        record = {
            "source_file": path.relative_to(source).as_posix(),
            "sha256": hashlib.sha256(text.encode()).hexdigest(),
            "geometry_constructors": dict(sorted(geometries.items())),
            "geometry_constructor_lines": line_numbers(GEOMETRY, text),
            "custom_buffer_geometries": len(CUSTOM.findall(text)),
            "texture_constructors": dict(sorted(textures.items())),
            "material_constructors": dict(sorted(materials.items())),
            "render_objects": dict(sorted(meshes.items())),
            "uses_math_random": "Math.random" in text,
            "dynamic_or_procedural": bool(PROCEDURAL.search(text)),
        }
        files.append(record)
        totals.update({f"geometry:{k}": v for k, v in geometries.items()})
        totals.update({f"texture:{k}": v for k, v in textures.items()})
        totals.update({f"material:{k}": v for k, v in materials.items()})
        totals["custom_buffer_geometries"] += record["custom_buffer_geometries"]
        totals["render_object_constructors"] += sum(meshes.values())
    return {
        "schema": 1,
        "source_commit": "f4e1e819a9c783374e79dbc99cde4597099aba11",
        "source_root_policy": "read-only",
        "coordinate_policy": "Y-up; source units retained as metres; validate Z orientation per asset",
        "files_with_model_or_material_code": len(files),
        "totals": dict(sorted(totals.items())),
        "files": files,
    }


def markdown(data: dict) -> str:
    rows = []
    for item in data["files"]:
        gs = ", ".join(f"{k}×{v}" for k, v in item["geometry_constructors"].items()) or "custom/indirect"
        ts = ", ".join(f"{k}×{v}" for k, v in item["texture_constructors"].items()) or "—"
        flags = ", ".join(x for x, yes in (("dynamic", item["dynamic_or_procedural"]), ("random", item["uses_math_random"])) if yes) or "static"
        rows.append(f"| `{item['source_file']}` | {gs} | {item['custom_buffer_geometries']} | {ts} | {flags} |")
    return "\n".join([
        "# Inventario procedural de modelos NEXUS 15.1", "",
        f"Fuente inmutable: `{data['source_commit']}`. Este documento se genera; el JSON conserva hashes y líneas de procedencia.", "",
        "## Regla de exportación", "",
        "Cada familia se exportará a GLB con materiales PBR, texturas PNG deterministas, pivotes y jerarquía. Las piezas dinámicas conservarán malla base y datos necesarios para reconstruir morphs, skin/spline o instancing en Godot; no se congelarán como una aproximación estática.", "",
        "| Archivo fuente | Constructores geométricos | BufferGeometry custom | Texturas | Riesgo |", "|---|---:|---:|---:|---|",
        *rows, "", "## Bloques de trabajo", "",
        "1. Arquitectura estática por zona: Sectors, Infrastructure, Workshop y Vault.",
        "2. Utilería funcional: Instruments, Files, Transit y VehicleModel.",
        "3. Entidades orgánicas: Operator, Larva y THE WATCHER.",
        "4. W-01 dinámico: Head/OcularSurface morphs, siete ojos y veinte tentáculos con ventosas.",
        "5. Texturas procedurales: piel, iris, suelo y canvases funcionales, usando semillas registradas durante exportación.", "",
        "Los conteos son sitios constructores del código, no el número final de instancias en runtime. Ese número se registrará en el manifest de cada familia.", "",
    ])


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("source", type=Path)
    parser.add_argument("json_output", type=Path)
    parser.add_argument("markdown_output", type=Path)
    args = parser.parse_args()
    data = inventory(args.source)
    args.json_output.parent.mkdir(parents=True, exist_ok=True)
    args.markdown_output.parent.mkdir(parents=True, exist_ok=True)
    args.json_output.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    args.markdown_output.write_text(markdown(data), encoding="utf-8")
    print(json.dumps({"files": len(data["files"]), "json": str(args.json_output), "markdown": str(args.markdown_output)}, indent=2))

if __name__ == "__main__":
    main()
