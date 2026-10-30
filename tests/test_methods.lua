-- Every widget method the addon calls must exist on this client.
--
-- The stub answers any Capitalised method call (a no-op for ones it does not
-- implement), so a call to a method Forever lacks would otherwise pass
-- silently. This checks each recorded "Type:Method" against the API dump's
-- widget-method walk. Keep it exercising every handler the addon installs.
-- It does NOT prove argument contracts, event behaviour or protection rules:
-- that is the in-game pass (docs/FOREVER-PROBE.md).
dofile("tests/wow_stubs.lua")
dofile("tests/harness.lua")

local f = io.open(WoW.DUMP, "r")
if not f then
    io.write("test_methods: SKIPPED (no API dump at " .. WoW.DUMP .. ")\n")
    os.exit(0)
end
local widget, documented = {}, {}
for line in f:lines() do
    local wm = line:match("^(%a+:%a+)%s*$")
    if wm then widget[wm] = true end
    local fn = line:match("^([%a_]+)%(")
    if fn then documented[fn] = true end
end
f:close()

WoW.methodsCalled = {}
local GQT = loadAddon()

-- Every handler the skin installs: layouts with every pooled extra, both
-- collapses, Edit Mode, Blizzard re-showing faded art; then every command,
-- each theme and opacity, stock and back.
WoW.layout("QuestObjectiveTracker", { blocks = 2, items = 1, groups = 1, bars = 1 })
WoW.collapseModule("QuestObjectiveTracker", true)
WoW.collapse(true)
WoW.layout("QuestObjectiveTracker", { blocks = 2 })
WoW.collapse(false)
WoW.editMode(true)
WoW.editMode(false)
WoW.asBlizzard(function() ObjectiveTrackerFrame.NineSlice:SetAlpha(0.6) end)
for _, cmd in ipairs({ "failures", "version", "help", "", "theme smoked", "theme class", "opacity solid",
                       "theme stock", "theme clear", "theme", "opacity" }) do
    GQT._test.slash(cmd)
end
WoW.flushTimers()

local n = 0
for name in pairs(WoW.methodsCalled) do
    n = n + 1
    local method = name:match(":(%a+)$")
    check(widget[name] or documented[method], "method exists on Forever: " .. name)
end
check(n > 35, "recorded a realistic number of methods (raise it as features land) (" .. n .. ")")
eq(next(GQT.failures), nil, "no failures recorded while exercising everything")
for k, v in pairs(GQT.failures) do io.write("    " .. k .. ": " .. v .. "\n") end
done("test_methods")
