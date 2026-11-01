# Buff Me Please

*Ask nicely. Or not. It depends who you are.*

A WoW Forever and Classic Era roleplay addon. Target a friendly player whose class can buff you and Buff Me Please asks them for it in `/say` (or a whisper, if you prefer), in your character's own voice. Pick a personality and every ask and every thank-you fits it:

> Um, Bob Smith? Sorry to bother you... could I maybe have Arcane Intellect? Only if it's no trouble. *(timid)*

> Bob Smith, what's your rate for a Blessing of Kings? I'm good for it. *(mercenary)*

## Personalities

Bold, Cheerful, Wise, Gruff, Roguish, Mystic, Scholarly and Timid (the same set as Campfire Tales Forever; a character's Campfire Tales personality is picked up on first login), plus Noble, Charming, Devout and Mercenary, or "A bit of everything". Each has 20 asks, 10 refreshes and 16 thank-yous: 552 lines in all, times four with the accents below.

Pick it per character in Esc > Options > AddOns > Buff Me Please (with a Preview button), by right-clicking the icon, or with `/buffme persona <name>`.

## Accents

Orcs, trolls and dwarves don't talk like everyone else, so every one of those lines also comes in an orc, troll and dwarf version. Same personality and same joke, said their way:

> Bob Smith, what be ya rate for some Blessing of Kings? Me good for it, mon. *(mercenary troll)*

> Um, Bob Smith? Sorry tae bother ye... could I maybe have Arcane Intellect? Only if it's nae trouble, lad. *(timid dwarf)*

> Bob Smith! You there. Power Word: Fortitude, on me. I put it to good use. Bloody use. *(bold orc)*

By default your race picks the accent (orc, troll or dwarf; everyone else speaks plainly). Any character can pick another, or none, in Esc > Options > AddOns > Buff Me Please or with `/buffme accent <race | none | orc | troll | dwarf | undead | jawless>`: a human who grew up in Ironforge can talk like a dwarf, an orc can speak plainly. Only that one set of lines is kept in memory; the others are dropped at login, so a new accent is heard after a `/reload`.

Two undead voices are there for the choosing, never picked by race: **undead**, a locked jaw that squeezes every vowel ("Thenk yuu, Bob Smith! I'll neme my next victury efter y-yuu. Mmf."), and **jawless**, no jaw at all ("Hhank you, shlrk, Bob Smith! I'll nange ngy nekht hictory ahhter you. Ghhk-hk.").

## What you ask for

| Their class | You ask for |
|---|---|
| Paladin | Blessing of Kings (level 20+), then Blessing of Might if you're a warrior or rogue, Blessing of Wisdom otherwise. Classic Era: Might/Wisdom first, since Kings is a talent there |
| Druid | Mark of the Wild |
| Priest | Power Word: Fortitude, then Divine Spirit (level 30+) if you use mana |
| Mage | Arcane Intellect, if you use mana |

You never ask for a buff you already have, unless it's about to drop (20 minutes left; 2 in Classic Era), and never for one your target is too low level to know. Group versions count as given.

## Features

- **Icon next to the target frame**, shown while your target has a buff for you. With [EzBlessings](https://github.com/lalibertemarc/EzBlessings) on a paladin, it sits just under the EzBlessings button instead, and follows it if you move it. Click to ask. A check mark means you have everything they can give; a gold border means a buff is fading and the click asks for a refresh. Right-click to change your personality.
- **Thank-you button** (the coin) beside it.
- **Say or whisper.** Lines go out in `/say` by default; switch to whispering them to your target on the options page or with `/buffme whisper`. The setting is shared by all your characters.
- **Clickable names.** Your target's name in your own line becomes a class-colored player link in your chat.
- **Key bindings** for both under Options > Keybindings > Buff Me Please. They work with the interface hidden.
- **Steps aside for EzMinion.** On a warlock with EzMinion loaded, Buff Me Please stays off (no icon, bindings or options), since EzMinion already orders your buffs. Other classes are unaffected.

Edit the lines in `Voices.lua` (`{name}`, `{buff}`, and `{me}`/`{my}`, which become "us"/"our" in a group), their accented versions in `VoicesOrc.lua`, `VoicesTroll.lua` and `VoicesDwarf.lua` (dwarves also get `{lad}`: "lad" or "lass"), and the buffs in `Data.lua`. `VoicesUndead.lua` and `VoicesJawless.lua` are made from `Voices.lua` by `python tools/rules_accents.py` (with AccentTranslator's `rules.py`, next to this addon in the workspace): rerun it after editing `Voices.lua` instead of editing them.

## Install

Install from CurseForge or Wago, or download the zip from the [Releases](../../releases) page and extract the `BuffMePlease` folder into your client's AddOns folder:

```
World of Warcraft\_classic_beta_\Interface\AddOns\
World of Warcraft\_classic_era_\Interface\AddOns\
```

## Commands

Use `/buffme` or `/bmp`.

| Command | Does |
|---|---|
| `/buffme` | Ask your target for a buff |
| `/buffme thanks` | Thank your target |
| `/buffme persona [name]` | Show or change your personality |
| `/buffme accent [race \| none \| orc \| troll \| dwarf \| undead \| jawless]` | Show or change your accent (heard after a `/reload`) |
| `/buffme say` / `whisper` | Say your lines (default) or whisper them to your target |
| `/buffme preview` | Sample lines in your personality (only you see them) |
| `/buffme config` | Open the options |
| `/buffme lock` / `unlock` | Lock or unlock the button (Shift-drag always moves it) |
| `/buffme reset` | Reset the button position |
| `/buffme lines [mix \| only \| off]` | With generated lines (below): use them with, instead of, or not at all with the hand-written ones |

## Generated lines (local LLM, for your own install)

`tools/generate.py` has a local model ([Ollama](https://ollama.com), `ollama pull llama3.1:8b`) write more lines in each personality's voice, using the hand-written ones as examples, into `Generated.lua`. Accents are translated from those plain lines, with matching plain/accent pairs from the `Voices*.lua` files as examples, so generate plain first. The model leaves out translations that break a rule; `tools/rules_accents.py` fills those in with the rules EzAccent speaks with (no model), and writes the undead and jawless sets whole. `tools/new_persona.py` adds a personality of your own (name, description, a few seed lines) and generates its lines. Both need Python 3 and only touch git-ignored files (`Generated.lua`, `tools/generated.json`, `tools/personas.json`), which are never packaged. `/reload` in game to pick them up.

```
python tools/generate.py                         # every personality, plain voice
python tools/generate.py --accent orc,troll,dwarf # translate the plain lines
python tools/rules_accents.py                    # fill what the model left out, write undead and jawless
python tools/new_persona.py                      # add or edit a personality of your own
python tools/new_persona.py --list | --remove <key>
```

To say any line of your own in an accent, see AccentTranslator (next to this addon in the workspace), which uses the same example pairs.
