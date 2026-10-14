-- Boot: the addon loads at login with no failure, and leaves only its own globals.
dofile("tests/wow_stubs.lua")
dofile("tests/harness.lua")

local before = {}
for k in pairs(_G) do before[k] = true end

local GQT = loadAddon()
eq(next(GQT.failures), nil, "no failures at login")
for k, v in pairs(GQT.failures) do io.write("    " .. k .. ": " .. v .. "\n") end
check(type(GQT.db) == "table", "saved settings ready")
eq(GQT.db, GlassQuestTrackerDB, "the settings are GlassQuestTrackerDB")

-- Our globals, and the library's loader; nothing else.
local ALLOWED = { GlassQuestTracker = true, GlassQuestTrackerDB = true, LibStub = true,
                  SLASH_GLASSQUESTTRACKER1 = true, SLASH_GLASSQUESTTRACKER2 = true }
for k in pairs(_G) do
    if not before[k] then check(ALLOWED[k], "no stray global: " .. tostring(k)) end
end
eq(SlashCmdList.GLASSQUESTTRACKER, GQT._test.slash, "/gqt registered")

-- The commands answer.
GQT._test.slash("version")
check(table.concat(WoW.chat, "\n"):find("measured on 1.60.1.70374", 1, true), "/gqt version")
WoW.chat = {}
GQT._test.slash("failures")
check(table.concat(WoW.chat, "\n"):find("no failures recorded", 1, true), "/gqt failures")
WoW.chat = {}
GQT._test.slash("")
check(table.concat(WoW.chat, "\n"):find("/gqt version", 1, true), "/gqt with no command prints the help")

-- Only what the player SET is saved.
GQT = loadAddon({ db = { junk = nil } })
eq(next(GlassQuestTrackerDB), nil, "an untouched profile saves nothing")

done("test_boot")
