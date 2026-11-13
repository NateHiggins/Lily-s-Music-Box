"""Source-backed finite dynamic speech and exact component reconstruction."""
from pathlib import Path
import copy
import json
import re
import shutil
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tools/voice'))
import dynamic


class DynamicVoiceTests(unittest.TestCase):
    def setUp(self):
        scratch = tempfile.TemporaryDirectory()
        self.addCleanup(scratch.cleanup)
        self.root = Path(scratch.name)
        for path in dynamic.PROVIDERS:
            target = self.root / path
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(ROOT / path, target)
        self.registry = {'profiles': {}}
        for key in ('alpha', 'transient_guest_a', 'lena_ortiz', 'lily'):
            self.registry['profiles'][key] = dict(id=key, display_name=key, voice_description='A fixture voice.',
                delivery_direction='Plainly.', delivery='spoken', seed=15,
                reference=None if key == 'lily' else {'file': key + '.wav', 'sha256': 'a' * 64, 'text': 'A reference.'})
        self.registry['profiles']['transient_guests'] = dict(id='transient_guests', display_name='Guests',
            voice_description='A fixture pair.', delivery_direction='Two voices.', delivery='spoken',
            seed=16, variants=['transient_guest_a'], reference=None)
        for owner in ('alpha', 'transient_guests', 'lily'):
            self.data('game/data/dialogue/' + owner + '.json',
                      {'meta': {'resident_id': owner}, 'nodes': {'open': {'line': 'Hello.'}}})
        weather = dict(resident_id='alpha', trend='It has gone on.')
        weather.update({kind: kind.title() + ' at this window.' for kind in
                        ('cold', 'heat', 'wet', 'snow', 'clearing', 'fair', 'fog', 'night')})
        self.data('game/data/weather/resident_weather.json', {'residents': [weather]})
        self.data('game/data/music_catalog.json', {'residents': {
            'alpha': {'favorite': 'record_a', 'anecdote': 'The chorus.\nA cough.', 'gift_line': 'Keep this one.'},
            'transient_guests': {'favorite': 'record_b', 'anecdote': "We know this hotel.", 'gift_line': 'Our room again.'},
            'lily': {'favorite': 'record_c', 'anecdote': 'A private recording.', 'gift_line': 'No reference yet.'}}})
        self.data('game/data/kitchen/cookbook.json', {'dishes': [
            {'resident': 'alpha', 'ingredients': [['rice', 2], ['onions', 1]]},
            {'resident': 'transient_guests', 'ingredients': [['rice', 1]]}]})
        self.data('game/data/kitchen/groceries.json', {
            'household': {'lighting': {'matches': 1}, 'washing_up': {'soap': 1, 'scour': 1}},
            'ingredients': {key: {'name': label} for key, label in
                            [('rice', 'Rice'), ('onions', 'Onions'), ('matches', 'Matches'),
                             ('soap', 'Soap flakes'), ('scour', 'Scouring powder'), ('unused_honey', 'Honey')]}})
        for source in re.findall(r'"res://([^\"]+\.json)"',
                                 re.search(r'const PATHS:.*?=\s*\[(.*?)\]',
                                           (ROOT / 'game/scripts/game/shop_catalogue.gd').read_text(), re.S)[1]):
            self.data('game/' + source, {'items': [{'id': 'flowers', 'gift': True},
                {'id': 'ledger', 'gift': False}] if source.endswith('/bodega.json') else []})

    def data(self, path, document=None):
        target = self.root / path
        if document is None:
            return json.loads(target.read_text(encoding='utf-8'))
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(json.dumps(document, ensure_ascii=False, indent=2), encoding='utf-8')

    def inventory(self):
        return dynamic.build(self.root, self.registry)

    def test_ticket_domain_is_the_real_selectable_wall_not_all_ticket_numbers(self):
        document = self.inventory()
        expected = {226, 233, 240, 261, 268, 275, 282, 303, 310, 317, 324, 345,
                    352, 359, 387, 394, 401, 422, 429, 436, 443, 464, 471, 478}
        for owner in ('alpha', 'transient_guests'):
            recipe = next(r for r in document['component_recipes']
                          if r['kind'] == 'parcel_ticket' and r['owner_resident_id'] == owner)
            self.assertEqual({t['ticket'] for t in recipe['ticket_components']}, expected)
            self.assertEqual({t['parcel_id'] for t in recipe['ticket_components']},
                             {f'{row}_{col}' for row in (1, 2, 3) for col in range(8)})
        ticket_rows = [row for row in document['supplemental_rows'] if row.get('component_kind') == 'ticket']
        self.assertEqual(len(ticket_rows), 48)
        self.assertTrue(all(row['text'] == str(row['component_value']) for row in ticket_rows))

    def test_grocery_domain_uses_only_recipe_and_household_names_without_state_products(self):
        document = self.inventory()
        recipe = next(r for r in document['component_recipes']
                      if r['kind'] == 'grocery_list' and r['owner_resident_id'] == 'alpha')
        self.assertEqual({i['ingredient_id'] for i in recipe['ingredient_components']},
                         {'rice', 'onions', 'matches', 'soap', 'scour'})
        self.assertEqual(recipe['max_items'], 4)
        ingredients = [row for row in document['supplemental_rows'] if row.get('component_kind') == 'ingredient']
        self.assertEqual(len(ingredients), 9)  # Five alpha names and four guest names, not their combinations.
        self.assertFalse(any(row['runtime_node_id'] in ('errand:ask', 'parcel:ask', 'parcel:wait')
                             for row in document['supplemental_rows']))
        self.assertFalse(any(row.get('component_value') == 'unused_honey' for row in ingredients))

    def test_components_reconstruct_every_ticket_and_a_sorted_first_four_list_exactly(self):
        document = self.inventory()
        clips = {(row['owner_resident_id'], row['runtime_node_id']): row['text']
                 for row in document['supplemental_rows']}
        grocery = next(r for r in document['component_recipes']
                       if r['kind'] == 'grocery_list' and r['owner_resident_id'] == 'alpha')
        missing = ['soap', 'rice', 'onions', 'matches', 'scour']
        names = [clips['alpha', 'component:ingredient:' + key] for key in sorted(missing)[:grocery['max_items']]]
        rendered = grocery['join'].join(names) + grocery['before_suffix'] + clips['alpha', grocery['suffix_component']]
        self.assertEqual(rendered, 'Matches, Onions, Rice, Scouring powder. If you\'re going anyway.')
        self.assertEqual(rendered, grocery['format_string'] % ', '.join(names))
        for recipe in document['component_recipes']:
            if recipe['kind'] != 'parcel_ticket':
                continue
            owner, ask, wait = recipe['owner_resident_id'], recipe['ask'], recipe['wait']
            for ticket in recipe['ticket_components']:
                number = clips[owner, ticket['runtime_node_id']]
                spoken_ask = clips[owner, ask['prefix_component']] + ask['before_number'] + number + ask['before_suffix'] + clips[owner, ask['suffix_component']]
                spoken_wait = number + wait['before_suffix'] + clips[owner, wait['suffix_component']]
                self.assertEqual(spoken_ask, ask['format_string'] % ticket['ticket'])
                self.assertEqual(spoken_wait, wait['format_string'] % ticket['ticket'])

    def test_weather_and_music_words_match_the_data_and_provider_joins(self):
        document = self.inventory()
        weather = self.data('game/data/weather/resident_weather.json')['residents'][0]
        rows = [row for row in document['supplemental_rows'] if row['namespace'] == 'weather']
        self.assertEqual(len(rows), 16)
        for row in rows:
            parts = row['runtime_node_id'].split(':')
            kind = parts[3]
            expected = weather[kind] + (' ' + weather['trend'] if parts[-1] == 'spell' else '')
            self.assertEqual(row['text'], expected)
            self.assertTrue(row['runtime_node_is_pattern'])
        music = self.data('game/data/music_catalog.json')['residents']['alpha']
        texts = {row['text'] for row in document['supplemental_rows']
                 if row['namespace'] == 'music' and row['owner_resident_id'] == 'alpha'}
        self.assertEqual(texts, {music['anecdote'], music['anecdote'] + '\n\n' + music['gift_line']})

    def test_reference_required_voices_are_excluded_and_guest_owner_is_not_replaced(self):
        document = self.inventory()
        self.assertFalse(any(row['profile_id'] == 'lily' for row in document['supplemental_rows']))
        self.assertTrue(any(row['owner_resident_id'] == 'lily' for row in document['excluded']))
        guests = [row for row in document['supplemental_rows'] if row['owner_resident_id'] == 'transient_guests']
        self.assertTrue(guests)
        self.assertEqual({row['profile_id'] for row in guests}, {'transient_guest_a'})
        self.assertEqual({row['runtime_node_id'] for row in document['supplemental_rows']
                          if row['namespace'] == 'gift'}, {'gift:flowers'})

    def test_mixed_guest_exchange_never_becomes_a_single_guest_a_take(self):
        data = self.data('game/data/music_catalog.json')
        data['residents']['transient_guests']['anecdote'] = 'Tea. — Coffee.'
        self.data('game/data/music_catalog.json', data)
        document = self.inventory()
        self.assertFalse(any('Tea. — Coffee.' in row['text'] for row in document['supplemental_rows']))
        self.assertTrue(any(row['reason'] == 'explicit_guest_turns_required' for row in document['excluded']))

    def test_an_unknown_recipe_ingredient_cannot_invent_a_spoken_name(self):
        cookbook = self.data('game/data/kitchen/cookbook.json')
        cookbook['dishes'][0]['ingredients'].append(['not_in_groceries', 1])
        self.data('game/data/kitchen/cookbook.json', cookbook)
        with self.assertRaisesRegex(ValueError, 'Unknown grocery ingredient'):
            self.inventory()

    def test_same_gift_sold_at_two_shops_has_one_runtime_row_and_both_sources(self):
        self.data('game/data/shops/luncheonette.json', {'items': [{'id': 'flowers', 'gift': True}]})
        gifts = [row for row in self.inventory()['supplemental_rows'] if row['namespace'] == 'gift']
        self.assertEqual(len(gifts), 2)  # One alias per resident, not per shop.
        for row in gifts:
            paths = {binding['path'] for binding in row['source_bindings']}
            self.assertIn('game/data/shops/bodega.json', paths)
            self.assertIn('game/data/shops/luncheonette.json', paths)

    def test_provider_changes_fail_closed_and_data_changes_invalidate_inventory(self):
        document = self.inventory()
        dynamic.verify_sources(self.root, document)
        data = self.data('game/data/kitchen/groceries.json')
        data['ingredients']['rice']['name'] = 'Changed rice'
        self.data('game/data/kitchen/groceries.json', data)
        with self.assertRaisesRegex(ValueError, 'Dynamic source changed'):
            dynamic.verify_sources(self.root, document)
        provider = self.root / dynamic.ERRANDS
        provider.write_bytes(provider.read_bytes() + b'\n# Unreviewed provider edit.\n')
        with self.assertRaisesRegex(ValueError, 'Unreviewed voice provider'):
            self.inventory()

    def test_source_guards_are_lf_portable_and_service_prompts_keep_their_carrier(self):
        provider = self.root / dynamic.PARCELS
        provider.write_bytes(provider.read_bytes().replace(b'\r\n', b'\n').replace(b'\n', b'\r\n'))
        document = self.inventory()
        service = [row for row in document['supplemental_rows'] if row['namespace'] == 'service_round']
        self.assertEqual(len(service), 3)
        self.assertEqual(next(row for row in service if row['runtime_node_id'] == 'service:call')['carrier'],
                         'service_set_remote_call')
        self.assertTrue(all(row['requires_runtime_present_key'] for row in service))
        self.assertTrue(all(row['source_bindings'] for row in document['supplemental_rows']))

    def test_cli_writes_a_portable_inventory_in_an_explicit_output_location(self):
        persisted = copy.deepcopy(self.registry)
        persisted['schema_version'] = 1
        persisted['profiles'] = list(persisted['profiles'].values())
        self.data('game/data/voice/voice_profiles.json', persisted)
        output = self.root / 'out/inventory.json'
        result = subprocess.run([sys.executable, str(Path(dynamic.__file__)), '--root', str(self.root),
                                 '--out', str(output)], capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        document = json.loads(output.read_text(encoding='utf-8'))
        self.assertEqual(json.loads(result.stdout)['rows'], len(document['supplemental_rows']))
        self.assertFalse(list(self.root.rglob('*.wav')))


if __name__ == '__main__':
    unittest.main()
