-- wow_stubs.lua: Glass Quest Tracker's part of the WoW: Forever mock for Lua
-- 5.1 unit tests. dofile("tests/wow_stubs.lua") FIRST in every test; drive it
-- via the WoW table.
--
-- The mechanics are WowTestKit's core (tests/kit.lua loads it at the commit
-- and build tests/kit.pin names; its README is the reference): strict
-- globals, secrets, CreateFrame and the widget method recorder
-- (WoW.methodsCalled, checked by Kit.checkMethods), events checked against
-- the build, OnShow / OnHide, OnUpdate ticks, timers, hooksecurefunc, print
-- with its stray-"|" check. This file adds only what the addon and its tests
-- use beyond them: Blizzard's objective tracker, with the UI contract's
-- record of what addon code does to it, and the client APIs the addon reads
-- (each verified in the dump).
dofile("tests/kit.lua")
local Methods = WoW.Methods

--------------------------------------------------------------------------------
-- Widget methods the core doesn't have, each read by the addon, its probe or
-- a test (all are widget methods on the build; Kit.checkMethods checks the
-- pairs called)
--------------------------------------------------------------------------------

-- A texture's source: Compat's Blank keeps it to give back on Unblank.
function Methods.GetAtlas(t) return t._atlas end
function Methods.GetTexture(t) return t._file end
-- Compat's Tint keeps the colour and desaturation it replaces (the core's
-- SetVertexColor and SetDesaturated write these fields).
function Methods.GetVertexColor(t)
    local c = t._vertex or { 1, 1, 1, 1 }
    return c[1], c[2], c[3], c[4] or 1
end
function Methods.IsDesaturated(t) return t._desaturated == true end
-- TrackerProbe's frames line reads these.
function Methods.GetNumPoints(w) return #w._points end
function Methods.SetScale(w, s) w._scale = s end
function Methods.GetScale(w) return w._scale or 1 end
-- WowTestKit #78: the core has no GetSize; TrackerProbe's frames line reads it.
function Methods.GetSize(w) return w._width, w._height end

--------------------------------------------------------------------------------
-- Blizzard's objective tracker (Mainline, as Forever runs it: wow-ui-source
-- branch forever, measured on 70374)
--------------------------------------------------------------------------------

-- A Blizzard object is a core widget whose metatable also records what addon
-- code (not the simulated Blizzard side, WoW.inBlizzard) does to it:
-- - every method called, by name (WoW.blizzCalls): test_contract checks each
--   against the C-only allowlist;
-- - a NEW key written (WoW.fieldWrites); a changed EXISTING key is caught by
--   WoW.fieldChanges() against the snapshot. Keys starting with "_" are the
--   stub's own bookkeeping.
-- The methods themselves are the core's, looked up on the type's own method
-- table, so the call is recorded for Kit.checkMethods as on any widget.
local blizzMTs = {}
local function blizzMT(wtype, methods)
    if blizzMTs[wtype] then return blizzMTs[wtype] end
    local mt = {
        __index = function(_, k)
            local fn = methods[k]
            if type(fn) ~= "function" then return fn end
            return function(self, ...)
                if type(self) == "table" and rawget(self, "_blizz") and not WoW.inBlizzard then
                    WoW.blizzCalls[k] = (WoW.blizzCalls[k] or 0) + 1
                end
                return fn(self, ...)
            end
        end,
        __newindex = function(t, k, v)
            if type(k) == "string" and k:sub(1, 1) == "_" then return rawset(t, k, v) end
            if not WoW.inBlizzard then table.insert(WoW.fieldWrites, tostring(k)) end
            rawset(t, k, v)
        end,
    }
    blizzMTs[wtype] = mt
    return mt
end

local function blizz(wtype, parent, name)
    local w = WoW.newWidget(wtype, parent, name)
    setmetatable(w, blizzMT(wtype, getmetatable(w).__index))
    rawset(w, "_blizz", true)
    table.insert(WoW.blizz, w)
    return w
end

local function blizzTexture(parent, atlas)
    local t = blizz("Texture", parent)
    t._atlas = atlas
    return t
end

-- A button's state textures are the core's fields (Get<State>Texture).
local function blizzButton(parent, normal, pushed, highlight, disabled)
    local b = blizz("Button", parent)
    b._normalTexture = blizzTexture(b, normal)
    b._pushedTexture = blizzTexture(b, pushed)
    b._highlightTexture = blizzTexture(b, highlight)
    if disabled then b._disabledTexture = blizzTexture(b, disabled) end
    return b
end

-- Blizzard's side writes its own fields through here: the snapshot follows.
function WoW.bset(t, k, v)
    rawset(t, k, v)
    if WoW.snap[t] then WoW.snap[t][k] = v end
end

-- A Lua method on a Blizzard object (a mixin copy): calling one from addon
-- code is recorded (WoW.luaCalls) as well as run.
local function luaMethod(obj, name, fn)
    rawset(obj, name, function(self, ...)
        if not WoW.inBlizzard then table.insert(WoW.luaCalls, name) end
        local was = WoW.inBlizzard
        WoW.inBlizzard = true
        local r = fn(self, ...)
        WoW.inBlizzard = was
        return r
    end)
end

-- A hook is addon code, even when Blizzard's side made the call: its calls on
-- Blizzard's objects count for the UI contract. The core's hooksecurefunc
-- does the hooking (and counts each hook in WoW.hooked); this only marks the
-- hook's body as the addon's.
local coreHook = hooksecurefunc
local function asAddon(fn)
    return function(...)
        local was = WoW.inBlizzard
        WoW.inBlizzard = false
        fn(...)
        WoW.inBlizzard = was
    end
end
function hooksecurefunc(t, name, fn)
    if type(t) == "string" then return coreHook(t, asAddon(name)) end
    return coreHook(t, name, asAddon(fn))
end

local function makeHeader(parent, bgAtlas, collapse, expand, withAnim)
    local h = blizz("Frame", parent)
    h.Background = blizzTexture(h, bgAtlas)
    h.Text = blizz("FontString", h)
    h.MinimizeButton = blizzButton(h, collapse, collapse .. "-pressed", "ui-questtrackerbutton-red-highlight")
    if withAnim then
        h.Shine = blizzTexture(h, "UI-QuestTracker-OBJFX-Shine")
        h.Glow = blizzTexture(h, "UI-QuestTracker-OBJFX-BarGlow")
        h.Shine._alpha, h.Glow._alpha = 0, 0
        -- The header's AnimationGroup (Blizzard_ObjectiveTrackerModule.xml:63,
        -- forever 70959) that animates those with setToFinalAlpha; TrackerProbe
        -- reports whether it's there.
        h.AddAnim = blizz("AnimationGroup", h)
    end
    luaMethod(h, "SetCollapsed", function(self, collapsed)
        local n, p = self.MinimizeButton:GetNormalTexture(), self.MinimizeButton:GetPushedTexture()
        n:SetAtlas(collapsed and expand or collapse)
        p:SetAtlas((collapsed and expand or collapse) .. "-pressed")
    end)
    return h
end

WoW.MODULE_NAMES = { "ScenarioObjectiveTracker", "UIWidgetObjectiveTracker", "CampaignQuestObjectiveTracker",
    "QuestObjectiveTracker", "AdventureObjectiveTracker", "AchievementObjectiveTracker",
    "MonthlyActivitiesObjectiveTracker", "InitiativeTasksObjectiveTracker", "ProfessionsRecipeTracker",
    "BonusObjectiveTracker", "WorldQuestObjectiveTracker" }

-- A module in the container's list. Named, as the client's are; with no
-- global of its name, it's one a later build added. Hidden until a layout
-- shows it (WoW.setShown: the core's visibility, without a method call).
function WoW.addModule(name)
    local t = ObjectiveTrackerFrame
    local m
    WoW.asBlizzard(function()
        m = blizz("Frame", t, name)
        WoW.setShown(m, false)
        m.Header = makeHeader(m, "UI-QuestTracker-Secondary-Objective-Header",
            "ui-questtrackerbutton-secondary-collapse", "ui-questtrackerbutton-secondary-expand", true)
        m.usedBlocks = {}
        luaMethod(m, "EndLayout", function() end)
        table.insert(t.modules, m)
        WoW.snapshot()
    end)
    return m
end

local function makeTracker()
    local t = blizz("Frame", UIParent, "ObjectiveTrackerFrame")
    t._width, t._height = 260, 800
    rawset(_G, "ObjectiveTrackerFrame", t)
    t.NineSlice = blizz("Frame", t)
    t.NineSlice._level = t._level
    t.NineSlice._alpha = 0
    t.Header = makeHeader(t, "ui-questtracker-primary-objective-header", "ui-questtrackerbutton-collapse-all",
        "ui-questtrackerbutton-expand-all")
    t.Header.FilterButton = blizzButton(t.Header, "ui-questtrackerbutton-filter",
        "ui-questtrackerbutton-filter-pressed", "ui-questtrackerbutton-red-highlight")
    WoW.setShown(t.Header.FilterButton, false)
    t.isCollapsed = false
    t.modules = {}
    for _, name in ipairs(WoW.MODULE_NAMES) do
        rawset(_G, name, WoW.addModule(name))
    end
    -- Hidden until Edit Mode opens: its OnShow / OnHide fire on the change.
    local em = blizz("Frame", UIParent, "EditModeManagerFrame")
    WoW.setShown(em, false)
    rawset(_G, "EditModeManagerFrame", em)
    WoW.snapshot()
end

function WoW.makeTracker() WoW.asBlizzard(makeTracker) end

-- The plain fields of every Blizzard object not yet snapshotted, as
-- Blizzard's side built them.
function WoW.snapshot()
    for _, w in ipairs(WoW.blizz) do
        if not WoW.snap[w] then
            local s = {}
            for k, v in pairs(w) do
                if type(k) ~= "string" or k:sub(1, 1) ~= "_" then s[k] = v end
            end
            WoW.snap[w] = s
        end
    end
end

-- Fields an addon changed or added since the snapshot (hooksecurefunc's own
-- wrapper excepted: the core counts each hook in WoW.hooked), as "key"
-- strings.
function WoW.fieldChanges()
    local out = {}
    for _, w in ipairs(WoW.blizz) do
        local s, hooked = WoW.snap[w] or {}, WoW.hooked[w] or {}
        for k, v in pairs(w) do
            if (type(k) ~= "string" or k:sub(1, 1) ~= "_") and not hooked[k] and s[k] ~= v then
                out[#out + 1] = tostring(k)
            end
        end
    end
    for _, k in ipairs(WoW.fieldWrites) do out[#out + 1] = k end
    return out
end

-- Run fn as Blizzard's own code.
function WoW.asBlizzard(fn, ...)
    local was = WoW.inBlizzard
    WoW.inBlizzard = true
    fn(...)
    WoW.inBlizzard = was
end

-- One layout of module `name` (a global name, or the module), the way the container drives it: the pools
-- this layout uses (spec.items item buttons, spec.groups find-group buttons,
-- spec.bars progress bars), shown when it has anything, then EndLayout. The
-- NineSlice's BOTTOM follows the last shown module (Container.lua:117).
function WoW.layout(name, spec)
    spec = spec or {}
    local t, m = ObjectiveTrackerFrame, type(name) == "table" and name or rawget(_G, name)
    WoW.asBlizzard(function()
        local edge = {}
        for i = 1, spec.items or 0 do
            local key = "item" .. i
            edge[key] = (m.usedRightEdgeFrames or {})[key] or blizzButton(m, "UI-QuestTrackerButton-QuestItem-Frame",
                "UI-QuestTrackerButton-QuestItem-Frame", nil)
        end
        for i = 1, spec.groups or 0 do
            local key = "group" .. i
            edge[key] = (m.usedRightEdgeFrames or {})[key] or blizzButton(m, nil, nil, nil, "disabled")
        end
        WoW.bset(m, "usedRightEdgeFrames", edge)
        local bars = {}
        for i = 1, spec.bars or 0 do
            local key = "bar" .. i
            local p = (m.usedProgressBars or {})[key]
            if not p then
                p = blizz("Frame", m)
                p.Bar = blizz("StatusBar", p)
                p.Bar.BorderLeft = blizz("Texture", p.Bar)
                p.Bar.BorderRight = blizz("Texture", p.Bar)
                p.Bar.BorderMid = blizz("Texture", p.Bar)
            end
            bars[key] = p
        end
        WoW.bset(m, "usedProgressBars", bars)
        local shown = spec.shown
        if shown == nil then shown = (spec.blocks or 0) > 0 or (spec.items or 0) > 0 or (spec.bars or 0) > 0 end
        WoW.setShown(m, shown and not t.isCollapsed)
        if m._shown then
            t.NineSlice:ClearAllPoints()
            t.NineSlice:SetPoint("TOPLEFT", t, "TOPLEFT", -30, 0)
            t.NineSlice:SetPoint("TOPRIGHT", t, "TOPRIGHT", 5, 0)
            t.NineSlice:SetPoint("BOTTOM", m, "BOTTOM", 0, -10)
        end
        WoW.snapshot()
        m:EndLayout()
    end)
end

-- The player clicks the container's collapse button: ContainerMixin:SetCollapsed
-- sets isCollapsed and the Header's button, with the modules still shown.
-- Its Update follows, where each module's EndLayout hides it
-- (ModuleMixin:EndLayout checks the container): drive that with WoW.layout.
function WoW.collapse(collapsed)
    local t = ObjectiveTrackerFrame
    WoW.asBlizzard(function()
        WoW.bset(t, "isCollapsed", collapsed)
        t.Header:SetCollapsed(collapsed)
    end)
end

-- The player collapses one module's section: ModuleHeaderMixin:SetCollapsed.
-- As ObjectiveTrackerModuleMixin:SetCollapsed: the module's field, then its
-- header (Blizzard_ObjectiveTrackerModule.lua:479).
function WoW.collapseModule(name, collapsed)
    WoW.asBlizzard(function()
        local m = rawget(_G, name)
        WoW.bset(m, "isCollapsed", collapsed)
        m.Header:SetCollapsed(collapsed)
    end)
end

-- Edit Mode opens or closes (EditModeManagerFrame's OnShow / OnHide).
function WoW.editMode(on)
    WoW.asBlizzard(function() EditModeManagerFrame:SetShown(on) end)
end

--------------------------------------------------------------------------------
-- Client APIs the addon reads
--------------------------------------------------------------------------------

SlashCmdList = {}
function wipe(t) for k in pairs(t) do t[k] = nil end; return t end
Enum = { UITextureSliceMode = { Stretched = 0, Tiled = 1 } }
function CreateColor(r, g, b, a) return { r = r, g = g, b = b, a = a } end
WoW.build, WoW.version = "70374", "v0.1.0"
function GetBuildInfo() return "1.60.1", WoW.build, "Oct 13 2026", 16001 end
C_AddOns = {
    GetAddOnMetadata = function(name, variable)
        if name == "GlassQuestTracker" and variable == "Version" then return WoW.version end
        return nil
    end,
    IsAddOnLoaded = function(name) return WoW.loaded[name] == true end,
}

-- Settings (Options > AddOns): the canvas category API.
Settings = {
    RegisterCanvasLayoutCategory = function(panel, name)
        return { panel = panel, name = name, GetID = function() return name end }
    end,
    RegisterCanvasLayoutSubcategory = function(parent, panel, name)
        return { panel = panel, name = name, parent = parent, GetID = function() return name end }
    end,
    RegisterAddOnCategory = function(cat) WoW.settingsCategory = cat end,
    OpenToCategory = function(id) WoW.settingsOpened = id end,
}

function GetCVarBool(name) return WoW.cvars[name] == true end
function UnitClass() return "Mage", WoW.class, 8 end
C_ClassColor = { GetClassColor = function(class)
    if class == "MAGE" then return { r = 0.25, g = 0.78, b = 0.92 } end
    return { r = 1, g = 1, b = 1 }
end }

--------------------------------------------------------------------------------
-- State the tests reset (WoW.reset, from the harness's loadAddon)
--------------------------------------------------------------------------------

-- The screen: UIParent's size (the core's UIParent has none).
UIParent._width, UIParent._height = 1024, 768

table.insert(WoW.onReset, function()
    WoW.settingsOpened = nil
    WoW.cvars = { autoQuestWatch = false }
    WoW.class = "MAGE"
    WoW.blizz, WoW.blizzCalls, WoW.luaCalls, WoW.fieldWrites = {}, {}, {}, {}
    WoW.snap = setmetatable({}, { __mode = "k" })
    WoW.inBlizzard = false
    WoW.loaded = {}
    WoW.makeTracker()
end)
WoW.reset()

-- Strict globals.
-- LibStub: the embedded library's own loader reads _G.LibStub before creating it.
Kit.strict({ GlassQuestTracker = true, GlassQuestTrackerDB = true,
             SLASH_GLASSQUESTTRACKER1 = true, SLASH_GLASSQUESTTRACKER2 = true, LibStub = true,
             -- TrackerProbe (tests/test_probe.lua): its saved table, read at its ADDON_LOADED.
             TrackerProbeDB = true })
