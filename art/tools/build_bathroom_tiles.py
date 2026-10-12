"""Registered periodic bathroom tile PBR: running-bond wall and 2-inch hex floor.

The generated glaze supplies microscopic pigment only. Joint geometry owns
height/normal/roughness together; there is no repeated baked grime or lighting.
"""
from pathlib import Path
import hashlib
import json
import shutil
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'art/textures/material_sources/bathroom_ivory_glaze.png'
SIZE = 1024
WIDTH = .6096


def smooth(a, b, x):
    t = np.clip((x-a)/(b-a), 0, 1)
    return t*t*(3-2*t)


def build(key):
    floor = key == 'bath_floor_tile'
    height_m = WIDTH * np.sqrt(3)/2 if floor else WIDTH
    yy, xx = np.mgrid[:SIZE, :SIZE]
    x = (xx+.5)/SIZE*WIDTH
    y = (yy+.5)/SIZE*height_m
    if floor:
        dx = .0508
        dy = dx*np.sqrt(3)/2
        # Three neighbouring centre rows suffice for the nearest regular hex.
        row0 = np.rint(y/dy).astype(int)
        distance = np.full(x.shape, -np.inf)
        cell_x = np.zeros_like(xx)
        cell_y = np.zeros_like(yy)
        for shift in [-1, 0, 1]:
            row = row0+shift
            col = np.rint(x/dx-(row % 2)*.5).astype(int)
            px = x-(col+(row % 2)*.5)*dx
            py = y-row*dy
            d = dx*.5-np.maximum(np.abs(px), np.abs(px)*.5+np.abs(py)*np.sqrt(3)/2)
            choose = d > distance
            distance = np.maximum(distance, d)
            cell_x = np.where(choose, col % 12, cell_x)
            cell_y = np.where(choose, row % 12, cell_y)
        gap, bevel, relief = .00065, .00055, .0009
    else:
        dx, dy = .1524, .0762
        cell_y = np.floor(y/dy).astype(int)
        shifted = x+(cell_y % 2)*dx*.5
        cell_x = np.floor(shifted/dx).astype(int) % 4
        px, py = shifted % dx, y % dy
        distance = np.minimum(np.minimum(px, dx-px), np.minimum(py, dy-py))
        gap, bevel, relief = .0009, .0009, .0012
    face = smooth(gap, gap+bevel, distance)
    # Low-amplitude, periodic tile-to-tile kiln variation; never dirt islands.
    rng = np.random.default_rng(19281012 + int(floor))
    colours = rng.uniform(-.006, .006, (12, 12))
    tone = colours[cell_y, cell_x]
    source = np.asarray(Image.open(SOURCE).convert('RGB').resize((SIZE, SIZE)), dtype=float)/255
    pigment = source-source.mean((0, 1))
    # Matched opposite edges for the microscopic pigment ingredient. Grout
    # layout is analytic and is never crossfaded or stochastically blended.
    window = np.sin(np.pi*(xx+.5)/SIZE)**2*np.sin(np.pi*(yy+.5)/SIZE)**2
    pigment = np.clip(pigment, -.04, .04)*window[..., None]*.10
    ivory = np.array([.919, .907, .875]) if floor else np.array([.940, .931, .904])
    grout = np.array([.64, .625, .59])
    albedo = grout+(ivory+pigment+tone[..., None]-grout)*face[..., None]
    # Glaze variation changes gloss, not the grout's geometry or height.
    rough = .76*(1-face)+(.35 if floor else .245)*face + tone*.5*face
    height = face
    nx = -(np.roll(height, -1, 1)-np.roll(height, 1, 1))*relief*SIZE*.5/WIDTH
    ny = (np.roll(height, -1, 0)-np.roll(height, 1, 0))*relief*SIZE*.5/height_m
    normal = np.stack([nx, ny, np.ones_like(nx)], -1)
    normal /= np.linalg.norm(normal, axis=-1)[..., None]
    maps = {'albedo':albedo, 'roughness':rough, 'height':height, 'normal':normal*.5+.5}
    out = ROOT/'art/textures/procedural'/key
    out.mkdir(parents=True, exist_ok=True)
    for name, values in maps.items():
        Image.fromarray(np.rint(np.clip(values, 0, 1)*255).astype(np.uint8)).save(out/(name+'.png'))
    meta = {'material':key, 'generator':'art/tools/build_bathroom_tiles.py',
            'source':SOURCE.relative_to(ROOT).as_posix(), 'meters_per_tile':WIDTH,
            'relief_mm':relief*1000, 'maps':{k:k+'.png' for k in maps}}
    meta['map_sha256'] = {k:hashlib.sha256((out/(k+'.png')).read_bytes()).hexdigest() for k in maps}
    (out/'material.json').write_text(json.dumps(meta, indent=2)+'\n', newline='\n')
    for name, suffix in [('albedo','albedo'), ('roughness','rough'), ('normal','normal')]:
        shutil.copyfile(out/(name+'.png'), ROOT/'game/assets/building/textures'/('T_ai_materials_'+key+'_'+suffix+'.png'))
    print(key, '1024px; registered joints; relief mm', relief*1000)


if __name__ == '__main__':
    for material in ['bath_wall_tile', 'bath_floor_tile']:
        build(material)
