"""Extract only pure assembly geometry; never imports or starts Blender/Godot."""
import ast, hashlib, json, math, zlib
from pathlib import Path
ROOT=Path(__file__).resolve().parents[4]
OUT=Path(__file__).parent
SOURCE='art/blender/scripts/build_orison.py'
PLACEMENTS=[('4B_wc','F04_B_BATH',[-6.7,0,5.5],0,[-6.7,0,4.5])]
METHODS={'__init__','add_quad','add_hex','add_lathe','add_tube','add_tbox'}
def generate():
    source=(ROOT/SOURCE).read_text(encoding='utf-8')
    tree=ast.parse(source)
    selected=[]
    for node in tree.body:
        if isinstance(node,ast.ClassDef) and node.name=='MeshBuf':
            node.body=[m for m in node.body if isinstance(m,ast.FunctionDef) and m.name in METHODS]
            selected.append(node)
        elif isinstance(node,ast.ClassDef) and node.name=='Frame': selected.append(node)
        elif isinstance(node,ast.FunctionDef) and node.name in {'asm_toilet'}: selected.append(node)
    namespace={'math':math,'zlib':zlib}
    exec(compile(ast.Module(body=selected,type_ignores=[]),SOURCE,'exec'),namespace)
    layout=json.loads((ROOT/'game/data/building_layout.json').read_text())
    records={r['id']:r for f in layout['floors'] for r in f.get('furniture',[])}
    furniture=[]
    def convert(v): return [v[0],v[2],-v[1]]
    for identity,room,position,yaw,stance in PLACEMENTS:
        buffers={}; hull=namespace['MeshBuf']('hull',None)
        def get_buf(material):
            if material not in buffers: buffers[material]=namespace['MeshBuf'](material,None)
            return buffers[material]
        frame=namespace['Frame'](get_buf,lambda:hull,0,0,0,0)
        spec=records[identity]
        namespace['asm_'+spec['asm']](frame,spec)
        surfaces=[]; all_vertices=[]
        for material,buf in buffers.items():
            if material=='fx_shadow': continue # Native lighting owns contact shadows.
            vertices=[]; normals=[]
            converted=[convert(v) for v in buf.verts]; all_vertices+=converted
            for face in buf.faces:
                for i in range(1,len(face)-1):
                    a,b,c=[converted[j] for j in (face[0],face[i],face[i+1])]
                    u=[b[j]-a[j] for j in range(3)]; v=[c[j]-a[j] for j in range(3)]
                    n=[u[1]*v[2]-u[2]*v[1],u[2]*v[0]-u[0]*v[2],u[0]*v[1]-u[1]*v[0]]
                    length=math.sqrt(sum(x*x for x in n))
                    if length<1e-12: continue
                    n=[x/length for x in n]
                    for vertex in (a,c,b): # Godot uses clockwise front faces.
                        vertices+=vertex; normals+=n
            surfaces.append(dict(material=material,vertices=vertices,normals=normals))
        # Include the source assembly's authored coarse collision.
        collision_vertices=all_vertices+[convert(v) for v in hull.verts]
        bounds=[[min(v[i] for v in collision_vertices) for i in range(3)],
                [max(v[i] for v in collision_vertices) for i in range(3)]]
        bounds=[[-.27,0,-.40],[.27,.84,.36]] # Existing flush owner's collider.
        record=dict(id=identity,kind=spec['asm'],bounds=bounds,surfaces=surfaces)
        furniture.append(record)
    return dict(schema_version=1,furniture=furniture)
if __name__=='__main__':
    result=generate()
    (OUT/'placements.json').write_text(json.dumps([dict(id=i,space=s,position=p,yaw=y,stance=t) for i,s,p,y,t in PLACEMENTS],indent=2)+'\n',newline='\n')
    target=ROOT/'game/data/orison_v2/domestic_furniture.json'
    existing=json.loads(target.read_text())
    existing['furniture']=[r for r in existing['furniture'] if r['id'] not in {p[0] for p in PLACEMENTS}]+result['furniture']
    target.write_text(json.dumps(existing,separators=(',',':'))+'\n',encoding='utf-8',newline='\n')
    blockout_path=ROOT/'game/data/orison_v2_blockout.json'
    blockout_text=blockout_path.read_text()
    blockout=json.loads(blockout_text)
    new_anchors=[]
    for identity,room,position,yaw,stance in PLACEMENTS:
        new_anchors += [dict(id=identity,level='F04',space=room,position=position,yaw=yaw,kind='furniture'),
                        dict(id=identity+'_STANCE',level='F04',space=room,position=stance,yaw=yaw+math.pi,kind='clearance')]
    new_anchors += [dict(id='F04_4B_SINK_01',level='F04',space='F04_B_BATH',position=[-7.6,0,3.8],yaw=math.pi,kind='fixture'),
                    dict(id='F04_4B_SINK_STANCE',level='F04',space='F04_B_BATH',position=[-7.6,0,4.7],yaw=0,kind='clearance')]
    new_ids={a['id'] for a in new_anchors}
    installed=[a for a in blockout['anchors'] if a['id'] in new_ids]
    if installed:
        assert installed == new_anchors, 'Existing placement differs; review before replacing it'
    else:
        # Preserve the hand-formatted document outside this added anchor group.
        start=blockout_text.index('[',blockout_text.index('"anchors"'))
        _,length=json.JSONDecoder().raw_decode(blockout_text[start:])
        end=start+length-1
        prefix=blockout_text[:end].rstrip()
        additions=',\n'.join('    '+json.dumps(a,separators=(',', ': ')) for a in new_anchors)
        blockout_path.write_text(prefix+',\n'+additions+'\n  '+blockout_text[end:],encoding='utf-8',newline='\n')
    fittings_path=ROOT/'game/data/orison_v2/domestic_fittings.json'
    fittings=json.loads(fittings_path.read_text())
    sink=dict(id='F04_4B_SINK_01',kind='sink',unit='4B',properties=dict(fixture='bath_sink'))
    found=[r for r in fittings['fittings'] if r['id']==sink['id']]
    if found:
        assert found == [sink], 'Existing fitting differs'
    else:
        fittings['fittings'].append(sink)
        fittings_path.write_text(json.dumps(fittings,indent=2)+'\n',newline='\n')
    (OUT/'extraction.json').write_text(json.dumps(dict(source=SOURCE,source_sha256=hashlib.sha256((ROOT/SOURCE).read_bytes()).hexdigest(),
       selected=['MeshBuf pure methods','Frame','asm_toilet'],
       layout_sha256=hashlib.sha256((ROOT/'game/data/building_layout.json').read_bytes()).hexdigest(),
       omitted='Baked contact shadow quads; native lighting owns shadows.',
       output_sha256=hashlib.sha256(target.read_bytes()).hexdigest()),indent=2)+'\n',newline='\n')
    print([(r['id'],sum(len(s['vertices'])//9 for s in r['surfaces'])) for r in result['furniture']])
