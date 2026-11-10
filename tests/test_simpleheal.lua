#!/usr/bin/env luajit
-- =========================================================================
-- SimpleHeal Headless Test Suite for World of Warcraft: Forever
-- =========================================================================
-- Runs outside the game via LuaJIT in ~5ms.
-- NOT listed in SimpleHeal.toc -> 0 KB memory and 0% CPU impact in-game.
--
-- Usage:
--   luajit tests/test_simpleheal.lua
-- =========================================================================

local passed = 0
local failed = 0
local currentTestName = ""
local test_print = print

local function assert_true(cond, msg)
    if not cond then
        error(string.format("[%s] Assertion failed: %s", currentTestName, msg or "expected true"), 2)
    end
end

local function assert_eq(actual, expected, msg)
    if actual ~= expected then
        error(string.format(
            "[%s] %s: expected %s, got %s",
            currentTestName,
            msg or "Values not equal",
            tostring(expected),
            tostring(actual)
        ), 2)
    end
end

local function run_test(name, fn)
    currentTestName = name
    local ok, err = pcall(fn)
    if ok then
        passed = passed + 1
        test_print(string.format("  [PASS] %s", name))
    else
        failed = failed + 1
        test_print(string.format("  [FAIL] %s\n         %s", name, tostring(err)))
    end
end

-- =========================================================================
-- Mock WoW Engine & FrameXML Environment (including WoW 12.0 Secret Values)
-- =========================================================================

local secretRegistry = setmetatable({}, { __mode = "k" })

-- Creates a simulated WoW 12.0 "secret value" that throws if indexed,
-- compared, or passed to string functions.
local function create_secret_value(label)
    local proxy = newproxy(true)
    local mt = getmetatable(proxy)
    mt.__index = function()
        error("attempt to index local 'rawName' (a secret string value, while execution tainted by 'SimpleHeal')", 2)
    end
    mt.__eq = function()
        error("attempt to compare a secret value (execution tainted by 'SimpleHeal')", 2)
    end
    mt.__lt = function()
        error("attempt to compare a secret value (execution tainted by 'SimpleHeal')", 2)
    end
    mt.__tostring = function()
        return "<secret:" .. (label or "value") .. ">"
    end
    secretRegistry[proxy] = true
    return proxy
end

-- Wrap string.match so passing a secret value throws the exact WoW C error
local real_string_match = string.match
string.match = function(s, pattern, init)
    if secretRegistry[s] then
        error("attempt to perform string conversion on a secret string value (execution tainted by 'SimpleHeal')", 2)
    end
    return real_string_match(s, pattern, init)
end

_G.issecretvalue = function(val)
    return secretRegistry[val] == true
end

-- Mock State
local mockState = {
    inCombat = false,
    inGroup = true,
    inRaid = false,
    isCtrl = false,
    isAlt = false,
    isShift = false,
    playerClass = { "Paladin", "PALADIN" },
    units = {
        player = {
            exists = true,
            name = "Lightbringer",
            server = nil,
            hp = 4500,
            maxHp = 5000,
            power = 3200,
            maxPower = 4000,
            isPlayer = true,
            inParty = true,
            inRaid = false,
            buffs = {},
        },
        pet = {
            exists = false,
            name = "Charger",
            hp = 1000,
            maxHp = 1000,
            isPlayer = false,
            buffs = {},
        },
        party1 = {
            exists = true,
            name = "Thrall-Forever",
            server = "Forever",
            hp = 6000,
            maxHp = 6000,
            isPlayer = true,
            inParty = true,
            inRaid = false,
            buffs = {},
        },
        raid1 = {
            exists = true,
            name = "Jaina",
            hp = 3500,
            maxHp = 3500,
            isPlayer = true,
            inParty = false,
            inRaid = true,
            buffs = {},
        },
    },
    spellIDs = {
        ["Blessing of Might"] = 19740,
        ["Greater Blessing of Might"] = 25782,
        ["Blessing of Wisdom"] = 19742,
        ["Greater Blessing of Wisdom"] = 25894,
        ["Blessing of Kings"] = 20217,
        ["Greater Blessing of Kings"] = 25898,
        ["Flash of Light"] = 19750,
        ["Holy Light"] = 635,
    },
    spellbook = {
        "Flash of Light",
        "Holy Light",
        "Holy Shock",
        "Blessing of Might",
        "Greater Blessing of Might",
        "Blessing of Wisdom",
        "Blessing of Kings",
        "Blessing of Protection",
        "Cleanse",
    },
    auraQueriesCount = 0,
    lastPopupMenu = nil,
    pendingTimers = {},
    secureHooks = {},
    cvars = {},
}

local function flush_timers()
    local q = mockState.pendingTimers
    mockState.pendingTimers = {}
    for _, cb in ipairs(q) do
        cb()
    end
end

-- Mock Frame System
local function CreateMockFontString(parent)
    local fs = {
        _parent = parent,
        _shown = true,
        _text = "",
        _points = {},
    }
    function fs:SetPoint(...) table.insert(self._points, { ... }) end
    function fs:ClearAllPoints() self._points = {} end
    function fs:SetText(t) self._text = t end
    function fs:GetText() return self._text end
    function fs:SetTextColor() end
    function fs:SetShadowColor() end
    function fs:SetShadowOffset() end
    function fs:Show() self._shown = true end
    function fs:Hide() self._shown = false end
    function fs:IsShown()
        if self._parent and self._parent.IsShown and not self._parent:IsShown() then
            return false
        end
        return self._shown
    end
    return fs
end

local function CreateMockTexture(parent)
    local tex = { _parent = parent, _shown = true }
    function tex:SetAllPoints() end
    function tex:SetColorTexture() end
    function tex:Show() self._shown = true end
    function tex:Hide() self._shown = false end
    function tex:IsShown() return self._shown end
    return tex
end

function _G.CreateFrame(frameType, name, parent, template)
    local f = {
        _type = frameType,
        _name = name,
        _parent = parent,
        _template = template,
        _shown = true,
        _attributes = {},
        _scripts = {},
        _hooks = {},
        _events = {},
        _minVal = 0,
        _maxVal = 100,
        _curVal = 100,
        _level = 1,
        TitleBg = {},
        InsetBg = {},
    }
    function f:SetSize() end
    function f:SetHeight() end
    function f:SetWidth() end
    function f:SetPoint() end
    function f:SetAllPoints() end
    function f:ClearAllPoints() end
    function f:SetFrameStrata() end
    function f:SetFrameLevel(lvl) self._level = lvl end
    function f:GetFrameLevel() return self._level end
    function f:SetClampedToScreen() end
    function f:SetMovable() end
    function f:EnableMouse() end
    function f:RegisterForDrag() end
    function f:RegisterForClicks() end
    function f:StartMoving() end
    function f:StopMovingOrSizing() end
    function f:SetBackdrop() end
    function f:SetBackdropBorderColor(r, g, b, a)
        self._borderColor = { r, g, b, a }
    end
    function f:SetScrollChild() end
    function f:SetStatusBarTexture() end
    function f:SetStatusBarColor() end
    function f:SetMinMaxValues(minV, maxV) self._minVal = minV; self._maxVal = maxV end
    function f:GetMinMaxValues() return self._minVal, self._maxVal end
    function f:SetValue(v) self._curVal = v end
    function f:GetValue() return self._curVal end
    function f:SetText(t) self._text = t end
    function f:GetText() return self._text end
    function f:GetName() return self._name end
    function f:GetEffectiveScale() return 1.0 end
    function f:Show() self._shown = true end
    function f:Hide() self._shown = false end
    function f:IsShown() return self._shown end
    function f:SetAttribute(k, v) self._attributes[k] = v end
    function f:GetAttribute(k) return self._attributes[k] end
    function f:RegisterEvent(ev) self._events[ev] = true end
    function f:SetScript(scriptName, fn) self._scripts[scriptName] = fn end
    function f:GetScript(scriptName) return self._scripts[scriptName] end
    function f:HookScript(scriptName, fn)
        self._hooks[scriptName] = self._hooks[scriptName] or {}
        table.insert(self._hooks[scriptName], fn)
    end
    function f:SimulateClick(button, down)
        if self._scripts["OnClick"] then
            self._scripts["OnClick"](self, button, down)
        end
        if self._hooks["PostClick"] then
            for _, hook in ipairs(self._hooks["PostClick"]) do
                hook(self, button, down)
            end
        end
    end
    function f:FireEvent(event, ...)
        if self._scripts["OnEvent"] then
            self._scripts["OnEvent"](self, event, ...)
        end
    end
    function f:CreateFontString() return CreateMockFontString(self) end
    function f:CreateTexture() return CreateMockTexture(self) end

    if name then
        _G[name] = f
    end
    return f
end

_G.UIParent = CreateFrame("Frame", "UIParent")
_G.SlashCmdList = {}

-- Mock WoW Global Functions
_G.print = function() end -- silence addon chat prints during test runs
_G.InCombatLockdown = function() return mockState.inCombat end
_G.IsInGroup = function() return mockState.inGroup end
_G.IsInRaid = function() return mockState.inRaid end
_G.IsControlKeyDown = function() return mockState.isCtrl end
_G.IsAltKeyDown = function() return mockState.isAlt end
_G.IsShiftKeyDown = function() return mockState.isShift end
_G.GetCursorPosition = function() return 500, 500 end
_G.SetCVar = function(k, v) mockState.cvars[k] = v end
_G.hooksecurefunc = function(name, fn) mockState.secureHooks[name] = fn end

_G.UnitClass = function(u)
    return mockState.playerClass[1], mockState.playerClass[2]
end

_G.UnitExists = function(u)
    return mockState.units[u] ~= nil and mockState.units[u].exists == true
end

_G.UnitIsDeadOrGhost = function(u)
    return mockState.units[u] and mockState.units[u].dead == true or false
end

_G.UnitIsConnected = function(u)
    if not mockState.units[u] then return false end
    if mockState.units[u].connected == false then return false end
    return true
end

_G.UnitIsUnit = function(u1, u2)
    return u1 == u2
end

_G.UnitInRaid = function(u)
    return mockState.units[u] and mockState.units[u].inRaid or false
end

_G.UnitInParty = function(u)
    return mockState.units[u] and mockState.units[u].inParty or false
end

_G.UnitIsPlayer = function(u)
    return mockState.units[u] and mockState.units[u].isPlayer or false
end

_G.UnitName = function(u)
    local data = mockState.units[u]
    if not data then return nil end
    return data.name, data.server
end

_G.UnitHealth = function(u)
    return mockState.units[u] and mockState.units[u].hp or 0
end

_G.UnitHealthMax = function(u)
    return mockState.units[u] and mockState.units[u].maxHp or 100
end

_G.UnitPower = function(u)
    return mockState.units[u] and mockState.units[u].power or 0
end

_G.UnitPowerMax = function(u)
    return mockState.units[u] and mockState.units[u].maxPower or 100
end

_G.UnitPopup_OpenMenu = function(which, contextData, owner)
    -- Replicate Blizzard's exact UnitPopupShared.lua:110 check:
    -- 'which' MUST be a string (concatenating it fails if a table is passed first!)
    local _ = "MENU_" .. which
    assert_true(type(contextData) == "table", "contextData must be a table")
    mockState.lastPopupMenu = {
        which = which,
        contextData = contextData,
        owner = owner,
    }
end

_G.C_Timer = {
    After = function(delay, cb)
        table.insert(mockState.pendingTimers, cb)
    end,
    NewTicker = function(interval, cb)
        mockState.tickerCallback = cb
        return { Cancel = function() end }
    end,
}

_G.C_Spell = {
    GetSpellInfo = function(spellName)
        local id = mockState.spellIDs[spellName]
        if id then
            return { name = spellName, spellID = id }
        end
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
        -- Enforce that GetBuffDataByIndex is not called with "HELPFUL" filter
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

-- Grab main event frame created on line 2
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

    -- Verify *type2 wildcard is NOT set on soloFrame or petFrame
    assert_eq(soloFrame:GetAttribute("*type2"), nil, "soloFrame *type2 wildcard must be nil")
    assert_eq(petFrame:GetAttribute("*type2"), nil, "petFrame *type2 wildcard must be nil")

    -- Verify plain right-click is bound to Holy Light macro
    assert_eq(soloFrame:GetAttribute("type2"), "macro", "type2 should be macro")
    assert_true(soloFrame:GetAttribute("macrotext2"):find("Holy Light") ~= nil, "macrotext2 should cast Holy Light")

    -- Simulate plain Right-Click release on soloFrame and partyFrame1
    soloFrame:SimulateClick("RightButton", false)
    partyFrame1:SimulateClick("RightButton", false)
    assert_eq(mockState.lastPopupMenu, nil, "Plain right-click must NOT open menu when bound to Holy Light")
end)

run_test("3. Ctrl+Alt+Right-Click Opens Context Menu with Correct Signature", function()
    mockState.lastPopupMenu = nil
    mockState.isCtrl = true
    mockState.isAlt = true
    mockState.isShift = false

    -- Mouse down should be ignored (no double-firing)
    soloFrame:SimulateClick("RightButton", true)
    assert_eq(mockState.lastPopupMenu, nil, "Mouse down should not open context menu")

    -- Mouse up on soloFrame -> SELF
    soloFrame:SimulateClick("RightButton", false)
    assert_true(mockState.lastPopupMenu ~= nil, "Ctrl+Alt+RightClick should open menu on soloFrame")
    assert_eq(mockState.lastPopupMenu.which, "SELF", "soloFrame menu type must be SELF")
    assert_eq(mockState.lastPopupMenu.contextData.unit, "player", "contextData.unit must be player")

    -- Mouse up on partyFrame1 -> PARTY
    mockState.lastPopupMenu = nil
    partyFrame1:SimulateClick("RightButton", false)
    assert_true(mockState.lastPopupMenu ~= nil, "Ctrl+Alt+RightClick should open menu on partyFrame1")
    assert_eq(mockState.lastPopupMenu.which, "PARTY", "partyFrame1 menu type must be PARTY")
    assert_eq(mockState.lastPopupMenu.contextData.unit, "party1", "contextData.unit must be party1")

    -- Mouse up on raidFrame1 -> RAID_PLAYER
    mockState.lastPopupMenu = nil
    raidFrame1:SimulateClick("RightButton", false)
    assert_true(mockState.lastPopupMenu ~= nil, "Ctrl+Alt+RightClick should open menu on raidFrame1")
    assert_eq(mockState.lastPopupMenu.which, "RAID_PLAYER", "raidFrame1 menu type must be RAID_PLAYER")

    mockState.isCtrl = false
    mockState.isAlt = false
end)

run_test("4. Secret String Taint During Zoning Does Not Crash", function()
    -- Simulate UnitName returning a WoW 12.0 secret string during zone transition
    local origName = mockState.units.party1.name
    mockState.units.party1.name = create_secret_value("ThrallSecret")

    -- Firing zone-in and aura updates must not throw any secret string error
    mainEventFrame:FireEvent("PLAYER_ENTERING_WORLD")
    flush_timers()
    UpdateAllBuffAlerts()

    -- Restore normal name
    mockState.units.party1.name = origName
end)

run_test("5. Missing Buff Alert & Secret Aura at Index 1 Does Not Block Buff Detection", function()
    -- Open buff selector on partyFrame1 (Thrall-Forever -> cleanName "Thrall")
    SimpleHeal_OpenBuffSelector(partyFrame1)
    assert_true(buffMenu:IsShown(), "Buff selector menu should open")

    -- Assign "Blessing of Might" to Thrall
    SimpleHealUnitBuffs["Thrall"] = "Blessing of Might"
    mockState.units.party1.buffs = {}
    UpdateAllBuffAlerts()

    local overlay = partyFrame1.simpleHealBuffOverlay
    assert_true(overlay ~= nil and overlay:IsShown(), "Alert overlay should show when buff is missing")
    assert_true(overlay.leftTag:IsShown() and overlay.rightTag:IsShown(), "~ tags should show when buff is missing")

    -- Now put a SECRET AURA at index 1 that throws, and "Blessing of Might" at index 2!
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

    -- Index 1 has a buff whose name is a secret value, Index 2 has Greater Blessing of Might
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

    -- Verify both ctrl-alt-shift and alt-ctrl-shift attributes are set for WoW SecureTemplates
    local macro1 = soloFrame:GetAttribute("ctrl-alt-shift-macrotext1")
    local macro2 = soloFrame:GetAttribute("alt-ctrl-shift-macrotext1")
    assert_true(macro1 and macro1:find("Blessing of Kings") ~= nil, "ctrl-alt-shift-macrotext1 must contain Blessing of Kings")
    assert_eq(macro1, macro2, "alt-ctrl-shift-macrotext1 must match ctrl-alt-shift-macrotext1")

    local soloOverlay = soloFrame.simpleHealBuffOverlay
    assert_true(soloOverlay ~= nil and soloOverlay:IsShown(), "Solo overlay should show when player lacks Blessing of Kings")

    -- Add Blessing of Kings (spellId 20217) to player buffs
    mockState.units.player.buffs = {
        [1] = { name = "Blessing of Kings", spellId = 20217 },
    }
    UpdateAllBuffAlerts()
    assert_true(not soloOverlay:IsShown(), "Solo overlay should hide when player gains Blessing of Kings")
end)

run_test("8. Performance: Combat Health/Mana Events Do Not Trigger Aura Scans", function()
    flush_timers()
    mockState.auraQueriesCount = 0

    -- Simulate 100 rapid health & mana events during combat
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

    -- Toggle tags off
    SlashCmdList["SIMPLEHEAL"]("buffalert tags")
    assert_eq(SimpleHealSettings.buffAlertTags, false, "buffAlertTags should be false")
    assert_true(not overlay.leftTag:IsShown(), "Left ~ tag should be hidden when tags disabled")

    -- Toggle outline off
    SlashCmdList["SIMPLEHEAL"]("buffalert outline")
    assert_eq(SimpleHealSettings.buffAlertOutline, false, "buffAlertOutline should be false")
    assert_eq(overlay._borderColor[4], 0, "Border alpha should be 0 when outline disabled")

    -- Toggle entire alert system off
    SlashCmdList["SIMPLEHEAL"]("buffalert")
    assert_eq(SimpleHealSettings.buffAlertEnabled, false, "buffAlertEnabled should be false")
    assert_true(not overlay:IsShown(), "Overlay should be hidden when buffAlertEnabled is false")

    -- Re-enable
    SlashCmdList["SIMPLEHEAL"]("buffalert")
    SlashCmdList["SIMPLEHEAL"]("buffalert tags")
    SlashCmdList["SIMPLEHEAL"]("buffalert outline")
    assert_eq(SimpleHealSettings.buffAlertEnabled, true, "buffAlertEnabled restored")
end)

run_test("11. Secret Values in Name Widget Text & Health Bar Do Not Crash", function()
    SimpleHealUnitBuffs["Thrall"] = "Blessing of Might"
    mockState.units.party1.buffs = {}

    -- Set partyFrame1's name FontString text to a WoW 12.0 secret string
    local origText = partyFrame1.name:GetText()
    partyFrame1.name:SetText(create_secret_value("SecretWidgetText"))

    -- Must not throw "attempt to compare a secret value" when anchoring ~ tags
    UpdateAllBuffAlerts()
    local overlay = partyFrame1.simpleHealBuffOverlay
    assert_true(overlay:IsShown(), "Overlay should still show when nameWidget holds a secret string")
    assert_true(overlay.leftTag:IsShown() and overlay.rightTag:IsShown(), "~ tags should anchor and show safely")

    partyFrame1.name:SetText(origText)

    -- Simulate secret numbers in player health bar during restricted encounter
    local origHP = mockState.units.player.hp
    mockState.units.player.hp = create_secret_value("SecretHP")
    mainEventFrame:FireEvent("UNIT_HEALTH", "player")
    flush_timers()
    mockState.units.player.hp = origHP
end)

run_test("12. Universal togglemenu on Any Button/Modifier Without Plain Right-Click False Triggers", function()
    -- Assign togglemenu to Shift+RightClick (shift2), Ctrl+LeftClick (ctrl1), Alt+MiddleClick (alt3), and Button4 (click4)
    SimpleHealSettings.click2 = "Holy Light"
    SimpleHealSettings.ctrlalt2 = ""
    SimpleHealSettings.shift2 = "togglemenu"
    SimpleHealSettings.ctrl1 = "togglemenu"
    SimpleHealSettings.alt3 = "togglemenu"
    SimpleHealSettings.click4 = "togglemenu"
    mainEventFrame:ApplyBindings()

    -- 1. Plain Right-Click (down + up) must NOT open menu when bound to Holy Light
    mockState.lastPopupMenu = nil
    mockState.isCtrl, mockState.isAlt, mockState.isShift = false, false, false
    soloFrame:SimulateClick("RightButton", true)
    soloFrame:SimulateClick("RightButton", false)
    assert_eq(mockState.lastPopupMenu, nil, "Plain Right-Click must NOT open context menu when bound to Holy Light")

    -- 2. Unbound Ctrl+Alt+Right-Click must NOT open menu when ctrlalt2 is cleared
    mockState.isCtrl, mockState.isAlt, mockState.isShift = true, true, false
    soloFrame:SimulateClick("RightButton", true)
    soloFrame:SimulateClick("RightButton", false)
    assert_eq(mockState.lastPopupMenu, nil, "Unbound Ctrl+Alt+Right-Click must NOT open context menu")

    -- 3. Shift+Right-Click (shift2) opens menu, even if Shift is released before mouse-up!
    mockState.isCtrl, mockState.isAlt, mockState.isShift = false, false, true
    partyFrame1:SimulateClick("RightButton", true)
    mockState.isShift = false -- Player releases Shift key slightly before mouse button release
    partyFrame1:SimulateClick("RightButton", false)
    assert_true(mockState.lastPopupMenu ~= nil, "Shift+RightClick (shift2) must open context menu even if Shift is released before mouse-up")
    assert_eq(mockState.lastPopupMenu.which, "PARTY", "Shift+RightClick on partyFrame1 must open PARTY menu")

    -- 4. Ctrl+Left-Click (ctrl1) opens menu
    mockState.lastPopupMenu = nil
    mockState.isCtrl, mockState.isAlt, mockState.isShift = true, false, false
    soloFrame:SimulateClick("LeftButton", true)
    soloFrame:SimulateClick("LeftButton", false)
    assert_true(mockState.lastPopupMenu ~= nil, "Ctrl+LeftClick (ctrl1) must open context menu")
    assert_eq(mockState.lastPopupMenu.which, "SELF", "Ctrl+LeftClick on soloFrame must open SELF menu")

    -- 5. Alt+Middle-Click (alt3) opens menu
    mockState.lastPopupMenu = nil
    mockState.isCtrl, mockState.isAlt, mockState.isShift = false, true, false
    raidFrame1:SimulateClick("MiddleButton", true)
    raidFrame1:SimulateClick("MiddleButton", false)
    assert_true(mockState.lastPopupMenu ~= nil, "Alt+MiddleClick (alt3) must open context menu")
    assert_eq(mockState.lastPopupMenu.which, "RAID_PLAYER", "Alt+MiddleClick on raidFrame1 must open RAID_PLAYER menu")

    -- 6. Plain Button4 (click4) opens menu
    mockState.lastPopupMenu = nil
    mockState.isCtrl, mockState.isAlt, mockState.isShift = false, false, false
    soloFrame:SimulateClick("Button4", true)
    soloFrame:SimulateClick("Button4", false)
    assert_true(mockState.lastPopupMenu ~= nil, "Button4 (click4) must open context menu")

    -- Restore defaults
    SimpleHealSettings.ctrlalt2 = "togglemenu"
    SimpleHealSettings.shift2 = ""
    SimpleHealSettings.ctrl1 = ""
    SimpleHealSettings.alt3 = ""
    SimpleHealSettings.click4 = ""
    mainEventFrame:ApplyBindings()
end)

run_test("13. Combat Secret Aura Lock Does Not Cause False Missing-Buff Alerts", function()
    -- 1. Out of combat: Player has Blessing of Kings, Thrall (party1) is missing Blessing of Might
    mockState.inCombat = false
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

    -- 2. Enter combat: WoW 12.0 restricts all aura access as secret during combat
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

    -- 3. Player casts stored buff (Ctrl+Alt+Shift+LeftClick) on Thrall during combat
    mockState.isCtrl, mockState.isAlt, mockState.isShift = true, true, true
    partyFrame1:SimulateClick("LeftButton", true)
    partyFrame1:SimulateClick("LeftButton", false)
    mockState.isCtrl, mockState.isAlt, mockState.isShift = false, false, false

    assert_true(not partyOverlay:IsShown(), "Casting assigned buff on Thrall during combat must immediately clear ~ and outline")

    -- 4. Combat ends (PLAYER_REGEN_ENABLED): real auras become readable again
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

test_print("=================================================================")
test_print(string.format("Results: %d passed, %d failed", passed, failed))
test_print("=================================================================")

if failed > 0 then
    os.exit(1)
end
