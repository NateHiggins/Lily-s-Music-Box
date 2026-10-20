"""Repeatable binding stock, with construction relief independent of pigment.

Candidate output stays under tmp until native and engine review. The palette
retains the six book identities; it contains no cover layout or lettering.
"""
from pathlib import Path
import argparse
import hashlib
import json
import numpy as np
from PIL import Image
from material_relief import relief, normals, smooth_height

ROOT = Path(__file__).resolve().parents[2]
TILE = .32
PALETTE = {
    'book_burgundy': ('leather', [.29, .068, .065]),
    'book_brown': ('leather', [.25, .135, .065]),
    'book_green': ('cloth', [.10, .205, .13]),
    'book_navy': ('cloth', [.075, .115, .205]),
    'book_ochre': ('cloth', [.49, .29, .075]),
    'book_teal': ('cloth', [.10, .255, .245]),
}


def leather(size=2048, tile=TILE, seed=19281021):
    """Shallow pebbled grain: periodic cellular valleys, never albedo height."""
    if not isinstance(size, int) or isinstance(size, bool) or size < 4:
        raise ValueError('Integer resolution >=4 required')
    if not np.isfinite(tile) or tile <= 0:
        raise ValueError('Positive finite metre scale required')
    spacing, width, depth = .0032, .00065, .000022
    periods = max(1, round(tile/spacing))
    actual_spacing = tile/periods
    description = dict(structure='shallow leather grain valleys',
                       cell_spacing_m=actual_spacing, valley_width_m=width,
                       valley_depth_m=depth)
    height = np.zeros((size, size), dtype=np.float64)
    resolved = size/periods >= 8 and width*size/tile >= 4
    if resolved:
        rng = np.random.default_rng(seed)
        centres = rng.uniform(.18, .82, (periods, periods, 2)).astype(np.float32)
        y, x = np.mgrid[:size, :size].astype(np.float32)*periods/size
        ix, iy = np.floor(x).astype(int), np.floor(y).astype(int)
        near = np.full_like(x, np.inf)
        second = near.copy()
        for dy in (-1, 0, 1):
            for dx in (-1, 0, 1):
                c = centres[(iy+dy) % periods, (ix+dx) % periods]
                distance = (x-(ix+dx+c[..., 0]))**2+(y-(iy+dy+c[..., 1]))**2
                second = np.minimum(second, np.maximum(near, distance))
                near = np.minimum(near, distance)
        gap = (np.sqrt(second)-np.sqrt(near))*actual_spacing
        height = -depth*np.exp(-(gap/width)**2)
        height = smooth_height(height, .65)
        height -= height.mean()
    normal = normals(height, tile)
    metadata = dict(profile='binding_leather', generator='art/tools/build_binding_stock.py',
                    height_units='metres', normal_convention='OpenGL', normal_strength=1.,
                    meters_per_tile=tile, resolution=size, seed=seed,
                    height_source='authored construction; independent of albedo and baked illumination',
                    bands=[description] if resolved else [],
                    unresolved_for_roughness=[] if resolved else [description],
                    rms_relief_m=float(height.std()),
                    maximum_slope=float((np.linalg.norm(normal[..., :2], axis=-1)/normal[..., 2]).max()))
    return height, normal, metadata


def build(destination):
    destination = destination.resolve()
    if not destination.is_relative_to(ROOT/'tmp'):
        raise ValueError('Candidates must remain below repository tmp')
    source_paths = [Path(__file__), ROOT/'art/tools/material_relief.py']
    source_bindings = {p.relative_to(ROOT).as_posix(): hashlib.sha256(
        p.read_bytes().replace(b'\r\n', b'\n')).hexdigest() for p in source_paths}
    for substance in ('cloth', 'leather'):
        if substance == 'cloth':
            height, normal, authoring = relief('cloth', 2048, TILE, 19281021)
            rough_base, rough_range = .56, .055
        else:
            height, normal, authoring = leather()
            rough_base, rough_range = .40, .07
        # Roughness retains unresolved fibre/pores as a broader lobe, not an
        # invented large bump. Valleys stay rougher than the worked high points.
        low = smooth_height(height, 3.)
        low /= max(float(low.std()), 1e-12)
        roughness = np.clip(rough_base-np.tanh(low)*rough_range, .15, .85)
        for key, (kind, color) in PALETTE.items():
            if kind != substance:
                continue
            out = destination/key
            out.mkdir(parents=True, exist_ok=True)
            # Pigment variation is deliberately low frequency, seamless and
            # independent of the normal. No ornamental atlas is repeated.
            rng = np.random.default_rng(19281021)
            pigment = smooth_height(rng.standard_normal((512, 512)), 12.)
            pigment /= max(float(pigment.std()), 1e-12)
            albedo = np.clip(np.asarray(color)[None, None, :]*(1+.012*np.tanh(pigment[..., None])), 0, 1)
            values = dict(albedo=albedo, roughness=roughness, normal=normal*.5+.5)
            for channel, value in values.items():
                Image.fromarray(np.uint8(np.rint(value*255))).save(out/(channel+'.png'))
            data = dict(material=key, generator='art/tools/build_binding_stock.py',
                        meters_per_tile=TILE, normal_convention='OpenGL', normal_strength=1.,
                        normal_authoring=authoring, metallic=0.,
                        roughness_range=[float(roughness.min()), float(roughness.max())],
                        subpixel_finish='Coating and fine fibre/pores contribute to the roughness lobe; no oversized pore noise.',
                        maps={channel: channel+'.png' for channel in values},
                        status='CANDIDATE_NOT_INSTALLED', source_bindings=source_bindings)
            data['map_sha256'] = {c: hashlib.sha256((out/(c+'.png')).read_bytes()).hexdigest() for c in values}
            (out/'material.json').write_text(json.dumps(data, indent=2)+'\n', encoding='utf8', newline='\n')
            print(key, substance, 'RMS micrometres', round(authoring['rms_relief_m']*1e6, 2))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--out', type=Path, required=True)
    build(parser.parse_args().out)
