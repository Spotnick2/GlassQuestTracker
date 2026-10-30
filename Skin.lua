-- Skin.lua: keeps the glass on Blizzard's tracker through every layout.
--
-- Hook points (Forever runs the Mainline tracker; CLAUDE.md, "Tracker facts"):
--   hooksecurefunc(<module instance>, "EndLayout")  after every real layout.
--       ObjectiveTrackerFrame.Update hooks miss dirty updates (a closure made
--       at OnLoad), and mixin-table hooks miss everything (mixins are copied
--       at creation).
--   <module>.Header.SetCollapsed     re-tint: it swaps the button's atlas
--   ObjectiveTrackerFrame.Header.SetCollapsed   collapsing the container lays
--       out no module, so the panel is placed from here
--   EditModeManagerFrame OnHide      leaving Edit Mode with nothing tracked
-- The hooks stay for the session (a hook can't be removed); with the "stock"
-- theme they only keep the panel placed.
--
-- Start runs once, after PLAYER_ENTERING_WORLD. Blizzard's first layout may
-- already have happened by then (Manager.lua:215), so it ends with one full
-- pass over what exists.

GlassQuestTracker = GlassQuestTracker or {}
local GQT = GlassQuestTracker
local API = GQT.API
local Theme = GQT.Theme
local Tracker = GQT.Tracker
local Blizzard = GQT.Blizzard
local Panel = GQT.Panel
local Skin = {}
GQT.Skin = Skin

Skin.started = false

local function active() return not Theme.IsStock() end

local function onLayout(m)
    if active() then Blizzard.Module(m) end
    Panel.Place()
end

-- A missing hook point (another build) is recorded, not fatal.
local function hook(key, obj, method, fn)
    if type(obj) ~= "table" or type(obj[method]) ~= "function" then
        return API.Fail("hook:" .. key, "no " .. method)
    end
    API.Try("hook:" .. key, hooksecurefunc, obj, method, fn)
end

function Skin.Start()
    if Skin.started then return true end
    local t = Tracker.Frame()
    if not t then
        API.Fail("tracker", "ObjectiveTrackerFrame not found")
        return false
    end
    Skin.started = true
    API.Try("panel", Panel.Build)
    for i, m in ipairs(Tracker.Modules()) do
        local name = API.Plain(m.GetName and m:GetName()) or ("module " .. i)
        hook("layout:" .. name, m, "EndLayout", onLayout)
        if type(m.Header) == "table" then
            hook("collapse:" .. name, m.Header, "SetCollapsed", function()
                if active() then Blizzard.Module(m) end
            end)
        end
    end
    hook("collapse:container", Tracker.Header(), "SetCollapsed", function()
        if active() then Blizzard.Container() end
        Panel.Place()
    end)
    local em = rawget(_G, "EditModeManagerFrame")
    if type(em) == "table" and em.HookScript then
        API.Try("hook:editmode", em.HookScript, em, "OnHide", function() Panel.Place() end)
    end
    Skin.Apply()
    return true
end

-- The whole look, now: glass on every module, or everything stock.
function Skin.Apply()
    if not Skin.started then return end
    if active() then
        Panel.SetShown(true)
        Theme.Refresh()
        Panel.Repaint()
        Blizzard.Container()
        for _, m in ipairs(Tracker.Modules()) do API.Try("skin:module", Blizzard.Module, m) end
    else
        Panel.SetShown(false)
        Blizzard.Restore()
    end
    Panel.Place()
end
