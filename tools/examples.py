"""Buff Me Please's hand-written accent examples, for the local-LLM tools that borrow them.

The addon says its accents live from Voices.lua (Accent.lua, EzAccent's engine), so the hand-written orc, troll and
dwarf lines left the addon. They're kept here, frozen, in tools/examples/: Voices<Accent>.lua next to the plain
Voices.lua they were written from (same personalities, kinds and order, so they zip into plain -> accent pairs).
Never packaged (.pkgmeta ignores tools/).

Used by EzBlessings' tools/accent.py (import examples as g: its Ollama call, accent descriptions and dwarf pairs).
AccentTranslator's accent.py reads the same files itself, and its ACCENT_STYLE is a copy of the one here.
"""
import json
import re
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
EXAMPLES = ROOT / "tools" / "examples"
SOURCES = {"plain": "Voices.lua", "orc": "VoicesOrc.lua", "troll": "VoicesTroll.lua", "dwarf": "VoicesDwarf.lua"}
KINDS = ["asks", "refreshes", "thanks"]

ACCENT_STYLE = {
    "plain": "Plain English, no accent.",
    "orc": "An orc: short blunt sentences, dropped articles and verbs ('I go now', 'You are strong'), "
           "the odd Orcish word (Lok'tar, Throm-ka, zug zug, Mak'gora). Write the words normally, not phonetically.",
    "troll": "A Darkspear troll: Caribbean-style dialect ('dere', 'dem', 'mon', 'me gonna', 'ya'), relaxed and "
             "sly, the odd voodoo or loa reference.",
    "dwarf": "A dwarf: Scottish-style dialect ('aye', 'ye', 'tae', 'wee', 'cannae', 'ken'), ale, stone and beards.",
}


def parse_voices(path):
    """Voices*.lua -> {persona: {kind: [lines]}}."""
    out = {}
    persona = pool = None
    for raw in path.read_text(encoding="utf-8").splitlines():
        m = re.match(r"^(\w+) = \{", raw)
        if m:
            persona = out.setdefault(m.group(1), {})
            continue
        m = re.match(r"^    (\w+) = \{", raw)
        if m and persona is not None:
            pool = persona.setdefault(m.group(1), [])
            continue
        m = re.match(r'^\s+"(.*)",?\s*$', raw)
        if m and pool is not None:
            pool.append(m.group(1).replace('\\"', '"').replace("\\\\", "\\"))
    return out


def parse_personas():
    """Data.lua's personalities: key -> (label, desc). "mixed" left out."""
    text = (ROOT / "Data.lua").read_text(encoding="utf-8")
    found = re.findall(r'\{ key = "(\w+)", label = "([^"]+)", desc = "([^"]+)" \}', text)
    return {key: (label, desc) for key, label, desc in found if key != "mixed"}


def load_custom():
    """Personalities of your own: key -> {"label", "desc", "seeds": {kind: [lines]}}."""
    return json.loads(PERSONAS_FILE.read_text(encoding="utf-8")) if PERSONAS_FILE.exists() else {}


def load_cache():
    """tools/generated.json: accent -> persona -> kind -> [lines]."""
    cache = json.loads(CACHE.read_text(encoding="utf-8")) if CACHE.exists() else {}
    # Before class asks were retired: accent -> "voices"/"class_asks" -> persona -> pool.
    return {a: s["voices"] if "voices" in s or "class_asks" in s else s for a, s in cache.items() if s}


def prompt_for(accent, label, desc, kind, examples, borrowed, count):
    placeholders = ["{name} = the target's name (use it in every line)"]
    if kind != "thanks":
        placeholders.append("{buff} = the buff's name, e.g. Arcane Intellect (use it in every line)")
    placeholders.append("{me} = 'me' or 'us', only after a verb or preposition (give {me}, on {me}, for {me}), "
                        "never as the subject; {my} = 'my' or 'our'. Never start a line with {me} or {my}")
    if accent == "dwarf":
        placeholders.append("{lad} = 'lad' or 'lass' (optional)")
    task = KIND_TASK[kind]
    system = (
        "You write short in-character /say chat lines for a roleplayer in classic World of Warcraft (vanilla, "
        "level 1-60, Alliance and Horde, no later expansions). One player asks another for a buff spell.\n"
        f"Personality: {label}. {desc}\n"
        f"Voice: {ACCENT_STYLE[accent]}\n"
        "Rules: each line is one or two short spoken sentences, under 110 characters, said out loud to the other "
        "player. No *actions*, no emojis, no hashtags, no quotation marks around the line, no modern slang or "
        "real-world references, and nothing about the game's interface (icons, buttons, bars, addons). "
        "{buff} is a spell's name: never write 'a {buff}', 'an {buff}', 'some {buff}' or 'your {buff}'. "
        "Be witty and specific like the examples, not generic. Every line different from the others.\n"
        "Placeholders, written exactly like this with curly braces:\n- " + "\n- ".join(placeholders)
    )
    user = f"Situation: {task}\n\n"
    if examples:
        user += "Examples in this voice:\n" + "\n".join(f"- {e}" for e in examples) + "\n\n"
    if borrowed:
        copy = "format and accent" if accent != "plain" else "format"
        user += (f"Examples from OTHER personalities (copy only their {copy}, not their personality):\n"
                 + "\n".join(f"- {e}" for e in borrowed) + "\n\n")
    user += (f"Write {count} NEW lines in the {label} voice described above. Don't reuse the examples' jokes. "
             'Reply as JSON: {"lines": ["...", "..."]}')
    return system, user


def ollama(host, model, system, user, temperature):
    body = {
        "model": model,
        "stream": False,
        "messages": [{"role": "system", "content": system}, {"role": "user", "content": user}],
        "format": {"type": "object", "properties": {"lines": {"type": "array", "items": {"type": "string"}}},
                   "required": ["lines"]},
        "options": {"temperature": temperature, "num_ctx": 4096},
    }
    req = urllib.request.Request(f"{host}/api/chat", json.dumps(body).encode(), {"Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=600) as resp:
        content = json.loads(resp.read().decode("utf-8"))["message"]["content"]
    lines = json.loads(content).get("lines", [])
    return [l for l in lines if isinstance(l, str)]


TYPOGRAPHY = {"‘": "'", "’": "'", "“": '"', "”": '"', "…": "...", "–": "-", "—": ", "}


def parse_voices(path):
    """Voices*.lua -> {persona: {kind: [lines]}}."""
    out = {}
    persona = pool = None
    for raw in path.read_text(encoding="utf-8").splitlines():
        m = re.match(r"^(\w+) = \{", raw)
        if m:
            persona = out.setdefault(m.group(1), {})
            continue
        m = re.match(r"^    (\w+) = \{", raw)
        if m and persona is not None:
            pool = persona.setdefault(m.group(1), [])
            continue
        m = re.match(r'^\s+"(.*)",?\s*$', raw)
        if m and pool is not None:
            pool.append(m.group(1).replace('\\"', '"').replace("\\\\", "\\"))
    return out


def norm(line):
    return re.sub(r"[^a-z{} ]", "", line.lower())


def accent_pairs(accent):
    """kind -> [(persona, plain line, accented line)] from examples/Voices.lua and Voices<Accent>.lua, which
    hold the same lines in the same order."""
    plain, accented = parse_voices(EXAMPLES / SOURCES["plain"]), parse_voices(EXAMPLES / SOURCES[accent])
    pairs = {kind: [] for kind in KINDS}
    for persona, pools in plain.items():
        for kind in KINDS:
            for a, b in zip(pools.get(kind, []), accented.get(persona, {}).get(kind, [])):
                if a != b:
                    pairs[kind].append((persona, a, b))
    return pairs


def lua_string(s):
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'
