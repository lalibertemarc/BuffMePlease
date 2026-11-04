# Buff Me Please

## v1.4.0

- **Accents said live.** Every line is now said in your accent as it goes out, with the same rules EzAccent speaks with, instead of coming from a separate accented copy of each line. A new accent is heard on the next line, no `/reload` needed, and the addon is much lighter (about 65 KB of accent engine instead of five 45 KB files of accented lines). Your target's name and the buff are never respelled, and a woman hears a dwarf's "lad" as "lass". Orc got richer at the same time: more Orcish (Throm-ka, Dabu, Aka'Magosh), clipped sentences and fewer slips.
- **Thick accents.** Tick **Thick accent** on the options page (or `/buffme thick on`) for a heavier orc, troll or dwarf: "could Ah maybe hae Arcane Intellect?" For the undead, thick is jawless, which replaces the separate Undead (jawless) choice: a character that had it keeps it, as Undead with thick on (`/buffme accent jawless` still works too).
- **New personality: Master.** Everyone is a servant, and everything belongs to them: "Bob Smith, you should have given me Arcane Intellect an hour ago!" 46 lines like the others.
- **Generated lines retired.** `/buffme lines`, `Generated.lua` and the local-LLM tools that wrote it (`tools/generate.py`, `tools/new_persona.py`, `tools/rules_accents.py`) are gone; the lines worth keeping are in `Voices.lua`.
- **Follows EzAccent.** With EzAccent loaded, changing your accent there (`/acc accent`, `/acc thick` or its options page) sets Buff Me Please's to the same one, thick included, heard on the next line. `/buffme accent` and the options page still change Buff Me Please's alone.

## v1.3.0

- **Two undead voices.** Pick **Undead (locked jaw)** or **Undead (jawless)** as your accent on the options page, or with `/buffme accent undead | jawless`. Every line in both, same personality, same joke: "Thenk yuu, Bob Smith! I'll neme my next victury efter y-yuu. Mmf." They're never picked by race, so the Forsaken still speak plainly unless they choose one.
- **Generated lines (your own install).** `tools/rules_accents.py` fills in the accent translations the local model left out, with the same rules EzAccent speaks with (no model), and writes undead and jawless versions of every generated line.

## v1.2.0

- **New name: Buff Me Please** (was RpBuffBeg). The slash command is now `/buffme` (or `/bmp`); key bindings and the options page are under Buff Me Please.
- **Pick your accent.** Your race still picks it by default, but any character can now talk like an orc, a troll or a dwarf, or speak plainly, whatever their race: Accent on the options page, or `/buffme accent <race | none | orc | troll | dwarf>`. Each character has their own; a change is heard after a `/reload`.
- **The campfire already gave.** In Forever, a camp's First Aid Kit, Fish Bowl, Mana Well, Lodestone, Enchanted Lute and Incense Candle each block the class buff they copy, so the target's Fortitude, Kings, Wisdom, Might, Mark of the Wild or Arcane Intellect would not land. Those buffs now count as given while the camp's benefit lasts: you ask for the next buff they can give instead, or nothing. The tooltip marks them "have, from camp".
- **Class asks retired.** Personalities no longer have extra asks for each class you play: every ask comes from the personality's own 20. 552 lines in all, times four with the accents.
- **Generated lines (your own install).** `tools/generate.py` has a local LLM (Ollama) write more lines in each personality's voice into `Generated.lua`, and `tools/new_persona.py` adds personalities of your own. Neither is packaged. `/buffme lines mix | only | off` picks how generated lines are used.

## v1.1.0

- **Twice the lines.** Every personality now has 20 asks, 10 refreshes and 16 thank-yous, and 4 asks for each class instead of 2 (so class lines no longer just alternate): 984 lines in all. Gruff mages, timid rogues hiding behind barrels, mercenary priests selling resurrections at fifty silver.
- **Orc, troll and dwarf accents.** Every line also comes in an orc, troll and dwarf version, same personality, same joke: Lok'tar, mon, and by me beard. Your race picks it, and only your accent is kept in memory. Dwarves call your target "lad" or "lass".

## v1.0.0

- **First release.** Target a friendly player whose class can buff you and ask them for it, in `/say`, in your character's own voice: "Um, Bob Smith? Sorry to bother you... could I maybe have Arcane Intellect? Only if it's no trouble." A coin button beside the icon thanks them.
- **Twelve personalities**, picked per character: bold, cheerful, wise, gruff, roguish, mystic, scholarly and timid (a character's Campfire Tales Forever personality is picked up on first login), plus noble, charming, devout and mercenary, or "a bit of everything". Each has its own asks, refreshes and thank-yous, and its own asks for each class you play: 480 lines in all. Change it on the options page (with a preview), by right-clicking the icon, or with `/buffme persona`.
- **Only what you need.** Paladins are asked for Kings, then Might (warriors and rogues) or Wisdom (everyone else); druids for Mark of the Wild; priests for Fortitude, then Divine Spirit if you use mana; mages for Arcane Intellect if you use mana. Nothing you already have, unless it's about to drop, and nothing your target is too young to know.
- **Say or whisper.** `/say` by default; whisper your target instead on the options page or with `/buffme whisper`.
- **Plays well with EzBlessings and EzMinion.** On a paladin, the icon sits under the EzBlessings button instead of on top of it. On a warlock with EzMinion, Buff Me Please stays off and lets your minions do the work.
- Works in WoW Forever and Classic Era. In Era, paladins are asked for Might or Wisdom before Kings (a talent there), and a buff is asked for again with 2 minutes left.
