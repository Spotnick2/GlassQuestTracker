-- The UI contract: on Blizzard's tracker, only C widget methods from the
-- allowlist, no Lua (mixin) method, and no field written.
--
-- A regression guard over everything the addon does in a session, not proof
-- of taint safety: that's the in-game taint pass (docs/FOREVER-PROBE.md).
dofile("tests/wow_stubs.lua")
dofile("tests/harness.lua")

-- CLAUDE.md, "C methods only on Blizzard objects". Getters (Get*, Is*) too.
local ALLOWED = { SetAlpha = true, EnableMouse = true, SetShadowOffset = true, SetShadowColor = true,
                  SetDesaturated = true, SetVertexColor = true, SetTexture = true, SetAtlas = true,
                  HookScript = true }

local GQT = loadAddon()

-- A session: layouts with every pooled extra, pool reuse, collapse both
-- ways, Edit Mode in and out with an Opacity change, every theme and opacity.
WoW.layout("QuestObjectiveTracker", { blocks = 2, items = 1, groups = 1, bars = 1 })
WoW.layout("CampaignQuestObjectiveTracker", { blocks = 1 })
WoW.layout("QuestObjectiveTracker", { blocks = 2, items = 2, groups = 1, bars = 1 })
WoW.collapseModule("QuestObjectiveTracker", true)
WoW.collapseModule("QuestObjectiveTracker", false)
WoW.collapse(true)
WoW.collapse(false)
WoW.editMode(true)
WoW.asBlizzard(function() ObjectiveTrackerFrame.NineSlice:SetAlpha(0.6) end)
WoW.editMode(false)
for _, cmd in ipairs({ "theme stock", "theme smoked", "theme class", "opacity solid", "opacity light",
                       "theme stock", "theme clear" }) do
    GQT._test.slash(cmd)
end
WoW.layout("QuestObjectiveTracker", { blocks = 1, items = 1, bars = 1 })

-- The record is live: the session did call into Blizzard's objects.
check((WoW.blizzCalls.SetAlpha or 0) > 0 and (WoW.blizzCalls.SetVertexColor or 0) > 0,
      "the session called Blizzard objects (the record works)")
for name in pairs(WoW.blizzCalls) do
    check(ALLOWED[name] or name:match("^Get") or name:match("^Is"), "C method on the allowlist: " .. name)
end
eq(#WoW.luaCalls, 0, "no Lua method of Blizzard's called (" .. table.concat(WoW.luaCalls, ", ") .. ")")
local changes = WoW.fieldChanges()
eq(#changes, 0, "no field written on a Blizzard object (" .. table.concat(changes, ", ") .. ")")
eq(next(GQT.failures), nil, "no failures")
for k, v in pairs(GQT.failures) do io.write("    " .. k .. ": " .. v .. "\n") end

-- Our frames are unnamed.
local named = {}
for _, w in ipairs(WoW.frames) do
    if w._name then named[#named + 1] = w._name end
end
eq(#named, 0, "every frame the addon made is unnamed (" .. table.concat(named, ", ") .. ")")

-- The guard catches what it guards: a write and a Lua call made as addon code.
ObjectiveTrackerFrame.NineSlice.glassy = true
ObjectiveTrackerFrame.isCollapsed = true
ObjectiveTrackerFrame.Header:SetCollapsed(true)
local caught = table.concat(WoW.fieldChanges(), ",")
check(caught:find("glassy", 1, true) and caught:find("isCollapsed", 1, true), "the guard sees new and changed fields")
eq(WoW.luaCalls[1], "SetCollapsed", "the guard sees a Lua method call")

done("test_contract")
