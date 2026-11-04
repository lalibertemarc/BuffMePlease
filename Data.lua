-- Buff Me Please data: personalities, buffs and who can give them. The lines themselves are in Voices.lua.
local _, ns = ...

-- Classic Era (interface 11xxx) instead of Forever (16xxx): shorter buffs, talent-only Kings and Divine Spirit.
ns.ERA = select(4, GetBuildInfo()) < 16000

-- Personalities, in menu order. Each character picks one (Esc > Options > AddOns > Buff Me Please, or
-- /buffme persona <key>). "mixed" draws every line from a random one.
ns.PERSONAS = {
    { key = "bold", label = "Bold", desc = "Fearless and a little cocky. Doesn't beg, just expects." },
    { key = "cheerful", label = "Cheerful", desc = "Warm and friendly. Asks with a smile, thanks with a bigger one." },
    { key = "wise", label = "Wise", desc = "Calm and thoughtful. Asks in proverbs." },
    { key = "gruff", label = "Gruff", desc = "A battle-worn grump. Asks as if it hurts, and thanks even less." },
    { key = "roguish", label = "Roguish", desc = "A charming scoundrel. Every buff is a deal, and the deal is always in their favor." },
    { key = "mystic", label = "Mystic", desc = "Reads omens in everything. The spirits said you would cast it." },
    { key = "scholarly", label = "Scholarly", desc = "Endlessly curious. Asks for a buff the way one asks for a sample." },
    { key = "timid", label = "Timid", desc = "Shy and nervous. Can barely get the words out, and is so grateful when you say yes." },
    { key = "noble", label = "Noble", desc = "A haughty aristocrat. Buffs are a service, and service is expected." },
    { key = "charming", label = "Charming", desc = "A shameless flirt. Every buff is a little romance." },
    { key = "devout", label = "Devout", desc = "Pious and earnest. Every buff is a blessing, and every blessing a prayer answered." },
    { key = "mercenary", label = "Mercenary", desc = "All business. Haggles over buffs like a goblin over gold." },
    { key = "master", label = "Master", desc = "Everyone is a servant, and everything belongs to them. The buff was due an hour ago." },
    { key = "mixed", label = "A bit of everything", desc = "No single mood: every line comes in a different voice." },
}
ns.PERSONA = {}
for _, p in ipairs(ns.PERSONAS) do ns.PERSONA[p.key] = p end
ns.DEFAULT_PERSONA = "cheerful"

-- Accents: Accent.lua (EzAccent's engine) says every line in Voices.lua live, in the accent of your race
-- (orcs, trolls and dwarves; everyone else speaks plainly) unless the character chose another
-- (BuffMePleaseCharDB.accent, a key below; /buffme accent or the options), and .thick makes any of them thicker
-- (undead: no jaw at all). Undead is never picked by race, only chosen.
-- UnitRace's file name -> accent.
ns.RACE_ACCENT = { Orc = "orc", Troll = "troll", Dwarf = "dwarf" }
-- Accent choices, in menu order.
ns.ACCENTS = {
    { key = "race", label = "By race", desc = "Orcs, trolls and dwarves use their own accent, everyone else speaks plainly." },
    { key = "none", label = "None", desc = "Plain lines, whatever your race." },
    { key = "orc", label = "Orc", desc = "Lok'tar! Short, blunt, and proud of it." },
    { key = "troll", label = "Troll", desc = "Easy now, mon. Da spirits be watchin'." },
    { key = "dwarf", label = "Dwarf", desc = "By me beard, lad! Your target is a lad or a lass." },
    { key = "undead", label = "Undead", desc = "Thenk yuu, nngh. A locked jaw squeezes every vowel; thick: no jaw at all." },
}
ns.ACCENT = {}
for _, a in ipairs(ns.ACCENTS) do ns.ACCENT[a.key] = a end
ns.DEFAULT_ACCENT = "race"

-- Lines use {name} (target's full name), {buff} (buff name, asks and refreshes), and {me}/{my}: you
-- alone, or your whole party or raid when you're in one ("give us Arcane Intellect").
ns.ME = { solo = "me", group = "us" }
ns.MY = { solo = "my", group = "our" }
-- A woman hears the accent's own address words in her form (dwarf "lad" -> "lass", troll "bruddah" -> "sistah"),
-- unless the plain line already has one of the typed words (as EzAccent does).
ns.TO_HER = {
    { he = "lad", she = "lass", typed = { "lad" } },
    { he = "bruddah", she = "sistah", typed = { "brother", "bruddah" } },
}
-- Longest chat line: past it, the plain line is said instead of the accent's.
ns.MAX_CHAT = 255

-- key -> ranks of the buff and of its group version as { spellId, level learned }, lowest rank first
-- (same IDs and levels in Forever as in Classic Era). Any of them on you counts as given. A group rank is as
-- strong as the best normal rank at its level. The first rank's name and icon are used in the line.
ns.BUFFS = {
    WISDOM = { -- Blessing / Greater Blessing of Wisdom
        ranks = { { 19742, 14 }, { 19850, 24 }, { 19852, 34 }, { 19853, 44 }, { 19854, 54 }, { 25290, 60 } },
        group = { { 25894, 54 }, { 25918, 60 } },
    },
    KINGS = { -- Blessing / Greater Blessing of Kings
        ranks = { { 20217, 20 } },
        group = { { 25898, 60 } },
    },
    MIGHT = { -- Blessing / Greater Blessing of Might
        ranks = { { 19740, 4 }, { 19834, 12 }, { 19835, 22 }, { 19836, 32 }, { 19837, 42 }, { 19838, 52 }, { 25291, 60 } },
        group = { { 25782, 52 }, { 25916, 60 } },
    },
    MOTW = { -- Mark / Gift of the Wild
        ranks = { { 1126, 1 }, { 5232, 10 }, { 6756, 20 }, { 5234, 30 }, { 8907, 40 }, { 9884, 50 }, { 9885, 60 } },
        group = { { 21849, 50 }, { 21850, 60 } },
    },
    FORT = { -- Power Word / Prayer of Fortitude
        ranks = { { 1243, 1 }, { 1244, 12 }, { 1245, 24 }, { 2791, 36 }, { 10937, 48 }, { 10938, 60 } },
        group = { { 21562, 48 }, { 21564, 60 } },
    },
    SPIRIT = { -- Divine / Prayer of Spirit (trained in Forever, a Discipline talent in Classic Era)
        ranks = { { 14752, 30 }, { 14818, 40 }, { 14819, 50 }, { 27841, 60 } },
        group = { { 27681, 60 } },
    },
    INT = { -- Arcane Intellect / Arcane Brilliance
        ranks = { { 1459, 1 }, { 1460, 14 }, { 1461, 28 }, { 10156, 42 }, { 10157, 56 } },
        group = { { 23028, 56 } },
    },
}

-- What each class can give, most wanted first. You ask for the first one you don't have (or that's
-- expiring) that they're old enough to know, skipping those your own class has no use for.
ns.GIVES = {
    PALADIN = { "KINGS", "WISDOM", "MIGHT" },
    DRUID   = { "MOTW" },
    PRIEST  = { "FORT", "SPIRIT" },
    MAGE    = { "INT" },
}
-- In Classic Era Kings is a Protection talent, so ask for the blessing every paladin has first.
if ns.ERA then ns.GIVES.PALADIN = { "WISDOM", "MIGHT", "KINGS" } end

-- Forever camps: each camp object puts a hidden aura on you (listed in the "Camp Benefits" buff) that blocks
-- the class buff it copies, so theirs would not land. While you have one, that buff counts as given.
-- key -> the camp object's aura spell ID. No camps in Classic Era.
ns.CAMP = ns.ERA and {} or {
    FORT   = 1230124, -- First Aid Kit
    KINGS  = 1230098, -- Fish Bowl
    WISDOM = 1230587, -- Mana Well
    MIGHT  = 1230164, -- Lodestone
    MOTW   = 1230653, -- Enchanted Lute
    INT    = 1229513, -- Incense Candle
}

-- Your class -> buffs it has no use for. Warriors and rogues have no mana; everyone else would
-- rather have Wisdom than Might (Might is melee only in classic, even for hunters).
local NO_MANA = { WISDOM = true, SPIRIT = true, INT = true }
ns.UNWANTED = { WARRIOR = NO_MANA, ROGUE = NO_MANA }
ns.UNWANTED_DEFAULT = { MIGHT = true }

-- Seconds left on a buff you have before it counts as owed again (same as EzBlessings). Classic Era's
-- blessings last 5 minutes (Greater 15), so there it's only owed again near the end.
ns.REFRESH_THRESHOLD = ns.ERA and 120 or 1200

-- Seconds after a line goes out before another can, so a double click or held key doesn't spam /say.
ns.SAY_COOLDOWN = 3

ns.NOTHING_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"
ns.THANKS_ICON = "Interface\\Icons\\INV_Misc_Coin_01"
