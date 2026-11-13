-- Accents for Buff Me Please's lines: a copy of EzAccent's Accent.lua (its hand port of AccentTranslator's
-- rules.accented()), byte-identical below this header: keep the two in step. The tables come from AccentRules.lua
-- (EzAccent's tools/gen_rules.py --out ../BuffMePlease/AccentRules.lua, every accent).
--   ns.Speak(accent, line, thick, max) -> the line in that accent ("none" leaves it alone)
-- Chat links (|H...|h...|h and other | escapes), {placeholder} tokens and %t are never touched.
local _, ns = ...

local random = math.random
local concat = table.concat

local function Pick(list)
    return list[random(#list)]
end

local function Trim(s)
    return (s:match("^%s*(.-)%s*$"))
end

local function Escape(s)
    return (s:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0"))
end

---------------------------------------------------------------------------
-- Protected tokens: swapped for {1}, {2}... while the accent works (rules.py already leaves {words} alone), put
-- back at the end.
---------------------------------------------------------------------------
local ESCAPES = { "^|c[^|]*|H.-|h.-|h|r", "^|H.-|h.-|h", "^|T.-|t", "^|A.-|a", "^|K.-|k", "^|c%x%x%x%x%x%x%x%x",
                  "^|r" }

local function Protect(line)
    local saved, out, i = {}, {}, 1
    while i <= #line do
        local c, s, e = line:sub(i, i)
        if c == "|" then
            for _, p in ipairs(ESCAPES) do
                s, e = line:find(p, i)
                if s then break end
            end
        elseif c == "{" then
            s, e = line:find("^{[^{}]*}", i)
        elseif c == "%" then
            s, e = line:find("^%%%a", i)
        end
        if s then
            saved[#saved + 1] = line:sub(s, e)
            out[#out + 1] = "{" .. #saved .. "}"
            i = e + 1
        else
            out[#out + 1] = c
            i = i + 1
        end
    end
    return concat(out), saved
end

local function Restore(line, saved)
    return (line:gsub("{(%d+)}", function(n) return saved[tonumber(n)] end))
end

---------------------------------------------------------------------------
-- Word swaps (rules.word_rx / swap_words / case_like)
---------------------------------------------------------------------------
-- c is part of a word: \w, an apostrophe, or the given brace (rules.py's [\w'{] before and [\w'}] after).
local function Inside(c, brace)
    return c ~= "" and (c:find("[%w_']") ~= nil or c == brace)
end

-- The lookbehinds gen_rules.py turns into rule.after.
local function AfterOK(line, i, after)
    if after == "word" then
        return line:sub(i - 1, i - 1) == " " and line:sub(i - 2, i - 2):find("[%w_}']") ~= nil
    elseif after == "comma" then
        return line:sub(i - 2, i - 1) == ", "
    elseif after == "start" then
        local prev = line:sub(i - 1, i - 1)
        return prev ~= "-" and not (prev == " " and line:sub(i - 2, i - 2):find("[%w_}']") ~= nil)
    end
    return true
end

-- The lookaheads gen_rules.py turns into rule.ahead: what must come right after the phrase (which ends at e).
local function AheadOK(line, e, ahead)
    if ahead == "stop" then
        return line:sub(e + 1, e + 1):find("^[,.!?]") ~= nil
    elseif ahead == "ask" then
        return line:sub(e + 1, e + 1) == "?"
    elseif ahead == "brace" then
        return line:sub(e + 1, e + 2) == " {"
    elseif ahead == "verb" then -- rules.TO_VERB: no place next ("going to the inn", "going to Orgrimmar")
        if line:sub(e + 1, e + 1) ~= " " then return true end
        if line:find("^%u", e + 2) then return false end
        local low = line:lower()
        for _, w in ipairs(ns.PLACES) do
            local last = e + 1 + #w
            if low:sub(e + 2, last) == w and not low:sub(last + 1, last + 1):find("[%w_]") then return false end
        end
    end
    return true
end

-- A capital on the original's first letter carries over, except on "I"; a shouted word stays shouted.
local function CaseLike(src, out)
    if out == "" or not src:find("^%u") or src == "I" or src:find("^I'") or src:find("^I%s") then return out end
    if #src > 2 and src:upper() == src then return out:upper() end
    return out:sub(1, 1):upper() .. out:sub(2)
end

-- At each word start the first rule (and phrase) that matches wins, like one big regex alternation.
local function SwapWords(line, rules)
    local low, out, i, n = line:lower(), {}, 1, #line
    while i <= n do
        local rule, e
        if not Inside(line:sub(i - 1, i - 1), "{") then
            for _, r in ipairs(rules) do
                if AfterOK(line, i, r.after) then
                    for _, p in ipairs(r.phrases) do
                        local last = i + #p - 1
                        if low:sub(i, last) == p and not Inside(line:sub(last + 1, last + 1), "}")
                                and AheadOK(line, last, r.ahead) then
                            rule, e = r, last
                            break
                        end
                    end
                end
                if rule then break end
            end
        end
        if rule then
            local src = line:sub(i, e)
            if rule.keep or random() > (rule.chance or 1) then
                out[#out + 1] = src
            else
                out[#out + 1] = CaseLike(src, type(rule.out) == "table" and Pick(rule.out) or rule.out)
            end
            i = e + 1
        else
            out[#out + 1] = line:sub(i, i)
            i = i + 1
        end
    end
    return concat(out)
end

local rulesCache = {}
local function Rules(accent, thick)
    local key = accent .. (thick and "_thick" or "")
    if not rulesCache[key] then
        local list = {}
        local function add(t) for _, r in ipairs(t) do list[#list + 1] = r end end
        -- Orc's "is fading" -> "fades" goes ahead of thick's dropped "is".
        if accent == "orc" then add(ns.WORDS.orc_pre) end
        if thick then add(ns.WORDS[accent .. "_thick"]) end
        add(ns.WORDS[accent])
        rulesCache[key] = list
    end
    return rulesCache[key]
end

---------------------------------------------------------------------------
-- The rest of rules.py's helpers
---------------------------------------------------------------------------
-- walking -> walkin', blessings -> blessin's; thing, king, bring keep theirs (no vowel before the -ing), and so
-- does Gaelic taing.
local function DropGs(line)
    return (line:gsub("()([%w_']+)()", function(s, word, e)
        if line:sub(s - 1, s - 1) == "{" or line:sub(e, e) == "}" or not word:find("^%a+$") then return end
        local stem, plural = word:match("^(%a-)ing(s?)$")
        if not stem or stem == "" or not stem:find("[aeiouyAEIOUY]") or word:lower() == "taing" then return end
        return stem .. "in'" .. plural
    end))
end

-- Lower-case words starting in th (think, three, thick) lose the h; Thrall keeps his.
local function TrollTh(line)
    return (line:gsub("%f[%w_'{]th(%l)", "t%1"))
end

-- Thick tauren take their time: one comma (not right before a {placeholder}) becomes "... ".
local function Pause(line)
    local commas = {}
    for s, e in line:gmatch("(),%s+()") do
        if line:sub(e, e) ~= "{" then commas[#commas + 1] = { s, e } end
    end
    if #commas == 0 then return line end
    local c = Pick(commas)
    return line:sub(1, c[1] - 1) .. "... " .. line:sub(c[2])
end

-- gsub until nothing changes: stands in for a repeated group, (?:...)+
local function Repeat(line, pattern, repl)
    local n
    repeat line, n = line:gsub(pattern, repl) until n == 0
    return line
end

local function Upper(prefix, c) return prefix .. c:upper() end

local function Tidy(line)
    line = line:gsub("%s+", " ")
    line = line:gsub("%s+([,.!?;:])", "%1")
    line = line:gsub("^[%s,.;:]+", "")
    line = Repeat(line, "([.!?])%s*[,;:]", "%1")
    -- "!." and ".!" lose the dot; an ellipsis ("...!", "!..") stays.
    line = line:gsub("()([!?])%.", function(at, mark)
        if line:sub(at + 2, at + 2) ~= "." then return mark end
    end)
    line = line:gsub("()%.([!?])", function(at, mark)
        if line:sub(at - 1, at - 1) ~= "." then return mark end
    end)
    line = Repeat(line, ",%s*,", ",")
    line = line:gsub("[,;:]%s*([.!?])", "%1")
    line = line:gsub("()%.%.()", function(s, e)  -- ".." -> ".", but not inside "..."
        if line:sub(s - 1, s - 1) ~= "." and line:sub(e, e) ~= "." then return "." end
    end)
    line = line:gsub("^(['\"]?)(%l)", Upper)
    line = line:gsub("()([.!?]%s+['\"]?)(%l)", function(at, prefix, c)  -- no capital after an ellipsis
        if line:sub(at - 2, at - 1) ~= ".." then return prefix .. c:upper() end
    end)
    return Trim(line)
end

local function EndWithStop(line)
    return line:find("[.!?]['\"]?$") and line or line .. "."
end

-- tag (", mon") before the closing mark of one sentence, the last more often than not.
local function AddTag(line, tag)
    local ends = {}
    for s, e in line:gmatch("()[.!?]+()") do
        local after = line:sub(e, e)
        if after == "" or after:find("%s") then ends[#ends + 1] = s end
    end
    if #ends == 0 then return (line:gsub("[,;: ]+$", "")) .. tag end
    local s = random() < 0.6 and ends[#ends] or ends[random(#ends)]
    return line:sub(1, s - 1) .. tag .. line:sub(s)
end

-- 'Would you cast X on me?' -> 'cast X on me.': orcs don't ask.
local MODALS = { "would", "could", "can", "will" }
-- Verbs after "would you" that ask what someone wants instead of telling them to do something (rules.py ASKING).
local ASKING = { "mind", "like", "want", "care", "prefer", "rather" }
local function Asking(low, at)
    for _, w in ipairs(ASKING) do
        if low:find("^" .. w .. "%f[^%w_]", at) then return true end
    end
end
local function OrcRequests(line)
    local low, out, pos = line:lower(), {}, 1
    while true do
        local at, youEnd
        for _, m in ipairs(MODALS) do
            local s, e = low:find("%f[%w_]" .. m .. " you", pos)
            if s and (not at or s < at) then at, youEnd = s, e end
        end
        if not at then break end
        -- "Would you mind/like/want...?" stays a question.
        local s, e, c1, c2 = low:find("^ please%s+()[^.!?]*()%?", youEnd + 1)
        if s and Asking(low, c1) then s = nil end
        if not s then s, e, c1, c2 = low:find("^%s+()[^.!?]*()%?", youEnd + 1) end
        if s and Asking(low, c1) then s = nil end
        if s then
            out[#out + 1] = line:sub(pos, at - 1) .. line:sub(c1, c2 - 1) .. "."
            pos = e + 1
        else
            out[#out + 1] = line:sub(pos, at)
            pos = at + 1
        end
    end
    out[#out + 1] = line:sub(pos)
    return concat(out)
end

-- One of rules.py's test regexes (ns.TEST, from gen_rules.py) on a line.
local function Has(line, test)
    local low = line:lower()
    for _, w in ipairs(test.words or {}) do
        local stem = w:match("^(.-)%*$")
        if low:find("%f[%w_]" .. Escape(stem or w) .. (stem and "" or "%f[^%w_]")) then return true end
    end
    for _, s in ipairs(test.subs or {}) do
        if low:find(s, 1, true) then return true end
    end
    return false
end

-- rules.orc_mood: which of ns.ORC_CLOSERS a line gets.
local function OrcMood(line)
    local T = ns.TEST
    return Has(line, T.THANKS) and "thanks" or Has(line, T.FIGHT) and "fight" or Has(line, T.GLOOM) and "gloom"
        or line:find("%?$") and "ask" or "any"
end

local function Contains(list, value)
    for _, v in ipairs(list) do
        if v == value then return true end
    end
    return false
end

local function StartsWithAny(line, list)
    local low = line:lower()
    for _, s in ipairs(list) do
        if low:sub(1, #s) == s then return true end
    end
    return false
end

---------------------------------------------------------------------------
-- Undead (rules.respell): spelling swaps, then a strained sound at the end
---------------------------------------------------------------------------
-- rules.shouted: the word around line[i..e] (letters and apostrophes) is in capitals and has two letters or more.
local function Shouted(line, i, e)
    while i > 1 and line:sub(i - 1, i - 1):find("[%a']") do i = i - 1 end
    while e < #line and line:sub(e + 1, e + 1):find("[%a']") do e = e + 1 end
    local w = line:sub(i, e)
    return w:find("%a.*%a") ~= nil and not w:find("%l")
end

local function Respell(line, swaps)
    local low, out, i, n = line:lower(), {}, 1, #line
    while i <= n do
        local hit
        for _, sw in ipairs(swaps) do
            local e = i + #sw.from - 1
            if low:sub(i, e) == sw.from and (not sw.ahead or low:find("^" .. sw.ahead, e + 1)) then
                hit = sw
                break
            end
        end
        if hit then
            local to = hit.to
            if Shouted(line, i, i + #hit.from - 1) then -- FOR THE HORDE -> HHOR HHE HORDE, not HhOR HhE
                to = to:upper()
            elseif line:find("^%u", i) then
                local k = to:sub(1, 1) == "'" and 2 or 1
                to = to:sub(1, k - 1) .. to:sub(k, k):upper() .. to:sub(k + 1)
            end
            out[#out + 1] = to
            i = i + #hit.from
        else
            out[#out + 1] = line:sub(i, i)
            i = i + 1
        end
    end
    return concat(out)
end

-- rules.SOUND_AT_END, by hand: a line already ending in a gurgle or strain gets no second one.
local SOUNDS = { "^gh+k+$", "^hh+r*k+$", "^hhh+$", "^n+gh$", "^h?m+f$", "^hk+$", "^nnn+$", "^sss+$", "^t+s+$", "^k+t$",
    "^k+h$", "^h?n+h$", "^m+h$", "^g?r+k$" }
local function IsSound(word)
    if not word then return false end
    for _, p in ipairs(SOUNDS) do
        if word:find(p) then return true end
    end
    return false
end

local function EndsInSound(line)
    local last = line:lower():gsub("[^%w_]*$", ""):match("([%w_]+%-?[%w_]*)$")
    if not last then return false end
    local head, tail = last:match("^([%w_]+)%-([%w_]+)$")
    if head then return IsSound(head) or IsSound(tail) end
    return IsSound(last)
end

-- rules.tuck: the sound tucked in before the line's last mark: "Huw ere yuu, mmf?"; after a full stop (or none) it
-- trails off: "I em tired... nngh.".
local function Tuck(line, sound)
    local base, mark = line:match("^(.-)([.!?]+)$")
    local word = sound:lower():gsub("%.+$", "")
    if not base or mark == "." then return (base or line) .. "... " .. word .. "." end
    return base .. ", " .. word .. mark
end

-- rules.drool: one of sounds at a comma (", ghk, ") or between two sentences (". Ghk. ").
local function Drool(line, sounds)
    local breaks = {}
    for s, mark, e in line:gmatch("()([,.!?]+)%s+()") do
        if e <= #line then breaks[#breaks + 1] = { s, mark, e } end
    end
    if #breaks == 0 then return line end
    local b, d = Pick(breaks), Pick(sounds)
    local ins = b[2] == "," and ", " .. d .. ", " or b[2] .. " " .. d:sub(1, 1):upper() .. d:sub(2) .. ". "
    return line:sub(1, b[1] - 1) .. ins .. line:sub(b[3])
end

-- rules.stutter: one word of three letters or more starting with a consonant, its first letter caught: w-would.
local function Stutter(line)
    local words = {}
    for s, w in line:gmatch("()([%w_]+)") do
        if line:sub(s - 1, s - 1) ~= "{" and line:sub(s - 1, s - 1) ~= "'" and #w >= 3
                and w:find("^[b-df-hj-np-tv-zB-DF-HJ-NP-TV-Z]") then
            words[#words + 1] = { s, w }
        end
    end
    if #words == 0 then return line end
    local s, w = unpack(Pick(words))
    local again = w:find("%l") and w:sub(1, 1):lower() or w:sub(1, 1) -- a shouted word stays shouted: H-HORDE
    return line:sub(1, s - 1) .. w:sub(1, 1) .. "-" .. again .. line:sub(s + 1)
end

-- The odd s hisses through the teeth: jusst, thiss (a word that already has ss is left alone).
local function Hiss(line)
    local words = {}
    for s, w, e in line:gmatch("()([%w_]+)()") do
        if line:sub(s - 1, s - 1) ~= "{" and line:sub(e, e) ~= "}" and w:find("s", 2, true)
                and not w:find("ss", 1, true) then -- not blesssing
            words[#words + 1] = { s, e, w }
        end
    end
    if #words == 0 then return line end
    local pick = Pick(words)
    local w = pick[3]
    local at = w:match("^.*()s")
    return line:sub(1, pick[1] - 1) .. w:sub(1, at) .. w:sub(at) .. line:sub(pick[2])
end

---------------------------------------------------------------------------
-- rules.accented, split in two so the extras (tag, closer, opener) can be dropped to fit the chat limit:
-- Parts() returns { core, tagged?, closer?, opener?, tidy }.
---------------------------------------------------------------------------
local function Parts(accent, line, thick)
    if accent == "undead" then
        if not thick and random() < 0.5 then line = Hiss(line) end
        if not thick and random() < ns.STUTTER_CHANCE then line = Stutter(line) end
        line = Respell(line, thick and ns.JAWLESS or ns.LOCKED)
        if random() < (thick and ns.DROOL_CHANCE or ns.CLENCH_CHANCE) then
            line = Drool(line, thick and ns.DROOLS or ns.CLENCHES)
        end
        local p = { core = line }
        -- Jawless always ends on a gurgle; a locked jaw only STRAIN_CHANCE of the time, sometimes tucked in.
        if not EndsInSound(line) and (thick or random() < ns.STRAIN_CHANCE) then
            local sound = Pick(thick and ns.GURGLES or ns.STRAINS)
            if not thick and random() < ns.TUCK_CHANCE then p.core = Tuck(line, sound) else p.closer = sound end
        end
        return p
    end

    if accent == "orc" then
        line = OrcRequests(line)
        if thick then  -- short sentences, but "Thanks, {name}!" keeps its comma
            line = line:gsub(",%s*()", function(at)
                if line:sub(at, at) ~= "{" then return ". " end
            end)
        end
    end
    line = SwapWords(line, Rules(accent, thick))
    if accent == "troll" or accent == "dwarf" then line = DropGs(line) end
    if accent == "troll" then line = TrollTh(line) end
    if accent == "tauren" and thick and random() < ns.PAUSE_CHANCE then line = Pause(line) end
    local p = { core = EndWithStop(Tidy(line)), tidy = true }

    local T = ns.TEST
    local tags = ns.TAGS[accent]
    if #tags > 0 and not Has(p.core, T.TAGGED) and not (accent == "tauren" and Has(p.core, T.FRIEND))
            and random() < (thick and ns.TAG_CHANCE_THICK or ns.TAG_CHANCE)[accent] then
        p.tagged = AddTag(p.core, Pick(tags))
    end
    local said = p.tagged or p.core
    if accent == "troll" and thick and not Has(said, T.MOJO) and random() < ns.TROLL_CLOSER_CHANCE then
        p.closer = Pick(ns.TROLL_CLOSERS[Has(said, T.THANKS) and "thanks" or Has(said, T.FIGHT) and "fight"
                                         or Has(said, T.GLOOM) and "gloom" or "any"])
    elseif accent == "orc" and not Has(said, T.ORCISH)
            and random() < ns.ORC_CLOSER_CHANCE[thick and "thick" or "light"] then
        p.closer = Pick(ns.ORC_CLOSERS[OrcMood(said)])
    elseif accent == "dwarf" and thick and not Has(said, T.GAELIC) and random() < ns.DWARF_CLOSER_CHANCE then
        local C = ns.DWARF_CLOSERS
        if random() < 0.4 then
            p.tagged = AddTag((said:gsub(", lad", "")), C.tag)
        elseif not said:find("%?$") then -- not "Would ye like some pie? So it is."
            p.closer = Pick(C[(Has(said, T.THANKS) or Has(said, T.DRINK)) and "thanks" or Has(said, T.FIGHT) and "fight"
                              or Has(said, T.GLOOM) and "gloom" or "any"])
        end
    elseif accent == "tauren" and not said:find("%?$") and not Has(said, T.TAUREN)
            and random() < ns.TAUREN_CLOSER_CHANCE[thick and "thick" or "light"] then
        p.closer = Pick(ns.TAUREN_CLOSERS[thick and "thick" or "light"][Has(said, T.THANKS) and "thanks"
                        or Has(said, T.FIGHT) and "fight" or Has(said, T.GLOOM) and "gloom" or "any"])
    end
    if p.closer and said:lower():find(p.closer:lower(), 1, true) then p.closer = nil end -- not "Good day. Yes? Yes?"
    local openers = (thick and ns.THICK_OPENERS or ns.OPENERS)[accent]
    local list = openers.list
    if accent == "orc" then
        -- No greeting on a thanks or a line that already has one, and not "Bah. ... Bah."
        local text = p.closer and said .. " " .. p.closer or said
        local greeted = Has(text, T.THANKS) or Has(text, T.GREETED)
        list = {}
        for _, o in ipairs(openers.list) do
            if not (greeted and Contains(ns.ORC_GREETINGS, o)) and o ~= p.closer then list[#list + 1] = o end
        end
    end
    if random() < openers.chance and not StartsWithAny(said, T.OPENED.subs) and #list > 0 then
        p.opener = Pick(list)
    end
    return p
end

-- drop: 0 keeps every extra, 1 drops the opener, 2 the closer too, 3 the tag too.
local function Build(p, drop)
    local line = drop < 3 and p.tagged or p.core
    if drop < 2 and p.closer then line = line .. " " .. p.closer end
    if drop < 1 and p.opener then line = p.opener .. " " .. line end
    return p.tidy and Tidy(line) or line
end

function ns.Speak(accent, line, thick, max)
    if not accent or accent == "none" or not ns.WORDS then return line end
    if accent ~= "undead" and not ns.WORDS[accent] then return line end
    local text, saved = Protect(line)
    local p = Parts(accent, text, thick)
    local out
    for drop = 0, 3 do
        out = Restore(Build(p, drop), saved)
        if not max or #out <= max then break end
    end
    return out
end

-- Cut at spaces (never inside a link) into messages of at most max bytes; a single longer word goes alone.
function ns.Split(text, max)
    local text2, saved = Protect(text)
    local out, cur = {}, ""
    for word in text2:gmatch("%S+") do
        word = Restore(word, saved)
        if cur == "" then
            cur = word
        elseif #cur + 1 + #word <= max then
            cur = cur .. " " .. word
        else
            out[#out + 1] = cur
            cur = word
        end
    end
    if cur ~= "" then out[#out + 1] = cur end
    return out
end
