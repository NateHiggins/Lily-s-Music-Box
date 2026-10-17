"""Matched native cap and socket helices. Dimensions describe custom stock,
not a claim of a particular commercial thread standard or historical maker.
Positive axial withdrawal and positive rotation preserve the mating phase.
"""
import json
import math
import sys
from pathlib import Path
import bpy

ROOT = Path(__file__).resolve().parents[3]
SPEC_PATH = ROOT/'art/data/orison_v2/radiator_vent_thread_source.json'
SPEC = json.loads(SPEC_PATH.read_text())
sys.path.insert(0,str(ROOT/'tools'))
from build_v2_radiator_vent_thread import project
project(SPEC)
PITCH, ENGAGEMENT = SPEC['pitch_m'], SPEC['engagement_m']
ROOT_RADIUS, CREST_RADIUS = SPEC['root_radius_m'], SPEC['crest_radius_m']
BOTTOM, SHOULDER = SPEC['stem_bottom_m'], SPEC['shoulder_m']
assert abs(SHOULDER-BOTTOM-ENGAGEMENT) < 1e-10
assert 0 < SPEC['female_radial_clearance_m'] < (CREST_RADIUS-ROOT_RADIUS)/2

def profile(z, angle):
    phase = ((z-BOTTOM)/PITCH-angle/math.tau) % 1.0
    distance = abs(phase-.5)
    half_crest = SPEC['crest_fraction']/2
    flank = (CREST_RADIUS-ROOT_RADIUS)/math.tan(math.radians(SPEC['flank_angle_degrees']))/PITCH
    return max(0., min(1., 1-(distance-half_crest)/flank))

def male_radius(z, angle):
    # Short feathered lead/runout; the female groove continues fully through
    # the neck, so these reduced male crests never wedge during withdrawal.
    fade = min(1., max(0., (z-BOTTOM)/(PITCH*.75)), max(0., (SHOULDER-z)/(PITCH*.5)))
    return ROOT_RADIUS+(CREST_RADIUS-ROOT_RADIUS)*profile(z,angle)*fade

def female_radius(z, angle):
    entry=max(0.,min(1.,(z-SHOULDER+SPEC['entry_chamfer_m'])/SPEC['entry_chamfer_m']))
    # The socket mouth clears the cap's eased shoulder. This is actual
    # receiving chamfer stock, not a collision exception at full seating.
    return ROOT_RADIUS+SPEC['female_radial_clearance_m']+(CREST_RADIUS-ROOT_RADIUS)*max(profile(z,angle),entry)

def _stock(name, rings, capped=False):
    n=SPEC['angular_samples'];vertices=[]
    for z,radius in rings:
        for index in range(n):
            angle=math.tau*index/n
            r=radius(z,angle) if callable(radius) else radius
            vertices.append((.043+r*math.cos(angle),r*math.sin(angle),z))
    faces=[]
    count=len(rings)
    for row in range(count-1):
        for i in range(n):
            j=(i+1)%n
            faces.append((row*n+i,row*n+j,(row+1)*n+j,(row+1)*n+i))
    if capped:
        faces += [tuple(reversed(range(n))),tuple((count-1)*n+i for i in range(n))]
    else:
        for i in range(n):
            j=(i+1)%n
            faces.append(((count-1)*n+i,(count-1)*n+j,j,i))
    mesh=bpy.data.meshes.new(name);mesh.from_pydata(vertices,[],faces);mesh.update()
    obj=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(obj)
    return obj

def cap_stock():
    steps=round(ENGAGEMENT/PITCH*SPEC['samples_per_pitch'])
    rings=[(BOTTOM+ENGAGEMENT*i/steps,male_radius) for i in range(steps+1)]
    # Outer flange, top, open insert socket, needle seat and bellmouth.
    rings += [(SHOULDER,.019),(.075,.019),(.075,.0032),(.061,.0032),
              (.061,.0012),(.0602,.0012),(.0602,.004),(BOTTOM,.004)]
    return _stock('ThreadedVentCap',rings)

def socket_cutter():
    start,end=BOTTOM,SHOULDER+.001
    steps=math.ceil((end-start)/PITCH*SPEC['samples_per_pitch'])
    rings=[(.045,.014),(BOTTOM-.0002,.014)]
    rings += [(start+(end-start)*i/steps,female_radius) for i in range(steps+1)]
    return _stock('MatchedFemaleCapSocket',rings,capped=True)
