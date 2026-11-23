#!/usr/bin/env python3
"""Export W-01 head, maw, teeth, collar and shoulders to deterministic GLB 2.0."""
from __future__ import annotations
import hashlib,json,math,struct
from pathlib import Path
import numpy as np
ROOT=Path(__file__).resolve().parents[1]; OUT=ROOT/'assets/generated/w01_core.glb'; TEX=ROOT/'assets/generated/textures/nexus_skin.png'; REPORT=ROOT/'reports/export-w01-core.json'
COMMIT='f4e1e819a9c783374e79dbc99cde4597099aba11'; START=.405; TILT=-.38; UP=math.sqrt(1-TILT*TILT)

def surface(a,t,o):
 u,v,s,c=math.cos(a),math.sin(a),math.sin(t),math.cos(t); f=math.exp(-6*(t-START)); h=.26+o*(.46 if v>0 else .7); v2=s*v*(1-(1-h)*f)
 d=1+.021*(1-f)*(math.sin(8*s*u+4*c)*math.cos(9*s*v)+.5*math.sin(17*c+3*s*v))
 return np.array([2.02*s*u*d,2.04*(TILT*c+UP*v2)*d,1.99*(UP*c-TILT*v2)*d-.5],np.float32)
def grid(rows,seg,fn,reverse=False,morph=False):
 p=[]; q=[]; uv=[]; idx=[]
 for j in range(rows+1):
  for i in range(seg+1):
   a=math.tau*i/seg; v=j/rows; p.append(fn(a,v,0)); uv.append((i/seg,v)); q.append(fn(a,v,1))
   if i<seg and j<rows:
    n=j*(seg+1)+i;b=n+seg+1; idx += ([n,n+1,b,b,n+1,b+1] if reverse else [n,b,n+1,n+1,b,b+1])
 return mesh(np.array(p,np.float32),np.array(idx,np.uint32),np.array(uv,np.float32),np.array(q,np.float32) if morph else None)
def normals(pos,idx):
 n=np.zeros_like(pos)
 tri=idx.reshape(-1,3)
 for a,b,c in tri:
  v=np.cross(pos[b]-pos[a],pos[c]-pos[a]); n[a]+=v;n[b]+=v;n[c]+=v
 lengths=np.linalg.norm(n,axis=1); lengths[lengths==0]=1; return (n/lengths[:,None]).astype(np.float32)
def mesh(p,i,uv=None,morph=None): return {'p':p,'i':i,'uv':uv,'n':normals(p,i),'morph':morph}
def sphere(rx,ry,rz,seed,ws,hs):
 p=[];uv=[];idx=[]
 for y in range(hs+1):
  ph=math.pi*y/hs
  for x in range(ws+1):
   th=math.tau*x/ws; vx=-math.cos(th)*math.sin(ph);vy=math.cos(ph);vz=math.sin(th)*math.sin(ph)
   wave=math.sin(vx*7.3+seed)*math.sin(vy*5.7-seed*.7); ridges=math.sin(vy*14+vz*4+seed)*.025; wob=1+wave*.055+ridges+math.cos(vx*12+vz*9)*.018
   p.append((vx*rx*wob,vy*ry*wob,vz*rz*wob));uv.append((x/ws,1-y/hs))
   if x<ws and y<hs:
    a=y*(ws+1)+x;b=a+ws+1;idx += [a,b,a+1,a+1,b,b+1]
 return mesh(np.array(p,np.float32),np.array(idx,np.uint32),np.array(uv,np.float32))
def tooth():
 seg=12;p=[];idx=[]
 for y in (0.,1.):
  for i in range(seg):
   a=math.tau*i/seg;r=1-y; z=math.sin(a)*r-y*y*.37;p.append((math.cos(a)*r,y,z))
 for i in range(seg):
  j=(i+1)%seg;idx += [i,j,seg+i,seg+i,j,seg+j]
 return mesh(np.array(p,np.float32),np.array(idx,np.uint32))
class GLB:
 def __init__(self): self.bin=bytearray();self.views=[];self.acc=[];self.meshes=[]
 def add(self,a,target=None):
  while len(self.bin)%4:self.bin.append(0)
  off=len(self.bin);raw=a.tobytes();self.bin.extend(raw);v={'buffer':0,'byteOffset':off,'byteLength':len(raw)}
  if target:v['target']=target
  self.views.append(v);return len(self.views)-1
 def accessor(self,a,kind,target=None):
  view=self.add(a,target); comp={np.dtype('float32'):5126,np.dtype('uint32'):5125}[a.dtype];x={'bufferView':view,'componentType':comp,'count':len(a),'type':kind}
  if kind!='SCALAR':x['min']=a.min(axis=0).tolist();x['max']=a.max(axis=0).tolist()
  self.acc.append(x);return len(self.acc)-1
 def addmesh(self,name,m,mat):
  attrs={'POSITION':self.accessor(m['p'],'VEC3',34962),'NORMAL':self.accessor(m['n'],'VEC3',34962)}
  if m['uv'] is not None:attrs['TEXCOORD_0']=self.accessor(m['uv'],'VEC2',34962)
  prim={'attributes':attrs,'indices':self.accessor(m['i'],'SCALAR',34963),'material':mat}
  if m['morph'] is not None:
   delta=(m['morph']-m['p']).astype(np.float32);prim['targets']=[{'POSITION':self.accessor(delta,'VEC3',34962)}]
  self.meshes.append({'name':name,'primitives':[prim],**({'weights':[0.0]} if m['morph'] is not None else {})});return len(self.meshes)-1
 def write(self,g):
  image=TEX.read_bytes(); view=self.add(np.frombuffer(image,dtype=np.uint8));g.update({'buffers':[{'byteLength':len(self.bin)}],'bufferViews':self.views,'accessors':self.acc,'meshes':self.meshes,'images':[{'name':'nexus_skin','bufferView':view,'mimeType':'image/png'}],'samplers':[{'wrapS':10497,'wrapT':10497}],'textures':[{'source':0,'sampler':0}]})
  while len(self.bin)%4:self.bin.append(0)
  raw=json.dumps(g,separators=(',',':'),sort_keys=True).encode();raw+=b' '*((-len(raw))%4);total=12+8+len(raw)+8+len(self.bin);OUT.parent.mkdir(parents=True,exist_ok=True);OUT.write_bytes(struct.pack('<4sII',b'glTF',2,total)+struct.pack('<I4s',len(raw),b'JSON')+raw+struct.pack('<I4s',len(self.bin),b'BIN\0')+self.bin)
def main():
 center=surface(0,START,0).copy();center[0]=0
 local=lambda a,o:surface(a,START,o)-center
 def ring(a,v,o):
  p=local(a,o);r=1-.14*v;p[0]*=r;p[1]*=r;p[2]+=math.sin(v*math.pi)*.069-.055*v;return p
 head=grid(48,80,lambda a,v,o:surface(a,START+v*(math.pi-START-.0001),o),morph=True)
 gum=grid(8,80,ring,True,True)
 def throat(a,v,o):
  p=ring(a,1,o);r=1-.999*v;p[0]*=r;p[1]=p[1]*r-.045*v;p[2]=p[2]*r-.67*v;return p
 throatm=grid(12,80,throat,True,True); collar=sphere(1.43,.73,.72,5.1,48,32); left=sphere(.61,1.02,.68,1.3,36,28);right=sphere(.61,1.02,.68,3.3,36,28); tm=tooth(); b=GLB()
 mats=[{'name':'skin','pbrMetallicRoughness':{'baseColorFactor':[.945,.863,.808,1],'baseColorTexture':{'index':0},'metallicFactor':.015,'roughnessFactor':.48}},{'name':'skin_light','pbrMetallicRoughness':{'baseColorFactor':[.502,.31,.314,1],'metallicFactor':0,'roughnessFactor':.34}},{'name':'mouth','doubleSided':True,'pbrMetallicRoughness':{'baseColorFactor':[.086,.035,.051,1],'metallicFactor':0,'roughnessFactor':.53}},{'name':'tooth','pbrMetallicRoughness':{'baseColorFactor':[.851,.788,.686,1],'metallicFactor':0,'roughnessFactor':.22}}]
 mi=[b.addmesh('head',head,0),b.addmesh('gum',gum,1),b.addmesh('throat',throatm,2),b.addmesh('collar',collar,1),b.addmesh('shoulder_left',left,0),b.addmesh('shoulder_right',right,0),b.addmesh('tooth',tm,3)]
 nodes=[{'name':'W01_Core','children':[1,4,5,6]},{'name':'Head','mesh':mi[0],'translation':[0,2.38,0],'children':list(range(2,4))+list(range(7,33))},{'name':'Gum','mesh':mi[1],'translation':center.tolist()},{'name':'Throat','mesh':mi[2],'translation':center.tolist()},{'name':'Collar','mesh':mi[3],'translation':[0,3.15,.36],'scale':[1,.68,.88]},{'name':'Shoulder_L','mesh':mi[4],'translation':[-1.48,2.42,.18],'rotation':[0,0,math.sin(.065),math.cos(.065)]},{'name':'Shoulder_R','mesh':mi[5],'translation':[1.48,2.42,.18],'rotation':[0,0,math.sin(-.065),math.cos(-.065)]}]
 for side in range(2):
  for i in range(13):
   a=(.12+((i+(.27 if side else 0))/12.7)*.92)*math.pi+side*math.pi;h=min(.1+.09*abs(math.sin(a))+.044*math.sin(i*2.4)**2,.175*abs(math.sin(a)));p=ring(a,.65,0);p[2]+=.014
   rz=(-.16*math.cos(a) if side else math.pi+.18*math.cos(a));rx=-.16 if side else .13
   # Euler XYZ quaternion
   qx=(math.sin(rx/2),0,0,math.cos(rx/2)); qz=(0,0,math.sin(rz/2),math.cos(rz/2));q=[qx[0]*qz[3],-qx[0]*qz[2],qx[3]*qz[2],qx[3]*qz[3]]
   nodes.append({'name':f'Tooth_{side}_{i:02d}','mesh':mi[6],'translation':p.tolist(),'scale':[.038+.019*math.cos(i)**2,h,.041],'rotation':q})
 g={'asset':{'version':'2.0','generator':'NEXUS deterministic W-01 exporter 1'},'scene':0,'scenes':[{'nodes':[0]}],'nodes':nodes,'materials':mats,'extras':{'source_commit':COMMIT,'source_files':['src/scene/Monster.ts','src/scene/Head.ts','src/scene/materials.ts'],'texture_seed':151001,'scope':'head, maw, 26 teeth, collar, shoulders'}};b.write(g)
 report={'output':OUT.relative_to(ROOT).as_posix(),'sha256':hashlib.sha256(OUT.read_bytes()).hexdigest(),'bytes':OUT.stat().st_size,'nodes':len(nodes),'meshes':len(b.meshes),'morph_targets':3,'teeth':26,'embedded_textures':1,'source_commit':COMMIT};REPORT.write_text(json.dumps(report,indent=2,sort_keys=True)+'\n');print(json.dumps(report,indent=2))
if __name__=='__main__':main()
