-- TrackerProbe: a throwaway measuring addon for Glass Quest Tracker (never shipped).
-- Answers the questions docs/FOREVER-PROBE.md lists, on the live client. Every
-- line goes to chat AND to TrackerProbeDB.log, so the results can be read from
-- WTF\Account\<account>\SavedVariables\TrackerProbe.lua after a /reload or logout.
--
--   /gqtprobe frames       P1 P2 P8 P9: the tracker, its modules, blocks and lines, fonts, other addons
--   /gqtprobe nine         P3: NineSlice and Header anchors, collapsed state; toggles a red overlay on NineSlice
--   /gqtprobe cvars        P4: autoQuestWatch, questPOI, the watch limit
--   /gqtprobe accept on|off|watch   P5: log QUEST_ACCEPTED (watch: also AddQuestWatch from addon code)
--   /gqtprobe hook         P6: taint pass A (hooks + a child panel), kept across /reload
--   /gqtprobe restyle      P7: taint pass B (pass A + fade, blank, shadows, tint), kept across /reload
--   /gqtprobe off          no pass at the next /reload
--   /gqtprobe counts       how often each hook ran
--   /gqtprobe clear        empty the log
--
-- It follows the addon's own rule: only C widget methods on Blizzard objects,
-- no field writes on their tables, state in our own tables.

local LOADED_AT_FILE_SCOPE = {
    tracker = C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("Blizzard_ObjectiveTracker"),
    frame = rawget(_G, "ObjectiveTrackerFrame") ~= nil,
}

local db
local function str(v)
    if issecretvalue and issecretvalue(v) then return "<secret>" end
    return tostring(v)
end

local function say(...)
    local parts = {}
    for i = 1, select("#", ...) do parts[#parts + 1] = str((select(i, ...))) end
    local line = table.concat(parts, " ")
    print("|cff7fd4ffgqtprobe|r " .. line)
    if db then
        db.log[#db.log + 1] = date("%H:%M:%S") .. " " .. line
        if #db.log > 3000 then table.remove(db.log, 1) end
    end
end

-- A method's results, or "err:..." when it throws.
local function call(obj, method, ...)
    if type(obj) ~= "table" or type(obj[method]) ~= "function" then return "n/a" end
    local r = { pcall(obj[method], obj, ...) }
    if not r[1] then return "err:" .. str(r[2]) end
    local out = {}
    for i = 2, #r do out[#out + 1] = str(r[i]) end
    if #out == 0 then return "nil" end
    return table.concat(out, ",")
end

local function tracker() return rawget(_G, "ObjectiveTrackerFrame") end

local FALLBACK_MODULES = { "ScenarioObjectiveTracker", "UIWidgetObjectiveTracker", "CampaignQuestObjectiveTracker",
    "QuestObjectiveTracker", "AdventureObjectiveTracker", "AchievementObjectiveTracker",
    "MonthlyActivitiesObjectiveTracker", "InitiativeTasksObjectiveTracker", "ProfessionsRecipeTracker",
    "BonusObjectiveTracker", "WorldQuestObjectiveTracker" }

-- The modules the container holds, else every known global module.
local function modules()
    local t, list = tracker(), {}
    if t and type(t.modules) == "table" and #t.modules > 0 then
        for _, m in ipairs(t.modules) do list[#list + 1] = m end
        return list, "container"
    end
    for _, name in ipairs(FALLBACK_MODULES) do
        local m = rawget(_G, name)
        if m then list[#list + 1] = m end
    end
    return list, "globals"
end

local function moduleName(m)
    for _, name in ipairs(FALLBACK_MODULES) do
        if rawget(_G, name) == m then return name end
    end
    return call(m, "GetName")
end

local function eachBlock(m, fn)
    if type(m.usedBlocks) ~= "table" then return end
    for _, blocks in pairs(m.usedBlocks) do
        if type(blocks) == "table" then
            for _, block in pairs(blocks) do fn(block) end
        end
    end
end

local function eachLine(block, fn)
    if type(block.usedLines) ~= "table" then return end
    for _, line in pairs(block.usedLines) do fn(line) end
end

--------------------------------------------------------------------------------
-- P1 P2 P8 P9: frames
--------------------------------------------------------------------------------

local function frames()
    local t = tracker()
    say("build " .. table.concat({ GetBuildInfo() }, " "))
    say("P1 at file scope: Blizzard_ObjectiveTracker loaded=" .. str(LOADED_AT_FILE_SCOPE.tracker)
        .. " ObjectiveTrackerFrame exists=" .. str(LOADED_AT_FILE_SCOPE.frame))
    if not t then return say("P1 ObjectiveTrackerFrame: MISSING") end
    say("P1 tracker: protected=" .. call(t, "IsProtected") .. " strata=" .. call(t, "GetFrameStrata")
        .. " level=" .. call(t, "GetFrameLevel") .. " size=" .. call(t, "GetSize") .. " scale=" .. call(t, "GetScale")
        .. " shown=" .. call(t, "IsShown") .. " visible=" .. call(t, "IsVisible") .. " alpha=" .. call(t, "GetAlpha"))
    say("P1 tracker: inDefault=" .. call(t, "IsInDefaultPosition") .. " editModeHeight=" .. str(t.editModeHeight)
        .. " isCollapsed=" .. str(t.isCollapsed) .. " points=" .. call(t, "GetNumPoints")
        .. " top=" .. call(t, "GetTop") .. " bottom=" .. call(t, "GetBottom"))
    if t.NineSlice then
        say("P2 NineSlice: alpha=" .. call(t.NineSlice, "GetAlpha") .. " level=" .. call(t.NineSlice, "GetFrameLevel")
            .. " top=" .. call(t.NineSlice, "GetTop") .. " bottom=" .. call(t.NineSlice, "GetBottom")
            .. " shown=" .. call(t.NineSlice, "IsShown"))
    end
    local h = t.Header
    if h then
        say("P2 Header: text=" .. call(h.Text, "GetText") .. " bg atlas=" .. call(h.Background, "GetAtlas")
            .. " minimize=" .. str(h.MinimizeButton ~= nil) .. " filter shown=" .. call(h.FilterButton, "IsShown"))
    end
    local list, from = modules()
    say("P2 modules (" .. from .. "): " .. #list)
    for _, m in ipairs(list) do
        local blocks, lines, items = 0, 0, 0
        eachBlock(m, function(b)
            blocks = blocks + 1
            if b.ItemButton then items = items + 1 end
            eachLine(b, function() lines = lines + 1 end)
        end)
        say(("P2  %s order=%s shown=%s collapsed=%s contentsHeight=%s headerHeight=%s blocks=%d lines=%d items=%d")
            :format(moduleName(m), str(m.uiOrder), call(m, "IsShown"), str(m.isCollapsed), str(m.contentsHeight),
                str(m.headerHeight), blocks, lines, items))
        if m.Header then
            say("P2    header: text=" .. call(m.Header.Text, "GetText") .. " bg=" .. call(m.Header.Background, "GetAtlas")
                .. " AddAnim=" .. str(m.Header.AddAnim ~= nil))
        end
        local shown = 0
        eachBlock(m, function(b)
            shown = shown + 1
            if shown > 2 then return end
            say("P2    block: header=" .. call(b.HeaderText, "GetText") .. " top=" .. call(b, "GetTop")
                .. " shown=" .. call(b, "IsShown") .. " item=" .. str(b.ItemButton ~= nil))
            if b.ItemButton then
                say("P2      item: normal=" .. call(b.ItemButton:GetNormalTexture(), "GetTexture")
                    .. " pushed=" .. str(b.ItemButton:GetPushedTexture() ~= nil) .. " protected="
                    .. call(b.ItemButton, "IsProtected"))
            end
            eachLine(b, function(line)
                say("P2      line: text=" .. call(line.Text, "GetText") .. " dash=" .. str(line.Dash ~= nil)
                    .. " icon=" .. str(line.Icon ~= nil))
            end)
        end)
        if type(m.usedRightEdgeFrames) == "table" then
            local n = 0
            for _ in pairs(m.usedRightEdgeFrames) do n = n + 1 end
            say("P2    right-edge frames: " .. n)
        end
    end
    -- P8 fonts.
    for _, name in ipairs({ "ObjectiveTrackerLineFont", "ObjectiveTrackerHeaderFont" }) do
        local f = rawget(_G, name)
        say("P8 " .. name .. ": font=" .. call(f, "GetFont") .. " shadow=" .. call(f, "GetShadowOffset")
            .. " color=" .. call(f, "GetShadowColor"))
    end
    -- P9 other trackers.
    for _, a in ipairs({ "Questie", "RXPGuides", "ForeverUI", "DialogueUI", "Leatrix_Plus", "ElvUI" }) do
        local ok, on = pcall(C_AddOns.IsAddOnLoaded, a)
        if ok and on then say("P9 loaded: " .. a) end
    end
end

--------------------------------------------------------------------------------
-- P3: NineSlice
--------------------------------------------------------------------------------

local overlay
local function points(f)
    if not f then return "n/a" end
    local ok, n = pcall(f.GetNumPoints, f)
    if not ok then return "err" end
    local out = {}
    for i = 1, (type(n) == "number" and n or 0) do
        local p = { pcall(f.GetPoint, f, i) }
        if p[1] then
            -- GetPoint: point, relativeTo, relativePoint, x, y.
            local rel = p[3]
            local t = tracker() or {}
            local relName = rel == nil and "nil" or rel == t and "tracker" or rel == t.Header and "Header"
                or rel == t.NineSlice and "NineSlice" or call(rel, "GetName")
            out[#out + 1] = ("%s->%s.%s(%s,%s)"):format(str(p[2]), relName, str(p[4]), str(p[5]), str(p[6]))
        end
    end
    return n .. ": " .. table.concat(out, " ")
end

local function nine()
    local t = tracker()
    if not t then return say("P3 no tracker") end
    -- Edit Mode's frame being shown, not IsEditModeActive: that's Blizzard Lua.
    say("P3 isCollapsed=" .. str(t.isCollapsed) .. " editMode=" .. call(rawget(_G, "EditModeManagerFrame"), "IsShown")
        .. " shown=" .. call(t, "IsShown"))
    say("P3 NineSlice points " .. points(t.NineSlice))
    say("P3 NineSlice top=" .. call(t.NineSlice, "GetTop") .. " bottom=" .. call(t.NineSlice, "GetBottom")
        .. " height=" .. call(t.NineSlice, "GetHeight"))
    say("P3 Header points " .. points(t.Header) .. " bottom=" .. call(t.Header, "GetBottom"))
    if not overlay then
        overlay = CreateFrame("Frame", nil, UIParent)
        overlay:SetFrameStrata("HIGH")
        local tex = overlay:CreateTexture(nil, "OVERLAY")
        tex:SetAllPoints()
        tex:SetColorTexture(1, 0, 0, 0.25)
        overlay:SetPoint("TOPLEFT", t.NineSlice, "TOPLEFT")
        overlay:SetPoint("BOTTOMRIGHT", t.NineSlice, "BOTTOMRIGHT")
        overlay:Hide()
    end
    overlay:SetShown(not overlay:IsShown())
    say("P3 red overlay on NineSlice: " .. (overlay:IsShown() and "on (look at it collapsed, empty, in Edit Mode)" or "off"))
    say("P3 overlay IsMouseOver=" .. call(overlay, "IsMouseOver"))
end

--------------------------------------------------------------------------------
-- P4 P5: watches
--------------------------------------------------------------------------------

local function cvars()
    for _, name in ipairs({ "autoQuestWatch", "questPOI" }) do
        local info = C_CVar and C_CVar.GetCVarInfo and { pcall(C_CVar.GetCVarInfo, name) }
        say("P4 " .. name .. ": GetCVar=" .. str(GetCVar(name)) .. " info=" .. (info and info[1]
            and (str(info[2]) .. " default=" .. str(info[3])) or "n/a"))
    end
    local c = Constants and Constants.QuestWatchConsts
    say("P4 Constants.QuestWatchConsts.MAX_QUEST_WATCHES=" .. str(c and c.MAX_QUEST_WATCHES)
        .. " MAX_WATCHABLE_QUESTS=" .. str(rawget(_G, "MAX_WATCHABLE_QUESTS"))
        .. " GetNumQuestWatches=" .. str(C_QuestLog.GetNumQuestWatches()))
    local _, numQuests = C_QuestLog.GetNumQuestLogEntries()
    say("P4 quests in log=" .. str(numQuests))
end

local function watchType(questID) return str(C_QuestLog.GetQuestWatchType(questID)) end

local function onAccepted(...)
    if not db.accept then return end
    local n = select("#", ...)
    local questID = ...
    say("P5 QUEST_ACCEPTED args=" .. n .. " questID=" .. str(questID) .. " type=" .. type(questID)
        .. " watchType now=" .. watchType(questID) .. " logIndex=" .. str(C_QuestLog.GetLogIndexForQuestID(questID)))
    if db.accept == "watch" then
        local ok, r = pcall(C_QuestLog.AddQuestWatch, questID)
        say("P5 AddQuestWatch now: ok=" .. str(ok) .. " returned=" .. str(r) .. " watchType=" .. watchType(questID))
    end
    C_Timer.After(0, function()
        say("P5 next frame: watchType=" .. watchType(questID) .. " watches=" .. str(C_QuestLog.GetNumQuestWatches()))
        if db.accept == "watch" and C_QuestLog.GetQuestWatchType(questID) == nil then
            local ok, r = pcall(C_QuestLog.AddQuestWatch, questID)
            say("P5 AddQuestWatch next frame: ok=" .. str(ok) .. " returned=" .. str(r) .. " watchType=" .. watchType(questID))
        end
    end)
end

--------------------------------------------------------------------------------
-- P6 P7: taint passes
--------------------------------------------------------------------------------

local counts = {}
local installed = false
local panel
local styled = setmetatable({}, { __mode = "k" })
local faded = setmetatable({}, { __mode = "k" })

local function count(key) counts[key] = (counts[key] or 0) + 1 end

-- Something is laid out: any module the container shows.
local function populated()
    for _, m in ipairs((modules())) do
        local ok, shown = pcall(m.IsShown, m)
        if ok and not (issecretvalue and issecretvalue(shown)) and shown then return true end
    end
    return false
end

-- The child panel, anchored the way Panel.lua will be.
local function placePanel()
    local t = tracker()
    if not (t and panel) then return end
    panel:ClearAllPoints()
    panel:SetPoint("TOPLEFT", t.NineSlice, "TOPLEFT", 16, 0)
    local collapsed = t.isCollapsed == true
    if collapsed or not populated() then
        panel:SetPoint("BOTTOMRIGHT", t.Header, "BOTTOMRIGHT", 0, -4)
        count("panel:header")
    else
        panel:SetPoint("BOTTOMRIGHT", t.NineSlice, "BOTTOMRIGHT", -2, 0)
        count("panel:nineslice")
    end
end

local function refade(region)
    local s = faded[region]
    if not s or s.busy then return end
    s.busy = true
    pcall(region.SetAlpha, region, 0)
    s.busy = false
end

local function fade(region)
    if type(region) ~= "table" or faded[region] then return end
    faded[region] = {}
    for _, m in ipairs({ "Show", "SetShown", "SetAlpha" }) do
        if type(region[m]) == "function" then
            hooksecurefunc(region, m, function(self) count("refade"); refade(self) end)
        end
    end
    refade(region)
end

local function shade(fs)
    if type(fs) ~= "table" or styled[fs] or not fs.SetShadowOffset then return end
    styled[fs] = true
    fs:SetShadowOffset(1, -1)
    fs:SetShadowColor(0, 0, 0, 1)
end

local function blank(tex)
    if type(tex) ~= "table" or styled[tex] or not tex.SetTexture then return end
    styled[tex] = true
    tex:SetTexture(nil)
end

local function tint(button)
    if type(button) ~= "table" or styled[button] then return end
    styled[button] = true
    for _, get in ipairs({ "GetNormalTexture", "GetPushedTexture" }) do
        local tex = button[get] and button[get](button)
        if tex then tex:SetDesaturated(true); tex:SetVertexColor(0.75, 0.9, 1) end
    end
    local hl = button.GetHighlightTexture and button:GetHighlightTexture()
    if hl then hl:SetAlpha(0.3) end
end

local function restyleModule(m)
    if m.Header then
        blank(m.Header.Background); blank(m.Header.Shine); blank(m.Header.Glow)
        shade(m.Header.Text)
        tint(m.Header.MinimizeButton)
    end
    eachBlock(m, function(b)
        shade(b.HeaderText)
        if b.ItemButton then
            local n, p = b.ItemButton:GetNormalTexture(), b.ItemButton:GetPushedTexture()
            if n then fade(n) end
            if p then fade(p) end
        end
        eachLine(b, function(line) shade(line.Text); shade(line.Dash) end)
    end)
end

local function restyleAll()
    local t = tracker()
    fade(t.NineSlice)
    if t.Header then
        fade(t.Header.Background)
        shade(t.Header.Text)
        tint(t.Header.MinimizeButton)
    end
    for _, m in ipairs((modules())) do restyleModule(m) end
end

local function install(mode)
    if installed then return say("pass already installed this session; /reload to change it") end
    local t = tracker()
    if not t then return say("P6 no tracker") end
    installed = true
    panel = CreateFrame("Frame", nil, t)
    panel:SetFrameLevel(t:GetFrameLevel())
    local tex = panel:CreateTexture(nil, "BACKGROUND")
    tex:SetAllPoints()
    tex:SetColorTexture(0.1, 0.5, 1, 0.18)
    local list, from = modules()
    for _, m in ipairs(list) do
        local name = moduleName(m)
        hooksecurefunc(m, "EndLayout", function(self)
            count("EndLayout:" .. name)
            placePanel()
            if mode == "B" then restyleModule(self) end
        end)
        if m.Header and m.Header.SetCollapsed then
            hooksecurefunc(m.Header, "SetCollapsed", function() count("SetCollapsed:" .. name) end)
        end
    end
    if t.Header and t.Header.SetCollapsed then
        hooksecurefunc(t.Header, "SetCollapsed", function() count("SetCollapsed:container"); placePanel() end)
    end
    local em = rawget(_G, "EditModeManagerFrame")
    if em then
        em:HookScript("OnShow", function() count("EditMode:show") end)
        em:HookScript("OnHide", function() count("EditMode:hide"); placePanel() end)
    end
    placePanel()
    if mode == "B" then restyleAll() end
    say("pass " .. mode .. " installed on " .. #list .. " modules (" .. from .. "). Now /console taintLog 1 and run the routine.")
end

local function showCounts()
    local keys = {}
    for k in pairs(counts) do keys[#keys + 1] = k end
    table.sort(keys)
    if #keys == 0 then return say("no hook has run") end
    for _, k in ipairs(keys) do say(k .. " = " .. counts[k]) end
end

--------------------------------------------------------------------------------
-- Boot and command
--------------------------------------------------------------------------------

local boot = CreateFrame("Frame")
boot:RegisterEvent("ADDON_LOADED")
boot:RegisterEvent("PLAYER_ENTERING_WORLD")
boot:RegisterEvent("QUEST_ACCEPTED")
boot:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" and ... == "TrackerProbe" then
        TrackerProbeDB = type(TrackerProbeDB) == "table" and TrackerProbeDB or {}
        db = TrackerProbeDB
        db.log = type(db.log) == "table" and db.log or {}
        say("session start, build " .. table.concat({ GetBuildInfo() }, " ") .. ", pass=" .. str(db.mode)
            .. ", accept=" .. str(db.accept))
    elseif event == "PLAYER_ENTERING_WORLD" then
        -- The tracker's modules arrive after PLAYER_ENTERING_WORLD + VARIABLES_LOADED.
        if db and db.mode and not installed then
            C_Timer.After(1, function() install(db.mode) end)
        end
    elseif event == "QUEST_ACCEPTED" and db then
        onAccepted(...)
    end
end)

SLASH_TRACKERPROBE1 = "/gqtprobe"
SlashCmdList.TRACKERPROBE = function(msg)
    local cmd, arg = (msg or ""):lower():match("^%s*(%S*)%s*(.-)%s*$")
    if cmd == "frames" then frames()
    elseif cmd == "nine" then nine()
    elseif cmd == "cvars" then cvars()
    elseif cmd == "accept" then
        db.accept = (arg == "on" and true) or (arg == "watch" and "watch") or nil
        say("accept logging: " .. str(db.accept))
    elseif cmd == "hook" then db.mode = "A"; install("A")
    elseif cmd == "restyle" then db.mode = "B"; install("B")
    elseif cmd == "off" then db.mode = nil; say("no pass at the next /reload")
    elseif cmd == "counts" then showCounts()
    elseif cmd == "clear" then db.log = {}; say("log cleared")
    else
        say("frames | nine | cvars | accept on|off|watch | hook | restyle | off | counts | clear")
    end
end
