#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/godot.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_float64_array.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
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
    bool pinned_mode=false;
    bool held_projection=false;
    double bend_error_m=.00002;
    std::string error;
    int iterations = 0, qp_iterations = 0;
    Points last_iterate;
    std::vector<double> dependence;
    std::vector<unsigned char> active_hint;
    static constexpr double ERROR_M = .00002;
    // The saved tightly curved floor case needs ~384 nonlinear iterations
    // to satisfy the separate accumulated-length bound, even after its
    // largest interval residual is small. Easy cases still return early.
    static constexpr int POSITION_ITERATIONS = 512;

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
                double residual=distance-lengths[i];
                if (pinned_mode && inverse[i]==0. && inverse[i+1]==0.) {
                    if (std::abs(residual)>ERROR_M) {error="incompatible fixed material interval";return false;}
                } else rows.push_back({i,i+1,d/real_t(distance),residual,true,false});
            }
            if (i<int(spans.size())) {
                Vector3 d=p[i]-p[i+2]; double distance=d.length();
                if (distance<.0000001) {error="collapsed native bend gradient";return false;}
                double residual=distance-spans[i];
                if (pinned_mode && inverse[i]==0. && inverse[i+2]==0.) {
                    if (residual<-bend_error_m) {error="incompatible fixed bend span";return false;}
                } else rows.push_back({i,i+2,d/real_t(distance),residual,false,false});
            }
            for (const Plane &plane:planes[i]) {
                double residual=dot(plane.normal,p[i])-plane.offset;
                if (pinned_mode && inverse[i]==0.) {
                    if (residual<-.000001) {error="incompatible fixed support";return false;}
                } else rows.push_back({i,-1,plane.normal,residual,false,true});
            }
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
        if (pinned_mode && active_hint.size()==rows.size()) active=active_hint;
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
            if (pinned_mode) active_hint=active;
            return true;
        }
        error="native active-set iteration ceiling";return false;
    }
    bool acceptable(const Rows &rows) const {
        double maximum=0.,total=0.,bend=0.,plane=0.;
        for (const Row &r:rows) {
            if (r.equality) {maximum=std::max(maximum,std::abs(r.g));total+=r.g;}
            else if (r.plane) plane=std::max(plane,-r.g);
            else bend=std::max(bend,-r.g);
        }
        return maximum<=ERROR_M && std::abs(total)<=ERROR_M && bend<=bend_error_m && plane<=.000001;
    }
    static double merit(const Rows &rows) {
        double value=0.;
        for (const Row &r:rows) value+=r.equality?std::abs(r.g):std::max(0.,-r.g);
        return value;
    }
    // Line-search trials need scalar residuals, not thousands of gradient
    // rows. Preserve make_rows()/merit()/acceptable() traversal and arithmetic
    // while avoiding row allocation, normalization and storage for each trial.
    bool assess(const Points &points,const Planes &planes,double &trial_merit,bool &accepted) {
        double maximum=0.,total=0.,bend=0.,plane_error=0.;trial_merit=0.;
        for (int i=0;i<int(points.size());++i) {
            if (i<int(lengths.size())) {
                double distance=(points[i]-points[i+1]).length();
                if (distance<.0000001) {error="collapsed native length gradient";return false;}
                double g=distance-lengths[i];maximum=std::max(maximum,std::abs(g));total+=g;trial_merit+=std::abs(g);
            }
            if (i<int(spans.size())) {
                double distance=(points[i]-points[i+2]).length();
                if (distance<.0000001) {error="collapsed native bend gradient";return false;}
                double g=distance-spans[i];bend=std::max(bend,-g);trial_merit+=std::max(0.,-g);
            }
            for (const Plane &p:planes[i]) {
                double g=dot(p.normal,points[i])-p.offset;plane_error=std::max(plane_error,-g);trial_merit+=std::max(0.,-g);
            }
        }
        accepted=maximum<=ERROR_M && std::abs(total)<=ERROR_M && bend<=bend_error_m && plane_error<=.000001;
        return true;
    }

    // Closest direction on the unit sphere inside a set of spherical caps.
    // At an optimum either the preferred direction, one cap circle, or two
    // cap boundaries are active. Enumerating those candidates is bounded by
    // the local contact count rather than the full strand's matrix dimension.
    static bool cap_direction(const Vector3 &preferred,const Vector3 &continuation,const std::vector<Plane> &caps,Vector3 &answer) {
        double best=-2.,smoothest=-2.;bool found=false;
        auto consider=[&](Vector3 candidate) {
            if (!candidate.is_finite() || candidate.length_squared()<1e-14) return;
            candidate.normalize();
            for (const Plane &cap:caps) if (dot(cap.normal,candidate)<cap.offset-2e-7) return;
            double score=dot(preferred,candidate);
            double smooth=dot(continuation,candidate);
            if (!found || score>best+1e-6 || (std::abs(score-best)<=1e-6 && smooth>smoothest)) {found=true;best=score;smoothest=smooth;answer=candidate;}
        };
        consider(preferred);
        if (found) return true;
        for (const Plane &cap:caps) {
            Vector3 tangent=preferred-cap.normal*real_t(dot(preferred,cap.normal));
            if (tangent.length_squared()<1e-14) {
                Vector3 axis=std::abs(cap.normal.x)<.7?Vector3(1,0,0):Vector3(0,1,0);
                tangent=axis-cap.normal*real_t(dot(axis,cap.normal));
            }
            tangent.normalize();
            real_t radius=real_t(std::sqrt(std::max(0.,1.-cap.offset*cap.offset)));
            consider(cap.normal*real_t(cap.offset)+tangent*radius);
            consider(cap.normal*real_t(cap.offset)-tangent*radius);
            // A preferred direction normal to a contact face has no unique
            // nearest tangent. Include the other local constraints' in-plane
            // directions before using a sphere-circle intersection that can
            // introduce an unnecessary out-of-plane fold.
            for (const Plane &other:caps) {
                Vector3 aligned=other.normal-cap.normal*real_t(dot(other.normal,cap.normal));
                if (aligned.length_squared()<1e-14) continue;
                aligned.normalize();
                consider(cap.normal*real_t(cap.offset)+aligned*radius);
                consider(cap.normal*real_t(cap.offset)-aligned*radius);
            }
        }
        for (int i=0;i<int(caps.size());++i) for (int j=i+1;j<int(caps.size());++j) {
            const Plane &a=caps[i],&b=caps[j];double cosine=dot(a.normal,b.normal),det=1.-cosine*cosine;
            if (det<1e-12) continue;
            Vector3 center=a.normal*real_t((a.offset-cosine*b.offset)/det)+b.normal*real_t((b.offset-cosine*a.offset)/det);
            double radius2=1.-dot(center,center);
            if (radius2<-2e-7) continue;
            Vector3 direction=a.normal.cross(b.normal).normalized();real_t radius=real_t(std::sqrt(std::max(0.,radius2)));
            consider(center+direction*radius);consider(center-direction*radius);
        }
        return found;
    }
    bool follow_support(Points &points,const Planes &planes,const std::vector<bool> &fixed) {
        for (int i=0;i<int(points.size());++i) {
            for (int pass=0;pass<8;++pass) for (const Plane &plane:planes[i]) {
                double residual=plane.offset-dot(plane.normal,points[i]);
                if (fixed[i]) {
                    if (residual>.000001) {error="incompatible fixed follower support";return false;}
                } else if (residual>0.) points[i]+=plane.normal*real_t(residual/dot(plane.normal,plane.normal));
            }
            for (const Plane &plane:planes[i]) if (plane.offset-dot(plane.normal,points[i])>.000001) {error="incompatible follower support planes";return false;}
        }
        return true;
    }
    bool follow_sweep(Points &points,const Points &hints,const Planes &planes,const std::vector<bool> &fixed,int step) {
        int count=int(points.size()),start=step<0?count-2:1,end=step<0?-1:count;
        for (int i=start;i!=end;i+=step) {
            if (fixed[i]) continue;
            int parent=i-step,length_index=std::min(i,parent);double length=lengths[length_index];
            Vector3 center=points[parent],preferred=points[i]-center;
            if (preferred.length_squared()<1e-14) preferred=hints[i]-hints[parent];
            if (preferred.length_squared()<1e-14) preferred=Vector3(1,0,0);
            preferred.normalize();std::vector<Plane> caps;caps.reserve(planes[i].size()+1);
            auto add_cap=[&](Vector3 normal,double threshold) {
                double magnitude=std::sqrt(dot(normal,normal));
                if (!std::isfinite(magnitude) || magnitude<1e-10 || !std::isfinite(threshold)) return false;
                normal/=real_t(magnitude);threshold/=magnitude;
                if (threshold>1.+1e-8) return false;
                if (threshold>-1.) caps.push_back({normal,std::min(1.,threshold)});
                return true;
            };
            for (const Plane &plane:planes[i]) {
                if (!add_cap(plane.normal,(plane.offset-dot(plane.normal,center))/length)) {error="infeasible follower support sphere";return false;}
            }
            int previous=i-2*step;
            if (previous>=0 && previous<count) {
                Vector3 span=center-points[previous];double span2=dot(span,span),minimum=spans[std::min(i,previous)];
                // |center + length*u - previous| must retain the native
                // minimum bend span. The moving neighbor's actual position
                // supplies this cap, including at a pinned end.
                double threshold=(minimum*minimum-length*length-span2)/(2.*length);
                if (!add_cap(span,threshold)) {error="infeasible follower bend sphere";return false;}
            }
            Vector3 direction;
            Vector3 continuation=preferred;
            if (previous>=0 && previous<count) continuation=(center-points[previous]).normalized();
            if (!cap_direction(preferred,continuation,caps,direction)) {error="incompatible follower caps";return false;}
            points[i]=center+direction*real_t(length);
        }
        return true;
    }

    bool follow_relax(Points &points,const Points &hints,const Planes &planes,const std::vector<bool> &fixed) {
        auto pair=[&](int a,int b,double desired,bool minimum) {
            Vector3 d=points[a]-points[b];double distance=d.length();
            if (minimum && distance>=desired) return true;
            double wa=fixed[a]?0.:inverse[a],wb=fixed[b]?0.:inverse[b],mobility=wa+wb;
            if (mobility==0.) return std::abs(distance-desired)<=ERROR_M;
            if (distance<1e-10) {
                d=hints[a]-hints[b];
                if (d.length_squared()<1e-14) d=Vector3(1,0,0);
                d.normalize();
            } else d/=real_t(distance);
            Vector3 correction=d*real_t((distance-desired)/mobility);
            points[a]-=correction*real_t(wa);points[b]+=correction*real_t(wb);
            return true;
        };
        for (int pass=0;pass<512;++pass) {
            ++iterations;
            if (!follow_support(points,planes,fixed)) return false;
            for (int i=0;i<int(lengths.size());++i) if (!pair(i,i+1,lengths[i],false)) return false;
            for (int i=int(lengths.size())-1;i>=0;--i) if (!pair(i,i+1,lengths[i],false)) return false;
            for (int i=0;i<int(spans.size());++i) if (!pair(i,i+2,spans[i],true)) return false;
            if (pass%8!=7) continue;
            if (!follow_support(points,planes,fixed)) return false;
            double value=0.;bool accepted=false;
            if (assess(points,planes,value,accepted) && accepted) return true;
            // Local relaxation finds a feasible bending neighborhood; a
            // copied directional pass can then restore all exact lengths.
            // Failed polishing never destroys the relaxed candidate.
            Points trial=points;
            if (follow_sweep(trial,hints,planes,fixed,-1) && assess(trial,planes,value,accepted) && accepted) {points=std::move(trial);return true;}
        }
        return false;
    }

    bool polish_total_roundoff(Points &points,const Planes &planes) {
        // Float32 coordinates can make all individual Newton corrections
        // sub-ulp while their signed length residuals accumulate. Adjust a
        // free curved ring by a few micrometres, then check every ORIGINAL
        // interval, aggregate, bend and support bound. Fixed fittings cannot
        // move. No tolerance or material target is changed.
        double total=0.,maximum=0.;
        for (int i=0;i<int(lengths.size());++i) {
            double residual=(points[i]-points[i+1]).length()-lengths[i];
            maximum=std::max(maximum,std::abs(residual));total+=residual;
        }
        if (maximum>ERROR_M || std::abs(total)<=ERROR_M || std::abs(total)>.0001) return false;
        std::vector<std::pair<double,int>> candidates;
        for (int i=1;i+1<int(points.size());++i) if (inverse[i]>0.) {
            Vector3 gradient=(points[i]-points[i-1]).normalized()+(points[i]-points[i+1]).normalized();
            candidates.push_back({dot(gradient,gradient),i});
        }
        std::sort(candidates.rbegin(),candidates.rend());
        int count=std::min(16,int(candidates.size()));
        for (int k=0;k<count;++k) {
            if (candidates[k].first<1e-6) continue;
            int i=candidates[k].second;
            Vector3 gradient=(points[i]-points[i-1]).normalized()+(points[i]-points[i+1]).normalized();
            Vector3 displacement=gradient*real_t(-total/candidates[k].first);
            for (double fraction=1.;fraction>=1./128.;fraction*=.5) {
                if (displacement.length()*fraction>ERROR_M*2.) continue;
                Points trial=points;trial[i]+=displacement*real_t(fraction);
                double value=0.;bool accepted=false;
                if (assess(trial,planes,value,accepted) && accepted) {points=std::move(trial);return true;}
            }
        }
        return false;
    }

    struct WidePoint {
        double x,y,z;
        WidePoint(const Vector3 &v):x(v.x),y(v.y),z(v.z) {}
        WidePoint(double a,double b,double c):x(a),y(b),z(c) {}
        WidePoint operator-(const WidePoint &v) const {return {x-v.x,y-v.y,z-v.z};}
        double length() const {return std::sqrt(x*x+y*y+z*z);}
        Vector3 narrow() const {return Vector3(real_t(x),real_t(y),real_t(z));}
    };
    using WidePoints=std::vector<WidePoint>;
    static Points narrow(const WidePoints &points) {
        Points result;result.reserve(points.size());for (const WidePoint &p:points) result.push_back(p.narrow());return result;
    }
    bool wide_rows(const WidePoints &p,const Planes &planes,Rows &rows) {
        for (int i=0;i<int(p.size());++i) {
            if (i<int(lengths.size())) {
                WidePoint d=p[i]-p[i+1];double distance=d.length();
                if (distance<1e-7) {error="collapsed wide material gradient";return false;}
                double residual=distance-lengths[i];
                if (inverse[i]==0. && inverse[i+1]==0.) {
                    if (std::abs(residual)>ERROR_M) {error="incompatible fixed wide interval";return false;}
                } else rows.push_back({i,i+1,Vector3(real_t(d.x/distance),real_t(d.y/distance),real_t(d.z/distance)),residual,true,false});
            }
            if (i<int(spans.size())) {
                WidePoint d=p[i]-p[i+2];double distance=d.length();
                if (distance<1e-7) {error="collapsed wide bend gradient";return false;}
                double residual=distance-spans[i];
                if (inverse[i]==0. && inverse[i+2]==0.) {
                    if (residual<-bend_error_m) {error="incompatible fixed wide bend";return false;}
                } else rows.push_back({i,i+2,Vector3(real_t(d.x/distance),real_t(d.y/distance),real_t(d.z/distance)),residual,false,false});
            }
            for (const Plane &plane:planes[i]) {
                double residual=plane.normal.x*p[i].x+plane.normal.y*p[i].y+plane.normal.z*p[i].z-plane.offset;
                if (inverse[i]==0.) {
                    if (residual<-1e-6) {error="incompatible fixed wide support";return false;}
                } else rows.push_back({i,-1,plane.normal,residual,false,true});
            }
        }
        return true;
    }
    bool wide_assess(const WidePoints &p,const Planes &planes,double &value,bool &accepted) {
        double maximum=0.,total=0.,bend=0.,support=0.;value=0.;
        for (int i=0;i<int(p.size());++i) {
            if (i<int(lengths.size())) {
                double distance=(p[i]-p[i+1]).length();if (distance<1e-7) return false;
                double residual=distance-lengths[i];maximum=std::max(maximum,std::abs(residual));total+=residual;value+=std::abs(residual);
            }
            if (i<int(spans.size())) {
                double distance=(p[i]-p[i+2]).length();if (distance<1e-7) return false;
                double residual=distance-spans[i];bend=std::max(bend,-residual);value+=std::max(0.,-residual);
            }
            for (const Plane &plane:planes[i]) {
                double residual=plane.normal.x*p[i].x+plane.normal.y*p[i].y+plane.normal.z*p[i].z-plane.offset;
                support=std::max(support,-residual);value+=std::max(0.,-residual);
            }
        }
        accepted=maximum<=ERROR_M && std::abs(total)<=ERROR_M && bend<=bend_error_m && support<=1e-6;
        return true;
    }
    Dictionary project_wide(const Points &seed,const Vector3 &anchor,const Planes &planes) {
        // Extra pinned fittings require sub-ulp intermediate corrections at
        // fifteen-metre coordinates. Keep only the opt-in working positions
        // in Float64; the engine boundary and FINAL checks remain Float32.
        // The legacy single-anchor reference path is unchanged.
        WidePoints points;points.reserve(seed.size());for (const Vector3 &p:seed) points.emplace_back(p);
        points.back()=WidePoint(anchor);
        auto final_result=[&]() {
            Points candidate=narrow(points);double value=0.;bool accepted=false;
            if ((assess(candidate,planes,value,accepted) && accepted) || polish_total_roundoff(candidate,planes)) {
                error.clear();last_iterate=candidate;return output(candidate);
            }
            error="wide result exceeds original engine material bounds";last_iterate=candidate;return output({});
        };
        int limit=held_projection?64:POSITION_ITERATIONS;
        for (int pass=0;pass<limit;++pass) {
            iterations=pass+1;double old_merit=0.;bool accepted=false;
            if (!wide_assess(points,planes,old_merit,accepted)) {error="collapsed wide input";last_iterate=narrow(points);return output({});}
            if (accepted) return final_result();
            Rows rows;if (!wide_rows(points,planes,rows)) {last_iterate=narrow(points);return output({});}
            Points delta;if (!linear(rows,int(points.size()),delta)) {last_iterate=narrow(points);return output({});}
            bool advanced=false;
            for (double fraction=1.;fraction>=1./4096.;fraction*=.5) {
                WidePoints trial=points;
                for (int i=0;i<int(points.size());++i) {
                    trial[i].x+=double(delta[i].x)*fraction;trial[i].y+=double(delta[i].y)*fraction;trial[i].z+=double(delta[i].z)*fraction;
                }
                trial.back()=WidePoint(anchor);double value=0.;bool valid=false;
                if (wide_assess(trial,planes,value,valid) && (valid || value<=old_merit*(1.-.01*fraction))) {points=std::move(trial);advanced=true;break;}
            }
            if (!advanced) {error="wide nonlinear line search stalled";last_iterate=narrow(points);return output({});}
        }
        error="wide nonlinear projection ceiling";last_iterate=narrow(points);return output({});
    }

    bool local_body_arc(Points &guide,const Points &hints,int first,int last,double stock) {
        Vector3 a=guide[first],b=guide[last],axis=b-a;double distance=axis.length();
        if (distance<stock*.95 || distance>=stock || last-first<4) return false;
        axis/=real_t(distance);std::vector<double> arc(last-first+1,0.);
        for (int i=first+1;i<=last;++i) arc[i-first]=arc[i-first-1]+lengths[i-1];
        Vector3 normal;double weight=0.,center=0.;
        for (int i=first+1;i<last;++i) {
            double t=arc[i-first]/stock;Vector3 deviation=hints[i]-a-axis*real_t(distance*t);
            deviation-=axis*real_t(dot(axis,deviation));double w=dot(deviation,deviation);
            center+=w*t;weight+=w;normal+=deviation*real_t(t*(1.-t));
        }
        if (normal.length_squared()<1e-12) normal=Vector3(0,-1,0)-axis*axis.y;
        if (normal.length_squared()<1e-12) normal=Vector3(0,0,1)-axis*axis.z;
        normal.normalize();
        double width=std::min(.35,2./distance),middle=weight>1e-12?center/weight:.5;
        middle=std::clamp(middle,width*.5,1.-width*.5);double start=middle-width*.5;
        auto curve=[&](double t,double amplitude) {
            double u=(t-start)/width,height=u>0. && u<1.?16.*amplitude*u*u*(1.-u)*(1.-u):0.;
            return a+axis*real_t(distance*t)+normal*real_t(height);
        };
        constexpr int SAMPLES=1024;Points samples(SAMPLES+1,Vector3());std::vector<double> prefix(SAMPLES+1,0.);
        Points best=guide;double best_error=INFINITY,low=0.,high=stock;
        for (int pass=0;pass<40;++pass) {
            double amplitude=(low+high)*.5;prefix[0]=0.;samples[0]=a;
            for (int j=1;j<=SAMPLES;++j) {samples[j]=curve(double(j)/SAMPLES,amplitude);prefix[j]=prefix[j-1]+samples[j].distance_to(samples[j-1]);}
            Points trial=guide;int segment=1;
            for (int i=first+1;i<last;++i) {
                double target=arc[i-first]/stock*prefix.back();
                while (segment<SAMPLES && prefix[segment]<target) ++segment;
                double fraction=(target-prefix[segment-1])/(prefix[segment]-prefix[segment-1]);
                trial[i]=curve((double(segment-1)+fraction)/SAMPLES,amplitude);
            }
            double actual=0.;for (int i=first;i<last;++i) actual+=trial[i].distance_to(trial[i+1]);
            double error=std::abs(actual-stock);if (error<best_error) {best_error=error;best=std::move(trial);}
            if (actual<stock) low=amplitude;else high=amplitude;
        }
        if (best_error>ERROR_M) return false;
        // Initial guess only: retain the round exit fillets and place spare
        // material in the existing slack region. Fine constraints and swept
        // native-world contact remain the only acceptance path.
        guide=std::move(best);return true;
    }

    bool fillet_held_hint(Points &points,const Points &hints,const std::vector<bool> &fixed) {
        int count=int(points.size()),left=0,right=count-1;
        while (left+1<count && fixed[left+1]) ++left;
        while (right>0 && fixed[right-1]) --right;
        if (left<2 || right>count-3 || right-left<8) return false;
        double stock=0.;for (int i=left;i<right;++i) stock+=lengths[i];
        Vector3 axis=points[right]-points[left];
        if (axis.length()<stock*.65) return false;
        axis.normalize();Points guide=hints;
        auto turn=[&](Vector3 from,const Vector3 &to,double maximum) {
            double angle=std::acos(std::clamp(dot(from,to),-1.,1.));
            if (angle<1e-6) return to;
            Vector3 normal=from.cross(to);
            if (normal.length_squared()<1e-12) normal=from.cross(std::abs(from.z)<.7?Vector3(0,0,1):Vector3(1,0,0));
            return from.rotated(normal.normalized(),real_t(std::min(angle,maximum))).normalized();
        };
        auto allowance=[&](int first,int middle,int last) {
            int span=std::min(first,last);double a=lengths[std::min(first,middle)],b=lengths[std::min(middle,last)];
            double cosine=(spans[span]*spans[span]-a*a-b*b)/(2.*a*b);
            return .75*std::acos(std::clamp(cosine,-1.,1.));
        };
        Vector3 direction=(guide[left]-guide[left-1]).normalized();int steps=0;
        while (dot(direction,axis)<.999999 && left+2<right && steps++<64) {
            double angle=allowance(left-1,left,left+1);if (angle<1e-7) return false;
            direction=turn(direction,axis,angle);guide[left+1]=guide[left]+direction*real_t(lengths[left]);++left;
        }
        if (dot(direction,axis)<.999999) return false;
        direction=(guide[right]-guide[right+1]).normalized();steps=0;
        while (dot(direction,-axis)<.999999 && left+2<right && steps++<64) {
            double angle=allowance(right+1,right,right-1);if (angle<1e-7) return false;
            direction=turn(direction,-axis,angle);guide[right-1]=guide[right]+direction*real_t(lengths[right-1]);--right;
        }
        if (dot(direction,-axis)<.999999) return false;
        Vector3 first_offset=guide[left]-hints[left],last_offset=guide[right]-hints[right];
        double free_stock=0.;for (int i=left;i<right;++i) free_stock+=lengths[i];
        double arc=0.;
        for (int i=left+1;i<right;++i) {
            arc+=lengths[i-1];guide[i]=hints[i]+first_offset.lerp(last_offset,real_t(arc/free_stock));
        }
        local_body_arc(guide,hints,left,right,free_stock);
        // A local initial guess, not a new constraint or accepted movement.
        points=std::move(guide);return true;
    }

    bool bow_held_hint(Points &points,const Points &hints,const std::vector<bool> &fixed) {
        int count=int(points.size()),first=0,last=count-1;
        while (first+1<count && fixed[first+1]) ++first;
        while (last>0 && fixed[last-1]) --last;
        if (first<2 || last>count-3 || last-first<4) return false;
        for (int i=first+1;i<last;++i) if (fixed[i]) return false;
        double stock=0.;for (int i=first;i<last;++i) stock+=lengths[i];
        Vector3 a=points[first],b=points[last],axis=b-a;double distance=axis.length();
        if (distance<stock*.95 || distance>=stock || distance<1e-6) return false;
        axis/=real_t(distance);
        if (axis.dot((points[first]-points[first-1]).normalized())<.9) return false;
        Vector3 normal;double arc=0.;
        for (int i=first+1;i<last;++i) {
            arc+=lengths[i-1];real_t t=real_t(arc/stock);
            Vector3 offset=hints[i]-a-axis*real_t(distance*t);offset-=axis*axis.dot(offset);
            normal+=offset*(t*(1.-t));
        }
        if (normal.length_squared()<1e-12) normal=Vector3(0,-1,0)-axis*axis.dot(Vector3(0,-1,0));
        if (normal.length_squared()<1e-12) normal=Vector3(0,0,1)-axis*axis.dot(Vector3(0,0,1));
        normal.normalize();
        Vector3 boundary=(points[first]-points[first-1]).normalized()-(points[last+1]-points[last]).normalized();
        boundary-=axis*axis.dot(boundary);
        if (boundary.length_squared()>1e-12) {
            boundary.normalize();
            if (normal.dot(boundary)<0.) normal=-normal;
            if (normal.dot(boundary)<.5) normal=boundary;
        }
        auto integral=[&](double u,double c) {
            return .5*(u*std::sqrt(distance*distance+c*c*u*u)+distance*distance/c*std::asinh(c*u/distance));
        };
        double low=0.,high=stock;
        for (int pass=0;pass<40;++pass) {
            double amplitude=(low+high)*.5,c=4.*amplitude;
            if (integral(1.,c)<stock) low=amplitude;else high=amplitude;
        }
        double amplitude=(low+high)*.5,c=4.*amplitude,total=integral(1.,c);arc=0.;
        // A smooth material-arc guess removes the last nearly-collinear fold
        // branch. It is neither an accepted pose nor a collision exemption:
        // all original fine rows and the owner's native sweeps still gate it.
        for (int i=first+1;i<last;++i) {
            arc+=lengths[i-1];double t=arc/stock;
            for (int pass=0;pass<8;++pass) {
                double u=1.-2.*t,current=(total-integral(u,c))*.5;
                double derivative=std::sqrt(distance*distance+c*c*u*u);
                t=std::clamp(t-(current-arc)/derivative,0.,1.);
            }
            points[i]=a+axis*real_t(distance*t)+normal*real_t(4.*amplitude*t*(1.-t));
        }
        return true;
    }

    struct WarmRow { int first,last; Vector3 vector; double rhs; };
    bool warm_support(Points &points,const Vector3 &anchor,const Planes &planes) {
        for (int i=0;i<int(points.size());++i) {
            if (i+1==int(points.size())) {
                for (const Plane &p:planes[i]) if (double(p.normal.dot(anchor))<p.offset-.000001) {error="incompatible support constraints";return false;}
                continue;
            }
            for (int pass=0;pass<8;++pass) for (const Plane &p:planes[i]) {
                double distance=p.offset-double(p.normal.dot(points[i]));
                if (distance>0.) points[i]+=p.normal*real_t(distance);
            }
            for (const Plane &p:planes[i]) if (double(p.normal.dot(points[i]))<p.offset-.000001) {error="incompatible support constraints";return false;}
        }
        points.back()=anchor;return true;
    }
    double warm_bend_error(const Points &points) const {
        double value=0.;
        for (int i=1;i+1<int(points.size());++i) value=std::max(value,spans[i-1]-double(points[i+1].distance_to(points[i-1])));
        return value;
    }
    Vector3 warm_weight(const Vector3 &value,int i) const {
        // Match the reference's diagonal Float32 Basis, not a Float64
        // redistribution that would silently choose a different trajectory.
        return value*real_t(inverse[i]);
    }
    bool warm_tridiagonal(const Points &points,const std::vector<double> &rhs,Points &corrections) {
        int n=int(lengths.size());std::vector<double> diagonal(n),off(n-1),answer=rhs;
        for (int i=0;i<n;++i) {
            Vector3 d=points[i]-points[i+1];
            diagonal[i]=d.dot(warm_weight(d,i)+warm_weight(d,i+1));
            if (i+1<n) off[i]=-double(d.dot(warm_weight(points[i+1]-points[i+2],i+1)));
            if (diagonal[i]<1e-18) {
                if (std::abs(rhs[i])>1e-12) {error="immobile distance constraint";return false;}
                diagonal[i]=1.;
            }
        }
        for (int i=1;i<n;++i) {
            if (diagonal[i-1]<=1e-18) {error="singular mass projection";return false;}
            double f=off[i-1]/diagonal[i-1];diagonal[i]-=f*off[i-1];answer[i]-=f*answer[i-1];
        }
        if (diagonal.back()<=1e-18) {error="singular terminal constraint";return false;}
        answer.back()/=diagonal.back();
        for (int i=n-2;i>=0;--i) answer[i]=(answer[i]-off[i]*answer[i+1])/diagonal[i];
        for (double a:answer) if (!std::isfinite(a)) {error="nonfinite mass projection";return false;}
        corrections.resize(points.size());
        for (int i=0;i<int(points.size());++i) {
            Vector3 force;
            if (i<n) force+=(points[i]-points[i+1])*real_t(answer[i]);
            if (i>0) force-=(points[i-1]-points[i])*real_t(answer[i-1]);
            corrections[i]=warm_weight(force,i);
        }
        return true;
    }
    bool warm_banded(const Points &points,const std::vector<WarmRow> &rows,Points &corrections) {
        int n=int(rows.size());std::vector<double> lower(size_t(n)*5,0.),diagonal(n,0.),answer(n,0.);
        for (int i=0;i<n;++i) {
            answer[i]=rows[i].rhs;
            for (int j=std::max(0,i-4);j<=i;++j) {
                const WarmRow &a=rows[i],&b=rows[j];double value=0.;
                if (a.first==b.first) value+=a.vector.dot(warm_weight(b.vector,a.first));
                if (a.first==b.last) value-=a.vector.dot(warm_weight(b.vector,a.first));
                if (a.last==b.first) value-=a.vector.dot(warm_weight(b.vector,a.last));
                if (a.last==b.last) value+=a.vector.dot(warm_weight(b.vector,a.last));
                for (int k=std::max(0,i-4);k<j;++k) value-=lower[size_t(i)*5+i-k]*diagonal[k]*lower[size_t(j)*5+j-k];
                if (i==j) {
                    if (value<=1e-18) {error="singular coupled bend/length row "+std::to_string(i);return false;}
                    diagonal[i]=value;
                } else lower[size_t(i)*5+i-j]=value/diagonal[j];
            }
            for (int j=std::max(0,i-4);j<i;++j) answer[i]-=lower[size_t(i)*5+i-j]*answer[j];
        }
        for (int i=0;i<n;++i) answer[i]/=diagonal[i];
        for (int i=n-1;i>=0;--i) {
            for (int j=i+1;j<std::min(n,i+5);++j) answer[i]-=lower[size_t(j)*5+j-i]*answer[j];
            if (!std::isfinite(answer[i])) {error="nonfinite coupled projection";return false;}
        }
        corrections.assign(points.size(),Vector3());
        for (int i=0;i<n;++i) {
            corrections[rows[i].first]+=rows[i].vector*real_t(answer[i]);
            corrections[rows[i].last]-=rows[i].vector*real_t(answer[i]);
        }
        for (int i=0;i<int(points.size());++i) corrections[i]=warm_weight(corrections[i],i);
        return true;
    }
    Dictionary warm_output(const Points &points,bool accepted) const {
        Dictionary result;result["points"]=pack(points);result["accepted"]=accepted;
        result["error"]=String(error.c_str());result["iterations"]=iterations;return result;
    }
public:
    Dictionary warm_start(const PackedVector3Array &seed,const Vector3 &anchor,const Dictionary &support,const PackedVector3Array &hint_input) {
        error.clear();iterations=0;Points points=unpack(seed),hints=unpack(hint_input);
        if (!valid_points(points)) return warm_output({},false);
        if (!anchor.is_finite() || hints.size()!=spans.size()) {error="invalid native warm anchor/hints";return warm_output({},false);}
        for (const Vector3 &v:hints) if (!v.is_finite()) {error="nonfinite native bend hint";return warm_output({},false);}
        Planes planes;if (!unpack_planes(support,int(points.size()),planes)) return warm_output({},false);
        if (pinned_mode) {
            // The old tridiagonal warm solve assumes one fixed endpoint.
            // Additional rigid neck points use the joint solve's reduced
            // mobility rows instead; no fixed coordinate is projected away.
            points.back()=anchor;last_iterate=points;return warm_output(points,false);
        }
        int limit=support.is_empty()?128:8;
        for (int pass=0;pass<limit;++pass) {
            iterations=pass+1;
            // Preserve the collapsed-only bend repair and operation order.
            for (int i=1;i+1<int(points.size());++i) {
                Vector3 span=points[i+1]-points[i-1];double distance=span.length();
                if (distance>=spans[i-1] || distance>.0000001) continue;
                Vector3 direction=distance>.0000001?span/real_t(distance):hints[i-1];
                Vector3 correction=direction*real_t(spans[i-1]-distance)/real_t(inverse[i-1]+inverse[i+1]);
                points[i-1]-=correction*real_t(inverse[i-1]);points[i+1]+=correction*real_t(inverse[i+1]);
            }
            if (!warm_support(points,anchor,planes)) return warm_output({},false);
            std::vector<double> rhs(lengths.size());double maximum=0.,total=0.;
            for (int i=0;i<int(lengths.size());++i) {
                double distance=points[i].distance_to(points[i+1]);
                if (!std::isfinite(distance) || distance<.0000001) {error="collapsed material interval";return warm_output({},false);}
                rhs[i]=.5*(distance*distance-lengths[i]*lengths[i]);
                maximum=std::max(maximum,std::abs(distance-lengths[i]));total+=distance-lengths[i];
            }
            if (maximum<.000001 && std::abs(total)<.000005 && warm_bend_error(points)<.000001) return warm_output(points,true);
            std::vector<WarmRow> rows;rows.reserve(lengths.size()+spans.size());int bends=0;
            for (int i=0;i<int(lengths.size());++i) {
                Vector3 d=points[i]-points[i+1];rows.push_back({i,i+1,d,.5*(double(d.length_squared())-lengths[i]*lengths[i])});
                if (i+2>=int(points.size())) continue;
                d=points[i]-points[i+2];
                if (d.length()>=spans[i]) continue;
                rows.push_back({i,i+2,d,.5*(double(d.length_squared())-spans[i]*spans[i])});++bends;
            }
            Points corrections;
            if (!(bends==0?warm_tridiagonal(points,rhs,corrections):warm_banded(points,rows,corrections))) return warm_output({},false);
            for (int i=0;i<int(points.size());++i) points[i]-=corrections[i];
        }
        if (!warm_support(points,anchor,planes)) return warm_output({},false);
        double maximum=0.,total=0.;
        for (int i=0;i<int(lengths.size());++i) {
            double distance=points[i].distance_to(points[i+1]);maximum=std::max(maximum,std::abs(distance-lengths[i]));total+=distance-lengths[i];
        }
        return warm_output(points,maximum<=ERROR_M && std::abs(total)<=ERROR_M && warm_bend_error(points)<=bend_error_m);
    }
private:

protected:
    static void _bind_methods() {
        ClassDB::bind_method(D_METHOD("warm_start","seed","anchor","planes","hints"),&OrisonHoseProjectionNative::warm_start);
        ClassDB::bind_method(D_METHOD("configure","lengths","spans","inverse"),&OrisonHoseProjectionNative::configure);
        ClassDB::bind_method(D_METHOD("set_bend_error","value"),&OrisonHoseProjectionNative::set_bend_error);
        ClassDB::bind_method(D_METHOD("project","seed","anchor","planes"),&OrisonHoseProjectionNative::project);
        ClassDB::bind_method(D_METHOD("project_velocity","points","velocity","planes"),&OrisonHoseProjectionNative::project_velocity);
        ClassDB::bind_method(D_METHOD("follow","seed","anchor","planes","pins"),&OrisonHoseProjectionNative::follow);
        ClassDB::bind_method(D_METHOD("resume_follow","seed","anchor","planes","pins"),&OrisonHoseProjectionNative::resume_follow);
        ClassDB::bind_method(D_METHOD("pin","indices"),&OrisonHoseProjectionNative::pin);
        ClassDB::bind_method(D_METHOD("round_self_constraints","before","after","radius","pins"),&OrisonHoseProjectionNative::round_self_constraints);
        ClassDB::bind_method(D_METHOD("round_guide_seed","before","goal","join","axis","side","floor"),&OrisonHoseProjectionNative::round_guide_seed);
    }
public:
    Dictionary round_guide_seed(const PackedVector3Array &before,const Vector3 &goal,int join,Vector3 axis,Vector3 side,double floor) {
        Dictionary result;result["points"]=PackedVector3Array();
        if (before.size()!=int(inverse.size()) || join<6 || join>=before.size()-3 || !goal.is_finite() || !std::isfinite(floor)) return result;
        axis=axis.normalized();side=(side-axis*dot(side,axis)).normalized();Vector3 up=axis.cross(side).normalized();
        if (axis.length_squared()<.99 || side.length_squared()<.99) return result;
        Vector3 end=before[join];
        double total=0.,neck=0.;for (int i=0;i<join;++i) {total+=lengths[i];if (i<3) neck+=lengths[i];}
        double distance=goal.distance_to(end),slack=total-distance;
        if (slack<.0001 || dot(up,goal)<floor-.00001 || dot(up,end)<floor-.00001) return result;
        const double au=dot(axis,goal),bu=dot(axis,end),az=dot(side,goal),bz=dot(side,end),ah=dot(up,goal),bh=dot(up,end);
        const double straight=std::clamp(1.-slack/.5,0.,1.);
        // Choose the vertical control height from the actual minimum of the
        // cubic, so the broad loose line touches the supplied ground datum.
        auto minimum_height=[&](double control) {
            double value=std::min(ah,bh),a=bh-ah,b=2.*(ah-control),c=control-ah;
            auto sample=[&](double t) {if (t>0. && t<1.) {double s=1.-t;value=std::min(value,ah*s*s*s+bh*t*t*t+3.*control*t*s);}};
            if (std::abs(a)<1e-14) {if (std::abs(b)>1e-14) sample(-c/b);}
            else {double discriminant=b*b-4.*a*c;if (discriminant>=0.) {double root=std::sqrt(discriminant);sample((-b-root)/(2.*a));sample((-b+root)/(2.*a));}}
            return value;
        };
        double low_height=floor-std::max(total,1.),high_height=std::min(ah,bh);
        for (int i=0;i<32;++i) {double mid=(low_height+high_height)*.5;if (minimum_height(mid)<floor) low_height=mid;else high_height=mid;}
        const double height=high_height*(1.-straight)+(ah+bh)*.5*straight;
        double looseness=1.;
        auto from_axes=[&](double u,double z,double h) {return WidePoint(axis.x*u+side.x*z+up.x*h,axis.y*u+side.y*z+up.y*h,axis.z*u+side.z*z+up.z*h);};
        auto norm=[](const WidePoint &p) {return std::sqrt(p.x*p.x+p.y*p.y+p.z*p.z);};
        auto build=[&](double depth,Points *output) {
            double width=std::sqrt(std::max(.1,depth-std::min(au,bu))*.15/.338);
            width=std::min(width,.8*std::sqrt(slack*std::max(distance,1.)));
            const double mean_z=(az+bz)*.5,mean_h=(ah+bh)*.5;
            WidePoint c1=from_axes(depth,mean_z+looseness*((az+2.*width)*(1.-straight)+mean_z*straight-mean_z),mean_h+looseness*(height-mean_h));
            WidePoint c2=from_axes(depth,mean_z+looseness*((bz+.1*width)*(1.-straight)+mean_z*straight-mean_z),mean_h+looseness*(height-mean_h));
            WidePoint first(goal),last(end);WidePoint tangent=c1-first;double magnitude=norm(tangent);
            if (magnitude<1e-8) return -1.;
            Vector3 direction(real_t(tangent.x/magnitude),real_t(tangent.y/magnitude),real_t(tangent.z/magnitude));
            WidePoint start(goal+direction*neck);
            auto evaluate=[&](double t) {double s=1.-t;return WidePoint(start.x*s*s*s+3.*c1.x*s*s*t+3.*c2.x*s*t*t+last.x*t*t*t,start.y*s*s*s+3.*c1.y*s*s*t+3.*c2.y*s*t*t+last.y*t*t*t,start.z*s*s*s+3.*c1.z*s*s*t+3.*c2.z*s*t*t+last.z*t*t*t);};
            Points candidate;if (output) {candidate=unpack(before);candidate[0]=goal;double at=0.;for (int i=1;i<=3;++i) {at+=lengths[i-1];candidate[i]=goal+direction*at;}}
            WidePoint previous=start;double parameter=0.;
            for (int ring=4;ring<join;++ring) {
                const double length=lengths[ring-1];double low=parameter,high=parameter;
                bool found=false;
                while (high<1.) {high=std::min(1.,high+1./256.);if (norm(evaluate(high)-previous)>=length) {found=true;break;}low=high;}
                if (!found) return -1.;
                for (int pass=0;pass<20;++pass) {double middle=(low+high)*.5;if (norm(evaluate(middle)-previous)<length) low=middle;else high=middle;}
                parameter=(low+high)*.5;previous=evaluate(parameter);
                if (output) candidate[ring]=previous.narrow();
            }
            double residual=norm(last-previous)-lengths[join-1];
            if (output) *output=std::move(candidate);
            return residual;
        };
        double low=(au+bu)*.5,high=std::max(au,bu)+total;
        // Spend only the material slack that exists. A wide ground-level
        // loop must rise and narrow continuously as the endpoints separate.
        if (build(low,nullptr)>0.) {
            double lower=0.,upper=1.;
            for (int pass=0;pass<20;++pass) {looseness=(lower+upper)*.5;if (build(low,nullptr)>0.) upper=looseness;else lower=looseness;}
            looseness=lower*.99;
        }
        if (build(low,nullptr)>0. || build(high,nullptr)<0.) return result;
        for (int pass=0;pass<26;++pass) {double middle=(low+high)*.5;if (build(middle,nullptr)<0.) low=middle;else high=middle;}
        Points candidate;double residual=build((low+high)*.5,&candidate);
        if (candidate.size()!=size_t(before.size()) || std::abs(residual)>.00001) return result;
        result["points"]=pack(candidate);result["movable_length_m"]=total;result["fixed_length_m"]=arc_length_after(join);return result;
    }
    double arc_length_after(int ring) const {double total=0.;for (int i=ring;i<int(lengths.size());++i) total+=lengths[i];return total;}
    Dictionary round_self_constraints(const PackedVector3Array &before,const PackedVector3Array &after,double radius,const Dictionary &pins) {
        Dictionary result; Array planes;
        result["valid"]=false;result["clear"]=false;result["planes"]=planes;
        if (before.size()!=int(inverse.size()) || after.size()!=before.size() || !std::isfinite(radius) || radius<=0.) return result;
        const int count=before.size();
        std::vector<double> arc(count,0.);
        for (int i=0;i<count;++i) {
            if (!before[i].is_finite() || !after[i].is_finite()) return result;
            if (i) arc[i]=arc[i-1]+lengths[i-1];
        }
        auto closest=[](const Vector3 &a,const Vector3 &b,const Vector3 &c,const Vector3 &d,double &s,double &t) {
            Vector3 u=b-a,v=d-c,w=a-c;
            double aa=dot(u,u),bb=dot(u,v),cc=dot(v,v),dd=dot(u,w),ee=dot(v,w);
            if (aa<1e-16 || cc<1e-16) {s=0.;t=0.;return a-c;}
            double denominator=aa*cc-bb*bb;
            s=denominator>1e-20?std::clamp((bb*ee-cc*dd)/denominator,0.,1.):0.;
            t=(bb*s+ee)/cc;
            if (t<0.) {t=0.;s=std::clamp(-dd/aa,0.,1.);}
            else if (t>1.) {t=1.;s=std::clamp((bb-dd)/aa,0.,1.);}
            return (a+u*s)-(c+v*t);
        };
        const double diameter=radius*2.;
        int pairs=0;
        for (int i=0;i<count-1;++i) for (int j=i+2;j<count-1;++j) {
            // Adjacent material is governed by the caller's conservative bend
            // bounds. This query is only for a uniform, round outer envelope.
            if (arc[j]-arc[i+1]<diameter*2.) continue;
            bool separated=false;
            for (int axis=0;axis<3;++axis) {
                double low_a=std::min({double(before[i][axis]),double(before[i+1][axis]),double(after[i][axis]),double(after[i+1][axis])});
                double high_a=std::max({double(before[i][axis]),double(before[i+1][axis]),double(after[i][axis]),double(after[i+1][axis])});
                double low_b=std::min({double(before[j][axis]),double(before[j+1][axis]),double(after[j][axis]),double(after[j+1][axis])});
                double high_b=std::max({double(before[j][axis]),double(before[j+1][axis]),double(after[j][axis]),double(after[j+1][axis])});
                if (low_a-high_b>diameter+.000002 || low_b-high_a>diameter+.000002) {separated=true;break;}
            }
            if (separated) continue;
            Vector3 velocity[4]={after[i]-before[i],after[i+1]-before[i+1],after[j]-before[j],after[j+1]-before[j+1]};
            // Remove common translation before bounding relative speed.
            double speed=(velocity[1]-velocity[0]).length()+std::max((velocity[2]-velocity[0]).length(),(velocity[3]-velocity[0]).length());
            double time=0.,s=0.,t=0.;Vector3 delta;bool hit=false;
            for (int iteration=0;iteration<32;++iteration) {
                delta=closest(before[i]+velocity[0]*time,before[i+1]+velocity[1]*time,before[j]+velocity[2]*time,before[j+1]+velocity[3]*time,s,t);
                double distance=delta.length();
                if (time==0. && distance<diameter-.00001) {result["error"]="initial round hose self penetration";result["first"]=i;result["second"]=j;result["distance_m"]=distance;return result;}
                if (distance<=diameter+.000002) {hit=true;break;}
                if (speed<1e-12 || time+(distance-diameter)/speed>1.) break;
                double advance=.9*(distance-diameter)/speed;
                if (advance<1e-7 || iteration==31) {hit=true;break;}
                time+=advance;
            }
            if (!hit) continue;
            if (delta.length_squared()<1e-16) {result["error"]="undefined round self contact normal";return result;}
            Vector3 normal=delta.normalized();
            const int rings[4]={i,i+1,j,j+1};
            const double weights[4]={1.-s,s,-(1.-t),-t};
            double mobility=0.;
            for (int k=0;k<4;++k) if (!pins.has(rings[k])) mobility+=weights[k]*weights[k]*inverse[rings[k]];
            if (mobility<1e-16) {result["error"]="fixed round self contact";return result;}
            Vector3 final_delta=(after[i]*(1.-s)+after[i+1]*s)-(after[j]*(1.-t)+after[j+1]*t);
            double correction=std::max(0.,diameter+.0002-dot(normal,final_delta))/mobility;
            for (int k=0;k<4;++k) {
                int ring=rings[k];
                if (pins.has(ring) || inverse[ring]==0. || std::abs(weights[k])<1e-10) continue;
                Vector3 axis=weights[k]>0.?normal:-normal;
                double offset=dot(axis,after[ring])+std::abs(weights[k])*inverse[ring]*correction;
                Dictionary plane;plane["ring"]=ring;plane["normal"]=axis;plane["offset"]=offset;planes.append(plane);
            }
            if (++pairs==8) {result["valid"]=true;result["planes"]=planes;return result;}
        }
        result["valid"]=true;result["clear"]=planes.is_empty();result["planes"]=planes;
        return result;
    }
    bool pin(const PackedInt32Array &indices) {
        if (inverse.empty()) return false;
        if (indices.is_empty()) return true;
        std::vector<double> proposed=inverse;
        for (int i=0;i<indices.size();++i) {
            if (indices[i]<0 || indices[i]>=int(proposed.size())) return false;
            proposed[indices[i]]=0.;
        }
        if (std::none_of(proposed.begin(),proposed.end(),[](double value){return value>0.;})) return false;
        inverse=std::move(proposed);pinned_mode=true;return true;
    }
    Dictionary follow(const PackedVector3Array &seed,const Vector3 &anchor,const Dictionary &support,const Dictionary &pins) {
        return follow_impl(seed,anchor,support,pins,false);
    }
    Dictionary resume_follow(const PackedVector3Array &seed,const Vector3 &anchor,const Dictionary &support,const Dictionary &pins) {
        return follow_impl(seed,anchor,support,pins,true);
    }
    Dictionary follow_impl(const PackedVector3Array &seed,const Vector3 &anchor,const Dictionary &support,const Dictionary &pins,bool continuation) {
        error.clear();iterations=0;qp_iterations=0;Points points=unpack(seed);last_iterate=points;
        if (!valid_points(points)) return output({});
        if (!anchor.is_finite()) {error="nonfinite follower anchor";return output({});}
        Planes planes;if (!unpack_planes(support,int(points.size()),planes)) return output({});
        Points seed_points=points;
        std::vector<bool> fixed(points.size(),false);fixed.back()=true;points.back()=anchor;
        if (pinned_mode) for (int i=0;i<int(points.size());++i) if (inverse[i]==0.) fixed[i]=true;
        Array keys=pins.keys();
        for (int k=0;k<keys.size();++k) {
            if (keys[k].get_type()!=Variant::INT || pins[keys[k]].get_type()!=Variant::VECTOR3) {error="invalid follower pin type";return output({});}
            int64_t i=keys[k];Vector3 position=pins[keys[k]];
            if (i<0 || i>=int64_t(points.size()) || !position.is_finite() || (i+1==int64_t(points.size()) && position!=anchor)) {error="invalid follower pin";return output({});}
            fixed[i]=true;points[i]=position;
        }
        // Reject unreachable held configurations before bounded iterations.
        // This checks stock length, not the still-required swept-world path.
        std::vector<double> arc(points.size(),0.);
        for (int i=1;i<int(points.size());++i) arc[i]=arc[i-1]+lengths[i-1];
        for (int i=0;i<int(points.size());++i) if (fixed[i]) for (int j=i+1;j<int(points.size());++j) if (fixed[j]) {
            if (double(points[i].distance_to(points[j]))>arc[j]-arc[i]+ERROR_M) {error="follower pins exceed available stock";return output({});}
        }
        // Spread the imposed fitting displacement across the intervening
        // material as an INITIAL GUESS. Otherwise a55mm hand move is first
        // imposed on one3mm interval and the local solver can trap that neck.
        // Every original length, bend, pin and support bound is still checked;
        // the owner still sweeps the complete actual skin before committing.
        int left=-1;
        for (int right=0;right<int(points.size());++right) if (fixed[right]) {
            if (left>=0 && arc[right]>arc[left]) {
                Vector3 first=points[left]-seed_points[left],last=points[right]-seed_points[right];
                for (int i=left+1;i<right;++i) {
                    real_t fraction=real_t((arc[i]-arc[left])/(arc[right]-arc[left]));
                    points[i]+=first.lerp(last,fraction);
                }
            }
            left=right;
        }
        Points hints=points;
        int stagnation=0;
        int directional_limit=continuation?0:(fixed[0]?8:(support.is_empty()?256:32));
        for (int pass=0;pass<directional_limit;++pass) {
            iterations=pass+1;
            Points previous=points;
            if (!follow_support(points,planes,fixed)) {last_iterate=points;return output({});}
            error.clear();
            bool forward=follow_sweep(points,hints,planes,fixed,-1);
            double value=0.;bool accepted=false;
            if (forward && assess(points,planes,value,accepted) && accepted) {error.clear();last_iterate=points;return output(points);}
            // A local sphere can be infeasible until its neighbor moves. The
            // opposite sweep supplies that movement instead of immediately
            // handing a dense floor-contact problem to the global matrix.
            if (!follow_support(points,planes,fixed)) {last_iterate=points;return output({});}
            error.clear();
            bool reverse=follow_sweep(points,hints,planes,fixed,1);
            if (reverse && assess(points,planes,value,accepted) && accepted) {error.clear();last_iterate=points;return output(points);}
            double moved=0.;for (int i=0;i<int(points.size());++i) moved=std::max(moved,double(points[i].distance_squared_to(previous[i])));
            stagnation=moved<1e-18?stagnation+1:0;
            if (stagnation>=4) break;
        }
        if (fixed[0]) {
            // A held fitting can trap a local directional sweep against its
            // rigid neck. Couple all original rows with zero mobility at the
            // exact caller pins rather than stretching or moving the fitting.
            if (!continuation && support.is_empty()) {
                if (bend_error_m<ERROR_M) fillet_held_hint(points,hints,fixed);
                else bow_held_hint(points,hints,fixed);
            }
            auto configured_inverse=inverse;bool configured_pinned=pinned_mode;
            for (int i=0;i<int(fixed.size());++i) if (fixed[i]) inverse[i]=0.;
            pinned_mode=true;bool previous_held=held_projection;held_projection=true;
            Dictionary result=project(pack(points),anchor,support);
            held_projection=previous_held;inverse=std::move(configured_inverse);pinned_mode=configured_pinned;
            return result;
        }
        Points relaxed=hints;
        if (follow_relax(relaxed,hints,planes,fixed)) {error.clear();last_iterate=relaxed;return output(relaxed);}
        error="bounded follower pin convergence ceiling";last_iterate=relaxed;return output({});
    }

    bool set_bend_error(double value) {
        if (!std::isfinite(value) || value<=0. || value>ERROR_M) return false;
        bend_error_m=value;return true;
    }
    bool configure(const PackedFloat64Array &l,const PackedFloat64Array &b,const PackedFloat64Array &w) {
        if (l.size()<2 || w.size()!=l.size()+1 || b.size()+1!=l.size()) return false;
        for (int i=0;i<l.size();++i) if (!std::isfinite(l[i]) || l[i]<=0.) return false;
        for (int i=0;i<b.size();++i) if (!std::isfinite(b[i]) || b[i]<=0.) return false;
        for (int i=0;i<w.size();++i) if (!std::isfinite(w[i]) || (i+1<w.size()?w[i]<=0.:w[i]!=0.)) return false;
        lengths.assign(l.ptr(),l.ptr()+l.size());spans.assign(b.ptr(),b.ptr()+b.size());inverse.assign(w.ptr(),w.ptr()+w.size());
        pinned_mode=false;bend_error_m=ERROR_M;
        return inverse.size()==lengths.size()+1 && spans.size()+1==lengths.size();
    }
    Dictionary project(const PackedVector3Array &seed,const Vector3 &anchor,const Dictionary &support) {
        error.clear();iterations=0;qp_iterations=0;active_hint.clear();Points points=unpack(seed);last_iterate=points;
        if (!valid_points(points)) return output({});
        if (!anchor.is_finite()) {error="nonfinite native anchor";return output({});}
        Planes planes;if (!unpack_planes(support,int(points.size()),planes)) return output({});
        points.back()=anchor;
        if (pinned_mode) return project_wide(points,anchor,planes);
        for (int iteration=0;iteration<POSITION_ITERATIONS;++iteration) {
            iterations=iteration+1;Rows rows;
            if (!make_rows(points,planes,rows)) return output({});
            if (acceptable(rows)) return output(points);
            Points delta;if (!linear(rows,int(points.size()),delta)) {last_iterate=points;return output({});}
            // Linearized distance constraints can overshoot sharply near a
            // dense contact set. Backtrack on actual nonlinear residuals;
            // acceptance still checks every original bound independently.
            double old_merit=merit(rows);bool advanced=false;
            for (double alpha=1.;alpha>=1./4096.;alpha*=.5) {
                Points trial=points;
                for (int i=0;i<int(points.size());++i) trial[i]+=delta[i]*real_t(alpha);
                trial.back()=anchor;double trial_merit=0.;bool accepted=false;
                if (!assess(trial,planes,trial_merit,accepted)) return output({});
                if (accepted || trial_merit<=old_merit*(1.-.01*alpha)) {
                    points=std::move(trial);advanced=true;break;
                }
            }
            last_iterate=points;
            if (!advanced) {
                if (pinned_mode && polish_total_roundoff(points,planes)) {error.clear();last_iterate=points;return output(points);}
                error="native nonlinear line search stalled";return output({});
            }
        }
        Rows rows;if (make_rows(points,planes,rows) && acceptable(rows)) return output(points);
        if (pinned_mode && polish_total_roundoff(points,planes)) {error.clear();last_iterate=points;return output(points);}
        error="native nonlinear projection ceiling";return output({});
    }
    Dictionary project_velocity(const PackedVector3Array &input,const PackedVector3Array &velocity,const Dictionary &support) {
        error.clear();iterations=0;qp_iterations=0;active_hint.clear();Points points=unpack(input),speed=unpack(velocity);last_iterate=points;
        if (!valid_points(points) || speed.size()!=points.size()) {error="native velocity sizes differ";return output({});}
        for (const Vector3 &v:speed) if (!v.is_finite()) {error="nonfinite native velocity";return output({});}
        if (pinned_mode) for (int i=0;i<int(speed.size());++i) if (inverse[i]==0.) speed[i]=Vector3();
        Planes planes;if (!unpack_planes(support,int(points.size()),planes)) return output({});
        Rows all,selected;if (!make_rows(points,planes,all)) return output({});
        for (Row row:all) {
            if (!row.equality && row.g>(row.plane?.000001:bend_error_m)) continue;
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
