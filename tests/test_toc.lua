-- The manifest, the pinned build, and the library's media.
dofile("tests/wow_stubs.lua")
dofile("tests/harness.lua")

local toc = io.open("GlassQuestTracker.toc"):read("*a")
check(toc:find("## Interface: 16001", 1, true), "interface 16001 (1.60.1; 11601 is the transposed-digit bug)")
check(toc:find("## Version: @project-version@", 1, true), "packager version token kept")
check(toc:find("## SavedVariables: GlassQuestTrackerDB", 1, true), "saved variables declared")
check(toc:find("## X-License: MIT", 1, true), "MIT, like its siblings")
check(io.open("LICENSE"):read("*a"):find("MIT License", 1, true), "LICENSE is MIT")
for _, f in ipairs(tocFiles()) do
    check(io.open(f, "r") ~= nil, "TOC file exists: " .. f)
end
eq(tocLines()[1], LIBGLASS_XML, "LibGlass-1.0 loads first")
eq(tocFiles()[1], "Compat.lua", "Compat is the first addon file")
eq(tocFiles()[#tocFiles()], "GlassQuestTracker.lua", "bootstrap loads last")
-- The packager replaces its tokens in EVERY file: never write one whole in Lua.
for _, f in ipairs(tocFiles()) do
    local src = io.open(f, "rb"):read("*a")
    local token = src:match("@project%-[%w-]+@") or src:match("@file%-[%w-]+@")
    check(not token, f .. " holds no packager token (found " .. tostring(token) .. ")")
end
local seen = {}
for _, f in ipairs(tocFiles()) do
    check(not seen[f], "TOC lists each file once: " .. f)
    seen[f] = true
end

local GQT = loadAddon()
eq(GQT.MEASURED_ON_BUILD, "1.60.1.70374", "MEASURED_ON_BUILD")

-- Every texture the library names ships with it. No Media of our own.
local root = libGlassRoot()
for size, S in pairs(GQT.Glass.SIZES) do
    for _, key in ipairs({ "mask", "rim", "dark", "shadow" }) do
        local f = root .. "/Media/" .. S[key] .. ".tga"
        check(io.open(f, "rb") ~= nil, size .. " texture exists: " .. f)
    end
end
eq(GQT.Glass.MEDIA, "Interface\\AddOns\\GlassQuestTracker\\Libs\\LibGlass-1.0\\Media\\",
   "Glass.MEDIA is the embedded copy's")
check(GQT.Glass ~= LibStub("LibGlass-1.0"), "Glass is our own instance, not the library")
eq(GQT.Glass.STYLE.thinRim, true, "the clean preset (thin rims)")

-- The dev-build notice: a deployed dev copy on another build says so once at login.
WoW.build, WoW.version = "70400", "dev"
loadAddon()
check(table.concat(WoW.chat, "\n"):find("differs from the one this addon was measured on", 1, true), "dev copy warns")
WoW.build, WoW.version = "70400", "v0.1.0"
loadAddon()
check(not table.concat(WoW.chat, "\n"):find("differs", 1, true), "a release keeps quiet")
WoW.build = "70374"

done("test_toc")
