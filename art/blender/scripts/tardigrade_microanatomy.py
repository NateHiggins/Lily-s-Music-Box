"""Deterministic nested tissue; uses the existing tardigrade pose/foot authority.

Roles are encoded in Anatomy.R only for species 3. G is authored optical
thickness (thinness); B retains the existing skin/internal/cilium ABI.
"""
import math
import random


def append(api, objects, collection, lod, seed):
    rng = random.Random(seed + 881)
    detail = 2 if lod == 0 else 1

    def blob(name, center, radius, role, resolution=None):
        obj = api.make_object(name, api.ellipsoid_cage(center, radius, seed + len(objects), resolution if resolution is not None else (1 if role in (5,8) else detail)), collection, 0, "external_organ" if role == 8 else "internal_organ")
        obj["micro_role"] = role
        objects.append(obj)
        return obj

    def strand(name, points, radius, role):
        obj = api.make_object(name, api.tube_cage(points, [radius * (1 - .65 * i / (len(points)-1)) for i in range(len(points))], 5), collection, 0, "cilia" if role == 7 else "internal_organ")
        obj["micro_role"] = role
        objects.append(obj)
        return obj

    for obj in objects:
        obj["micro_role"] = 0 if obj.name == "Skin" else 4
        if obj.name.startswith("StorageCell"): obj["micro_role"] = 2
        if obj.name.startswith("Stylet"): obj["micro_role"] = 6
        if obj.name.startswith("Claw"): obj["micro_role"] = 6
    blob("IrregularNucleus", (-.075, -.085, -.095), (.105, .115, .135), 1)
    blob("GerminalMass", (.11, -.09, -.22), (.12, .09, .10), 1)
    for i, p in enumerate([(-.18, .11, .11), (.19, -.10, -.08)]):
        blob("StorageVacuole_%d" % i, p, (.08, .095, .11), 2)
    for i, p in enumerate([(-.11, .17, -.17), (.14, .13, .20)]):
        blob("ContractileSac_%d" % i, p, (.085, .055, .065), 3)
    # Branching, discontinuous mineral filaments at three anatomical depths.
    for band, x in enumerate([-.21, .015, .20]):
        for j in range(3 if lod == 0 else 1):
            z = -.27 + j * .17
            points = [(x + .018*math.sin(k*1.7+j), -.035 + band*.055 + .025*math.sin(k), z+k*.025) for k in range(5)]
            strand("Conduction_%d_%d" % (band, j), points, .0035, 6)
            strand("ConductionBranch_%d_%d" % (band, j), [points[2], (x+.045, points[2][1]+.015, z+.08), (x+.065, points[2][1]+.03, z+.09)], .0025, 6)
    # Paired dorsal brain lobes and a ventral ganglion chain, separated from
    # the fictional mineral conduction network (Mayer et al. 2013/2014).
    for side in (-1, 1):
        blob("BrainLobe_%d" % side, (side*.047, .08, .27), (.036,.025,.038), 1, 1)
    if lod == 0:
        for i, z in enumerate((-.22,-.07,.08,.23)):
            blob("VentralGanglion_%d" % i, (0,-.13,z), (.023,.016,.027), 5)
        for side in (-1, 1):
            for i in range(4):
                z = -.22+i*.14
                strand("SomaticMuscle_%d_%d" % (side,i),
                       [(side*.12,-.07,z), (side*.19,-.035,z+.025),
                        (side*.26,-.09,z+.055)], .004, 3)
    for i in range(6 if lod == 0 else 0):
        p = (rng.uniform(-.24,.24), rng.uniform(-.17,.17), rng.uniform(-.30,.30))
        blob("SuspendedGranule_%02d" % i, p, (.009,.012,.008), 5)
    # Surface-rooted fibers obtained from actual evaluated skin vertices.
    skin = objects[0]
    candidates = [api.gd(v.co) for v in skin.data.vertices if api.gd(v.co).z > .32 or (api.gd(v.co).y > .13 and abs(api.gd(v.co).z-.2)<.055)]
    for i in range(40 if lod == 0 else 4):
        p = candidates[i * len(candidates)//(40 if lod == 0 else 4)]
        direction = p.normalized()
        points = [p + direction * (.027*k/3) + api.Vector((.004*math.sin(k),0,0)) for k in range(4)]
        strand("SensoryCilium_%02d" % i, points, .0019, 7)
    # Separate meniscus pools: sparse and flattened, not a duplicate plastic shell.
    for i in range(8 if lod == 0 else 2):
        p=candidates[i*len(candidates)//8]
        blob("WetMeniscus_%02d" % i, p, (.006,.002,.008), 8)


def semantics(obj, point, window):
    role = obj.get("micro_role", 0)
    # Unequal reserve folds and thick joint collars; never a light scalar.
    if role == 0:
        window = .35 + .5 * math.exp(-((point.y-.06)/.27)**2)
        window *= .65 + .35 * math.sin(point.z*29 + point.x*3)**2
    return role / 10., window, 4 if role >= 7 else (1 if role == 0 else 2)
