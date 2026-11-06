"""Build the reflection-atlas and audio-shutdown fixes on 4.7.1; pin the lane.
No Godot process is launched here. Rendering tests still use tools/lane.ps1.
"""
import argparse,hashlib,json,os,subprocess,sys,urllib.request,zipfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
SOURCES=[('godot-4.7.1-stable.zip','https://github.com/godotengine/godot/archive/refs/tags/4.7.1-stable.zip','3d82fe7a78db5827a21382689919595734559270648dd5f44d3e829d5a2472e6'),('llvm-mingw.zip','https://github.com/mstorsjo/llvm-mingw/releases/download/20261020/llvm-mingw-20261020-ucrt-x86_64.zip','fd5462b7f5d93b2ff981fcd3f9c7e427e47f3203c64ea91c27bcc444eebd74cd')]
PATCHES=[('reflection_atlas_4_7_1.patch','86ab87598f732271991332a2be5f4ba1f6e2987fbacc21030e39645ab9b3010f'),('audio_playback_shutdown_4_7_1.patch','04d87ee4797404cf490bcea45d3bed0beaaf201dc34a844e9909fdfa1b57a3d1')]

def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def main():
 ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('--directory',type=Path,default=Path('C:/devkit/tentacle-audio-20261104-01'));ap.add_argument('--jobs',type=int,default=12);ap.add_argument('--configure-only',action='store_true');a=ap.parse_args()
 base=a.directory.resolve();base.mkdir(parents=True,exist_ok=True)
 source=base/'godot-4.7.1-stable';compiler=base/'llvm-mingw-20261020-ucrt-x86_64'
 if not a.configure_only:
  for name,url,digest in SOURCES:
   archive=base/name
   if not archive.exists():urllib.request.urlretrieve(url,archive)
   if sha(archive)!=digest:raise RuntimeError('Source archive hash mismatch: '+name)
   destination=source if name.startswith('godot') else compiler
   if not destination.exists():
    with zipfile.ZipFile(archive) as z:
     if any(not (base/n).resolve().is_relative_to(base) for n in z.namelist()):raise RuntimeError('Escaping archive member')
     z.extractall(base)
 for name,digest in PATCHES:
  patch=ROOT/'tools/engine_patches'/name
  if sha(patch)!=digest:raise RuntimeError('Patch hash mismatch: '+name)
  reverse=subprocess.run(['git','apply','--reverse','--check',str(patch)],cwd=source,capture_output=True)
  if reverse.returncode:
   if a.configure_only:raise RuntimeError('Configured source is missing patch: '+name)
   subprocess.run(['git','apply',str(patch)],cwd=source,check=True)
 if not a.configure_only:
  env=os.environ.copy();env['PATH']=str(compiler/'bin')+os.pathsep+env['PATH']
  subprocess.run([sys.executable,'-m','SCons','platform=windows','target=editor','arch=x86_64','use_mingw=yes','use_llvm=yes','mingw_prefix='+str(compiler),'debug_symbols=no','optimize=speed','lto=none','winrt=no','accesskit=no','d3d12=no','-j'+str(a.jobs)],cwd=source,env=env,check=True)
 binaries=sorted((source/'bin').glob('godot.windows.editor.x86_64*.exe'))
 if len(binaries)<2:raise RuntimeError('Expected engine and console wrapper outputs')
 console=next(p for p in binaries if '.console.' in p.name)
 manifest=dict(path=str(console),sha256=sha(console),binaries={str(p):sha(p) for p in binaries},base='4.7.1-stable',upstream_fix='https://github.com/godotengine/godot/pull/124743',source_archives={n:h for n,u,h in SOURCES},local_patches=dict(PATCHES),build_options='Vulkan, LLVM MinGW; D3D12/WinRT/AccessKit disabled; remaining default editor features')
 (ROOT/'.godot-engine.json').write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf8')
 print(json.dumps(manifest,indent=2))
if __name__=='__main__':main()
