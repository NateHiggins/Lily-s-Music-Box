"""Native counterpart of the scoped V2 optical overrides, without mesh edits."""
from pathlib import Path
import json
import bpy,numpy as np
ROOT=Path(__file__).resolve().parents[3]

def apply_current(group):
    data=json.loads((ROOT/'game/data/orison_v2/owner_finish_profiles.json').read_text())
    profiles={g['id']:{r['source_key']:r for r in g['recipes']} for g in data['groups']}[group]
    catalog=json.loads((ROOT/'game/data/runtime_material_sets.json').read_text())['materials']
    keys={}
    for k,s in catalog.items():keys.setdefault(s['files'][0],k)
    changed=[]
    for mat in bpy.data.materials:
        if not mat.use_nodes:continue
        nodes=mat.node_tree.nodes;links=mat.node_tree.links;bsdf=next((n for n in nodes if n.type=='BSDF_PRINCIPLED'),None)
        if not bsdf:continue
        textures=[n for n in nodes if n.type=='TEX_IMAGE' and n.image]
        albedo=next((n for n in textures if Path(n.image.filepath).name in keys),None)
        key=keys[Path(albedo.image.filepath).name] if albedo else mat.name.split('.')[0]
        recipe=profiles.get(key)
        if not recipe:continue
        if bsdf.inputs['Alpha'].default_value<1 or bsdf.inputs['Transmission Weight'].default_value>0:continue
        bsdf.inputs['Metallic'].default_value=recipe['metallic']
        if recipe.get('untextured'):
            for name in ['Base Color','Normal','Roughness']:
                for link in list(bsdf.inputs[name].links):links.remove(link)
            bsdf.inputs['Base Color'].default_value=tuple(v/12.92 if v<=.04045 else ((v+.055)/1.055)**2.4 for v in recipe['color'][:3])+(1,)
            bsdf.inputs['Roughness'].default_value=recipe['roughness']
        else:
            selected=recipe.get('catalog',key)
            if selected!=key:
                before=catalog[key];after=catalog[selected]
                for node in textures:
                    name=Path(node.image.filepath).name
                    if name in before['files']:
                        index=before['files'].index(name)
                        node.image=bpy.data.images.load(str(ROOT/'game/assets/building/textures'/after['files'][index]),check_existing=True)
                        if index:node.image.colorspace_settings.name='Non-Color'
                for node in nodes:
                    if node.type=='VECT_MATH' and node.operation=='SCALE':node.inputs['Scale'].default_value*=before['meters_per_tile']/after['meters_per_tile']
            if not recipe.get('retain_tint',False) and albedo:
                tint=tuple(v/12.92 if v<=.04045 else ((v+.055)/1.055)**2.4 for v in recipe['color'][:3])+(1,)
                mix=nodes.new('ShaderNodeMixRGB');mix.blend_type='MULTIPLY';mix.inputs[0].default_value=1;mix.inputs[2].default_value=tint
                links.new(albedo.outputs['Color'],mix.inputs[1]);links.new(mix.outputs[0],bsdf.inputs['Base Color'])
            for node in nodes:
                if node.type=='NORMAL_MAP':node.inputs['Strength'].default_value=recipe['normal']
            rough=bsdf.inputs['Roughness']
            if rough.links:
                source=rough.links[0].from_socket
                if source.node.type=='MATH' and source.node.operation=='MULTIPLY':source.node.inputs[1].default_value=recipe['roughness']
                else:
                    mul=nodes.new('ShaderNodeMath');mul.operation='MULTIPLY';mul.inputs[1].default_value=recipe['roughness'];links.new(source,mul.inputs[0]);links.new(mul.outputs[0],rough)
            else:rough.default_value=recipe['roughness']
            if 'pigment' in recipe and albedo:
                sample=albedo.image.copy();sample.scale(32,32)
                pixels=np.array(sample.pixels[:],dtype=float).reshape(32,32,4)
                mean=pixels[:,:,:3].mean((0,1));bpy.data.images.remove(sample)
                destinations=[link.to_socket for link in list(albedo.outputs['Color'].links)]
                mix=nodes.new('ShaderNodeMixRGB');mix.name='Owner pigment contrast';mix.blend_type='MIX';mix.inputs[0].default_value=recipe['pigment'];mix.inputs[1].default_value=(*mean,1)
                links.new(albedo.outputs['Color'],mix.inputs[2])
                for socket in destinations:links.new(mix.outputs[0],socket)
        changed.append({'material':mat.name,'key':key})
    return changed
