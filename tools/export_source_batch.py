#!/usr/bin/env python3
"""Build and execute the source-driven Three.js bulk exporter, then hash its GLBs."""
from pathlib import Path
import hashlib,json,subprocess
ROOT=Path(__file__).resolve().parents[1];SRC=Path('/home/user/NEXUS-15.1-source');OUT=ROOT/'assets/generated/source-batch'
def main():
 if not (SRC/'node_modules/esbuild/bin/esbuild').exists(): subprocess.run(['npm','ci','--ignore-scripts'],cwd=SRC,check=True)
 subprocess.run([str(SRC/'node_modules/.bin/esbuild'),str(ROOT/'tools/source_mass_export.ts'),'--bundle','--platform=node','--format=esm','--target=node20','--outfile=/tmp/nexus-mass.mjs','--external:cannon-es'],cwd=SRC,check=True)
 nm=Path('/tmp/node_modules');
 if nm.is_symlink() or nm.exists(): nm.unlink()
 nm.symlink_to(SRC/'node_modules',target_is_directory=True)
 for stale in OUT.glob('*.glb'): stale.unlink()
 subprocess.run(['node','/tmp/nexus-mass.mjs'],check=True)
 assets=[]
 for p in sorted(OUT.glob('*.glb')):assets.append({'path':p.relative_to(ROOT).as_posix(),'bytes':p.stat().st_size,'sha256':hashlib.sha256(p.read_bytes()).hexdigest()})
 report={'schema':1,'source_commit':'f4e1e819a9c783374e79dbc99cde4597099aba11','method':'original TypeScript constructors bundled with esbuild; runtime canvas maps stripped because dynamic CanvasTexture must be native Godot UI/material work','assets':assets}
 (ROOT/'reports/export-source-batch.json').write_text(json.dumps(report,indent=2,sort_keys=True)+'\n');print(json.dumps({'assets':len(assets),'bytes':sum(x['bytes'] for x in assets)},indent=2))
if __name__=='__main__':main()
