"""Fills in Buff Me Please's missing accent lines with AccentTranslator's rules.py: the same word swaps and spelling
rules EzAccent speaks with in game (its Rules.lua is generated from rules.py). No model, so it's quick, and each line
is seeded by its own text: a rerun gives the same lines.

Hand-written sets (Voices<Accent>.lua):
- undead (a locked jaw) and jawless (undead with no jaw, rules.py's thick undead) have no hand-written lines, so
  VoicesUndead.lua and VoicesJawless.lua are written whole from Voices.lua. Don't edit them: edit Voices.lua and rerun.
- orc, troll and dwarf only get the lines they lack (same personality, kind and place as in Voices.lua); a file
  with nothing missing is left alone.

Generated lines (tools/generated.json -> Generated.lua, your install only, when generated.json exists):
- orc, troll and dwarf: the model's translations leave out lines that broke a rule, so each pool is lined up with
  its plain lines (in order, by likeness) and the plain lines with no translation get one by the rules.
- undead and jawless: every pool is rewritten from the plain lines (and your personalities' seed lines).

    python tools/rules_accents.py                  # everything
    python tools/rules_accents.py --accent undead  # just some accents (comma-separated)
    python tools/rules_accents.py --check          # say what's missing, write nothing

Needs ../AccentTranslator (rules.py) next to this addon. After editing rules.py, rerun this (and EzAccent's
tools/gen_rules.py).
"""
import argparse
import difflib
import json
import random
import sys
from pathlib import Path

import generate as gen

sys.path.insert(0, str(gen.ROOT.parent / "AccentTranslator"))
import rules  # noqa: E402

# Buff Me Please accent -> rules.py accent and thick.
ACCENTS = {"orc": ("orc", False), "troll": ("troll", False), "dwarf": ("dwarf", False),
           "undead": ("undead", False), "jawless": ("undead", True)}
# Accents with no lines of their own (hand-written or from the model): rewritten whole every run.
RULES_ONLY = ("undead", "jawless")
FILES = {**{a: f for a, f in gen.SOURCES.items() if a != "plain"},
         "undead": "VoicesUndead.lua", "jawless": "VoicesJawless.lua"}
HEADERS = {
    "undead": "-- Buff Me Please lines with an undead accent, a locked jaw that squeezes every vowel: one variant for\n"
              "-- every line in Voices.lua, same personalities, kinds and order (see the placeholders there).\n",
    "jawless": "-- Buff Me Please lines with an undead accent, no jaw at all (no lip sounds, slushy s and th): one\n"
               "-- variant for every line in Voices.lua, same personalities, kinds and order (see the placeholders\n"
               "-- there).\n",
}
GENERATED_BY = ("-- Written by tools/rules_accents.py with AccentTranslator's rules (the ones EzAccent speaks with):\n"
                "-- don't edit by hand, edit Voices.lua and rerun it.\n")
# Tries at a line before giving up on it; each try is seeded differently.
TRIES = 30
# Below this likeness (difflib ratio, 0-1) a model translation is never taken for a plain line's.
MATCH = 0.15


def say(accent, line, kind):
    """line in the accent by the rules, or None when no try keeps to generate.py's rules (any rule the plain line
    itself already breaks, like a hand-written "a {buff}", doesn't count)."""
    voice, thick = ACCENTS[accent]
    own = gen.clean(line, kind, "plain")[1]
    for n in range(TRIES):
        out = rules.accented(voice, line, thick, random.Random(f"{accent}|{line}|{n}"))
        if accent == "dwarf":
            out = gen.lad(out)
        why = gen.clean(out, kind, accent)[1]
        if why in (None, own) and gen.norm(out) != gen.norm(line) and all(
                out.count("{%s}" % k) == line.count("{%s}" % k) for k in gen.KEPT):
            return out
    return None


def align(source, translated):
    """source index -> translated index. translate_pool keeps the source's order and only leaves lines out, so this
    is the in-order pairing with the most likeness in all."""
    n, m = len(source), len(translated)
    a, b = [gen.norm(s) for s in source], [gen.norm(t) for t in translated]
    score = [[0.0] * (m + 1) for _ in range(n + 1)]
    step = [[None] * (m + 1) for _ in range(n + 1)]
    for i in range(n + 1):
        for j in range(m + 1):
            best = None
            if i:
                best = (score[i - 1][j], "skip source")
            if j and (best is None or score[i][j - 1] > best[0]):
                best = (score[i][j - 1], "skip translated")
            if i and j:
                r = difflib.SequenceMatcher(None, a[i - 1], b[j - 1]).ratio()
                if r >= MATCH and score[i - 1][j - 1] + r > best[0]:
                    best = (score[i - 1][j - 1] + r, "pair")
            if best:
                score[i][j], step[i][j] = best
    pairs, i, j = {}, n, m
    while i or j:
        s = step[i][j]
        if s == "pair":
            pairs[i - 1] = j - 1
        i, j = (i - 1, j - 1) if s == "pair" else (i - 1, j) if s == "skip source" else (i, j - 1)
    return pairs


def lua_voices(accent, header, voices):
    out = [header + "local _, ns = ...\n\n" + f"ns.ACCENT_VOICES.{accent} = {{\n"]
    blocks = []
    for persona, pools in voices.items():
        block = [f"{persona} = {{\n"]
        for kind, lines in pools.items():
            block.append(f"    {kind} = {{\n" + "".join(f"        {gen.lua_string(l)},\n" for l in lines) + "    },\n")
        blocks.append("".join(block) + "},\n")
    return "".join(out) + "\n".join(blocks) + "}\n"


def fill_voices(accent, plain, check):
    """Voices<Accent>.lua: whole for a rules-only accent, else only its missing lines. Returns lines added."""
    path = gen.ROOT / FILES[accent]
    old = {} if accent in RULES_ONLY or not path.exists() else gen.parse_voices(path)
    voices, added, kept_plain = {}, 0, []
    for persona, pools in plain.items():
        for kind, lines in pools.items():
            have = old.get(persona, {}).get(kind, [])
            out = []
            for i, line in enumerate(lines):
                if i < len(have):
                    out.append(have[i])
                    continue
                added += 1
                said = say(accent, line, kind)
                if said is None:
                    kept_plain.append(line)
                out.append(said or line)
            voices.setdefault(persona, {})[kind] = out
    if accent in RULES_ONLY:
        header = HEADERS[accent] + GENERATED_BY
    else:
        text = path.read_text(encoding="utf-8")
        header = text[:text.index("local _, ns = ...")]
    if not check and added:
        path.write_text(lua_voices(accent, header, voices), encoding="utf-8", newline="\n")
    if accent in RULES_ONLY:
        print(f"{FILES[accent]}: {'would write' if check else 'wrote'} all {added} lines")
    else:
        print(f"{FILES[accent]}: {('would add ' if check else 'added ') + str(added) if added else 'nothing missing'}")
    for line in kept_plain:
        print(f"    no accent version keeps the rules, left plain: {line}")
    return added


def fill_generated(accents, check):
    """tools/generated.json: the plain lines each accent pool lacks, then Generated.lua rebuilt."""
    cache, custom = gen.load_cache(), gen.load_custom()
    plain = cache.get("plain", {})
    total = 0
    for accent in accents:
        added = 0
        for persona in sorted(set(plain) | set(custom)):
            for kind in gen.KINDS:
                # The same source generate.py translates: your seeds (they're plain), then the generated lines.
                seeds = custom.get(persona, {}).get("seeds", {}).get(kind, [])
                source = seeds + [l for l in plain.get(persona, {}).get(kind, []) if l not in seeds]
                if not source:
                    continue
                pools = cache.setdefault(accent, {}).setdefault(persona, {})
                have = [] if accent in RULES_ONLY else pools.get(kind, [])
                pairs = align(source, have)
                out = []
                for i, line in enumerate(source):
                    said = have[pairs[i]] if i in pairs else say(accent, line, kind)
                    if said is not None:
                        out.append(said)
                        added += i not in pairs
                # Translations paired with no plain line (if any) stay, at the end.
                out += [t for j, t in enumerate(have) if j not in pairs.values()]
                pools[kind] = out
        if accent in RULES_ONLY:
            print(f"Generated {accent}: {'would write' if check else 'wrote'} all {added} lines")
        else:
            print(f"Generated {accent}: {('would add ' if check else 'added ') + str(added) if added else 'nothing missing'}")
        total += added
    if not check and total:
        gen.CACHE.write_text(json.dumps(cache, indent=1, ensure_ascii=False), encoding="utf-8")
        gen.write_lua()
        print(f"Wrote {gen.CACHE.name} and {gen.OUTPUT.name}")


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--accent", default="all", help=f"{', '.join(ACCENTS)} (comma-separated), or all")
    ap.add_argument("--check", action="store_true", help="say what's missing, write nothing")
    args = ap.parse_args()
    accents = list(ACCENTS) if args.accent == "all" else args.accent.split(",")
    bad = [a for a in accents if a not in ACCENTS]
    if bad:
        sys.exit(f"Unknown accent: {', '.join(bad)}. Choose from: {', '.join(ACCENTS)}")

    plain = gen.parse_voices(gen.ROOT / gen.SOURCES["plain"])
    for accent in accents:
        fill_voices(accent, plain, args.check)
    if gen.CACHE.exists():
        fill_generated(accents, args.check)
    if not args.check:
        print("/reload in game.")


if __name__ == "__main__":
    main()
