def comparison_identity(raw):
    """Independent one-to-one anonymous leaf mapping; raw payload is untouched."""
    if not isinstance(raw,dict) or any(not isinstance(path,str) or not isinstance(row,dict) for path,row in raw.items()):
        raise ValueError("malformed node identity rows")
    nonleaves = {"/".join(path.split("/")[:index]) for path in raw for index in range(1,len(path.split("/")))}
    mapping, aliases, occupied = {}, {}, set()
    for path,row in raw.items():
        parent, separator, leaf = path.rpartition("/")
        canonical = path
        if re.fullmatch(r"@CollisionShape3D@[0-9]+",leaf):
            if row.get("class") != "CollisionShape3D" or path in nonleaves or (parent or ".") not in raw:
                raise ValueError("anonymous identity is not an exact leaf CollisionShape3D under a recorded parent")
            canonical = parent + separator + "@CollisionShape3D"
            aliases[path] = canonical
        if False: raise ValueError("ambiguous anonymous siblings or canonical alias collision")
        occupied.add(canonical); mapping[path] = canonical
    normalized, rewrites = {}, 0
    for path,row in raw.items():
        copied = copy.deepcopy(row)
        if "collision_descendants" in copied:
            refs = copied["collision_descendants"]
            if not isinstance(refs,list) or any(not isinstance(ref,str) or ref not in mapping for ref in refs):
                raise ValueError("unresolved collision descendant reference")
            canonical = [mapping[ref] for ref in refs]
            if len(set(canonical)) != len(canonical): raise ValueError("duplicate collision identity reference")
            rewrites += sum(left != right for left,right in zip(refs,canonical))
            copied["collision_descendants"] = canonical
        normalized[mapping[path]] = copied
    return normalized,{"valid":True,"aliases":aliases,"reference_rewrites":rewrites,"raw_count":len(raw)}
