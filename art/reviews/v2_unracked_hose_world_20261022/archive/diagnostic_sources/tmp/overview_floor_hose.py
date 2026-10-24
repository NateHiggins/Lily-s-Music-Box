import bpy,os
from pathlib import Path
from mathutils import Vector
root=Path(__file__).resolve().parents[1]
source=Path(os.environ['HOSE_OVERVIEW_SOURCE'])
bpy.ops.wm.open_mainfile(filepath=str(source))
obj=bpy.data.objects['UnrackedHose']
points=[obj.matrix_world@Vector(v) for v in obj.bound_box]
low=Vector(tuple(min(p[i] for p in points) for i in range(3)))
high=Vector(tuple(max(p[i] for p in points) for i in range(3)))
center=(low+high)/2;extent=max(high-low)
scene=bpy.context.scene
scene.camera.location=center+Vector((2.4,-1.2,1.2))*extent
scene.camera.rotation_euler=(center-scene.camera.location).to_track_quat('-Z','Y').to_euler()
scene.camera.data.lens=48
for i,light in enumerate(o for o in bpy.data.objects if o.type=='LIGHT'):
    light.location=center+Vector((1.0,(-1 if i else 1)*.8,1.2))*extent
    light.rotation_euler=(center-light.location).to_track_quat('-Z','Y').to_euler()
    light.data.energy=150;light.data.size=extent
scene.render.filepath=os.environ['HOSE_OVERVIEW_OUT']
bpy.ops.render.render(write_still=True)
