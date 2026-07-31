"""Generate the complete Orison resident cast through the shared IK pipeline."""
import json
import os
import subprocess
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
BLENDER = os.environ.get(
    "ORISON_BLENDER",
    r"C:\Program Files\Blender Foundation\Blender 3.6\blender.exe")
GENERATOR = os.path.join(ROOT, "tools", "generate_mina_character.py")


def profile(slug, display, prefix, trait, palette, motion, body):
    return {
        "slug": slug, "display": display, "prefix": prefix, "trait": trait,
        "palette": palette, "motion": motion, "body": body,
    }


def pal(skin, hair, outer, shirt, trousers, shoes):
    return dict(skin=skin, hair=hair, outer=outer, shirt=shirt,
                trousers=trousers, shoes=shoes)


def mot(sway, glance, hand, posture, stride, lift, bounce, arm):
    return dict(sway=sway, glance=glance, hand=hand, posture=posture,
                stride=stride, lift=lift, bounce=bounce, arm=arm)


CAST = [
 profile("evelyn_marsh", "Evelyn Marsh", "Evelyn",
  "Corrects invisible papers; walks with controlled teacherly precision.",
  pal([.55,.35,.24],[.20,.17,.15],[.29,.20,.15],[.72,.62,.42],[.12,.10,.09],[.25,.12,.07]),
  mot(.35,.55,1.65,-.15,.72,.55,.45,.42), dict(height=.96,width=1.05,head=.95)),
 profile("teresa_vale", "Teresa Vale", "Teresa",
  "Tired triage posture and careful steps that anticipate the next alarm.",
  pal([.43,.25,.16],[.08,.07,.065],[.16,.27,.30],[.58,.66,.62],[.08,.11,.12],[.18,.20,.18]),
  mot(.55,.32,.62,.8,.62,.42,.28,.38), dict(height=.98,width=1.10,head=1.0)),
 profile("mina_vale", "Mina Vale", "Mina",
  "Furtive glances, captioning hands, and a quick self-conscious pace.",
  pal([.42,.225,.14],[.018,.026,.035],[.035,.16,.17],[.58,.34,.055],[.055,.06,.072],[.36,.055,.045]),
  mot(1,1,1,0,1,1,1,1), dict(height=1,width=1,head=1)),
 profile("lena_ortiz", "Lena Ortiz", "Lena",
  "Hands continually stitch and mend; her walk carries everyone else's weight.",
  pal([.48,.25,.15],[.10,.045,.025],[.38,.09,.10],[.78,.53,.35],[.14,.09,.08],[.32,.12,.09]),
  mot(.42,.35,2.0,.55,.74,.62,.55,.48), dict(height=.94,width=1.08,head=1.0)),
 profile("juno_kells", "Juno Kells", "Juno",
  "Keeps an internal beat with asymmetric hands and a syncopated stride.",
  pal([.31,.17,.12],[.025,.02,.045],[.20,.08,.34],[.10,.47,.52],[.045,.035,.06],[.48,.18,.07]),
  mot(1.35,.85,1.8,-.35,1.18,1.15,1.45,1.55), dict(height=1.02,width=.92,head=.96)),
 profile("malcolm_reed", "Malcolm Reed", "Malcolm",
  "Gentle plant-tending hands and a rooted, grief-heavy walk.",
  pal([.32,.19,.12],[.055,.045,.035],[.10,.24,.12],[.55,.46,.23],[.10,.12,.09],[.24,.18,.08]),
  mot(.72,.38,1.25,.35,.68,.48,.32,.55), dict(height=1.05,width=1.12,head=1.02)),
 profile("omar_bell", "Omar Bell", "Omar",
  "Checks an imaginary tool in each hand; walks like every step needs repair.",
  pal([.46,.27,.16],[.035,.03,.025],[.18,.20,.21],[.62,.37,.10],[.08,.09,.10],[.24,.20,.12]),
  mot(.28,.52,1.75,.15,.82,.58,.48,.66), dict(height=1.01,width=1.15,head=.96)),
 profile("rhea_sato", "Rhea Sato", "Rhea",
  "Controlled singer's breathing gives way to expressive, performance-sized motion.",
  pal([.58,.36,.24],[.025,.022,.025],[.30,.055,.16],[.70,.48,.58],[.08,.055,.075],[.30,.07,.14]),
  mot(1.12,.64,1.38,-.25,1.0,.85,1.22,1.42), dict(height=.97,width=.94,head=1.0)),
 profile("peter_wren", "Peter Wren", "Peter",
  "Nervous form-straightening gestures and small uncertain steps.",
  pal([.60,.39,.27],[.16,.12,.09],[.20,.24,.30],[.70,.70,.64],[.10,.12,.16],[.18,.12,.09]),
  mot(.22,1.45,1.62,.42,.56,.38,.25,.30), dict(height=1.04,width=.90,head=.98)),
 profile("cam_ortiz", "Cam Ortiz", "Cam",
  "Never fully stops moving; fast courier stride with high feet and restless bounce.",
  pal([.46,.24,.14],[.045,.028,.018],[.48,.15,.055],[.76,.56,.12],[.07,.09,.10],[.55,.12,.04]),
  mot(1.75,1.25,1.35,-.55,1.45,1.65,1.65,1.65), dict(height=1.0,width=.91,head=.95)),
 profile("noel_price", "Noel Price", "Noel",
  "Museum-handler stillness, precise hands, and artifact-safe measured steps.",
  pal([.36,.21,.14],[.08,.065,.05],[.18,.15,.12],[.62,.58,.46],[.10,.09,.08],[.20,.16,.10]),
  mot(.16,.28,.52,.05,.50,.32,.18,.22), dict(height=.99,width=.93,head=.96)),
 profile("transient_guests", "Transient Guests", "Guests",
  "Jet-lagged swaying and hesitant steps as if the room assignment keeps changing.",
  pal([.52,.31,.20],[.11,.08,.055],[.22,.25,.34],[.67,.42,.28],[.09,.10,.15],[.28,.18,.12]),
  mot(1.65,1.65,.75,.72,.70,.85,.82,.45), dict(height=1.02,width=1.03,head=1.02)),
 profile("nadia_quell", "Nadia Quell", "Nadia",
  "Drafting-square hand motions and angular, code-compliant strides.",
  pal([.47,.28,.18],[.03,.025,.02],[.08,.19,.30],[.72,.60,.22],[.06,.08,.12],[.18,.22,.24]),
  mot(.24,.72,1.55,-.2,.88,.58,.42,.72), dict(height=1.03,width=.91,head=.95)),
 profile("cal_dwyer", "Cal Dwyer", "Cal",
  "Head cocks toward unheard broadcasts while the body walks half a beat late.",
  pal([.63,.42,.29],[.20,.16,.11],[.24,.18,.11],[.42,.49,.37],[.11,.10,.08],[.22,.16,.08]),
  mot(.82,1.85,.46,.48,.78,.52,.62,.32), dict(height=1.06,width=1.06,head=1.0)),
 profile("iris_bell", "Iris Bell", "Iris",
  "Paints in the air with broad wrists; walks with color-seeking lateral sway.",
  pal([.38,.20,.13],[.075,.025,.05],[.31,.09,.28],[.14,.48,.51],[.07,.055,.09],[.46,.20,.10]),
  mot(1.42,.92,2.1,-.42,1.02,.96,1.22,1.72), dict(height=.98,width=.98,head=1.04)),
 profile("sacha_reed", "Sacha Reed", "Sacha",
  "Camera-steady hands and evidence-scanning head turns; purposeful witness stride.",
  pal([.34,.18,.12],[.025,.022,.02],[.13,.16,.18],[.50,.42,.30],[.055,.065,.075],[.18,.14,.10]),
  mot(.20,1.65,.40,-.15,1.08,.72,.48,.28), dict(height=1.02,width=.95,head=.96)),
 profile("jonah_price", "Jonah Price", "Jonah",
  "Writes, pauses, and loses the next word; a soft interrupted walk.",
  pal([.57,.36,.24],[.12,.075,.045],[.17,.24,.23],[.68,.56,.39],[.10,.11,.10],[.24,.17,.10]),
  mot(.62,1.12,1.82,.58,.64,.46,.30,.52), dict(height=1.0,width=.96,head=1.02)),
 profile("mae_kessler", "Mae Kessler", "Mae",
  "Guarded archive handling and an exact, provenance-conscious walk.",
  pal([.49,.29,.19],[.08,.06,.045],[.20,.12,.18],[.55,.46,.37],[.075,.065,.08],[.20,.12,.10]),
  mot(.12,.48,.68,.22,.54,.34,.20,.26), dict(height=.96,width=.90,head=.97)),
]


def main():
    if not os.path.exists(BLENDER):
        raise SystemExit(f"Blender not found: {BLENDER}")
    manifest = []
    for character in CAST:
        env = os.environ.copy()
        env["ORISON_CHARACTER_CONFIG"] = json.dumps(character)
        print(f"Generating {character['display']}...")
        subprocess.run(
            [BLENDER, "--background", "--python", GENERATOR],
            cwd=ROOT, env=env, check=True)
        manifest.append(character)
    manifest_path = os.path.join(
        ROOT, "game", "data", "resident_animation_profiles.json")
    with open(manifest_path, "w", encoding="utf-8") as handle:
        json.dump(manifest, handle, indent=2)
    print(f"Generated {len(CAST)} resident characters.")


if __name__ == "__main__":
    main()
