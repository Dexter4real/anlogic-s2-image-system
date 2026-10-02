"""Independent scalar reference + cycle-accurate RTL comparison, no vendor IP."""
from pathlib import Path
import subprocess, json, random, argparse, os, shutil
from PIL import Image, ImageDraw
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'sim/out';OUT.mkdir(parents=True,exist_ok=True)
IVER=os.environ.get('IVERILOG') or shutil.which('iverilog') or 'C:/iverilog/bin/iverilog.exe'
VVP=os.environ.get('VVP') or shutil.which('vvp') or 'C:/iverilog/bin/vvp.exe'
def reference(frame,mode,bright,contrast,level):
    w,h=frame.size; pix=frame.load(); result=Image.new('RGB',(w,h)); dst=result.load()
    gray=[[sum((pix[x,y][0],2*pix[x,y][1],pix[x,y][2]))//4 for x in range(w)] for y in range(h)]
    factors=[3,4,5]; thresholds=[40,80,160,320,640]
    for y in range(h):
      for x in range(w):
        c=pix[x,y]
        if mode==1: c=tuple(max(0,min(255,((v-128)*factors[contrast])//4+128+(bright-2)*16)) for v in c)
        elif mode==2:
          v=0
          if x>=2 and y>=2:
            q=[[gray[y-2+j][x-2+i] for i in range(3)] for j in range(3)]
            gx=sum(q[j][2]*[1,2,1][j]-q[j][0]*[1,2,1][j] for j in range(3))
            gy=sum(q[0][i]*[1,2,1][i]-q[2][i]*[1,2,1][i] for i in range(3))
            v=255 if abs(gx)+abs(gy)>=thresholds[level] else 0
          c=(v,v,v)
        dst[x,y]=c
    return result
def run(w,h,cases,name,reset_between=False):
    folder=OUT/name;folder.mkdir(exist_ok=True)
    vectors=[]; expected=[]; images=[]
    def tick(rst=1,de=0,x=0,y=0,rgb=0,m=0,b=2,c=1,e=2,sel=0,hs=0,vs=0,expect=0):
      vectors.append(f'{rst} {de} {hs} {vs} {x} {y} {rgb:06x} {m} {b} {c} {e} {sel}\n')
      expected.append((rst,de,hs,vs,x,y,expect,m,b,c,e,sel))
    tick(rst=0);tick(rst=0)
    for idx,(frame,m,b,c,e) in enumerate(cases):
      if reset_between and idx: tick(rst=0);tick(rst=0)
      ref=reference(frame,m,b,c,e); start=len(vectors);valid_positions=[]
      for y in range(h):
       for x in range(w):
        # Mid-line bubbles must not advance line memories or horizontal windows.
        if name=='regression' and (x+y)%17==3: tick()
        color=frame.getpixel((x,y));color=(color[0]<<16)|(color[1]<<8)|color[2]
        r=ref.getpixel((x,y));r=(r[0]<<16)|(r[1]<<8)|r[2]
        valid_positions.append(len(vectors))
        tick(de=1,x=x,y=y,rgb=color,m=m,b=b,c=c,e=e,sel=idx%2,expect=r)
       for _ in range(5):tick(hs=1)
      for _ in range(9):tick(vs=1)
      images.append((frame,ref,valid_positions))
    for _ in range(6):tick()
    (folder/'input.txt').write_text(''.join(vectors),encoding='ascii')
    tb='''`timescale 1ns/1ps
module tb;
reg clk=0;always #5 clk=~clk;
reg rst=0,de=0,hs=0,vs=0,sel=0;reg [11:0] x=0,y=0;reg [23:0] rgb=0;
reg [1:0] m=0,c=1;reg [2:0] b=2,e=2;
wire od,oh,ov,os;wire [11:0] ox,oy;wire [23:0] orgb;wire [1:0] om,oc;wire [2:0] ob,oe;
s2_pixels #(.WIDTH(WIDTH_VALUE)) dut(clk,rst,de,hs,vs,x,y,rgb,m,c,b,e,sel,od,oh,ov,ox,oy,orgb,om,oc,ob,oe,os);
integer fi,fo,n;
initial begin
fi=$fopen("input.txt","r");fo=$fopen("output.txt","w");
while(!$feof(fi)) begin
 @(negedge clk);n=$fscanf(fi,"%d %d %d %d %d %d %h %d %d %d %d %d\\n",rst,de,hs,vs,x,y,rgb,m,b,c,e,sel);
 if(n!=12) $fatal(1,"bad vector");
 @(posedge clk);#1;
 $fwrite(fo,"%b %b %b %d %d %h %d %d %d %d %b\\n",od,oh,ov,ox,oy,orgb,om,ob,oc,oe,os);
end
$fclose(fo);$finish;
end
endmodule
'''.replace('WIDTH_VALUE',str(w))
    (folder/'tb.v').write_text(tb)
    subprocess.run([IVER,'-g2012','-Wall','-s','tb','-o','sim.vvp','tb.v',str(ROOT/'rtl/s2_pixels.v')],cwd=folder,check=True,capture_output=True)
    subprocess.run([VVP,'sim.vvp'],cwd=folder,check=True,capture_output=True)
    lines=(folder/'output.txt').read_text().splitlines();assert len(lines)==len(vectors)
    last_reset=0; mismatches=[];actual=[]
    for i,line in enumerate(lines):
      tokens=line.split(); got=[int(v,16 if k==5 else 10) if not any(c in v for c in 'xz') else -1 for k,v in enumerate(tokens)]
      actual.append(got)
      if expected[i][0]==0:
       last_reset=i
       assert got[0:3]==[0,0,0] and got[5]==0, ('reset output',i,got)
      if i-last_reset<5: continue
      src=expected[i-4]; want=list(src[1:]);
      if not src[1]:want[5]=0
      if got!=want:
       mismatches.append({'cycle':i,'got':got,'want':want})
       if len(mismatches)>8:break
    if mismatches:raise AssertionError(json.dumps(mismatches))
    for idx,(frame,ref,positions) in enumerate(images):
      if name!='preview':continue
      im=Image.new('RGB',(w,h));im.putdata([((actual[p+4][5]>>16)&255,(actual[p+4][5]>>8)&255,actual[p+4][5]&255) for p in positions])
      assert im.tobytes()==ref.tobytes()
      im.save(folder/f'rtl_{idx}.png');frame.save(folder/'input.png')
    return dict(name=name,cycles=len(vectors),frames=len(cases),pixels=w*h*len(cases),passed=True)
def main():
    rng=random.Random(20260923);w,h=64,32
    frames=[]
    for kind in range(5):
      im=Image.new('RGB',(w,h))
      if kind==0:im.putdata([(v%256,v%256,v%256) for v in range(w*h)])
      if kind==1:im.putdata([tuple(rng.randrange(256) for _ in range(3)) for _ in range(w*h)])
      if kind==2:im.putdata([((255,0,0) if (x//4)%2 else (0,255,255)) for y in range(h) for x in range(w)])
      if kind==3:im.paste((255,255,255),(0,0,w,h))
      frames.append(im)
    cases=[(frames[0],1,b,c,2) for b in range(5) for c in range(3)]
    cases +=[(im,1,b,c,2) for im in frames[1:3] for b in range(5) for c in range(3)]
    cases +=[(im,2,2,1,e) for im in frames for e in range(5)]
    cases +=[(im,0,2,1,2) for im in frames]
    results=[run(w,h,cases,'regression'),run(w,h,[(im,2,2,1,2) for im in frames[:4]],'reset',True)]
    im=Image.new('RGB',(1280,8));im.putdata([((x*31)%256,(y*67)%256,(x+y)%256) for y in range(8) for x in range(1280)])
    results.append(run(1280,8,[(im,2,2,1,2),(im,0,2,1,2)],'width1280'))
    im=Image.new('RGB',(640,360));im.putdata([(int(20+100*x/639),int(20+90*y/359),50) for y in range(360) for x in range(640)])
    dr=ImageDraw.Draw(im);dr.rectangle((90,130,250,310),fill=(100,45,35));dr.ellipse((350,140,530,320),fill=(35,90,60));dr.text((195,90),'FPGA S2 - SYNTHETIC TEST IMAGE',fill=(150,150,150))
    results.append(run(640,360,[(im,0,2,1,2),(im,1,4,2,2),(im,2,2,1,1)],'preview'))
    (ROOT/'evidence/pixel_tests.json').write_text(json.dumps(results,indent=2))
    print(json.dumps(results,indent=2))
if __name__=='__main__':main()
