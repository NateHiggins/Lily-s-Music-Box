"""Seed scene imports with reviewed UV precision before the first Godot run."""
from pathlib import Path
import hashlib,re
ROOT=Path(__file__).resolve().parents[1]
template=(ROOT/'game/assets/props/roof_lighting_supply.glb.import').read_text(encoding='utf-8')
for name in ['active_household_radios','active_household_projector']:
    target=ROOT/f'game/assets/props/{name}.glb.import'
    if target.exists():continue
    source=f'res://assets/props/{name}.glb'
    cache=f'res://.godot/imported/{name}.glb-'+hashlib.md5(source.encode()).hexdigest()+'.scn'
    text=re.sub(r'^uid=.*\n','',template,flags=re.M)
    text=re.sub(r'^path=.*$',f'path="{cache}"',text,flags=re.M)
    text=re.sub(r'^source_file=.*$',f'source_file="{source}"',text,flags=re.M)
    text=re.sub(r'^dest_files=.*$',f'dest_files=["{cache}"]',text,flags=re.M)
    target.write_text(text,encoding='utf-8',newline='\n')
    print('Seeded UV-safe scene import without reusing any UID:',name)
