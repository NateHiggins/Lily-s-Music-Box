"""Two editable opaque pleated infills in existing LEFT leaf LOCAL GODOT metres.

This is freshly authored receiver geometry, not a scale/transform of old meshes.
Front/back UVs unfold the polyline's actual rest length; hem/end charts use
orthonormal physical planes. No interaction, disposal or light-tightness claim.
"""
import math

OWNER='storm_shop_photo_supplies_dr_door'
SEGMENTS=80
WAVES=7
THICKNESS=.0024
BOTTOM=.85
TOP=2.18
SOURCE_WITNESS={
    'geometry_source':'art/blender/scripts/photo_radio_fittings_geometry.py',
    'material_source':'art/data/photo_radio_fittings/source_plan.json',
    'source_owner':OWNER,'source_part_id':OWNER+'__fabric_warm',
    'material_family':'fabric_warm','tint':[.035,.035,.035,1.],
    'original_segments':80,'original_waves':7,'original_amplitudes_m':[.008,.004],
    'original_thickness_m':.0024,'original_mean_source_blender_x_m':[22.844,22.872],
    'original_overlap_m':.09,
    'receiver_adaptation':'New .39m spans /1.33m height /40mm overlap /20mm mean-depth stagger; original meshes not scaled.'}


def stocks():
    """Return2closed stocks with one metre UV per face corner (face_uvs)."""
    result=[]
    for number,(x0,x1,depth,amplitude) in enumerate([(.13,.52,-.010,.008),(.48,.87,.010,.004)]):
        n=SEGMENTS+1
        line=[(x0+(x1-x0)*j/SEGMENTS,depth+amplitude*math.cos(j/SEGMENTS*math.tau*WAVES)) for j in range(n)]
        arc=[0.]
        for a,b in zip(line,line[1:]):arc.append(arc[-1]+math.hypot(b[0]-a[0],b[1]-a[1]))
        vertices=[(x,y,z+side*THICKNESS*.5) for side in [-1,1] for y in [BOTTOM,TOP] for x,z in line]
        faces=[];uvs=[];roles=[]
        def index(side,high,j):return side*2*n+high*n+j
        def emit(face,role):
            chart=[]
            for i in face:
                side=i//(2*n);high=(i%(2*n))//n;j=i%n;x,y,z=vertices[i]
                if role in ('front','back'):uv=((-arc[j] if role=='front' else arc[j]),y-BOTTOM)
                elif role in ('bottom_hem','top_hem'):uv=(x-x0,(-1 if role=='top_hem' else 1)*(z-depth))
                else:uv=((-1 if role=='right_cap' else 1)*(z-line[j][1]),y-BOTTOM)
                chart.append(uv)
            faces.append(face);uvs.append(chart);roles.append(role)
        for j in range(SEGMENTS):
            emit([index(0,0,j),index(0,1,j),index(0,1,j+1),index(0,0,j+1)],'front')
            emit([index(1,0,j),index(1,0,j+1),index(1,1,j+1),index(1,1,j)],'back')
            emit([index(0,0,j),index(0,0,j+1),index(1,0,j+1),index(1,0,j)],'bottom_hem')
            emit([index(0,1,j),index(1,1,j),index(1,1,j+1),index(0,1,j+1)],'top_hem')
        emit([index(0,0,0),index(1,0,0),index(1,1,0),index(0,1,0)],'left_cap')
        emit([index(0,0,SEGMENTS),index(0,1,SEGMENTS),index(1,1,SEGMENTS),index(1,0,SEGMENTS)],'right_cap')
        # Return fresh provenance arrays too; downstream authoring cannot mutate constants.
        witness={k:list(v) if isinstance(v,list) else v for k,v in SOURCE_WITNESS.items()}
        result.append(dict(name='PhotoDarkroomCurtain'+str(number),vertices=vertices,faces=faces,
            face_uvs=uvs,face_roles=roles,material='fabric_warm',material_family='fabric_warm',
            tint=[.035,.035,.035,1.],tile_m=.7,owner=OWNER,source_owner=OWNER,source_part_id=OWNER+'__fabric_warm',source_witness=witness,role='double_pleated_leaf_infill',
            coordinate_frame='LOCAL_GODOT_LEFT_LEAF',fixed=False,bevel_m=0.,
            bounds_low=[x0,BOTTOM,min(z for x,z in line)-THICKNESS*.5],
            bounds_high=[x1,TOP,max(z for x,z in line)+THICKNESS*.5],
            rest_arclength_m=arc,mean_depth_m=depth,amplitude_m=amplitude,
            closed_volume_m3=(x1-x0)*(TOP-BOTTOM)*THICKNESS,
            source_disposal_authorized=False,optical_light_tightness_qualified=False))
    return result
