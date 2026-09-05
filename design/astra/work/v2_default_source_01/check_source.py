"""Source-only checks for the V2 default preparation; never launches an engine."""
import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[4]
OUT = Path(__file__).parent
BASE = '409bcac716ede34da837879296fd961472a8a913'
sys.path.insert(0, 'C:/Users/nate_/.cache/orison-source-tools/gdtoolkit')
from gdtoolkit.parser import parser

paths = [
    'game/scripts/building/orison_v2_runtime_root.gd',
    'game/scripts/building/orison_v2_shop_bucket_registry.gd',
    'game/scripts/building/orison_v2_shop_simulation.gd',
    'game/scripts/building/orison_v2_atmosphere.gd',
    'game/tests/orison_v2_shop_simulation_test.gd',
    'game/tests/orison_v2_connected_world_test.gd',
    'game/tests/OrisonV2ShopSimulationTest.tscn',
    'game/shaders/orison_waking_sky.gdshader',
    'tools/orison_spatial_dependency_manifest.json',
]
for path in paths:
    text = (ROOT/path).read_text(encoding='utf-8')
    if path.endswith('.gd'):
        parser.parse(text)
    if path.endswith(('.gd', '.tscn')):
        for dependency in re.findall(r'"(res://[^"\n]+)"', text):
            assert (ROOT/'game'/dependency.removeprefix('res://')).exists(), dependency

original = (ROOT/'game/scripts/building/building_root.gd').read_text(encoding='utf-8')
method = original.split('func _build_sky_dome(panorama: Texture2D) -> void:', 1)[1]
shader = method.split('shader.code = """', 1)[1].split('"""', 1)[0].lstrip('\n')
assert shader == (ROOT/'game/shaders/orison_waking_sky.gdshader').read_text(encoding='utf-8')
old_manifest = json.loads(subprocess.check_output(['git', 'show', BASE+':tools/orison_spatial_dependency_manifest.json'], cwd=ROOT))
new_manifest = json.loads((ROOT/'tools/orison_spatial_dependency_manifest.json').read_text())
assert new_manifest['records'][:len(old_manifest['records'])] == old_manifest['records']
assert len(new_manifest['records']) == len(old_manifest['records']) + 7
protected = ['game/scripts/building/building_root_selector.gd',
             'game/scripts/building/building_root.gd',
             'game/data/building_layout.json', 'art/data/building_layout.json',
             'game/scripts/game/campaign_clock_driver.gd', 'game/scripts/game/campaign_clock.gd']
for floor in ['01', '02', '03', '04', '05', '06', 'b1']:
    for extension in ['gltf', 'bin']:
        protected.append(f'game/assets/building/floor_{floor}.{extension}')
subprocess.run(['git', 'diff', '--exit-code', BASE, '--', *protected], cwd=ROOT, check=True)
receipt = {
    'status': 'SOURCE_CHECKS_PASS_NATIVE_UNRUN',
    'base_head': BASE,
    'native_godot_started': False,
    'gdscript_syntax_parser': 'gdtoolkit 4.5; not the Godot compiler',
    'parsed_gdscript_files': sum(p.endswith('.gd') for p in paths),
    'sky_shader_exact_extraction': True,
    'existing_spatial_inventory_records_unchanged': True,
    'reviewed_inventory_additions': 7,
    'preserved_paths': protected,
    'files': {p: hashlib.sha256((ROOT/p).read_bytes()).hexdigest() for p in paths},
    'native_scenes_prepared_not_run': ['res://tests/OrisonV2ShopSimulationTest.tscn',
                                      'res://tests/OrisonV2ConnectedWorldTest.tscn'],
    'default_switch': 'NOT_APPLIED: structural, runtime, visual and performance gates remain open',
}
(OUT/'source_checks.json').write_text(json.dumps(receipt, indent=2)+'\n', encoding='utf-8', newline='\n')
print(json.dumps({k:v for k,v in receipt.items() if k not in ['files','preserved_paths']}, indent=2))
