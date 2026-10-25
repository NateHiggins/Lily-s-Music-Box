"""Exact consumed-layout guard for the registered native city-shell library."""
import re

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

def check_registered_layout(layout,projection,registration):
    assert projection['layout_sha256']==registration['bindings']['art/data/building_layout.json']
    assert projection['native_sha256']==registration['source_native_sha256']
    assert shell_projection(layout)==projection['records'], 'Registered city physical source changed; rebuild its native library before closure'
