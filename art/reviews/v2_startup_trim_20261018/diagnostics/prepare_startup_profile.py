from pathlib import Path
import re,json
r=Path('C:/PleaseRemainOnTheLine')
helper='''
func _profile_mark(label: String) -> void:
	var events: Array=Engine.get_meta("v2_startup_profile",[])
	events.append({"label":label,"us":Time.get_ticks_usec()})
	Engine.set_meta("v2_startup_profile",events)
'''
for basename,methods,out in [('orison_v2_runtime_root',['_ready','_compose_authorities','_compose_exterior'],'_v2_startup_profile_runtime'),('orison_v2_blockout',['_ready'],'_v2_startup_profile_blockout')]:
 src=(r/f'game/scripts/building/{basename}.gd').read_text(encoding='utf8')
 result=f'extends "res://scripts/building/{basename}.gd"\n'+helper
 for method in methods:
  match=re.search(r'^func '+method+r'\(.*?(?=^func |\Z)',src,re.M|re.S);assert match,method
  lines=match.group().splitlines(); new=[lines[0],f'\t_profile_mark("{basename}.{method}:enter")']
  for number,line in enumerate(lines[1:],1):
   text=line.strip()
   if line.startswith('\t') and not line.startswith('\t\t') and (text.startswith(('if not ','preload(','_build_','_compose_','add_child(','_mount(')) or (text.startswith('var ') and text.count('(')==text.count(')') and 'new()' in text)):
    new.append('\t_profile_mark('+json.dumps(f'{basename}.{method}:{number} {text[:100]}')+')')
   new.append(line)
   if basename=='orison_v2_runtime_root' and line=='\t_blockout = BLOCKOUT.instantiate()':new.append('\t_blockout.set_script(load("res://tests/_v2_startup_profile_blockout.gd"))')
  new.append(f'\t_profile_mark("{basename}.{method}:end")');result+='\n'.join(new)+'\n'
 (r/f'game/tests/{out}.gd').write_text(result,encoding='utf8',newline='\n')
print('Generated inherited method probes; production scripts unchanged')
