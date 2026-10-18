"""Mirroring must preserve the actual surface, density, normals and tangent sign."""
from pathlib import Path
import sys,unittest
import numpy as np
sys.path.insert(0,str(Path(__file__).resolve().parents[2]/'art/blender/scripts'))
from construction_shed_uv import mirrored_triangles

class MirroredWoodTests(unittest.TestCase):
    def fold(self,uv):
        points=np.column_stack((uv,np.zeros(3)))[None]
        return mirrored_triangles(points,np.array(uv)[None],np.array([[[0.,0.,1.]]*3]),np.array([[1.,0.,0.]]))
    def test_splits_preserve_area_and_physical_chart_scale(self):
        uv=np.array([[.15,.25],[2.6,.25],[.15,1.8]])
        points,charts,normals,guides,sign=self.fold(uv)
        area=np.linalg.norm(np.cross(points[:,1]-points[:,0],points[:,2]-points[:,0]),axis=1)
        a,b=uv[1]-uv[0],uv[2]-uv[0];expected=a[0]*b[1]-a[1]*b[0]
        self.assertAlmostEqual(float(area.sum()),float(expected),places=11)
        a,b=charts[:,1]-charts[:,0],charts[:,2]-charts[:,0];uv_area=np.abs(a[:,0]*b[:,1]-a[:,1]*b[:,0])
        np.testing.assert_allclose(area,uv_area,rtol=1e-10,atol=1e-12)
        self.assertGreater(len(points),3);self.assertTrue(np.all((charts>=0)&(charts<=1)))
        np.testing.assert_allclose(np.linalg.norm(normals,axis=2),1.)
    def test_single_reflection_reverses_tangent_and_handedness(self):
        points,uv,n,g,w=self.fold([[1.1,.1],[1.8,.1],[1.1,.8]])
        np.testing.assert_allclose(g,[[[-1.,0.,0.]]*3]);np.testing.assert_allclose(w,[1.])
    def test_two_reflections_preserve_handedness(self):
        *_,sign=self.fold([[1.1,1.1],[1.8,1.1],[1.1,1.8]])
        np.testing.assert_allclose(sign,[-1.])
    def test_shared_boundary_has_identical_clamped_coordinates(self):
        points,uv,*_=self.fold([[.8,.2],[1.2,.2],[1.,.8]])
        pairs={}
        for p,c in zip(points.reshape((-1,3)),uv.reshape((-1,2))):
            if abs(p[0]-1)<1e-10:pairs.setdefault(tuple(np.round(p,10)),[]).append(c)
        self.assertTrue(any(len(v)>1 for v in pairs.values()))
        for values in pairs.values():
            for value in values:np.testing.assert_allclose(value,values[0],atol=1e-10)

    def test_export_precision_discards_only_collapsed_geometry(self):
        points=np.array([[[3.25,2.7,3.7],[2.25,2.7,3.7],[3.25,2.70000001,3.7]]])
        uv=np.array([[[0.,0.],[1.,0.],[0.,.00000001]]])
        result=mirrored_triangles(points,uv,np.array([[[0.,0.,1.]]*3]),np.array([[-1.,0.,0.]]))
        self.assertEqual(len(result[0]),0)

if __name__=='__main__':unittest.main()
