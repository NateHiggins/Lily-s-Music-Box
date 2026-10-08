"""Reuse established native cameras for the changed cloth and object details."""
from pathlib import Path
import json,sys,os
ROOT=Path(__file__).resolve().parents[3]
sys.path.insert(0,str(Path(__file__).parent))
from owner_finish_materials import apply_current
out=ROOT/'tmp/v2-improvement/cloth-object-native';out.mkdir(parents=True,exist_ok=True)
for family,group in [('household_wardrobes','domestic'),('domestic_objects','domestic_objects')]:
    path=ROOT/'art/blender/scripts'/('render_'+family+'.py')
    code=path.read_text(encoding='utf-8').replace('tmp/v2-finish-review','tmp/v2-improvement/cloth-object-native')
    if family=='household_wardrobes':
        code=code.replace("if os.environ.get('WARDROBE_DRAFT'):spec=[('Wardrobe00','closed'),('Wardrobe00','open')]","spec=[('Wardrobe00','open'),('Wardrobe03','open')]")
    else:
        code=code.replace("for row in plan['variants']:","for row in [r for r in plan['variants'] if r['id'] in ['DomesticObject03','DomesticObject05','DomesticObject11','DomesticObject12']]:")
    lines=code.splitlines();index=next(i for i,s in enumerate(lines) if 'bpy.ops.wm.open_mainfile(' in s)
    lines.insert(index+1,"apply_current('"+group+"')")
    exec(compile('\n'.join(lines),str(path),'exec'),{'__file__':str(path),'__name__':'__main__','apply_current':apply_current})
