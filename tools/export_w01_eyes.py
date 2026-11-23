#!/usr/bin/env python3
"""Export the seven-eye W-01 anatomical rig as a deterministic GLB baseline."""
from __future__ import annotations
import hashlib,json,math,sys
from pathlib import Path
import numpy as np
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT/'tools'))
import export_w01_core as core
OUT=ROOT/'assets/generated/w01_eyes.glb';REPORT=ROOT/'reports/export-w01-eyes.json';IRIS=ROOT/'assets/generated/textures/nexus_iris.png';COMMIT=core.COMMIT

def uv_sphere(ws,hs):
 p=[];uv=[];idx=[]
 for y in range(hs+1):
  ph=math.pi*y/hs
  for x in range(ws+1):
   th=math.tau*x/ws;p.append((-math.cos(th)*math.sin(ph),math.cos(ph),math.sin(th)*math.sin(ph)));uv.append((x/ws,1-y/hs))
   if x<ws and y<hs:
    a=y*(ws+1)+x;b=a+ws+1;idx += [a,b,a+1,a+1,b,b+1]
 return core.mesh(np.array(p,np.float32),np.array(idx,np.uint32),np.array(uv,np.float32))
def torus(R=.79,r=.13,rs=14,ts=64):
 p=[];uv=[];idx=[]
 for j in range(rs+1):
  v=math.tau*j/rs
  for i in range(ts+1):
   u=math.tau*i/ts;p.append(((R+r*math.cos(v))*math.cos(u),(R+r*math.cos(v))*math.sin(u),r*math.sin(v)));uv.append((i/ts,j/rs))
   if i<ts and j<rs:
    a=j*(ts+1)+i;b=a+ts+1;idx += [a,b,a+1,a+1,b,b+1]
 return core.mesh(np.array(p,np.float32),np.array(idx,np.uint32),np.array(uv,np.float32))
def cap(rx,ry,lift):
 p=[];uv=[];idx=[]
 for j in range(8):
  for i in range(57):
   a=i*math.pi/28;r=j/7;x=math.cos(a)*r;y=math.sin(a)*r;p.append((rx*x,ry*y,math.sqrt(max(0,1-(rx*x)**2-(ry*y)**2))+lift));uv.append((.5+.5*x,.5+.5*y))
   if j<7 and i<56:
    n=j*57+i;b=n+57;idx += [n,b,n+1,n+1,b,b+1]
 return core.mesh(np.array(p,np.float32),np.array(idx,np.uint32),np.array(uv,np.float32))
def lid(top):
 p=[];uv=[];idx=[]
 for j in range(8):
  for i in range(33):
   t=.006+i/32*(math.pi-.012);x=-math.cos(t);h=math.sin(t);edge=.94 if top else -1.1;a=edge+(((1 if top else -1)*1.97)-edge)*j/7;p.append((x*1.049,.768*h*math.sin(a),.567*h*math.cos(a)+.023));uv.append((i/32,j/7))
   if i<32 and j<7:
    n=j*33+i;b=n+33;idx += [n,b,n+1,n+1,b,b+1]
 return core.mesh(np.array(p,np.float32),np.array(idx,np.uint32),np.array(uv,np.float32))
def main():
 b=core.GLB(); mats=[
 {'name':'socket','pbrMetallicRoughness':{'baseColorFactor':[.224,.129,.149,1],'roughnessFactor':.28}},
 {'name':'skin','pbrMetallicRoughness':{'baseColorFactor':[.945,.863,.808,1],'roughnessFactor':.48}},
 {'name':'eye_white','pbrMetallicRoughness':{'baseColorFactor':[.71,.616,.518,1],'roughnessFactor':.2}},
 {'name':'iris','pbrMetallicRoughness':{'baseColorTexture':{'index':0},'metallicFactor':.08,'roughnessFactor':.3},'emissiveFactor':[.204,.063,.067]},
 {'name':'pupil','pbrMetallicRoughness':{'baseColorFactor':[.02,.016,.02,1],'roughnessFactor':1}},
 {'name':'cornea','alphaMode':'BLEND','doubleSided':True,'pbrMetallicRoughness':{'baseColorFactor':[.91,.898,.867,.045],'metallicFactor':0,'roughnessFactor':.035}},]
 mids=[b.addmesh('socket',torus(),0),b.addmesh('bed',uv_sphere(32,20),1),b.addmesh('globe',uv_sphere(48,32),2),b.addmesh('iris',cap(.47,.63,.009),3),b.addmesh('pupil',cap(.19,.29,.023),4),b.addmesh('cornea',uv_sphere(40,28),5),b.addmesh('lid_top',lid(True),1),b.addmesh('lid_bottom',lid(False),1)]
 eyes=[([0,3.23,1.37],1.18,True),([-1.42,2.68,.74],.37,False),([1.42,2.76,.74],.39,False),([-1.28,3.92,.79],.28,False),([1.31,3.87,.79],.3,False),([-1.43,2.05,.68],.26,False),([1.31,2.1,.74],.29,False)]
 nodes=[{'name':'W01_Seven_Eyes','children':[]}]
 for ei,(pos,size,main) in enumerate(eyes):
  if not main and pos[1]<=3.6:pos[2]=1.98*math.sqrt(max(.08,1-(pos[0]/2.02)**2-((pos[1]-2.38)/2.04)**2))-.5+size*.22
  base=len(nodes);nodes[0]['children'].append(base);nodes.append({'name':'primary-eye' if main else f'secondary-eye-{ei}','translation':pos,'scale':[size]*3,'children':list(range(base+1,base+9))})
  specs=[('Socket',mids[0],[0,0,-.045],[1.28,.94,.62]),('Bed',mids[1],[0,0,-.29],[1.13,.88,.52]),('Globe',mids[2],[0,0,0],[1.02,.74,.53]),('Iris',mids[3],[0,0,0],[1.02,.74,.53]),('Pupil',mids[4],[0,0,0],[1.02,.74,.53]),('Cornea',mids[5],[0,0,0],[1.035,.752,.55]),('LidTop',mids[6],[0,0,0],[1,1,1]),('LidBottom',mids[7],[0,0,0],[1,1,1])]
  for name,mi,tr,sc in specs:nodes.append({'name':f'Eye{ei}_{name}','mesh':mi,'translation':tr,'scale':sc})
 core.OUT=OUT;core.TEX=IRIS;b.write({'asset':{'version':'2.0','generator':'NEXUS W-01 eye exporter 1'},'scene':0,'scenes':[{'nodes':[0]}],'nodes':nodes,'materials':mats,'extras':{'source_commit':COMMIT,'source_files':['src/scene/EyeSystem.ts','src/scene/OcularSurface.ts','src/scene/materials.ts'],'eye_count':7,'texture_seed':151002}})
 OUT.write_bytes(OUT.read_bytes().replace(b'nexus_skin',b'nexus_iris'))
 report={'output':OUT.relative_to(ROOT).as_posix(),'sha256':hashlib.sha256(OUT.read_bytes()).hexdigest(),'bytes':OUT.stat().st_size,'eyes':7,'nodes':len(nodes),'shared_meshes':8,'visible_mesh_instances':56,'embedded_textures':1,'limitations':['vein tubes deferred to dynamic Godot rig','lids exported in open baseline; runtime blink deformation pending'],'source_commit':COMMIT};REPORT.write_text(json.dumps(report,indent=2,sort_keys=True)+'\n');print(json.dumps(report,indent=2))
if __name__=='__main__':main()
