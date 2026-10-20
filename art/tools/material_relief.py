"""Material-specific, periodic relief in metres; never derive height from lighting.

Resolved relief becomes an OpenGL tangent normal. Features below four texels
are recorded for roughness treatment instead of being aliased into that normal.
Large seams, bores, chips at silhouettes and glass bevels remain geometry.
"""
import numpy as np


PROFILES = {
    # (construction, wavelength metres, RMS height metres, across-U/V stretch)
    'fired_enamel': [('orange peel', .0007, .000012, 1., 1.),
                     ('flow', .006, .000004, 1., 1.)],
    'cast_metal': [('mould sand', .001, .000030, 1., 1.),
                   ('casting skin', .006, .000012, 1., 1.)],
    'worked_metal': [('draw marks', .0007, .0000018, .12, 1.),
                     ('rolling', .004, .000002, .2, 1.)],
    'cloth': [('fibres', .0007, .000008, 1., .15),
              ('thread unevenness', .004, .000012, .2, 1.)],
    'timber': [('pores', .001, .000010, .15, 1.),
               ('grain', .005, .000035, .08, 1.)],
    'plaster': [('mineral grains', .001, .000022, 1., 1.),
                ('trowel drag', .020, .00009, .18, 1.)],
    'porcelain': [('glaze flow', .005, .0000015, 1., 1.)],
    'paper': [('fibres', .0007, .000003, 1., .25)],
    'glass_drawn': [('draw undulation', .032, .00016, .2, 1.),
                    ('fine draw lines', .001, .000001, .12, 1.)],
    'glass_reeded': [('casting variation', .016, .000015, 1., 1.)],
    'glass_cut': [('working variation', .020, .000008, 1., 1.)],
    'glass_frosted': [('etched grains', .0007, .000006, 1., 1.),
                      ('uneven etch', .008, .000003, 1., 1.)],
}


def smooth_height(height_m, sigma_texels):
    """Periodic float filtering: image filters quantize micrometre heights away."""
    height_m = np.asarray(height_m, dtype=np.float64)
    if (height_m.ndim != 2 or not np.isfinite(height_m).all()
            or not np.isfinite(sigma_texels) or sigma_texels < 0):
        raise ValueError('Finite height and nonnegative smoothing width required')
    fx, fy = np.meshgrid(np.fft.fftfreq(height_m.shape[1]),
                         np.fft.fftfreq(height_m.shape[0]))
    transfer = np.exp(-2*np.pi**2*sigma_texels**2*(fx*fx+fy*fy))
    return np.fft.ifft2(np.fft.fft2(height_m)*transfer).real


def normals(height_m, tile_m):
    """Differentiate physical height, with wrapped charts and image-Y convention."""
    height_m = np.asarray(height_m, dtype=np.float64)
    if (height_m.ndim != 2 or min(height_m.shape, default=0) < 2
            or not np.isfinite(height_m).all() or not np.isfinite(tile_m) or tile_m <= 0):
        raise ValueError('Finite physical height and positive tile scale required')
    dy = (np.roll(height_m, -1, 0)-np.roll(height_m, 1, 0))*height_m.shape[0]/(2*tile_m)
    dx = (np.roll(height_m, -1, 1)-np.roll(height_m, 1, 1))*height_m.shape[1]/(2*tile_m)
    result = np.stack((-dx, dy, np.ones_like(dx)), axis=-1)
    result /= np.linalg.norm(result, axis=-1)[..., None]
    return result


def relief(profile, size=1024, tile_m=.128, seed=19281020):
    if profile not in PROFILES:
        raise ValueError('Choose a material construction profile or author a bespoke recipe')
    if (not isinstance(size, int) or isinstance(size, bool) or size < 4
            or not np.isfinite(tile_m) or tile_m <= 0):
        raise ValueError('Resolution must be an integer >=4 and tile scale finite and positive')
    rng = np.random.default_rng(seed)
    fx, fy = np.meshgrid(np.fft.fftfreq(size, d=tile_m/size),
                         np.fft.fftfreq(size, d=tile_m/size))
    height = np.zeros((size, size)); bands = []; unresolved = []
    for name, wavelength, rms, u, v in PROFILES[profile]:
        description = dict(structure=name, wavelength_m=wavelength, rms_height_m=rms,
                           frequency_stretch_uv=[u, v])
        if wavelength < 4*tile_m/size:
            unresolved.append(description); continue
        radius = np.hypot(fx/u, fy/v)
        centre = 1/wavelength
        spectrum = np.exp(-.5*((radius-centre)/(centre*.38))**2)
        spectrum[0, 0] = 0.
        field = np.fft.ifft2(np.fft.fft2(rng.standard_normal((size, size)))*spectrum).real
        if field.std() < 1e-12:
            raise ValueError('Profile cannot be represented at this physical tile scale')
        height += (field-field.mean())/field.std()*rms
        bands.append(description)
    y, x = np.mgrid[:size, :size]/size
    if profile == 'glass_reeded':
        # Ten-millimetre-ish rolled flutes; integer periods retain a real seam.
        periods = max(1, round(tile_m/.0128))
        description=dict(structure='rolled flutes', wavelength_m=tile_m/periods,
                         peak_height_m=.00065)
        if size/periods >= 4:
            height += .00065*np.cos(2*np.pi*periods*x);bands.append(description)
        else:unresolved.append(description)
    elif profile == 'glass_cut':
        periods = max(1, round(tile_m/.032))
        triangle = lambda a: 1-4*np.abs(np.mod(a, 1)-.5)
        description=dict(structure='cross-cut diamond facets', cell_m=tile_m/periods,
                         peak_height_m=.00076)
        if size/(periods*np.sqrt(2)) >= 4:
            height += .00038*(triangle((x+y)*periods)+triangle((x-y)*periods));bands.append(description)
        else:unresolved.append(description)
    elif profile == 'cloth':
        periods = max(1, round(tile_m/.001))
        description=dict(structure='crossed weave', spacing_m=tile_m/periods,
                         peak_height_m=.000036)
        if size/periods >= 4:
            height += .000018*(np.cos(2*np.pi*x*periods)+np.cos(2*np.pi*y*periods));bands.append(description)
        else:unresolved.append(description)
    normal = normals(height, tile_m)
    slopes = np.linalg.norm(normal[..., :2], axis=-1)/normal[..., 2]
    metadata = dict(profile=profile, generator='art/tools/material_relief.py',
                    height_units='metres', normal_convention='OpenGL', normal_strength=1.,
                    meters_per_tile=tile_m, resolution=size, seed=seed,
                    height_source='authored construction; independent of albedo and baked illumination',
                    bands=bands, unresolved_for_roughness=unresolved,
                    rms_relief_m=float(height.std()), maximum_slope=float(slopes.max()))
    return height, normal, metadata
