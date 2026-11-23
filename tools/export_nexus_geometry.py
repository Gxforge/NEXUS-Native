#!/usr/bin/env python3
"""Deterministic NEXUS TypeScript-box manifest to GLB 2.0 exporter. No third-party modules."""
from __future__ import annotations
import argparse, hashlib, json, struct
from pathlib import Path

FACES = (
    ((0, 0, -1), (0, 2, 3, 1)), ((0, 0, 1), (4, 5, 7, 6)),
    ((-1, 0, 0), (0, 4, 6, 2)), ((1, 0, 0), (1, 3, 7, 5)),
    ((0, -1, 0), (0, 1, 5, 4)), ((0, 1, 0), (2, 6, 7, 3)),
)
CORNERS = ((-1,-1,-1),(1,-1,-1),(-1,1,-1),(1,1,-1),(-1,-1,1),(1,-1,1),(-1,1,1),(1,1,1))

def color(value: str) -> list[float]:
    value = value.lstrip('#')
    return [int(value[i:i+2], 16) / 255.0 for i in (0, 2, 4)] + [1.0]

def align4(data: bytearray) -> None:
    while len(data) % 4: data.append(0)

def export(manifest_path: Path, output: Path) -> dict:
    manifest = json.loads(manifest_path.read_text(encoding='utf-8'))
    grouped: dict[str, list[dict]] = {}
    for box in manifest['boxes']: grouped.setdefault(box['material'], []).append(box)
    binary = bytearray(); views=[]; accessors=[]; primitives=[]
    def add_blob(blob: bytes, target: int) -> int:
        align4(binary); offset=len(binary); binary.extend(blob)
        views.append({'buffer':0,'byteOffset':offset,'byteLength':len(blob),'target':target})
        return len(views)-1
    def accessor(view:int, component:int, count:int, kind:str, mins=None, maxs=None)->int:
        a={'bufferView':view,'componentType':component,'count':count,'type':kind}
        if mins is not None: a['min']=mins; a['max']=maxs
        accessors.append(a); return len(accessors)-1
    material_names=list(manifest['materials'])
    for mat_name, boxes in grouped.items():
        pos=[]; normals=[]; indices=[]
        for box in boxes:
            cx,cy,cz=box['center']; sx,sy,sz=[v*.5 for v in box['size']]
            corners=[(cx+x*sx,cy+y*sy,cz+z*sz) for x,y,z in CORNERS]
            for normal, face in FACES:
                base=len(pos)//3
                for idx in face: pos.extend(corners[idx]); normals.extend(normal)
                indices.extend((base,base+1,base+2,base,base+2,base+3))
        pblob=struct.pack('<%sf'%len(pos),*pos); nblob=struct.pack('<%sf'%len(normals),*normals)
        iblob=struct.pack('<%sI'%len(indices),*indices)
        pview=add_blob(pblob,34962); nview=add_blob(nblob,34962); iview=add_blob(iblob,34963)
        triples=list(zip(pos[0::3],pos[1::3],pos[2::3]))
        mins=[min(v[i] for v in triples) for i in range(3)]; maxs=[max(v[i] for v in triples) for i in range(3)]
        primitives.append({'attributes':{'POSITION':accessor(pview,5126,len(pos)//3,'VEC3',mins,maxs),'NORMAL':accessor(nview,5126,len(normals)//3,'VEC3')},'indices':accessor(iview,5125,len(indices),'SCALAR'),'material':material_names.index(mat_name)})
    materials=[]
    for name,spec in manifest['materials'].items():
        materials.append({'name':name,'pbrMetallicRoughness':{'baseColorFactor':color(spec['base_color']),'metallicFactor':spec['metallic'],'roughnessFactor':spec['roughness']}})
    extras={'source_commit':manifest['source_commit']}
    if 'source_file' in manifest: extras['source_file']=manifest['source_file']
    else: extras['source_files']=manifest['source_files']
    gltf={'asset':{'version':'2.0','generator':'NEXUS deterministic geometry exporter 1'},'scene':0,'scenes':[{'nodes':[0]}],'nodes':[{'name':manifest['asset_id'],'mesh':0}],'meshes':[{'name':manifest['asset_id'],'primitives':primitives}],'materials':materials,'buffers':[{'byteLength':len(binary)}],'bufferViews':views,'accessors':accessors,'extras':extras}
    j=json.dumps(gltf,separators=(',',':'),sort_keys=True).encode(); j+=b' ' * ((4-len(j)%4)%4); align4(binary)
    total=12+8+len(j)+8+len(binary); output.parent.mkdir(parents=True,exist_ok=True)
    output.write_bytes(struct.pack('<4sII',b'glTF',2,total)+struct.pack('<I4s',len(j),b'JSON')+j+struct.pack('<I4s',len(binary),b'BIN\0')+binary)
    digest=hashlib.sha256(output.read_bytes()).hexdigest()
    return {'output':str(output),'sha256':digest,'boxes':len(manifest['boxes']),'materials':len(materials),'bytes':output.stat().st_size}

def main() -> None:
    ap=argparse.ArgumentParser(); ap.add_argument('manifest',type=Path); ap.add_argument('output',type=Path)
    args=ap.parse_args(); print(json.dumps(export(args.manifest,args.output),indent=2))
if __name__=='__main__': main()
