"""Offline oak-film technical-map candidate; original albedo bytes are retained.

The shellac microrelief and roughness are independent periodic fields, not
lighting inferred from the generated wood pigment. No production publication.
"""
from pathlib import Path
import argparse,hashlib,json,shutil
import numpy as np
from PIL import Image
ROOT=Path(__file__).resolve().parents[3]
def build(source,out):
    source=source.resolve();out=out.resolve()
    allowed=[ROOT/'art/reviews/v2_panel_oak_20261018',ROOT/'tmp/v2-panel-oak-20261018']
    if not any(out.is_relative_to(path) for path in allowed):raise ValueError('Offline review output only')
    out.mkdir(parents=True,exist_ok=True)
    size,tile=2048,.6;rng=np.random.default_rng(1928101806)
    fx,fy=np.meshgrid(np.fft.fftfreq(size),np.fft.fftfreq(size))
    def field(x,y):
        f=np.fft.ifft2(np.fft.fft2(rng.standard_normal((size,size)))*np.exp(-(fx/x)**2-(fy/y)**2)).real
        return (f-f.mean())/f.std()
    fibers=field(.20,.014);film=field(.09,.09);broad=field(.012,.012)
    height_m=fibers*.0000025+film*.0000006
    dx=(np.roll(height_m,-1,1)-np.roll(height_m,1,1))*size/(2*tile)
    dy=(np.roll(height_m,-1,0)-np.roll(height_m,1,0))*size/(2*tile)
    normal=np.stack((-dx,dy,np.ones_like(dx)),axis=-1);normal/=np.linalg.norm(normal,axis=-1)[...,None]
    roughness=np.clip(.30+broad*.012+film*.008,.24,.38)
    extent=float(abs(height_m).max())
    Image.fromarray(np.rint(np.clip(normal*.5+.5,0,1)*255).astype('uint8')).save(out/'normal.png')
    Image.fromarray(np.rint(roughness*255).astype('uint8')).save(out/'roughness.png')
    Image.fromarray(np.rint((height_m/(extent*2)+.5)*65535).astype('uint16')).save(out/'height.png')
    shutil.copyfile(source,out/'albedo_source.png')
    d=dict(evidence_class='INERT',status='UNINSTALLED_CANDIDATE',generator='art/blender/arcade_fabric_candidate/build_panel_oak_maps.py',source=source.relative_to(ROOT).as_posix(),source_sha256=hashlib.sha256(source.read_bytes()).hexdigest(),meters_per_tile=tile,size=size,seed=1928101806,normal_convention='OpenGL',planned_normal_gain=1.,planned_roughness_gain=1.,metallic=0.,roughness_range=[float(roughness.min()),float(roughness.max())],relief_rms_microns=float(height_m.std()*1e6),height_range_microns=[-extent*1e6,extent*1e6],maximum_normal_slope=float(np.hypot(dx,dy).max()),physical_scope=__doc__,pending=['Albedo tiling/appearance review','Catalogue registration and runtime ingest','Actual UV orientation and loaded mip qualification','Composed diffuse/grazing/carried-light review','Human acceptance'])
    d['map_sha256']={name:hashlib.sha256((out/name).read_bytes()).hexdigest() for name in ['albedo_source.png','normal.png','roughness.png','height.png']}
    (out/'material_candidate.json').write_text(json.dumps(d,indent=2)+'\n',encoding='utf8',newline='\n')
    return d
if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--source',type=Path,required=True);p.add_argument('--out',type=Path,required=True);a=p.parse_args();print(json.dumps(build(a.source,a.out),indent=2))
