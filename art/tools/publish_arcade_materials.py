"""Publish source-bound arcade map recipes through their registered catalogue.

This stages pixels, not acceptance. Runtime imports and composed render proof
remain necessary. The old shared terrazzo/common-brick stock stays available
to V1; V2's selected stock cannot be resurrected by an AI full-ingestion run.
"""
from pathlib import Path
import argparse
import hashlib
import json
import shutil

ROOT = Path(__file__).resolve().parents[2]
KEYS = ['arcade_terrazzo', 'arcade_terrazzo_dark', 'arcade_brick_face',
        'arcade_brick_bond', 'arcade_lime_mortar']


def publish(review):
    mapping = json.loads((ROOT / 'art/textures/catalog_mapping.json').read_text())
    for key in KEYS:
        source = Path(review) / 'materials' / key
        meta = json.loads((source / 'material.json').read_text())
        if meta['material'] != key or mapping.get(key) != 'procedural/' + key:
            raise ValueError('Unregistered arcade stock: ' + key)
        if hashlib.sha256((ROOT / meta['generator']).read_bytes().replace(b'\r\n', b'\n')).hexdigest() != meta['generator_sha256_lf']:
            raise ValueError('Expired stock generator: ' + key)
        if hashlib.sha256((ROOT / meta['albedo_source']).read_bytes()).hexdigest() != meta['albedo_source_sha256']:
            raise ValueError('Expired stock ingredient: ' + key)
        for role, filename in meta['maps'].items():
            if hashlib.sha256((source / filename).read_bytes()).hexdigest() != meta['map_sha256'][role]:
                raise ValueError('Map drift: ' + key + '/' + role)
        target = ROOT / 'art/textures' / mapping[key]
        target.mkdir(parents=True, exist_ok=True)
        for filename in list(meta['maps'].values()) + ['material.json']:
            shutil.copyfile(source / filename, target / filename)
        for role, suffix in [('albedo', 'albedo'), ('roughness', 'rough'), ('normal', 'normal')]:
            shutil.copyfile(source / meta['maps'][role], ROOT / 'game/assets/building/textures' / ('T_ai_materials_' + key + '_' + suffix + '.png'))
        print('Staged registered custom stock:', key)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--review', type=Path, required=True)
    args = parser.parse_args()
    publish(args.review)
