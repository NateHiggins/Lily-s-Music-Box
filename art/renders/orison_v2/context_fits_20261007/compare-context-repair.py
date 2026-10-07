from pathlib import Path
import ast,hashlib,json,struct,subprocess
R=Path.cwd();tree=ast.parse((R/'tmp/v2-finish-review/rebind-grain-dependencies.py').read_text(encoding='utf-8'))
function=ast.unparse(next(n for n in tree.body if isinstance(n,ast.FunctionDef) and n.name=='geometry'))
function=function.replace("for i in indices:\n                h.update(positions[struct.unpack('<' + fmt, i)[0]])", "expanded=[positions[struct.unpack('<' + fmt,i)[0]] for i in indices]\n            triangles=[min(tuple(expanded[k+j:k+3]+expanded[k:k+j]) for j in range(3)) for k in range(0,len(expanded),3)]\n            for triangle in sorted(triangles):h.update(b''.join(triangle))")
assert 'triangles=[min(' in function
exec(compile(function,'<canonical physical triangle comparator>','exec'))
results=[]
allowed={'laundry_fittings':lambda n:('_parcel' in n and n.endswith('__linen')) or '_iron_pad__' in n,
 'hardware_stock':lambda n:'_bin_e' in n or '_stock_e' in n,
 'news_fittings':lambda n:any(w in n for w in ['_stool__','_chair_hollow__','_counter__countertop']),
 'locksmith_fittings':lambda n:'_safe__' in n,
 'druggist_cupboard':lambda n:'_poison_cupboard__wood_dark' in n,
 'cobbler_fittings':lambda n:'_dust_felt__soot__south' in n,
 'shop_joinery':lambda n:'_radio_service_boh_door__' in n,
 'hardware_tools':lambda n:'_tool_board__timber' in n}
for family in allowed:
 path=f'game/assets/props/{family}.glb';before=subprocess.check_output(['git','show','HEAD:'+path]);after=(R/path).read_bytes();a=geometry(before);b=geometry(after)
 assert a['parts'].keys()==b['parts'].keys(),family
 assert a['graph']==b['graph'],('scene graph changed',family)
 changed=[name for name in a['parts'] if a['parts'][name]!=b['parts'][name]]
 for name in changed:
  assert allowed[family](name),(family,name)
  assert [r['triangles'] for r in a['parts'][name]]==[r['triangles'] for r in b['parts'][name]],name
 results.append({'family':family,'changed_geometry':changed,'unchanged_geometry':len(a['parts'])-len(changed),'triangle_counts_unchanged':True,'asset_before':hashlib.sha256(before).hexdigest(),'asset_after':hashlib.sha256(after).hexdigest()})
 print(family,len(changed),'changed parts;',len(a['parts'])-len(changed),'unchanged')
(R/'tmp/v2-finish-review/context-repair-geometry-comparison.json').write_text(json.dumps({'evidence_class':'INERT','results':results},indent=2)+'\n',encoding='utf-8',newline='\n')
