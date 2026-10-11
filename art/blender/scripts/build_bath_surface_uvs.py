"""Author retained soap-dish triangle charts in Blender; preserve source stock."""
from pathlib import Path
import json,sys
import bpy
ROOT=Path(__file__).resolve().parents[3]
sys.path.insert(0,str(Path(__file__).parent))
from repair_surface_uvs import repair_scene
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.preferences.filepaths.save_version=0
path=ROOT/'game/data/orison_v2/bath_details.json'
data=json.loads(path.read_text());charts=[]
source=next(r for r in data['props'] if r['kind']=='soap_dish')
for number,surface in enumerate(source['surfaces']):
    p=surface['vertices'];points=[(p[i],-p[i+2],p[i+1]) for i in range(0,len(p),3)]
    mesh=bpy.data.meshes.new(surface['material']);mesh.from_pydata(points,[],[tuple(range(i,i+3)) for i in range(0,len(points),3)])
    obj=bpy.data.objects.new('SoapDish_'+str(number),mesh);bpy.context.collection.objects.link(obj)
repair_scene()
for obj in bpy.context.scene.objects:
    uv=obj.data.uv_layers.active.data
    charts.append([value for loop in uv for value in (float(loop.uv.x),float(1-loop.uv.y))])
for record in data['props']:
    if record['kind']=='soap_dish':
        assert [s['vertices'] for s in record['surfaces']]==[s['vertices'] for s in source['surfaces']]
        for surface,chart in zip(record['surfaces'],charts): surface['uvs']=chart
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art/blender/bath_surface_uvs.blend'))
path.write_text(json.dumps(data,separators=(',',':'))+'\n',newline='\n')
print('SOAP DISH UVS: retained three stocks, twelve original owners')
