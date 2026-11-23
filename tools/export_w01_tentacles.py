#!/usr/bin/env python3
"""Batch-export all 20 W-01 tentacles and their 87 sucker assemblies."""
from __future__ import annotations
import hashlib,json,math,sys
from pathlib import Path
import numpy as np
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT/'tools'));import export_w01_core as core
OUT=ROOT/'assets/generated/w01_tentacles.glb';REPORT=ROOT/'reports/export-w01-tentacles.json';SKIN=ROOT/'assets/generated/textures/nexus_skin.png'
BASE=[([-1.48,3.03,.12],[-1,.22,.08],2.65,.22),([1.48,3.08,.12],[1,.13,.1],2.5,.21),([-1.42,2.51,.32],[-1,-.19,.06],2.85,.24),([1.39,2.48,.34],[1,-.27,.06],3.05,.24),([-1.01,1.87,.25],[-.72,-.77,.15],2.7,.2),([1.01,1.82,.25],[.76,-.68,.13],2.85,.21),([-.77,3.55,-.25],[-.52,.84,-.24],1.95,.17),([.79,3.52,-.22],[.56,.79,-.21],2.15,.18),([-1.11,2.17,-.31],[-.94,-.08,-.48],2.45,.18),([1.1,2.14,-.31],[.91,-.08,-.52],2.35,.18)]
DORSAL=[[-1.3,3.35,-1.32,-.65,.38,-.7],[1.34,3.27,-1.39,.72,.29,-.71],[-.55,3.86,-1.48,-.26,.8,-.61],[.53,3.89,-1.45,.32,.73,-.7],[-1.49,2.22,-1.55,-.89,-.16,-.6],[1.45,2.12,-1.52,.87,-.2,-.65],[-.68,1.32,-1.77,-.37,-.32,-.88],[.7,1.37,-1.83,.47,-.34,-.84],[-.35,2.76,-2.18,-.37,.18,-.92],[.38,2.63,-2.15,.43,-.04,-.9]]
for i,v in enumerate(DORSAL):
 length=2+(i%3)*.39;BASE.append((v[:3],v[3:],length,.14+.028*(length-2)))
def curve(ctrl,u):
 x=u*4;k=min(3,int(x));t=x-k;p0=ctrl[max(0,k-1)];p1=ctrl[k];p2=ctrl[min(4,k+1)];p3=ctrl[min(4,k+2)]
 return .5*((2*p1)+(-p0+p2)*t+(2*p0-5*p1+4*p2-p3)*t*t+(-p0+3*p1-3*p2+p3)*t**3)
def tube(ctrl,r):
 rings=28;rad=9;points=np.array([curve(ctrl,i/rings) for i in range(rings+1)],np.float32);p=[];uv=[];idx=[]
 for i,pt in enumerate(points):
  tangent=points[min(rings,i+1)]-points[max(0,i-1)];tangent/=np.linalg.norm(tangent);ref=np.array([0,1,0],np.float32) if abs(tangent[1])<.9 else np.array([1,0,0],np.float32);n=np.cross(tangent,ref);n/=np.linalg.norm(n);bn=np.cross(tangent,n);rr=r*(1-i/rings)**.78+.012
  for j in range(rad+1):
   a=math.tau*j/rad;p.append(pt+(n*math.cos(a)+bn*math.sin(a))*rr);uv.append((i/rings,j/rad))
   if i<rings and j<rad:q=i*(rad+1)+j;b=q+rad+1;idx += [q,q+1,b,b,q+1,b+1]
 return core.mesh(np.array(p,np.float32),np.array(idx,np.uint32),np.array(uv,np.float32))
def torus():
 p=[];uv=[];idx=[];rs=7;ts=16
 for j in range(rs+1):
  v=math.tau*j/rs
  for i in range(ts+1):
   u=math.tau*i/ts;p.append(((1+.25*math.cos(v))*math.cos(u),(1+.25*math.cos(v))*math.sin(u),.25*math.sin(v)));uv.append((i/ts,j/rs))
   if i<ts and j<rs:a=j*(ts+1)+i;b=a+ts+1;idx += [a,b,a+1,a+1,b,b+1]
 return core.mesh(np.array(p,np.float32),np.array(idx,np.uint32),np.array(uv,np.float32))
def main():
 b=core.GLB();mats=[{'name':'skin','pbrMetallicRoughness':{'baseColorFactor':[.945,.863,.808,1],'baseColorTexture':{'index':0},'metallicFactor':.015,'roughnessFactor':.48}},{'name':'sucker','pbrMetallicRoughness':{'baseColorFactor':[.376,.18,.208,1],'roughnessFactor':.27}},{'name':'socket','pbrMetallicRoughness':{'baseColorFactor':[.224,.129,.149,1],'roughnessFactor':.28}}]
 cup=b.addmesh('sucker_cup_unit',torus(),1);center=b.addmesh('sucker_center_unit',core.sphere(1,1,1,0,12,8),2);nodes=[{'name':'W01_20_Tentacles','children':[]}];suckers=0
 for ai,(root,direction,length,radius) in enumerate(BASE):
  d=np.array(direction,np.float32);d/=np.linalg.norm(d);ctrl=np.array([np.zeros(3),d*length*.26+[0,.08,0],d*length*.53,d*length*.79,d*length],np.float32);mi=b.addmesh(f'arm_{ai:02d}',tube(ctrl,radius),0);ri=len(nodes);nodes[0]['children'].append(ri);nodes.append({'name':f'arm-{ai}','translation':root,'children':[ri+1]});nodes.append({'name':f'arm-{ai}-mesh','mesh':mi})
  count=5 if ai%3==0 else 4
  for si in range(count):
   u=.32+si*.115;pt=curve(ctrl,u);scale=radius*(.48-si*.035);rig=len(nodes);nodes[ri]['children'].append(rig);nodes.append({'name':f'arm-{ai}-sucker-{si}','translation':pt.tolist(),'children':[rig+1,rig+2]});nodes.append({'name':f'cup-{ai}-{si}','mesh':cup,'scale':[scale,scale*.77,scale]});nodes.append({'name':f'center-{ai}-{si}','mesh':center,'translation':[0,0,.006],'scale':[radius*.31,radius*.31*.72,radius*.31*.38]});suckers+=1
 core.OUT=OUT;core.TEX=SKIN;b.write({'asset':{'version':'2.0','generator':'NEXUS W-01 tentacle batch exporter 1'},'scene':0,'scenes':[{'nodes':[0]}],'nodes':nodes,'materials':mats,'extras':{'source_commit':core.COMMIT,'source_file':'src/scene/Tentacles.ts','tube_segments':28,'radial_segments':9,'arm_count':20,'sucker_count':suckers}})
 rep={'output':OUT.relative_to(ROOT).as_posix(),'sha256':hashlib.sha256(OUT.read_bytes()).hexdigest(),'bytes':OUT.stat().st_size,'tentacles':20,'suckers':suckers,'visible_mesh_instances':20+suckers*2,'nodes':len(nodes),'source_commit':core.COMMIT,'limitations':['baseline rest curves exported; runtime locomotion and collision response remain native rig work','sucker facing is updated dynamically in source and remains runtime rig work']};REPORT.write_text(json.dumps(rep,indent=2,sort_keys=True)+'\n');print(json.dumps(rep,indent=2))
if __name__=='__main__':main()
