"""Extract only pure assembly geometry; never imports or starts Blender/Godot."""
import ast, hashlib, json, math, zlib
from pathlib import Path
ROOT=Path(__file__).resolve().parents[4]
OUT=Path(__file__).parent
SOURCE='art/blender/scripts/build_orison.py'
PLACEMENTS=[('3B_abed','F03_B_ALCOVE',[10.5,0,-10.7],math.pi,[11.9,0,-10.7]),
            ('3B_workbench','F03_B_MAIN',[13.65,0,-.2],0,[13.65,0,-1.35]),
            ('3B_wc','F03_B_BATH',[15.05,0,-11.9],math.pi,[15.05,0,-11.02]),
            ('3B_abed_ns','F03_B_ALCOVE',[11.62,0,-11.4],0,[11.9,0,-10.7]),
            ('3B_aw_wardrobe','F03_B_ALCOVE',[10.4,0,-8.5],0,[11.7,0,-9.15]),
            ('3B_tools0','F03_B_MAIN',[11.8,0,-3.5],-math.pi/2,[12.65,0,-3.5]),
            ('3B_tools1','F03_B_MAIN',[11.8,0,-4.6],-math.pi/2,[12.65,0,-4.6])]
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
        elif isinstance(node,ast.FunctionDef) and node.name in {'asm_bed','asm_workbench','asm_toilet','case_wood','asm_nightstand','asm_wardrobe','asm_shelf','hash_str','_jit'}: selected.append(node)
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
        # Include authored coarse collision and decorative protrusions such as vise handle.
        collision_vertices=all_vertices+[convert(v) for v in hull.verts]
        bounds=[[min(v[i] for v in collision_vertices) for i in range(3)],
                [max(v[i] for v in collision_vertices) for i in range(3)]]
        if spec['asm']=='toilet': bounds=[[-.27,0,-.40],[.27,.84,.36]] # Existing mechanism collider.
        record=dict(id=identity,kind=spec['asm'],bounds=bounds,surfaces=surfaces)
        if spec['asm']=='wardrobe':
            record['mechanism']={key:spec[key] for key in ['id','asm','W','case_wood']}
            record['bounds']=[[-.71,-.03,-.37],[.71,1.99,.37]]
        furniture.append(record)
    return dict(schema_version=1,furniture=furniture)
if __name__=='__main__':
    result=generate()
    (OUT/'placements.json').write_text(json.dumps([dict(id=i,space=s,position=p,yaw=y,stance=t) for i,s,p,y,t in PLACEMENTS],indent=2)+'\n',newline='\n')
    target=ROOT/'game/data/orison_v2/domestic_furniture.json'
    target.write_text(json.dumps(result,separators=(',',':'))+'\n',encoding='utf-8',newline='\n')
    (OUT/'extraction.json').write_text(json.dumps(dict(source=SOURCE,source_sha256=hashlib.sha256((ROOT/SOURCE).read_bytes()).hexdigest(),
       selected=['MeshBuf pure methods','Frame','case_wood','asm_bed','asm_workbench','asm_toilet','asm_nightstand','asm_wardrobe','asm_shelf','hash_str','_jit'],
       omitted='Baked contact shadow quads; native lighting owns shadows.',
       output_sha256=hashlib.sha256(target.read_bytes()).hexdigest()),indent=2)+'\n',newline='\n')
    print([(r['id'],sum(len(s['vertices'])//9 for s in r['surfaces'])) for r in result['furniture']])
