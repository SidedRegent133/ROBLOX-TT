-- language: Luau, file: Loader.lua, target: Roblox executor (Synapse/Fluxus/Solara)
-- entry point: loadstring(game:HttpGet("<raw loader url>"))()
--
-- raw.githubusercontent caches the branch path for minutes, which serves stale
-- builds right after a push. resolve the newest commit sha first, then fetch
-- Gui.lua pinned to that immutable revision.
local REPO = "SidedRegent133/ROBLOX-TT"
local BRANCH = "main"

local HttpService = game:GetService("HttpService")

local function latestSha()
    local ok, body = pcall(function()
        return game:HttpGet(("https://api.github.com/repos/%s/commits/%s"):format(REPO, BRANCH))
    end)
    if not ok or type(body) ~= "string" then
        return nil
    end

    local decoded, data = pcall(function()
        return HttpService:JSONDecode(body)
    end)
    if decoded and type(data) == "table" and type(data.sha) == "string" then
        return data.sha
    end
    return body:match('"sha"%s*:%s*"(%x+)"')
end

local function fetch(file)
    local sha = latestSha()
    local ref = sha or BRANCH
    local url = ("https://raw.githubusercontent.com/%s/%s/%s"):format(REPO, ref, file)
    return game:HttpGet(url), ref
end

local function boot()
    local source, ref = fetch("Gui.lua")
    local chunk, compileErr = loadstring(source)
    if not chunk then
        error("Gui.lua failed to compile: " .. tostring(compileErr))
    end

    local gui = chunk()
    if type(gui) ~= "table" or type(gui.Init) ~= "function" then
        error("Gui.lua did not return a module with Init()")
    end

    gui.Init()
    print("[TT] gui up @ " .. tostring(ref):sub(1, 7))
    return gui
end

local ok, err = pcall(boot)
if not ok then
    warn("[TT] boot failed: " .. tostring(err))
end
