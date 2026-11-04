-- Checks the lines outside the game (Lua 5.1, also in CI): lua tests/lines.lua [print]
-- Every personality has asks, refreshes and thanks; every placeholder is one its kind fills; and every line, said
-- live in every accent the way Core.lua's Line() does it ({me}/{my} filled, ns.Speak, then {name} and {buff}),
-- keeps its {name} and {buff} and stays inside the chat limit with long words filled in. "print" also prints one line per pool and accent.
local ns = {}
GetBuildInfo = function() return "1.60.1", "0", "", 16001 end
for _, file in ipairs({ "Data.lua", "Voices.lua", "AccentRules.lua", "Accent.lua" }) do
    assert(loadfile(file))("BuffMePlease", ns)
end
local show = arg[1] == "print"

local failures = 0
local function Fail(msg)
    failures = failures + 1
    print("FAIL: " .. msg)
end

local KINDS = { asks = { name = true, buff = true, me = true, my = true },
                refreshes = { name = true, buff = true, me = true, my = true },
                thanks = { name = true, me = true, my = true } }
-- The longest words a line can get: a group ("us", "our"), a long buff, a long full name.
local LONG = { name = "Bartholomewsy Thunderhammer", buff = "Greater Blessing of Sanctuary", me = "us", my = "our" }
-- Same as Core.lua's AFTER: put in after the accent.
local AFTER = { name = true, buff = true }
local function Count(s, key) return select(2, s:gsub("{" .. key .. "}", "")) end

local lines = 0
for _, p in ipairs(ns.PERSONAS) do
    if p.key ~= "mixed" then
        local voice = ns.VOICES[p.key]
        if not voice then Fail("no lines for " .. p.key) end
        for kind, allowed in pairs(KINDS) do
            local pool = voice and voice[kind]
            if not pool or #pool == 0 then Fail(p.key .. "." .. kind .. ": empty") end
            for i, text in ipairs(pool or {}) do
                lines = lines + 1
                local where = p.key .. "." .. kind .. "#" .. i
                for key in text:gmatch("{(%a+)}") do
                    if not allowed[key] then Fail(where .. ": {" .. key .. "} not filled here") end
                end
                if not text:find("{name}", 1, true) then Fail(where .. ": no {name}") end
                if text:find("^{m[ey]}") then Fail(where .. ": starts with {me}/{my}") end
            end
        end
    end
end
for _, p in pairs(ns.VOICES) do
    if type(p) ~= "table" then Fail("ns.VOICES has a non-table entry") end
end
for key in pairs(ns.VOICES) do
    if not ns.PERSONA[key] or key == "mixed" then Fail("lines for an unknown personality: " .. key) end
end

-- Every accent the options offer ("race" picks one of them), light and thick.
math.randomseed(1)
local said = 0
for _, a in ipairs(ns.ACCENTS) do
    if a.key ~= "race" and a.key ~= "none" then
        for _, p in ipairs(ns.PERSONAS) do
            for kind in pairs(KINDS) do
                for i, text in ipairs(ns.VOICES[p.key] and ns.VOICES[p.key][kind] or {}) do
                    local where = a.key .. ": " .. p.key .. "." .. kind .. "#" .. i
                    local filled = text:gsub("{(%a+)}", function(k) if not AFTER[k] then return LONG[k] end end)
                    local function Final(s) return (s:gsub("{(%a+)}", function(k) if AFTER[k] then return LONG[k] end end)) end
                    local grow = 0
                    for k in filled:gmatch("{(%a+)}") do grow = grow + #LONG[k] - #k - 2 end
                    for n = 1, 4 do
                        local thick = n > 2 -- light twice, thick twice
                        local out = ns.Speak(a.key, filled, thick, ns.MAX_CHAT - math.max(grow, 0))
                        said = said + 1
                        for k in pairs(AFTER) do
                            if Count(out, k) ~= Count(filled, k) then Fail(where .. ": {" .. k .. "} lost: " .. out) end
                        end
                        local final = Final(out)
                        if final:find("[{}]") then Fail(where .. ": stray brace: " .. final) end
                        if #final > ns.MAX_CHAT and #Final(filled) > ns.MAX_CHAT then Fail(where .. ": too long even plain") end
                        if show and (n == 1 or n == 3) and i == 1 then print(where .. (thick and " (thick)" or "") .. "  " .. final) end
                    end
                end
            end
        end
    end
end

print(("%d lines, %d accented sayings, %d failures"):format(lines, said, failures))
os.exit(failures == 0 and 0 or 1)
