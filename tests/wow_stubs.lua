-- wow_stubs.lua: a minimal WoW: Forever mock for Lua 5.1 unit tests.
-- dofile("tests/wow_stubs.lua") FIRST in every test; drive it via the WoW table.
-- Glass MiniMap's stubs (themselves Glass MiniMap Bar's, GlassUnitFrames' and
-- GlassPanel's), trimmed to the widgets and the globals this addon reads.
--
-- What it models, on purpose:
-- - STRICT globals: reading any global it does not define is an error. The
--   stub is the allowlist of APIs verified present in the API dump.
-- - EVENT names: RegisterEvent throws on a name the API dump does not declare.
-- - METHOD calls: every widget method called is recorded (WoW.methodsCalled)
--   so test_methods.lua can check each against the dump's widget methods.
-- - The widget METATABLE is a real method table, like the client's.

WoW = {}
WoW.DUMP = os.getenv("GLASSQT_API_DUMP") or "C:/Projects/WoW/References/forever-api-1.60.1.70374.md"

--------------------------------------------------------------------------------
-- Known events (from the dump when present)
--------------------------------------------------------------------------------

WoW.KNOWN_EVENTS = {}
do
    local f = io.open(WoW.DUMP, "r")
    if f then
        local inEvents = false
        for line in f:lines() do
            if line:match("^## Documented events") then inEvents = true
            elseif line:match("^## ") then inEvents = false
            elseif inEvents then
                local name = line:match("^([A-Z][A-Z0-9_]+)%s+%(")
                if name then WoW.KNOWN_EVENTS[name] = true end
            end
        end
        f:close()
    end
    if next(WoW.KNOWN_EVENTS) == nil then
        -- CI has no dump: the events this addon registers, checked locally against it.
        for _, e in ipairs({ "ADDON_LOADED", "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "QUEST_ACCEPTED",
                             "QUEST_LOG_UPDATE", "QUEST_WATCH_LIST_CHANGED", "EDIT_MODE_LAYOUTS_UPDATED",
                             "PLAYER_REGEN_ENABLED", "CVAR_UPDATE" }) do
            WoW.KNOWN_EVENTS[e] = true
        end
    end
end

--------------------------------------------------------------------------------
-- Widgets
--------------------------------------------------------------------------------

local Methods = {}   -- implementations, by method name
WoW.Methods = Methods

local function record(w, name)
    WoW.methodsCalled[(rawget(w, "_type") or "?") .. ":" .. name] = true
    -- A call on a Blizzard object from addon code (not from the simulated
    -- Blizzard side): test_contract checks each against the C-only allowlist.
    if rawget(w, "_blizz") and not WoW.inBlizzard then WoW.blizzCalls[name] = (WoW.blizzCalls[name] or 0) + 1 end
end

-- The shared method table: any Capitalised name is a method (a no-op unless
-- implemented below); anything else reads as nil, like a missing field.
local MethodTable = setmetatable({}, {
    __index = function(_, k)
        if type(k) ~= "string" or not k:match("^%u") then return nil end
        return function(self, ...)
            record(self, k)
            local impl = Methods[k]
            if impl then return impl(self, ...) end
            return nil
        end
    end,
})
local widgetMT = { __index = MethodTable }

local function newWidget(wtype, parent, name)
    local w = setmetatable({ _type = wtype, _parent = parent, _shown = true, _points = {},
                             _scripts = {}, _events = {}, _children = {}, _regions = {},
                             _level = parent and parent._level and (parent._level + 1) or 1,
                             _width = 0, _height = 0, _name = name, _scale = 1, _alpha = 1,
                             _mouse = false }, widgetMT)
    return w
end
WoW.newWidget = newWidget

local function adopt(parent, w)
    if parent and parent._children then table.insert(parent._children, w) end
end

local SCRIPTED = { Frame = true, Button = true, CheckButton = true, StatusBar = true, GameTooltip = true,
                   EditBox = true }

function CreateFrame(ftype, name, parent, template)
    local w = newWidget(ftype, parent, name)
    w._template = template
    adopt(parent, w)
    table.insert(WoW.frames, w)
    if name then rawset(_G, name, w) end
    if template == "UICheckButtonTemplate" or template == "UIPanelButtonTemplate" then
        w.Text = newWidget("FontString", w)
    end
    if template == "UIRadioButtonTemplate" then w.text = newWidget("FontString", w) end
    return w
end

function Methods.Show(w) if not w._shown then w._shown = true; if w._scripts.OnShow then w._scripts.OnShow(w) end end end
function Methods.Hide(w) if w._shown then w._shown = false; if w._scripts.OnHide then w._scripts.OnHide(w) end end end
function Methods.SetShown(w, v) if v then Methods.Show(w) else Methods.Hide(w) end end
function Methods.IsShown(w) return w._shown end
function Methods.IsVisible(w)
    local p = w
    while p do if not p._shown then return false end; p = p._parent end
    return true
end
function Methods.SetPoint(w, ...) table.insert(w._points, { ... }) end
function Methods.ClearAllPoints(w) w._points = {} end
function Methods.GetPoint(w, i)
    local p = w._points[i or 1]
    if p then return p[1], p[2], p[3], p[4], p[5] end
end
function Methods.GetNumPoints(w) return #w._points end
function Methods.SetAllPoints(w, rel) table.insert(w._points, { "ALL", rel }) end
function Methods.SetSize(w, x, y) w._width, w._height = x, y end
function Methods.SetWidth(w, x) w._width = x end
function Methods.SetHeight(w, y) w._height = y end
function Methods.GetWidth(w) return w._width end
function Methods.GetHeight(w) return w._height end
function Methods.GetSize(w) return w._width, w._height end
function Methods.GetCenter(w) return w._cx, w._cy end
function Methods.GetEffectiveScale(w) return w._effScale or 1 end
function Methods.SetScale(w, s) w._scale = s end
function Methods.GetScale(w) return w._scale end
-- A gradient texture ignores SetAlpha on this client (GlassActionBars'
-- /gab inspect, 2026-10-13: its wash read 1.00 right after SetAlpha(0); here
-- too, 70374, 2026-10-15), so the stub ignores it as well: only the
-- gradient's own colours set its alpha.
function Methods.SetAlpha(w, a)
    if w._gradient then return end
    w._alpha = a
end
function Methods.GetAlpha(w) return w._alpha end
function Methods.GetFrameLevel(w) return w._level end
function Methods.SetFrameLevel(w, l) w._level = l end
function Methods.SetFrameStrata(w, s) w._strata = s end
function Methods.GetFrameStrata(w) return w._strata or "MEDIUM" end
function Methods.GetName(w) return w._name end
function Methods.GetParent(w) return w._parent end
function Methods.SetParent(w, p)
    if w._parent and w._parent._children then
        for i, c in ipairs(w._parent._children) do
            if c == w then table.remove(w._parent._children, i); break end
        end
    end
    w._parent = p
    adopt(p, w)
end
function Methods.GetChildren(w) return unpack(w._children) end
function Methods.GetRegions(w) return unpack(w._regions) end
function Methods.IsObjectType(w, t)
    if w._type == t then return true end
    return t == "Frame" and (w._type == "Button" or w._type == "CheckButton")
end
function Methods.GetObjectType(w) return w._type end
function Methods.IsForbidden(w) return false end
function Methods.IsProtected(w) return w._protected == true end
function Methods.EnableMouse(w, v) w._mouse = v and true or false end
function Methods.IsMouseEnabled(w) return w._mouse == true end
function Methods.RegisterForClicks(w, ...) w._clicks = { ... } end
function Methods.RegisterForDrag(w, ...) w._drag = { ... } end
function Methods.IsMouseOver(w) return WoW.mouseOver[w] == true end
function Methods.GetChecked(w) return w._checked == true end
function Methods.SetEnabled(w, v) w._enabled = v and true or false end
function Methods.IsEnabled(w) return w._enabled ~= false end
function Methods.SetChecked(w, v) w._checked = v and true or false end
function Methods.SetText(w, t) w._text = t end
function Methods.GetText(w) return w._text end
function Methods.SetTextColor(w, r, g, b) w._textColor = { r, g, b } end
function Methods.GetAnimationGroups(w) return unpack(w._anims or {}) end
function Methods.UnregisterAllEvents(w) w._events = {} end
function Methods.SetHighlightTexture(w, file, blend)
    w._highlight = newWidget("Texture", w)
    w._highlight._file = file
    return true
end
function Methods.GetHighlightTexture(w) return w._highlight end
function Methods.SetNormalTexture(w, file) w._normal = newWidget("Texture", w); w._normal._file = file end
function Methods.GetNormalTexture(w) return w._normal end
function Methods.SetCheckedTexture(w, file) w._checkedTex = newWidget("Texture", w) end
function Methods.GetCheckedTexture(w) return w._checkedTex end
function Methods.GetPushedTexture(w) return w._pushed end
function Methods.GetDisabledTexture(w) return w._disabled end
function Methods.SetDesaturated(t, v) t._desat = v and true or false end
function Methods.IsDesaturated(t) return t._desat == true end
function Methods.GetVertexColor(t)
    local c = t._vertex or { 1, 1, 1, 1 }
    return c[1], c[2], c[3], c[4] or 1
end

-- Animations: Play marks a group playing; WoW.finishAnimations() completes
-- every playing group (OnFinished), as the client would after its duration.
function Methods.CreateAnimationGroup(w)
    local ag = newWidget("AnimationGroup", w)
    ag._animations = {}
    w._anims = w._anims or {}
    table.insert(w._anims, ag)
    table.insert(WoW.animGroups, ag)
    return ag
end
function Methods.CreateAnimation(ag, atype)
    local a = newWidget(atype or "Animation", ag)
    table.insert(ag._animations, a)
    return a
end
function Methods.GetAnimations(ag) return unpack(ag._animations) end
function Methods.GetTarget(a) return a._parent and a._parent._parent end
function Methods.Play(ag) ag._playing = true; ag._plays = (ag._plays or 0) + 1 end
function Methods.Stop(ag) ag._playing = false end
function Methods.IsPlaying(ag) return ag._playing == true end
function Methods.SetOrigin(a, point) a._origin = point end
function Methods.SetScaleFrom(a, x, y) a._from = { x, y } end
function Methods.SetScaleTo(a, x, y) a._to = { x, y } end
function WoW.finishAnimations()
    for _, ag in ipairs(WoW.animGroups) do
        if ag._playing then
            ag._playing = false
            if ag._scripts.OnFinished then ag._scripts.OnFinished(ag) end
        end
    end
end

-- Scripts. HasScript: every scripted widget type knows these handlers.
local HANDLERS = { OnClick = true, OnMouseUp = true, OnMouseDown = true, OnEnter = true, OnLeave = true,
                   OnShow = true, OnHide = true, OnUpdate = true, OnEvent = true, OnDragStart = true, OnDragStop = true,
                   OnDoubleClick = true, OnMouseWheel = true }
function Methods.HasScript(w, name) return SCRIPTED[w._type] == true and HANDLERS[name] == true end
function Methods.SetScript(w, name, fn) w._scripts[name] = fn end
function Methods.GetScript(w, name) return w._scripts[name] end
function Methods.HookScript(w, name, fn)
    local old = w._scripts[name]
    w._scripts[name] = function(...) if old then old(...) end; fn(...) end
end
function Methods.Click(w, mouse)
    if w._scripts.OnClick then w._scripts.OnClick(w, mouse or "LeftButton", false) end
end
function Methods.RegisterEvent(w, e)
    if not WoW.KNOWN_EVENTS[e] then error("Attempt to register unknown event \"" .. e .. "\"", 2) end
    w._events[e] = true
    return true
end
function Methods.UnregisterEvent(w, e) w._events[e] = nil end

-- Regions.
local function region(w, wtype, layer)
    local r = newWidget(wtype, w)
    r._layer = layer
    if wtype ~= "MaskTexture" then table.insert(w._regions, r) end
    return r
end
function Methods.CreateTexture(w, _, layer) return region(w, "Texture", layer) end
function Methods.CreateMaskTexture(w) return region(w, "MaskTexture") end
function Methods.CreateFontString(w, _, layer) return region(w, "FontString", layer) end
function Methods.SetTexture(t, file) t._file = file; t._atlas = nil; return true end
function Methods.GetTexture(t) return t._file end
function Methods.SetAtlas(t, atlas) t._atlas = atlas; t._file = nil; return true end
function Methods.GetAtlas(t) return t._atlas end
function Methods.SetTexCoord(t, ...) t._coords = { ... } end
function Methods.GetTexCoord(t)
    local c = t._coords or { 0, 0, 0, 1, 1, 0, 1, 1 }
    return unpack(c)
end
function Methods.SetVertexColor(t, r, g, b, a) t._vertex = { r, g, b, a } end
function Methods.SetRotation(t, r) t._rotation = r end
function Methods.SetColorTexture(t, r, g, b, a) t._color = { r, g, b, a } end
function Methods.AddMaskTexture(t, m) t._masks = t._masks or {}; table.insert(t._masks, m) end
function Methods.RemoveMaskTexture(t, m)
    for i, x in ipairs(t._masks or {}) do if x == m then table.remove(t._masks, i); return end end
end
function Methods.SetGradient(t, orientation, c1, c2)
    assert(type(c1) == "table" and type(c2) == "table", "SetGradient takes color objects on this API")
    t._gradient = { orientation, c1, c2 }
    t._alpha = 1
end
function Methods.SetFont(fs, file, size, flags) fs._font = { file, size, flags }; return true end

-- GameTooltip: records its lines.
function Methods.SetOwner(tt, owner) tt._owner = owner; tt._lines = {} end
function Methods.GetOwner(tt) return tt._owner end
function Methods.ClearLines(tt) tt._lines = {} end
function Methods.AddLine(tt, text, r, g, b)
    table.insert(tt._lines, text)
    tt._colors = tt._colors or {}
    tt._colors[#tt._lines] = { r, g, b }
end
function Methods.AddDoubleLine(tt, l, r) table.insert(tt._lines, tostring(l) .. "|" .. tostring(r)) end

--------------------------------------------------------------------------------
-- Blizzard's objective tracker (Mainline, as Forever runs it: wow-ui-source
-- branch forever, measured on 70374)
--------------------------------------------------------------------------------

-- A Blizzard object: a NEW key written from addon code is trapped here;
-- a changed EXISTING key is caught by WoW.fieldChanges() against the
-- snapshot. Keys starting with "_" are the stub's own bookkeeping.
local blizzMT = {
    __index = MethodTable,
    __newindex = function(t, k, v)
        if type(k) == "string" and k:sub(1, 1) == "_" then return rawset(t, k, v) end
        if not WoW.inBlizzard then table.insert(WoW.fieldWrites, tostring(k)) end
        rawset(t, k, v)
    end,
}

local function blizz(wtype, parent, name)
    local w = setmetatable(newWidget(wtype, parent, name), blizzMT)
    rawset(w, "_blizz", true)
    table.insert(WoW.blizz, w)
    return w
end

local function blizzTexture(parent, atlas)
    local t = blizz("Texture", parent)
    t._atlas = atlas
    return t
end

local function blizzButton(parent, normal, pushed, highlight, disabled)
    local b = blizz("Button", parent)
    b._normal = blizzTexture(b, normal)
    b._pushed = blizzTexture(b, pushed)
    b._highlight = blizzTexture(b, highlight)
    if disabled then b._disabled = blizzTexture(b, disabled) end
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

local function makeHeader(parent, bgAtlas, collapse, expand, withAnim)
    local h = blizz("Frame", parent)
    h.Background = blizzTexture(h, bgAtlas)
    h.Text = blizz("FontString", h)
    h.MinimizeButton = blizzButton(h, collapse, collapse .. "-pressed", "ui-questtrackerbutton-red-highlight")
    if withAnim then
        h.Shine = blizzTexture(h, "UI-QuestTracker-OBJFX-Shine")
        h.Glow = blizzTexture(h, "UI-QuestTracker-OBJFX-BarGlow")
        h.Shine._alpha, h.Glow._alpha = 0, 0
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
-- global of its name, it's one a later build added.
function WoW.addModule(name)
    local t = ObjectiveTrackerFrame
    local m
    WoW.asBlizzard(function()
        m = blizz("Frame", t, name)
        m._shown = false
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
    t.Header.FilterButton._shown = false
    t.isCollapsed = false
    t.modules = {}
    for _, name in ipairs(WoW.MODULE_NAMES) do
        rawset(_G, name, WoW.addModule(name))
    end
    local em = blizz("Frame", UIParent, "EditModeManagerFrame")
    em._shown = false
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
-- wrapper excepted), as "key" strings.
function WoW.fieldChanges()
    local out = {}
    for _, w in ipairs(WoW.blizz) do
        local s, hooked = WoW.snap[w] or {}, WoW.hookedKeys[w] or {}
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
        m._shown = shown and not t.isCollapsed
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
function WoW.collapseModule(name, collapsed)
    WoW.asBlizzard(function() rawget(_G, name).Header:SetCollapsed(collapsed) end)
end

-- Edit Mode opens or closes (EditModeManagerFrame's OnShow / OnHide).
function WoW.editMode(on)
    WoW.asBlizzard(function() EditModeManagerFrame:SetShown(on) end)
end

--------------------------------------------------------------------------------
-- Globals
--------------------------------------------------------------------------------

function WoW.reset()
    WoW.frames = {}
    WoW.chat = {}
    WoW.methodsCalled = WoW.methodsCalled or {}
    WoW.timers = {}
    WoW.mouseOver = {}
    WoW.animGroups = {}
    WoW.settingsOpened = nil
    WoW.cvars = { autoQuestWatch = false }
    WoW.class = "MAGE"
    WoW.blizz, WoW.blizzCalls, WoW.luaCalls, WoW.fieldWrites = {}, {}, {}, {}
    WoW.hookedKeys = setmetatable({}, { __mode = "k" })
    WoW.snap = setmetatable({}, { __mode = "k" })
    WoW.inBlizzard = false
    WoW.combat = false
    WoW.loaded = {}
    UIParent = newWidget("Frame", nil, "UIParent")
    UIParent._level = 0
    UIParent._width, UIParent._height = 1024, 768
    GameTooltip = newWidget("GameTooltip", UIParent, "GameTooltip")
    UISpecialFrames = {}
    WoW.makeTracker()
end

function print(...)
    local parts = {}
    for i = 1, select("#", ...) do parts[#parts + 1] = tostring((select(i, ...))) end
    table.insert(WoW.chat, table.concat(parts, " "))
end

SlashCmdList = {}
strmatch = string.match
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
function issecretvalue(v) return false end
function InCombatLockdown() return WoW.combat end
-- hooksecurefunc(table, name, fn) or hooksecurefunc(globalName, fn).
function hooksecurefunc(t, name, fn)
    if type(t) == "string" then
        local gname, f = t, name
        local orig = rawget(_G, gname)
        rawset(_G, gname, function(...) local r = orig(...); f(...); return r end)
        return
    end
    local orig = t[name]
    -- The client's own field: not an addon write (test_contract skips it).
    if rawget(t, "_blizz") then WoW.hookedKeys[t] = WoW.hookedKeys[t] or {}; WoW.hookedKeys[t][name] = true end
    rawset(t, name, function(self, ...)
        local r = orig(self, ...)
        -- The hook is addon code, even when Blizzard's side made the call.
        local was = WoW.inBlizzard
        WoW.inBlizzard = false
        fn(self, ...)
        WoW.inBlizzard = was
        return r
    end)
end

-- Timers keep their delay: WoW.flushTimers(upTo) runs those due within upTo.
C_Timer = { After = function(s, fn) table.insert(WoW.timers, { s = s, fn = fn }) end }
function WoW.flushTimers(upTo)
    for _ = 1, 10 do   -- timers may schedule timers; settle them
        local run, keep = {}, {}
        for _, t in ipairs(WoW.timers) do
            if upTo == nil or t.s <= upTo then run[#run + 1] = t else keep[#keep + 1] = t end
        end
        WoW.timers = keep
        if #run == 0 then return end
        for _, t in ipairs(run) do t.fn() end
    end
end

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
-- Driving
--------------------------------------------------------------------------------

-- Fire an event at every frame registered for it. Errors are NOT caught.
function WoW.fire(event, ...)
    local list = {}
    for _, w in ipairs(WoW.frames) do list[#list + 1] = w end
    for _, w in ipairs(list) do
        local handler = w._scripts.OnEvent
        if handler and w._events[event] then handler(w, event, ...) end
    end
end

-- One rendered frame: OnUpdate on every visible frame.
function WoW.tick(elapsed)
    elapsed = elapsed or 0.02
    local list = {}
    for _, w in ipairs(WoW.frames) do list[#list + 1] = w end
    for _, w in ipairs(list) do
        local fn = w._scripts.OnUpdate
        if fn and Methods.IsVisible(w) then fn(w, elapsed) end
    end
end

WoW.reset()

-- Strict globals.
-- LibStub: the embedded library's own loader reads _G.LibStub before creating it.
local allowNil = { GlassQuestTracker = true, GlassQuestTrackerDB = true,
                   SLASH_GLASSQUESTTRACKER1 = true, SLASH_GLASSQUESTTRACKER2 = true, LibStub = true }
setmetatable(_G, { __index = function(_, k)
    if allowNil[k] then return nil end
    error("read of undefined global '" .. tostring(k) .. "' (not stubbed: is it in the API dump?)", 2)
end })
