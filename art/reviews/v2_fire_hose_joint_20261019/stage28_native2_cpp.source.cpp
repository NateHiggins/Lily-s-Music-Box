#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/godot.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_float64_array.hpp>
#include <godot_cpp/variant/packed_vector3_array.hpp>
#include <algorithm>
#include <cmath>
#include <string>
#include <vector>

using namespace godot;

// Native version of hose_contact_projection.gd. It owns numerical buffers only.
// Geometry, world queries, time, energy, save and mechanical authorities stay
// with their existing owners. Vector3 boundaries retain Godot's single precision.
class OrisonHoseProjectionNative : public RefCounted {
    GDCLASS(OrisonHoseProjectionNative, RefCounted)
    struct Plane { Vector3 normal; double offset; };
    struct Row { int first, last; Vector3 vector; double g; bool equality, plane; };
    using Points = std::vector<Vector3>;
    using Rows = std::vector<Row>;
    using Planes = std::vector<std::vector<Plane>>;
    std::vector<double> lengths, spans, inverse;
    std::string error;
    int iterations = 0, qp_iterations = 0;
    Points last_iterate;
    std::vector<double> dependence;
    static constexpr double ERROR_M = .00002;

    static double dot(const Vector3 &a, const Vector3 &b) {
        return double(a.x)*double(b.x)+double(a.y)*double(b.y)+double(a.z)*double(b.z);
    }
    static Points unpack(const PackedVector3Array &p) {
        if (p.is_empty()) return {};
        return Points(p.ptr(), p.ptr() + p.size());
    }
    static PackedVector3Array pack(const Points &p) {
        PackedVector3Array result; result.resize(p.size());
        if (!p.empty()) std::copy(p.begin(), p.end(), result.ptrw());
        return result;
    }
    Dictionary output(const Points &p) const {
        Dictionary result;
        result["points"]=pack(p); result["error"]=String(error.c_str());
        result["iterations"]=iterations; result["qp_iterations"]=qp_iterations;
        result["last_iterate"]=pack(last_iterate);
        return result;
    }
    bool valid_points(const Points &p) {
        if (p.size()!=inverse.size() || lengths.size()+1!=p.size() || spans.size()+2!=p.size()) {
            error="native material sizes differ"; return false;
        }
        for (const Vector3 &v:p) if (!v.is_finite()) {error="nonfinite native input"; return false;}
        return true;
    }
    bool unpack_planes(const Dictionary &source, int count, Planes &result) {
        result.resize(count);
        Array keys=source.keys();
        for (int k=0;k<keys.size();++k) {
            int i=int64_t(keys[k]);
            if (i<0 || i>=count) {error="native support index outside material";return false;}
            Array rows=source[keys[k]];
            for (int j=0;j<rows.size();++j) {
                Dictionary row=rows[j]; Vector3 n=row["normal"]; double offset=row["offset"];
                if (!n.is_finite() || !std::isfinite(offset) || std::abs(dot(n,n)-1.)>.0001) {
                    error="invalid native support plane";return false;
                }
                result[i].push_back({n,offset});
            }
        }
        return true;
    }
    bool make_rows(const Points &p, const Planes &planes, Rows &rows) {
        rows.reserve(lengths.size()+spans.size()+128);
        for (int i=0;i<int(p.size());++i) {
            if (i<int(lengths.size())) {
                Vector3 d=p[i]-p[i+1]; double distance=d.length();
                if (distance<.0000001) {error="collapsed native length gradient";return false;}
                rows.push_back({i,i+1,d/real_t(distance),distance-lengths[i],true,false});
            }
            if (i<int(spans.size())) {
                Vector3 d=p[i]-p[i+2]; double distance=d.length();
                if (distance<.0000001) {error="collapsed native bend gradient";return false;}
                rows.push_back({i,i+2,d/real_t(distance),distance-spans[i],false,false});
            }
            for (const Plane &plane:planes[i]) rows.push_back({i,-1,plane.normal,dot(plane.normal,p[i])-plane.offset,false,true});
        }
        return true;
    }
    double entry(const Row &a,const Row &b) const {
        double w=0.;
        if (a.first==b.first) w+=inverse[a.first];
        if (a.first==b.last) w-=inverse[a.first];
        if (a.last>=0) {
            if (a.last==b.first) w-=inverse[a.last];
            if (a.last==b.last) w+=inverse[a.last];
        }
        return dot(a.vector,b.vector)*w;
    }
    bool factor(const Rows &rows,const std::vector<int> &ids,std::vector<double> &answer) {
        dependence.clear();
        int n=int(ids.size()), band=0;
        for (int i=0;i<n;++i) for (int j=i-1;j>=0;--j) {
            if (rows[ids[i]].first-rows[ids[j]].first>2) break;
            band=std::max(band,i-j);
        }
        if (band>128) {error="excess native contact bandwidth";return false;}
        int width=band+1;
        std::vector<double> lower(size_t(n)*width,0.),diagonal(n,0.);
        answer.resize(n);
        for (int i=0;i<n;++i) {
            answer[i]=rows[ids[i]].g;
            for (int j=std::max(0,i-band);j<=i;++j) {
                double value=entry(rows[ids[i]],rows[ids[j]]);
                for (int k=std::max(0,i-band);k<j;++k) value-=lower[size_t(i)*width+i-k]*diagonal[k]*lower[size_t(j)*width+j-k];
                if (i==j) {
                    if (!std::isfinite(value) || value<=1e-16) {
                        error="dependent native constraint row "+std::to_string(i);
                        // Recover the row dependency from the partial LDL
                        // factors so an obsolete inequality can leave the
                        // active set. Permanent material lengths never leave it.
                        if (std::isfinite(value)) {
                            dependence.assign(rows.size(),0.);dependence[ids[i]]=1.;
                            std::vector<double> coefficients(i,0.);
                            for (int j=i-1;j>=0;--j) {
                                double c=(i-j<=band)?lower[size_t(i)*width+i-j]:0.;
                                for (int k=j+1;k<std::min(i,j+width);++k) c-=lower[size_t(k)*width+k-j]*coefficients[k];
                                coefficients[j]=c;dependence[ids[j]]=-c;
                            }
                        }
                        return false;
                    }
                    diagonal[i]=value;
                } else lower[size_t(i)*width+i-j]=value/diagonal[j];
            }
            for (int j=std::max(0,i-band);j<i;++j) answer[i]-=lower[size_t(i)*width+i-j]*answer[j];
        }
        for (int i=0;i<n;++i) answer[i]/=diagonal[i];
        for (int i=n-1;i>=0;--i) {
            for (int j=i+1;j<std::min(n,i+width);++j) answer[i]-=lower[size_t(j)*width+j-i]*answer[j];
            if (!std::isfinite(answer[i])) {error="nonfinite native multiplier";return false;}
        }
        return true;
    }
    static double gradient(const Row &row,const Points &values) {
        Vector3 d=values[row.first]; if (row.last>=0) d-=values[row.last];
        return dot(row.vector,d);
    }
    bool linear(const Rows &rows,int count,Points &delta) {
        std::vector<unsigned char> active(rows.size(),0);
        std::vector<double> previous(rows.size(),0.);
        bool robust=false;int last_added=-1;
        for (int iteration=0;iteration<512;++iteration) {
            if (iteration==64 && !robust) {robust=true;std::fill(active.begin(),active.end(),0);last_added=-1;}
            ++qp_iterations;
            std::vector<int> ids;ids.reserve(rows.size());
            for (int i=0;i<int(rows.size());++i) if (rows[i].equality || active[i]) ids.push_back(i);
            std::vector<double> multipliers;
            if (!factor(rows,ids,multipliers)) {
                if (!dependence.empty() && !robust) {
                    robust=true;std::fill(active.begin(),active.end(),0);last_added=-1;error.clear();continue;
                }
                if (robust && last_added>=0 && !dependence.empty() && std::abs(dependence[last_added])>1e-12) {
                    int remove=-1;double smallest=INFINITY;
                    for (int id:ids) {
                        if (id==last_added || rows[id].equality) continue;
                        double coefficient=-dependence[id]/dependence[last_added];
                        if (coefficient<=1e-10) continue;
                        double ratio=std::max(0.,-previous[id])/coefficient;
                        if (ratio<smallest) {smallest=ratio;remove=id;}
                    }
                    if (remove>=0) {active[remove]=0;error.clear();continue;}
                }
                return false;
            }
            delta.assign(count,Vector3());
            for (int i=0;i<int(ids.size());++i) {
                const Row &row=rows[ids[i]];
                delta[row.first]-=row.vector*real_t(inverse[row.first]*multipliers[i]);
                if (row.last>=0) delta[row.last]+=row.vector*real_t(inverse[row.last]*multipliers[i]);
            }
            int remove=-1;double largest=.0000000001;
            for (int i=0;i<int(ids.size());++i) if (!rows[ids[i]].equality && multipliers[i]>largest) {largest=multipliers[i];remove=ids[i];}
            if (robust && remove>=0) {active[remove]=0;last_added=-1;continue;}
            bool added=false;int worst=-1;double violation=-.000000001;
            for (int i=0;i<int(rows.size());++i) if (!rows[i].equality && !active[i]) {
                double value=rows[i].g+gradient(rows[i],delta);
                if (robust) {if (value<violation) {violation=value;worst=i;}}
                else if (value<-.000000001) {active[i]=1;added=true;}
            }
            if (robust && worst>=0) {
                std::fill(previous.begin(),previous.end(),0.);
                for (int i=0;i<int(ids.size());++i) previous[ids[i]]=multipliers[i];
                active[worst]=1;last_added=worst;continue;
            }
            if (added) continue;
            if (remove>=0) {active[remove]=0;last_added=-1;continue;}
            return true;
        }
        error="native active-set iteration ceiling";return false;
    }
    static bool acceptable(const Rows &rows) {
        double maximum=0.,total=0.,bend=0.,plane=0.;
        for (const Row &r:rows) {
            if (r.equality) {maximum=std::max(maximum,std::abs(r.g));total+=r.g;}
            else if (r.plane) plane=std::max(plane,-r.g);
            else bend=std::max(bend,-r.g);
        }
        return maximum<=ERROR_M && std::abs(total)<=ERROR_M && bend<=ERROR_M && plane<=.000001;
    }
protected:
    static void _bind_methods() {
        ClassDB::bind_method(D_METHOD("configure","lengths","spans","inverse"),&OrisonHoseProjectionNative::configure);
        ClassDB::bind_method(D_METHOD("project","seed","anchor","planes"),&OrisonHoseProjectionNative::project);
        ClassDB::bind_method(D_METHOD("project_velocity","points","velocity","planes"),&OrisonHoseProjectionNative::project_velocity);
    }
public:
    bool configure(const PackedFloat64Array &l,const PackedFloat64Array &b,const PackedFloat64Array &w) {
        if (l.size()<2 || w.size()!=l.size()+1 || b.size()+1!=l.size()) return false;
        for (int i=0;i<l.size();++i) if (!std::isfinite(l[i]) || l[i]<=0.) return false;
        for (int i=0;i<b.size();++i) if (!std::isfinite(b[i]) || b[i]<=0.) return false;
        for (int i=0;i<w.size();++i) if (!std::isfinite(w[i]) || (i+1<w.size()?w[i]<=0.:w[i]!=0.)) return false;
        lengths.assign(l.ptr(),l.ptr()+l.size());spans.assign(b.ptr(),b.ptr()+b.size());inverse.assign(w.ptr(),w.ptr()+w.size());
        return inverse.size()==lengths.size()+1 && spans.size()+1==lengths.size();
    }
    Dictionary project(const PackedVector3Array &seed,const Vector3 &anchor,const Dictionary &support) {
        error.clear();iterations=0;qp_iterations=0;Points points=unpack(seed);last_iterate=points;
        if (!valid_points(points)) return output({});
        if (!anchor.is_finite()) {error="nonfinite native anchor";return output({});}
        Planes planes;if (!unpack_planes(support,int(points.size()),planes)) return output({});
        points.back()=anchor;
        for (int iteration=0;iteration<64;++iteration) {
            iterations=iteration+1;Rows rows;
            if (!make_rows(points,planes,rows)) return output({});
            if (acceptable(rows)) return output(points);
            Points delta;if (!linear(rows,int(points.size()),delta)) {last_iterate=points;return output({});}
            for (int i=0;i<int(points.size());++i) points[i]+=delta[i];
            points.back()=anchor;last_iterate=points;
        }
        Rows rows;if (make_rows(points,planes,rows) && acceptable(rows)) return output(points);
        error="native nonlinear projection ceiling";return output({});
    }
    Dictionary project_velocity(const PackedVector3Array &input,const PackedVector3Array &velocity,const Dictionary &support) {
        error.clear();iterations=0;qp_iterations=0;Points points=unpack(input),speed=unpack(velocity);last_iterate=points;
        if (!valid_points(points) || speed.size()!=points.size()) {error="native velocity sizes differ";return output({});}
        for (const Vector3 &v:speed) if (!v.is_finite()) {error="nonfinite native velocity";return output({});}
        Planes planes;if (!unpack_planes(support,int(points.size()),planes)) return output({});
        Rows all,selected;if (!make_rows(points,planes,all)) return output({});
        for (Row row:all) {
            if (!row.equality && row.g>(row.plane?.000001:ERROR_M)) continue;
            row.g=gradient(row,speed);selected.push_back(row);
        }
        Points delta;if (!linear(selected,int(points.size()),delta)) return output({});
        for (int i=0;i<int(speed.size());++i) speed[i]+=delta[i];
        speed.back()=Vector3();return output(speed);
    }
};

void initialize_hose_math(ModuleInitializationLevel level) {
    if (level==MODULE_INITIALIZATION_LEVEL_SCENE) GDREGISTER_CLASS(OrisonHoseProjectionNative);
}
void uninitialize_hose_math(ModuleInitializationLevel) {}
extern "C" GDExtensionBool GDE_EXPORT orison_hose_math_init(GDExtensionInterfaceGetProcAddress address,GDExtensionClassLibraryPtr library,GDExtensionInitialization *initialization) {
    GDExtensionBinding::InitObject object(address,library,initialization);
    object.register_initializer(initialize_hose_math);object.register_terminator(uninitialize_hose_math);
    object.set_minimum_library_initialization_level(MODULE_INITIALIZATION_LEVEL_SCENE);
    return object.init();
}
