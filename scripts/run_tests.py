"""Portable regression; --full requires the team package's official baseline."""
from pathlib import Path
import argparse, datetime, hashlib, json, os, shutil, subprocess, sys, traceback
ROOT=Path(__file__).resolve().parents[1]
def executable(env, name):
    value=os.environ.get(env) or shutil.which(name)
    fallback=Path('C:/iverilog/bin')/(name+'.exe')
    if not value and fallback.is_file(): value=str(fallback)
    if not value: raise RuntimeError('Missing '+name+': install Icarus Verilog and add its bin to PATH, or set '+env)
    return value
def main():
    ap=argparse.ArgumentParser();ap.add_argument('--full',action='store_true');args=ap.parse_args()
    iv=executable('IVERILOG','iverilog');vv=executable('VVP','vvp')
    stamp=datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%dT%H%M%SZ')
    output=ROOT/'sim/out'/stamp;output.mkdir(parents=True,exist_ok=False)
    os.environ['IVERILOG']=iv;os.environ['VVP']=vv;os.environ['PYTHONUTF8']='1'
    evidence=ROOT/'evidence';evidence.mkdir(exist_ok=True)
    sources={str(p.relative_to(ROOT)).replace('\\','/'):hashlib.sha256(p.read_bytes()).hexdigest()
      for name in ('rtl','sim','scripts') for p in sorted((ROOT/name).rglob('*'))
      if p.is_file() and 'out' not in p.parts and '__pycache__' not in p.parts}
    result={'passed':False,'started_utc':stamp,'full':args.full,'source_sha256':sources,
      'scope':'RTL only; full adds original video_out with a limited FIFO substitute. No vendor IP/DDR/camera/board validation.'}
    commands=[[iv,'-g2012','-Wall','-s','tb_controls','-o',str(output/'controls.vvp'),str(ROOT/'rtl/s2_controls.v'),str(ROOT/'sim/tb_controls.v')],
      [vv,str(output/'controls.vvp')],[sys.executable,'-X','utf8',str(ROOT/'scripts/test_pixels.py')]]
    if args.full:
      h=ROOT/'baseline/user_source/hdl_source'
      for name in ('anlogic_logo_rom.v','osd_char_lib.v','video_out.v'):
        if not (h/name).is_file():raise RuntimeError('Full test requires team package baseline: '+name)
      commands += [[iv,'-g2012','-s','tb_auto','-o',str(output/'auto.vvp'),str(ROOT/'sim/tb_auto.v'),*[str(p) for p in sorted((ROOT/'rtl').glob('*.v'))],str(h/'anlogic_logo_rom.v'),str(h/'osd_char_lib.v')],
        [vv,str(output/'auto.vvp')],[sys.executable,'-X','utf8',str(ROOT/'scripts/test_display.py')]]
    with (output/'run.log').open('w',encoding='utf-8') as log:
      try:
        for command in commands:
          run=subprocess.run(command,cwd=ROOT,capture_output=True,text=True,encoding='utf-8',errors='replace')
          log.write('COMMAND '+repr(command)+'\n'+run.stdout+run.stderr+'\n');log.flush()
          print(run.stdout,flush=True)
          if run.returncode:raise RuntimeError('Test failed, exit '+str(run.returncode)+': '+run.stderr)
        result['passed']=True
      except Exception:
        result['error']=traceback.format_exc();raise
      finally:
        (output/'result.json').write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf-8')
        temp=evidence/'portable_test_run.tmp'
        temp.write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf-8')
        temp.replace(evidence/'portable_test_run.json')
    print('ALL_TESTS_PASSED (RTL simulation; hardware remains UNVERIFIED)')
if __name__=='__main__':main()
