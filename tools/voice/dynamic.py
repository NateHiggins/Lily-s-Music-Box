"""Source-bound authored dynamic speech; finite clips rather than state products."""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import re

import intake


# Reviewed provider semantics at main 1149ae1ad. A changed provider requires a
# source review, not silent reuse of this interpretation or old audio evidence.
PROVIDERS = {
    'game/scripts/game/resident_conversations.gd': '79e8193ac12df4e8fed2b8476630600d7227e10504ef3845a7981d1f88e9c4a8',
    'game/scripts/game/resident_weather.gd': 'b35addd59a5b87a8a020a3be2fdd910586338c5fdc7620e79c147122855f3f9f',
    'game/scripts/game/resident_errands.gd': '17e09ab3343fc20e11f0c86719d85785c90b5854714ae9774944350146ce2381',
    'game/scripts/game/parcel_errands.gd': 'fa41fe4a2fb270db882454c167c9e7b758f073a0f590c52894a3b73bf957b356',
    'game/scripts/game/kitchen_larder.gd': 'fd953386b115024133168e920bf07eaff9d2b4aa042c7206809ab9d6b4665967',
    'game/scripts/audio/orison_v2_music_library.gd': '53d2c208f2e953f15b1425e2399991f0357aae194d3754d4d44645e2d981bd88',
    'game/scripts/game/service_round_director.gd': 'cc5fa8a86903f683f6323054592ff67aac2214e9ceae462384b6dee06c9e2ff3',
    'game/scripts/game/resident_gifts.gd': '35c95adb75a584c4d8655d6e44b8b80898994bb138959cdd880bdf81ff866698',
    'game/scripts/game/shop_catalogue.gd': 'f9416c1e3121f1fd17b16bde4f1fae8da46c788c36b8ad2060c3f17f1312aed6',
}
CONVERSATIONS = 'game/scripts/game/resident_conversations.gd'
WEATHER = 'game/scripts/game/resident_weather.gd'
ERRANDS = 'game/scripts/game/resident_errands.gd'
PARCELS = 'game/scripts/game/parcel_errands.gd'
MUSIC = 'game/scripts/audio/orison_v2_music_library.gd'
SERVICE = 'game/scripts/game/service_round_director.gd'
QUOTED = r'"(?:\\.|[^"\\])*"'


def digest(raw):
    return hashlib.sha256(raw).hexdigest()


def number_words(value):
    """Unambiguous English cardinal for a source ticket value, not a year."""
    if type(value) is not int or not 0 <= value < 1000000:
        raise ValueError('Unsupported spoken ticket number')
    small = ('zero one two three four five six seven eight nine ten eleven twelve '
             'thirteen fourteen fifteen sixteen seventeen eighteen nineteen').split()
    tens = ('', '', 'twenty', 'thirty', 'forty', 'fifty', 'sixty', 'seventy', 'eighty', 'ninety')
    if value < 20:
        return small[value]
    if value < 100:
        return tens[value//10] + ('-' + small[value%10] if value%10 else '')
    if value < 1000:
        return small[value//100] + ' hundred' + (' ' + number_words(value%100) if value%100 else '')
    return number_words(value//1000) + ' thousand' + (' ' + number_words(value%1000) if value%1000 else '')


def verify_sources(root, inventory):
    for path, expected in inventory['source_bindings'].items():
        try:
            actual = digest((root / path).read_bytes().replace(b'\r\n', b'\n'))
        except OSError as error:
            raise ValueError(f'Dynamic source unavailable: {path}') from error
        if actual != expected:
            raise ValueError(f'Dynamic source changed: {path}')


class Sources:
    def __init__(self, root):
        self.root, self.raw, self.hashes = root, {}, {}

    def text(self, path):
        if path not in self.raw:
            raw = (self.root / path).read_bytes().replace(b'\r\n', b'\n')
            actual = digest(raw)
            if path in PROVIDERS and actual != PROVIDERS[path]:
                raise ValueError(f'Unreviewed voice provider source: {path}')
            self.raw[path], self.hashes[path] = raw.decode('utf-8-sig'), actual
        return self.raw[path]

    def data(self, path):
        return json.loads(self.text(path))

    def bind(self, path, **location):
        self.text(path)
        return dict(path=path, sha256_lf=self.hashes[path], **location)

    def function(self, path, name):
        source = self.text(path)
        found = re.search(r'(?m)^(?:static )?func ' + re.escape(name) + r'\(', source)
        if not found:
            raise ValueError(f'Missing voice provider function {path}:{name}')
        following = re.search(r'(?m)^(?:static )?func ', source[found.end():])
        end = found.end() + following.start() if following else len(source)
        return source[found.start():end], source[:found.start()].count('\n') + 1

    def match(self, path, function, pattern):
        text, start = self.function(path, function)
        matches = list(re.finditer(pattern, text, re.S))
        if len(matches) != 1:
            raise ValueError(f'Ambiguous voice provider expression {path}:{function}')
        match = matches[0]
        return match, self.bind(path, line=start + text[:match.start()].count('\n'))


def build(root: Path, registry=None):
    root = Path(root)
    sources = Sources(root)
    for path in PROVIDERS:
        sources.text(path)
    if registry is None:
        sources.text('game/data/voice/voice_profiles.json')
        registry = intake.load_profiles(root / 'game/data/voice/voice_profiles.json')
    if isinstance(registry['profiles'], list):
        raise ValueError('Pass the loaded, ID-keyed voice registry')
    rows, recipes, excluded, identities = [], [], {}, {}

    def voice_for(owner, source):
        performance = 'transient_guest_a' if owner == 'transient_guests' else owner
        profile = registry['profiles'].get(performance)
        if not profile or profile.get('delivery') != 'spoken' or not profile.get('reference'):
            reason = 'unknown_or_unapproved_voice' if not profile else 'written_or_reference_required'
            excluded[(owner, source, reason)] = dict(owner_resident_id=owner, source=source, reason=reason)
            return None
        return performance

    def add(owner, runtime, text, namespace, bindings, **extra):
        profile = voice_for(owner, bindings[0]['path'])
        if profile is None:
            return
        if not isinstance(text, str) or not text.strip():
            raise ValueError(f'Empty dynamic speech: {owner}:{runtime}')
        if owner == 'transient_guests' and re.search(r'(?:^|\s)—(?:\s|$)', text):
            reason = 'explicit_guest_turns_required'
            excluded[(owner, runtime, reason)] = dict(owner_resident_id=owner, runtime_node_id=runtime, reason=reason)
            return
        if namespace == 'component':
            kind, _, value = runtime.removeprefix('component:').partition(':')
            extra.update(component_kind=kind, component_value=int(value) if kind == 'ticket' else value or text)
            if kind == 'ticket':
                extra['spoken_form'] = number_words(int(value))
        identity = (owner, profile, namespace, runtime, text)
        if identity in identities:
            row = identities[identity]
            if any(row.get(key) != value for key, value in extra.items()):
                raise ValueError(f'Conflicting dynamic speech metadata: {owner}:{runtime}')
            row['source_bindings'].extend(binding for binding in bindings if binding not in row['source_bindings'])
            return
        row = dict(profile_id=profile, owner_resident_id=owner, runtime_node_id=runtime,
                   namespace=namespace, text=text, text_sha256=digest(text.encode('utf-8')),
                   source_bindings=list(bindings), **extra)
        identities[identity] = row
        rows.append(row)

    # The files with actual door trees determine which dynamic grafts can run.
    base = {}
    for path in sorted((root / 'game/data/dialogue').glob('*.json')):
        relative = path.relative_to(root).as_posix()
        doc = sources.data(relative)
        if not isinstance(doc.get('nodes'), dict):
            continue
        owner = doc.get('meta', {}).get('resident_id', path.stem)
        if voice_for(owner, relative):
            base[owner] = sources.bind(relative, pointer='/meta/resident_id')

    weather_path = 'game/data/weather/resident_weather.json'
    weather_text, _ = sources.function(WEATHER, 'observation')
    fields = re.findall(r'(' + QUOTED + r')\s*:\s*str\(record.get\((' + QUOTED + r'),', weather_text)
    kinds = [json.loads(key) for key, value in fields if json.loads(key) == json.loads(value)]
    if len(set(kinds)) != 8:
        raise ValueError('Unrecognized authored weather conditions')
    match, weather_join_binding = sources.match(WEATHER, 'observation', r'line\s*\+=\s*(' + QUOTED + r')\s*\+\s*str\(record.get\("trend"')
    trend_join = json.loads(match[1])
    match, weather_id_binding = sources.match(WEATHER, 'observation', r'return\s*\{"id":\s*(' + QUOTED + r')')
    weather_template = json.loads(match[1])
    match, _ = sources.match(WEATHER, 'observation', r'(' + QUOTED + r')\s+if trend else\s+""')
    trend_id = json.loads(match[1])
    for index, record in enumerate(sources.data(weather_path)['residents']):
        owner = record['resident_id']
        if owner not in base:
            voice_for(owner, weather_path)
            continue
        for kind in kinds:
            for trend in (False, True):
                text = record[kind] + (trend_join + record['trend'] if trend else '')
                bindings = [sources.bind(weather_path, pointer=f'/residents/{index}/{kind}'), weather_id_binding]
                if trend:
                    bindings += [sources.bind(weather_path, pointer=f'/residents/{index}/trend'), weather_join_binding]
                add(owner, weather_template % (owner, '<chapter_snake>', kind, trend_id if trend else ''),
                    text, 'weather', bindings, runtime_node_is_pattern=True,
                    source_admissible_only=True)

    match, music_binding = sources.match(MUSIC, 'anecdote', r'words\s*\+=\s*(' + QUOTED + r')\s*\+\s*str\(resident.get\("gift_line"')
    music_join = json.loads(match[1])
    music_path = 'game/data/music_catalog.json'
    for owner, record in sources.data(music_path)['residents'].items():
        for resolved in (False, True):
            text = record['anecdote'] + (music_join + record['gift_line'] if resolved else '')
            pointers = [f'/residents/{owner}/anecdote', f'/residents/{owner}/favorite']
            if resolved:
                pointers.append(f'/residents/{owner}/gift_line')
            add(owner, 'music:' + record['favorite'], text, 'music',
                [sources.bind(music_path, pointer=p) for p in pointers] + [music_binding])

    # Read every spoken template from the actual consumer, not a duplicate script.
    errand = {}
    for constant in ('ERRAND_ASK', 'ERRAND_THANKS', 'ERRAND_WAIT'):
        match, binding = sources.match(CONVERSATIONS, 'with_errand',
            r'node_id\s*=\s*' + constant + r'\s*\n\s*line\s*=\s*(' + QUOTED + r')')
        errand[constant] = (json.loads(match[1]), binding)
    parcel = {}
    for constant in ('PARCEL_ASK', 'PARCEL_THANKS', 'PARCEL_WAIT'):
        match, binding = sources.match(CONVERSATIONS, 'with_parcel', constant + r',\s*(' + QUOTED + r')')
        parcel[constant] = (json.loads(match[1]), binding)
    match, gift_binding = sources.match(CONVERSATIONS, 'with_gifts', r'"line"\s*:\s*(' + QUOTED + r')')
    gift_words = json.loads(match[1])
    match, list_binding = sources.match(ERRANDS, 'list_words', r'return\s+(' + QUOTED + r')\.join\(names\)')
    list_separator = json.loads(match[1])
    list_limit = int(re.search(r'(?m)^const LIST_LIMIT := (\d+)', sources.text(ERRANDS))[1])

    def split_suffix(template, token):
        if template.count(token) != 1:
            raise ValueError('Unrecognized dynamic speech template')
        prefix, after = template.split(token)
        punctuation = re.match(r'[^\w]*', after)[0]
        suffix = after[len(punctuation):]
        if not suffix:
            raise ValueError('Dynamic suffix has no spoken words')
        return prefix, punctuation, suffix

    errand_template, errand_binding = errand['ERRAND_ASK']
    empty, errand_before_suffix, errand_suffix = split_suffix(errand_template, '%s')
    if empty:
        raise ValueError('Grocery template unexpectedly has an introductory phrase')
    ask_template, ask_binding = parcel['PARCEL_ASK']
    ask_prefix, ask_before_suffix, ask_suffix = split_suffix(ask_template, '%d')
    ask_prefix_words = ask_prefix.rstrip()
    ask_before_number = ask_prefix[len(ask_prefix_words):]
    wait_template, wait_binding = parcel['PARCEL_WAIT']
    empty, wait_before_suffix, wait_suffix = split_suffix(wait_template, '%d')
    if empty:
        raise ValueError('Parcel wait template unexpectedly has a prefix')

    cookbook_path, grocery_path = 'game/data/kitchen/cookbook.json', 'game/data/kitchen/groceries.json'
    groceries = sources.data(grocery_path)
    for index, dish in enumerate(sources.data(cookbook_path)['dishes']):
        owner = dish['resident']
        if owner not in base:
            continue
        ingredients = sorted({row[0] for row in dish['ingredients']} |
                             set(groceries['household']['lighting']) | set(groceries['household']['washing_up']))
        bindings = [sources.bind(cookbook_path, pointer=f'/dishes/{index}/ingredients'),
                    sources.bind(grocery_path, pointer='/household/lighting'),
                    sources.bind(grocery_path, pointer='/household/washing_up'), list_binding, errand_binding]
        domain = []
        for item in ingredients:
            if item not in groceries['ingredients']:
                raise ValueError(f'Unknown grocery ingredient {item}')
            runtime = 'component:ingredient:' + item
            binding = sources.bind(grocery_path, pointer='/ingredients/' + item + '/name')
            add(owner, runtime, groceries['ingredients'][item]['name'], 'component', [binding] + bindings)
            domain.append(dict(ingredient_id=item, runtime_node_id=runtime,
                               display_name=groceries['ingredients'][item]['name']))
        add(owner, 'component:errand_suffix', errand_suffix, 'component', [errand_binding])
        for constant, runtime in [('ERRAND_THANKS', 'errand:thanks'), ('ERRAND_WAIT', 'errand:wait')]:
            text, binding = errand[constant]
            add(owner, runtime, text, 'errand', [binding, base[owner]])
        recipes.append(dict(kind='grocery_list', owner_resident_id=owner, profile_id=voice_for(owner, cookbook_path),
            runtime_node_id='errand:ask', ingredient_components=domain, sort_by='ingredient_id',
            max_items=list_limit, join=list_separator, before_suffix=errand_before_suffix,
            suffix_component='component:errand_suffix', format_string=errand_template,
            source_bindings=bindings))

    # The ticket function and its actual selectable wall domain provide numbers.
    parcel_source = sources.text(PARCELS)
    constants = {name: int(value) for name, value in re.findall(r'(?m)^const (\w+) := (\d+)', parcel_source)}
    match, ticket_binding = sources.match(PARCELS, 'ticket',
        r'return (\d+) \+ \(\(int\(at\[0\]\) \* COLUMNS \+ int\(at\[1\]\)\) \* (\d+)\) % \(ROWS \* COLUMNS\) \* (\d+)')
    origin, multiplier, step = map(int, match.groups())
    _, chosen_binding = sources.match(PARCELS, 'chosen',
        r'for row in range\(FIRST_TICKET_ROW, UNCLAIMED_ROW\):\s*for column in COLUMNS:')
    tickets = []
    for row in range(constants['FIRST_TICKET_ROW'], constants['UNCLAIMED_ROW']):
        for column in range(constants['COLUMNS']):
            value = origin + (((row * constants['COLUMNS'] + column) * multiplier) %
                              (constants['ROWS'] * constants['COLUMNS'])) * step
            tickets.append(dict(parcel_id=f'{row}_{column}', ticket=value,
                                runtime_node_id=f'component:ticket:{value}'))
    if len({item['ticket'] for item in tickets}) != len(tickets):
        raise ValueError('Parcel ticket numbers collide')
    for owner in sorted(base):
        add(owner, 'parcel:thanks', parcel['PARCEL_THANKS'][0], 'parcel', [parcel['PARCEL_THANKS'][1], base[owner]])
        for runtime, text, binding in [('component:parcel_ask_prefix', ask_prefix_words, ask_binding),
                                       ('component:parcel_ask_suffix', ask_suffix, ask_binding),
                                       ('component:parcel_wait_suffix', wait_suffix, wait_binding)]:
            add(owner, runtime, text, 'component', [binding, ticket_binding, chosen_binding])
        for ticket in tickets:
            add(owner, ticket['runtime_node_id'], str(ticket['ticket']), 'component', [ticket_binding, chosen_binding])
        recipes.append(dict(kind='parcel_ticket', owner_resident_id=owner,
            profile_id=voice_for(owner, PARCELS), ticket_components=tickets,
            ask=dict(runtime_node_id='parcel:ask', format_string=ask_template,
                     prefix_component='component:parcel_ask_prefix', before_number=ask_before_number,
                     before_suffix=ask_before_suffix, suffix_component='component:parcel_ask_suffix'),
            wait=dict(runtime_node_id='parcel:wait', format_string=wait_template,
                      before_suffix=wait_before_suffix, suffix_component='component:parcel_wait_suffix'),
            source_bindings=[ticket_binding, chosen_binding, ask_binding, wait_binding]))

    shop_path = 'game/scripts/game/shop_catalogue.gd'
    shop_block = re.search(r'const PATHS:.*?=\s*\[(.*?)\]', sources.text(shop_path), re.S)[1]
    for shop in re.findall(r'"res://([^\"]+\.json)"', shop_block):
        shop = 'game/' + shop
        for index, item in enumerate(sources.data(shop)['items']):
            if item.get('gift') is not True:
                continue
            for owner in sorted(base):
                add(owner, 'gift:' + item['id'], gift_words, 'gift',
                    [gift_binding, sources.bind(shop, pointer=f'/items/{index}/gift'), base[owner]])

    for function, runtime, carrier in [('answer_incoming_call', 'service:call', 'service_set_remote_call'),
                                       ('_present_threshold', 'service:threshold', 'resident_3d'),
                                       ('_present_return', 'service:return', 'resident_3d')]:
        match, binding = sources.match(SERVICE, function,
            r'dialogue.present\(' + QUOTED + r',\s*(' + QUOTED + r')')
        add('lena_ortiz', runtime, json.loads(match[1]), 'service_round', [binding],
            requires_runtime_present_key=True, carrier=carrier)

    document = dict(schema_version=1, source_bindings=sources.hashes, supplemental_rows=rows,
                    component_recipes=recipes, excluded=list(excluded.values()),
                    editorial_guest_performance=dict(owner_resident_id='transient_guests',
                        profile_id='transient_guest_a', scope='Generic single-speaker dynamic pieces only; mixed exchanges need explicit turns.'))
    verify_sources(root, document)
    return document


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, default=intake.ROOT)
    parser.add_argument('--out', type=Path, required=True)
    args = parser.parse_args()
    document = build(args.root)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    pending = args.out.with_suffix(args.out.suffix + '.pending')
    pending.write_text(json.dumps(document, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    os.replace(pending, args.out)
    print(json.dumps(dict(rows=len(document['supplemental_rows']), component_recipes=len(document['component_recipes']))))


if __name__ == '__main__':
    main()
