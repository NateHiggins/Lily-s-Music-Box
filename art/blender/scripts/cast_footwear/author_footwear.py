"""CPU native weight-band authoring; no asset export/render. Blender --background --python this -- ..."""
from pathlib import Path
import argparse,sys,json,hashlib,bpy
ap=argparse.ArgumentParser();ap.add_argument('--control',required=True,type=Path);ap.add_argument('--output',required=True,type=Path);ap.add_argument('--part',required=True);a=ap.parse_args(sys.argv[sys.argv.index('--')+1:]);assert a.control.resolve()!=a.output.resolve();before=hashlib.sha256(a.control.read_bytes()).hexdigest();bpy.ops.wm.open_mainfile(filepath=str(a.control));rig=next(o for o in bpy.data.objects if o.type=='ARMATURE');objects=[o for o in bpy.data.objects if o.type=='MESH'and o.get('part')==a.part];assert len(objects)==1 and len(rig.data.bones)==76
# Native groupedit only. Keep originalgroup names, Toe/others unchanged; sumsconserved.
canon=lambda n:n.replace('mixamorig:','');ankles={s:float((rig.matrix_world@next(b for b in rig.data.bones if canon(b.name)==s+'Foot').head_local).z)for s in['Left','Right']};changes=[];above=0;full={s:0 for s in ankles}
for obj in objects:
 groups={canon(x.name):x for x in obj.vertex_groups};names={x.index:canon(x.name)for x in obj.vertex_groups}
 for v in obj.data.vertices:
  z=float((obj.matrix_world@v.co).z);old={names[x.group]:float(x.weight)for x in v.groups};new=dict(old)
  for side in['Left','Right']:
   amount=old.get(side+'Leg',0)
   if amount<=0:continue
   low=ankles[side]-.005;high=ankles[side]+.025;t=max(0.,min(1.,(z-low)/(high-low)));f=1-t*t*(3-2*t)
   if f==0:above+=1;continue
   new[side+'Leg']=amount*(1-f);new[side+'Foot']=old.get(side+'Foot',0)+amount*f
   if f==1:full[side]+=1
  if new!=old:
   for side in['Left','Right']:
    for suffix in['Leg','Foot']:
     name=side+suffix
     if new.get(name,0)!=old.get(name,0):
      group=groups[name]
      if new[name]>0:group.add([v.index],new[name],'REPLACE')
      else:group.remove([v.index])
   after={names[x.group]:float(x.weight)for x in v.groups};assert all(after.get(n,0)==w for n,w in old.items()if n not in['LeftLeg','RightLeg','LeftFoot','RightFoot']);assert abs(sum(old.values())-sum(after.values()))<1e-6;changes.append(dict(vertex=v.index,world_z=z,before=old,after=after))

for image in bpy.data.images:
 if image.filepath:image.filepath=bpy.path.abspath(image.filepath)
a.output.parent.mkdir(parents=True,exist_ok=True);bpy.context.preferences.filepaths.save_version=0;bpy.ops.wm.save_as_mainfile(filepath=str(a.output));assert hashlib.sha256(a.control.read_bytes()).hexdigest()==before
(a.output.with_suffix('.authoring.json')).write_bytes(json.dumps(dict(control=str(a.control),control_sha256=before,output=str(a.output),output_sha256=hashlib.sha256(a.output.read_bytes()).hexdigest(),ankle_world_z=ankles,band=[-.005,.025],changed_vertices=changes,full_transfer_counts=full,above_band_leg_unchanged=above),indent=2).encode())
