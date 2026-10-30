-- Tracker.lua: read-only resolvers for Blizzard's ObjectiveTrackerFrame.
--
-- Forever runs the Mainline tracker: a container (ObjectiveTrackerFrame) with
-- a NineSlice and a Header, eleven module instances with their headers, and
-- each module's pooled extras (usedRightEdgeFrames: item and find-group
-- buttons; usedProgressBars). Blocks and lines aren't styled: the tracker's
-- fonts already carry a 1,-1 black shadow (P8). Measured on 70374
-- (docs/FOREVER-PROBE.md, P1/P2).
--
-- Everything here only reads. A missing piece (another build) is skipped and
-- returns nil, never an error: the skin styles what it finds.

GlassQuestTracker = GlassQuestTracker or {}
local GQT = GlassQuestTracker
local API = GQT.API
local Tracker = {}
GQT.Tracker = Tracker

-- The module instances, by global name, in Blizzard's order
-- (Blizzard_ObjectiveTrackerManager.lua). They exist from load; the manager
-- only assigns them to the container after PLAYER_ENTERING_WORLD.
Tracker.MODULES = { "ScenarioObjectiveTracker", "UIWidgetObjectiveTracker", "CampaignQuestObjectiveTracker",
    "QuestObjectiveTracker", "AdventureObjectiveTracker", "AchievementObjectiveTracker",
    "MonthlyActivitiesObjectiveTracker", "InitiativeTasksObjectiveTracker", "ProfessionsRecipeTracker",
    "BonusObjectiveTracker", "WorldQuestObjectiveTracker" }

local function tbl(v) return type(v) == "table" and v or nil end

function Tracker.Frame() return tbl(rawget(_G, "ObjectiveTrackerFrame")) end
function Tracker.NineSlice() local t = Tracker.Frame(); return t and tbl(t.NineSlice) end
function Tracker.Header() local t = Tracker.Frame(); return t and tbl(t.Header) end

function Tracker.IsCollapsed()
    local t = Tracker.Frame()
    return t ~= nil and API.Plain(t.isCollapsed) == true
end

-- Every module: the known globals, then any other the container holds.
function Tracker.Modules()
    local list, seen = {}, {}
    local function add(m)
        if tbl(m) and not seen[m] then seen[m] = true; list[#list + 1] = m end
    end
    for _, name in ipairs(Tracker.MODULES) do add(rawget(_G, name)) end
    local t = Tracker.Frame()
    if t and tbl(t.modules) then
        for _, m in ipairs(t.modules) do add(m) end
    end
    return list
end

-- Any module on screen: the container lays out only the shown ones.
function Tracker.Populated()
    for _, m in ipairs(Tracker.Modules()) do
        if m.IsShown then
            local ok, shown = pcall(m.IsShown, m)
            if ok and API.Plain(shown) == true then return true end
        end
    end
    return false
end

-- fn(frame) for each pooled extra a module shows this layout.
function Tracker.EachRightEdgeFrame(m, fn)
    for _, frame in pairs(tbl(m.usedRightEdgeFrames) or {}) do
        if tbl(frame) then fn(frame) end
    end
end

function Tracker.EachProgressBar(m, fn)
    for _, bar in pairs(tbl(m.usedProgressBars) or {}) do
        if tbl(bar) then fn(bar) end
    end
end
