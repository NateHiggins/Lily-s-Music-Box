"""Project a retired plate's calibrated replacement into native material sets.

Only the named brown phenolic recipe migrates here. Source geometry, tints,
placement and all other finishes retain their existing authority.
"""
import json

def calibrate_sets(root,sets,plan,catalog):
    canonical=catalog['bakelite']
    recipe=json.loads((root/'art/textures'/canonical['catalog_mapping']/'material.json').read_text(encoding='utf-8'))
    assert canonical['catalog_mapping']=='procedural/bakelite'
    assert abs(canonical['meters_per_tile']-recipe['meters_per_tile'])<1e-9
    for key,spec in sets.items():
        if plan.get('catalog_variants',{}).get(key,key)!='bakelite':continue
        spec.update(files=canonical['files'],meters_per_tile=canonical['meters_per_tile'],
                    metallic=canonical['metallic'],normal_scale=recipe['normal_strength'],roughness=1.)
        plan.setdefault('finish_parameters',{}).setdefault(key,{}).update(normal_scale=recipe['normal_strength'],roughness=1.)
