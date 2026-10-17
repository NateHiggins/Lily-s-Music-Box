"""Project the restored-front lighting plan without changing existing room owners."""
import argparse
import copy
import hashlib
import json
import re
import struct
from pathlib import Path
from build_v2_roof import render, upsert_records

ROOT=Path(__file__).resolve().parents[1]


def supply_from_export(asset, report):
    """Bind exported placeholder stock to catalogue finishes and imported names."""
    if hashlib.sha256(asset).hexdigest()!=report['asset_sha256']:
        raise ValueError('Export report does not describe the supplied GLB')
    size=struct.unpack_from('<I',asset,12)[0]
    document=json.loads(asset[20:20+size])
    nodes={node['name']:node for node in document['nodes'] if 'mesh' in node}
    hangers=[]
    for row in report['hanger_placements']:
        matches=[name for name in nodes if name==row['node'] or
                 re.fullmatch(re.escape(row['node'])+r'\.\d+',name)]
        if len(matches)!=1:raise ValueError('Ambiguous exported support '+row['node'])
        hangers.append(dict(row,node=matches[0].replace('.','_')))
    materials=[]
    for mesh in document['meshes']:
        key=next((key for key in ['iron_neutral','brass_dull','galvanized_roof']
                  if mesh['name'].endswith('_'+key)),None)
        if key is None:raise ValueError('Unknown exported finish '+mesh['name'])
        materials.append(dict(mesh='front_lighting_supply_'+mesh['name'],catalog_key=key))
    return dict(schema_version=1,asset='res://assets/props/front_lighting_supply.glb',
                asset_sha256=report['asset_sha256'],material_tile=.65,
                hangers=hangers,materials=materials,
                superseded_covers=[f'F{i:02}_ELECTRICAL_JUNCTION' for i in range(1,7)])


def source_from_plan(plan, layout):
    rooms={s['id'] for s in layout['spaces']}
    anchors=[]
    for kind,rows in [('fixture',plan['fixtures']),('interaction',plan['switches'])]:
        for row in rows:
            if row['room'] not in rooms:raise ValueError('Missing room '+row['room'])
            anchors.append(dict(id=row['id'],level=row['level'],space=row['room'],
                position=row['position'],yaw=row['yaw'],kind=kind))
    lighting=dict(fixtures=[{k:copy.deepcopy(row[k]) for k in ['id','room','kind','properties']} for row in plan['fixtures']],
                  switches=[{k:row[k] for k in ['id','room']} for row in plan['switches']])
    wall=float(layout['dimensions']['partition_wall'])
    ports=[]
    for i,row in enumerate(plan['wall_ports']):
        axis=0 if row['side'] in ['west','east'] else 2
        # The shell subtracts an opening through its exact wall thickness.
        # Overshoot belongs in a Boolean cutter, not an owned opening record.
        half=[row['half_width']]*3;half[axis]=wall/2
        bounds=[row['center'][j]-half[j] for j in range(3)]+[row['center'][j]+half[j] for j in range(3)]
        ports.append(dict(id=row['space']+'_FRONT_LIGHT_PORT_'+str(i),space=row['space'],side=row['side'],bounds=bounds))
    return dict(schema_version=1,records=dict(anchors=anchors,wall_service_openings=ports),lighting=lighting)


def project(layout,lighting,source):
    result=copy.deepcopy(layout);lights=copy.deepcopy(lighting)
    for key,rows in source['records'].items():result[key]=upsert_records(result.get(key,[]),rows)
    for key,rows in source['lighting'].items():lights[key]=upsert_records(lights[key],rows)
    return result,lights


def save(path,data):path.write_text(json.dumps(data,indent=2)+'\n',encoding='utf-8',newline='\n')


def render_layout(original,result):
    ending='\r\n' if '\r\n' in original else '\n'
    return render(original.replace('\r\n','\n'),result).replace('\n',ending)


def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--apply',action='store_true');parser.add_argument('--out',type=Path,required=True)
    args=parser.parse_args()
    layout_path=ROOT/'game/data/orison_v2_blockout.json';light_path=ROOT/'game/data/orison_v2/room_lighting.json'
    raw=layout_path.read_bytes().decode('utf-8');layout=json.loads(raw);lighting=json.loads(light_path.read_text())
    source=source_from_plan(json.loads((ROOT/'art/data/front_lighting_plan.json').read_text()),layout)
    args.out.parent.mkdir(parents=True,exist_ok=True);save(args.out,source)
    new_layout,new_lights=project(layout,lighting,source)
    if args.apply:
        layout_path.write_bytes(render_layout(raw,new_layout).encode('utf-8'));save(light_path,new_lights)
        save(ROOT/'art/data/orison_v2/front_lighting_source.json',source)
        save(ROOT/'game/data/orison_v2/front_lighting_supply.json',supply_from_export(
            (ROOT/'game/assets/props/front_lighting_supply.glb').read_bytes(),
            json.loads((ROOT/'art/data/orison_v2/front_lighting_supply_export.json').read_text())))
    print(dict(applied=args.apply,anchors=len(source['records']['anchors']),ports=len(source['records']['wall_service_openings']),
               fixtures=len(source['lighting']['fixtures']),switches=len(source['lighting']['switches'])))


if __name__=='__main__':main()
