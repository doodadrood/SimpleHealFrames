-- =========================================================================
-- Headless Unit & Taint Test Suite for SimpleHeal (World of Warcraft: Forever)
-- Run with: luajit tests/test_simpleheal.lua
-- =========================================================================

local passed = 0
local failed = 0

local function test_print(msg)
    io.stdout:write(tostring(msg) .. "\n")
end

local function assert_true(cond, msg)
    if not cond then
        error("Assertion failed: " .. (msg or "expected true"), 2)
    end
end

local function assert_eq(actual, expected, msg)
    if actual ~= expected then
        error(string.format(
            "Assertion failed: %s (expected %s, got %s)",
            msg or "values not equal",
            tostring(expected),
            tostring(actual)
        ), 2)
    end
end

local function run_test(name, fn)
    local ok, err = pcall(fn)
    if ok then
        passed = passed + 1
        test_print("  [PASS] " .. name)
    else
        failed = failed + 1
        test_print("  [FAIL] " .. name)
        test_print("         " .. tostring(err))
    end
end

-- =========================================================================
-- WoW 12.0 Secret Value Simulator
-- Simulates tainted/secret strings & numbers that throw Lua errors if indexed,
-- compared, concatenated, or converted without pcall / issecretvalue guards.
-- =========================================================================
local secretRegistry = setmetatable({}, { __mode = "k" })

local function create_secret_value(label)
    local proxy = newproxy(true)
    local mt = getmetatable(proxy)
    local function taint_err()
        error("attempt to perform operation on a secret value (" .. tostring(label) .. ") (execution tainted by 'SimpleHeal')", 2)
    end
    mt.__index = taint_err
    mt.__newindex = taint_err
    mt.__eq = taint_err
    mt.__lt = taint_err
    mt.__le = taint_err
    mt.__concat = taint_err
    mt.__add = taint_err
    mt.__sub = taint_err
    mt.__mul = taint_err
    mt.__div = taint_err
    mt.__tostring = taint_err
    secretRegistry[proxy] = true
    return proxy
end

_G.issecretvalue = function(val)
    return secretRegistry[val] == true
end

-- Enforce secret string failure inside string.match / string.find just like WoW C API
local orig_string_match = string.match
string.match = function(s, ...)
    if _G.issecretvalue(s) then
        error("attempt to perform string conversion on a secret string value (execution tainted by 'SimpleHeal')", 2)
    end
    return orig_string_match(s, ...)
end

local orig_string_find = string.find
string.find = function(s, ...)
    if _G.issecretvalue(s) then
        error("attempt to perform string conversion on a secret string value (execution tainted by 'SimpleHeal')", 2)
    end
    return orig_string_find(s, ...)
end

-- =========================================================================
-- Minimal WoW FrameXML & C_Namespace Mock Environment
-- =========================================================================
_G.UISpecialFrames = {}
_G.ClickCastFrames = {}
_G.SlashCmdList = {}
_G.UnitPopupMenus = {
    SELF = true,
    PET = true,
    PARTY = true,
    RAID_PLAYER = true,
    RAID = true,
    PLAYER = true,
    TARGET = true,
}

local mockState = {
    inCombat = false,
    isInGroup = true,
    isInRaid = false,
    isCtrl = false,
    isAlt = false,
    isShift = false,
    playerClassName = "Paladin",
    playerClassFile = "PALADIN",
    cVars = {},
    timers = {},
    lastPopupMenu = nil,
    auraQueriesCount = 0,
    units = {
        player = {
            exists = true,
            name = "Lightbringer",
            server = nil,
            hp = 1000,
            maxHp = 1000,
            power = 800,
            maxPower = 1000,
            dead = false,
            connected = true,
            isPlayer = true,
            inParty = true,
            inRaid = false,
            className = "Paladin",
            classFile = "PALADIN",
            buffs = {},
        },
        pet = {
            exists = true,
            name = "Charger",
            server = nil,
            hp = 500,
            maxHp = 500,
            power = 100,
            maxPower = 100,
            dead = false,
            connected = true,
            isPlayer = false,
            inParty = false,
            inRaid = false,
            className = "Warrior",
            classFile = "WARRIOR",
            buffs = {},
        },
        party1 = {
            exists = true,
            name = "Thrall-Forever",
            server = "Forever",
            hp = 1200,
            maxHp = 1500,
            power = 500,
            maxPower = 500,
            dead = false,
            connected = true,
            isPlayer = true,
            inParty = true,
            inRaid = false,
            className = "Shaman",
            classFile = "SHAMAN",
            buffs = {},
        },
        raid1 = {
            exists = true,
            name = "Jaina-Forever",
            server = "Forever",
            hp = 900,
            maxHp = 900,
            power = 1200,
            maxPower = 1200,
            dead = false,
            connected = true,
            isPlayer = true,
            inParty = false,
            inRaid = true,
            className = "Mage",
            classFile = "MAGE",
            buffs = {},
        },
        raid2 = {
            exists = true,
            name = "Nobundo-Forever",
            server = "Forever",
            hp = 1100,
            maxHp = 1100,
            power = 900,
            maxPower = 900,
            dead = false,
            connected = true,
            isPlayer = true,
            inParty = false,
            inRaid = true,
            className = "Shaman",
            classFile = "SHAMAN",
            buffs = {},
        },
    },
    spellbook = {
        "Flash of Light",
        "Holy Light",
        "Holy Shock",
        "Blessing of Might",
        "Greater Blessing of Might",
        "Blessing of Wisdom",
        "Blessing of Kings",
        "Divine Spirit",
        "Power Word: Fortitude",
        "Cleanse",
    },
    spellIDs = {
        ["Flash of Light"] = 19750,
        ["Holy Light"] = 635,
        ["Holy Shock"] = 20473,
        ["Blessing of Might"] = 19740,
        ["Greater Blessing of Might"] = 25782,
        ["Blessing of Wisdom"] = 19742,
        ["Blessing of Kings"] = 20217,
        ["Divine Spirit"] = 14752,
        ["Power Word: Fortitude"] = 1243,
        ["Cleanse"] = 4987,
    },
}

local function NewMockWidget(frameType, name, parent)
    local w = {
        _type = frameType or "Frame",
        _name = name,
        _parent = parent,
        _shown = true,
        _mouseOver = false,
        _attributes = {},
        _scripts = {},
        _hooks = {},
        _events = {},
        _text = "",
        _min = 0,
        _max = 100,
        _val = 100,
        _level = 1,
        _points = {},
        _borderColor = { 1, 1, 1, 1 },
    }

    function w:SetSize() end
    function w:SetWidth() end
    function w:SetHeight() end
    function w:SetPoint(...) table.insert(self._points, { ... }) end
    function w:SetAllPoints() end
    function w:ClearAllPoints() self._points = {} end
    function w:SetFrameStrata() end
    function w:SetFrameLevel(lvl) self._level = lvl end
    function w:GetFrameLevel() return self._level end
    function w:SetClampedToScreen() end
    function w:SetBackdrop() end
    function w:SetBackdropColor() end
    function w:SetBackdropBorderColor(r, g, b, a) self._borderColor = { r, g, b, a } end
    function w:SetMovable() end
    function w:EnableMouse() end
    function w:EnableKeyboard() end
    function w:SetPropagateKeyboardInput() end
    function w:IsMouseOver() return self._mouseOver end
    function w:RegisterForDrag() end
    function w:RegisterForClicks() end
    function w:StartMoving() end
    function w:StopMovingOrSizing() end
    function w:Show() self._shown = true end
    function w:Hide() self._shown = false end
    function w:IsShown() return self._shown end
    function w:GetName() return self._name end
    function w:GetEffectiveScale() return 1.0 end
    function w:SetScrollChild() end
    function w:SetStatusBarTexture() end
    function w:SetStatusBarColor() end
    function w:SetMinMaxValues(minV, maxV) self._min, self._max = minV, maxV end
    function w:GetMinMaxValues() return self._min, self._max end
    function w:SetValue(v) self._val = v end
    function w:GetValue() return self._val end
    function w:SetColorTexture() end
    function w:SetTexture() end
    function w:SetTexCoord() end
    function w:SetBlendMode() end
    function w:SetJustifyH() end
    function w:SetTextColor() end
    function w:SetShadowColor() end
    function w:SetShadowOffset() end
    function w:SetText(t) self._text = t end
    function w:GetText() return self._text end

    function w:SetAttribute(k, v)
        if _G.InCombatLockdown() then
            error("Attempt to call SetAttribute during combat lockdown!", 2)
        end
        self._attributes[k] = v
    end
    function w:GetAttribute(k) return self._attributes[k] end

    function w:RegisterEvent(ev) self._events[ev] = true end
    function w:SetScript(scriptName, fn) self._scripts[scriptName] = fn end
    function w:GetScript(scriptName) return self._scripts[scriptName] end
    function w:HookScript(scriptName, fn)
        self._hooks[scriptName] = self._hooks[scriptName] or {}
        table.insert(self._hooks[scriptName], fn)
    end

    function w:FireEvent(event, ...)
        if self._events[event] and self._scripts["OnEvent"] then
            self._scripts["OnEvent"](self, event, ...)
        end
    end

    function w:SimulateClick(button, down)
        if self._scripts["OnClick"] then
            self._scripts["OnClick"](self, button, down)
        end
        if self._hooks["PostClick"] then
            for _, fn in ipairs(self._hooks["PostClick"]) do
                fn(self, button, down)
            end
        end
    end

    function w:CreateTexture(texName)
        local t = NewMockWidget("Texture", texName, self)
        if texName then _G[texName] = t end
        return t
    end

    function w:CreateFontString(fsName)
        local fs = NewMockWidget("FontString", fsName, self)
        if fsName then _G[fsName] = fs end
        return fs
    end

    if name then
        _G[name] = w
    end
    return w
end

_G.UIParent = NewMockWidget("Frame", "UIParent", nil)
_G.CreateFrame = function(frameType, name, parent)
    return NewMockWidget(frameType, name, parent)
end

_G.UnitClass = function(unit)
    local u = mockState.units[unit or "player"]
    if u and u.className and u.classFile then
        return u.className, u.classFile
    end
    return mockState.playerClassName, mockState.playerClassFile
end
_G.InCombatLockdown = function() return mockState.inCombat end
_G.IsInGroup = function() return mockState.isInGroup end
_G.IsInRaid = function() return mockState.isInRaid end
_G.IsControlKeyDown = function() return mockState.isCtrl end
_G.IsAltKeyDown = function() return mockState.isAlt end
_G.IsShiftKeyDown = function() return mockState.isShift end
_G.GetCursorPosition = function() return 200, 200 end
_G.SetCVar = function(k, v) mockState.cVars[k] = v end
_G.hooksecurefunc = function(tblOrName, funcNameOrHook, maybeHook)
    if type(tblOrName) == "string" then
        local orig = _G[tblOrName]
        _G[tblOrName] = function(...)
            if orig then orig(...) end
            funcNameOrHook(...)
        end
    end
end
_G.UIDropDownMenu_SetWidth = function() end
_G.UIDropDownMenu_SetText = function() end
_G.UIDropDownMenu_Initialize = function() end
_G.UIDropDownMenu_CreateInfo = function() return {} end
_G.UIDropDownMenu_AddButton = function() end

_G.UnitExists = function(unit)
    local u = unit and mockState.units[unit]
    return u ~= nil and u.exists == true
end
_G.UnitName = function(unit)
    local u = unit and mockState.units[unit]
    if not u then return nil end
    return u.name, u.server
end
_G.UnitIsUnit = function(u1, u2)
    if not u1 or not u2 then return false end
    return u1 == u2
end
_G.UnitIsDeadOrGhost = function(unit)
    local u = unit and mockState.units[unit]
    return u and u.dead or false
end
_G.UnitIsConnected = function(unit)
    local u = unit and mockState.units[unit]
    return u and u.connected ~= false
end
_G.UnitInRaid = function(unit)
    local u = unit and mockState.units[unit]
    return u and u.inRaid or false
end
_G.UnitInParty = function(unit)
    local u = unit and mockState.units[unit]
    return u and u.inParty or false
end
_G.UnitIsPlayer = function(unit)
    local u = unit and mockState.units[unit]
    return u and u.isPlayer or false
end
_G.UnitHealth = function(unit)
    local u = unit and mockState.units[unit]
    return u and u.hp or 0
end
_G.UnitHealthMax = function(unit)
    local u = unit and mockState.units[unit]
    return u and u.maxHp or 100
end
_G.UnitPower = function(unit)
    local u = unit and mockState.units[unit]
    return u and u.power or 0
end
_G.UnitPowerMax = function(unit)
    local u = unit and mockState.units[unit]
    return u and u.maxPower or 100
end

-- UnitPopup_OpenMenu mock: strictly validates WoW 11.x/12.x signature (which: string, contextData: table)
_G.UnitPopup_OpenMenu = function(which, contextData, unitFrame)
    if type(which) ~= "string" then
        error("UnitPopupShared.lua:110: attempt to concatenate upvalue 'which' (a " .. type(which) .. " value)", 2)
    end
    if type(contextData) ~= "table" or not contextData.unit then
        error("UnitPopup_OpenMenu: contextData must be a table with .unit", 2)
    end
    mockState.lastPopupMenu = { which = which, contextData = contextData, frame = unitFrame }
end

_G.C_Timer = {
    After = function(_, cb)
        table.insert(mockState.timers, cb)
    end,
    NewTicker = function(_, cb)
        mockState.tickerCallback = cb
        return { Cancel = function() end }
    end,
}

local function flush_timers()
    local q = mockState.timers
    mockState.timers = {}
    for _, cb in ipairs(q) do
        cb()
    end
end

_G.C_Spell = {
    GetSpellInfo = function(spellName)
        local id = mockState.spellIDs[spellName]
        if id then return { name = spellName, spellID = id } end
        return nil
    end,
}

_G.C_SpellBook = {
    GetNumSpellBookSkillLines = function() return 1 end,
    GetSpellBookSkillLineInfo = function()
        return { itemIndexOffset = 0, numSpellBookItems = #mockState.spellbook }
    end,
    GetSpellBookItemType = function() return 0 end,
    GetSpellBookItemName = function(slot) return mockState.spellbook[slot] end,
    GetSpellBookItemInfo = function(slot) return { isPassive = false } end,
}

_G.C_UnitAuras = {
    GetPlayerAuraBySpellID = function(spellID)
        mockState.auraQueriesCount = mockState.auraQueriesCount + 1
        local buffs = mockState.units.player.buffs or {}
        for _, b in ipairs(buffs) do
            if not b.isSecretAura and b.spellId == spellID then
                return b
            end
        end
        return nil
    end,
    GetBuffDataByIndex = function(unit, index, filter)
        mockState.auraQueriesCount = mockState.auraQueriesCount + 1
        if filter == "HELPFUL" then
            error("GetBuffDataByIndex(): Invalid filter 'HELPFUL'", 2)
        end
        local u = mockState.units[unit]
        if not u or not u.buffs then return nil end
        local b = u.buffs[index]
        if not b then return nil end
        if b.throwSecretError then
            error("GetBuffDataByIndex(): Auras cannot be accessed when secret while tainted by 'SimpleHeal'", 2)
        end
        return b
    end,
    GetAuraDataByIndex = function(unit, index, filter)
        mockState.auraQueriesCount = mockState.auraQueriesCount + 1
        local u = mockState.units[unit]
        if not u or not u.buffs then return nil end
        local b = u.buffs[index]
        if not b then return nil end
        if b.throwSecretError then
            error("GetAuraDataByIndex(): Auras cannot be accessed when secret while tainted by 'SimpleHeal'", 2)
        end
        return b
    end,
}

-- Create mock party and raid frames before loading addon
local partyFrame1 = CreateFrame("Button", "CompactPartyFrameMember1", UIParent, "SecureUnitButtonTemplate")
partyFrame1:SetAttribute("unit", "party1")
partyFrame1.name = partyFrame1:CreateFontString()
partyFrame1.name:SetText("Thrall")

local raidFrame1 = CreateFrame("Button", "CompactRaidFrame1", UIParent, "SecureUnitButtonTemplate")
raidFrame1:SetAttribute("unit", "raid1")
raidFrame1.name = raidFrame1:CreateFontString()
raidFrame1.name:SetText("Jaina")

local raidFrame2 = CreateFrame("Button", "CompactRaidFrame2", UIParent, "SecureUnitButtonTemplate")
raidFrame2:SetAttribute("unit", "raid2")
raidFrame2.name = raidFrame2:CreateFontString()
raidFrame2.name:SetText("Nobundo")

_G.CompactUnitFrame_SetUpFrame = function() end
_G.CompactUnitFrame_SetUnit = function(frame, unit)
    frame.unit = unit
    frame.displayedUnit = unit
    frame:SetAttribute("unit", unit)
end

-- =========================================================================
-- Load SimpleHeal.lua
-- =========================================================================
test_print("=================================================================")
test_print("SimpleHeal Test Suite (World of Warcraft: Forever)")
test_print("=================================================================")

local addonChunk, loadErr = loadfile("SimpleHeal.lua")
if not addonChunk then
    test_print("[FATAL] Failed to parse SimpleHeal.lua: " .. tostring(loadErr))
    os.exit(1)
end

local createdFrames = {}
local origCreateFrame = _G.CreateFrame
_G.CreateFrame = function(...)
    local f = origCreateFrame(...)
    table.insert(createdFrames, f)
    return f
end

addonChunk("SimpleHeal", {})
_G.CreateFrame = origCreateFrame

local mainEventFrame = createdFrames[1]
local soloFrame = _G.SimpleHealSoloFrame
local petFrame = _G.SimpleHealPetFrame
local buffMenu = _G.SimpleHealBuffMenu

-- =========================================================================
-- Test Cases
-- =========================================================================

run_test("1. Addon Initialization & Paladin Class Defaults", function()
    mainEventFrame:FireEvent("ADDON_LOADED", "SimpleHeal")
    mainEventFrame:FireEvent("PLAYER_LOGIN")
    flush_timers()

    assert_true(soloFrame ~= nil, "SimpleHealSoloFrame should exist")
    assert_true(petFrame ~= nil, "SimpleHealPetFrame should exist")
    assert_eq(SimpleHealSettings.click1, "Flash of Light", "Paladin click1 default")
    assert_eq(SimpleHealSettings.click2, "Holy Light", "Paladin click2 default")
    assert_eq(SimpleHealSettings.ctrlalt1, "target", "Universal ctrlalt1 default")
    assert_eq(SimpleHealSettings.ctrlalt2, "togglemenu", "Universal ctrlalt2 default")
end)

run_test("2. Right-Click Spell Does Not Open Context Menu (Wildcard & Hook Fix)", function()
    mockState.lastPopupMenu = nil
    mockState.isCtrl = false
    mockState.isAlt = false
    mockState.isShift = false

    assert_eq(soloFrame:GetAttribute("*type2"), nil, "soloFrame *type2 wildcard must be nil")
    assert_eq(petFrame:GetAttribute("*type2"), nil, "petFrame *type2 wildcard must be nil")

    assert_eq(soloFrame:GetAttribute("type2"), "macro", "type2 should be macro")
    assert_true(soloFrame:GetAttribute("macrotext2"):find("Holy Light") ~= nil, "macrotext2 should cast Holy Light")

    soloFrame:SimulateClick("RightButton", false)
    partyFrame1:SimulateClick("RightButton", false)
    assert_eq(mockState.lastPopupMenu, nil, "Plain right-click must NOT open menu when bound to Holy Light")
end)

run_test("3. Ctrl+Alt+Right-Click Opens Context Menu with Correct Signature", function()
    mockState.lastPopupMenu = nil
    mockState.isCtrl = true
    mockState.isAlt = true
    mockState.isShift = false

    soloFrame:SimulateClick("RightButton", true)
    assert_eq(mockState.lastPopupMenu, nil, "Mouse down should not open context menu")

    soloFrame:SimulateClick("RightButton", false)
    assert_true(mockState.lastPopupMenu ~= nil, "Ctrl+Alt+RightClick should open menu on soloFrame")
    assert_eq(mockState.lastPopupMenu.which, "SELF", "soloFrame menu type must be SELF")
    assert_eq(mockState.lastPopupMenu.contextData.unit, "player", "contextData.unit must be player")

    mockState.lastPopupMenu = nil
    partyFrame1:SimulateClick("RightButton", false)
    assert_true(mockState.lastPopupMenu ~= nil, "Ctrl+Alt+RightClick should open menu on partyFrame1")
    assert_eq(mockState.lastPopupMenu.which, "PARTY", "partyFrame1 menu type must be PARTY")
    assert_eq(mockState.lastPopupMenu.contextData.unit, "party1", "contextData.unit must be party1")

    mockState.lastPopupMenu = nil
    raidFrame1:SimulateClick("RightButton", false)
    assert_true(mockState.lastPopupMenu ~= nil, "Ctrl+Alt+RightClick should open menu on raidFrame1")
    assert_eq(mockState.lastPopupMenu.which, "RAID_PLAYER", "raidFrame1 menu type must be RAID_PLAYER")

    mockState.isCtrl = false
    mockState.isAlt = false
end)

run_test("4. Secret String Taint During Zoning Does Not Crash", function()
    local origName = mockState.units.party1.name
    mockState.units.party1.name = create_secret_value("ThrallSecret")

    mainEventFrame:FireEvent("PLAYER_ENTERING_WORLD")
    flush_timers()
    UpdateAllBuffAlerts()

    mockState.units.party1.name = origName
end)

run_test("5. Missing Buff Alert & Secret Aura at Index 1 Does Not Block Buff Detection", function()
    SimpleHeal_OpenBuffSelector(partyFrame1)
    assert_true(buffMenu:IsShown(), "Buff selector menu should open")

    SimpleHealUnitBuffs["Thrall"] = "Blessing of Might"
    mockState.units.party1.buffs = {}
    UpdateAllBuffAlerts()

    local overlay = partyFrame1.simpleHealBuffOverlay
    assert_true(overlay ~= nil and overlay:IsShown(), "Alert overlay should show when buff is missing")
    assert_true(overlay.leftTag:IsShown() and overlay.rightTag:IsShown(), "~ tags should show when buff is missing")

    mockState.units.party1.buffs = {
        [1] = { throwSecretError = true },
        [2] = { name = "Blessing of Might", spellId = 19740 },
    }

    mainEventFrame:FireEvent("UNIT_AURA", "party1")
    flush_timers()

    assert_true(not overlay:IsShown(), "Overlay must be cleared when buff is at index 2 despite secret aura at index 1")
    assert_true(not overlay.leftTag:IsShown() and not overlay.rightTag:IsShown(), "~ tags must be hidden when buff is present")
end)

run_test("6. Greater Blessing Equivalence & Secret Field Guard", function()
    SimpleHealUnitBuffs["Thrall"] = "Blessing of Might"

    mockState.units.party1.buffs = {
        [1] = { name = create_secret_value("HiddenEncounterAura"), spellId = create_secret_value("99999") },
        [2] = { name = "Greater Blessing of Might", spellId = 25782 },
    }

    UpdateAllBuffAlerts()
    local overlay = partyFrame1.simpleHealBuffOverlay
    assert_true(not overlay:IsShown(), "Greater Blessing of Might must satisfy Blessing of Might assignment")
end)

run_test("7. Direct Player SpellID Lookup & Stored Buff Macro Attributes", function()
    SimpleHealUnitBuffs["Lightbringer"] = "Blessing of Kings"
    mockState.units.player.buffs = {}
    mainEventFrame:ApplyBindings()
    UpdateAllBuffAlerts()

    local macro1 = soloFrame:GetAttribute("ctrl-alt-shift-macrotext1")
    local macro2 = soloFrame:GetAttribute("alt-ctrl-shift-macrotext1")
    assert_true(macro1 and macro1:find("Blessing of Kings") ~= nil, "ctrl-alt-shift-macrotext1 must contain Blessing of Kings")
    assert_eq(macro1, macro2, "alt-ctrl-shift-macrotext1 must match ctrl-alt-shift-macrotext1")

    local soloOverlay = soloFrame.simpleHealBuffOverlay
    assert_true(soloOverlay ~= nil and soloOverlay:IsShown(), "Solo overlay should show when player lacks Blessing of Kings")

    mockState.units.player.buffs = {
        [1] = { name = "Blessing of Kings", spellId = 20217 },
    }
    UpdateAllBuffAlerts()
    assert_true(not soloOverlay:IsShown(), "Solo overlay should hide when player gains Blessing of Kings")
end)

run_test("8. Performance: Combat Health/Mana Events Do Not Trigger Aura Scans", function()
    flush_timers()
    mockState.auraQueriesCount = 0

    for _ = 1, 50 do
        mainEventFrame:FireEvent("UNIT_HEALTH", "player")
        mainEventFrame:FireEvent("UNIT_POWER_UPDATE", "player")
        mainEventFrame:FireEvent("UNIT_HEALTH", "party1")
        mainEventFrame:FireEvent("UNIT_HEALTH", "raid1")
    end
    flush_timers()

    assert_eq(mockState.auraQueriesCount, 0, "Health and mana events must trigger 0 aura queries")
end)

run_test("9. Performance: Short-Circuit When No Buffs Are Assigned", function()
    SlashCmdList["SIMPLEHEAL"]("clearbuffs")
    flush_timers()

    mockState.auraQueriesCount = 0
    UpdateAllBuffAlerts()
    assert_eq(mockState.auraQueriesCount, 0, "UpdateAllBuffAlerts must do 0 aura queries when no buffs are assigned")
end)

run_test("10. Slash Commands Toggle Outline, Tags, and Move Mode", function()
    SimpleHealUnitBuffs["Thrall"] = "Blessing of Wisdom"
    mockState.units.party1.buffs = {}
    UpdateAllBuffAlerts()

    local overlay = partyFrame1.simpleHealBuffOverlay
    assert_true(overlay:IsShown(), "Overlay shown initially")

    SlashCmdList["SIMPLEHEAL"]("buffalert tags")
    assert_eq(SimpleHealSettings.buffAlertTags, false, "buffAlertTags should be false")
    assert_true(not overlay.leftTag:IsShown(), "Left ~ tag should be hidden when tags disabled")

    SlashCmdList["SIMPLEHEAL"]("buffalert outline")
    assert_eq(SimpleHealSettings.buffAlertOutline, false, "buffAlertOutline should be false")
    assert_eq(overlay._borderColor[4], 0, "Border alpha should be 0 when outline disabled")

    SlashCmdList["SIMPLEHEAL"]("buffalert")
    assert_eq(SimpleHealSettings.buffAlertEnabled, false, "buffAlertEnabled should be false")
    assert_true(not overlay:IsShown(), "Overlay should be hidden when buffAlertEnabled is false")

    SlashCmdList["SIMPLEHEAL"]("buffalert")
    SlashCmdList["SIMPLEHEAL"]("buffalert tags")
    SlashCmdList["SIMPLEHEAL"]("buffalert outline")
    assert_eq(SimpleHealSettings.buffAlertEnabled, true, "buffAlertEnabled restored")
end)

run_test("11. Secret Values in Name Widget Text & Health Bar Do Not Crash", function()
    SimpleHealUnitBuffs["Thrall"] = "Blessing of Might"
    mockState.units.party1.buffs = {}

    local origText = partyFrame1.name:GetText()
    partyFrame1.name:SetText(create_secret_value("SecretWidgetText"))

    UpdateAllBuffAlerts()
    local overlay = partyFrame1.simpleHealBuffOverlay
    assert_true(overlay:IsShown(), "Overlay should still show when nameWidget holds a secret string")
    assert_true(overlay.leftTag:IsShown() and overlay.rightTag:IsShown(), "~ tags should anchor and show safely")

    partyFrame1.name:SetText(origText)

    local origHP = mockState.units.player.hp
    mockState.units.player.hp = create_secret_value("SecretHP")
    mainEventFrame:FireEvent("UNIT_HEALTH", "player")
    flush_timers()
    mockState.units.player.hp = origHP
end)

run_test("12. Universal togglemenu on Any Button/Modifier Without Plain Right-Click False Triggers", function()
    SimpleHealSettings.click2 = "Holy Light"
    SimpleHealSettings.ctrlalt2 = ""
    SimpleHealSettings.shift2 = "togglemenu"
    SimpleHealSettings.ctrl1 = "togglemenu"
    SimpleHealSettings.alt3 = "togglemenu"
    SimpleHealSettings.click4 = "togglemenu"
    mainEventFrame:ApplyBindings()

    mockState.lastPopupMenu = nil
    mockState.isCtrl, mockState.isAlt, mockState.isShift = false, false, false
    soloFrame:SimulateClick("RightButton", true)
    soloFrame:SimulateClick("RightButton", false)
    assert_eq(mockState.lastPopupMenu, nil, "Plain Right-Click must NOT open context menu when bound to Holy Light")

    mockState.isCtrl, mockState.isAlt, mockState.isShift = true, true, false
    soloFrame:SimulateClick("RightButton", true)
    soloFrame:SimulateClick("RightButton", false)
    assert_eq(mockState.lastPopupMenu, nil, "Unbound Ctrl+Alt+Right-Click must NOT open context menu")

    mockState.isCtrl, mockState.isAlt, mockState.isShift = false, false, true
    partyFrame1:SimulateClick("RightButton", true)
    mockState.isShift = false
    partyFrame1:SimulateClick("RightButton", false)
    assert_true(mockState.lastPopupMenu ~= nil, "Shift+RightClick (shift2) must open context menu even if Shift is released before mouse-up")
    assert_eq(mockState.lastPopupMenu.which, "PARTY", "Shift+RightClick on partyFrame1 must open PARTY menu")

    mockState.lastPopupMenu = nil
    mockState.isCtrl, mockState.isAlt, mockState.isShift = true, false, false
    soloFrame:SimulateClick("LeftButton", true)
    soloFrame:SimulateClick("LeftButton", false)
    assert_true(mockState.lastPopupMenu ~= nil, "Ctrl+LeftClick (ctrl1) must open context menu")
    assert_eq(mockState.lastPopupMenu.which, "SELF", "Ctrl+LeftClick on soloFrame must open SELF menu")

    mockState.lastPopupMenu = nil
    mockState.isCtrl, mockState.isAlt, mockState.isShift = false, true, false
    raidFrame1:SimulateClick("MiddleButton", true)
    raidFrame1:SimulateClick("MiddleButton", false)
    assert_true(mockState.lastPopupMenu ~= nil, "Alt+MiddleClick (alt3) must open context menu")
    assert_eq(mockState.lastPopupMenu.which, "RAID_PLAYER", "Alt+MiddleClick on raidFrame1 must open RAID_PLAYER menu")

    mockState.lastPopupMenu = nil
    mockState.isCtrl, mockState.isAlt, mockState.isShift = false, false, false
    soloFrame:SimulateClick("Button4", true)
    soloFrame:SimulateClick("Button4", false)
    assert_true(mockState.lastPopupMenu ~= nil, "Button4 (click4) must open context menu")

    SimpleHealSettings.ctrlalt2 = "togglemenu"
    SimpleHealSettings.shift2 = ""
    SimpleHealSettings.ctrl1 = ""
    SimpleHealSettings.alt3 = ""
    SimpleHealSettings.click4 = ""
    mainEventFrame:ApplyBindings()
end)

run_test("13. Combat Secret Aura Lock Does Not Cause False Missing-Buff Alerts", function()
    mockState.inCombat = false
    SimpleHealUnitBuffs = {}
    SimpleHealUnitBuffs["Lightbringer"] = "Blessing of Kings"
    SimpleHealUnitBuffs["Thrall"] = "Blessing of Might"
    mockState.units.player.buffs = {
        [1] = { name = "Blessing of Kings", spellId = 20217 },
    }
    mockState.units.party1.buffs = {}
    UpdateAllBuffAlerts()

    local soloOverlay = soloFrame.simpleHealBuffOverlay
    local partyOverlay = partyFrame1.simpleHealBuffOverlay
    assert_true(not soloOverlay or not soloOverlay:IsShown(), "Player is buffed out of combat -> alert hidden")
    assert_true(partyOverlay and partyOverlay:IsShown(), "Thrall is unbuffed out of combat -> alert shown")

    mockState.inCombat = true
    mockState.units.player.buffs = {
        [1] = { throwSecretError = true, isSecretAura = true },
    }
    mockState.units.party1.buffs = {
        [1] = { throwSecretError = true, isSecretAura = true },
    }
    mainEventFrame:FireEvent("UNIT_AURA", "player")
    mainEventFrame:FireEvent("UNIT_AURA", "party1")
    flush_timers()

    assert_true(not soloOverlay or not soloOverlay:IsShown(), "Player was already buffed entering combat -> alert must NOT falsely show during combat")
    assert_true(partyOverlay:IsShown(), "Thrall was unbuffed entering combat -> alert remains shown during combat")

    mockState.isCtrl, mockState.isAlt, mockState.isShift = true, true, true
    partyFrame1:SimulateClick("LeftButton", true)
    partyFrame1:SimulateClick("LeftButton", false)
    mockState.isCtrl, mockState.isAlt, mockState.isShift = false, false, false

    assert_true(not partyOverlay:IsShown(), "Casting assigned buff on Thrall during combat must immediately clear ~ and outline")

    mockState.inCombat = false
    mockState.units.player.buffs = {
        [1] = { name = "Blessing of Kings", spellId = 20217 },
    }
    mockState.units.party1.buffs = {
        [1] = { name = "Blessing of Might", spellId = 19740 },
    }
    mainEventFrame:FireEvent("PLAYER_REGEN_ENABLED")
    flush_timers()

    assert_true(not soloOverlay or not soloOverlay:IsShown(), "Player alert remains hidden after combat")
    assert_true(not partyOverlay:IsShown(), "Thrall alert remains hidden after combat")
end)

-- Helper to find a button inside SimpleHealBuffMenu by spell name
local function find_buff_menu_button(spellName)
    for _, w in ipairs(buffMenu.buttons or {}) do
        if w.spellName == spellName and w:IsShown() then
            return w
        end
    end
    return nil
end

run_test("14. Multi-Buff Toggle Menu (Divine Spirit + Power Word: Fortitude) & Dynamic Missing-Buff Cast Macro", function()
    SimpleHealUnitBuffs = {}
    mockState.units.raid1.buffs = {}

    -- Open buff selector on Jaina (raidFrame1)
    SimpleHeal_OpenBuffSelector(raidFrame1)
    assert_true(buffMenu:IsShown(), "Buff menu should open on raidFrame1")
    assert_true(buffMenu.headerText ~= nil, "Buff menu headerText should exist")
    assert_true(buffMenu.headerText:GetText():find("Left Click") ~= nil and buffMenu.headerText:GetText():find("Right Click") ~= nil,
        "Header must specify Left Click Individual and Right Click Class")

    local dsBtn = find_buff_menu_button("Divine Spirit")
    local pwfBtn = find_buff_menu_button("Power Word: Fortitude")
    assert_true(dsBtn ~= nil and pwfBtn ~= nil, "Divine Spirit and Power Word: Fortitude buttons should exist")
    assert_eq(dsBtn.isToggled, false, "Divine Spirit initially untoggled")
    assert_eq(pwfBtn.isToggled, false, "Power Word: Fortitude initially untoggled")

    -- Left-click Divine Spirit -> toggles ON and keeps menu OPEN
    dsBtn:GetScript("OnClick")(dsBtn, "LeftButton")
    assert_true(buffMenu:IsShown(), "Buff menu must stay open after toggling a buff")
    assert_eq(dsBtn.isToggled, true, "Divine Spirit should be toggled ON")

    -- Left-click Power Word: Fortitude -> toggles ON and keeps menu OPEN
    pwfBtn:GetScript("OnClick")(pwfBtn, "LeftButton")
    assert_true(buffMenu:IsShown(), "Buff menu must stay open after toggling second buff")
    assert_eq(pwfBtn.isToggled, true, "Power Word: Fortitude should be toggled ON")

    -- Both buffs are missing on Jaina: alert is shown and macro casts first missing buff (Divine Spirit)
    local raidOverlay = raidFrame1.simpleHealBuffOverlay
    assert_true(raidOverlay ~= nil and raidOverlay:IsShown(), "Alert must show when both buffs are missing")
    local macro = raidFrame1:GetAttribute("ctrl-alt-shift-macrotext1")
    assert_true(macro and macro:find("Divine Spirit") ~= nil, "Macro must cast Divine Spirit first when both are missing")

    -- Now apply Divine Spirit to Jaina (Power Word: Fortitude is STILL missing!)
    mockState.units.raid1.buffs = {
        [1] = { name = "Divine Spirit", spellId = 14752 },
    }
    mainEventFrame:FireEvent("UNIT_AURA", "raid1")
    flush_timers()

    assert_true(raidOverlay:IsShown(), "Alert must stay shown when 1 of 2 assigned buffs (Power Word: Fortitude) is still missing")
    macro = raidFrame1:GetAttribute("ctrl-alt-shift-macrotext1")
    assert_true(macro and macro:find("Power Word: Fortitude") ~= nil,
        "Macro must automatically switch to Power Word: Fortitude once Divine Spirit is active")

    -- Now apply Power Word: Fortitude as well -> both buffs present -> alert clears!
    mockState.units.raid1.buffs = {
        [1] = { name = "Divine Spirit", spellId = 14752 },
        [2] = { name = "Power Word: Fortitude", spellId = 1243 },
    }
    mainEventFrame:FireEvent("UNIT_AURA", "raid1")
    flush_timers()

    assert_true(not raidOverlay:IsShown(), "Alert must hide once both Divine Spirit and Power Word: Fortitude are present")

    -- Toggle Divine Spirit OFF via Left-Click -> leaves only Power Word: Fortitude ON
    dsBtn:GetScript("OnClick")(dsBtn, "LeftButton")
    assert_eq(dsBtn.isToggled, false, "Divine Spirit toggled OFF")
    assert_eq(pwfBtn.isToggled, true, "Power Word: Fortitude remains ON")
end)

run_test("15. Right-Click Class-Wide Buff Assignment & Escape / Click-Away Menu Dismissal", function()
    SimpleHealUnitBuffs = {}
    mockState.units.party1.buffs = {}
    mockState.units.raid1.buffs = {}
    mockState.units.raid2.buffs = {}

    -- Open buff selector on Thrall (party1, Shaman). raid2 (Nobundo) is also a Shaman; raid1 (Jaina) is a Mage.
    SimpleHeal_OpenBuffSelector(partyFrame1)
    assert_true(buffMenu:IsShown(), "Buff menu opened on Thrall (Shaman)")

    local bokBtn = find_buff_menu_button("Blessing of Kings")
    assert_true(bokBtn ~= nil, "Blessing of Kings button exists")

    -- Right-click Blessing of Kings -> assigns to ALL Shamans (Thrall AND Nobundo), but NOT Jaina (Mage)
    bokBtn:GetScript("OnClick")(bokBtn, "RightButton")
    assert_eq(bokBtn.isToggled, true, "Blessing of Kings toggled ON for Thrall")

    -- Open buff selector on Nobundo (raidFrame2, Shaman) -> should show Blessing of Kings already toggled ON!
    SimpleHeal_OpenBuffSelector(raidFrame2)
    bokBtn = find_buff_menu_button("Blessing of Kings")
    assert_eq(bokBtn.isToggled, true, "Nobundo (same class: Shaman) must show Blessing of Kings toggled ON")

    -- Open buff selector on Jaina (raidFrame1, Mage) -> should NOT have Blessing of Kings toggled ON
    SimpleHeal_OpenBuffSelector(raidFrame1)
    bokBtn = find_buff_menu_button("Blessing of Kings")
    assert_eq(bokBtn.isToggled, false, "Jaina (Mage) must NOT have Blessing of Kings toggled ON")

    -- Re-open on Nobundo (Shaman) and Right-Click Blessing of Kings to toggle it OFF for all Shamans
    SimpleHeal_OpenBuffSelector(raidFrame2)
    bokBtn = find_buff_menu_button("Blessing of Kings")
    bokBtn:GetScript("OnClick")(bokBtn, "RightButton")
    assert_eq(bokBtn.isToggled, false, "Right-clicking again toggles Blessing of Kings OFF for Nobundo")

    SimpleHeal_OpenBuffSelector(partyFrame1)
    bokBtn = find_buff_menu_button("Blessing of Kings")
    assert_eq(bokBtn.isToggled, false, "Right-clicking on Nobundo also toggled Blessing of Kings OFF for Thrall")

    -- Test closing menu by pressing Escape
    assert_true(buffMenu:IsShown(), "Buff menu is shown before Escape")
    buffMenu:GetScript("OnKeyDown")(buffMenu, "ESCAPE")
    assert_true(not buffMenu:IsShown(), "Pressing Escape must close buffMenu")

    -- Re-open and test closing menu by clicking away (GLOBAL_MOUSE_DOWN when mouse is not over buffMenu)
    SimpleHeal_OpenBuffSelector(partyFrame1)
    assert_true(buffMenu:IsShown(), "Buff menu re-opened")
    buffMenu._mouseOver = true
    mainEventFrame:FireEvent("GLOBAL_MOUSE_DOWN")
    assert_true(buffMenu:IsShown(), "Clicking inside buffMenu must NOT close it")

    buffMenu._mouseOver = false
    mainEventFrame:FireEvent("GLOBAL_MOUSE_DOWN")
    assert_true(not buffMenu:IsShown(), "Clicking outside buffMenu must close it")
end)

run_test("16. Multi-Buff Cycling by Lowest Duration & /shf buffcycle Command", function()
    SimpleHealUnitBuffs = {
        Jaina = { "Divine Spirit", "Power Word: Fortitude" }
    }
    -- Out of combat: both present, Fortitude has lower expiration time (50s left) vs Divine Spirit (1000s left)
    mockState.units.raid1.buffs = {
        [1] = { name = "Divine Spirit", spellId = 14752, duration = 1800, expirationTime = 1000 },
        [2] = { name = "Power Word: Fortitude", spellId = 1243, duration = 1800, expirationTime = 50 },
    }
    mainEventFrame:FireEvent("UNIT_AURA", "raid1")
    flush_timers()

    local macro = raidFrame1:GetAttribute("ctrl-alt-shift-macrotext1")
    assert_true(macro ~= nil, "Macro must exist for multi-buff player")
    assert_true(macro:find("Power Word: Fortitude", 1, true) ~= nil,
        "Lowest duration buff (Fortitude) must be prioritized out of combat")
    assert_true(macro:find("/castsequence [combat", 1, true) ~= nil,
        "Macro must include combat /castsequence")

    -- Test /shf buffcycle slash command
    SlashCmdList["SIMPLEHEAL"]("buffcycle 10")
    assert_eq(SimpleHealSettings.buffCycleReset, 10, "buffCycleReset setting updated to 10")
    local updatedMacro = raidFrame1:GetAttribute("ctrl-alt-shift-macrotext1")
    assert_true(updatedMacro:find("reset=10.") ~= nil, "Macro sequence reset seconds updated to 10")
end)

run_test("17. Out-of-Zone Target Macro Binding, CompactUnitFrame_SetUnit Sync & Secret Guard", function()
    local wantParty1 = "/target [@party1,exists][@mouseover,exists]\n/stopmacro [@party1,exists][@mouseover,exists]\n/target party1"
    assert_eq(partyFrame1:GetAttribute("ctrl-alt-type1"), "macro", "ctrl-alt-type1 uses macro")
    assert_eq(partyFrame1:GetAttribute("ctrl-alt-macrotext1"), wantParty1, "partyFrame1 target macro resolves party1")
    assert_eq(partyFrame1:GetAttribute("alt-ctrl-macrotext1"), wantParty1, "alt-ctrl-macrotext1 resolves party1")

    local wantPlayer = "/target [@player,exists][@mouseover,exists]\n/stopmacro [@player,exists][@mouseover,exists]\n/target player"
    assert_eq(soloFrame:GetAttribute("ctrl-alt-macrotext1"), wantPlayer, "soloFrame target macro resolves player")

    -- Frame set up before unit assignment falls back to @mouseover, then updates on SetUnit
    local latePartyFrame = CreateFrame("Button", "CompactPartyFrameMember4", UIParent, "SecureUnitButtonTemplate")
    CompactUnitFrame_SetUpFrame(latePartyFrame)
    assert_eq(latePartyFrame:GetAttribute("ctrl-alt-macrotext1"), "/target [@mouseover,exists]",
        "Unassigned frame falls back cleanly to mouseover")

    CompactUnitFrame_SetUnit(latePartyFrame, "party2")
    local wantParty2 = "/target [@party2,exists][@mouseover,exists]\n/stopmacro [@party2,exists][@mouseover,exists]\n/target party2"
    assert_eq(latePartyFrame:GetAttribute("ctrl-alt-macrotext1"), wantParty2,
        "CompactUnitFrame_SetUnit refreshes target macro to newly assigned unit")

    -- Nameplate updates should be ignored by CompactUnitFrame_SetUnit
    local plateFrame = CreateFrame("Button", "NamePlate1UnitFrame", UIParent, "SecureUnitButtonTemplate")
    CompactUnitFrame_SetUpFrame(plateFrame)
    plateFrame._simpleHealBoundUnit = nil
    CompactUnitFrame_SetUnit(plateFrame, "nameplate1")
    assert_eq(plateFrame._simpleHealBoundUnit, nil, "Nameplates must not trigger CompactUnitFrame_SetUnit re-bind")
    assert_eq(plateFrame:GetAttribute("ctrl-alt-macrotext1"), "/target [@mouseover,exists]",
        "Nameplate target macro must remain unchanged on SetUnit")

    -- Secret unit value on frame must not crash BindFrame / GetTargetMacroForUnitFrame
    local secretUnitFrame = CreateFrame("Button", "CompactPartyFrameMember5", UIParent, "SecureUnitButtonTemplate")
    secretUnitFrame:SetAttribute("unit", create_secret_value("unit_token"))
    CompactUnitFrame_SetUpFrame(secretUnitFrame)
    assert_eq(secretUnitFrame:GetAttribute("ctrl-alt-macrotext1"), "/target [@mouseover,exists]",
        "Secret unit token safely falls back to @mouseover")
end)

test_print("=================================================================")
test_print(string.format("Results: %d passed, %d failed", passed, failed))
test_print("=================================================================")

if failed > 0 then
    os.exit(1)
end
