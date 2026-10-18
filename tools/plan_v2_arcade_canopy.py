"""Source-fitted arcade barrel-glazing candidate; no runtime publication.

The retained ribs define sixteen straight chord surfaces. A six millimetre
glass shell sits above their actual 45 mm radius, under seated metal caps.
The crossing lantern, original rib actors and all lights remain source-owned.
"""
from pathlib import Path
import hashlib
import json
import math

ROOT = Path(__file__).resolve().parents[1]


def build():
    layout_path = ROOT / 'art/data/building_layout.json'
    layout = json.loads(layout_path.read_text(encoding='utf8'))
    furniture = [row for floor in layout['floors'] if floor['id'] == 'F01' for row in floor['furniture']]
    rows = [row for row in furniture if row['id'].startswith('site_passage_vault_glass_')]
    if len(rows) != 20:
        raise ValueError('Source roof changed; review retirement boundaries')
    retired = []
    gables = ['n_1', 'n_2', 'n_3', 's_head', 's_stepa', 's_stepb', 's_crown1', 's_crown2']
    upper_gables = [row for row in furniture if row['id'] in ['site_passage_nave_gable_' + suffix for suffix in gables]]
    if len(upper_gables) != len(gables) or any(row['mat'] != 'plaster' for row in upper_gables):
        raise ValueError('Source gable changed; review retirement boundaries')
    diaphragms = [row for row in furniture if row['id'].startswith('site_passage_lantern_diaphragm_')]
    if len(diaphragms) != 6 or any(row['mat'] != 'glassish' for row in diaphragms):
        raise ValueError('Source lantern changed; review retirement boundaries')
    for row in rows + upper_gables + diaphragms:
        r = row['rect']
        if row in rows and (row['mat'] != 'glassish' or abs(row['h'] - .035) > 1e-8):
            raise ValueError('Unexpected source roof stock: ' + row['id'])
        retired.append(dict(id=row['id'], key=row['mat'], low=[r[0], row['z0'], -r[3]],
                            high=[r[2], row['z0'] + row['h'], -r[1]], expected_triangles=12))
    # Use the retained physical ribs as the profile authority, not a second
    # approximation of the arch. All ten retained ribs must agree.
    ribs = [row for row in furniture if row['id'].startswith('site_passage_rib_')]
    if len(ribs) != 160:
        raise ValueError('Retained rib count changed')
    first = sorted([row for row in ribs if row['id'].startswith('site_passage_rib_00_')], key=lambda row: row['id'])
    points = [(row['p0'][0], row['p0'][2]) for row in first] + [(first[-1]['p1'][0], first[-1]['p1'][2])]
    for row in ribs:
        segment = int(row['id'].rsplit('_', 1)[1])
        if abs(row['r'] - .045) > 1e-9 or math.dist((row['p0'][0], row['p0'][2]), points[segment]) > 1e-9 or math.dist((row['p1'][0], row['p1'][2]), points[segment + 1]) > 1e-9:
            raise ValueError('Retained ribs disagree: ' + row['id'])
    parts = []

    def stock(identity, center, axes, size, material, bevel=0):
        parts.append(dict(id=identity, center_m=list(center), axes=[list(a) for a in axes],
                          size_m=list(size), material=material, bevel_m=bevel))

    facets = []
    pane_count = 0
    for i, (a, b) in enumerate(zip(points, points[1:])):
        length = math.dist(a, b)
        tangent = ((b[0] - a[0]) / length, (b[1] - a[1]) / length, 0)
        normal = (-tangent[1], tangent[0], 0)
        axial = (0, 0, 1)
        facets.append(dict(index=i, start=list(a), end=list(b), chord_m=length,
                           tangent=list(tangent), outward_normal=list(normal)))
        for zone, bounds in enumerate(([38.6, 39, 41, 43, 45, 47, 48.6],
                                        [54.6, 55, 57, 59, 61, 63, 64.6])):
            def at(u, z, height):
                return (a[0] + tangent[0] * u + normal[0] * height,
                        a[1] + tangent[1] * u + normal[1] * height, z)
            for bay, (lo, hi) in enumerate(zip(bounds, bounds[1:])):
                name = f'facet_{i:02}_{zone}_{bay}'
                # Axes must be right handed: tangent x -axial = normal.
                axes = (tangent, (0, 0, -1), normal)
                stock(name + '_pane', at(length / 2, (lo + hi) / 2, .049), axes,
                      (length - .008, hi - lo - .008, .006), 'glassish')
                pane_count += 1
                if i % 2 and hi - lo > .8:
                    # Diamond relief remains attached to the actual pane plane.
                    # It never bridges two planes or floats under a slab.
                    middle = (lo + hi) / 2
                    diamond = [(length * .22, middle), (length / 2, middle + .23),
                               (length * .78, middle), (length / 2, middle - .23)]
                    for j, (p, q) in enumerate(zip(diamond, diamond[1:] + diamond[:1])):
                        du, dz = q[0] - p[0], q[1] - p[1]
                        span = math.hypot(du, dz)
                        axis = tuple(tangent[k] * du / span + axial[k] * dz / span for k in range(3))
                        across = tuple(normal[(k + 1) % 3] * axis[(k + 2) % 3] - normal[(k + 2) % 3] * axis[(k + 1) % 3] for k in range(3))
                        stock(name + f'_diamond_{j}', at((p[0] + q[0]) / 2, (p[1] + q[1]) / 2, .055),
                              (axis, across, normal), (span, .014, .004), 'enamel_appliance', .0006)
            # Individual caps seat over the pane edges. Two adjacent facets
            # retain their own section instead of forcing a bent flat ribbon.
            for side, u in enumerate((0, length)):
                stock(f'facet_{i:02}_{zone}_long_cap_{side}', at(u, (bounds[0] + bounds[-1]) / 2, .060),
                      (tangent, (0, 0, -1), normal), (.026, bounds[-1] - bounds[0], .016), 'iron_blackened', .001)
            for bay, z in enumerate(bounds):
                stock(f'facet_{i:02}_{zone}_cross_cap_{bay}', at(length / 2, z, .060),
                      (tangent, (0, 0, -1), normal), (length, .028, .016), 'iron_blackened', .001)
    # The old stepped gables left open shoulders and protruded through the
    # barrel near the crown. Fit a proper arch to the glass's inner planes.
    # Offset-line intersections give seated mitres, rather than an arbitrary
    # vertical offset which would miss the steep side panes.
    lines = []
    for facet in facets:
        nx, ny, _ = facet['outward_normal']
        x, y = facet['start']
        lines.append((-nx / ny, y + nx * x / ny + .046 / ny))
    top = [(11., lines[0][0] * 11 + lines[0][1])]
    for a, b in zip(lines, lines[1:]):
        x = (b[1] - a[1]) / (a[0] - b[0])
        top.append((x, a[0] * x + a[1]))
    top.append((17., lines[-1][0] * 17 + lines[-1][1]))

    def roof_height(x):
        for a, b in zip(top, top[1:]):
            if a[0] - 1e-8 <= x <= b[0] + 1e-8:
                return a[1] + (b[1] - a[1]) * (x - a[0]) / (b[0] - a[0])
        raise ValueError('Outside roof profile')

    for name, lo, hi, bottom, z0, z1 in [
        ('north_arch', 11., 17., 7.2, 38.6, 38.84),
        ('south_arch_west', 11., 12.9, 7.2, 64.36, 64.6),
        ('south_arch_head', 12.9, 15.1, 8., 64.36, 64.6),
        ('south_arch_east', 15.1, 17., 7.2, 64.36, 64.6),
    ]:
        profile = [(lo, bottom), (hi, bottom), (hi, roof_height(hi))]
        profile += list(reversed([p for p in top if lo + 1e-8 < p[0] < hi - 1e-8]))
        profile.append((lo, roof_height(lo)))
        parts.append(dict(id=name, kind='gable_prism', profile_xy=profile, z_interval=[z0, z1],
                          material='plaster_stained', bevel_m=0,
                          axes=[[1., 0., 0.], [0., 1., 0.], [0., 0., 1.]]))
    # The lantern rises above the barrel. Its source diaphragms instead
    # crossed the nave below the arch and left the actual outside shoulders
    # open. New spandrels occupy only the volume ABOVE the roof profile.
    for end, z in enumerate((48.6, 54.6)):
        profile = list(top) + [(17., 10.), (11., 10.)]
        parts.append(dict(id=f'lantern_spandrel_{end}', kind='gable_prism',
                          profile_xy=profile, z_interval=[z - .003, z + .003],
                          material='glassish', bevel_m=0,
                          axes=[[1., 0., 0.], [0., 1., 0.], [0., 0., 1.]]))
        # Seated head rail lies within the retained lantern curb.
        stock(f'lantern_spandrel_head_{end}', (14, 9.98, z),
              ((1, 0, 0), (0, 0, -1), (0, 1, 0)), (6., .028, .03), 'iron_blackened', .001)
    for side, x in enumerate((11., 17.)):
        for bay, (lo, hi) in enumerate(zip([48.6, 50.6, 52.6], [50.6, 52.6, 54.6])):
            stock(f'lantern_side_{side}_{bay}', (x, 8.56, (lo + hi) / 2),
                  ((0, 1, 0), (0, 0, 1), (1, 0, 0)), (2.72, hi - lo - .008, .006), 'glassish')
        for post, z in enumerate((48.6, 50.6, 52.6, 54.6)):
            stock(f'lantern_side_post_{side}_{post}', (x, 8.56, z),
                  ((0, 1, 0), (0, 0, 1), (1, 0, 0)), (2.74, .028, .028), 'iron_blackened', .001)
        stock(f'lantern_side_sill_{side}', (x, 7.2, 51.6),
              ((1, 0, 0), (0, 0, -1), (0, 1, 0)), (.035, 6., .03), 'iron_blackened', .001)
    return dict(schema_version=1, evidence_class='INERT', status='NATIVE_CANDIDATE_NOT_INSTALLED',
                source=layout_path.relative_to(ROOT).as_posix(),
                source_sha256_lf=hashlib.sha256(layout_path.read_bytes().replace(b'\r\n', b'\n')).hexdigest(),
                coordinate_frame='Source cell Godot metres: x, height, -source_y; retained Passage offset applies at runtime.',
                rib_radius_m=.045, glass_thickness_m=.006, glass_inner_offset_m=.046,
                lantern_open_interval_z=[48.6, 54.6], pane_count=pane_count,
                lantern_closed_panes=8,
                facets=facets, gable_top_xy=top, retire=retired, parts=parts,
                pending=['Runtime surgical retirement and matched collision', 'Legacy ornament retirement',
                         'Loaded game UV/PBR/mipmap and weather review'])


if __name__ == '__main__':
    import argparse
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--out', type=Path, required=True)
    args = parser.parse_args()
    args.out.parent.mkdir(parents=True, exist_ok=True)
    data = build()
    args.out.write_text(json.dumps(data, indent=2) + '\n', encoding='utf8', newline='\n')
    print(len(data['parts']), 'stock pieces;', data['pane_count'], 'closed panes;', len(data['retire']), 'source boxes to retire')
