#!/usr/bin/env python3
"""Deterministically bake the three procedural textures from src/scene/materials.ts."""
from __future__ import annotations
import argparse, hashlib, json, math, random
from pathlib import Path
from PIL import Image, ImageDraw

SEEDS = {"skin": 151001, "iris": 151002, "floor": 151003}
SOURCE = "src/scene/materials.ts"
COMMIT = "f4e1e819a9c783374e79dbc99cde4597099aba11"

def clamp(v: float) -> int: return max(0, min(255, round(v)))
def alpha_layer(base: Image.Image, layer: Image.Image) -> None: base.alpha_composite(layer)

def skin() -> Image.Image:
    rng=random.Random(SEEDS["skin"]); w,h=1024,512
    data=[]
    for y in range(h):
        for x in range(w):
            bands=math.sin(y*.09+math.sin(x*.017)*3+math.sin(y*.034+x*.012)*6)
            grain=rng.random()*17+9*bands+9*math.sin(x*.035+math.sin(y*.023)*2)*math.cos(y*.053+math.sin(x*.018)*3)+math.sin(x*.04-y*.07)*9
            marble=math.sin(x*.027+4*math.sin(y*.019)+2*math.cos(y*.042+x*.007))*math.sin(y*.039+3*math.sin(x*.014))
            data.append((clamp(112+grain+17*marble),clamp(61+grain*.63+21*marble),clamp(63+grain*.63+16*marble),255))
    image=Image.new("RGBA",(w,h)); image.putdata(data)
    for _ in range(58):
        cx,cy,r=rng.random()*w,rng.random()*h,18+rng.random()*100
        rgb=(181,88,91) if rng.random()>.5 else (27,16,20); peak=.18 if rgb[0]>100 else .22
        box=(max(0,int(cx-r)),max(0,int(cy-r)),min(w,int(cx+r)+1),min(h,int(cy+r)+1)); layer=Image.new("RGBA",(w,h))
        px=layer.load()
        for yy in range(box[1],box[3]):
            for xx in range(box[0],box[2]):
                d=math.hypot(xx-cx,yy-cy)/r
                if d<1: px[xx,yy]=(*rgb,clamp(255*peak*(1-d)))
        alpha_layer(image,layer)
    draw=ImageDraw.Draw(image,"RGBA")
    for _ in range(40):
        x,y=rng.random()*w,rng.random()*h
        p0=(x,y); p1=(x+(rng.random()-.5)*90,y+30+rng.random()*55); p2=(x+(rng.random()-.5)*140,y-40+rng.random()*120); p3=(x+(rng.random()-.5)*170,y+(rng.random()-.5)*180)
        pts=[]
        for n in range(25):
            t=n/24; q=1-t
            pts.append((q**3*p0[0]+3*q*q*t*p1[0]+3*q*t*t*p2[0]+t**3*p3[0],q**3*p0[1]+3*q*q*t*p1[1]+3*q*t*t*p2[1]+t**3*p3[1]))
        draw.line(pts,fill=(161,63,65,clamp(255*(.12+rng.random()*.18))),width=max(1,round(1+rng.random()*2.2)))
    def vein(x:float,y:float,a:float,length:float,depth:int)->None:
        pts=[(x,y)]
        for _ in range(6):
            a+=(rng.random()-.5)*.48; x+=math.cos(a)*length/6; y+=math.sin(a)*length/6; pts.append((x,y))
        draw.line(pts,fill=(78,39,60,clamp(255*(.17+depth*.07))),width=max(1,round(.44+depth*.5)))
        if depth: vein(x,y,a+.42,length*.68,depth-1); vein(x,y,a-.57,length*.57,depth-1)
    for _ in range(65): vein(rng.random()*w,rng.random()*h,rng.random()*6.28,22+rng.random()*45,3)
    for _ in range(7800):
        x,y,r=rng.random()*w,rng.random()*h,.35+rng.random()*1.4
        draw.ellipse((x-r,y-r*.66,x+r,y+r*.66),fill=(45,18,29,66)); draw.rectangle((x,y+r*.5,x+r,y+r*.5+.6),fill=(214,168,141,46))
    return image

def iris() -> Image.Image:
    rng=random.Random(SEEDS["iris"]); s=512; c=s/2; image=Image.new("RGBA",(s,s)); px=image.load()
    stops=[(0,(24,13,17)),(.23,(82,37,45)),(.42,(167,77,62)),(.64,(115,52,47)),(.84,(193,128,85)),(1,(50,24,29))]
    for y in range(s):
        for x in range(s):
            t=min(1,max(0,(math.hypot(x-c,y-c)-20)/(c-20)))
            for j in range(len(stops)-1):
                if t<=stops[j+1][0]:
                    a,ca=stops[j]; b,cb=stops[j+1]; f=(t-a)/(b-a); px[x,y]=tuple(clamp(ca[k]+(cb[k]-ca[k])*f) for k in range(3))+(255,); break
    draw=ImageDraw.Draw(image,"RGBA"); colors=[(237,161,102,128),(37,13,22,158),(213,89,62,122)]
    for i in range(310):
        a=i/310*math.tau+(rng.random()-.5)*.07; inner=58+rng.random()*42; outer=135+rng.random()*100
        draw.line((c+math.cos(a)*inner,c+math.sin(a)*inner,c+math.cos(a)*outer,c+math.sin(a)*outer),fill=colors[i%3],width=max(1,round(1+rng.random()*2.1)))
    for ring in range(5):
        r=130+ring*21; draw.ellipse((c-r,c-r,c+r,c+r),outline=(235,130+ring*10,82,clamp(255*(.22+ring*.035))),width=2 if ring%2==0 else 1)
    return image

def floor() -> Image.Image:
    rng=random.Random(SEEDS["floor"]); s=512; image=Image.new("RGBA",(s,s),(32,35,35,255)); draw=ImageDraw.Draw(image,"RGBA")
    for _ in range(14000):
        shade=int(18+rng.random()*35); x,y=rng.random()*s,rng.random()*s
        draw.rectangle((x,y,x+1+rng.random()*4,y+1+rng.random()*3),fill=(shade+4,shade+5,shade+4,clamp(rng.random()*.34*255)))
    for i in range(9):
        x=i*64; draw.line((x,0,x+(rng.random()-.5)*30,s),fill=(7,9,10,115),width=3)
    return image

def main()->None:
    ap=argparse.ArgumentParser(); ap.add_argument("output",type=Path); ap.add_argument("report",type=Path); args=ap.parse_args(); args.output.mkdir(parents=True,exist_ok=True)
    specs={"nexus_skin.png":(skin(),"sRGB",[1.5,1.15]),"nexus_iris.png":(iris(),"sRGB",[1,1]),"nexus_floor.png":(floor(),"sRGB",[6,6])}; assets=[]
    for name,(im,space,repeat) in specs.items():
        path=args.output/name; im.convert("RGB").save(path,"PNG",optimize=False,compress_level=9)
        assets.append({"path":path.as_posix(),"sha256":hashlib.sha256(path.read_bytes()).hexdigest(),"width":im.width,"height":im.height,"color_space":space,"repeat":repeat,"seed":SEEDS[name.split('_')[1].split('.')[0]]})
    report={"schema":1,"source_file":SOURCE,"source_commit":COMMIT,"random_policy":"Python MT19937 fixed seeds; formulas and draw order ported from source; rasterizer is Pillow rather than browser Canvas2D","assets":assets}
    args.report.parent.mkdir(parents=True,exist_ok=True); args.report.write_text(json.dumps(report,indent=2,sort_keys=True)+"\n")
    print(json.dumps(report,indent=2))
if __name__=="__main__": main()
