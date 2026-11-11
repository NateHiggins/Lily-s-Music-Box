"""Freeze authored speech and its runtime identities without changing dialogue."""
from __future__ import annotations
import hashlib
import json
from pathlib import Path
import re

import intake


def text_hash(text):
    return hashlib.sha256(text.encode('utf-8')).hexdigest()


def pointer_token(value):
    return str(value).replace('~', '~0').replace('/', '~1')


def safe_node(value):
    # Keep authored safe IDs readable. Encode punctuation injectively; never
    # collapse distinct runtime IDs by replacing every separator with '_'.
    if intake.TOKEN.fullmatch(value) and not value.startswith('encoded_'):
        return value
    return 'encoded_' + value.encode('utf-8').hex()


def build(root: Path, registry: dict, guest_map=None, extra_rows=()):
    rows, bindings = [], {}
    speakers = {p['display_name'].casefold(): key for key, p in registry['profiles'].items()}
    speakers.update(nadia='nadia_quell', adela='adela_voss', guests='transient_guests')
    guest_entries = {(row['source'], row['pointer']): row for row in (guest_map or {}).get('entries', [])}

    def add(source, pointer, namespace, runtime_node, profile_id, text, node=None, identity=None):
        if not isinstance(text, str) or not text.strip():
            raise ValueError(f'Empty speech field {source}:{pointer}')
        relative = source.relative_to(root).as_posix()
        bindings[relative] = intake.fingerprint(source)
        owner_resident_id = profile_id
        if node and 'speaker' in node:
            profile_id = speakers.get(node['speaker'].casefold(), 'unmapped_speaker')
        profile = registry['profiles'].get(profile_id)
        state = 'ready'
        if not any(char.isalnum() for char in text):
            state = 'silent'
        elif node and node.get('spoken') is False:
            state = 'written'
        elif node and node.get('delivery') in ('written', 'silent'):
            state = node['delivery']
        elif not profile:
            state = 'recorded_scene_required' if node and node.get('speaker') == 'THE REEL' else 'unmapped'
        elif profile['delivery'] != 'spoken':
            state = profile['delivery']
        elif not profile.get('reference') and not profile.get('variants'):
            state = 'reference_required'
        identity = identity or intake.line_id(namespace, safe_node(runtime_node))
        row = dict(line_id=identity, namespace=namespace, runtime_node_id=runtime_node,
                   profile_id=profile_id, owner_resident_id=owner_resident_id, source=relative, pointer=pointer, text=text,
                   text_sha256=text_hash(text), state=state, segments=[])
        if state == 'ready' and profile.get('variants'):
            mapped = guest_entries.get((relative, pointer))
            if mapped is None:
                row['state'] = 'turn_map_required'
            else:
                if mapped['text_sha256'] != row['text_sha256']:
                    raise ValueError(f'Stale guest turns: {identity}')
                previous_end = 0
                for i, turn in enumerate(mapped['turns']):
                    voice = turn['profile_id']
                    if voice not in profile['variants']:
                        raise ValueError(f'Unexpected guest voice: {voice}')
                    start, end = turn['start'], turn['end']
                    if type(start) is not int or type(end) is not int or not previous_end <= start < end <= len(text):
                        raise ValueError(f'Invalid guest offsets: {identity}')
                    if any(char.isalnum() for char in text[previous_end:start]):
                        raise ValueError(f'Omitted guest words: {identity}')
                    excerpt = text[turn['start']:turn['end']]
                    if not excerpt.strip():
                        raise ValueError(f'Empty guest turn: {identity}')
                    row['segments'].append(dict(part_id=identity + f'_turn_{i:03d}',
                        profile_id=voice, text=excerpt, start_char=turn['start'], end_char=turn['end']))
                    previous_end = end
                if any(char.isalnum() for char in text[previous_end:]):
                    raise ValueError(f'Omitted guest words: {identity}')
        elif state == 'ready':
            row['segments'] = [dict(part_id=identity, profile_id=profile_id, text=text,
                                    start_char=0, end_char=len(text))]
        rows.append(row)

    for directory, prefix in [('dialogue', ''), ('mystery', 'mystery_')]:
        for source in sorted((root/'game/data'/directory).glob('*.json')):
            doc = intake.read_json(source)
            if not isinstance(doc.get('nodes'), dict):
                continue
            profile = doc.get('meta', {}).get('resident_id', source.stem)
            for node_id, node in sorted(doc['nodes'].items()):
                if 'line' in node:
                    add(source, '/nodes/' + pointer_token(node_id) + '/line', prefix + source.stem,
                        node_id, profile, node['line'], node)
    source = root/'game/data/case01_dialogue.json'
    for node_id, node in sorted(intake.read_json(source)['nodes'].items()):
        add(source, '/nodes/' + pointer_token(node_id) + '/line', 'case01_dialogue',
            node_id, 'mina_vale', node['line'], node)
    for source in sorted((root/'game/data/opinions').glob('*.json')):
        doc = intake.read_json(source)
        profile = doc['resident_id']
        namespace = 'opinion_' + source.stem
        if doc.get('hook_line'):
            add(source, '/hook_line', namespace, 'op_menu', profile, doc['hook_line'])
        for i, opinion in enumerate(doc['opinions']):
            base = '/opinions/' + str(i)
            runtime = 'op:' + opinion['id']
            add(source, base + '/line', namespace, runtime, profile, opinion['line'])
            if opinion.get('silence_reply'):
                add(source, base + '/silence_reply', namespace, runtime + ':s', profile, opinion['silence_reply'])
            for j, choice in enumerate(opinion.get('choices', [])):
                add(source, base + '/choices/' + str(j) + '/reply', namespace,
                    runtime + ':r' + str(j), profile, choice['reply'])
    for row in extra_rows:
        sources = row['source_bindings']
        for binding in sources:
            source = root/binding['path']
            actual = hashlib.sha256(source.read_bytes().replace(b'\r\n', b'\n')).hexdigest()
            if actual != binding['sha256_lf']:
                raise ValueError(f'Stale supplemental speech source: {source}')
            bindings[binding['path']] = intake.fingerprint(source)
        token = text_hash(row['namespace'] + '\0' + row['runtime_node_id'] + '\0' + row['text'])
        identity = intake.line_id('dynamic_' + row['profile_id'], 'entry_' + token)
        add(root/sources[0]['path'], sources[0].get('pointer', 'line:' + str(sources[0].get('line', ''))),
            row['namespace'], row['runtime_node_id'], row['profile_id'], row['text'], identity=identity)
        rows[-1]['runtime_node_is_pattern'] = row.get('runtime_node_is_pattern', False)
        rows[-1]['source_bindings'] = sources
    identities = [row['line_id'] for row in rows]
    if len(set(identities)) != len(identities):
        raise ValueError('Duplicate production speech identity')
    return dict(schema_version=1, source_bindings=bindings, lines=rows)


def verify_sources(root: Path, document):
    for relative, digest in document['source_bindings'].items():
        if intake.fingerprint(root/relative) != digest:
            raise ValueError(f'Frozen speech source changed: {relative}')


def freeze(root: Path, case: Path, extra_rows=()):
    profiles_path = root/'game/data/voice/voice_profiles.json'
    registry = intake.load_profiles(profiles_path)
    guest_path = root/'game/data/voice/guest_turns.json'
    guests = intake.read_json(guest_path) if guest_path.exists() else None
    document = build(root, registry, guests, extra_rows)
    document['source_bindings']['game/data/voice/voice_profiles.json'] = intake.fingerprint(profiles_path)
    if guests:
        document['source_bindings']['game/data/voice/guest_turns.json'] = intake.fingerprint(guest_path)
    case.mkdir(parents=True, exist_ok=True)
    target = case/'catalog.json'
    if target.exists():
        raise ValueError(f'Frozen catalog already exists: {target}')
    target.write_text(json.dumps(document, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    (case/'profiles.json').write_bytes(profiles_path.read_bytes())
    return document
