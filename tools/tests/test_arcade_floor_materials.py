"""Source-floor glTF sampling is the oracle for the five retained _b finishes.

Reads shipped source/texture data only. No private reports, generators with
side effects, native/GPU launches or generated-file writes.
"""
import ast
import hashlib
import importlib.util
import json
import math
from pathlib import Path
import sys
import unittest
from urllib.parse import unquote

import numpy as np
from PIL import Image

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tools'))
sys.path.insert(0,str(ROOT/'art/blender/scripts'))
from prepare_arcade_native_projection import SourceCell, raw_bounds
from fabrication_uvs import chart_for_triangle

SPEC=importlib.util.spec_from_file_location('floor_runtime_generator',
    ROOT/'art/tools/generate_runtime_materials.py')
gen=importlib.util.module_from_spec(SPEC);SPEC.loader.exec_module(gen)
FAMILIES={'floor_oak_b','quarry_tile_b','linoleum_b','terrazzo_b','concrete_b'}


def pixels(path):
    with Image.open(path) as image:
        rgba=image.convert('RGBA')
        return image.size,hashlib.sha256(rgba.tobytes()).hexdigest()


class ArcadeFloorMaterialTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.contract=gen.build_contract()
        cls.catalog=json.loads(gen.CATALOG.read_text())
        cls.mapping=json.loads(gen.MAPPING.read_text())
        layout=json.loads((ROOT/'game/data/building_layout.json').read_text())
        floor=next(f for f in layout['floors'] if f['id']=='F01')
        cls.records=[r for r in floor['furniture'] if
                     (r['id'].startswith('storm_shop_') or r['id'].startswith('site_rear_'))
                     and r['id'].endswith('_floor') and r.get('batch','').startswith('shop_')]
        cls.sources=[];cls.cells={}
        for record in cls.records:
            cell=record['batch'].replace('shop_otis___son','shop_otis_son')
            if cell not in cls.cells:
                rel='res://assets/building/floor_01_cells/'+cell+'.gltf'
                path=ROOT/'game'/rel[6:];doc=json.loads(path.read_text())
                buffers={rel.rsplit('/',1)[0]+'/'+b['uri']:
                         hashlib.sha256((path.parent/b['uri']).read_bytes()).hexdigest()
                         for b in doc['buffers']}
                cls.cells[cell]=(path,doc,SourceCell(ROOT,rel,buffers))
            path,doc,_=cls.cells[cell]
            material=next(m for m in doc['materials'] if m['name']=='M_'+record['mat']+'_b')
            pbr=material['pbrMetallicRoughness']
            maps=[]
            for entry in [pbr['baseColorTexture'],pbr['metallicRoughnessTexture'],material['normalTexture']]:
                image=doc['images'][doc['textures'][entry['index']]['source']]
                maps.append((path.parent/unquote(image['uri'])).resolve())
            cls.sources.append(dict(record=record,cell=cell,material=material,maps=maps))

    def test_roster_is_eleven_sales_and_eleven_original_concrete_stock_floors(self):
        self.assertEqual(len(self.cells),11)
        self.assertEqual(len(self.sources),22)
        self.assertEqual({s['record']['mat']+'_b' for s in self.sources},FAMILIES)
        stock=[s for s in self.sources if s['record']['id'].startswith('site_rear_')]
        self.assertEqual(len(stock),11)
        self.assertEqual({s['record']['mat'] for s in stock},{'concrete'})

    def test_contract_aliases_preserve_actual_source_pixels_and_metadata_scale(self):
        for source in self.sources:
            key=source['record']['mat']+'_b'
            with self.subTest(key=key,cell=source['cell']):
                self.assertIn(key,self.contract['materials'])
                spec=self.contract['materials'][key]
                self.assertFalse(spec['visual_lock'])
                self.assertEqual(spec['catalog_mapping'],'ai_materials/'+key)
                metadata=json.loads((ROOT/'art/textures'/self.mapping[key]/'material.json').read_text())
                self.assertEqual(spec['meters_per_tile'],metadata['meters_per_tile'])
                self.assertEqual(spec['canonical_meters_per_tile'],metadata['meters_per_tile'])
                for original,alias in zip(source['maps'],spec['files']):
                    # Byte-dedup aliases may use another filename. Compare
                    # actual decoded pixels, not names or semantic similarity.
                    self.assertEqual(pixels(original),pixels(gen.GODOT_TEXTURES/alias))

    def test_actual_gltf_white_pbr_not_old_registry_colour(self):
        for source in self.sources:
            key=source['record']['mat']+'_b';material=source['material']
            pbr=material['pbrMetallicRoughness']
            with self.subTest(key=key):
                self.assertEqual(pbr.get('baseColorFactor',[1,1,1,1]),[1,1,1,1])
                self.assertIn(key,self.catalog)
                self.assertEqual(self.catalog[key]['base_color'],[1,1,1,1])
                self.assertIn(key,self.contract['materials'])
                spec=self.contract['materials'][key]
                self.assertEqual(spec['metallic'],pbr.get('metallicFactor',1))
                self.assertEqual(spec['roughness_multiplier'],pbr.get('roughnessFactor',1))
                self.assertAlmostEqual(gen.RUNTIME_POLICY[key]['normal_scale'],
                                       material['normalTexture'].get('scale',1),places=6)
                self.assertFalse(spec['alpha'])

    def test_green_roughness_survives_policy_to_generated_optics(self):
        # glTF metallicRoughnessTexture has roughness in G, not R. Check both
        # authoring policy and the rendered generated consumer dictionary.
        text=gen.render_gd(self.contract).split('const OPTICS := ',1)[1]
        optics=ast.literal_eval(text.split('\n}',1)[0]+'\n}')
        for key in FAMILIES:
            with self.subTest(key=key):
                self.assertIn(key,gen.RUNTIME_POLICY)
                self.assertEqual(gen.RUNTIME_POLICY[key]['roughness_channel'],'green')
                self.assertIn(key,optics)
                self.assertEqual(optics[key]['roughness_channel'],'green')
                self.assertAlmostEqual(optics[key]['normal_scale'],.35)

    def test_red_channel_negative_control_and_concrete_grayscale_control(self):
        differences={}
        for source in self.sources:
            key=source['record']['mat']+'_b'
            with Image.open(source['maps'][1]) as image:
                rgb=np.asarray(image.convert('RGB')).astype(int)
                differences[key]=int(np.max(np.abs(rgb[:,:,0]-rgb[:,:,1])))
        self.assertEqual(differences['concrete_b'],0)
        for key in FAMILIES-{'concrete_b'}:
            self.assertGreater(differences[key],0,'RED substitution would change actual roughness')
        self.assertEqual(set(differences),FAMILIES)

    def test_actual_top_triangles_match_metadata_metric_chart_and_v_phase(self):
        without_v_offset=[]
        for source in self.sources:
            record=source['record'];key=record['mat']+'_b'
            self.assertIn(key,self.contract['materials'])
            tile=self.contract['materials'][key]['meters_per_tile']
            _,_,cell=self.cells[source['cell']];low,high=raw_bounds(record)
            top=[]
            for face in cell.faces:
                if face['binding']['material_name']!='M_'+key:continue
                if not all(abs(p[1]-high[1])<2e-5 and low[0]-2e-5<=p[0]<=high[0]+2e-5
                           and low[2]-2e-5<=p[2]<=high[2]+2e-5 for p in face['points']):continue
                normals,_=cell.accessor(face['binding']['attributes']['NORMAL']['accessor'])
                if all(normals[i][1]>.999 for i in face['indices']):top.append(face)
            self.assertEqual(len(top),2,record['id'])
            for face in top:
                # Actual once-only Godot->Blender conversion, target floorY0.
                points=np.asarray([[x,-z,y-.01] for x,y,z in face['points']])
                _,_,metric,fallback=chart_for_triangle(points,np.zeros(3),tile)
                self.assertFalse(fallback)
                original,_=cell.accessor(face['binding']['attributes']['TEXCOORD_0']['accessor'])
                for uv,index in zip(metric,face['indices']):
                    projected=[float(uv[0])/tile,(1-float(uv[1]))/tile+1-1/tile]
                    wrong=[float(uv[0])/tile,(1-float(uv[1]))/tile]
                    for channel in range(2):
                        # ModuloREPEAT permits helper's whole physical-tile
                        # chart shifts, not a stretched or swizzled texture.
                        error=abs((projected[channel]-original[index][channel]+.5)%1-.5)
                        self.assertLess(error,2e-6,(record['id'],channel,error))
                        without_v_offset.append(abs((wrong[channel]-original[index][channel]+.5)%1-.5))
        self.assertGreater(max(without_v_offset),.3,'missing V correction must fail control')


if __name__=='__main__':unittest.main()
