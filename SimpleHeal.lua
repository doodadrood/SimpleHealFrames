local addonName, addonTable = ...
local frame = CreateFrame("Frame")

-- Base Universal Defaults (All Classes)
local baseDefaults = {
    click1 = "", click2 = "", click3 = "", click4 = "", click5 = "",
    shift1 = "", shift2 = "", shift3 = "", shift4 = "", shift5 = "",
    ctrl1 = "", ctrl2 = "", ctrl3 = "", ctrl4 = "", ctrl5 = "",
    alt1 = "", alt2 = "", alt3 = "", alt4 = "", alt5 = "",
    ctrlalt1 = "target",
    ctrlalt2 = "togglemenu",
    ctrlalt3 = "", ctrlalt4 = "", ctrlalt5 = "",
    ctrlaltshift1 = "caststoredbuff",
    ctrlaltshift2 = "openbuffmenu",
    buffAlertEnabled = true,
    buffAlertOutline = true,
    buffAlertTags = true,
    buffCycleReset = 5
}

-- Per-Class Default Profiles
local classDefaults = {
    PALADIN = {
        click1 = "Flash of Light",
        click2 = "Holy Light",
        click3 = "Holy Shock",
        click4 = "Blessing of Freedom",
        click5 = "Blessing of Protection",
        shift1 = "Light's Vigil",
        shift4 = "Blessing of Sacrifice",
        ctrl2 = "Lay on Hands",
        alt1 = "Cleanse",
        alt2 = "Purify",
    },
    DRUID = {
        click1 = "Regrowth",
        click2 = "Healing Touch",
        click3 = "Rejuvenation",
        click4 = "Wild Growth",
        click5 = "Swiftmend",
        alt1 = "Remove Curse",
        alt2 = "Abolish Poison",
    },
    PRIEST = {
        click1 = "Flash Heal",
        click2 = "Heal",
        click3 = "Renew",
        click4 = "Power Word: Shield",
        click5 = "Prayer of Mending",
        shift1 = "Penance",
        shift2 = "Prayer of Healing",
        alt1 = "Dispel Magic",
        alt2 = "Cure Disease",
    },
    SHAMAN = {
        click1 = "Lesser Healing Wave",
        click2 = "Chain Heal",
        click3 = "Riptide",
        click4 = "Healing Wave",
        alt1 = "Cure Disease",
        alt2 = "Cure Poison",
    }
}

local function GetClassDefaults()
local _, classFilename = UnitClass("player")
local merged = {}

for k, v in pairs(baseDefaults) do
    merged[k] = v
    end

    if classFilename and classDefaults[classFilename] then
        for k, v in pairs(classDefaults[classFilename]) do
            merged[k] = v
            end
            end

            return merged
            end

            local defaults = GetClassDefaults()
            local isUnlocked = false
            local baseOptions = { "", "target", "togglemenu", "openbuffmenu", "caststoredbuff" }
            local spellOptionsList = {}
            local knownClassSpells = {}

            -- ---------------------------------------------------------
            -- Helpers & Name Normalization
            -- ---------------------------------------------------------
            local function GetSetting(key)
            if SimpleHealSettings and SimpleHealSettings[key] ~= nil then
                return SimpleHealSettings[key]
                end
                return defaults[key] or ""
                end

                local function GetCleanUnitName(unit)
                    if not unit then return nil end
                    local rawName = UnitName(unit)
                    if not rawName then return nil end
                    if issecretvalue and issecretvalue(rawName) then return nil end
                    local ok, cleanName = pcall(string.match, rawName, "^([^%s%-]+)")
                    if ok and cleanName then
                        return cleanName
                    end
                    if issecretvalue and issecretvalue(rawName) then return nil end
                    return rawName
                end

                        -- ---------------------------------------------------------
                        -- Dynamic Spellbook Scanner
                        -- ---------------------------------------------------------
                        local function ScanPlayerSpellbook()
                        local spellMap = {}
                        local spellList = {}
                        knownClassSpells = {}

                        local bankPlayer = (Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player) or 0

                        if C_SpellBook and C_SpellBook.GetNumSpellBookSkillLines then
                            local numSkillLines = C_SpellBook.GetNumSpellBookSkillLines()
                            for skillLineIndex = 1, numSkillLines do
                                local skillLineInfo = C_SpellBook.GetSpellBookSkillLineInfo(skillLineIndex)
                                if skillLineInfo and skillLineInfo.numSpellBookItems then
                                    local offset = skillLineInfo.itemIndexOffset or 0
                                    for i = 1, skillLineInfo.numSpellBookItems do
                                        local slotIndex = offset + i
                                        local itemType = C_SpellBook.GetSpellBookItemType(slotIndex, bankPlayer)
                                        if itemType == (Enum and Enum.SpellBookItemType and Enum.SpellBookItemType.Spell or 0) or itemType == (Enum and Enum.SpellBookItemType and Enum.SpellBookItemType.FutureSpell or 1) then
                                            local name = C_SpellBook.GetSpellBookItemName(slotIndex, bankPlayer)
                                            local info = C_SpellBook.GetSpellBookItemInfo(slotIndex, bankPlayer)
                                            if name and info and not info.isPassive and not spellMap[name] then
                                                spellMap[name] = true
                                                table.insert(spellList, name)
                                                end
                                                end
                                                end
                                                end
                                                end
                                                elseif GetNumSpellTabs then
                                                    local numTabs = GetNumSpellTabs()
                                                    for t = 1, numTabs do
                                                        local _, _, offset, numSpells = GetSpellTabInfo(t)
                                                        for i = 1, numSpells do
                                                            local slotIndex = offset + i
                                                            local spellType, id = GetSpellBookItemInfo(slotIndex, "player")
                                                            if spellType == "SPELL" or spellType == "FUTURESPELL" then
                                                                local name = GetSpellBookItemName(slotIndex, "player")
                                                                local isPassive = IsPassiveSpell and IsPassiveSpell(slotIndex, "player")
                                                                if name and not isPassive and not spellMap[name] then
                                                                    spellMap[name] = true
                                                                    table.insert(spellList, name)
                                                                    end
                                                                    end
                                                                    end
                                                                    end
                                                                    end

                                                                    table.sort(spellList)
                                                                    knownClassSpells = spellList

                                                                    spellOptionsList = {}
                                                                    for _, opt in ipairs(baseOptions) do table.insert(spellOptionsList, opt) end
                                                                        for _, spell in ipairs(spellList) do table.insert(spellOptionsList, spell) end
                                                                            end

                                                                            -- ---------------------------------------------------------
-- ---------------------------------------------------------
-- Stored Player Buff Management & Dynamic Selector Window
-- ---------------------------------------------------------
SimpleHealUnitBuffs = SimpleHealUnitBuffs or {}
local monitoredUnitFrames = setmetatable({}, { __mode = "k" })
local UnitHasBuff
local GetBuffExpiration

local buffMenu = CreateFrame("Frame", "SimpleHealBuffMenu", UIParent, "BackdropTemplate")
buffMenu:SetSize(210, 230)
buffMenu:SetFrameStrata("DIALOG")
buffMenu:SetClampedToScreen(true)
buffMenu:EnableMouse(true)
if buffMenu.EnableKeyboard then buffMenu:EnableKeyboard(true) end
if buffMenu.SetPropagateKeyboardInput then buffMenu:SetPropagateKeyboardInput(true) end
buffMenu:Hide()

if type(UISpecialFrames) == "table" then
    local alreadyRegistered = false
    for _, name in ipairs(UISpecialFrames) do
        if name == "SimpleHealBuffMenu" then alreadyRegistered = true; break end
    end
    if not alreadyRegistered then
        table.insert(UISpecialFrames, "SimpleHealBuffMenu")
    end
end

buffMenu:SetScript("OnKeyDown", function(self, key)
    if key == "ESCAPE" then
        if self.SetPropagateKeyboardInput and not InCombatLockdown() then
            self:SetPropagateKeyboardInput(false)
        end
        self:Hide()
    else
        if self.SetPropagateKeyboardInput and not InCombatLockdown() then
            self:SetPropagateKeyboardInput(true)
        end
    end
end)

buffMenu:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 }
})

buffMenu.headerText = buffMenu:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
buffMenu.headerText:SetPoint("TOP", buffMenu, "TOP", 0, -8)
buffMenu.headerText:SetText("|cFFFFD100Left Click:|r Individual | |cFFFFD100Right Click:|r Class")

local buffMenuScroll = CreateFrame("ScrollFrame", "SimpleHealBuffMenuScroll", buffMenu, "UIPanelScrollFrameTemplate")
buffMenuScroll:SetPoint("TOPLEFT", buffMenu, "TOPLEFT", 8, -24)
buffMenuScroll:SetPoint("BOTTOMRIGHT", buffMenu, "BOTTOMRIGHT", -26, 8)

local buffMenuChild = CreateFrame("Frame", "SimpleHealBuffMenuChild", buffMenuScroll)
buffMenuChild:SetSize(172, 100)
buffMenuScroll:SetScrollChild(buffMenuChild)

local activeMenuUnit = nil
local activeMenuUnitName = nil
local buffMenuButtons = {}
buffMenu.buttons = buffMenuButtons
local soloFrame, petFrame

local function GetNameAssignedBuffList(cleanName)
    if not cleanName or not SimpleHealUnitBuffs then return {} end
    local raw = SimpleHealUnitBuffs[cleanName]
    if type(raw) == "string" then
        if raw == "" or raw == "<Clear / None>" then return {} end
        return { raw }
    elseif type(raw) == "table" then
        local res = {}
        for _, sp in ipairs(raw) do
            if type(sp) == "string" and sp ~= "" and sp ~= "<Clear / None>" then
                table.insert(res, sp)
            end
        end
        return res
    end
    return {}
end

local function GetUnitAssignedBuffList(unit, fallbackCleanName)
    local cleanName = GetCleanUnitName(unit) or fallbackCleanName
    local list = GetNameAssignedBuffList(cleanName)
    if #list == 0 and unit and UnitIsUnit(unit, "player") then
        list = GetNameAssignedBuffList("player")
    end
    return list
end

local function IsBuffAssignedToName(cleanName, spellName)
    if not cleanName or not spellName then return false end
    local list = GetNameAssignedBuffList(cleanName)
    for _, sp in ipairs(list) do
        if sp == spellName then return true end
    end
    return false
end

local function SetBuffAssignedForName(cleanName, spellName, enabled)
    if not cleanName or not spellName then return end
    local list = GetNameAssignedBuffList(cleanName)
    local newList = {}
    local found = false
    for _, sp in ipairs(list) do
        if sp == spellName then
            found = true
            if enabled then
                table.insert(newList, sp)
            end
        else
            table.insert(newList, sp)
        end
    end
    if enabled and not found then
        table.insert(newList, spellName)
    end
    if #newList == 0 then
        SimpleHealUnitBuffs[cleanName] = nil
    else
        SimpleHealUnitBuffs[cleanName] = newList
    end
end

local function GetSafeUnitClass(unit)
    if not unit or not UnitExists(unit) or not UnitClass then return nil, nil end
    local ok, classDisplayName, classFilename = pcall(UnitClass, unit)
    if not ok then return nil, nil end
    if issecretvalue and ((classFilename and issecretvalue(classFilename)) or (classDisplayName and issecretvalue(classDisplayName))) then
        return nil, nil
    end
    return classDisplayName, classFilename
end

local function GetGroupNamesOfClass(targetUnit, fallbackCleanName)
    local names = {}
    local seen = {}
    local function addName(n)
        if n and n ~= "" and not seen[n] then
            seen[n] = true
            table.insert(names, n)
        end
    end

    local classDisplayName, targetClass = GetSafeUnitClass(targetUnit)
    addName(fallbackCleanName)

    if targetClass then
        local function checkUnit(u)
            if u and UnitExists(u) then
                local _, uClass = GetSafeUnitClass(u)
                if uClass and uClass == targetClass then
                    addName(GetCleanUnitName(u))
                end
            end
        end

        checkUnit("player")
        for i = 1, 4 do checkUnit("party" .. i) end
        for i = 1, 40 do checkUnit("raid" .. i) end
        if monitoredUnitFrames then
            for uFrame, _ in pairs(monitoredUnitFrames) do
                local u = (uFrame.GetAttribute and uFrame:GetAttribute("unit")) or uFrame.unit or uFrame.displayedUnit
                checkUnit(u)
            end
        end
    end

    return names, classDisplayName or targetClass or "Class"
end

local function EvaluateUnitBuffs(unit, assignedList)
    if not assignedList or #assignedList == 0 then
        return true, nil, false, 0
    end
    if not unit or not UnitExists(unit) or not UnitHasBuff then
        return false, assignedList[1], false, #assignedList
    end
    local firstMissing = nil
    local missingCount = 0
    local anySecret = false
    for _, buffName in ipairs(assignedList) do
        local hasOne, sawSecret = UnitHasBuff(unit, buffName)
        if sawSecret then anySecret = true end
        if not hasOne then
            missingCount = missingCount + 1
            if not firstMissing then
                firstMissing = buffName
            end
        end
    end
    return (missingCount == 0), firstMissing, anySecret, missingCount
end

-- ---------------------------------------------------------
-- Multi-Buff Cycling (Ctrl+Alt+Shift cast stored buff)
-- Out of combat: the macro always casts the most-needed buff (missing buffs
--   first, then the buff with the lowest remaining duration). It is rebuilt on
--   every aura change, so repeated clicks walk through every assigned buff and
--   refresh the shortest one each time.
-- In combat: aura data is restricted and secure attributes are locked, so a
--   /castsequence (pre-sorted by the same priority before combat) advances to
--   the next buff after each successful cast and resets to the top of the list
--   after `buffCycleReset` seconds without a click.
-- ---------------------------------------------------------
local nextBuffCycleId = 0

local function GetBuffCycleResetSeconds()
    local v = tonumber(GetSetting("buffCycleReset"))
    if not v or v < 1 then v = 5 end
    if v > 60 then v = 60 end
    return math.floor(v)
end

local function GetBuffPriorityOrder(unit, assignedList)
    local entries = {}
    local canRead = unit and UnitExists(unit) and UnitHasBuff
    for idx, buffName in ipairs(assignedList) do
        local missing, expiration = false, math.huge
        if canRead then
            if not UnitHasBuff(unit, buffName) then
                missing = true
            elseif GetBuffExpiration then
                expiration = GetBuffExpiration(unit, buffName) or math.huge
            end
        end
        entries[#entries + 1] = { name = buffName, idx = idx, missing = missing, exp = expiration }
    end
    table.sort(entries, function(a, b)
        if a.missing ~= b.missing then return a.missing end
        if not a.missing and a.exp ~= b.exp then return a.exp < b.exp end
        return a.idx < b.idx
    end)
    local order = {}
    for i, e in ipairs(entries) do order[i] = e.name end
    return order
end

local function GetStoredBuffMacroForUnitFrame(uFrame)
    local unit = (uFrame and uFrame.GetAttribute and uFrame:GetAttribute("unit")) or (uFrame and (uFrame.unit or uFrame.displayedUnit)) or "player"
    local assignedList = GetUnitAssignedBuffList(unit, uFrame and uFrame._lastCleanName)
    local fallbackDefault = knownClassSpells[1] or "Flash of Light"
    if #assignedList <= 1 then
        return "/use [@mouseover,help,nodead][@unit,help,nodead][@player] " .. (assignedList[1] or fallbackDefault)
    end

    local order = GetBuffPriorityOrder(unit, assignedList)

    -- Each frame gets a unique fractional reset value so its /castsequence keeps
    -- its own position (sequence state is keyed by the macro text), meaning
    -- clicking a different player always starts at the top of *their* list.
    if uFrame and not uFrame._simpleHealCycleId then
        nextBuffCycleId = nextBuffCycleId + 1
        uFrame._simpleHealCycleId = nextBuffCycleId
    end
    local cycleId = ((uFrame and uFrame._simpleHealCycleId) or 0) % 1000
    local resetStr = string.format("%d.%03d", GetBuffCycleResetSeconds(), cycleId)

    return "/use [nocombat,@mouseover,help,nodead][nocombat,@unit,help,nodead][nocombat,@player] " .. order[1]
        .. "\n/castsequence [combat,@mouseover,help,nodead][combat,@unit,help,nodead][combat,@player] reset="
        .. resetStr .. " " .. table.concat(order, ", ")
end

local function UpdateFrameStoredBuffMacro(uFrame)
    if not uFrame or InCombatLockdown() then return end
    local macroText = GetStoredBuffMacroForUnitFrame(uFrame)
    if uFrame._storedBuffMacroText == macroText then return end
    uFrame._storedBuffMacroText = macroText

    if GetSetting("ctrlaltshift1") == "caststoredbuff" then
        uFrame:SetAttribute("ctrl-alt-shift-type1", "macro")
        uFrame:SetAttribute("ctrl-alt-shift-macrotext1", macroText)
        uFrame:SetAttribute("alt-ctrl-shift-type1", "macro")
        uFrame:SetAttribute("alt-ctrl-shift-macrotext1", macroText)
    end
    if GetSetting("ctrlaltshift2") == "caststoredbuff" then
        uFrame:SetAttribute("ctrl-alt-shift-type2", "macro")
        uFrame:SetAttribute("ctrl-alt-shift-macrotext2", macroText)
        uFrame:SetAttribute("alt-ctrl-shift-type2", "macro")
        uFrame:SetAttribute("alt-ctrl-shift-macrotext2", macroText)
    end
end

local RefreshBuffSelectorButtons

local function SyncStoredBuffState()
    if not InCombatLockdown() then
        if frame.ApplyBindings then
            frame:ApplyBindings()
        else
            if ClickCastFrames then
                for uFrame, _ in pairs(ClickCastFrames) do UpdateFrameStoredBuffMacro(uFrame) end
            end
            for i = 1, 40 do
                UpdateFrameStoredBuffMacro(_G["CompactRaidFrame" .. i])
                UpdateFrameStoredBuffMacro(_G["CompactRaidPet" .. i])
            end
            for i = 1, 5 do
                UpdateFrameStoredBuffMacro(_G["CompactPartyFrameMember" .. i])
                UpdateFrameStoredBuffMacro(_G["CompactPartyFrameGroup1Member" .. i])
                UpdateFrameStoredBuffMacro(_G["PartyMemberFrame" .. i])
            end
            if soloFrame then UpdateFrameStoredBuffMacro(soloFrame) end
            if petFrame then UpdateFrameStoredBuffMacro(petFrame) end
        end
    end
    if monitoredUnitFrames then
        for uFrame, _ in pairs(monitoredUnitFrames) do
            uFrame._lastKnownHasBuff = nil
        end
    end
    if UpdateAllBuffAlerts then UpdateAllBuffAlerts() end
    if buffMenu:IsShown() and RefreshBuffSelectorButtons then
        RefreshBuffSelectorButtons()
    end
end

local function SelectBuffForUnit(spellName, mouseButton)
    if not activeMenuUnitName then return end

    local isRightClick = (mouseButton == "RightButton")

    if spellName == "<Clear / None>" or spellName == "" then
        if isRightClick then
            local names, classLabel = GetGroupNamesOfClass(activeMenuUnit, activeMenuUnitName)
            for _, n in ipairs(names) do
                SimpleHealUnitBuffs[n] = nil
            end
            print("|cFF00FF00[SimpleHeal]|r Cleared all buff assignments for class |cFFFFD100[" .. classLabel .. "]|r")
        else
            SimpleHealUnitBuffs[activeMenuUnitName] = nil
            print("|cFF00FF00[SimpleHeal]|r Cleared all buff assignments for |cFFFFD100[" .. activeMenuUnitName .. "]|r")
        end
    else
        local currentlyEnabled = IsBuffAssignedToName(activeMenuUnitName, spellName)
        local nextState = not currentlyEnabled
        local stateText = nextState and "|cFF00FF00ON|r" or "|cFFFF5555OFF|r"

        if isRightClick then
            local names, classLabel = GetGroupNamesOfClass(activeMenuUnit, activeMenuUnitName)
            for _, n in ipairs(names) do
                SetBuffAssignedForName(n, spellName, nextState)
            end
            print("|cFF00FF00[SimpleHeal]|r Class |cFFFFD100[" .. classLabel .. "]|r -> |cFF00FFFF" .. spellName .. "|r: " .. stateText)
        else
            SetBuffAssignedForName(activeMenuUnitName, spellName, nextState)
            print("|cFF00FF00[SimpleHeal]|r |cFFFFD100[" .. activeMenuUnitName .. "]|r -> |cFF00FFFF" .. spellName .. "|r: " .. stateText)
        end
    end

    SyncStoredBuffState()
end

RefreshBuffSelectorButtons = function()
    for _, btn in ipairs(buffMenuButtons) do btn:Hide() end

    local classSpells = (#knownClassSpells > 0) and knownClassSpells or { "Blessing of Might", "Blessing of Wisdom", "Blessing of Kings", "Blessing of Protection" }
    local list = { "<Clear / None>" }
    for _, sp in ipairs(classSpells) do table.insert(list, sp) end
    local buttonHeight = 22
    buffMenuChild:SetHeight(#list * buttonHeight + 10)

    for i, spell in ipairs(list) do
        local btn = buffMenuButtons[i]
        if not btn then
            btn = CreateFrame("Button", nil, buffMenuChild, "UIPanelButtonTemplate")
            btn:SetSize(166, 20)
            if btn.RegisterForClicks then
                btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
            end
            table.insert(buffMenuButtons, btn)
        end
        btn:SetPoint("TOPLEFT", buffMenuChild, "TOPLEFT", 2, -((i - 1) * buttonHeight))
        btn.spellName = spell

        if spell == "<Clear / None>" then
            btn.isToggled = false
            btn:SetText("|cFFFF8888<Clear All>|r")
        else
            local enabled = activeMenuUnitName and IsBuffAssignedToName(activeMenuUnitName, spell) or false
            btn.isToggled = enabled
            if enabled then
                btn:SetText("|cFF00FF00[x] " .. spell .. "|r")
            else
                btn:SetText("|cFF888888[ ]|r " .. spell)
            end
        end

        btn:SetScript("OnClick", function(_, mouseButton)
            SelectBuffForUnit(spell, mouseButton or "LeftButton")
        end)
        btn:Show()
    end
end

function SimpleHeal_OpenBuffSelector(unitFrame)
    if InCombatLockdown() then
        print("|cFFFF0000[SimpleHeal]|r Cannot change target buff mappings during combat!")
        return
    end
    local unit = (unitFrame and unitFrame.GetAttribute and unitFrame:GetAttribute("unit")) or (unitFrame and (unitFrame.unit or unitFrame.displayedUnit)) or "player"
    activeMenuUnit = unit
    activeMenuUnitName = GetCleanUnitName(unit)

    if not activeMenuUnitName then return end

    RefreshBuffSelectorButtons()
    local x, y = GetCursorPosition()
    local scale = UIParent:GetEffectiveScale()
    buffMenu:ClearAllPoints()
    buffMenu:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", x / scale, y / scale)
    buffMenu:Show()
end

-- ---------------------------------------------------------
-- Missing Buff Alert System (Outline & ~ Name ~ Indicator)
-- ---------------------------------------------------------

local function SafeCompare(a, b)
    return a == b
end

local spellIDCache = {}
local function GetCachedSpellID(spellName)
    if not spellName then return nil end
    local cached = spellIDCache[spellName]
    if cached ~= nil then return cached or nil end

    local id
    if C_Spell and C_Spell.GetSpellInfo then
        local ok, info = pcall(C_Spell.GetSpellInfo, spellName)
        if ok and info and info.spellID then id = info.spellID end
    elseif GetSpellInfo then
        local ok, _, _, _, _, _, _, spellID = pcall(GetSpellInfo, spellName)
        if ok and spellID then id = spellID end
    end
    spellIDCache[spellName] = id or false
    return id
end

local buffEquivalents = {
    ["Blessing of Might"] = { "Blessing of Might", "Greater Blessing of Might" },
    ["Greater Blessing of Might"] = { "Blessing of Might", "Greater Blessing of Might" },
    ["Blessing of Wisdom"] = { "Blessing of Wisdom", "Greater Blessing of Wisdom" },
    ["Greater Blessing of Wisdom"] = { "Blessing of Wisdom", "Greater Blessing of Wisdom" },
    ["Blessing of Kings"] = { "Blessing of Kings", "Greater Blessing of Kings" },
    ["Greater Blessing of Kings"] = { "Blessing of Kings", "Greater Blessing of Kings" },
    ["Blessing of Sanctuary"] = { "Blessing of Sanctuary", "Greater Blessing of Sanctuary" },
    ["Greater Blessing of Sanctuary"] = { "Blessing of Sanctuary", "Greater Blessing of Sanctuary" },
    ["Blessing of Light"] = { "Blessing of Light", "Greater Blessing of Light" },
    ["Greater Blessing of Light"] = { "Blessing of Light", "Greater Blessing of Light" },
    ["Blessing of Salvation"] = { "Blessing of Salvation", "Greater Blessing of Salvation" },
    ["Greater Blessing of Salvation"] = { "Blessing of Salvation", "Greater Blessing of Salvation" },
    ["Power Word: Fortitude"] = { "Power Word: Fortitude", "Prayer of Fortitude" },
    ["Prayer of Fortitude"] = { "Power Word: Fortitude", "Prayer of Fortitude" },
    ["Shadow Protection"] = { "Shadow Protection", "Prayer of Shadow Protection" },
    ["Prayer of Shadow Protection"] = { "Shadow Protection", "Prayer of Shadow Protection" },
    ["Divine Spirit"] = { "Divine Spirit", "Prayer of Spirit" },
    ["Prayer of Spirit"] = { "Divine Spirit", "Prayer of Spirit" },
    ["Mark of the Wild"] = { "Mark of the Wild", "Gift of the Wild" },
    ["Gift of the Wild"] = { "Mark of the Wild", "Gift of the Wild" },
    ["Arcane Intellect"] = { "Arcane Intellect", "Arcane Brilliance" },
    ["Arcane Brilliance"] = { "Arcane Intellect", "Arcane Brilliance" },
}

local function CheckSingleBuff(unit, nameToCheck)
    if not unit or not nameToCheck then return false, false end

    local sawSecret = false

    -- 1. Look up target spell ID from cache (zero allocations)
    local targetSpellID = GetCachedSpellID(nameToCheck)

    -- 2. Direct player lookup by spell ID (O(1), immune to secret aura iteration issues)
    if (unit == "player" or UnitIsUnit(unit, "player")) and targetSpellID and C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID then
        local ok, aura = pcall(C_UnitAuras.GetPlayerAuraBySpellID, targetSpellID)
        if ok and aura then return true, false end
        if not ok then sawSecret = true end
    end

    -- 3. Direct lookup by spell name
    if C_UnitAuras and C_UnitAuras.GetAuraDataBySpellName then
        local ok, aura = pcall(C_UnitAuras.GetAuraDataBySpellName, unit, nameToCheck, "HELPFUL")
        if ok and aura then return true, false end
        local ok2, aura2 = pcall(C_UnitAuras.GetAuraDataBySpellName, unit, nameToCheck)
        if ok2 and aura2 then return true, false end
    end

    -- 4. AuraUtil.FindAuraByName
    if AuraUtil and AuraUtil.FindAuraByName then
        local ok, found = pcall(AuraUtil.FindAuraByName, nameToCheck, unit, "HELPFUL")
        if ok and found then return true, false end
        local ok2, found2 = pcall(AuraUtil.FindAuraByName, nameToCheck, unit)
        if ok2 and found2 then return true, false end
    end

    -- Helper to safely compare aura name and ID without crashing on secret values
    local function AuraMatches(aName, aID)
        local isNameSecret = issecretvalue and aName ~= nil and issecretvalue(aName)
        local isIDSecret = issecretvalue and aID ~= nil and issecretvalue(aID)
        if isNameSecret or isIDSecret then
            sawSecret = true
        end
        if aName and not isNameSecret then
            local ok, m = pcall(SafeCompare, aName, nameToCheck)
            if ok and m then return true end
            if not ok then sawSecret = true end
        end
        if aID and targetSpellID and not isIDSecret then
            local ok, m = pcall(SafeCompare, aID, targetSpellID)
            if ok and m then return true end
            if not ok then sawSecret = true end
        end
        return false
    end

    -- 5. C_UnitAuras.GetBuffDataByIndex (without "HELPFUL" filter!)
    -- CRITICAL: When an index encounters a secret aura, do NOT break! Skip it and keep scanning!
    if C_UnitAuras and C_UnitAuras.GetBuffDataByIndex then
        local emptyCount = 0
        for i = 1, 40 do
            local ok, aura = pcall(C_UnitAuras.GetBuffDataByIndex, unit, i)
            if ok then
                if aura then
                    emptyCount = 0
                    if AuraMatches(aura.name, aura.spellId) then return true, false end
                else
                    emptyCount = emptyCount + 1
                    if emptyCount >= 3 then break end
                end
            else
                -- Secret aura encountered: record and continue checking other indices
                sawSecret = true
                emptyCount = 0
            end
        end
    end

    -- 6. C_UnitAuras.GetAuraDataByIndex (with "HELPFUL" filter)
    if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
        local emptyCount = 0
        for i = 1, 40 do
            local ok, aura = pcall(C_UnitAuras.GetAuraDataByIndex, unit, i, "HELPFUL")
            if ok then
                if aura then
                    emptyCount = 0
                    if AuraMatches(aura.name, aura.spellId) then return true, false end
                else
                    emptyCount = emptyCount + 1
                    if emptyCount >= 3 then break end
                end
            else
                sawSecret = true
                emptyCount = 0
            end
        end
    end

    -- 7. Legacy UnitAura
    if UnitAura then
        local emptyCount = 0
        for i = 1, 40 do
            local ok, aName, _, _, _, _, _, _, _, _, aID = pcall(UnitAura, unit, i, "HELPFUL")
            if ok then
                if aName then
                    emptyCount = 0
                    if AuraMatches(aName, aID) then return true, false end
                else
                    emptyCount = emptyCount + 1
                    if emptyCount >= 3 then break end
                end
            else
                sawSecret = true
                emptyCount = 0
            end
        end
    end

    -- 8. Legacy UnitBuff
    if UnitBuff then
        local emptyCount = 0
        for i = 1, 40 do
            local ok, aName = pcall(UnitBuff, unit, i)
            if ok then
                if aName then
                    emptyCount = 0
                    if AuraMatches(aName, nil) then return true, false end
                else
                    emptyCount = emptyCount + 1
                    if emptyCount >= 3 then break end
                end
            else
                sawSecret = true
                emptyCount = 0
            end
        end
    end

    return false, sawSecret
end

UnitHasBuff = function(unit, spellName)
    if not unit or not spellName or not UnitExists(unit) then return false, false end
    local equivalents = buffEquivalents[spellName] or { spellName }
    local anySecret = false
    for _, nameToCheck in ipairs(equivalents) do
        local found, sawSecret = CheckSingleBuff(unit, nameToCheck)
        if found then
            return true, false
        end
        if sawSecret then
            anySecret = true
        end
    end
    return false, anySecret
end

-- Converts aura duration / expiration into a sortable expiration time.
-- Returns math.huge for auras without a duration, or nil when unreadable (secret).
local function ReadAuraExpiration(duration, expirationTime)
    if issecretvalue and ((duration ~= nil and issecretvalue(duration)) or (expirationTime ~= nil and issecretvalue(expirationTime))) then
        return nil
    end
    if type(expirationTime) ~= "number" or expirationTime <= 0 then return math.huge end
    if type(duration) == "number" and duration <= 0 then return math.huge end
    return expirationTime
end

local function GetSingleBuffExpiration(unit, nameToCheck)
    if (unit == "player" or UnitIsUnit(unit, "player")) and C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID then
        local spellID = GetCachedSpellID(nameToCheck)
        if spellID then
            local ok, aura = pcall(C_UnitAuras.GetPlayerAuraBySpellID, spellID)
            if ok and aura then
                local exp = ReadAuraExpiration(aura.duration, aura.expirationTime)
                if exp then return exp end
            end
        end
    end

    if C_UnitAuras and C_UnitAuras.GetAuraDataBySpellName then
        -- Prefer our own cast of the buff, then anyone's
        local ok, aura = pcall(C_UnitAuras.GetAuraDataBySpellName, unit, nameToCheck, "HELPFUL|PLAYER")
        if not (ok and aura) then
            ok, aura = pcall(C_UnitAuras.GetAuraDataBySpellName, unit, nameToCheck, "HELPFUL")
        end
        if ok and aura then
            local exp = ReadAuraExpiration(aura.duration, aura.expirationTime)
            if exp then return exp end
        end
    end

    if AuraUtil and AuraUtil.FindAuraByName then
        local ok, name, _, _, _, duration, expirationTime = pcall(AuraUtil.FindAuraByName, nameToCheck, unit, "HELPFUL")
        if ok and name then
            local exp = ReadAuraExpiration(duration, expirationTime)
            if exp then return exp end
        end
    end

    if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
        for i = 1, 40 do
            local ok, aura = pcall(C_UnitAuras.GetAuraDataByIndex, unit, i, "HELPFUL")
            if ok and not aura then break end
            if ok and aura and aura.name and not (issecretvalue and issecretvalue(aura.name)) then
                local okc, match = pcall(SafeCompare, aura.name, nameToCheck)
                if okc and match then
                    local exp = ReadAuraExpiration(aura.duration, aura.expirationTime)
                    if exp then return exp end
                end
            end
        end
    elseif UnitAura then
        for i = 1, 40 do
            local ok, aName, _, _, _, duration, expirationTime = pcall(UnitAura, unit, i, "HELPFUL")
            if ok and not aName then break end
            if ok and aName and not (issecretvalue and issecretvalue(aName)) then
                local okc, match = pcall(SafeCompare, aName, nameToCheck)
                if okc and match then
                    local exp = ReadAuraExpiration(duration, expirationTime)
                    if exp then return exp end
                end
            end
        end
    end

    return nil
end

GetBuffExpiration = function(unit, spellName)
    if not unit or not spellName or not UnitExists(unit) then return nil end
    local best
    for _, nameToCheck in ipairs(buffEquivalents[spellName] or { spellName }) do
        local exp = GetSingleBuffExpiration(unit, nameToCheck)
        if exp and (not best or exp > best) then best = exp end
    end
    return best
end

local function GetOrCreateBuffAlertOverlay(unitFrame)
    if unitFrame.simpleHealBuffOverlay then
        return unitFrame.simpleHealBuffOverlay
    end

    local overlay = CreateFrame("Frame", nil, unitFrame, "BackdropTemplate")
    overlay:SetAllPoints(unitFrame)
    overlay:SetFrameLevel((unitFrame:GetFrameLevel() or 1) + 8)
    overlay:EnableMouse(false)

    overlay:SetBackdrop({
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 2,
        insets = { left = 0, right = 0, top = 0, bottom = 0 }
    })
    overlay:SetBackdropBorderColor(1.0, 0.82, 0.0, 0.95)

    overlay.leftTag = overlay:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    overlay.leftTag:SetText("~")
    overlay.leftTag:SetTextColor(1.0, 0.85, 0.1, 1.0)
    overlay.leftTag:SetShadowColor(0, 0, 0, 1)
    overlay.leftTag:SetShadowOffset(1, -1)

    overlay.rightTag = overlay:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    overlay.rightTag:SetText("~")
    overlay.rightTag:SetTextColor(1.0, 0.85, 0.1, 1.0)
    overlay.rightTag:SetShadowColor(0, 0, 0, 1)
    overlay.rightTag:SetShadowOffset(1, -1)

    overlay:Hide()
    unitFrame.simpleHealBuffOverlay = overlay
    return overlay
end

local function UpdateFrameBuffAlert(unitFrame)
    if not unitFrame then return end

    local overlay = unitFrame.simpleHealBuffOverlay
    local s = SimpleHealSettings or defaults
    if s and s.buffAlertEnabled == false then
        if overlay then overlay:Hide() end
        return
    end

    if not unitFrame:IsShown() then
        if overlay then overlay:Hide() end
        return
    end

    local unit = (unitFrame.GetAttribute and unitFrame:GetAttribute("unit")) or unitFrame.unit or unitFrame.displayedUnit
    if not unit or not UnitExists(unit) or UnitIsDeadOrGhost(unit) or not UnitIsConnected(unit) then
        if overlay then overlay:Hide() end
        return
    end

    local cleanName = GetCleanUnitName(unit) or unitFrame._lastCleanName
    if not cleanName then
        if overlay then overlay:Hide() end
        return
    end
    unitFrame._lastCleanName = cleanName

    local assignedList = GetUnitAssignedBuffList(unit, cleanName)
    if #assignedList == 0 then
        unitFrame._lastKnownHasBuff = nil
        unitFrame._preCombatMissingCount = nil
        unitFrame._lastFirstMissingBuff = nil
        if overlay then
            if overlay.leftTag then overlay.leftTag:Hide() end
            if overlay.rightTag then overlay.rightTag:Hide() end
            overlay:Hide()
        end
        return
    end

    local hasBuff, firstMissingBuff, sawSecret, missingCount = EvaluateUnitBuffs(unit, assignedList)
    if not hasBuff and InCombatLockdown() then
        -- WoW 12.0 restricts reading unit auras during combat (secret values / taint guard).
        -- Preserve the unit's pre-combat buff state (or true if unknown) so the alert
        -- never falsely triggers during combat when the unit is already buffed.
        if sawSecret or unitFrame._lastKnownHasBuff ~= false then
            if unitFrame._lastKnownHasBuff == false then
                hasBuff = false
            else
                hasBuff = true
            end
        end
    else
        unitFrame._lastKnownHasBuff = hasBuff
        unitFrame._preCombatMissingCount = missingCount
    end

    if not hasBuff then
        local ol = GetOrCreateBuffAlertOverlay(unitFrame)

        if s and s.buffAlertOutline == false then
            ol:SetBackdropBorderColor(0, 0, 0, 0)
        else
            ol:SetBackdropBorderColor(1.0, 0.82, 0.0, 0.95)
        end

        if s and s.buffAlertTags == false then
            ol.leftTag:Hide()
            ol.rightTag:Hide()
        else
            local nameWidget = unitFrame.name or unitFrame.nameText
            if not nameWidget and unitFrame.GetName and unitFrame:GetName() then
                nameWidget = _G[unitFrame:GetName() .. "Name"]
            end

            ol.leftTag:ClearAllPoints()
            ol.rightTag:ClearAllPoints()
            local nameText = nameWidget and nameWidget.GetText and nameWidget:GetText()
            local hasNameText = false
            if nameText then
                if issecretvalue and issecretvalue(nameText) then
                    hasNameText = true
                else
                    local ok, isEmpty = pcall(SafeCompare, nameText, "")
                    hasNameText = ok and not isEmpty
                end
            end
            if nameWidget and nameWidget:IsShown() and hasNameText then
                ol.leftTag:SetPoint("RIGHT", nameWidget, "LEFT", -2, 0)
                ol.rightTag:SetPoint("LEFT", nameWidget, "RIGHT", 2, 0)
            else
                ol.leftTag:SetPoint("TOPLEFT", ol, "TOPLEFT", 3, -3)
                ol.rightTag:SetPoint("TOPRIGHT", ol, "TOPRIGHT", -3, -3)
            end
            ol.leftTag:Show()
            ol.rightTag:Show()
        end

        ol:Show()
    else
        if overlay then
            if overlay.leftTag then overlay.leftTag:Hide() end
            if overlay.rightTag then overlay.rightTag:Hide() end
            overlay:Hide()
        end
    end
end

-- Re-sorts the cycling buff macro (missing / lowest remaining duration first) for
-- every frame with 2+ assigned buffs. Runs regardless of the alert display settings.
local function RefreshCyclingBuffMacros()
    if InCombatLockdown() or not SimpleHealUnitBuffs or not next(SimpleHealUnitBuffs) then return end
    local function refresh(uFrame)
        if not uFrame then return end
        local unit = (uFrame.GetAttribute and uFrame:GetAttribute("unit")) or uFrame.unit or uFrame.displayedUnit
        if not unit or not UnitExists(unit) then return end
        if #GetUnitAssignedBuffList(unit, uFrame._lastCleanName) > 1 then
            UpdateFrameStoredBuffMacro(uFrame)
        end
    end
    for uFrame, _ in pairs(monitoredUnitFrames) do refresh(uFrame) end
    if soloFrame and not monitoredUnitFrames[soloFrame] then refresh(soloFrame) end
    if petFrame and not monitoredUnitFrames[petFrame] then refresh(petFrame) end
end

function UpdateAllBuffAlerts()
    RefreshCyclingBuffMacros()
    local s = SimpleHealSettings or defaults
    if (s and s.buffAlertEnabled == false) or not SimpleHealUnitBuffs or not next(SimpleHealUnitBuffs) then
        for uFrame, _ in pairs(monitoredUnitFrames) do
            if uFrame.simpleHealBuffOverlay and uFrame.simpleHealBuffOverlay:IsShown() then
                uFrame.simpleHealBuffOverlay:Hide()
            end
        end
        return
    end

    for uFrame, _ in pairs(monitoredUnitFrames) do
        UpdateFrameBuffAlert(uFrame)
    end
    if soloFrame and not monitoredUnitFrames[soloFrame] then UpdateFrameBuffAlert(soloFrame) end
    if petFrame and not monitoredUnitFrames[petFrame] then UpdateFrameBuffAlert(petFrame) end
end

local auraUpdatePending = false
local function RequestBuffAlertsUpdate()
    if auraUpdatePending then return end
    auraUpdatePending = true
    if C_Timer and C_Timer.After then
        C_Timer.After(0.05, function()
            auraUpdatePending = false
            UpdateAllBuffAlerts()
        end)
    else
        auraUpdatePending = false
        UpdateAllBuffAlerts()
    end
end


                                                                                                                                    local function SetupToggleDragging(f)
                                                                                                                                    f:SetMovable(true)
                                                                                                                                    f:EnableMouse(true)
                                                                                                                                    f:RegisterForDrag("LeftButton")
                                                                                                                                    f:SetScript("OnDragStart", function(self)
                                                                                                                                    if isUnlocked and not InCombatLockdown() then self:StartMoving() end
                                                                                                                                        end)
                                                                                                                                    f:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
                                                                                                                                    end

-- ---------------------------------------------------------
-- Context Menu Driver (Modern Client API Fix)
-- ---------------------------------------------------------
local function OpenUnitContextMenu(unitFrame)
    if not unitFrame then return end

    local unit = (unitFrame.GetAttribute and unitFrame:GetAttribute("unit")) or unitFrame.unit or unitFrame.displayedUnit or "player"
    local name, server = UnitName(unit)
    name = name or (type(unit) == "string" and unit) or "player"

    local contextData = {
        unit = unit,
        name = name,
        server = server,
        fromPlayerFrame = UnitIsUnit(unit, "player"),
    }

    local isPlainUnit = type(unit) == "string" and not (issecretvalue and issecretvalue(unit))
    local which = "TARGET"
    if UnitIsUnit(unit, "player") then
        which = "SELF"
    elseif UnitIsUnit(unit, "pet") then
        which = "PET"
    elseif UnitIsUnit(unit, "vehicle") then
        which = "VEHICLE"
    elseif UnitInRaid(unit) or (isPlainUnit and string.find(unit, "^raid")) then
        which = (UnitPopupMenus and not UnitPopupMenus["RAID_PLAYER"] and UnitPopupMenus["RAID"]) and "RAID" or "RAID_PLAYER"
    elseif UnitInParty(unit) or (isPlainUnit and string.find(unit, "^party")) then
        which = "PARTY"
    elseif UnitIsPlayer(unit) then
        which = "PLAYER"
    else
        which = "TARGET"
    end

    if UnitPopup_OpenMenu then
        UnitPopup_OpenMenu(which, contextData, unitFrame)
    elseif UnitPopup_ShowMenu and unitFrame.dropDown then
        UnitPopup_ShowMenu(unitFrame.dropDown, which, unit, name)
    elseif ToggleDropDownMenu and unitFrame.dropDown then
        ToggleDropDownMenu(1, nil, unitFrame.dropDown, "cursor")
    elseif OpenContextMenu then
        OpenContextMenu(unitFrame, unit)
    end
end

                                                                                                                                                                -- ---------------------------------------------------------
                                                                                                                                                                -- Config UI (/shf ui)
                                                                                                                                                                -- ---------------------------------------------------------
                                                                                                                                                                local configUI = CreateFrame("Frame", "SimpleHealConfigFrame", UIParent, "BasicFrameTemplateWithInset")
                                                                                                                                                                configUI:SetSize(420, 520)
                                                                                                                                                                configUI:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
                                                                                                                                                                configUI:SetFrameStrata("HIGH")
                                                                                                                                                                configUI:SetMovable(true)
                                                                                                                                                                configUI:EnableMouse(true)
                                                                                                                                                                configUI:RegisterForDrag("LeftButton")
                                                                                                                                                                configUI:SetScript("OnDragStart", configUI.StartMoving)
                                                                                                                                                                configUI:SetScript("OnDragStop", configUI.StopMovingOrSizing)
                                                                                                                                                                configUI:Hide()

                                                                                                                                                                configUI.title = configUI:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
                                                                                                                                                                configUI.title:SetPoint("CENTER", configUI.TitleBg, "CENTER", 0, 0)
                                                                                                                                                                configUI.title:SetText("SimpleHeal - Binding Configuration")

                                                                                                                                                                local scrollFrame = CreateFrame("ScrollFrame", "SimpleHealConfigScrollFrame", configUI, "UIPanelScrollFrameTemplate")
                                                                                                                                                                scrollFrame:SetPoint("TOPLEFT", configUI.InsetBg, "TOPLEFT", 10, -10)
                                                                                                                                                                scrollFrame:SetPoint("BOTTOMRIGHT", configUI.InsetBg, "BOTTOMRIGHT", -30, 10)

                                                                                                                                                                local scrollChild = CreateFrame("Frame", "SimpleHealConfigScrollChild", scrollFrame)
                                                                                                                                                                scrollChild:SetSize(360, 1100)
                                                                                                                                                                scrollFrame:SetScrollChild(scrollChild)

                                                                                                                                                                local activePickerDropdown = nil
                                                                                                                                                                local pickerFrame = CreateFrame("Frame", "SimpleHealPickerFrame", UIParent, "BackdropTemplate")
                                                                                                                                                                pickerFrame:SetSize(180, 200)
                                                                                                                                                                pickerFrame:SetFrameStrata("TOOLTIP")
                                                                                                                                                                pickerFrame:SetClampedToScreen(true)
                                                                                                                                                                pickerFrame:Hide()

                                                                                                                                                                pickerFrame:SetBackdrop({
                                                                                                                                                                    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
                                                                                                                                                                    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
                                                                                                                                                                    tile = true, tileSize = 32, edgeSize = 16,
                                                                                                                                                                    insets = { left = 4, right = 4, top = 4, bottom = 4 }
                                                                                                                                                                })

                                                                                                                                                                local pickerScroll = CreateFrame("ScrollFrame", nil, pickerFrame, "UIPanelScrollFrameTemplate")
                                                                                                                                                                pickerScroll:SetPoint("TOPLEFT", pickerFrame, "TOPLEFT", 6, -6)
                                                                                                                                                                pickerScroll:SetPoint("BOTTOMRIGHT", pickerFrame, "BOTTOMRIGHT", -24, 6)

                                                                                                                                                                local pickerChild = CreateFrame("Frame", nil, pickerScroll)
                                                                                                                                                                pickerChild:SetSize(145, 100)
                                                                                                                                                                pickerScroll:SetScrollChild(pickerChild)

                                                                                                                                                                local pickerButtons = {}

                                                                                                                                                                local function OpenPickerForDropdown(dropdown, keyName)
                                                                                                                                                                activePickerDropdown = dropdown
                                                                                                                                                                for _, btn in ipairs(pickerButtons) do btn:Hide() end

                                                                                                                                                                    local itemHeight = 20
                                                                                                                                                                    pickerChild:SetHeight(#spellOptionsList * itemHeight + 10)

                                                                                                                                                                    for i, val in ipairs(spellOptionsList) do
                                                                                                                                                                        local btn = pickerButtons[i]
                                                                                                                                                                        if not btn then
                                                                                                                                                                            btn = CreateFrame("Button", nil, pickerChild, "UIPanelButtonTemplate")
                                                                                                                                                                            btn:SetSize(140, 18)
                                                                                                                                                                            table.insert(pickerButtons, btn)
                                                                                                                                                                            end
                                                                                                                                                                            btn:SetPoint("TOPLEFT", pickerChild, "TOPLEFT", 2, -((i - 1) * itemHeight))
                                                                                                                                                                            btn:SetText((val == "") and "<Unbound>" or val)
                                                                                                                                                                            btn:SetScript("OnClick", function()
                                                                                                                                                                            SimpleHealSettings = SimpleHealSettings or defaults
                                                                                                                                                                            SimpleHealSettings[keyName] = val
                                                                                                                                                                            dropdown.buttonText:SetText((val == "") and "<Unbound>" or val)
                                                                                                                                                                            pickerFrame:Hide()
                                                                                                                                                                            if frame.ApplyBindings then frame:ApplyBindings() end
                                                                                                                                                                                end)
                                                                                                                                                                            btn:Show()
                                                                                                                                                                            end

                                                                                                                                                                            local x, y = GetCursorPosition()
                                                                                                                                                                            local scale = UIParent:GetEffectiveScale()
                                                                                                                                                                            pickerFrame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x / scale, y / scale)
                                                                                                                                                                            pickerFrame:Show()
                                                                                                                                                                            end

                                                                                                                                                                            local function CreateUIDropdown(parent, labelText, keyName, yOffset)
                                                                                                                                                                            local label = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                                                                                                                                                                            label:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, yOffset)
                                                                                                                                                                            label:SetText(labelText)

                                                                                                                                                                            local dropdown = CreateFrame("Button", "SimpleHealDropdown_" .. keyName, parent, "UIPanelButtonTemplate")
                                                                                                                                                                            dropdown:SetSize(180, 22)
                                                                                                                                                                            dropdown:SetPoint("TOPLEFT", parent, "TOPLEFT", 150, yOffset + 4)

                                                                                                                                                                            dropdown.buttonText = dropdown:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                                                                                                                                                                            dropdown.buttonText:SetPoint("CENTER", dropdown, "CENTER", 0, 0)

                                                                                                                                                                            local currentVal = GetSetting(keyName)
                                                                                                                                                                            dropdown.buttonText:SetText((currentVal == "") and "<Unbound>" or currentVal)

                                                                                                                                                                            dropdown:SetScript("OnClick", function() OpenPickerForDropdown(dropdown, keyName) end)
                                                                                                                                                                            dropdown.Refresh = function()
                                                                                                                                                                            local val = GetSetting(keyName)
                                                                                                                                                                            dropdown.buttonText:SetText((val == "") and "<Unbound>" or val)
                                                                                                                                                                            end

                                                                                                                                                                            return dropdown
                                                                                                                                                                            end

                                                                                                                                                                            local uiDropdowns = {}
                                                                                                                                                                            local bindingRows = {
                                                                                                                                                                                { label = "Left Click", key = "click1" },
                                                                                                                                                                                { label = "Right Click", key = "click2" },
                                                                                                                                                                                { label = "Middle Click", key = "click3" },
                                                                                                                                                                                { label = "Button 4", key = "click4" },
                                                                                                                                                                                { label = "Button 5", key = "click5" },
                                                                                                                                                                                { label = "Shift + Left", key = "shift1" },
                                                                                                                                                                                { label = "Shift + Right", key = "shift2" },
                                                                                                                                                                                { label = "Shift + Middle", key = "shift3" },
                                                                                                                                                                                { label = "Shift + Btn4", key = "shift4" },
                                                                                                                                                                                { label = "Shift + Btn5", key = "shift5" },
                                                                                                                                                                                { label = "Ctrl + Left", key = "ctrl1" },
                                                                                                                                                                                { label = "Ctrl + Right", key = "ctrl2" },
                                                                                                                                                                                { label = "Ctrl + Middle", key = "ctrl3" },
                                                                                                                                                                                { label = "Ctrl + Btn4", key = "ctrl4" },
                                                                                                                                                                                { label = "Ctrl + Btn5", key = "ctrl5" },
                                                                                                                                                                                { label = "Alt + Left", key = "alt1" },
                                                                                                                                                                                { label = "Alt + Right", key = "alt2" },
                                                                                                                                                                                { label = "Alt + Middle", key = "alt3" },
                                                                                                                                                                                { label = "Alt + Btn4", key = "alt4" },
                                                                                                                                                                                { label = "Alt + Btn5", key = "alt5" },
                                                                                                                                                                                { label = "Ctrl+Alt + Left", key = "ctrlalt1" },
                                                                                                                                                                                { label = "Ctrl+Alt + Right", key = "ctrlalt2" },
                                                                                                                                                                                { label = "Ctrl+Alt + Middle", key = "ctrlalt3" },
                                                                                                                                                                                { label = "Ctrl+Alt + Btn4", key = "ctrlalt4" },
                                                                                                                                                                                { label = "Ctrl+Alt + Btn5", key = "ctrlalt5" },
                                                                                                                                                                                { label = "Ctrl+Alt+Shift + Left", key = "ctrlaltshift1" },
                                                                                                                                                                                { label = "Ctrl+Alt+Shift + Right", key = "ctrlaltshift2" },
                                                                                                                                                                            }

                                                                                                                                                                            local yPos = -10
                                                                                                                                                                            for _, row in ipairs(bindingRows) do
                                                                                                                                                                                local dd = CreateUIDropdown(scrollChild, row.label, row.key, yPos)
                                                                                                                                                                                table.insert(uiDropdowns, dd)
                                                                                                                                                                                yPos = yPos - 38
                                                                                                                                                                                end

                                                                                                                                                                                function SimpleHeal_ToggleConfigUI()
                                                                                                                                                                                if configUI:IsShown() then
                                                                                                                                                                                    configUI:Hide()
                                                                                                                                                                                    pickerFrame:Hide()
                                                                                                                                                                                    else
                                                                                                                                                                                        ScanPlayerSpellbook()
                                                                                                                                                                                        for _, dd in ipairs(uiDropdowns) do if dd.Refresh then dd:Refresh() end end
                                                                                                                                                                                            configUI:Show()
                                                                                                                                                                                            end
                                                                                                                                                                                            end

                                                                                                                                                                                            -- ---------------------------------------------------------
                                                                                                                                                                                            -- Frame Creation
                                                                                                                                                                                            -- ---------------------------------------------------------
                                                                                                                                                                                            soloFrame = CreateFrame("Button", "SimpleHealSoloFrame", UIParent, "SecureUnitButtonTemplate")
                                                                                                                                                                                            soloFrame:SetSize(120, 38)
                                                                                                                                                                                            soloFrame:SetPoint("CENTER", UIParent, "CENTER", -300, 0)
                                                                                                                                                                                            soloFrame:SetAttribute("unit", "player")
                                                                                                                                                                                            SetupToggleDragging(soloFrame)

                                                                                                                                                                                            soloFrame.bg = soloFrame:CreateTexture(nil, "BACKGROUND")
                                                                                                                                                                                            soloFrame.bg:SetAllPoints()
                                                                                                                                                                                            soloFrame.bg:SetColorTexture(0.05, 0.05, 0.05, 0.85)

                                                                                                                                                                                            soloFrame.moveOverlay = soloFrame:CreateTexture(nil, "OVERLAY")
                                                                                                                                                                                            soloFrame.moveOverlay:SetAllPoints()
                                                                                                                                                                                            soloFrame.moveOverlay:SetColorTexture(0.0, 1.0, 0.0, 0.35)
                                                                                                                                                                                            soloFrame.moveOverlay:Hide()

                                                                                                                                                                                            soloFrame.moveText = soloFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
                                                                                                                                                                                            soloFrame.moveText:SetPoint("CENTER", soloFrame, "CENTER", 0, 0)
                                                                                                                                                                                            soloFrame.moveText:SetText("|cFF00FF00[DRAG ME]|r")
                                                                                                                                                                                            soloFrame.moveText:Hide()

                                                                                                                                                                                            soloFrame.healthBar = CreateFrame("StatusBar", nil, soloFrame)
                                                                                                                                                                                            soloFrame.healthBar:SetSize(116, 26)
                                                                                                                                                                                            soloFrame.healthBar:SetPoint("TOP", soloFrame, "TOP", 0, -2)
                                                                                                                                                                                            soloFrame.healthBar:SetStatusBarTexture("Interface\\RaidFrame\\Raid-Bar-Hp-Fill")
                                                                                                                                                                                            soloFrame.healthBar:SetStatusBarColor(0.1, 0.8, 0.2)

                                                                                                                                                                                            soloFrame.manaBar = CreateFrame("StatusBar", nil, soloFrame)
                                                                                                                                                                                            soloFrame.manaBar:SetSize(116, 5)
                                                                                                                                                                                            soloFrame.manaBar:SetPoint("TOP", soloFrame.healthBar, "BOTTOM", 0, -1)
                                                                                                                                                                                            soloFrame.manaBar:SetStatusBarTexture("Interface\\RaidFrame\\Raid-Bar-Resource-Fill")
                                                                                                                                                                                            soloFrame.manaBar:SetStatusBarColor(0.0, 0.4, 0.9)

                                                                                                                                                                                            soloFrame.nameText = soloFrame.healthBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                                                                                                                                                                                            soloFrame.nameText:SetPoint("TOP", soloFrame.healthBar, "TOP", 0, -2)
                                                                                                                                                                                            soloFrame.nameText:SetText(UnitName("player") or "Player")

                                                                                                                                                                                            soloFrame.healthLeftText = soloFrame.healthBar:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
                                                                                                                                                                                            soloFrame.healthLeftText:SetPoint("BOTTOMLEFT", soloFrame.healthBar, "BOTTOMLEFT", 4, 2)

                                                                                                                                                                                            soloFrame.healthRightText = soloFrame.healthBar:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
                                                                                                                                                                                            soloFrame.healthRightText:SetPoint("BOTTOMRIGHT", soloFrame.healthBar, "BOTTOMRIGHT", -4, 2)

                                                                                                                                                                                            soloFrame.manaLeftText = soloFrame.manaBar:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
                                                                                                                                                                                            soloFrame.manaLeftText:SetPoint("LEFT", soloFrame.manaBar, "LEFT", 4, 0)

                                                                                                                                                                                            soloFrame.manaRightText = soloFrame.manaBar:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
                                                                                                                                                                                            soloFrame.manaRightText:SetPoint("RIGHT", soloFrame.manaBar, "RIGHT", -4, 0)

                                                                                                                                                                                            soloFrame:Hide()

                                                                                                                                                                                            petFrame = CreateFrame("Button", "SimpleHealPetFrame", UIParent, "SecureUnitButtonTemplate")
                                                                                                                                                                                            petFrame:SetSize(120, 30)
                                                                                                                                                                                            petFrame:SetPoint("TOP", soloFrame, "BOTTOM", 0, -6)
                                                                                                                                                                                            petFrame:SetAttribute("unit", "pet")
                                                                                                                                                                                            SetupToggleDragging(petFrame)

                                                                                                                                                                                            petFrame.bg = petFrame:CreateTexture(nil, "BACKGROUND")
                                                                                                                                                                                            petFrame.bg:SetAllPoints()
                                                                                                                                                                                            petFrame.bg:SetColorTexture(0.05, 0.05, 0.05, 0.85)

                                                                                                                                                                                            petFrame.moveOverlay = petFrame:CreateTexture(nil, "OVERLAY")
                                                                                                                                                                                            petFrame.moveOverlay:SetAllPoints()
                                                                                                                                                                                            petFrame.moveOverlay:SetColorTexture(0.0, 1.0, 0.0, 0.35)
                                                                                                                                                                                            petFrame.moveOverlay:Hide()

                                                                                                                                                                                            petFrame.nameText = petFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                                                                                                                                                                                            petFrame.nameText:SetPoint("TOP", petFrame, "TOP", 0, -2)
                                                                                                                                                                                            petFrame.nameText:SetText("Pet")

                                                                                                                                                                                            petFrame.healthBar = CreateFrame("StatusBar", nil, petFrame)
                                                                                                                                                                                            petFrame.healthBar:SetSize(116, 18)
                                                                                                                                                                                            petFrame.healthBar:SetPoint("TOP", petFrame, "TOP", 0, -10)
                                                                                                                                                                                            petFrame.healthBar:SetStatusBarTexture("Interface\\RaidFrame\\Raid-Bar-Hp-Fill")
                                                                                                                                                                                            petFrame.healthBar:SetStatusBarColor(0.2, 0.7, 0.9)

                                                                                                                                                                                            petFrame.healthLeftText = petFrame.healthBar:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
                                                                                                                                                                                            petFrame.healthLeftText:SetPoint("LEFT", petFrame.healthBar, "LEFT", 4, 0)

                                                                                                                                                                                            petFrame.healthRightText = petFrame.healthBar:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
                                                                                                                                                                                            petFrame.healthRightText:SetPoint("RIGHT", petFrame.healthBar, "RIGHT", -4, 0)

                                                                                                                                                                                            petFrame:Hide()

                                                                                                                                                                                            -- ---------------------------------------------------------
                                                                                                                                                                                            -- Stat Updates
                                                                                                                                                                                            -- ---------------------------------------------------------
                                                                                                                                                                                            local function UpdateBarTextFromWidget(bar, leftText, rightText)
                                                                                                                                                                                            if not bar or not leftText or not rightText then return end
                                                                                                                                                                                                local ok, pct, missing, rawCur = pcall(function()
                                                                                                                                                                                                local minV, maxV = bar:GetMinMaxValues()
                                                                                                                                                                                                local curV = bar:GetValue()
                                                                                                                                                                                                local c = tonumber(tostring(curV))
                                                                                                                                                                                                local m = tonumber(tostring(maxV))
                                                                                                                                                                                                if not c or not m or m == 0 then return nil end
                                                                                                                                                                                                    return math.floor((c / m) * 100), math.floor(m - c), c
                                                                                                                                                                                                    end)

                                                                                                                                                                                                if ok and pct and missing then
                                                                                                                                                                                                    leftText:SetText(pct .. "%")
                                                                                                                                                                                                    if missing > 0 then rightText:SetText("(-" .. missing .. ") " .. rawCur)
                                                                                                                                                                                                        else rightText:SetText("(0) " .. rawCur) end
                                                                                                                                                                                                            else
                                                                                                                                                                                                                leftText:SetText("")
                                                                                                                                                                                                                rightText:SetText("")
                                                                                                                                                                                                                end
                                                                                                                                                                                                                end

                                                                                                                                                                                                                local function UpdateSoloFrameStats()
                                                                                                                                                                                                                if soloFrame:IsShown() then
                                                                                                                                                                                                                    soloFrame.nameText:SetText(UnitName("player") or "Player")
                                                                                                                                                                                                                    local curHP, maxHP = UnitHealth("player"), UnitHealthMax("player")
                                                                                                                                                                                                                    if curHP and maxHP then
                                                                                                                                                                                                                        soloFrame.healthBar:SetMinMaxValues(0, maxHP)
                                                                                                                                                                                                                        soloFrame.healthBar:SetValue(curHP)
                                                                                                                                                                                                                        UpdateBarTextFromWidget(soloFrame.healthBar, soloFrame.healthLeftText, soloFrame.healthRightText)
                                                                                                                                                                                                                        end

                                                                                                                                                                                                                        local curPower, maxPower = UnitPower("player"), UnitPowerMax("player")
                                                                                                                                                                                                                        if curPower and maxPower then
                                                                                                                                                                                                                            soloFrame.manaBar:SetMinMaxValues(0, maxPower)
                                                                                                                                                                                                                            soloFrame.manaBar:SetValue(curPower)
                                                                                                                                                                                                                            UpdateBarTextFromWidget(soloFrame.manaBar, soloFrame.manaLeftText, soloFrame.manaRightText)
                                                                                                                                                                                                                            end
                                                                                                                                                                                                                            end

                                                                                                                                                                                                                            if petFrame:IsShown() and UnitExists("pet") then
                                                                                                                                                                                                                                petFrame.nameText:SetText(UnitName("pet") or "Pet")
                                                                                                                                                                                                                                local curPetHP, maxPetHP = UnitHealth("pet"), UnitHealthMax("pet")
                                                                                                                                                                                                                                if curPetHP and maxPetHP then
                                                                                                                                                                                                                                    petFrame.healthBar:SetMinMaxValues(0, maxPetHP)
                                                                                                                                                                                                                                    petFrame.healthBar:SetValue(curPetHP)
                                                                                                                                                                                                                                    UpdateBarTextFromWidget(petFrame.healthBar, petFrame.healthLeftText, petFrame.healthRightText)
                                                                                                                                                                                                                                    end
                                                                                                                                                                                                                                    end
                                                                                                                                                                                                                                    end

                                                                                                                                                                                                                                    local soloStatsUpdatePending = false
                                                                                                                                                                                                                                    local function RequestSoloStatsUpdate()
                                                                                                                                                                                                                                        if soloStatsUpdatePending then return end
                                                                                                                                                                                                                                        soloStatsUpdatePending = true
                                                                                                                                                                                                                                        if C_Timer and C_Timer.After then
                                                                                                                                                                                                                                            C_Timer.After(0, function()
                                                                                                                                                                                                                                                soloStatsUpdatePending = false
                                                                                                                                                                                                                                                UpdateSoloFrameStats()
                                                                                                                                                                                                                                            end)
                                                                                                                                                                                                                                        else
                                                                                                                                                                                                                                            soloStatsUpdatePending = false
                                                                                                                                                                                                                                            UpdateSoloFrameStats()
                                                                                                                                                                                                                                        end
                                                                                                                                                                                                                                    end

-- ---------------------------------------------------------
-- Universal Action Binding
-- ---------------------------------------------------------
local buttonNameToIndex = {
    LeftButton = "1",
    RightButton = "2",
    MiddleButton = "3",
    Button4 = "4",
    Button5 = "5",
}

local function GetActiveBindingForClick(button)
    local btnIndex = buttonNameToIndex[button]
    if not btnIndex then return nil end

    local isCtrl = IsControlKeyDown()
    local isAlt = IsAltKeyDown()
    local isShift = IsShiftKeyDown()

    local modKey
    if isCtrl and isAlt and isShift then
        modKey = "ctrlaltshift"
    elseif isCtrl and isAlt then
        modKey = "ctrlalt"
    elseif isShift and not isCtrl and not isAlt then
        modKey = "shift"
    elseif isCtrl and not isAlt and not isShift then
        modKey = "ctrl"
    elseif isAlt and not isCtrl and not isShift then
        modKey = "alt"
    elseif not isCtrl and not isAlt and not isShift then
        modKey = "click"
    else
        return nil
    end

    return GetSetting(modKey .. btnIndex)
end

local function SetActionBinding(unitFrame, modPrefix, btn, val)
    local prefix = ""
    if modPrefix and modPrefix ~= "" then prefix = modPrefix .. "-" end

    local typeAttr = prefix .. "type" .. btn
    local spellAttr = prefix .. "spell" .. btn
    local macroAttr = prefix .. "macrotext" .. btn

    if not val or val == "" then
        unitFrame:SetAttribute(typeAttr, nil)
        unitFrame:SetAttribute(spellAttr, nil)
        unitFrame:SetAttribute(macroAttr, nil)
    elseif val == "target" then
        unitFrame:SetAttribute(typeAttr, "macro")
        unitFrame:SetAttribute(spellAttr, nil)
        unitFrame:SetAttribute(macroAttr, "/target [@mouseover,exists][@unit,exists]")
    elseif val == "togglemenu" or val == "menu" or val == "openbuffmenu" then
        unitFrame:SetAttribute(typeAttr, "attribute")
        unitFrame:SetAttribute(spellAttr, nil)
        unitFrame:SetAttribute(macroAttr, nil)
    elseif val == "caststoredbuff" then
        local storedMacro = GetStoredBuffMacroForUnitFrame(unitFrame)
        unitFrame._storedBuffMacroText = storedMacro
        unitFrame:SetAttribute(typeAttr, "macro")
        unitFrame:SetAttribute(spellAttr, nil)
        unitFrame:SetAttribute(macroAttr, storedMacro)
    else
        unitFrame:SetAttribute(typeAttr, "macro")
        unitFrame:SetAttribute(spellAttr, nil)
        unitFrame:SetAttribute(macroAttr, "/use [@mouseover,help,nodead][@unit,help,nodead][] " .. val)
    end
end

local function BindFrame(unitFrame)
    if not unitFrame then return end
    monitoredUnitFrames[unitFrame] = true
    UpdateFrameBuffAlert(unitFrame)
    if InCombatLockdown() then return end

    unitFrame:RegisterForClicks("AnyDown", "AnyUp")

    -- Clear wildcard attributes so unbound right-click modifiers on Blizzard party/raid frames
    -- never fall back to Blizzard's default *type2 = "togglemenu"
    unitFrame:SetAttribute("*type1", nil)
    unitFrame:SetAttribute("*type2", nil)

    if not unitFrame.simpleHealPostClickHooked then
        unitFrame:HookScript("PostClick", function(self, button, down)
            if down then
                self._pendingClickAction = GetActiveBindingForClick(button) or ""
                if self._pendingClickAction ~= "openbuffmenu" and buffMenu:IsShown() then
                    if not (buffMenu.IsMouseOver and buffMenu:IsMouseOver()) then
                        buffMenu:Hide()
                    end
                end
                return
            end
            local action = self._pendingClickAction
            self._pendingClickAction = nil
            if action == nil then
                action = GetActiveBindingForClick(button)
            end
            if action == "caststoredbuff" and not InCombatLockdown() and C_Timer and C_Timer.After then
                C_Timer.After(0.3, RequestBuffAlertsUpdate)
            end
            if action == "togglemenu" or action == "menu" then
                OpenUnitContextMenu(self)
            elseif action == "openbuffmenu" then
                SimpleHeal_OpenBuffSelector(self)
            elseif InCombatLockdown() and action and action ~= "" and action ~= "target" then
                local unit = (self.GetAttribute and self:GetAttribute("unit")) or self.unit or self.displayedUnit
                local cleanName = GetCleanUnitName(unit) or self._lastCleanName
                local assignedList = GetUnitAssignedBuffList(unit, cleanName)
                if #assignedList > 0 then
                    local matched = (action == "caststoredbuff")
                    if not matched then
                        for _, assignedBuff in ipairs(assignedList) do
                            if action == assignedBuff then
                                matched = true
                                break
                            end
                            if buffEquivalents[assignedBuff] then
                                for _, eq in ipairs(buffEquivalents[assignedBuff]) do
                                    if action == eq then matched = true; break end
                                end
                            end
                            if matched then break end
                        end
                    end
                    if matched then
                        local remaining = (self._preCombatMissingCount or 1) - 1
                        self._preCombatMissingCount = remaining
                        if remaining <= 0 then
                            self._lastKnownHasBuff = true
                            UpdateFrameBuffAlert(self)
                        end
                    end
                end
            end
        end)
        unitFrame.simpleHealPostClickHooked = true
    end

    SetActionBinding(unitFrame, "", 1, GetSetting("click1"))
    SetActionBinding(unitFrame, "", 2, GetSetting("click2"))
    SetActionBinding(unitFrame, "", 3, GetSetting("click3"))
    SetActionBinding(unitFrame, "", 4, GetSetting("click4"))
    SetActionBinding(unitFrame, "", 5, GetSetting("click5"))

    SetActionBinding(unitFrame, "shift", 1, GetSetting("shift1"))
    SetActionBinding(unitFrame, "shift", 2, GetSetting("shift2"))
    SetActionBinding(unitFrame, "shift", 3, GetSetting("shift3"))
    SetActionBinding(unitFrame, "shift", 4, GetSetting("shift4"))
    SetActionBinding(unitFrame, "shift", 5, GetSetting("shift5"))

    SetActionBinding(unitFrame, "ctrl", 1, GetSetting("ctrl1"))
    SetActionBinding(unitFrame, "ctrl", 2, GetSetting("ctrl2"))
    SetActionBinding(unitFrame, "ctrl", 3, GetSetting("ctrl3"))
    SetActionBinding(unitFrame, "ctrl", 4, GetSetting("ctrl4"))
    SetActionBinding(unitFrame, "ctrl", 5, GetSetting("ctrl5"))

    SetActionBinding(unitFrame, "alt", 1, GetSetting("alt1"))
    SetActionBinding(unitFrame, "alt", 2, GetSetting("alt2"))
    SetActionBinding(unitFrame, "alt", 3, GetSetting("alt3"))
    SetActionBinding(unitFrame, "alt", 4, GetSetting("alt4"))
    SetActionBinding(unitFrame, "alt", 5, GetSetting("alt5"))

    for btn = 1, 5 do
        local ctrlAltVal = GetSetting("ctrlalt" .. btn)
        SetActionBinding(unitFrame, "alt-ctrl", btn, ctrlAltVal)
        SetActionBinding(unitFrame, "ctrl-alt", btn, ctrlAltVal)
    end

    local cas1 = GetSetting("ctrlaltshift1")
    local cas2 = GetSetting("ctrlaltshift2")

    SetActionBinding(unitFrame, "ctrl-alt-shift", 1, cas1)
    SetActionBinding(unitFrame, "ctrl-alt-shift", 2, cas2)
    SetActionBinding(unitFrame, "alt-ctrl-shift", 1, cas1)
    SetActionBinding(unitFrame, "alt-ctrl-shift", 2, cas2)
end

                                                                                                                                                                                                                                                                function frame:ApplyBindings()
                                                                                                                                                                                                                                                                if InCombatLockdown() then return end

                                                                                                                                                                                                                                                                SetCVar("useCompactPartyFrames", 1)

                                                                                                                                                                                                                                                                BindFrame(soloFrame)
                                                                                                                                                                                                                                                                BindFrame(petFrame)

                                                                                                                                                                                                                                                                soloFrame:Show()

                                                                                                                                                                                                                                                                if UnitExists("pet") or isUnlocked then petFrame:Show()
                                                                                                                                                                                                                                                                else petFrame:Hide() end

                                                                                                                                                                                                                                                                if ClickCastFrames then
                                                                                                                                                                                                                                                                for uFrame, _ in pairs(ClickCastFrames) do BindFrame(uFrame) end
                                                                                                                                                                                                                                                                end

                                                                                                                                                                                                                                                                for i = 1, 40 do
                                                                                                                                                                                                                                                                local rf = _G["CompactRaidFrame" .. i]
                                                                                                                                                                                                                                                                if rf then BindFrame(rf) end
                                                                                                                                                                                                                                                                local petRF = _G["CompactRaidPet" .. i]
                                                                                                                                                                                                                                                                if petRF then BindFrame(petRF) end
                                                                                                                                                                                                                                                                end

                                                                                                                                                                                                                                                                for i = 1, 5 do
                                                                                                                                                                                                                                                                local cpf = _G["CompactPartyFrameMember" .. i] or _G["CompactPartyFrameGroup1Member" .. i]
                                                                                                                                                                                                                                                                if cpf then BindFrame(cpf) end
                                                                                                                                                                                                                                                                local pmf = _G["PartyMemberFrame" .. i]
                                                                                                                                                                                                                                                                if pmf then BindFrame(pmf) end
                                                                                                                                                                                                                                                                local petPF = _G["PartyMemberFrame" .. i .. "Pet"] or _G["CompactPartyFrameMember" .. i .. "Pet"]
                                                                                                                                                                                                                                                                if petPF then BindFrame(petPF) end
                                                                                                                                                                                                                                                                end

                                                                                                                                                                                                                                                                RequestSoloStatsUpdate()
                                                                                                                                                                                                                                                                end

                                                                                                                                                                                                                                                                hooksecurefunc("CompactUnitFrame_SetUpFrame", function(unitFrame)
                                                                                                                                                                                                                                                                if unitFrame and not InCombatLockdown() then BindFrame(unitFrame) end
                                                                                                                                                                                                                                                                end)

                                                                                                                                                                                                                                                                if CompactRaidFrameContainer_UpdateLayout then
                                                                                                                                                                                                                                                                hooksecurefunc("CompactRaidFrameContainer_UpdateLayout", function()
                                                                                                                                                                                                                                                                if not InCombatLockdown() then frame:ApplyBindings() end
                                                                                                                                                                                                                                                                end)
                                                                                                                                                                                                                                                                end

                                                                                                                                                                                                                                                                -- ---------------------------------------------------------
                                                                                                                                                                                                                                                                -- Events
                                                                                                                                                                                                                                                                -- ---------------------------------------------------------
                                                                                                                                                                                                                                                                frame:RegisterEvent("ADDON_LOADED")
                                                                                                                                                                                                                                                                frame:RegisterEvent("PLAYER_LOGIN")
                                                                                                                                                                                                                                                                frame:RegisterEvent("PLAYER_ENTERING_WORLD")
                                                                                                                                                                                                                                                                frame:RegisterEvent("SPELLS_CHANGED")
                                                                                                                                                                                                                                                                frame:RegisterEvent("GROUP_ROSTER_UPDATE")
                                                                                                                                                                                                                                                                frame:RegisterEvent("PLAYER_REGEN_ENABLED")
                                                                                                                                                                                                                                                                frame:RegisterEvent("UNIT_HEALTH")
                                                                                                                                                                                                                                                                frame:RegisterEvent("UNIT_MAXHEALTH")
                                                                                                                                                                                                                                                                frame:RegisterEvent("UNIT_POWER_UPDATE")
                                                                                                                                                                                                                                                                frame:RegisterEvent("UNIT_MAXPOWER")
                                                                                                                                                                                                                                                                frame:RegisterEvent("UNIT_PET")
                                                                                                                                                                                                                                                                frame:RegisterEvent("PET_UI_UPDATE")
frame:RegisterEvent("UNIT_AURA")
frame:RegisterEvent("GLOBAL_MOUSE_DOWN")

        frame:SetScript("OnEvent", function(self, event, arg1)
        if event == "ADDON_LOADED" and arg1 == addonName then
            defaults = GetClassDefaults()
            if type(SimpleHealSettings) ~= "table" then
                SimpleHealSettings = {}
            end
            for k, v in pairs(defaults) do
                if SimpleHealSettings[k] == nil then
                    SimpleHealSettings[k] = v
                end
            end
            for _, dd in ipairs(uiDropdowns) do if dd.Refresh then dd:Refresh() end end
        elseif event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
                                                                                                                                                                                                                                                                defaults = GetClassDefaults()
                                                                                                                                                                                                                                                                ScanPlayerSpellbook()
                                                                                                                                                                                                                                                                self:ApplyBindings()
                                                                                                                                                                                                                                                                RequestSoloStatsUpdate()
    RequestBuffAlertsUpdate()
    if C_Timer and C_Timer.After then C_Timer.After(1.0, UpdateAllBuffAlerts) end
                                                                                                                                                                                                                                                                elseif event == "SPELLS_CHANGED" then
                                                                                                                                                                                                                                                                ScanPlayerSpellbook()
        elseif event == "PLAYER_REGEN_ENABLED" then
            self:ApplyBindings()
            RequestSoloStatsUpdate()
            RequestBuffAlertsUpdate()
                                                                                                                                                                                                                                                                elseif event == "GROUP_ROSTER_UPDATE" then
                                                                                                                                                                                                                                                                if not IsInGroup() and not IsInRaid() then SimpleHealUnitBuffs = {} end
                                                                                                                                                                                                                                                                self:ApplyBindings()
                                                                                                                                                                                                                                                                RequestSoloStatsUpdate()
    RequestBuffAlertsUpdate()
                                                                                                                                                                                                                                                                elseif event == "UNIT_PET" or event == "PET_UI_UPDATE" then
                                                                                                                                                                                                                                                                self:ApplyBindings()
                                                                                                                                                                                                                                                                RequestSoloStatsUpdate()
                                                                                                                                                                                                                                                                elseif event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH" or event == "UNIT_POWER_UPDATE" or event == "UNIT_MAXPOWER" then
                                                                                                                                                                                                                                if arg1 == "player" or arg1 == "pet" then RequestSoloStatsUpdate() end
    elseif event == "UNIT_AURA" then
        RequestBuffAlertsUpdate()
    elseif event == "GLOBAL_MOUSE_DOWN" then
        if buffMenu:IsShown() and not (buffMenu.IsMouseOver and buffMenu:IsMouseOver()) then
            buffMenu:Hide()
        end
    end
end)

if C_Timer and C_Timer.NewTicker then
    C_Timer.NewTicker(1.0, UpdateAllBuffAlerts)
end

                                                                                                                                                                                                                                                                -- ---------------------------------------------------------
                                                                                                                                                                                                                                                                -- Slash Commands (/shf)
                                                                                                                                                                                                                                                                -- ---------------------------------------------------------
                                                                                                                                                                                                                                                                SLASH_SIMPLEHEAL1 = "/shf"
                                                                                                                                                                                                                                                                SlashCmdList["SIMPLEHEAL"] = function(msg)
                                                                                                                                                                                                                                                                local command, val = msg:match("^(%S+)%s+(.+)$")
                                                                                                                                                                                                                                                                local input = msg and msg:lower() or ""

                                                                                                                                                                                                                                                                if input == "ui" or input == "menu" or input == "spells" or input == "config" then
                                                                                                                                                                                                                                                                SimpleHeal_ToggleConfigUI()
                                                                                                                                                                                                                                                                return
                                                                                                                                                                                                                                                                end

                                                                                                                                                                                                                                                                if input == "clearbuffs" or input == "resetbuffs" then
                                                                                                                                                                                                                                                                SimpleHealUnitBuffs = {}
                                                                                                                                                                                                                                                                print("|cFF00FF00[SimpleHeal]|r Stored player buff assignments cleared!")
                                                                                                                                                                                                                                                                if frame.ApplyBindings then frame:ApplyBindings() end
    UpdateAllBuffAlerts()
                                                                                                                                                                                                                                                                return
                                                                                                                                                                                                                                                                end

    if input == "buffcycle" or (command and command:lower() == "buffcycle") then
        SimpleHealSettings = SimpleHealSettings or {}
        local secs = tonumber(val)
        if input == "buffcycle" then
            print("|cFF00FF00[SimpleHeal]|r In-combat buff cycle resets after |cFFFFD100" .. GetBuffCycleResetSeconds() .. "s|r idle. Usage: /shf buffcycle <1-60>")
            return
        elseif not secs or secs < 1 or secs > 60 then
            print("|cFFFF0000[SimpleHeal]|r Usage: /shf buffcycle <seconds 1-60>")
            return
        end
        SimpleHealSettings.buffCycleReset = math.floor(secs)
        print("|cFF00FF00[SimpleHeal]|r In-combat buff cycle reset set to |cFFFFD100" .. SimpleHealSettings.buffCycleReset .. "s|r")
        if not InCombatLockdown() and frame.ApplyBindings then frame:ApplyBindings() end
        return
    end

    if input == "buffalert" then
        SimpleHealSettings = SimpleHealSettings or defaults
        local enabled = not (SimpleHealSettings.buffAlertEnabled ~= false)
        SimpleHealSettings.buffAlertEnabled = enabled
        UpdateAllBuffAlerts()
        print("|cFF00FF00[SimpleHeal]|r Missing Buff Alert: " .. (enabled and "|cFFFFD100ENABLED|r" or "|cFFFF0000DISABLED|r"))
        return
    elseif input == "buffalert outline" then
        SimpleHealSettings = SimpleHealSettings or defaults
        SimpleHealSettings.buffAlertOutline = not (SimpleHealSettings.buffAlertOutline ~= false)
        UpdateAllBuffAlerts()
        print("|cFF00FF00[SimpleHeal]|r Buff Alert Frame Outline: " .. (SimpleHealSettings.buffAlertOutline and "|cFFFFD100ENABLED|r" or "|cFFFF0000DISABLED|r"))
        return
    elseif input == "buffalert tags" then
        SimpleHealSettings = SimpleHealSettings or defaults
        SimpleHealSettings.buffAlertTags = not (SimpleHealSettings.buffAlertTags ~= false)
        UpdateAllBuffAlerts()
        print("|cFF00FF00[SimpleHeal]|r Buff Alert Name (~) Tags: " .. (SimpleHealSettings.buffAlertTags and "|cFFFFD100ENABLED|r" or "|cFFFF0000DISABLED|r"))
        return
    end

                                                                                                                                                                                                                                                                if input == "move" or input == "unlock" or input == "lock" then
                                                                                                                                                                                                                                                                if InCombatLockdown() then
                                                                                                                                                                                                                                                                print("|cFFFF0000[SimpleHeal]|r Cannot toggle move mode during combat!")
                                                                                                                                                                                                                                                                return
                                                                                                                                                                                                                                                                end
                                                                                                                                                                                                                                                                if input == "lock" then isUnlocked = false
                                                                                                                                                                                                                                                                elseif input == "unlock" then isUnlocked = true
                                                                                                                                                                                                                                                                else isUnlocked = not isUnlocked end

                                                                                                                                                                                                                                                                if isUnlocked then
                                                                                                                                                                                                                                                                soloFrame:Show(); petFrame:Show()
                                                                                                                                                                                                                                                                soloFrame.moveOverlay:Show(); soloFrame.moveText:Show(); petFrame.moveOverlay:Show()
                                                                                                                                                                                                                                                                print("|cFF00FF00[SimpleHeal]|r Move Mode |cFFFFD100ENABLED|r. Drag frame with Left-Click.")
                                                                                                                                                                                                                                                                else
                                                                                                                                                                                                                                                                soloFrame.moveOverlay:Hide(); soloFrame.moveText:Hide(); petFrame.moveOverlay:Hide()
                                                                                                                                                                                                                                                                frame:ApplyBindings()
                                                                                                                                                                                                                                                                print("|cFF00FF00[SimpleHeal]|r Move Mode |cFFFFD100LOCKED|r.")
                                                                                                                                                                                                                                                                end
                                                                                                                                                                                                                                                                return
                                                                                                                                                                                                                                                                end

                                                                                                                                                                                                                                                                if command then
                                                                                                                                                                                                                                                                command = command:lower()
                                                                                                                                                                                                                                                                if command == "left" then SimpleHealSettings.click1 = val
                                                                                                                                                                                                                                                                elseif command == "right" then SimpleHealSettings.click2 = val
                                                                                                                                                                                                                                                                elseif command == "middle" or command == "btn3" then SimpleHealSettings.click3 = val
                                                                                                                                                                                                                                                                elseif command == "btn4" then SimpleHealSettings.click4 = val
                                                                                                                                                                                                                                                                elseif command == "btn5" then SimpleHealSettings.click5 = val
                                                                                                                                                                                                                                                                elseif command == "ctrlaltshiftleft" then SimpleHealSettings.ctrlaltshift1 = val
                                                                                                                                                                                                                                                                elseif command == "ctrlaltshiftright" then SimpleHealSettings.ctrlaltshift2 = val
                                                                                                                                                                                                                                                                end
                                                                                                                                                                                                                                                                print("|cFF00FF00[SimpleHeal]|r " .. command .. " bound to: |cFFFFD100" .. val .. "|r")
                                                                                                                                                                                                                                                                frame:ApplyBindings()
                                                                                                                                                                                                                                                                return
                                                                                                                                                                                                                                                                end

                                                                                                                                                                                                                                                                print("|cFF00FF00[SimpleHeal Usage]|r")
                                                                                                                                                                                                                                                                print("  /shf ui - Opens the drop-down binding menu")
                                                                                                                                                                                                                                                                print("  /shf move - Toggles frame move mode on or off")
    print("  /shf buffalert - Toggles missing buff alert on/off")
    print("  /shf buffalert outline - Toggles frame outline only")
    print("  /shf buffalert tags - Toggles name (~) tags only")
    print("  /shf buffcycle <sec> - In-combat multi-buff cycle reset delay")
                                                                                                                                                                                                                                                                print("  /shf clearbuffs - Clears stored player buff assignments")
                                                                                                                                                                                                                                                                end
