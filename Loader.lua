-- language: Luau, file: Loader.lua, target: Roblox executor (Synapse/Fluxus/Solara)
-- entry point: loadstring(game:HttpGet("<raw loader url>"))()
local REPO = "SidedRegent133/ROBLOX-TT"
local BRANCH = "main"

local function fetch(file)
    -- cache-buster: raw.githubusercontent caches for ~5 min, which serves stale
    -- builds right after a push
    local url = ("https://raw.githubusercontent.com/%s/%s/%s?t=%d"):format(REPO, BRANCH, file, os.time())
    return game:HttpGet(url)
end

local function boot()
    local source = fetch("Gui.lua")
    local chunk, compileErr = loadstring(source)
    if not chunk then
        error("Gui.lua failed to compile: " .. tostring(compileErr))
    end

    local gui = chunk()
    if type(gui) ~= "table" or type(gui.Init) ~= "function" then
        error("Gui.lua did not return a module with Init()")
    end

    gui.Init()
    print("[TT] gui up")
    return gui
end

local ok, err = pcall(boot)
if not ok then
    warn("[TT] boot failed: " .. tostring(err))
end
