std = "lua51"
max_line_length = false
self = false
exclude_files = { "tests/" }

globals = {
    "BuffMePleaseDB",
    "BuffMePleaseCharDB",
    "SLASH_BUFFMEPLEASE1",
    "SLASH_BUFFMEPLEASE2",
    "SlashCmdList",
    "BINDING_HEADER_BUFFMEPLEASE",
    "_G",
}

read_globals = {
    -- Lua / WoW utility
    "format", "strtrim", "wipe", "floor",
    -- Frames & UI
    "CreateFrame", "UIParent", "TargetFrame", "EzBlessingsButton", "GameTooltip", "DEFAULT_CHAT_FRAME",
    "RAID_CLASS_COLORS", "NORMAL_FONT_COLOR",
    -- Settings panel
    "Settings", "CreateSettingsListSectionHeaderInitializer", "CreateSettingsButtonInitializer",
    -- Namespaced APIs
    "C_AddOns", "IsAddOnLoaded", "C_Spell", "C_UnitAuras", "C_Timer", "C_ChatInfo", "C_Secrets", "issecretvalue",
    "ChatFrameUtil", "ChatFrame_AddMessageEventFilter",
    -- Global APIs
    "GetBuildInfo", "GetSpellInfo", "GetTime", "UnitBuff", "UnitClass", "UnitName", "UnitLevel", "UnitIsUnit", "UnitExists", "UnitIsPlayer",
    "UnitIsFriend", "UnitIsDeadOrGhost", "UnitRace", "UnitSex", "IsInGroup", "SendChatMessage", "GetCVarBool", "IsShiftKeyDown", "InCombatLockdown",
    -- Other addons
    "CampfireTalesForeverChar", "EzAccentAPI",
}
