# Buff Me Please

*Ask nicely. Or not. It depends who you are.*

A WoW Forever and Classic Era roleplay addon. Target a friendly player whose class can buff you and Buff Me Please asks them for it in `/say` (or a whisper, if you prefer), in your character's own voice. Pick a personality and every ask and every thank-you fits it:

> Um, Bob Smith? Sorry to bother you... could I maybe have Arcane Intellect? Only if it's no trouble. *(timid)*

> Bob Smith, what's your rate for a Blessing of Kings? I'm good for it. *(mercenary)*

## Personalities

Bold, Cheerful, Wise, Gruff, Roguish, Mystic, Scholarly and Timid (the same set as Campfire Tales Forever; a character's Campfire Tales personality is picked up on first login), plus Noble, Charming, Devout, Mercenary and Master (everyone is a servant, and the buff was due an hour ago), or "A bit of everything". Each has 20 asks, 10 refreshes and 16 thank-yous: 598 lines in all, each one said in any of the accents below.

Pick it per character in Esc > Options > AddOns > Buff Me Please (with a Preview button), by right-clicking the icon, or with `/buffme persona <name>`.

## Accents

Orcs, trolls and dwarves don't talk like everyone else, so every line can be said in an orc, troll or dwarf accent. Same personality and same joke, said their way:

> Bob Smith, what be ya rate for a Blessing of Kings, mon? I be good for it. *(mercenary troll)*

> Um, Bob Smith? Sorry tae bother ye... could I maybe have Arcane Intellect? Only if it's nae trouble. *(timid dwarf)*

> Throm-ka. Good doing business with you, Bob Smith. Lok'tar! *(mercenary orc)*

By default your race picks the accent (orc, troll or dwarf; everyone else speaks plainly). Any character can pick another, or none, in Esc > Options > AddOns > Buff Me Please or with `/buffme accent <race | none | orc | troll | dwarf | undead>`: a human who grew up in Ironforge can talk like a dwarf, an orc can speak plainly. A new accent is heard on the next line, no `/reload` needed. With [EzAccent](../EzAccent) loaded, changing your accent there sets this one too; `/buffme accent` still sets Buff Me Please's alone.

**Thick accent** (a checkbox under the accent, or `/buffme thick on | off`) lays it on heavier: more Orcish, deeper Darkspear, broad Scots ("could Ah maybe hae Arcane Intellect?").

**Undead** is there for the choosing, never picked by race: a locked jaw that squeezes every vowel ("Thenk yuu, Bob Smith! I'll neme my next victury efter y-yuu. Mmf."), or with thick on, no jaw at all ("Hhank you, shlrk, Bob Smith! I'll nange ngy nekht hictory ahhter you. Ghhk-hk.").

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

Edit the lines in `Voices.lua` (`{name}`, `{buff}`, and `{me}`/`{my}`, which become "us"/"our" in a group) and the buffs in `Data.lua`; `lua tests/lines.lua` checks them in every accent. The accents are said live from those lines by `Accent.lua`, a copy of [EzAccent](../EzAccent)'s engine, with the rules in `AccentRules.lua` (generated from AccentTranslator's `rules.py` by EzAccent's `tools/gen_rules.py --out ../BuffMePlease/AccentRules.lua`; don't edit it by hand). Your target's name and the buff are put in after the accent, so they're never respelled, and a woman hears a dwarf's "lad" as "lass". A line the accent would push past 255 characters goes out plain.

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
| `/buffme accent [race \| none \| orc \| troll \| dwarf \| undead]` | Show or change your accent |
| `/buffme thick [on \| off]` | Thicker accent (undead: no jaw at all) |
| `/buffme say` / `whisper` | Say your lines (default) or whisper them to your target |
| `/buffme preview` | Sample lines in your personality (only you see them) |
| `/buffme config` | Open the options |
| `/buffme lock` / `unlock` | Lock or unlock the button (Shift-drag always moves it) |
| `/buffme reset` | Reset the button position |

## Tools

`tools/examples/` keeps the old hand-written orc, troll and dwarf lines, frozen next to the plain `Voices.lua` they were written from, as plain -> accent example pairs for the local-LLM tools that borrow them: `tools/examples.py` (used by EzBlessings' `tools/accent.py`) and AccentTranslator's `accent.py --ai`. Not packaged.
