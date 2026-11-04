-- Options page: Esc > Options > AddOns > Buff Me Please. Built at login, once the saved variables exist.
local _, ns = ...

function ns.BuildSettings()
    local category, layout = Settings.RegisterVerticalLayoutCategory("Buff Me Please")
    ns.settingsCategory = category

    local function Header(text)
        layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(text))
    end

    local function Button(name, text, onClick, tooltip)
        layout:AddInitializer(CreateSettingsButtonInitializer(name, text, onClick, tooltip, false))
    end

    Header("Your character")
    -- Per character: each of your characters can have a voice of their own.
    local persona = Settings.RegisterAddOnSetting(category, "BUFFMEPLEASE_PERSONA", "persona", BuffMePleaseCharDB,
        Settings.VarType.String, "Personality", ns.DEFAULT_PERSONA)
    local function Options()
        local container = Settings.CreateControlTextContainer()
        for _, p in ipairs(ns.PERSONAS) do container:Add(p.key, p.label, p.desc) end
        return container:GetData()
    end
    Settings.CreateDropdown(category, persona, Options,
        "How this character asks for buffs and says thank you. Each character has their own.")
    local accent = Settings.RegisterAddOnSetting(category, "BUFFMEPLEASE_ACCENT", "accent", BuffMePleaseCharDB,
        Settings.VarType.String, "Accent", ns.DEFAULT_ACCENT)
    Settings.CreateDropdown(category, accent, function()
        local container = Settings.CreateControlTextContainer()
        for _, a in ipairs(ns.ACCENTS) do container:Add(a.key, a.label, a.desc) end
        return container:GetData()
    end, "The accent this character's lines are said in. Each character has their own.")
    local thick = Settings.RegisterAddOnSetting(category, "BUFFMEPLEASE_THICK", "thick", BuffMePleaseCharDB,
        Settings.VarType.Boolean, "Thick accent", false)
    Settings.CreateCheckbox(category, thick, "A thicker accent. For the undead: no jaw at all.")
    Button("Sample lines", "Preview", function() ns.Preview() end,
        "Prints a few lines in this personality and accent to your chat. Only you see them.")

    Header("Chat")
    local channel = Settings.RegisterAddOnSetting(category, "BUFFMEPLEASE_CHANNEL", "channel", BuffMePleaseDB,
        Settings.VarType.String, "Speak in", "SAY")
    Settings.CreateDropdown(category, channel, function()
        local container = Settings.CreateControlTextContainer()
        container:Add("SAY", "/say", "Everyone nearby hears you ask and thank.")
        container:Add("WHISPER", "Whisper", "Only your target hears you.")
        return container:GetData()
    end, "Where your asks and thank-yous go. Shared by all your characters.")

    Header("Button")
    local locked = Settings.RegisterAddOnSetting(category, "BUFFMEPLEASE_LOCKED", "locked", BuffMePleaseDB,
        Settings.VarType.Boolean, "Lock position", true)
    Settings.CreateCheckbox(category, locked, "Shift-drag always moves the button.")
    -- No inline binding rows or search tags: they taint the options search in Forever.
    Button("Key bindings", "Key Bindings",
        function() Settings.OpenToCategory(Settings.KEYBINDINGS_CATEGORY_ID, "Buff Me Please") end,
        "Bind the ask and thank keys in the Buff Me Please section of the Key Bindings page.")

    Settings.RegisterAddOnCategory(category)
end
