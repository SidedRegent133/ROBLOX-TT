-- language: Luau, file: Loader.lua, target: Roblox executor (Synapse/Fluxus/Solara)
-- entry point: loadstring(game:HttpGet("<raw loader url>"))()
local REPO = "SidedRegent133/ROBLOX-TT"
local BRANCH = "main"

local function fetch(file)
    local url = ("https://raw.githubusercontent.com/%s/%s/%s"):format(REPO, BRANCH, file)
    return game:HttpGet(url)
end

local function boot()
    local chunk, compileErr = loadstring(fetch("Gui.lua"))
    if not chunk then
        error("Gui.lua failed to compile: " .. tostring(compileErr))
    end

    local gui = chunk()
    if type(gui) ~= "table" or type(gui.Init) ~= "function" then
        error("Gui.lua did not return a module with Init()")
    end

    gui.Init()
    return gui
end

local ok, err = pcall(boot)
if not ok then
    warn("[TT] boot failed: " .. tostring(err))
end
