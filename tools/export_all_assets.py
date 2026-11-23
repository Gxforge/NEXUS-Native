#!/usr/bin/env python3
"""Rebuild every currently implemented native asset and emit one auditable batch report."""
from __future__ import annotations
import hashlib, json, subprocess, sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
PY=sys.executable

def run(*args:str)->None:
    subprocess.run(args,cwd=ROOT,check=True)

def sha(path:Path)->str:return hashlib.sha256(path.read_bytes()).hexdigest()

def main()->None:
    run(PY,'tools/inventory_nexus_models.py','/home/user/NEXUS-15.1-source','reports/model-inventory.json','docs/migration/MODEL_EXPORT_INVENTORY.md')
    run(PY,'tools/export_procedural_textures.py','assets/generated/textures','reports/export-procedural-textures.json')
    manifest_outputs={
      'manifests/migration/a01_portal_frame.json':'assets/generated/a01_portal_frame.glb',
      'manifests/migration/a01_door_leaf.json':'assets/generated/a01_door_leaf.glb',
      'manifests/migration/a01_structural_shell.json':'assets/generated/a01_structural_shell.glb',
      'manifests/migration/c04_structural_shell.json':'assets/generated/c04_structural_shell.glb',
    }
    for manifest,output in manifest_outputs.items():run(PY,'tools/export_nexus_geometry.py',manifest,output)
    run(PY,'tools/export_w01_core.py')
    run(PY,'tools/export_w01_eyes.py')
    run(PY,'tools/export_w01_tentacles.py')
    run(PY,'tools/export_operator.py')
    run(PY,'tools/export_environment.py')
    run(PY,'tools/export_source_batch.py')
    outputs=[*(ROOT/p for p in manifest_outputs.values()),ROOT/'assets/generated/w01_core.glb',ROOT/'assets/generated/w01_eyes.glb',ROOT/'assets/generated/w01_tentacles.glb',ROOT/'assets/generated/operator.glb',ROOT/'assets/generated/environment.glb',*sorted((ROOT/'assets/generated/source-batch').glob('*.glb')),*sorted((ROOT/'assets/generated/textures').glob('*.png'))]
    inventory=json.loads((ROOT/'reports/model-inventory.json').read_text())
    covered={'src/scene/Sectors.ts','src/scene/Infrastructure.ts','src/scene/Head.ts','src/scene/Monster.ts','src/scene/materials.ts','src/scene/EyeSystem.ts','src/scene/OcularSurface.ts','src/scene/Tentacles.ts','src/scene/Operator.ts','src/scene/Environment.ts','src/scene/Workshop.ts','src/scene/Vault.ts','src/scene/Transit.ts','src/scene/Larva.ts','src/scene/Instruments.ts','src/vehicle/VehicleModel.ts','src/scene/Effects.ts','src/scene/Glove.ts','src/scene/TelemetryScreen.ts','src/scene/Displays.ts','src/vehicle/Cockpit.ts','src/scene/Touch.ts'}
    source_files=[x['source_file'] for x in inventory['files']]
    report={
      'schema':1,'source_commit':'f4e1e819a9c783374e79dbc99cde4597099aba11',
      'command':'python3 tools/export_all_assets.py',
      'implemented_source_files':sorted(covered),
      'pending_source_files':sorted(set(source_files)-covered),
      'coverage':{'implemented_source_files':len(covered),'inventoried_source_files':len(source_files)},
      'outputs':[{'path':p.relative_to(ROOT).as_posix(),'bytes':p.stat().st_size,'sha256':sha(p)} for p in outputs],
    }
    path=ROOT/'reports/export-all-assets.json';path.write_text(json.dumps(report,indent=2,sort_keys=True)+'\n')
    print(json.dumps({'outputs':len(outputs),'implemented_sources':len(covered),'pending_sources':len(report['pending_source_files']),'report':str(path.relative_to(ROOT))},indent=2))
if __name__=='__main__':main()
