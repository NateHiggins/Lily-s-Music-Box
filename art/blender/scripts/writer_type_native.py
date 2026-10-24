"""One batched reverse-letter relief decal, with physical and atlas UVs."""
import math
import bpy
from mathutils import Vector,Matrix

def stock(api):
    vertices=[];faces=[]
    cx,cy,cz=-.059,-.030,.068
    for bank in range(3):
        for j in range(16):
            angle=j*math.tau/16;n=Vector((math.sin(angle),0,-math.cos(angle)))
            u=Vector((-math.cos(angle),0,-math.sin(angle)))
            tilt=(bank-1)*math.radians(6)
            v=Vector((0,1,0))*math.cos(tilt)-n*math.sin(tilt)
            center=Vector((cx,cy+(bank-1)*.0045,cz))+n*.01393
            base=len(vertices)
            for a,b in [(-1,-1),(1,-1),(1,1),(-1,1)]:vertices.append(api['coords'](center+u*a*.0018+v*b*.0019))
            faces.append(tuple(base+i for i in range(4)))
    mesh=bpy.data.meshes.new('TypeEmboss');mesh.from_pydata(vertices,[],faces);mesh.update()
    obj=bpy.data.objects.new('TypeEmboss',mesh);api['stocks'].objects.link(obj)
    api['finish'](obj,'Reverse raised type','TypeSelector','TypeEmboss')

def finish(obj,root):
    mesh=obj.data;uv=mesh.uv_layers.active;atlas=mesh.uv_layers.new(name='TypeGlyph')
    for face in mesh.polygons:
        glyph=mesh.loops[face.loop_start].vertex_index//4;bank,j=divmod(glyph,16);angle=j*math.tau/16
        u=Vector((-math.cos(angle),math.sin(angle),0)) # Blender basis of outward face
        radial=Vector((math.sin(angle),math.cos(angle),0));tilt=(bank-1)*math.radians(6)
        vertical=Vector((0,0,1))*math.cos(tilt)-radial*math.sin(tilt)
        center=Vector((-.059,-.068,-.030+(bank-1)*.0045))+Vector((math.sin(angle),math.cos(angle),0))*.01393
        for li in face.loop_indices:
            delta=mesh.vertices[mesh.loops[li].vertex_index].co-center
            x=delta.dot(u)/.0036+.5;y=delta.dot(vertical)/.0038+.5
            uv.data[li].uv=(x*.0036,y*.0038)
            atlas.data[li].uv=((glyph%8+x)/8,1-(glyph//8+1-y)/6)
            mesh.attributes['_tangent_guide'].data[li].vector=(u.x,u.z,-u.y)
    mat=obj.data.materials[0]
    tree=mat.node_tree;bsdf=tree.nodes['Principled BSDF']
    coord=tree.nodes.new('ShaderNodeUVMap');coord.uv_map='TypeGlyph'
    tex=tree.nodes.new('ShaderNodeTexImage');tex.image=bpy.data.images.load(str(root/'game/assets/device/writer_type/reversed_type_emboss.png'))
    tex.image.colorspace_settings.name='Non-Color';tree.links.new(coord.outputs[0],tex.inputs[0])
    normal=tree.nodes.new('ShaderNodeNormalMap');normal.uv_map=mesh.uv_layers[0].name
    tree.links.new(tex.outputs['Color'],normal.inputs['Color']);tree.links.new(normal.outputs[0],bsdf.inputs['Normal'])
    tree.links.new(tex.outputs['Alpha'],bsdf.inputs['Alpha'])
    # Only the selected bank/cell may glow, no world-space light is created.
    sep=tree.nodes.new('ShaderNodeSeparateXYZ');tree.links.new(coord.outputs[0],sep.inputs[0])
    row=tree.nodes.new('ShaderNodeMath');row.operation='LESS_THAN';row.inputs[1].default_value=1/6
    tree.links.new(sep.outputs['Y'],row.inputs[0])
    col=tree.nodes.new('ShaderNodeMath');col.operation='LESS_THAN';col.inputs[1].default_value=1/8
    tree.links.new(sep.outputs['X'],col.inputs[0])
    mask=tree.nodes.new('ShaderNodeMath');mask.operation='MULTIPLY';tree.links.new(row.outputs[0],mask.inputs[0]);tree.links.new(col.outputs[0],mask.inputs[1])
    heat=tree.nodes.new('ShaderNodeMath');heat.name='ImpressionHeat';heat.operation='MULTIPLY';heat.inputs[1].default_value=0.
    tree.links.new(mask.outputs[0],heat.inputs[0]);tree.links.new(heat.outputs[0],bsdf.inputs['Emission Strength'])
    bsdf.inputs['Emission Color'].default_value=(.85,.12,.012,1)
    mat.surface_render_method='DITHERED'

def row_keys(obj,objects,pivot):
    """Top/bottom faces rock independently to a flat impression seat.

    Body, fixed spindle and the other row are untouched. The decal and die
    meshes use matching morphs, keeping raised letters attached to their die.
    """
    rest=[v.co.copy() for v in obj.data.vertices]
    obj.shape_key_add(name='Basis',from_mix=False)
    for bank,name in [(-1,'LowerSeat'),(1,'UpperSeat')]:
        key=obj.shape_key_add(name=name,from_mix=False);offset=0
        for i,point in enumerate(rest):key.data[i].co=point
        for source in objects:
            count=len(source.data.vertices)
            if 'type_bank' in source and source['type_bank']==bank:
                angle=source['type_angle'];radius=.01365
                center=Vector((-.059+radius*math.sin(angle),-.068+radius*math.cos(angle),-.030+bank*.0045))
                axis=Vector((-math.cos(angle),math.sin(angle),0))
                transform=Matrix.Rotation(bank*math.radians(6),4,axis)
                for i in range(count):key.data[offset+i].co=transform@(key.data[offset+i].co-center)+center
            elif source.name.startswith('Stock__Reverse raised type'):
                for i in range(count):
                    glyph=i//4;glyph_bank=glyph//16-1
                    if glyph_bank!=bank:continue
                    angle=(glyph%16)*math.tau/16;radius=.01393
                    center=Vector((-.059+radius*math.sin(angle),-.068+radius*math.cos(angle),-.030+bank*.0045))
                    axis=Vector((-math.cos(angle),math.sin(angle),0))
                    key.data[offset+i].co=Matrix.Rotation(bank*math.radians(6),4,axis)@(key.data[offset+i].co-center)+center
            offset+=count
        assert offset==len(obj.data.vertices)
