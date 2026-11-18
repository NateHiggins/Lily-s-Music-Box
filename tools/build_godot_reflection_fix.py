"""Build the reflection-atlas and audio-shutdown fixes on 4.7.1; pin the lane.
No Godot process is launched here. Rendering tests still use tools/lane.ps1.
"""
import argparse,configparser,hashlib,json,os,shutil,subprocess,sys,urllib.request,zipfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
SOURCES=[('godot-4.7.1-stable.zip','https://github.com/godotengine/godot/archive/refs/tags/4.7.1-stable.zip','3d82fe7a78db5827a21382689919595734559270648dd5f44d3e829d5a2472e6'),('llvm-mingw.zip','https://github.com/mstorsjo/llvm-mingw/releases/download/20261020/llvm-mingw-20261020-ucrt-x86_64.zip','fd5462b7f5d93b2ff981fcd3f9c7e427e47f3203c64ea91c27bcc444eebd74cd')]
PATCHES=[('reflection_atlas_4_7_1.patch','86ab87598f732271991332a2be5f4ba1f6e2987fbacc21030e39645ab9b3010f'),('audio_playback_shutdown_4_7_1.patch','04d87ee4797404cf490bcea45d3bed0beaaf201dc34a844e9909fdfa1b57a3d1')]
TEMPLATE_CACHE=Path('game/.godot/orison_templates')
TEMPLATE_FILES={'runtime':'windows_release.exe','console':'windows_release.console.exe'}
TEMPLATE_RESOURCE='res://.godot/orison_templates/windows_release.exe'
RELEASE_OPTIONS={'disable_path_overrides':'no'}

def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()

def publish_template(binaries, provenance):
 """Stage a local release template without changing the editor pin or installed templates."""
 cache=ROOT/TEMPLATE_CACHE;cache.mkdir(parents=True,exist_ok=True)
 selected={'runtime':next(p for p in binaries if '.console.' not in p.name),
           'console':next(p for p in binaries if '.console.' in p.name)}
 hashes={}
 for role,source in selected.items():
  destination=cache/TEMPLATE_FILES[role]
  shutil.copy2(source,destination)
  hashes[role]=sha(destination)
 manifest=dict(provenance,schema='orison.godot-template.v1',target='template_release',binaries=hashes,release_options=RELEASE_OPTIONS)
 (cache/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf8')
 return manifest

def check_template():
 """Refuse a missing, changed or differently sourced release template before export."""
 cache=ROOT/TEMPLATE_CACHE
 try:manifest=json.loads((cache/'manifest.json').read_text(encoding='utf8'))
 except (OSError,ValueError) as error:raise RuntimeError('Patched Windows template is absent; build --target template_release first') from error
 if not isinstance(manifest,dict):raise RuntimeError('Patched Windows template manifest must be an object')
 expected={'schema':'orison.godot-template.v1','target':'template_release','base':'4.7.1-stable',
           'source_archives':{n:h for n,u,h in SOURCES},'local_patches':dict(PATCHES),'release_options':RELEASE_OPTIONS}
 for key,value in expected.items():
  if manifest.get(key)!=value:raise RuntimeError('Patched Windows template provenance mismatch: '+key)
 if not isinstance(manifest.get('binaries'),dict) or set(manifest['binaries'])!=set(TEMPLATE_FILES):raise RuntimeError('Expected runtime and console template hashes')
 for role,name in TEMPLATE_FILES.items():
  path=cache/name
  if not path.is_file() or sha(path)!=manifest['binaries'][role]:raise RuntimeError('Patched Windows template hash mismatch: '+role)
 for name,digest in PATCHES:
  if sha(ROOT/'tools/engine_patches'/name)!=digest:raise RuntimeError('Current patch hash mismatch: '+name)
 presets=configparser.ConfigParser(interpolation=None)
 try:
  with (ROOT/'game/export_presets.cfg').open(encoding='utf8') as stream:presets.read_file(stream)
 except (OSError,configparser.Error) as error:raise RuntimeError('Cannot read Windows export preset') from error
 windows=[section for section in presets.sections() if not section.endswith('.options') and presets.get(section,'name',fallback='')=='"Windows"']
 if len(windows)!=1 or presets.get(windows[0]+'.options','custom_template/release',fallback='')!=json.dumps(TEMPLATE_RESOURCE):
  raise RuntimeError('Windows release preset does not select the pinned local template')
 return manifest

def main():
 ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('--directory',type=Path,default=Path('C:/devkit/tentacle-audio-20261104-01'));ap.add_argument('--jobs',type=int,default=12);ap.add_argument('--configure-only',action='store_true')
 ap.add_argument('--target',choices=['editor','template_release'],default='editor')
 ap.add_argument('--archive-directory',type=Path,help='Reuse verified archives without downloading duplicate copies')
 ap.add_argument('--compiler-directory',type=Path,help='Reuse the extracted pinned LLVM MinGW directory')
 ap.add_argument('--check-template',action='store_true',help='Read-only check of the staged release template; no build or engine launch')
 a=ap.parse_args()
 if a.check_template:
  check_template();print('PATCHED WINDOWS TEMPLATE CHECK PASS');return
 if a.configure_only and a.target=='template_release':
  ap.error('--configure-only is editor-only; release outputs must pass the normal SCons build before staging')
 if a.jobs<1:ap.error('--jobs must be positive')
 base=a.directory.resolve();base.mkdir(parents=True,exist_ok=True)
 source=base/'godot-4.7.1-stable';compiler=a.compiler_directory.resolve() if a.compiler_directory else base/'llvm-mingw-20261020-ucrt-x86_64'
 archives=a.archive_directory.resolve() if a.archive_directory else base
 if not a.configure_only:
  archives.mkdir(parents=True,exist_ok=True)
  for name,url,digest in SOURCES:
   archive=archives/name
   if not archive.exists():
    if a.configure_only:raise RuntimeError('Verified source archive is absent: '+name)
    urllib.request.urlretrieve(url,archive)
   if sha(archive)!=digest:raise RuntimeError('Source archive hash mismatch: '+name)
   destination=source if name.startswith('godot') else compiler
   if not destination.exists():
    if a.configure_only:raise RuntimeError('Configured source/toolchain is absent: '+str(destination))
    extraction_root=source.parent if name.startswith('godot') else compiler.parent
    with zipfile.ZipFile(archive) as z:
     if any(not (extraction_root/n).resolve().is_relative_to(extraction_root) for n in z.namelist()):raise RuntimeError('Escaping archive member')
     z.extractall(extraction_root)
 for name,digest in PATCHES:
  patch=ROOT/'tools/engine_patches'/name
  if sha(patch)!=digest:raise RuntimeError('Patch hash mismatch: '+name)
  reverse=subprocess.run(['git','apply','--reverse','--check',str(patch)],cwd=source,capture_output=True)
  if reverse.returncode:
   if a.configure_only:raise RuntimeError('Configured source is missing patch: '+name)
   subprocess.run(['git','apply',str(patch)],cwd=source,check=True)
 if not a.configure_only:
  env=os.environ.copy();env['PATH']=str(compiler/'bin')+os.pathsep+env['PATH']
  release_options=[key+'='+value for key,value in RELEASE_OPTIONS.items()] if a.target=='template_release' else []
  subprocess.run([sys.executable,'-m','SCons','platform=windows','target='+a.target,'arch=x86_64','use_mingw=yes','use_llvm=yes','mingw_prefix='+str(compiler),'debug_symbols=no','optimize=speed','lto=none','winrt=no','accesskit=no','d3d12=no','-j'+str(a.jobs)]+release_options,cwd=source,env=env,check=True)
 binaries=sorted((source/'bin').glob('godot.windows.'+a.target+'.x86_64*.exe'))
 if a.target=='template_release':
  # Never select a stale non-LLVM build merely because it sorts first.
  stem=source/'bin/godot.windows.template_release.x86_64.llvm'
  binaries=[Path(str(stem)+'.exe'),Path(str(stem)+'.console.exe')]
  if not all(p.is_file() for p in binaries):raise RuntimeError('Expected the exact LLVM release runtime and console outputs')
 if len(binaries)<2:raise RuntimeError('Expected engine and console wrapper outputs')
 console=next(p for p in binaries if '.console.' in p.name)
 if a.target=='template_release':
  manifest=publish_template(binaries,dict(base='4.7.1-stable',source_archives={n:h for n,u,h in SOURCES},local_patches=dict(PATCHES),build_options='Vulkan, LLVM MinGW; D3D12/WinRT/AccessKit disabled; path overrides enabled for packaged qualification'))
  check_template();print(json.dumps(manifest,indent=2));return
 manifest=dict(path=str(console),sha256=sha(console),binaries={str(p):sha(p) for p in binaries},base='4.7.1-stable',upstream_fix='https://github.com/godotengine/godot/pull/124743',source_archives={n:h for n,u,h in SOURCES},local_patches=dict(PATCHES),build_options='Vulkan, LLVM MinGW; D3D12/WinRT/AccessKit disabled; remaining default editor features')
 (ROOT/'.godot-engine.json').write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf8')
 print(json.dumps(manifest,indent=2))
if __name__=='__main__':main()
