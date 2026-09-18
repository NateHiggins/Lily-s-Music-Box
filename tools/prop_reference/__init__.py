"""Prop reference comparison: photograph the shed, fetch licence-clean references, compare, rank.

Pipeline (see README.md beside this file):

1. ``game/tests/PropWarehouseShot.tscn`` photographs every specimen in the
   inspection shed and writes ``warehouse_manifest.json``.
2. ``fetch`` pulls reference photographs and period plates from Wikimedia
   Commons for each specimen's queries, keeping only permissively licensed
   files, and records provenance beside every byte it downloads.
3. ``sheets`` lays our frames beside the references, one contact sheet per
   specimen, and writes ``comparison_index.json`` for the critique pass.
4. ``score`` folds the structured critiques into a deterministic priority.
5. ``brief`` assembles the modelling/texturing brief in that order.

Third-party bytes live only under ``art/reference/props/_fetched`` (ignored
by git); the URL, licence and author in ``provenance.json`` are the record.
"""
