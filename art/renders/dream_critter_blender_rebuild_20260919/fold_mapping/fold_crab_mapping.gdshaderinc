// STAGED PROPOSAL: include after blender_pose helpers and crab_* uniforms.
// Depends on Spatial's validated base uniforms; do not duplicate declarations.
// blender_joint_base[section]: 8 chains x 5 constant atlas rows.
// blender_manipulator_base[section]: 2 chains x 3 constant atlas rows.
// All arguments/returns are support-frame metres except material axial u.

vec3 fold_finite_normal(vec3 n, vec3 fallback) {
    return dot(n,n)>0.000000000001 ? normalize(n) : fallback;
}

int fold_cpu_leg(int canonical, int count) {
    int per_side = (count + 1) / 2;
    int row = canonical % 4;
    int side_count = canonical < 4 ? per_side : count - per_side;
    int cpu_row = row;
    if (side_count == 3) {
        if (row == 2) return -1;
        if (row == 3) cpu_row = 2;
    }
    return (canonical < 4 ? 0 : per_side) + cpu_row;
}

// OPTIONAL: root currently selects root-only transport; do not call these
// cortex helpers in the initial integration. The following is a count-variant
// collar adaptation, not a new motion law. The plateau moves
// the entire middle root ring; linear shoulders have positive axial Jacobian
// (minimum .297297...). Source row2 and the outer rows remain unchanged.
// Apply to unbound cortex AND all unbound internal tissue before world scale.
float fold_collar_delta(vec3 p, int count) {
    int per_side = (count + 1) / 2;
    int side_count = p.x < 0.0 ? per_side : count - per_side;
    if (side_count != 3) return 0.0;
    float lateral = smoothstep(0.10, 0.28, abs(p.x));
    float lower = clamp((p.z + 0.074) / 0.148, 0.0, 1.0);
    float upper = clamp((0.282 - p.z) / 0.148, 0.0, 1.0);
    return -0.104 * lateral * lower * upper;
}
vec3 fold_collar_point(vec3 p, vec3 dimensions, int count) {
    p.z += dimensions.z * fold_collar_delta(p / dimensions, count);
    return p;
}
vec3 fold_collar_normal(vec3 p, vec3 n, vec3 dimensions, int count) {
    vec3 q = p / dimensions;
    float e = 0.0001;
    float dx = (fold_collar_delta(q + vec3(e,0.0,0.0),count)
              - fold_collar_delta(q - vec3(e,0.0,0.0),count)) / (2.0*e);
    float dz = (fold_collar_delta(q + vec3(0.0,0.0,e),count)
              - fold_collar_delta(q - vec3(0.0,0.0,e),count)) / (2.0*e);
    dx *= dimensions.z / dimensions.x;
    return normalize(vec3((1.0+dz)*n.x-dx*n.z,(1.0+dz)*n.y,n.z));
}

// Same fixed-knot cubic used by source: one common tangent at each joint.
// It preserves each actual CPU joint and avoids independent-segment jumps.
vec3 fold_chain(vec3 p0,vec3 p1,vec3 p2,vec3 p3,vec3 p4,float u) {
    vec3 a; vec3 b; vec3 ta; vec3 tb; float lo; float hi;
    if (u < 0.18) {
        a=p0; b=p1; ta=(p1-p0)/0.18; tb=(p2-p0)/0.52; lo=0.0; hi=0.18;
    } else if (u < 0.52) {
        a=p1; b=p2; ta=(p2-p0)/0.52; tb=(p3-p1)/0.66; lo=0.18; hi=0.52;
    } else if (u < 0.84) {
        a=p2; b=p3; ta=(p3-p1)/0.66; tb=(p4-p2)/0.48; lo=0.52; hi=0.84;
    } else {
        a=p3; b=p4; ta=(p4-p2)/0.48; tb=(p4-p3)/0.16; lo=0.84; hi=1.0;
    }
    float t=(u-lo)/(hi-lo);
    return (2.0*t*t*t-3.0*t*t+1.0)*a+(t*t*t-2.0*t*t+t)*(hi-lo)*ta
         +(-2.0*t*t*t+3.0*t*t)*b+(t*t*t-t*t)*(hi-lo)*tb;
}
vec3 fold_source_center(int section,int canonical,float u,vec3 d) {
    int base=int(round(blender_joint_base[section]))+canonical*5;
    return fold_chain(blender_pose(base,0,0)*d,blender_pose(base+1,0,0)*d,
        blender_pose(base+2,0,0)*d,blender_pose(base+3,0,0)*d,
        blender_pose(base+4,0,0)*d,u);
}
vec3 fold_target_center(int c,int cpu,float u,vec3 d,vec4 law,float bob) {
    int j=c*8+cpu;
    vec3 root=crab_socket[j].xyz;
    float flank=sign(root.x);
    float amount=abs(law.y-float(cpu))<0.5 ? clamp(law.z,0.0,1.0) : 0.0;
    vec3 foot=crab_foot[j].xyz-vec3(0.0,bob,0.0);
    vec3 coxa=root+vec3(flank*d.x*0.18,d.y*0.08,0.0);
    vec3 knee=crab_knee[j].xyz+vec3(-flank*d.x*0.22,d.y*0.20,d.z*0.12)*amount;
    // Packed joints exclude the common body bob. Preserve the body/root bob
    // while cancelling it at the planted foot; the knee inherits .48.
    knee.y-=bob*0.48;
    vec3 ankle=mix(knee,foot,0.70)+vec3(0.0,d.y*0.08,0.0);
    return fold_chain(root,coxa,knee,ankle,foot,u);
}
vec3 fold_leg_point(vec3 posed,int section,int c,int canonical,int count,
                    float u,vec3 d,vec4 law,float bob) {
    int cpu=fold_cpu_leg(canonical,count);
    if (cpu<0) {
        // Keep the shared root ring; collapse the whole positive branch to it.
        return u>0.0001 ? fold_source_center(section,canonical,0.0,d) : posed;
    }
    return posed+fold_target_center(c,cpu,u,d,law,bob)
                -fold_source_center(section,canonical,u,d);
}
vec3 fold_leg_normal(vec3 n,int section,int c,int canonical,int count,
                    float u,vec3 d,vec4 law,float bob) {
    int cpu=fold_cpu_leg(canonical,count);
    if (cpu<0 || u<0.0001) return n;
    float lo=max(0.0,u-0.0001); float hi=min(1.0,u+0.0001);
    vec3 rest=fold_source_center(section,canonical,hi,d)-fold_source_center(section,canonical,lo,d);
    vec3 dest=fold_target_center(c,cpu,hi,d,law,bob)-fold_target_center(c,cpu,lo,d,law,bob);
    if (abs(rest.x)<0.0000001) return n;
    // Source legs are flank-normal laminated sections. This is the exact
    // inverse-transpose for their axial translation warp, away from collars.
    vec3 delta=(dest-rest)/rest.x;
    return fold_finite_normal(vec3(n.x-delta.y*n.y-delta.z*n.z,
        (1.0+delta.x)*n.y,(1.0+delta.x)*n.z),n);
}

vec3 fold_jaw_chain(vec3 root,vec3 elbow,vec3 tip,float u) {
    float lo=u<0.52?0.0:0.52; float hi=u<0.52?0.52:1.0;
    vec3 a=u<0.52?root:elbow; vec3 b=u<0.52?elbow:tip;
    vec3 ta=u<0.52?(elbow-root)/0.52:(tip-root);
    vec3 tb=u<0.52?(tip-root):(tip-elbow)/0.48;
    float t=(u-lo)/(hi-lo);
    return (2.0*t*t*t-3.0*t*t+1.0)*a+(t*t*t-2.0*t*t+t)*(hi-lo)*ta
         +(-2.0*t*t*t+3.0*t*t)*b+(t*t*t-t*t)*(hi-lo)*tb;
}
vec3 fold_jaw_center(int section,int jaw,float u,vec3 d,float deploy,float time) {
    int base=int(round(blender_manipulator_base[section]))+jaw*3;
    vec3 root=blender_pose(base,0,0)*d;
    vec3 elbow=blender_pose(base+1,0,0)*d+vec3(0.0,-0.08*d.y,0.12*d.z)*deploy;
    vec3 tip=blender_pose(base+2,0,0)*d+vec3(0.0,-0.08*d.y,0.42*d.z)*deploy;
    float flank=jaw==0?-1.0:1.0;
    vec3 p=fold_jaw_chain(root,elbow,tip,u);
    p.x+=sin(time*3.1+flank*1.7)*deploy*d.x*0.018*u;
    return p;
}
// Jaw translation preserves source anatomical cross-section and exact roots.
// The existing examination clock is photo.x; TIME is only its old tiny wave.
vec3 fold_jaw_point(vec3 posed,int section,int jaw,float u,vec3 d,float deploy,float time) {
    return posed+fold_jaw_center(section,jaw,u,d,deploy,time)
                -fold_jaw_center(section,jaw,u,d,0.0,time);
}

// First-order normal correction for the jaw's curving source tube. Unlike
// flank-planar legs, its authored u-gradient is approximated by the rest
// centerline tangent; native normal/collar inspection remains necessary.
vec3 fold_jaw_normal(vec3 n,int section,int jaw,float u,vec3 d,float deploy,float time) {
    if (u<0.0001) return n;
    float lo=max(0.0,u-0.0001); float hi=min(1.0,u+0.0001);
    vec3 rest=(fold_jaw_center(section,jaw,hi,d,0.0,time)
              -fold_jaw_center(section,jaw,lo,d,0.0,time))/(hi-lo);
    vec3 dest=(fold_jaw_center(section,jaw,hi,d,deploy,time)
              -fold_jaw_center(section,jaw,lo,d,deploy,time))/(hi-lo);
    float l2=dot(rest,rest);
    if (l2<0.000000000001) return n;
    vec3 grad=rest/l2; vec3 change=dest-rest;
    vec3 jx=vec3(1.0,0.0,0.0)+change*grad.x;
    vec3 jy=vec3(0.0,1.0,0.0)+change*grad.y;
    vec3 jz=vec3(0.0,0.0,1.0)+change*grad.z;
    return fold_finite_normal(n.x*cross(jy,jz)+n.y*cross(jz,jx)+n.z*cross(jx,jy),n);
}
