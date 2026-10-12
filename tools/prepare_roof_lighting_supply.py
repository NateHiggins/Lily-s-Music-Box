"""Author the two roof lighting wall entries in their existing construction owner."""
import json
from pathlib import Path
from build_v2_roof import project, render
ROOT=Path(__file__).resolve().parents[1]
source_path=ROOT/'art/data/orison_v2/roof_source.json'
source=json.loads(source_path.read_text(encoding='utf-8'))
walls=[];masonry=[]
for room,side,x in [('ROOF_PUBLIC_CORE','east',5.4),('ROOF_SERVICE_CORE','west',9.5)]:
    stem=room+'_LIGHT_SUPPLY'
    walls.append({'id':stem+'_WALL_PORT','space':room,'side':side,
                  'bounds':[x-.07,21.86,.96,x+.07,21.94,1.04]})
# The roof bulkheads have retained partition stock, not ExteriorMasonry.
# Do not fabricate service openings in an owner with no roof leaf.
for table,rows in [('wall_service_openings',walls),('masonry_service_openings',masonry)]:
    ids={r['id'] for r in rows}
    if table=='masonry_service_openings':ids={'ROOF_PUBLIC_CORE_LIGHT_SUPPLY_MASONRY_PORT','ROOF_SERVICE_CORE_LIGHT_SUPPLY_MASONRY_PORT'}
    source['records'][table]=[r for r in source['records'].get(table,[]) if r['id'] not in ids]+rows
source_path.write_text(json.dumps(source,indent=2)+'\n',encoding='utf-8',newline='\n')
p=ROOT/'game/data/orison_v2_blockout.json';old=p.read_text(encoding='utf-8')
layout=json.loads(old)
layout['masonry_service_openings']=[r for r in layout.get('masonry_service_openings',[]) if r['id'] not in {'ROOF_PUBLIC_CORE_LIGHT_SUPPLY_MASONRY_PORT','ROOF_SERVICE_CORE_LIGHT_SUPPLY_MASONRY_PORT'}]
p.write_text(render(old,project(layout,source)),encoding='utf-8',newline='\n')
print('Two bounded source-owned bulkhead wall ports')
