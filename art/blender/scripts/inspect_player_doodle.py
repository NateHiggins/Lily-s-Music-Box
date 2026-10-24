"""Inspect the owner's rig and animation before native integration."""
from pathlib import Path
import bpy,json
root=Path(__file__).resolve().parents[3]
source=root/'art/source/player_doodle_20261023/Meshy_AI_Smiling_Stick_Figure_biped'
out=root/'art/reviews/v2_player_doodle_20261023';out.mkdir(parents=True,exist_ok=True)
records=[]
for path in sorted(source.glob('*.fbx')):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.fbx(filepath=str(path))
    records.append({'file':path.name,'fps':bpy.context.scene.render.fps,'objects':[{'name':o.name,'type':o.type,'scale':list(o.scale),'dimensions':list(o.dimensions),'location':list(o.location),'rotation':list(o.rotation_euler),'vertices':len(o.data.vertices) if o.type=='MESH' else 0,'polygons':len(o.data.polygons) if o.type=='MESH' else 0,'uv_layers':len(o.data.uv_layers) if o.type=='MESH' else 0,'bones':[b.name for b in o.data.bones] if o.type=='ARMATURE' else []} for o in bpy.context.scene.objects],'actions':[{'name':a.name,'range':list(a.frame_range),'slots':[s.identifier for s in a.slots]} for a in bpy.data.actions]})
(out/'source_inspection.json').write_text(json.dumps({'evidence_class':'INERT','files':records},indent=2)+'\n',encoding='utf-8',newline='\n')
print(json.dumps(records))
