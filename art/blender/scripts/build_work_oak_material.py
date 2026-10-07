"""Keep the generated albedo intact; derive restrained physical maps in Blender."""
from pathlib import Path
import hashlib,json,shutil,sys
import bpy,numpy as np

r=next(p for p in Path(__file__).resolve().parents if (p/'game/project.godot').is_file())
source=r/'art/textures/ai_sources/oak_work_surface_20261007.png'
out=r/'art/textures/ai_materials/oak_work_surface';out.mkdir(parents=True,exist_ok=True)
image=bpy.data.images.load(str(source),check_existing=False)
image.colorspace_settings.name='Non-Color'
w,h=image.size;pixels=np.empty(w*h*4,dtype=np.float32);image.pixels.foreach_get(pixels)
rgb=pixels.reshape((h,w,4))[:,:,:3].astype(np.float64)
gray=rgb@np.array([.2126,.7152,.0722])
fy=np.fft.fftfreq(h)[:,None];fx=np.fft.fftfreq(w)[None,:]
def blur(values,sigma):return np.fft.ifft2(np.fft.fft2(values)*np.exp(-2*np.pi**2*sigma**2*(fx*fx+fy*fy))).real
detail=blur(gray,.9)-blur(gray,5.)
detail/=max(detail.std(),1e-8)
height=np.clip(detail,-3,3)*.000006
dx=(np.roll(height,-1,1)-np.roll(height,1,1))/(2*.9/w)
dy=(np.roll(height,-1,0)-np.roll(height,1,0))/(2*.9/h)
normal=np.stack((-dx,-dy,np.ones_like(dx)),axis=2)
normal/=np.linalg.norm(normal,axis=2)[:,:,None]
slow=blur(gray,36);slow=(slow-slow.mean())/max(slow.std(),1e-8)
rough=np.clip(.425+np.clip(slow,-2,2)*.009+np.clip(detail,-3,3)*.004,.38,.47)
def save(name,array):
    if array.ndim==2:array=np.repeat(array[:,:,None],3,axis=2)
    rgba=np.ones((h,w,4),dtype=np.float32);rgba[:,:,:3]=array
    im=bpy.data.images.new('work_oak_'+name,width=w,height=h,alpha=True,float_buffer=True)
    im.colorspace_settings.name='Non-Color';im.pixels.foreach_set(rgba.ravel());im.filepath_raw=str(out/(name+'.png'));im.file_format='PNG';im.save()
shutil.copyfile(source,out/'albedo.png')
save('normal',normal*.5+.5);save('roughness',rough);save('height',height/.000036+.5)
report={'material':'oak_work_surface','source':source.relative_to(r).as_posix(),'source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'generator':'art/blender/scripts/build_work_oak_material.py','meters_per_tile':.9,'resolution':[w,h],'maps':{k:k+'.png' for k in ['albedo','roughness','height','normal']},'height_range_m':[-.000018,.000018],'roughness_range':[float(rough.min()),float(rough.max())],'albedo_processing':'Unmodified generated source; no letters, object edges, board seams or baked scene lighting.','interpretation':'Analytic microrelief proxy, not a measured scan. Physical normal derivatives use the declared metre scale.','grain_texture_axis':'V'}
(out/'material.json').write_text(json.dumps(report,indent=2)+'\n',newline='\n')
print('WORK OAK',w,h,'height +/-18 micrometres; roughness',report['roughness_range'])
# Runtime-only materials are invisible to the editor's automatic 3D detector.
# Write their real import policy before the first engine launch.
sys.path.insert(0,str(r/'art/tools'))
from fix_runtime_texture_imports import patch
for source_name,runtime_name in [('albedo','albedo'),('roughness','rough'),('normal','normal')]:
 target=r/f'game/assets/building/textures/T_ai_materials_oak_work_surface_{runtime_name}.png';shutil.copyfile(out/(source_name+'.png'),target)
 sidecar=target.with_suffix('.png.import')
 if not sidecar.is_file():
  resource='res://'+target.relative_to(r/'game').as_posix();cache='res://.godot/imported/'+target.name+'-'+hashlib.md5(resource.encode()).hexdigest()+'.ctex'
  sidecar.write_text('[remap]\n\nimporter="texture"\ntype="CompressedTexture2D"\npath='+json.dumps(cache)+'\nmetadata={"vram_texture": false}\n\n[deps]\n\nsource_file='+json.dumps(resource)+'\ndest_files=['+json.dumps(cache)+']\n\n[params]\n\ncompress/mode=0\n',newline='\n')
 patch(sidecar)
