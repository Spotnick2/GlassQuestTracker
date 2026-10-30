-- The skin: the stock art steps aside on the first pass and on every layout,
-- stays aside when Blizzard shows it again, and "stock" gives it all back.
dofile("tests/wow_stubs.lua")
dofile("tests/harness.lua")

local function tracker() return ObjectiveTrackerFrame end
local function quests() return QuestObjectiveTracker end

-- Blizzard laid out before we started (Manager.lua:215): the first pass
-- still styles what exists.
local GQT = loadAddon({ before = function()
    WoW.layout("QuestObjectiveTracker", { blocks = 1, items = 1 })
end })
check(GQT.Skin.started, "the skin started after PLAYER_ENTERING_WORLD")
eq(next(GQT.failures), nil, "no failures")
for k, v in pairs(GQT.failures) do io.write("    " .. k .. ": " .. v .. "\n") end
eq(quests().usedRightEdgeFrames.item1:GetNormalTexture():GetAlpha(), 0, "an item button laid out before start is faded")

-- The container.
local t = tracker()
eq(t.NineSlice:GetAlpha(), 0, "NineSlice faded")
eq(t.Header.Background:GetAlpha(), 0, "the container header's gold bar faded")
local mn = t.Header.MinimizeButton:GetNormalTexture()
check(mn:IsDesaturated(), "container minimize desaturated")
near(select(3, mn:GetVertexColor()), GQT.Blizzard.TINT[3], "container minimize tinted")
check(t.Header.MinimizeButton:GetHighlightTexture():IsDesaturated(), "its red highlight tinted too")

-- Every module header, shown or not: blanked (alpha can't hold against AddAnim).
for _, name in ipairs(WoW.MODULE_NAMES) do
    local h = rawget(_G, name).Header
    check(h.Background:GetAtlas() == nil and h.Background:GetTexture() == nil, name .. " header bar blanked")
    check(h.Shine:GetAtlas() == nil and h.Glow:GetAtlas() == nil, name .. " shine and glow blanked")
    check(h.MinimizeButton:GetNormalTexture():IsDesaturated(), name .. " minimize tinted")
end
check(t.Header.Background:GetAtlas() ~= nil, "a faded region keeps its art (fade is alpha only)")

-- A layout with every pooled extra.
WoW.layout("QuestObjectiveTracker", { blocks = 2, items = 1, groups = 1, bars = 1 })
local m = quests()
local item, group, bar = m.usedRightEdgeFrames.item1, m.usedRightEdgeFrames.group1, m.usedProgressBars.bar1
eq(item:GetNormalTexture():GetAlpha(), 0, "item button frame faded")
eq(item:GetPushedTexture():GetAlpha(), 0, "item button pushed art faded")
eq(group:GetDisabledTexture():GetAlpha(), 0, "find-group button disabled art faded")
for _, key in ipairs({ "BorderLeft", "BorderRight", "BorderMid" }) do
    eq(bar.Bar[key]:GetAlpha(), 0, "progress bar " .. key .. " faded")
end

-- Pool reuse: the next layout hands the same button back; Blizzard showing
-- or re-alphaing it is undone at once.
WoW.layout("QuestObjectiveTracker", { blocks = 2, items = 2 })
eq(m.usedRightEdgeFrames.item1, item, "the pool hands back the same button")
eq(m.usedRightEdgeFrames.item2:GetNormalTexture():GetAlpha(), 0, "a new pooled button is faded")
WoW.asBlizzard(function()
    item:GetNormalTexture():Show()
    item:GetNormalTexture():SetAlpha(1)
end)
eq(item:GetNormalTexture():GetAlpha(), 0, "Blizzard's Show/SetAlpha is faded again")

-- Collapse swaps the minimize atlas; the tint stays.
WoW.collapseModule("QuestObjectiveTracker", true)
local qn = m.Header.MinimizeButton:GetNormalTexture()
eq(qn:GetAtlas(), "ui-questtrackerbutton-secondary-expand", "Blizzard swapped the atlas")
check(qn:IsDesaturated(), "still tinted after the swap")

-- Edit Mode's Opacity while glass is on: remembered, still faded.
WoW.asBlizzard(function() t.NineSlice:SetAlpha(0.6) end)
eq(t.NineSlice:GetAlpha(), 0, "Edit Mode Opacity doesn't bring the NineSlice back")

-- Stock: everything back as Blizzard had it, the latest Opacity included.
GQT._test.slash("theme stock")
eq(GlassQuestTrackerDB.theme, "stock", "theme saved")
near(t.NineSlice:GetAlpha(), 0.6, "NineSlice back at the latest alpha Blizzard asked for")
eq(t.Header.Background:GetAlpha(), 1, "gold bar back")
eq(m.Header.Background:GetAtlas(), "UI-QuestTracker-Secondary-Objective-Header", "module header bar back")
eq(m.Header.Shine:GetAtlas(), "UI-QuestTracker-OBJFX-Shine", "shine back")
eq(item:GetNormalTexture():GetAlpha(), 1, "item button frame back")
eq(bar.Bar.BorderMid:GetAlpha(), 1, "progress bar border back")
check(not qn:IsDesaturated(), "minimize untinted")
eq(select(1, qn:GetVertexColor()), 1, "minimize white again")
eq(qn:GetAtlas(), "ui-questtrackerbutton-secondary-expand", "untint leaves Blizzard's current atlas alone")
WoW.asBlizzard(function() t.NineSlice:SetAlpha(0.3) end)
near(t.NineSlice:GetAlpha(), 0.3, "stock: Blizzard's alpha writes stand")

-- Stock lays out stock.
WoW.layout("QuestObjectiveTracker", { blocks = 1, items = 3 })
eq(m.usedRightEdgeFrames.item3:GetNormalTexture():GetAlpha(), 1, "a layout under stock styles nothing")

-- And back to glass: re-applied to everything, the new button included.
GQT._test.slash("theme clear")
eq(rawget(GlassQuestTrackerDB, "theme"), nil, "the default isn't saved")
eq(t.NineSlice:GetAlpha(), 0, "NineSlice faded again")
eq(m.Header.Background:GetAtlas(), nil, "module header blanked again")
eq(m.usedRightEdgeFrames.item3:GetNormalTexture():GetAlpha(), 0, "the button laid out under stock is faded")
check(qn:IsDesaturated(), "minimize tinted again")
GQT._test.slash("theme stock")
near(t.NineSlice:GetAlpha(), 0.3, "a second restore gives back the alpha Blizzard set while stock")

-- A saved "stock" starts stock: nothing touched.
GQT = loadAddon({ db = { theme = "stock" } })
t = tracker()
eq(t.NineSlice:GetAlpha(), 0, "(the stub's NineSlice starts at Blizzard's alpha 0)")
eq(t.Header.Background:GetAlpha(), 1, "stock from login: the gold bar is untouched")
eq(quests().Header.Background:GetAtlas(), "UI-QuestTracker-Secondary-Objective-Header", "stock from login: header untouched")
check(not t.Header.MinimizeButton:GetNormalTexture():IsDesaturated(), "stock from login: minimize untouched")

-- An unknown name changes nothing.
GQT._test.slash("theme sparkly")
eq(GlassQuestTrackerDB.theme, "stock", "an unknown theme is refused")
check(table.concat(WoW.chat, "\n"):find("theme is stock", 1, true), "and the current one is named")

-- No tracker (another build): recorded, nothing thrown.
GQT = loadAddon({ before = function() rawset(_G, "ObjectiveTrackerFrame", nil) end })
check(not GQT.Skin.started, "no tracker: the skin doesn't start")
check(GQT.failures.tracker ~= nil, "no tracker: /gqt failures says so")
GQT._test.slash("theme smoked")
eq(GlassQuestTrackerDB.theme, "smoked", "no tracker: settings still work")

-- A module without a header or pools (another build): skipped.
GQT = loadAddon({ before = function()
    rawset(QuestObjectiveTracker, "Header", nil)
    rawset(QuestObjectiveTracker, "usedBlocks", nil)
end })
WoW.layout("QuestObjectiveTracker", { blocks = 1, items = 1 })
eq(QuestObjectiveTracker.usedRightEdgeFrames.item1:GetNormalTexture():GetAlpha(), 0, "headerless module still styled")
check(GQT.failures["hook:collapse:QuestObjectiveTracker"] == nil, "no header: no collapse hook wanted")

-- A module only the container lists (a later build's): hooked and styled too.
local extra
GQT = loadAddon({ before = function() extra = WoW.addModule("NewObjectiveTracker") end })
eq(extra.Header.Background:GetAtlas(), nil, "a container-only module's header is blanked")
WoW.layout(extra, { blocks = 1, items = 1 })
eq(extra.usedRightEdgeFrames.item1:GetNormalTexture():GetAlpha(), 0, "and its layouts are hooked")

done("test_skin")
