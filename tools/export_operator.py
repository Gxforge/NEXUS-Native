#!/usr/bin/env python3
"""Deterministic rest-pose export of the complete procedural Operator model."""
from __future__ import annotations
import hashlib,json,math,sys
from pathlib import Path
import numpy as np
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT/'tools'));import export_w01_core as c
OUT=ROOT/'assets/generated/operator.glb';REPORT=ROOT/'reports/export-operator.json'
def cube():
 p=[];idx=[]
 corners=[(-1,-1,-1),(1,-1,-1),(-1,1,-1),(1,1,-1),(-1,-1,1),(1,-1,1),(-1,1,1),(1,1,1)]
 for face in [(0,2,3,1),(4,5,7,6),(0,4,6,2),(1,3,7,5),(0,1,5,4),(2,6,7,3)]:
  q=len(p);p += [corners[i] for i in face];idx += [q,q+1,q+2,q,q+2,q+3]
 return c.mesh(np.array(p,np.float32)*.5,np.array(idx,np.uint32))
def main():
 b=c.GLB();mats=[]
 for name,color,metal,rough in [('suit',[.204,.271,.294,1],0,.86),('armor',[.443,.502,.506,1],.4,.5),('boot',[.118,.157,.173,1],0,1),('strap',[.533,.451,.298,1],0,1),('visor',[.149,.275,.345,1],.64,.18),('strip',[.576,.863,.796,1],0,1)]:mats.append({'name':name,'pbrMetallicRoughness':{'baseColorFactor':color,'metallicFactor':metal,'roughnessFactor':rough},**({'emissiveFactor':color[:3]} if name=='strip' else {})})
 sm=b.addmesh('operator_oval',c.sphere(1,1,1,0,22,14),0);bm=[b.addmesh(f'operator_block_{i}',cube(),i) for i in range(6)];nodes=[{'name':'Operator','children':[]}]
 def add(name,mat,pos,scale,parent=0):
  n=len(nodes);nodes[parent].setdefault('children',[]).append(n);nodes.append({'name':name,'mesh':sm if name.startswith('oval') else bm[mat],'translation':pos,'scale':scale});return n
 ovals=[(0,[0,1.17,0],[.218,.32,.14]),(1,[0,1.31,-.025],[.225,.226,.128]),(0,[0,.94,0],[.193,.17,.135]),(2,[0,1.02,0],[.2,.048,.145]),(0,[0,1.52,0],[.097,.094,.091]),(1,[0,1.66,0],[.127,.16,.132]),(4,[0,1.678,-.052],[.122,.079,.101]),(2,[0,1.572,-.051],[.097,.055,.1])]
 for i,(m,p,s) in enumerate(ovals):add(f'oval_torso_{i}',m,p,s)
 blocks=[(3,[0,1.02,-.139],[.16,.104,.028]),(5,[.092,1.37,-.15],[.144,.028,.024]),(2,[0,1.29,.117],[.56,.64,.174]),(1,[0,1.31,.164],[.46,.42,.054]),(5,[0,1.42,.162],[.184,.036,.034])]
 for i in range(3):blocks.append((2,[(i-1)*.1,1.15,-.132],[.172,.21,.08]))
 for j in range(4):blocks.append((0,[0,1.22+j*.047,.182],[.38,.036,.036]))
 for i,(m,p,s) in enumerate(blocks):add(f'block_torso_{i}',m,p,s)
 for side in (-1,1):
  add(f'oval_ear_{side}',2,[side*.12,1.66,0],[.025,.049,.056]);leg=len(nodes);nodes[0]['children'].append(leg);nodes.append({'name':f'Leg_{side}','translation':[side*.102,.93,0],'children':[]})
  for i,(m,p,s) in enumerate([(0,[0,-.211,0],[.103,.224,.112]),(1,[0,-.446,-.035],[.081,.09,.076]),(0,[0,-.624,.012],[.079,.184,.091]),(2,[0,-.815,-.029],[.086,.113,.141])]):add(f'oval_leg_{side}_{i}',m,p,s,leg)
  add(f'block_sole_{side}',2,[0,-.908,-.033],[.32,.088,.53],leg);arm=len(nodes);nodes[0]['children'].append(arm);nodes.append({'name':f'Arm_{side}','translation':[side*.219,1.441,0],'children':[]})
  armdata=[(1,[side*.022,-.044,0],[.099,.097,.103]),(0,[side*.039,-.179,0],[.071,.159,.078]),(2,[side*.049,-.319,-.005],[.065,.072,.069]),(0,[side*.049,-.446,-.032],[.061,.145,.065]),(2,[side*.05,-.597,-.057],[.049,.078,.048])]
  for i,(m,p,s) in enumerate(armdata):add(f'oval_arm_{side}_{i}',m,p,s,arm)
  for j in range(4):add(f'oval_finger_{side}_{j}',2,[side*.047,-.66,-.029-j*.019],[.029,.045,.011],arm)
 c.OUT=OUT;c.TEX=ROOT/'assets/generated/textures/nexus_skin.png';b.write({'asset':{'version':'2.0','generator':'NEXUS Operator exporter 1'},'scene':0,'scenes':[{'nodes':[0]}],'nodes':nodes,'materials':mats,'extras':{'source_commit':c.COMMIT,'source_files':['src/scene/Operator.ts','src/scene/Infrastructure.ts'],'pose':'standing rest'}})
 r={'output':OUT.relative_to(ROOT).as_posix(),'sha256':hashlib.sha256(OUT.read_bytes()).hexdigest(),'nodes':len(nodes),'visible_meshes':len(nodes)-5,'source_commit':c.COMMIT,'note':'cross-body diagonal strap bar pending exact cylinder orientation'};REPORT.write_text(json.dumps(r,indent=2,sort_keys=True)+'\n');print(json.dumps(r,indent=2))
if __name__=='__main__':main()
