"""Reuse accepted native cameras, stock charts and source poses for finish review."""
from pathlib import Path
import json,hashlib,sys
ROOT=Path(__file__).resolve().parents[3]
sys.path.insert(0,str(Path(__file__).resolve().parent))
from owner_finish_materials import apply_current
out=ROOT/'tmp/v2-improvement/household-finishes-native';out.mkdir(parents=True,exist_ok=True)
records=[]
for family,group in [('domestic_seating','domestic'),('domestic_tables','domestic'),('household_wardrobes','domestic'),('domestic_objects','domestic')]:
    path=ROOT/'art/blender/scripts'/('render_'+family+'.py')
    code=path.read_text(encoding='utf-8').replace('tmp/v2-finish-review','tmp/v2-improvement/household-finishes-native')
    lines=code.splitlines();index=next(i for i,s in enumerate(lines) if 'bpy.ops.wm.open_mainfile(' in s)
    lines.insert(index+1,"owner_finish_changes=apply_current('"+group+"')")
    scope={'__file__':str(path),'__name__':'__main__','apply_current':apply_current}
    exec(compile('\n'.join(lines),str(path),'exec'),scope)
    records.append({'family':family,'source_sha256':hashlib.sha256((ROOT/'art/blender'/(family+'.blend')).read_bytes()).hexdigest(),'materials':scope['owner_finish_changes']})
(out/'review.json').write_text(json.dumps({'evidence_class':'INERT','scope':'Retained native geometry, charts, tints and cameras; material-only review of shared finish recipes.','families':records},indent=2)+'\n',newline='\n')
