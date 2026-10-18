from pathlib import Path
import subprocess,re
r=Path('C:/PleaseRemainOnTheLine')
src=subprocess.check_output(['git','show','de076e78:game/scripts/building/orison_v2_millwork.gd'],cwd=r).decode('utf8')
f=re.search(r'^static func build\(.*?(?=^static func )',src,re.M|re.S).group()
for name in ['_room_wall_faces','collect_wall_stock','_casing_boxes','_corner_run','_profile_sections','_placement','_emit']:
 f=re.sub(r'(?<![A-Za-z0-9_.])'+name+r'\(', 'Trim.'+name+'(',f)
f=f.replace('EYE_RAIL_HEIGHT','Trim.EYE_RAIL_HEIGHT')
out='''extends RefCounted
## Unculled composition reference from de076e78, for differential fitting checks.
## Shared face/profile operations remain the shipping geometry authority.
const Trim=preload("res://scripts/building/orison_v2_millwork.gd")
'''+f
(r/'game/tests/millwork_unculled_reference.gd').write_text(out,encoding='utf8',newline='\n')
print('Frozen unculled composition only; no competing visual authority')
