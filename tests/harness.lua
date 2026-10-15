-- harness.lua: assertions and the addon loader. dofile it after wow_stubs.lua.

local passed, failed = 0, 0

function check(cond, msg)
    if cond then passed = passed + 1 else
        failed = failed + 1
        io.write("  FAIL: " .. tostring(msg) .. "\n")
    end
end

function eq(actual, expected, msg)
    check(actual == expected, string.format("%s: expected %s, got %s", msg, tostring(expected), tostring(actual)))
end

function near(actual, expected, msg)
    check(type(actual) == "number" and math.abs(actual - expected) < 1e-6,
        string.format("%s: expected %s, got %s", msg, tostring(expected), tostring(actual)))
end

function done(name)
    io.write(string.format("%s: %d passed, %d failed\n", name, passed, failed))
    os.exit(failed == 0 and 0 or 1)
end

-- Every file line of the TOC, in load order, as written.
function tocLines()
    local lines = {}
    for line in io.lines("GlassQuestTracker.toc") do
        line = line:gsub("\r", "")
        if line ~= "" and not line:match("^#") then lines[#lines + 1] = line end
    end
    return lines
end

-- Lua files listed in the TOC, in load order.
function tocFiles()
    local files = {}
    for _, line in ipairs(tocLines()) do
        if line:match("%.lua$") then files[#files + 1] = (line:gsub("\\", "/")) end
    end
    return files
end

-- The embedded LibGlass-1.0 comes from a checkout, not from Libs\ (gitignored,
-- filled by the packager): $LIBGLASS, else ../LibGlass. No checkout fails the
-- run loudly; a silently skipped library would test nothing.
LIBGLASS_XML = "Libs\\LibGlass-1.0\\LibGlass-1.0.xml"
function libGlassRoot()
    local root = (os.getenv("LIBGLASS") or "../LibGlass"):gsub("\\", "/"):gsub("/$", "")
    local f = io.open(root .. "/LibGlass-1.0.xml", "rb")
    if not f then
        error("LibGlass checkout not found at " .. root .. " (no LibGlass-1.0.xml): clone "
              .. "github.com/Spotnick2/LibGlass there or set LIBGLASS", 0)
    end
    f:close()
    return root
end

-- The Lua files the library's XML loads, as paths, in order.
function libGlassScripts()
    local root = libGlassRoot()
    local f = assert(io.open(root .. "/LibGlass-1.0.xml", "rb"))
    local xml = f:read("*a"):gsub("<!%-%-.-%-%->", "")   -- listed in a comment is not loaded
    f:close()
    local files = {}
    for file in xml:gmatch('<Script%s+file="([^"]+)"') do
        local path = root .. "/" .. file:gsub("\\", "/")
        local src = io.open(path, "rb")
        if not src then error("LibGlass checkout at " .. root .. " is missing " .. file, 0) end
        src:close()
        files[#files + 1] = path
    end
    if #files == 0 then error("LibGlass-1.0.xml at " .. root .. " lists no Script files", 0) end
    return files
end

-- Load the addon the way the client does, in a fresh session: every TOC line
-- with (name, ns), the library's XML expanded in place, then ADDON_LOADED,
-- PLAYER_LOGIN and PLAYER_ENTERING_WORLD.
-- opts.db: saved variables. opts.before(): runs after the files load and
-- before ADDON_LOADED.
function loadAddon(opts)
    opts = opts or {}
    GlassQuestTracker, GlassQuestTrackerDB, LibStub = nil, nil, nil
    WoW.reset()
    local ns = {}
    for _, line in ipairs(tocLines()) do
        local files
        if line == LIBGLASS_XML then
            files = libGlassScripts()
        elseif line:match("%.lua$") then
            files = { (line:gsub("\\", "/")) }
        else
            error("the harness can't load TOC line " .. line, 0)
        end
        for _, file in ipairs(files) do
            local chunk = assert(loadfile(file))
            chunk("GlassQuestTracker", ns)
        end
    end
    if opts.db then GlassQuestTrackerDB = opts.db end
    if opts.before then opts.before() end
    WoW.fire("ADDON_LOADED", "GlassQuestTracker")
    WoW.fire("PLAYER_LOGIN")
    WoW.fire("PLAYER_ENTERING_WORLD", true, false)
    WoW.flushTimers(0)
    return GlassQuestTracker
end

-- ForeverProbe, the host TrackerProbe is a module of: $FOREVERPROBE, else
-- ..\ForeverProbe; nil without a checkout (CI without the host's token).
function foreverProbeRoot()
    local root = (os.getenv("FOREVERPROBE") or "../ForeverProbe"):gsub("\\", "/"):gsub("/$", "")
    local toc = io.open(root .. "/ForeverProbe.toc", "rb")
    if not toc then return nil end
    toc:close()
    return root
end

local function tocScripts(path)
    local f = assert(io.open(path, "rb"))
    local list = {}
    for line in f:read("*a"):gmatch("[^\r\n]+") do
        line = line:gsub("^%s+", ""):gsub("%s+$", "")
        if line:match("%.lua$") and not line:match("^#") then list[#list + 1] = (line:gsub("\\", "/")) end
    end
    f:close()
    return list
end

-- The host, as the client loads it (GlassChat's loadForeverProbe): every TOC
-- file with ("ForeverProbe", {}), then its ADDON_LOADED.
function loadForeverProbe(root)
    for _, file in ipairs(tocScripts(root .. "/ForeverProbe.toc")) do
        assert(loadfile(root .. "/" .. file))("ForeverProbe", {})
    end
    WoW.fire("ADDON_LOADED", "ForeverProbe")
    return ForeverProbe
end

-- TrackerProbe, after the host: its TOC's files with ("TrackerProbe", ns),
-- then its ADDON_LOADED. Returns the namespace (ns._test is the seam).
function loadProbe()
    local dir = "Tools/TrackerProbe/"
    local ns = {}
    for _, file in ipairs(tocScripts(dir .. "TrackerProbe.toc")) do
        assert(loadfile(dir .. file))("TrackerProbe", ns)
    end
    WoW.fire("ADDON_LOADED", "TrackerProbe")
    return ns
end
