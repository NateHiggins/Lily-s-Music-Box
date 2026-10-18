"""Project floor-borne landing programmes without rebuilding their core stock."""
import argparse
import copy
import json
from pathlib import Path

from build_v2_roof import render, upsert_records
from derive_v2_public_landings import union

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT/'art/data/orison_v2/public_landings_source.json'
TARGET = ROOT/'game/data/orison_v2_blockout.json'


def project(layout, source):
    if source.get('schema_version') != 1 or set(source) != {'schema_version','programmes','platform_repairs'}:
        raise ValueError('Explicit public landing authoring schema required')
    layout=copy.deepcopy(layout)
    repairs=[]
    for repair in source['platform_repairs']:
        if set(repair)!={'id','level','rect','class','reason'} or repair['id']!='F01_PUBLIC_LANDING_E' or repair['level']!='F01' or repair['class']!='core' or not repair['reason'].strip():
            raise ValueError('Explicit bounded ground landing repair required')
        union([repair['rect']])
        primary=next(s for s in layout['stairs'] if s['id']=='PRIMARY_F01_F02')
        south=next(p for p in layout['platforms'] if p['id']=='F01_PUBLIC_LANDING_S')['rect']
        north=next(p for p in layout['platforms'] if p['id']=='F01_PUBLIC_LANDING_N')['rect']
        expected=[primary['origin'][0]+2*primary['width']+primary['gap'],south[3],min(south[2],north[2]),north[1]]
        if any(abs(a-b)>1e-9 for a,b in zip(repair['rect'],expected)):
            raise ValueError('Repair must butt the existing slab edges outside the real stair width')
        a=repair['rect']
        for shaft in layout['risers']:
            if shaft.get('solid') is not False:continue
            b=shaft['rect']
            if min(a[2],b[2])>max(a[0],b[0]) and min(a[3],b[3])>max(a[1],b[1]):
                raise ValueError('Landing repair cannot fill a shaft reservation')
        repairs.append({k:copy.deepcopy(repair[k]) for k in ['id','level','rect','class']})
    if len(repairs)!=1:
        raise ValueError('One ground landing repair required')
    layout['platforms']=upsert_records(layout['platforms'],repairs)
    records = source['programmes']
    if len(records) != 6 or {r['level'] for r in records} != {f'F{i:02d}' for i in range(1,7)}:
        raise ValueError('One authored public landing on every occupied floor required')
    spaces = {r['id']:r for r in layout['spaces']}
    anchors = {r['id']:r for r in layout['anchors']}
    additions = []
    for record in records:
        if set(record) != {'id','level','core','purpose','landmark_anchor'}:
            raise ValueError('Unknown or missing landing authoring field')
        floor = record['level']; core = spaces.get(record['core'],{})
        if record['id'] != floor+'_LANDING' or record['core'] != floor+'_PUBLIC_CORE' or core.get('class') != 'core' or core.get('level') != floor:
            raise ValueError('Landing requires its existing public core authority')
        anchor = anchors.get(record['landmark_anchor'],{})
        if anchor.get('level') != floor or anchor.get('space') != record['core'] or anchor.get('kind') != 'furniture':
            raise ValueError('Existing same-core physical landmark required')
        owners = [r for r in layout['platforms'] if r['id'].startswith(floor+'_PUBLIC_LANDING_')]
        if not owners or any(r.get('level') != floor for r in owners):
            raise ValueError('Existing same-floor landing platforms required')
        rects = [r['rect'] for r in owners]
        union(rects)  # Reject degenerate/nonfinite stock before projection.
        bounds = [min(r[0] for r in rects),min(r[1] for r in rects),max(r[2] for r in rects),max(r[3] for r in rects)]
        c = core['rect']
        if not (c[0] <= bounds[0] < bounds[2] <= c[2] and c[1] <= bounds[1] < bounds[3] <= c[3]) or not record['purpose'].strip():
            raise ValueError('Landing footprint must belong to its declared core')
        previous = copy.deepcopy(spaces.get(record['id'],{}))
        previous.update(id=record['id'],level=floor,**{'class':'public'},rect=bounds,
                        purpose=record['purpose'],open_shell=True,no_floor=True,no_ceiling=True,
                        landing_core=record['core'],floor_platforms=[r['id'] for r in owners],
                        programme_anchors=[record['landmark_anchor']])
        additions.append(previous)
    result = copy.deepcopy(layout)
    result['spaces'] = upsert_records(layout['spaces'],additions)
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check',action='store_true')
    args = parser.parse_args()
    original = TARGET.read_text(encoding='utf-8')
    before = json.loads(original)
    after = project(before,json.loads(SOURCE.read_text(encoding='utf-8')))
    if args.check:
        if after != before:
            raise SystemExit('Public landing projection is stale')
        print('Public landing programmes match their authored source and platform owners')
    else:
        # Preserve the installed schema's Windows newline convention. Digests use LF.
        TARGET.write_bytes(render(original,after).replace('\n','\r\n').encode('utf-8'))


if __name__ == '__main__':
    main()
