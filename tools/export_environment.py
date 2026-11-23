#!/usr/bin/env python3
"""Export shared NEXUS floor and four C-04 emitter housings."""
from pathlib import Path
import hashlib,json,sys,numpy as np
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT/'tools'));import export_w01_core as c
OUT=ROOT/'assets/generated/environment.glb';REPORT=ROOT/'reports/export-environment.json'
def quad():
 p=np.array([[-36,0,-54],[36,0,-54],[-36,0,54],[36,0,54]],np.float32);return c.mesh(p,np.array([0,2,1,1,2,3],np.uint32),np.array([[0,0],[6,0],[0,6],[6,6]],np.float32))
def box():
 p=[];ind=[]
 for f in [(0,2,3,1),(4,5,7,6),(0,4,6,2),(1,3,7,5),(0,1,5,4),(2,6,7,3)]:
  q=len(p);cs=[(-.6,-.06,-.075),(.6,-.06,-.075),(-.6,.06,-.075),(.6,.06,-.075),(-.6,-.06,.075),(.6,-.06,.075),(-.6,.06,.075),(.6,.06,.075)];p += [cs[i] for i in f];ind += [q,q+1,q+2,q,q+2,q+3]
 return c.mesh(np.array(p,np.float32),np.array(ind,np.uint32))
def main():
 b=c.GLB();m=[{'name':'floor','pbrMetallicRoughness':{'baseColorFactor':[.671,.714,.694,1],'baseColorTexture':{'index':0},'metallicFactor':.26,'roughnessFactor':.6}},{'name':'emitter','emissiveFactor':[.576,.863,.796],'pbrMetallicRoughness':{'baseColorFactor':[.576,.863,.796,1],'roughnessFactor':.35}}];fm=b.addmesh('floor',quad(),0);lm=b.addmesh('lamp_housing',box(),1);nodes=[{'name':'Environment','children':[1,2,3,4,5]},{'name':'Floor','mesh':fm,'translation':[0,-.035,16]}]+[{'name':f'Emitter_{i}','mesh':lm,'translation':[x,3.2,-13.63]} for i,x in enumerate([-15,-5,5,15])];c.OUT=OUT;c.TEX=ROOT/'assets/generated/textures/nexus_floor.png';b.write({'asset':{'version':'2.0','generator':'NEXUS Environment exporter 1'},'scene':0,'scenes':[{'nodes':[0]}],'nodes':nodes,'materials':m,'extras':{'source_commit':c.COMMIT,'source_file':'src/scene/Environment.ts'}});raw=OUT.read_bytes().replace(b'nexus_skin',b'nexus_floor');OUT.write_bytes(raw);r={'output':'assets/generated/environment.glb','sha256':hashlib.sha256(raw).hexdigest(),'nodes':6,'floor_dimensions_m':[72,108],'emitters':4,'source_commit':c.COMMIT};REPORT.write_text(json.dumps(r,indent=2,sort_keys=True)+'\n');print(json.dumps(r,indent=2))
if __name__=='__main__':main()
