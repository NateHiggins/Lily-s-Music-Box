"""One Blender process for the complete native candidate construction batch."""
from pathlib import Path
import runpy,sys,time,os,json
HERE=Path(__file__).resolve().parent
sys.path.insert(0,str(HERE))
STEPS=['cast_sections','cast_feet','header_fittings','globe_valve',
       'stem_packing','stem_screw','supply_family','family_surfaces',
       'pitch_kinematics','pitch_shims','articulated_union','automatic_vent',
       'mechanism_surfaces','union_packing','check_service_motion',
       'sliding_wall_ties','check_tie_casting_fit',
       'export_mechanisms','check_morph_buffers']
if os.environ.get('ORISON_RADIATOR_RENDER')=='1':
    os.environ['RADIATOR_FINISHED_REVIEW']='1'
    STEPS+=['render_assembly','render_vent','render_packing','render_wall_ties']
for name in STEPS:
    started=time.monotonic()
    print('RADIATOR STAGE',name,'START',flush=True)
    runpy.run_path(str(HERE/(name+'.py')),run_name='__main__')
    print('RADIATOR STAGE',name,'PASS',round(time.monotonic()-started,3),'seconds',flush=True)
