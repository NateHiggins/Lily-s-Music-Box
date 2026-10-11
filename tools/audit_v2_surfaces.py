"""Evaluate composed V2 UV/PBR/mip discovery without hiding legacy debt.

Returns 1 for any unresolved surface requirement. It does not certify visual
appearance or ledger contracts. Use a current inventory from the Godot lane.
"""
import argparse,collections,json,copy,math
from pathlib import Path

TRIPLETS = [('albedo_texture','roughness_texture','normal_texture'),
            ('albedo_tex','rough_tex','normal_tex')]

def evaluate(data):
    if data.get('schema')!='orison.v2-surface-inventory.v1':raise ValueError('unknown inventory schema')
    if data.get('passage_state')!='RESIDENT':raise ValueError('passage was not resident; scope incomplete')
    if not data.get('draws') or not data.get('meshes') or not data.get('materials'):
        raise ValueError('empty composed geometry scope')
    # A next pass is another material on the same geometry, not invisible debt.
    data=copy.deepcopy(data)
    extra=[]
    for draw in data['draws']:
        for index,key in enumerate(draw['materials']):
            material=data['materials'].get(key,{})
            depth=0
            while material.get('next_pass'):
                depth+=1;material=material['next_pass']
                pass_key=draw['path']+f'/next_pass_{index}_{depth}'
                data['materials'][pass_key]=material
                data['meshes'][pass_key]={'source':data['meshes'][draw['mesh']]['source'],'surfaces':[data['meshes'][draw['mesh']]['surfaces'][index]]}
                extra.append(dict(draw,path=pass_key,mesh=pass_key,materials=[pass_key]))
    data['draws'].extend(extra)
    findings=[];effects=[]
    for row in data.get('unhandled_geometry',[]):
        findings.append({'id':row['path'],'owner':'','owner_script':'','mesh':'','material_name':'','visible':True,'reasons':['unhandled_geometry:'+row['type']]})
    for draw in data['draws']:
        if draw['instances']==0:continue
        mesh=data['meshes'][draw['mesh']]
        for index,surface in enumerate(mesh['surfaces']):
            identity=draw['path']+':'+str(index);reasons=[]
            material=data['materials'].get(draw['materials'][index],{})
            maps=material.get('maps',{})
            # Explicit external effects only. Unshaded, transparent or flat
            # materials do not automatically become exempt physical stock.
            shader=material.get('shader','')
            if (draw.get('surface_role')=='weather_optics' and
                draw.get('owner_script')=='res://scripts/building/v2_weather_fx.gd' and
                draw['path'].split('/')[-1] in ('DrivingRainSpatter','LiveSnow','LiveHail','DrivingRainMiddle','RoadwayMist') and
                (material.get('unshaded') or material.get('shader_unshaded'))):
                effects.append({'id':identity,'class':'weather_optics'});continue
            if (draw.get('surface_role')=='storm_volume' and
                draw.get('owner_script')=='res://scripts/building/exterior_detail_pass.gd' and
                material.get('name')=='V2_storm_volume' and material.get('shader_unshaded')):
                effects.append({'id':identity,'class':'storm_volume'});continue
            if (shader=='res://shaders/lamp_optical_dust.gdshader' and
                draw.get('owner_script')=='res://scripts/building/orison_v2_lamp_atmosphere.gd'):
                effects.append({'id':identity,'class':'light_scattering_dust'});continue
            halo=(draw.get('surface_role')=='optical_halo' and
                  draw.get('owner_script')=='res://scripts/props/light_fixture_prop.gd' and
                  all(material.get(flag) for flag in ('unshaded','additive','billboard')))
            steam=(draw.get('surface_role')=='steam_volume' and
                   draw.get('owner_script') in ('res://scripts/props/radiator_prop.gd','res://scripts/building/orison_v2_household_radiator.gd') and
                   draw.get('geometry_transparency',0)>0)
            flame=(draw.get('surface_role')=='gas_flame' and
                   draw.get('owner_script') in ('res://scripts/props/stove_prop.gd','res://scripts/building/orison_v2_stove.gd') and
                   material.get('unshaded') and material.get('emissive') and material.get('transparency',0)>0)
            optical_effect=halo or steam or flame
            if (draw.get('surface_role')=='reservation_debug' and
                draw.get('owner_script')=='res://scripts/building/orison_v2_blockout.gd'):
                effects.append({'id':identity,'class':'reservation_debug'});continue
            if shader=='res://shaders/orison_waking_sky.gdshader':
                effects.append({'id':identity,'class':'sky_projection'});continue
            if shader=='res://shaders/lamp_optical_glass_haze.gdshader':
                effects.append({'id':identity,'class':'secondary_scattering_layer'});continue
            if shader=='res://shaders/projected_film.gdshader':
                effects.append({'id':identity,'class':'projected_light'});continue
            if (material.get('name')=='M_fx_shadow' and maps.get('albedo_texture')=='res://assets/building/textures/T_fx_fx_shadow.png' and material.get('unshaded')):
                effects.append({'id':identity,'class':'contact_shadow_decal'});continue
            if surface['missing_uv']:reasons.append('missing_uv')
            if surface['nonfinite_uv']:reasons.append('nonfinite_uv')
            if surface['degenerate_uv_triangles']:reasons.append('collapsed_uv_triangles')
            clear_glass=(shader=='res://shaders/lamp_glass_surface.gdshader' and
                         maps.get('rough_tex')=='res://assets/building/textures/T_glass_rough.png' and
                         maps.get('normal_tex')=='res://assets/building/textures/T_glass_normal.png')
            if halo: effects.append({'id':identity,'class':'optical_halo'})
            if steam: effects.append({'id':identity,'class':'steam_volume'})
            if flame: effects.append({'id':identity,'class':'gas_flame'})
            if not optical_effect and not clear_glass and not any(all(maps.get(channel) for channel in triplet) for triplet in TRIPLETS):
                reasons.append('incomplete_pbr_maps')
            if not optical_effect and material.get('type')=='StandardMaterial3D':
                if 'normal_enabled' not in material: reasons.append('normal_map_state_unobserved')
                elif not material['normal_enabled']: reasons.append('normal_map_disabled')
                if material.get('filter') not in (2,3,4,5):reasons.append('non_mipmapped_filter')
            if not optical_effect:
                for flag in ('has_normal_tex','has_rough_tex','has_albedo_tex'):
                    if material.get(flag) is False:reasons.append('disabled_shader_map:'+flag)
            for texture in set(maps.values()):
                row=data['textures'][texture]
                if row.get('type')=='ViewportTexture':
                    effects.append({'id':identity,'class':'live_display_signal','texture':texture});continue
                if not row['mips']:reasons.append('missing_loaded_mips:'+texture)
                elif 'mip_levels' in row and row['mip_levels']<int(math.log2(max(row['width'],row['height']))):
                    reasons.append('incomplete_loaded_mip_chain:'+texture)
            if material.get('type')=='ShaderMaterial' and 'mip_filters' in material:
                for channel,texture in maps.items():
                    if data['textures'][texture].get('type')!='ViewportTexture' and not material['mip_filters'].get(channel):
                        reasons.append('non_mipmapped_shader_sampler:'+channel)
            if reasons:findings.append({'id':identity,'owner':draw.get('owner',''),'owner_script':draw.get('owner_script',''),'mesh':mesh['source'],'material_name':material.get('name',''),'visible':draw['visible'],'reasons':sorted(set(reasons))})
    counts=collections.Counter(reason.split(':')[0] for finding in findings for reason in finding['reasons'])
    return {'evidence_class':'INERT','result':'FAIL' if findings else 'PASS_TECHNICAL_ONLY','visual_acceptance':'requires reviewed renders','counts':dict(counts),'failing_surfaces':len(findings),'findings':findings,'separate_effects':effects}

def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--inventory',required=True);parser.add_argument('--out');args=parser.parse_args()
    report=evaluate(json.loads(Path(args.inventory).read_text()))
    if args.out:Path(args.out).write_text(json.dumps(report,indent=2)+'\n',newline='\n')
    print('V2 SURFACES:',report['result'],report['failing_surfaces'],'unresolved surfaces;',report['counts'])
    return 1 if report['findings'] else 0

if __name__=='__main__':raise SystemExit(main())
