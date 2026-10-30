-- TrackerProbe (Tools/TrackerProbe), a ForeverProbe module: it loads on the
-- host beside the addon, its lines go to its saved log and never to chat,
-- its passes refuse to install over the addon's own skin, the routine
-- counts only within an installed pass (#10's review), and the look
-- procedure (#3's in-game checks) walks end to end, checking what each step
-- says and putting the owner's theme and opacity back.
-- Needs a ForeverProbe checkout ($FOREVERPROBE, else ..\ForeverProbe); skips
-- without one (CI without the host's token).
dofile("tests/wow_stubs.lua")
dofile("tests/harness.lua")

local root = foreverProbeRoot()
if not root then
    io.write("test_probe: SKIPPED (no ForeverProbe checkout: set FOREVERPROBE or clone it beside this repo)\n")
    os.exit(0)
end

local errors = {}
rawset(_G, "geterrorhandler", function() return function(e) errors[#errors + 1] = tostring(e) end end)
-- What the probe's measurements read beyond the addon's stub, each in the
-- 70374 dump; filled only where the shared stub has none.
local extra = {
    IsInInstance = function() return false, "none" end,
    GetCVar = function() return "0" end,
    C_CVar = { GetCVarInfo = function() return "1", "1" end },
    Constants = { QuestWatchConsts = { MAX_QUEST_WATCHES = 25 } },
    C_QuestLog = { GetNumQuestWatches = function() return 2 end, GetNumQuestLogEntries = function() return 4, 3 end,
                   GetQuestWatchType = function() return 0 end, GetLogIndexForQuestID = function() return 1 end,
                   AddQuestWatch = function() return true end },
}
for k, v in pairs(extra) do if rawget(_G, k) == nil then rawset(_G, k, v) end end

-- The owner's own look, which the procedure must put back.
local GQT = loadAddon({ db = { theme = "smoked", opacity = "light" } })
WoW.layout("QuestObjectiveTracker", { blocks = 2 })
local FP = loadForeverProbe(root)
local ns = loadProbe()
local T = ns._test
local DB = TrackerProbeDB
local function fp(msg) SlashCmdList.FOREVERPROBE(msg) end
local function logHas(text)
    for _, l in ipairs(DB.log) do if l:find(text, 1, true) then return true end end
    return false
end
local function chatHas(text)
    for _, l in ipairs(WoW.chat) do if l:find(text, 1, true) then return true end end
    return false
end
-- Screenshots go through the host's OnUpdate queue; Screenshot() isn't
-- stubbed, so each is recorded as failed and the procedure moves on.
local function settle() for _ = 1, 12 do WoW.tick(0.05) end end

check(type(DB) == "table" and DB.log ~= nil, "the saved table is made at the probe's ADDON_LOADED")
check(logHas("Glass Quest Tracker loaded"), "the session line says the addon is loaded")
check(not chatHas("session start"), "the probe's lines stay out of chat")

------------------------------------------------------------------------------
-- The commands
------------------------------------------------------------------------------
for _, cmd in ipairs({ "frames", "nine", "cvars", "counts", "routine", "accept on", "accept off" }) do
    local before = #DB.log
    local ok, err = pcall(fp, "gqt " .. cmd)
    check(ok, "/fp gqt " .. cmd .. " runs" .. (ok and "" or (": " .. tostring(err))))
    check(#DB.log > before, "  and logs")
end
fp("gqt nine")   -- the overlay off again
fp("gqt state")
check(logHas("theme=smoked backing=0.35 glass=true panel=populated wash=false nineslice=0 headerbar=0"),
      "state: the addon's look as it holds it")
check(not chatHas("theme=smoked"), "  in the log, not in chat")

-- The passes refuse to stack on the addon's skin, and aren't remembered.
fp("gqt restyle")
check(logHas("pass B refused: Glass Quest Tracker is loaded"), "restyle is refused while the addon is loaded")
eq(DB.mode, nil, "a refused pass isn't kept for the next /reload")
WoW.layout("QuestObjectiveTracker", { blocks = 2 })
DB.log[#DB.log + 1] = "--"
fp("gqt counts")
check(logHas("no hook has run"), "and no hook was installed")

------------------------------------------------------------------------------
-- The look procedure, end to end
------------------------------------------------------------------------------
local S = FP.Steps
fp("steps gqt look")
local rec = ForeverProbeDB.steps.records["TrackerProbe/look"]
check(rec and rec.status == "active", "/fp steps gqt look starts the procedure")
eq(rec.results[1].check, "PASS", "1: the addon's state reads, on arrival")
eq(DB.look and DB.look.theme, "smoked", "  the owner's theme is kept to put back")
eq(DB.look and DB.look.opacity, "light", "  and their opacity")

local Theme, Panel = GQT.Theme, GQT.Panel
local function run(i, msg)
    eq(rec.at, i, "at step " .. i)
    S.Run(); settle()
    eq(rec.results[i].check, "PASS", msg)
    if rec.results[i].check ~= "PASS" then io.write("    " .. tostring(rec.results[i].checkDetail) .. "\n") end
end
local function nextStep(i, msg)
    eq(rec.at, i, "at step " .. i)
    S.Next(); settle()
    eq(rec.results[i].check, "PASS", msg)
    if rec.results[i].check ~= "PASS" then io.write("    " .. tostring(rec.results[i].checkDetail) .. "\n") end
end
local function answer(i, yes)
    eq(rec.at, i, "at step " .. i)
    S.Answer(yes); settle()
end

run(2, "2: clear at medium");      eq(Theme.Name(), "clear", "  the theme is clear")
eq(Theme.BackingAlpha(), Theme.OPACITY.medium, "  at medium")
check(chatHas("theme"), "  through /gqt, as typed (its own reply is in chat)")
check(logHas("clear, medium: Screenshot() isn't on this client"), "  a screenshot was asked for (none in the stub)")

-- Restarted part-way (the host runs none of the stopped run's steps), and
-- step 1 run again after Back: the owner's look is still the one to put back.
fp("steps gqt look")
rec = ForeverProbeDB.steps.records["TrackerProbe/look"]
eq(rec.results[1].check, "PASS", "restarted: step 1 again")
eq(DB.look.theme, "smoked", "  the unfinished run's theme is kept, not the test's clear")
eq(DB.look.opacity, "light", "  and its opacity, not medium")
check(logHas("an unfinished run's settings are kept to put back: smoked, light"), "  and the log says so")
S.Back(); settle()
eq(rec.at, 1, "Back to step 1")
S.Run(); settle()
eq(DB.look.theme, "smoked", "  step 1 run again keeps them too")
run(2, "2: clear at medium, restarted")
run(3, "3: smoked");               eq(Theme.Name(), "smoked", "  smoked")
run(4, "4: class");                eq(Theme.Name(), "class", "  class")
run(5, "5: stock");                check(not Panel._test.frame():IsShown(), "  stock: no glass")
answer(6, true)
eq(rec.results[6].status, "yes", "6: the owner's answer is the result")
run(7, "7: clear again")
run(8, "8: opacity light");        eq(Theme.BackingAlpha(), Theme.OPACITY.light, "  light")
run(9, "9: opacity solid");        eq(Theme.BackingAlpha(), Theme.OPACITY.solid, "  solid")
run(10, "10: medium again")
answer(11, true)
check(logHas("right edge: Screenshot() isn't on this client"), "11: the right-edge question takes a screenshot")

-- The owner's clicks, which the probe can't make.
eq(rec.at, 12, "at step 12")
S.Next(); settle()
eq(rec.results[12].check, "FAIL", "12: Next without collapsing fails its check")
S.Back(); settle()
WoW.collapse(true)
nextStep(12, "12: collapsed, the glass on the header")
WoW.collapse(false); WoW.layout("QuestObjectiveTracker", { blocks = 2 })
-- A section the owner keeps collapsed: it mustn't count as the one step 15 asks for.
WoW.collapseModule("CampaignQuestObjectiveTracker", true)
nextStep(13, "13: expanded, populated again")
eq(rec.results[14].status, "done", "14: the snapshot for the manual steps, on arrival")
-- Next without the owner's action fails: the state alone looks the same
-- (Codex, PR #14).
local function skipped(i, msg)
    eq(rec.at, i, "at step " .. i)
    S.Next(); settle()
    eq(rec.results[i].check, "FAIL", msg)
    S.Back(); settle()
end
skipped(15, "15: Next without collapsing a section fails")
WoW.collapseModule("QuestObjectiveTracker", true); WoW.layout("QuestObjectiveTracker", { shown = true })
nextStep(15, "15: a section collapsed, still populated")
check(rec.results[15].checkDetail:find("QuestObjectiveTracker collapsed", 1, true) ~= nil, "  naming the section")
skipped(16, "16: Next with the section still collapsed fails")
WoW.collapseModule("QuestObjectiveTracker", false); WoW.layout("QuestObjectiveTracker", { blocks = 2 })
nextStep(16, "16: the section expanded")
check(rec.results[16].checkDetail:find("QuestObjectiveTracker expanded", 1, true) ~= nil, "  the same section")

-- A /reload mid-way: the probe's file runs again (its snapshot is gone) and
-- the host resumes the same step at PLAYER_LOGIN (Codex, PR #14).
local function reload()
    ns = loadProbe()
    WoW.fire("PLAYER_LOGIN")
    settle()
end
local function lost(i, msg)
    eq(rec.at, i, "at step " .. i)
    S.Next(); settle()
    eq(rec.results[i].check, "FAIL", msg)
    check(tostring(rec.results[i].checkDetail):find("no snapshot", 1, true) ~= nil, "  saying the snapshot is gone")
    S.Back(); settle()
end
local function backTo(i) while rec.at > i do S.Back(); settle() end end
backTo(15)
reload()
eq(rec.at, 15, "reloaded at 15: resumed there")
WoW.collapseModule("QuestObjectiveTracker", true); WoW.layout("QuestObjectiveTracker", { shown = true })
lost(15, "15 after a /reload: collapsing can't be judged, so it fails")
WoW.collapseModule("QuestObjectiveTracker", false); WoW.layout("QuestObjectiveTracker", { blocks = 2 })
backTo(14)
S.Run(); settle()          -- the snapshot again, by hand after Back
WoW.collapseModule("QuestObjectiveTracker", true); WoW.layout("QuestObjectiveTracker", { shown = true })
nextStep(15, "15: redone after a new snapshot")
reload()
eq(rec.at, 16, "reloaded at 16: resumed there")
WoW.collapseModule("QuestObjectiveTracker", false); WoW.layout("QuestObjectiveTracker", { blocks = 2 })
lost(16, "16 after a /reload: a missing snapshot is no evidence of expanding")
backTo(14)
S.Run(); settle()
WoW.collapseModule("QuestObjectiveTracker", true); WoW.layout("QuestObjectiveTracker", { shown = true })
nextStep(15, "15: redone")
WoW.collapseModule("QuestObjectiveTracker", false); WoW.layout("QuestObjectiveTracker", { blocks = 2 })
nextStep(16, "16: redone")
answer(17, false)
skipped(18, "18: Next without Edit Mode fails")
WoW.editMode(true)
skipped(18, "18: Edit Mode opened but not closed fails")
WoW.editMode(false)
reload()
eq(rec.at, 18, "reloaded at 18: resumed there")
WoW.editMode(true); WoW.editMode(false)
lost(18, "18 after a /reload: Edit Mode can't be judged, so it fails")
backTo(14)
S.Run(); settle()
WoW.collapseModule("QuestObjectiveTracker", true); WoW.layout("QuestObjectiveTracker", { shown = true })
nextStep(15, "15: redone after the Edit Mode reload")
WoW.collapseModule("QuestObjectiveTracker", false); WoW.layout("QuestObjectiveTracker", { blocks = 2 })
nextStep(16, "16: redone")
answer(17, false)
WoW.editMode(true); WoW.editMode(false)
nextStep(18, "18: after Edit Mode, opened and closed")
answer(19, true)
eq(rec.results[20].check, "PASS", "20: no failures, on arrival")
eq(rec.results[21].check, "PASS", "21: the owner's look put back, on arrival")
eq(Theme.Name(), "smoked", "  their theme")
eq(Theme.BackingAlpha(), Theme.OPACITY.light, "  their opacity")
eq(DB.look.pending, false, "  and marked put back")
eq(rec.at, 22, "22: the reload step")

-- A finished run's snapshot is replaced by the next run's.
SlashCmdList.GLASSQUESTTRACKER("theme class")
fp("steps gqt look")
rec = ForeverProbeDB.steps.records["TrackerProbe/look"]
eq(DB.look.theme, "class", "a new run after a finished one keeps the look of now")
eq(DB.look.pending, true, "  to put back")
SlashCmdList.GLASSQUESTTRACKER("theme clear")
fp("gqt restore")
eq(Theme.Name(), "class", "/fp gqt restore puts a stopped run's look back")
eq(DB.look.pending, false, "  and marks it")
fp("gqt restore")
check(logHas("nothing to put back"), "  a second restore has nothing to do")

-- A failure recorded by the addon fails step 20 (checked on a fresh walk).
GQT.failures["hook:test"] = "no EndLayout"
fp("steps gqt look")
rec = ForeverProbeDB.steps.records["TrackerProbe/look"]
for i = 2, 19 do
    local step = FP.procedures["TrackerProbe/look"].steps[i]
    if step.auto then -- ran on arrival
    elseif step.run then S.Run() elseif step.ask then S.Answer(true) else S.Skip() end
    settle()
end
eq(rec.results[20].check, "FAIL", "20: a recorded failure fails the step")
check(logHas("failure hook:test: no EndLayout"), "  and is named in the log")
GQT.failures["hook:test"] = nil

-- The glass checks catch a broken look, not only a theme name.
local steps = FP.procedures["TrackerProbe/look"].steps
local g = Panel._test.g()
SlashCmdList.GLASSQUESTTRACKER("theme clear")
check((steps[7].check()), "(the back-to-clear check passes on the real look)")
g.wash:Show()
check(not (steps[7].check()), "a wash left showing (the gradient bug) fails it")
g.wash:Hide()
Panel._test.frame():Hide()
check(not (steps[7].check()), "a hidden glass fails it")
Panel._test.frame():Show()
WoW.asBlizzard(function() ObjectiveTrackerFrame.Header.Background:SetAlpha(1) end)
GQT.API.Unfade(ObjectiveTrackerFrame.Header.Background)
WoW.asBlizzard(function() ObjectiveTrackerFrame.Header.Background:SetAlpha(1) end)
check(not (steps[7].check()), "the gold header bar back fails it")
GQT.Skin.Apply()
check((steps[7].check()), "(and passes again once the skin is reapplied)")

------------------------------------------------------------------------------
-- /fp steps gqt collapse: the hand steps alone, to redo them without the themes
------------------------------------------------------------------------------
fp("steps gqt collapse")
rec = ForeverProbeDB.steps.records["TrackerProbe/collapse"]
check(rec and rec.status == "active", "/fp steps gqt collapse starts")
eq(#FP.procedures["TrackerProbe/collapse"].steps, 9, "the state, the seven hand steps, the reload")
eq(rec.results[1].check, "PASS", "1: the glass is on, on arrival")
eq(rec.at, 2, "at 2")
S.Next(); settle()
eq(rec.results[2].check, "FAIL", "2: Next without collapsing still fails")
S.Back(); settle()
WoW.collapse(true)
nextStep(2, "2: collapsed")
WoW.collapse(false); WoW.layout("QuestObjectiveTracker", { blocks = 2 })
nextStep(3, "3: expanded")
eq(rec.results[4].status, "done", "4: the snapshot, on arrival")
WoW.collapseModule("QuestObjectiveTracker", true); WoW.layout("QuestObjectiveTracker", { shown = true })
nextStep(5, "5: a section collapsed")
WoW.collapseModule("QuestObjectiveTracker", false); WoW.layout("QuestObjectiveTracker", { blocks = 2 })
nextStep(6, "6: and expanded")
answer(7, false)
WoW.editMode(true); WoW.editMode(false)
nextStep(8, "8: Edit Mode opened and closed")
eq(rec.at, 9, "9: the reload step")
eq(Theme.Name(), "clear", "it changes no theme")

------------------------------------------------------------------------------
-- The routine counts only within an installed pass (#10's review)
------------------------------------------------------------------------------
rawset(_G, "GlassQuestTracker", nil)   -- as if the addon were disabled
WoW.fire("QUEST_ACCEPTED", 1)
WoW.fire("PLAYER_REGEN_DISABLED")
DB.log[#DB.log + 1] = "--"
fp("gqt routine")
check(not logHas("[x] accept") and not logHas("[x] fight"), "with no pass installed, nothing counts")
fp("gqt hook")
check(logHas("pass A installed"), "without the addon, pass A installs")
eq(DB.mode, "A", "  and is kept for the next /reload")
local function routine()
    DB.log[#DB.log + 1] = "--"
    fp("gqt routine")
    local out = {}
    for i = #DB.log, 1, -1 do
        if DB.log[i] == "--" then break end
        table.insert(out, 1, DB.log[i])
    end
    return table.concat(out, "\n")
end
local r = routine()
check(not r:find("[x] accept", 1, true), "a quest accepted before the pass doesn't count")
check(not r:find("[x] fight", 1, true), "nor a fight")
WoW.fire("QUEST_ACCEPTED", 2)
WoW.fire("PLAYER_REGEN_DISABLED")
r = routine()
check(r:find("[x] accept", 1, true) ~= nil and r:find("[x] fight", 1, true) ~= nil, "after it, both count")
WoW.collapse(true)
r = routine()
check(not r:find("[x] collapse", 1, true), "one container collapse isn't the collapse step")
check(r:find("tracker collapsed, not expanded", 1, true) ~= nil, "  what's missing is shown")
WoW.collapse(false)
WoW.collapseModule("QuestObjectiveTracker", true)
WoW.collapseModule("QuestObjectiveTracker", false)
r = routine()
check(r:find("[x] collapse", 1, true) ~= nil, "both headers both ways: the step is done")

eq(#errors, 0, "no error reached the error handler")
for _, e in ipairs(errors) do io.write("    " .. e .. "\n") end
done("test_probe")
