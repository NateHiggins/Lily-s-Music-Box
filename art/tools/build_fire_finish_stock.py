"""Candidate cabinet enamel and expressive glass; publish only after render review."""
from pathlib import Path
import argparse, hashlib, json
import numpy as np
from PIL import Image
from material_relief import relief, smooth_height
from ingest_material_sources import flatten_lighting, make_tileable, blur

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT/'art/textures/ai_sources/fire_enamel_20261020.png'
SETS = {
    'fire_cabinet_enamel': ('fired_enamel', [.39, .035, .022], .31, .015),
    'fire_cabinet_lining': ('porcelain', [.69, .67, .59], .26, .025),
    'fire_hardware_steel': ('worked_metal', [.23, .25, .26], .32, .035),
    'glass_drawn_expressive': ('glass_drawn', [.94, .98, .97], .09, .025),
    'glass_reeded': ('glass_reeded', [.94, .98, .97], .09, .02),
    'glass_cut': ('glass_cut', [.96, .985, .98], .065, .02),
    'glass_frosted': ('glass_frosted', [.96, .98, .97], .39, .065),
}


def build(destination):
    destination = destination.resolve()
    if not destination.is_relative_to(ROOT/'tmp'):
        raise ValueError('Candidates must remain under repository tmp')
    size, tile = 1024, .128
    source = np.asarray(Image.open(SOURCE).convert('RGB').resize((size, size)), dtype=float)/255
    source = make_tileable(flatten_lighting(source))
    source = np.asarray(Image.fromarray(np.uint8(np.clip(source, 0, 1)*255)).resize((size, size)), dtype=float)/255
    # Remove the scan's specular brightness from the pigment signal. Height is
    # independent construction data; pale painted highlights never become bumps.
    red = source[..., 0]/np.maximum(source.sum(axis=-1), .001)
    pigment = blur(red, 12)
    pigment = (pigment-pigment.mean())/max(pigment.std(), 1e-9)
    for i, (key, (profile, color, rough, variation)) in enumerate(SETS.items()):
        out = destination/key; out.mkdir(parents=True, exist_ok=True)
        height, normal, metadata = relief(profile, size, tile, 192810200+i)
        low = smooth_height(height, 8); low = (low-low.mean())/max(low.std(), 1e-12)
        albedo = np.broadcast_to(color, (size, size, 3)).copy()
        if key == 'fire_cabinet_enamel':
            albedo *= np.clip(1+pigment[..., None]*.012, .90, 1.10)
        elif 'glass' not in key:
            albedo *= np.clip(1+low[..., None]*.005, .985, 1.015)
        roughness = np.clip(rough+np.tanh(low)*variation, .025, .68)
        extent = max(float(np.abs(height).max()), 1e-12)
        maps = dict(albedo=np.clip(albedo, 0, 1), roughness=roughness,
                    normal=normal*.5+.5, height=height/(2*extent)+.5)
        for channel, value in maps.items():
            Image.fromarray(np.uint8(np.rint(value*255))).save(out/(channel+'.png'))
        data = dict(material=key, generator='art/tools/build_fire_finish_stock.py',
                    meters_per_tile=tile, normal_convention='OpenGL', normal_strength=1.,
                    normal_authoring=metadata, metallic=.88 if key=='fire_hardware_steel' else 0.,
                    height_encoding_range_m=[-extent, extent],
                    roughness_range=[float(roughness.min()), float(roughness.max())],
                    maps={channel: channel+'.png' for channel in maps},
                    status='CANDIDATE_NOT_INSTALLED',
                    source_image=str(SOURCE.relative_to(ROOT)) if key=='fire_cabinet_enamel' else None,
                    source_bindings={path.relative_to(ROOT).as_posix():hashlib.sha256(path.read_bytes().replace(b'\r\n',b'\n') if path.suffix=='.py' else path.read_bytes()).hexdigest()
                                     for path in (Path(__file__), ROOT/'art/tools/material_relief.py', SOURCE)})
        data['map_sha256']={channel:hashlib.sha256((out/(channel+'.png')).read_bytes()).hexdigest() for channel in maps}
        (out/'material.json').write_text(json.dumps(data, indent=2)+'\n', encoding='utf8', newline='\n')
        print(key, 'RMS micrometres', round(metadata['rms_relief_m']*1e6, 2),
              'max slope', round(metadata['maximum_slope'], 3))


if __name__ == '__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--out', type=Path, required=True)
    build(parser.parse_args().out)
