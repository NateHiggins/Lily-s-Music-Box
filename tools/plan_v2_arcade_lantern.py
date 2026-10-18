"""Fit closed folded roof stock to the three existing arcade lantern tiers.

Offline construction plan only. Original glass, posts, mast and clock remain
owned by the source scene. The existing top light gets a real stepped well.
"""
from pathlib import Path
import hashlib
import json

ROOT = Path(__file__).resolve().parents[1]


def build(layout=None):
    source = ROOT / 'art/data/building_layout.json'
    layout = layout or json.loads(source.read_text(encoding='utf8'))
    rows = {r['id']: r for floor in layout['floors'] if floor['id'] == 'F01'
            for r in floor['furniture']}
    caps = [rows['site_passage_lantern_cap_' + str(i)] for i in range(3)]
    light = rows['site_passage_lantern_cap_light']

    def bounds(row):
        a, b, c, d = row['rect']
        return [a, row['z0'], -d], [c, row['z0'] + row['h'], -b]

    tiers = [bounds(r) for r in caps]
    glow_low, glow_high = bounds(light)
    for i, (low, high) in enumerate(tiers):
        if caps[i]['mat'] != 'cast_iron' or abs(high[1] - low[1] - .16) > 1e-7:
            raise ValueError('Lantern roof source changed')
        if i and (abs(low[1] - tiers[i-1][1][1]) > 1e-7 or
                  not all(tiers[i-1][0][k] < low[k] < high[k] < tiers[i-1][1][k] for k in [0, 2])):
            raise ValueError('Lantern tiers no longer nest or bear on each other')
    if light['mat'] != 'milk_glass' or abs(glow_low[1] - tiers[-1][1][1]) > 1e-7:
        raise ValueError('Retained top light no longer seats on roof')
    parts = []

    def box(name, low, high, key='iron_blackened', bevel=.0005):
        if any(b <= a for a, b in zip(low, high)):
            raise ValueError('Empty roof stock: ' + name)
        parts.append(dict(id=name, low=low, high=high, catalog_key=key,
                          bevel_m=min(bevel, min(b-a for a, b in zip(low, high)) / 4)))

    def ring(name, outside, inside, bottom, top, key='iron_blackened'):
        x0, z0, x1, z1 = outside
        a, b, c, d = inside
        if not (x0 < a < c < x1 and z0 < b < d < z1):
            raise ValueError('Roof well is outside its stock')
        # Four closed mitre-free strips, with no coplanar duplicate faces.
        for n, (lo, hi) in enumerate([
            ([x0,bottom,z0],[x1,top,b]), ([x0,bottom,d],[x1,top,z1]),
            ([x0,bottom,b],[a,top,d]), ([c,bottom,b],[x1,top,d])]):
            box(name+'_'+str(n),lo,hi,key)

    wells = []
    for i, (low, high) in enumerate(tiers):
        outer = [low[0], low[2], high[0], high[2]]
        if i < 2:
            nlow, nhigh = tiers[i+1]
            inner = [nlow[0]+.025,nlow[2]+.025,nhigh[0]-.025,nhigh[2]-.025]
        else:
            inner = [glow_low[0]+.02,glow_low[2]+.02,glow_high[0]-.02,glow_high[2]-.02]
        wells.append(inner)
        # A thin weather skin, folded outer return and load-bearing well frame
        # replace a solid 160 mm plate. Each tier remains inside its old bounds.
        ring(f'tier_{i}_skin',outer,inner,high[1]-.022,high[1]-.020)
        return_inner = [outer[0]+.003,outer[1]+.003,outer[2]-.003,outer[3]-.003]
        ring(f'tier_{i}_outer_return',outer,return_inner,low[1],high[1]-.020)
        well_outer = [inner[0]-.025,inner[1]-.025,inner[2]+.025,inner[3]+.025]
        ring(f'tier_{i}_well_frame',well_outer,inner,low[1],high[1])
        # Narrow standing seams lie on the weather side, never across the well.
        for side, (a, c) in enumerate([(outer[0],inner[0]),(inner[2],outer[2])]):
            z = outer[1]+.60
            n = 0
            while z < outer[3]-.10:
                box(f'tier_{i}_seam_{side}_{n}',[a,high[1]-.020,z-.004],
                    [c,high[1],z+.004])
                z += .60
                n += 1
        for side,(b,d) in enumerate([(outer[1],inner[1]),(inner[3],outer[3])]):
            x=outer[0]+.60
            n=0
            while x<outer[2]-.10:
                box(f'tier_{i}_end_seam_{side}_{n}',[x-.004,high[1]-.020,b],
                    [x+.004,high[1],d])
                x+=.60
                n+=1
    # The folded skin alone is above the retained corner posts. A closed
    # perimeter channel supplies an actual seat at each source post top;
    # the drip return is a weather edge, not a structural bearing.
    low,high=tiers[0]
    posts=[row for identity,row in rows.items() if identity.startswith('site_lantern_post_')]
    if len(posts)!=4:raise ValueError('Expected four retained lantern corner posts')
    bearings=[]
    for post in posts:
        p=max([post['p0'],post['p1']],key=lambda p:p[2])
        if abs(p[2]-(low[1]+.02))>1e-7 or abs(post['r']-.045)>1e-7:
            raise ValueError('Retained lantern post bearing changed')
        bearings.append(dict(id=post['id'],at=[p[0],p[2],-p[1]],radius=post['r']))
    channel_outer=[low[0]+.04,low[2]+.04,high[0]-.04,high[2]-.04]
    channel_inner=[low[0]+.22,low[2]+.22,high[0]-.22,high[2]-.22]
    web_inner=[channel_outer[0]+.012,channel_outer[1]+.012,channel_outer[2]-.012,channel_outer[3]-.012]
    seat=low[1]+.02
    ring('base_channel_lower_flange',channel_outer,channel_inner,seat,seat+.012)
    ring('base_channel_web',channel_outer,web_inner,seat+.012,high[1]-.034)
    ring('base_channel_upper_flange',channel_outer,channel_inner,high[1]-.034,high[1]-.022)
    # Preserve the clock's exact hanger endpoint. A cross-tie seats on the
    # first tier frame and a closed collar reaches the retained stem at 10.90.
    stem = rows['site_crossing_clock_stem']
    endpoint = max([stem['p0'],stem['p1']],key=lambda p:p[2])
    cx, cz, top = endpoint[0], -endpoint[1], endpoint[2]
    low, high = tiers[0]
    if (stem['p0'][:2] != stem['p1'][:2] or stem['r'] > .04 or
            not low[0]+.05 < cx < high[0]-.05 or
            not low[2]+.05 < cz < high[2]-.05 or not 0 < low[1]-top < .15):
        raise ValueError('Retained clock hanger no longer fits the closed collar')
    box('clock_cross_tie',[low[0],low[1],cz-.04],[high[0],low[1]+.06,cz+.04])
    box('clock_hanger_collar',[cx-.045,top,cz-.045],[cx+.045,low[1],cz+.045])
    retired = [dict(id=r['id'],key=r['mat'],low=lo,high=hi,expected_triangles=12)
               for r,(lo,hi) in zip(caps,tiers)]
    return dict(evidence_class='INERT',source='art/data/building_layout.json',
                source_sha256_lf=hashlib.sha256(source.read_bytes().replace(b'\r\n',b'\n')).hexdigest(),
                retire=retired,parts=parts,wells=wells,
                post_bearings=bearings,
                retained_light=light['id'],retained_clock_stem=stem['id'],
                hanger_bearing=[cx,top,cz],
                scope='Offline native candidate; no runtime or appearance acceptance.')


if __name__ == '__main__':
    import argparse
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--out',type=Path,required=True)
    args=parser.parse_args()
    args.out.parent.mkdir(parents=True,exist_ok=True)
    data=build()
    args.out.write_text(json.dumps(data,indent=2)+'\n',encoding='utf8',newline='\n')
    print(len(data['parts']),'closed roof stocks;',len(data['retire']),'source slabs')
