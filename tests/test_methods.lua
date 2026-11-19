-- Every widget method the addon calls must exist on this client, for that
-- widget type (WowTestKit's Kit.checkMethods, against the build tests/kit.pin
-- names).
--
-- The stub refuses a method the build lacks on a type only where it's called,
-- and a method a Methods implementation provides answers on every type, so a
-- call to a method Forever lacks on that widget would otherwise pass
-- silently. This checks each recorded "Type:Method" as that exact pair.
-- Keep it exercising every handler the addon installs.
-- It does NOT prove argument contracts, event behaviour or protection rules:
-- that is the in-game pass (docs/FOREVER-PROBE.md).
dofile("tests/wow_stubs.lua")
dofile("tests/harness.lua")

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

-- The help ("help", "") prints /gqt's two lines with a bare | (#17).
eq(acceptKnownStrays(), 4, "the known stray help lines, two per help printed (#17)")

-- Loading alone records 41 (the first pass styles every module), the session
-- 43 (a find-group button's disabled art, a collapse's atlas swap): the floor
-- sits above the load, so the exercise can't quietly shrink back to it.
local recorded = Kit.checkMethods()
check(recorded >= 42,"the exercise reached the tracker and every command (" .. recorded .. " recorded)")
eq(next(GQT.failures), nil, "no failures recorded while exercising everything")
for k, v in pairs(GQT.failures) do io.write("    " .. k .. ": " .. v .. "\n") end
done("test_methods")
