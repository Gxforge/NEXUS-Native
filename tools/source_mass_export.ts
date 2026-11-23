import * as T from "/home/user/NEXUS-15.1-source/node_modules/three/build/three.module.js";
import { GLTFExporter } from "/home/user/NEXUS-15.1-source/node_modules/three/examples/jsm/exporters/GLTFExporter.js";
class FR { result:any; onloadend:any; onerror:any; readAsArrayBuffer(b:Blob){b.arrayBuffer().then(x=>{this.result=x;this.onloadend?.()}).catch(e=>this.onerror?.(e))} readAsDataURL(b:Blob){b.arrayBuffer().then(x=>{this.result=`data:${b.type};base64,${Buffer.from(x).toString('base64')}`;this.onloadend?.()})} }
(globalThis as any).FileReader=FR;
const ctx:any=new Proxy({canvas:null,createImageData:(w:number,h:number)=>({data:new Uint8ClampedArray(w*h*4),width:w,height:h}),getImageData:(x:number,y:number,w:number,h:number)=>({data:new Uint8ClampedArray(w*h*4),width:w,height:h}),createLinearGradient:()=>({addColorStop(){}}),createRadialGradient:()=>({addColorStop(){}}),measureText:()=>({width:10})},{get:(o,p)=>p in o?o[p]:()=>{}});
(globalThis as any).document={createElement:(kind:string)=>{const c:any={width:512,height:512,getContext:()=>ctx};ctx.canvas=c;return c}};
let seed=0x15100001;(Math as any).random=()=>{seed=(seed+0x6D2B79F5)|0;let t=seed;t=Math.imul(t^t>>>15,t|1);t^=t+Math.imul(t^t>>>7,t|61);return((t^t>>>14)>>>0)/4294967296};
const {Pods}=await import("/home/user/NEXUS-15.1-source/src/scene/Workshop.ts");
const {Vault}=await import("/home/user/NEXUS-15.1-source/src/scene/Vault.ts");
const {Transit}=await import("/home/user/NEXUS-15.1-source/src/scene/Transit.ts");
const {larva}=await import("/home/user/NEXUS-15.1-source/src/scene/Larva.ts");
const {instrumentModel}=await import("/home/user/NEXUS-15.1-source/src/scene/Instruments.ts");
const {VehicleModel}=await import("/home/user/NEXUS-15.1-source/src/vehicle/VehicleModel.ts");
const {Effects}=await import("/home/user/NEXUS-15.1-source/src/scene/Effects.ts");
const {glove}=await import("/home/user/NEXUS-15.1-source/src/scene/Glove.ts");
const {TelemetryScreen}=await import("/home/user/NEXUS-15.1-source/src/scene/TelemetryScreen.ts");
const {Display}=await import("/home/user/NEXUS-15.1-source/src/scene/Displays.ts");
const {Cockpit}=await import("/home/user/NEXUS-15.1-source/src/vehicle/Cockpit.ts");
const {Touch}=await import("/home/user/NEXUS-15.1-source/src/scene/Touch.ts");
const finish=(v:number)=>new T.MeshStandardMaterial({color:v});
const assets:any[]=[];
function pick(x:any){for(const k of ["group","root","train"]){if(x?.[k] instanceof T.Object3D)return x[k]}if(x instanceof T.Object3D)return x;throw Error("no root")}
try{assets.push(["workshop_pods",pick(new Pods())])}catch(e){console.error("Pods",e)}
try{assets.push(["vault",pick(new Vault())])}catch(e){console.error("Vault",e)}
try{assets.push(["transit",pick(new Transit())])}catch(e){console.error("Transit",e)}
for(let i=0;i<3;i++){const g=new T.Group();try{larva(g,i);assets.push([`larva_${i}`,g])}catch(e){console.error("Larva",i,e)}}
for(let i=0;i<3;i++)try{assets.push([`instrument_${i}`,instrumentModel(i,finish)])}catch(e){console.error("Instrument",i,e)}
try{assets.push(["vehicle",pick(new VehicleModel())])}catch(e){console.error("Vehicle",e)}
try{assets.push(["effects",pick(new Effects())])}catch(e){console.error("Effects",e)}
for(const pose of ["press","drawer","grip","lamp","flat","round","box"] as const)try{assets.push([`glove_${pose}`,glove(pose,finish)])}catch(e){console.error("Glove",pose,e)}
try{assets.push(["telemetry_screen",new TelemetryScreen().face])}catch(e){console.error("Telemetry",e)}
try{const g=new T.Group();new Display(g,0,0,0,1,.5);assets.push(["display",g])}catch(e){console.error("Display",e)}
try{const g=new T.Group();new Cockpit(g);assets.push(["cockpit",g])}catch(e){console.error("Cockpit",e)}
try{const camera=new T.PerspectiveCamera();new Touch(camera);camera.traverse(o=>o.visible=true);assets.push(["touch_rig_assets",camera])}catch(e){console.error("Touch",e)}
const out="/home/user/NEXUS-Native-audit/assets/generated/source-batch";await import("node:fs").then(fs=>fs.mkdirSync(out,{recursive:true}));
const exporter=new GLTFExporter();const report:any[]=[];
for(const [name,root] of assets){root.traverse((o:any)=>{if(o.material){for(const m of (Array.isArray(o.material)?o.material:[o.material])){m.map=null;m.bumpMap=null;m.normalMap=null;m.alphaMap=null;m.emissiveMap=null}}});const data:any=await exporter.parseAsync(root,{binary:true,onlyVisible:false});const buf=Buffer.from(data);await import("node:fs").then(fs=>fs.writeFileSync(`${out}/${name}.glb`,buf));let meshes=0;root.traverse((o:any)=>{if(o.isMesh)meshes++});report.push({name,bytes:buf.length,meshes})}
console.log(JSON.stringify(report,null,2));
