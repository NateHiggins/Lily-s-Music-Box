"""Exact consumed-layout guard for the registered native city-shell library."""
import copy
import math
import re


def city_group(identity):
    return '_'.join(identity.split('_')[:3]) if identity.startswith(('site_nbr_', 'site_back_', 'site_far_')) else '_'.join(identity.split('_')[:2])


def v2_layout(layout, plan):
    """Project explicit V2 height landmarks without editing the frozen V1 source.

    Roof equipment above the final roof translates rigidly. Only masonry bands
    below it change height; footprints, radii, identities and source data survive.
    Strict monotone landmarks also keep every original support contact aligned.
    """
    result = copy.deepcopy(layout)
    rows = next(f for f in result['floors'] if f['id'] == 'F01')['furniture']
    for profile in plan['buildings']:
        if 'vertical_profile' not in profile:
            continue
        identity = profile['id']
        members = [r for r in rows if city_group(r['id']) == identity]
        assert members, identity
        shafts = sorted([r for r in members if re.search(r'_s\d+$', r['id'])], key=lambda r: r['z0'])
        base = next(r for r in members if r['id'] == identity + '_base0')
        old = [0., base['z0'] + base['h'], shafts[0]['z0'], shafts[-1]['z0'], shafts[-1]['z0'] + shafts[-1]['h']]
        new = profile['vertical_profile']
        assert len(new) == len(old) and new[0] == old[0] == 0., identity
        assert all(math.isfinite(v) for v in new), identity
        assert all(b > a for values in [old, new] for a, b in zip(values, values[1:])), identity

        def height(z):
            if z >= old[-1]:
                return z + new[-1] - old[-1]
            if z <= 0:
                return z
            for a, b, c, d in zip(old, old[1:], new, new[1:]):
                if z <= b:
                    return c + (z-a) * (d-c) / (b-a)
            raise AssertionError((identity, z))

        for row in members:
            if 'rect' in row:
                bottom = float(row.get('z0', 0))
                row['z0'], row['h'] = height(bottom), height(bottom+row['h'])-height(bottom)
            if row.get('asm') == 'pipe':
                for field in ['p0', 'p1']:
                    row[field][2] = height(row[field][2])
    return result

def shell_projection(layout):
    floor=next(row for row in layout['floors'] if row['id']=='F01')
    rows=[]
    for row in floor['furniture']:
        identity=row['id']
        selected=identity.startswith(('site_nbr_','site_back_','site_far_')) or re.match(r'^site_(?:nw|ne|sw|se)\d+_',identity)
        if selected and 'rect' in row and not identity.endswith('_beacon'):
            rows.append({'id':identity,'rect':row['rect'],'z0':float(row.get('z0',0)),'h':row['h'],'mat':row['mat']})
    assert len(rows)==335 and len({row['id'] for row in rows})==335
    return sorted(rows,key=lambda row:row['id'])

def check_registered_layout(layout,projection,registration,plan=None):
    assert projection['layout_sha256']==registration['bindings']['art/data/building_layout.json']
    assert projection['native_sha256']==registration['source_native_sha256']
    expected = projection.get('source_records', projection['records'])
    assert shell_projection(layout)==expected, 'Registered city physical source changed; rebuild its native library before closure'
    if 'source_records' in projection:
        assert plan is not None, 'V2 city projection requires its authoring plan'
        assert shell_projection(v2_layout(layout, plan)) == projection['records'], 'V2 height program changed; rebuild native city stock'
