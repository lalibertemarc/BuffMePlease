-- Buff Me Please: asks your friendly target, in /say (or a whisper) and in your character's own voice,
-- for the buff their class can give you.
local _, ns = ...

-- The key bindings (Bindings.xml) click the buttons, so they work with the UI hidden (e.g. EzCinematic).
BINDING_HEADER_BUFFMEPLEASE = "Buff Me Please"
_G["BINDING_NAME_CLICK BuffMePleaseButton:LeftButton"] = "Ask your target for a buff"
_G["BINDING_NAME_CLICK BuffMePleaseThanksButton:LeftButton"] = "Thank your target"

---------------------------------------------------------------------------
-- API compat (old classic globals vs. modern C_ namespaces)
---------------------------------------------------------------------------
local function SpellInfo(id)
    if C_Spell and C_Spell.GetSpellInfo then
        local info = C_Spell.GetSpellInfo(id)
        if info then return info.name, info.iconID end
    elseif GetSpellInfo then
        local name, _, icon = GetSpellInfo(id)
        return name, icon
    end
end

-- chatType "SAY", or "WHISPER" to target (a full name: "First Surname" in Forever, "Name-Realm" in Era).
local function Send(msg, chatType, target)
    if C_ChatInfo and C_ChatInfo.SendChatMessage then
        C_ChatInfo.SendChatMessage(msg, chatType, nil, target)
    else
        SendChatMessage(msg, chatType, nil, target)
    end
end

-- Encounters and similar lock addon chat (C_ChatInfo.InChatMessagingLockdown). A real game block:
-- SendChatMessage then raises ADDON_ACTION_BLOCKED.
local function ChatLocked()
    return C_ChatInfo and C_ChatInfo.InChatMessagingLockdown and C_ChatInfo.InChatMessagingLockdown()
end

-- Forever's client hides aura data from addons in some situations (e.g. combat) as "secret" values.
local issecret = issecretvalue or function() return false end

local function AurasHidden()
    return C_Secrets and C_Secrets.ShouldAurasBeSecret and C_Secrets.ShouldAurasBeSecret()
end

-- Returns name, expirationTime, spellId of the i-th buff; nil past the end; false if auras are hidden.
local function BuffAt(unit, i)
    if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
        -- Index access throws while auras are secret, so never call it bare.
        local ok, a = pcall(C_UnitAuras.GetAuraDataByIndex, unit, i, "HELPFUL")
        if not ok or issecret(a) then return false end
        if a then return a.name, a.expirationTime, a.spellId end
    else
        local name, _, _, _, _, expires, _, _, _, spellId = UnitBuff(unit, i)
        return name, expires, spellId
    end
end

-- Seconds left on the aura of that spell on you (0 if it never expires), including hidden ones like the
-- camp objects'; nil without it or while it's hidden.
local function AuraLeft(spellId)
    if not (C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID) then return nil end
    local ok, a = pcall(C_UnitAuras.GetPlayerAuraBySpellID, spellId)
    if not ok or not a or issecret(a) or issecret(a.expirationTime) then return nil end
    return a.expirationTime > 0 and a.expirationTime - GetTime() or 0
end

---------------------------------------------------------------------------
-- Spell data
---------------------------------------------------------------------------
local buff = {}      -- key -> { name, icon, level (first rank learned) }
local nameToKey = {} -- localized buff name (normal or group version) -> key

-- Strength (learn level) of the highest rank of key a caster of this level knows; 0 if none.
local function BestRank(key, level)
    local best = 0
    for _, r in ipairs(ns.BUFFS[key].ranks) do
        if r[2] <= level then best = r[2] end
    end
    return best
end

-- Spell ID of any rank -> its strength: the learn level of the normal rank as strong as it.
-- Group ranks match the best normal rank at their level (Greater Kings at 60 is Kings at 20).
local rankLevel = {}
for key, b in pairs(ns.BUFFS) do
    for _, r in ipairs(b.ranks) do rankLevel[r[1]] = r[2] end
    for _, r in ipairs(b.group) do rankLevel[r[1]] = BestRank(key, r[2]) end
end

local function RefreshSpells()
    wipe(nameToKey)
    for key, b in pairs(ns.BUFFS) do
        local name, icon = SpellInfo(b.ranks[1][1])
        buff[key] = { name = name or key, icon = icon or 134400, level = b.ranks[1][2] }
        for _, t in ipairs({ b.ranks, b.group }) do
            local n = SpellInfo(t[1][1]) -- every rank shares the name
            if n then nameToKey[n] = key end
        end
    end
end

---------------------------------------------------------------------------
-- Evaluation
---------------------------------------------------------------------------
-- key -> { remaining = seconds or nil, rank = learn level or nil, camp } for each tracked buff you have,
-- or nil if the game hides your buffs. rank is nil when the spell ID is unknown or hidden. camp = a camp
-- object gives it instead (ns.CAMP), so no one can renew it.
local function MyBuffs()
    if AurasHidden() then return nil end
    local found, now = {}, GetTime()
    for i = 1, 40 do
        local name, expires, spellId = BuffAt("player", i)
        if name == false then return nil end
        if not name then break end
        local key = not (issecret(name) or issecret(expires)) and nameToKey[name]
        if key then
            found[key] = {
                remaining = (expires and expires > 0) and (expires - now) or nil,
                rank = spellId and not issecret(spellId) and rankLevel[spellId] or nil,
            }
        end
    end
    for key, spellId in pairs(ns.CAMP) do
        local left = not found[key] and AuraLeft(spellId)
        if left then found[key] = { remaining = left > 0 and left or nil, camp = true } end
    end
    return found
end

local function ValidTarget(unit)
    return UnitExists(unit) and UnitIsPlayer(unit) and UnitIsFriend("player", unit)
        and not UnitIsUnit(unit, "player") and not UnitIsDeadOrGhost(unit)
end

-- "First Surname"; Forever's UnitName returns the surname where Classic Era returns the realm ("Name-Realm").
local function FullName(unit)
    local name, surname = UnitName(unit)
    if not name or issecret(name) then return nil end
    if surname and not issecret(surname) and surname ~= "" then return name .. (ns.ERA and "-" or " ") .. surname end
    return name
end

-- The buffs a class can give that your own class has a use for, most wanted first.
local function Wants(class)
    local unwanted = ns.UNWANTED[select(2, UnitClass("player"))] or ns.UNWANTED_DEFAULT
    local list = {}
    for _, key in ipairs(ns.GIVES[class] or {}) do
        if not unwanted[key] then list[#list + 1] = key end
    end
    return list
end

-- Result: { name, class, list = { { key, have, expiring, remaining, young } }, demand = key or nil,
-- refresh, hidden, young, given }, or nil when the target isn't a friendly player. The list is empty
-- when their class has nothing you'd want. expiring = you have it but it's about to drop
-- (ns.REFRESH_THRESHOLD), so it's asked for again; refresh = the demand is such a buff. young = the
-- target is below the level that buff is learned at (result: that's why nothing is asked for). A buff
-- expiring at a higher rank than any the target knows isn't asked for: theirs wouldn't land. hidden =
-- your buffs couldn't be read, so the most wanted buff is asked for. given = nothing left to ask for.
local function Evaluate(unit)
    if not ValidTarget(unit) then return nil end
    local name = FullName(unit)
    if not name then return nil end
    local _, class = UnitClass(unit)
    local level = UnitLevel(unit)
    if not level or issecret(level) or level <= 0 then level = math.huge end -- -1 means far above you

    local have = MyBuffs()
    local r = { name = name, class = class, list = {}, hidden = have == nil }
    have = have or {}
    for _, key in ipairs(Wants(class)) do
        local h, best = have[key], BestRank(key, level)
        local e = { key = key, have = h ~= nil, remaining = h and h.remaining, young = best == 0, camp = h and h.camp }
        -- A camp's buff blocks theirs until it drops, so it's never asked for again early.
        e.expiring = not e.camp and e.remaining ~= nil and e.remaining <= ns.REFRESH_THRESHOLD
        local outranked = e.expiring and h.rank ~= nil and h.rank > best
        r.list[#r.list + 1] = e
        if e.young and not e.have then r.young = true end
        if not (r.demand or e.young or outranked) and (e.expiring or not e.have) then
            r.demand, r.refresh = key, e.expiring
        end
    end
    r.given = not r.demand and #r.list > 0 and not r.young
    return r
end

---------------------------------------------------------------------------
-- Messages
---------------------------------------------------------------------------
local function Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cffe6b34dBuff Me Please|r: " .. msg)
end

-- This character's personality key (ns.PERSONA), "mixed" included.
function ns.PersonaKey()
    local p = BuffMePleaseCharDB and BuffMePleaseCharDB.persona
    return ns.PERSONA[p] and p or ns.DEFAULT_PERSONA
end

-- The personality that speaks this line: yours, or a random one when you're "mixed".
local function Speaker()
    local p = ns.PersonaKey()
    if p ~= "mixed" then return p end
    local keys = {}
    for _, q in ipairs(ns.PERSONAS) do
        if q.key ~= "mixed" then keys[#keys + 1] = q.key end
    end
    return keys[math.random(#keys)]
end

-- This character's accent choice (ns.ACCENT), "race" included.
function ns.AccentKey()
    local a = BuffMePleaseCharDB and BuffMePleaseCharDB.accent
    return ns.ACCENT[a] and a or ns.DEFAULT_ACCENT
end

-- The accent that choice speaks in, nil for plain.
local function ChosenAccent()
    local a = ns.AccentKey()
    if a == "race" then return ns.RACE_ACCENT[select(2, UnitRace("player"))] end
    if a ~= "none" then return a end
end

-- Thick: undead with no jaw at all (the "jawless" choice); the other accents have no thick choice here.
local THICK = { jawless = true }
-- The accent engine's name for each choice (Accent.lua speaks "undead", thick or not).
local ENGINE = { jawless = "undead" }

-- A woman hears the accent's "lad" and "bruddah" as "lass" and "sistah" (ns.TO_HER), only where the accent put
-- them in: words the plain line already has are left alone.
local function HasWord(s, w)
    return s:lower():find("%f[%a]" .. w .. "%f[%A]") ~= nil
end

local function Cap(s) return s:sub(1, 1):upper() .. s:sub(2) end

local function ToHer(said, text)
    for _, w in ipairs(ns.TO_HER) do
        local typed = false
        for _, t in ipairs(w.typed) do typed = typed or HasWord(text, t) end
        if not typed then
            if HasWord(said, w.she) then said = said:gsub(", " .. w.he .. "%f[%A]", "") end
            said = said:gsub("%f[%a]" .. w.he .. "%f[%A]", w.she):gsub("%f[%a]" .. Cap(w.he) .. "%f[%A]", Cap(w.she))
        end
    end
    return said
end

-- 3 when the unit is a woman, 2 a man, nil unknown or hidden.
local function Sex(unit)
    local sex = unit and UnitSex(unit)
    if sex and not issecret(sex) and (sex == 2 or sex == 3) then return sex end
end

-- Lines of that kind ("asks", "refreshes", "thanks") for the speaker.
local function Lines(kind, persona)
    local lines = ns.VOICES[persona] and ns.VOICES[persona][kind]
    if not lines or #lines == 0 then lines = ns.VOICES[ns.DEFAULT_PERSONA][kind] end
    return lines
end

local lastPick = {} -- lines table -> index said last time

-- Placeholders put in after the accent, so they're never respelled (and the link filter finds the name as is).
local AFTER = { name = true, buff = true }

-- A random line of that kind (not the one said last time) in your accent: {me} and {my} are filled in before the
-- accent, {name} and {buff} after it. The plain line when the accent would pass the chat limit. unit: your target,
-- for "lad" or "lass".
local function Line(kind, name, buffName, unit)
    local lines = Lines(kind, Speaker())
    local i = math.random(#lines)
    if #lines > 1 and i == lastPick[lines] then i = i % #lines + 1 end
    lastPick[lines] = i
    local group = IsInGroup() and "group" or "solo"
    local fill = { name = name, buff = buffName or "", me = ns.ME[group], my = ns.MY[group] }
    -- Function replacements, so a "%" in a name can't break gsub.
    local text = lines[i]:gsub("{(%a+)}", function(key) if not AFTER[key] then return fill[key] end end)
    local function Filled(s) return (s:gsub("{(%a+)}", function(key) if AFTER[key] then return fill[key] end end)) end
    local accent = ChosenAccent()
    if accent then
        local grow = 0
        for key in text:gmatch("{(%a+)}") do
            if AFTER[key] then grow = grow + #fill[key] - #key - 2 end
        end
        local said = ns.Speak(ENGINE[accent] or accent, text, THICK[accent] or false, ns.MAX_CHAT - math.max(grow, 0))
        if Sex(unit) == 3 then said = ToHer(said, text) end
        said = Filled(said)
        if #said <= ns.MAX_CHAT then return said end
    end
    return Filled(text)
end

-- A few sample lines in your chat only, for the options page.
function ns.Preview()
    local p = ns.PERSONA[ns.PersonaKey()]
    local sample = buff.KINGS and buff.KINGS.name or "Blessing of Kings"
    local a = ChosenAccent()
    a = a and ns.ACCENT[a].label:lower()
    Print("In a " .. p.label:lower() .. " voice" .. (a and ", with " .. (a:find("^[aeiou]") and "an " or "a ") .. a .. " accent" or "") .. ":")
    for _, kind in ipairs({ "asks", "asks", "refreshes", "thanks" }) do
        DEFAULT_CHAT_FRAME:AddMessage("  " .. Line(kind, "Bob Smith", sample))
    end
end

---------------------------------------------------------------------------
-- Target links
---------------------------------------------------------------------------
-- The server won't take player links in sent chat, so the name goes out as plain text and is turned
-- into a link when your own line comes back. Only you see the link.
local said = {} -- your last few lines, newest last: { msg, name, class }

local function Remember(msg, name, class)
    said[#said + 1] = { msg = msg, name = name, class = class }
    if #said > 5 then table.remove(said, 1) end
end

-- Class-colored link on the full name, "First Surname" like Blizzard's own chat links.
local function NameLink(name, class)
    local c = RAID_CLASS_COLORS[class]
    local link = format("|Hplayer:%s|h%s|h", name, name)
    return c and c.colorStr and format("|c%s%s|r", c.colorStr, link) or link
end

-- CHAT_MSG_SAY / CHAT_MSG_WHISPER_INFORM filter: returning false keeps the line; the message, if any, replaces it.
local function LinkTarget(_, _, msg, ...)
    if issecret(msg) then return false end
    for _, s in ipairs(said) do
        if s.msg == msg then
            local link = NameLink(s.name, s.class)
            local pattern = s.name:gsub("%p", "%%%0")
            return false, (msg:gsub(pattern, function() return link end)), ...
        end
    end
    return false
end

local lastSaid = -math.huge -- GetTime() of your last line

-- Whispering instead of saying (BuffMePleaseDB.channel, /say by default).
local function Whispering()
    return BuffMePleaseDB.channel == "WHISPER"
end

-- "/say" or "a whisper", for tooltips.
local function ChannelText()
    return Whispering() and "a whisper" or "/say"
end

-- Says the message, or whispers it to the target, unless the game blocks addon chat. name/class:
-- the target, linked in your chat.
local function SayOrWarn(msg, name, class)
    if ChatLocked() then return Print("The game blocks addon chat right now.") end
    local now = GetTime()
    if now - lastSaid < ns.SAY_COOLDOWN then return end -- double click: drop it quietly
    lastSaid = now
    Remember(msg, name, class)
    if Whispering() then Send(msg, "WHISPER", name) else Send(msg, "SAY") end
end

-- /buffme say | whisper: where your lines go.
local function SetChannel(channel)
    BuffMePleaseDB.channel = channel
    Print(channel == "WHISPER" and "Lines are now whispered to your target." or "Lines are now said in /say.")
end

local function Ask()
    if not ValidTarget("target") then return Print("Target a friendly player to ask for a buff.") end
    local r = Evaluate("target")
    if not r then return Print("Your target's name is hidden by the game right now.") end
    if r.demand then
        return SayOrWarn(Line(r.refresh and "refreshes" or "asks", r.name, buff[r.demand].name, "target"), r.name, r.class)
    end
    Print((#r.list == 0 and r.name .. " has no buff you need.")
        or (r.young and r.name .. " is too young to know the buff you need.")
        or ("You already have everything " .. r.name .. " can give."))
end

-- Thanks any friendly target, not only those with a buff for you.
local function Thank()
    local name = ValidTarget("target") and FullName("target")
    if not name then return Print("Target a friendly player to thank.") end
    SayOrWarn(Line("thanks", name, nil, "target"), name, select(2, UnitClass("target")))
end

local function OpenSettings()
    if InCombatLockdown() then return Print("Options can't open in combat.") end
    if ns.settingsCategory then Settings.OpenToCategory(ns.settingsCategory:GetID()) end
end

-- "a, b, c" from the keys of ns.PERSONAS or ns.ACCENTS.
local function KeyList(list)
    local keys = {}
    for _, p in ipairs(list) do keys[#keys + 1] = p.key end
    return table.concat(keys, ", ")
end

local function PersonaList() return KeyList(ns.PERSONAS) end

-- /buffme persona [key]: shows or sets this character's personality.
local function SetPersona(key)
    key = key:lower()
    if key == "" then
        local p = ns.PERSONA[ns.PersonaKey()]
        Print("Personality: " .. p.label .. ". " .. p.desc)
        return Print("Change it with /buffme persona <" .. PersonaList() .. ">.")
    end
    if not ns.PERSONA[key] then return Print("Unknown personality. Pick one of: " .. PersonaList() .. ".") end
    BuffMePleaseCharDB.persona = key
    Print("Personality: " .. ns.PERSONA[key].label .. ". " .. ns.PERSONA[key].desc)
end

-- /buffme accent [key]: shows or sets this character's accent.
local function SetAccent(key)
    key = key:lower()
    if key ~= "" and not ns.ACCENT[key] then
        return Print("Unknown accent. Pick one of: " .. KeyList(ns.ACCENTS) .. ".")
    end
    if key ~= "" then BuffMePleaseCharDB.accent = key end
    local a = ns.ACCENT[ns.AccentKey()]
    Print("Accent: " .. a.label .. ". " .. a.desc)
    if key == "" then return Print("Change it with /buffme accent <" .. KeyList(ns.ACCENTS) .. ">.") end
end

-- EzAccent's accent changed (EzAccentAPI): the same accent here, undead jawless when thick (the other accents have
-- no thick choice here). A "race" choice that already speaks it is kept.
local function FromEzAccent(accent, thick)
    local key = accent == "undead" and thick and "jawless" or accent
    if not ns.ACCENT[key] then key = "none" end
    if ChosenAccent() == (key ~= "none" and key or nil) then return end
    BuffMePleaseCharDB.accent = key
    return "BuffMePlease to " .. ns.ACCENT[key].label
end

---------------------------------------------------------------------------
-- Buttons
---------------------------------------------------------------------------
local current -- last Evaluate() result for the target, nil when it isn't a friendly player
local Update  -- refreshes the buttons and tooltip; defined below

local function IconButton(name, parent, size)
    local b = CreateFrame("Button", name, parent)
    b:SetSize(size, size)
    b:RegisterForDrag("LeftButton")
    b:RegisterForClicks(GetCVarBool("ActionButtonUseKeyDown") and "LeftButtonDown" or "LeftButtonUp")
    b:EnableMouse(false)
    b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")

    b.border = b:CreateTexture(nil, "BACKGROUND")
    b.border:SetPoint("TOPLEFT", -2, 2)
    b.border:SetPoint("BOTTOMRIGHT", 2, -2)
    b.border:SetColorTexture(0, 0, 0)

    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetAllPoints()
    b.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    return b
end

local btn = IconButton("BuffMePleaseButton", UIParent, 40)
btn:SetFrameStrata("MEDIUM")
btn:SetMovable(true)
btn:SetClampedToScreen(true)
btn:SetAlpha(0)

btn.check = btn:CreateTexture(nil, "OVERLAY")
btn.check:SetSize(22, 22)
btn.check:SetPoint("BOTTOMRIGHT", 4, -4)
btn.check:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready")

-- Right-click opens the options (personality); the key binding always clicks LeftButton.
local keyDown = GetCVarBool("ActionButtonUseKeyDown")
btn:RegisterForClicks(keyDown and "LeftButtonDown" or "LeftButtonUp", keyDown and "RightButtonDown" or "RightButtonUp")
btn:SetScript("OnClick", function(_, button)
    if button == "RightButton" then return OpenSettings() end
    Ask()
end)

-- Child of the ask button: moves and fades with it.
local thanks = IconButton("BuffMePleaseThanksButton", btn, 32)
thanks:SetPoint("LEFT", btn, "RIGHT", 8, 0)
thanks.icon:SetTexture(ns.THANKS_ICON)
thanks:SetScript("OnClick", Thank)

local function ApplyPosition()
    local p = BuffMePleaseDB.pos
    btn:ClearAllPoints()
    if p then
        btn:SetPoint(p[1], UIParent, p[2], p[3], p[4])
    elseif EzBlessingsButton then
        -- EzBlessings (paladins only) sits on the same spot by the target frame, its label to the
        -- right: go under it instead, and follow it wherever it's moved.
        btn:SetPoint("TOPLEFT", EzBlessingsButton, "BOTTOMLEFT", 0, -10)
    else
        btn:SetPoint("LEFT", TargetFrame, "RIGHT", -10, 10)
    end
end

-- Dragging either button moves the pair.
local function DragStart()
    if BuffMePleaseDB.locked and not IsShiftKeyDown() then return end
    btn:StartMoving()
    btn.moving = true
end
-- Also fires after a drag that never started (locked): saving then would store the default anchor without TargetFrame.
local function DragStop()
    if not btn.moving then return end
    btn.moving = false
    btn:StopMovingOrSizing()
    local point, _, relPoint, x, y = btn:GetPoint()
    BuffMePleaseDB.pos = { point, relPoint, x, y }
end

for _, b in ipairs({ btn, thanks }) do
    b:SetScript("OnDragStart", DragStart)
    b:SetScript("OnDragStop", DragStop)
end

---------------------------------------------------------------------------
-- Tooltip
---------------------------------------------------------------------------
local function FormatTime(sec)
    if not sec then return "" end
    return sec >= 60 and format(" (%dm)", floor(sec / 60)) or format(" (%ds)", floor(sec))
end

local function ShowTooltip()
    if not current then return GameTooltip:Hide() end
    local c = RAID_CLASS_COLORS[current.class] or NORMAL_FONT_COLOR
    GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
    GameTooltip:AddLine(current.name, c.r, c.g, c.b)
    if current.hidden and current.demand then
        GameTooltip:AddLine("Your buffs are hidden by the game right now.", 1, 0.5, 0.1)
        GameTooltip:AddLine("Asking for the most wanted.", 1, 0.5, 0.1)
    end
    GameTooltip:AddLine(" ")
    for _, e in ipairs(current.list) do
        local state = (e.camp and "|cff40ff40have, from camp|r") or (e.expiring and "|cffffd000have, expiring|r")
            or (e.have and "|cff40ff40have|r")
            or (e.young and format("|cff808080too young (%d)|r", buff[e.key].level)) or "|cffff4040missing|r"
        GameTooltip:AddDoubleLine(buff[e.key].name, state .. FormatTime(e.remaining), 1, 1, 1)
    end
    GameTooltip:AddLine(" ")
    if current.demand then
        GameTooltip:AddLine((current.refresh and "Click to ask for a refresh in " or "Click to ask in ") .. ChannelText(), 1, 0.82, 0)
    else
        GameTooltip:AddLine(current.young and "Too young to give you what you need." or "You have all they can give.", 0.6, 0.6, 0.6)
    end
    GameTooltip:AddLine("Right-click to change your personality (" .. ns.PERSONA[ns.PersonaKey()].label .. ")", 1, 0.82, 0)
    GameTooltip:AddLine("Key bindings: Options > Keybindings > Buff Me Please", 0.6, 0.6, 0.6)
    GameTooltip:AddLine(BuffMePleaseDB.locked and "Shift-drag to move" or "Drag to move", 0.6, 0.6, 0.6)
    GameTooltip:Show()
end

btn:SetScript("OnEnter", function(self) self.hover = true; ShowTooltip() end)
btn:SetScript("OnLeave", function(self) self.hover = false; GameTooltip:Hide() end)

thanks:SetScript("OnEnter", function(self)
    if not current then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine("Thank " .. current.name, 1, 0.82, 0)
    GameTooltip:AddLine("Click to thank them in " .. ChannelText(), 0.6, 0.6, 0.6)
    GameTooltip:Show()
end)
thanks:SetScript("OnLeave", function() GameTooltip:Hide() end)

---------------------------------------------------------------------------
-- Update
---------------------------------------------------------------------------
function Update()
    current = Evaluate("target")
    if current and #current.list == 0 then current = nil end -- nothing to ask them for: no icon
    -- Stays clickable through the key bindings while invisible, so they can ask for a target.
    btn:SetAlpha(current and 1 or 0)
    btn:EnableMouse(current ~= nil)
    thanks:EnableMouse(current ~= nil)
    if current then
        local key = current.demand or current.list[1].key
        btn.icon:SetTexture(buff[key].icon)
        btn.icon:SetDesaturated(current.demand == nil)
        btn.check:SetShown(current.given)
        -- Gold border while the ask is a refresh, like EzBlessings' expiring blessing.
        if current.refresh then btn.border:SetColorTexture(1, 0.8, 0) else btn.border:SetColorTexture(0, 0, 0) end
    end
    if btn.hover then ShowTooltip() end
end

---------------------------------------------------------------------------
-- Slash commands
---------------------------------------------------------------------------
local HELP = {
    "/buffme - ask your target for a buff",
    "/buffme thanks - thank your target",
    "/buffme persona [name] - show or change your personality",
    "/buffme accent [race | none | orc | troll | dwarf | undead | jawless] - show or change your accent",
    "/buffme say | whisper - say your lines (default) or whisper them to your target",
    "/buffme preview - sample lines in your personality (only you see them)",
    "/buffme config - open the options",
    "/buffme lock | unlock - lock button position (shift-drag always moves)",
    "/buffme reset - reset button position",
}

local COMMANDS = {
    [""]    = Ask,
    thanks  = Thank,
    persona = SetPersona,
    accent  = SetAccent,
    say    = function() SetChannel("SAY") end,
    whisper = function() SetChannel("WHISPER") end,
    preview = function() ns.Preview() end,
    config  = OpenSettings,
    lock    = function() BuffMePleaseDB.locked = true; Print("Locked.") end,
    unlock  = function() BuffMePleaseDB.locked = false; Print("Unlocked.") end,
    reset   = function()
        BuffMePleaseDB.pos = nil
        ApplyPosition()
        Print("Position reset.")
    end,
}

SLASH_BUFFMEPLEASE1 = "/buffme"
SLASH_BUFFMEPLEASE2 = "/bmp"
SlashCmdList.BUFFMEPLEASE = function(msg)
    local cmd, arg = strtrim(msg):match("^(%S*)%s*(.-)$")
    local fn = COMMANDS[cmd:lower()]
    if fn then
        fn(arg)
        Update()
    else
        for _, line in ipairs(HELP) do Print(line) end
    end
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------
local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function(self, event, unit)
    if event == "UNIT_AURA" and unit ~= "player" then return end
    if event == "PLAYER_LOGIN" then
        -- EzMinion already does this job on a warlock (it does nothing on other classes): stand down,
        -- no buttons, binding or options. Never DisableAddOn from code: it bleeds to other characters.
        local IsLoaded = (C_AddOns and C_AddOns.IsAddOnLoaded) or IsAddOnLoaded
        if IsLoaded("EzMinion") and select(2, UnitClass("player")) == "WARLOCK" then
            btn:Hide() -- hides the thanks button with it
            btn:SetScript("OnClick", nil)
            thanks:SetScript("OnClick", nil)
            SlashCmdList.BUFFMEPLEASE = function() Print("Off on this character: EzMinion handles your buffs.") end
            self:UnregisterAllEvents()
            ns.VOICES = nil -- nothing to say on this character
            return
        end
        BuffMePleaseDB = BuffMePleaseDB or {}
        if BuffMePleaseDB.locked == nil then BuffMePleaseDB.locked = true end
        BuffMePleaseDB.channel = BuffMePleaseDB.channel or "SAY"
        BuffMePleaseDB.lines = nil -- the old /buffme lines setting, gone with Generated.lua
        BuffMePleaseCharDB = BuffMePleaseCharDB or {}
        -- First login: borrow the personality this character already has in Campfire Tales, if any.
        local campfire = CampfireTalesForeverChar and CampfireTalesForeverChar.persona
        BuffMePleaseCharDB.persona = BuffMePleaseCharDB.persona or (ns.PERSONA[campfire] and campfire) or ns.DEFAULT_PERSONA
        BuffMePleaseCharDB.accent = ns.ACCENT[BuffMePleaseCharDB.accent] and BuffMePleaseCharDB.accent or ns.DEFAULT_ACCENT
        if EzAccentAPI then EzAccentAPI.OnAccentChanged(FromEzAccent) end
        ApplyPosition()
        ns.BuildSettings()
        local AddFilter = (ChatFrameUtil and ChatFrameUtil.AddMessageEventFilter) or ChatFrame_AddMessageEventFilter
        if AddFilter then
            AddFilter("CHAT_MSG_SAY", LinkTarget)
            AddFilter("CHAT_MSG_WHISPER_INFORM", LinkTarget)
        end
        -- Combat end: buffs hidden in combat become readable again.
        for _, e in ipairs({ "PLAYER_TARGET_CHANGED", "UNIT_AURA", "SPELLS_CHANGED", "PLAYER_REGEN_ENABLED", "PLAYER_ENTERING_WORLD" }) do
            self:RegisterEvent(e)
        end
        -- A buff crossing the refresh threshold fires no event.
        C_Timer.NewTicker(1, Update)
    end
    if event == "PLAYER_LOGIN" or event == "SPELLS_CHANGED" then
        RefreshSpells()
    end
    Update()
end)
