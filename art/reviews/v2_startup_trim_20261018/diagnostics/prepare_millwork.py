from pathlib import Path
import re
r=Path('C:/PleaseRemainOnTheLine')
s=(r/'game/scripts/building/orison_v2_blockout.gd').read_text(encoding='utf8')
f=re.search(r'^func _build_spaces\(.*?(?=^func )',s,re.M|re.S).group()
f=f.split('\t# Shared wall owners must all exist before fitting either room-facing side.')[0]
out='''extends "res://scripts/building/orison_v2_blockout.gd"
func _ready() -> void:
	layout=_load_layout(layout_path)
	_validate_layout()
	if not failures.is_empty():return
	_build_palette()
	_build_spaces()
'''+f
(r/'game/tests/_v2_millwork_stock_probe.gd').write_text(out,encoding='utf8',newline='\n')
print('Stock-only source build; original wall construction unchanged; no production mutation')
