-- language: Luau, file: Gui.lua, target: Roblox executor (Synapse/Fluxus/Solara), returns { Init } for Loader.lua
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local Gui = {}

------------------------------------------------------------- video sources
-- resolution order for VIDEOS:
--   1. USE_ASSET_IDS = true -> uploaded roblox video assets (dashboard upload,
--      Premium required), ids pasted into ASSET_IDS in the same slot order as FILES
--   2. HOSTED urls present   -> streamed straight from the host
--   3. otherwise             -> the mp4s sitting in this repo
local USE_ASSET_IDS = false

-- 17 clips, uploaded so the engine can stream them without a roblox upload
local HOSTED = {
    "https://files.catbox.moe/frzu3r.mp4",
    "https://files.catbox.moe/ropx9x.mp4",
    "https://files.catbox.moe/wybhcd.mp4",
    "https://files.catbox.moe/6rm81o.mp4",
    "https://files.catbox.moe/fq547k.mp4",
    "https://files.catbox.moe/fdsnar.mp4",
    "https://files.catbox.moe/f4bnen.mp4",
    "https://files.catbox.moe/zdhcfx.mp4",
    "https://files.catbox.moe/52sc6v.mp4",
    "https://files.catbox.moe/4phn8i.mp4",
    "https://files.catbox.moe/qzawf3.mp4",
    "https://files.catbox.moe/hq0ujg.mp4",
    "https://files.catbox.moe/sqxpik.mp4",
    "https://files.catbox.moe/w0w4gh.mp4",
    "https://files.catbox.moe/60zx96.mp4",
    "https://files.catbox.moe/nboibe.mp4",
    "https://files.catbox.moe/jn760x.mp4",
}

local ASSET_IDS = {
    -- "1234567890",
}

local REPO_RAW = "https://raw.githubusercontent.com/SidedRegent133/ROBLOX-TT/main/"

local FILES = {
    "0072decf9cdfee236c5363424fc4c22b.mp4",
    "242c039241f99043c9bf611a868ed5f1.mp4",
    "25f3b63fc238bdb8566e3b0068e8b028.mp4",
    "364bba9269d3b9f605929f78b509340c.mp4",
    "466db02d7e5aab9d6401094394b5f64e.mp4",
    "4e55a0aa7bbf36c8e6dcf04c399672c7.mp4",
    "651ea21b9ff0a53ae21cf9453d783d01.mp4",
    "980c0041725eae193e236fb596ace2f2.mp4",
    "9ccb69c63473ac48d6d280d25e6f467c.mp4",
    "aeafedb8839207732d688120d2dfe3bc.mp4",
    "b0cccb09eea98ecb2e58a9ea2ef1af21.mp4",
    "ce969f96507235be5dddbb21a5652e36.mp4",
    "d887aae7ec7d09ad3830e034b3f9f003.mp4",
    "df357b9188835e90a8a54aff95cbc802.mp4",
    "eb0aa056753bfec68ce6d3c201e8922d.mp4",
    "f6f62f7e44d5de62ab98b1aedfc7c22d.mp4",
    "feb75453e812542cf283bb49565c8c3a.mp4",
}

local VIDEOS = {}
local activeMode = "repo"

-- ids handed in at runtime (Loader.lua reads AssetIds.lua) win over the in-file lists
local function useAssetIds(ids)
    local out = {}
    for i, id in ipairs(ids) do
        local s = tostring(id)
        if s ~= "" and s ~= "nil" then
            out[i] = "rbxassetid://" .. s
        end
    end
    if #out == 0 then
        return false
    end
    VIDEOS = out
    activeMode = "asset"
    return true
end

local function buildDefaultSources()
    if USE_ASSET_IDS and #ASSET_IDS > 0 then
        if useAssetIds(ASSET_IDS) then
            return
        end
    end
    if #HOSTED > 0 then
        VIDEOS = {}
        for i, url in ipairs(HOSTED) do
            VIDEOS[i] = url
        end
        activeMode = "hosted"
        return
    end
    VIDEOS = {}
    for i, file in ipairs(FILES) do
        VIDEOS[i] = REPO_RAW .. file
    end
    activeMode = "repo"
end

buildDefaultSources()

------------------------------------------------------------- look and feel
local GUI_NAME = "TTGui"
local BLACK    = Color3.fromRGB(0, 0, 0)
local DARK     = Color3.fromRGB(16, 16, 16)
local GREY     = Color3.fromRGB(44, 44, 44)
local WHITE    = Color3.fromRGB(255, 255, 255)
local ACCENT   = Color3.fromRGB(254, 44, 85) -- tiktok red
local SKIP_GAP = 0.25                         -- seconds between skips (wheel debounce)
local LOAD_WAIT = 8                           -- seconds before a clip is declared dead

------------------------------------------------------------- random deck
local deck = {}
local lastPlayed = nil

local function reshuffle()
    local n = #VIDEOS
    deck = table.create(n)
    for i = 1, n do
        deck[i] = i
    end
    for i = n, 2, -1 do
        local j = math.random(i)
        deck[i], deck[j] = deck[j], deck[i]
    end
    if n > 1 and deck[1] == lastPlayed then -- never open a fresh deck on the video that just played
        deck[1], deck[2] = deck[2], deck[1]
    end
end

-- +1 draws from the front, -1 from the back; both are random, deck never repeats until empty
local function pick(step)
    if #VIDEOS == 0 then
        return nil
    end
    if #deck == 0 then
        reshuffle()
    end
    local idx = step > 0 and table.remove(deck, 1) or table.remove(deck)
    lastPlayed = idx
    return idx
end

-- every property assignment is defended: one rejected property on an unknown
-- client build used to abort the whole build and leave a dead black frame
local function setProps(inst, props)
    if type(props) ~= "table" then
        return
    end
    local parent = props.Parent
    for k, v in pairs(props) do
        if k ~= "Parent" then
            local ok = pcall(function()
                inst[k] = v
            end)
            if not ok then
                warn(("[TT] %s.%s rejected"):format(inst.ClassName, tostring(k)))
            end
        end
    end
    if parent then
        inst.Parent = parent
    end
end

local function make(class, props)
    local ok, inst = pcall(Instance.new, class)
    if not ok or not inst then
        warn("[TT] cannot create " .. tostring(class))
        return nil
    end
    setProps(inst, props)
    return inst
end

------------------------------------------------------------- error surface
-- a dead build paints its reason on screen instead of leaving a black hole
local function showFatal(playerGui, err)
    warn("[TT] fatal: " .. tostring(err))
    local screen = Instance.new("ScreenGui")
    screen.Name = GUI_NAME
    screen.ResetOnSpawn = false
    screen.IgnoreGuiInset = true
    screen.DisplayOrder = 1000
    screen.Parent = playerGui

    local box = Instance.new("TextLabel")
    box.Size = UDim2.new(0.8, 0, 0, 140)
    box.Position = UDim2.fromScale(0.5, 0.12)
    box.AnchorPoint = Vector2.new(0.5, 0)
    box.BackgroundColor3 = Color3.fromRGB(120, 12, 24)
    box.BorderSizePixel = 0
    box.Font = Enum.Font.Code
    box.TextSize = 14
    box.TextWrapped = true
    box.TextColor3 = WHITE
    box.Text = "[TT] fatal:\n" .. tostring(err)
    box.Parent = screen
    return screen
end

------------------------------------------------------------- build
local function build(playerGui)
    local cam = workspace.CurrentCamera
    local viewport = cam and cam.ViewportSize or Vector2.new(1280, 720)
    local locked = false
    local lastSkip = 0
    local showTag = 0

    local screen = make("ScreenGui", {
        Name = GUI_NAME,
        ResetOnSpawn = false,
        IgnoreGuiInset = true,
        DisplayOrder = 999,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        Parent = playerGui,
    })
    if not screen then
        error("ScreenGui refused to instantiate")
    end

    local window = make("Frame", {
        Name = "Window",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromOffset(viewport.X * 0.5, viewport.Y * 0.5),
        Size = UDim2.fromScale(0.6, 0.9),
        BackgroundColor3 = BLACK,
        BorderSizePixel = 0,
        Active = true,
        Parent = screen,
    })

    make("UISizeConstraint", {
        MinSize = Vector2.new(240, 420),
        MaxSize = Vector2.new(460, 900),
        Parent = window,
    })

    ------------------------------------------------------------- top bar
    local bar = make("Frame", {
        Name = "Bar",
        BackgroundColor3 = DARK,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 36),
        Active = true,
        Parent = window,
    })
    make("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(12, 0),
        Size = UDim2.new(0, 60, 1, 0),
        Font = Enum.Font.GothamBlack,
        Text = "TT",
        TextSize = 18,
        TextColor3 = WHITE,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = bar,
    })

    local lockBtn = make("TextButton", {
        Name = "Lock",
        AutoButtonColor = false,
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -54, 0, 6),
        Size = UDim2.fromOffset(76, 24),
        BackgroundColor3 = GREY,
        BorderSizePixel = 0,
        Font = Enum.Font.GothamBold,
        Text = "LOCK",
        TextSize = 12,
        TextColor3 = WHITE,
        Parent = bar,
    })
    local closeBtn = make("TextButton", {
        Name = "Close",
        AutoButtonColor = false,
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -6, 0, 6),
        Size = UDim2.fromOffset(40, 24),
        BackgroundColor3 = ACCENT,
        BorderSizePixel = 0,
        Font = Enum.Font.GothamBold,
        Text = "X",
        TextSize = 12,
        TextColor3 = WHITE,
        Parent = bar,
    })

    ------------------------------------------------------------- stage
    local holder = make("Frame", {
        Name = "Stage",
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(0, 36),
        Size = UDim2.new(1, 0, 1, -60),
        Active = true,
        Parent = window,
    })

    local video = make("VideoFrame", {
        Name = "Feed",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = BLACK,
        BorderSizePixel = 0,
        Volume = 0.6,
        Looped = true,
        Parent = holder,
    })
    make("UIAspectRatioConstraint", {
        AspectRatio = 9 / 16,
        AspectType = Enum.AspectType.FitWithinMaxSize,
        DominantAxis = Enum.DominantAxis.Height,
        Parent = video,
    })

    local status = make("TextLabel", {
        Name = "Status",
        BackgroundTransparency = 1,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.new(1, -24, 0, 60),
        Font = Enum.Font.GothamBold,
        TextSize = 15,
        TextColor3 = WHITE,
        TextStrokeTransparency = 0.4,
        TextWrapped = true,
        ZIndex = 3,
        Text = "",
        Parent = holder,
    })
    local counter = make("TextLabel", {
        Name = "Counter",
        BackgroundColor3 = BLACK,
        BackgroundTransparency = 0.35,
        AnchorPoint = Vector2.new(1, 1),
        Position = UDim2.new(1, -10, 1, -10),
        Size = UDim2.fromOffset(72, 22),
        BorderSizePixel = 0,
        Font = Enum.Font.GothamBold,
        TextSize = 12,
        TextColor3 = WHITE,
        ZIndex = 3,
        Text = "",
        Parent = window,
    })
    local hint = make("TextLabel", {
        Name = "Hint",
        BackgroundColor3 = DARK,
        BorderSizePixel = 0,
        AnchorPoint = Vector2.new(0, 1),
        Position = UDim2.new(0, 0, 1, 0),
        Size = UDim2.new(1, 0, 0, 24),
        Font = Enum.Font.Gotham,
        TextSize = 11,
        TextColor3 = WHITE,
        Text = "",
        Parent = window,
    })

    local mode = activeMode

    local function hintText()
        local state = locked and "LOCKED - SCROLL/SWIPE" or "DRAG TO MOVE"
        return ("%s | %d clips | %s"):format(mode, #VIDEOS, state)
    end

    ------------------------------------------------------------- playback
    local function show(index)
        local uri = VIDEOS[index]
        showTag += 1
        local tag = showTag

        status.Text = "LOADING " .. index .. " / " .. #VIDEOS
        counter.Text = index .. " / " .. #VIDEOS
        pcall(function() video:Pause() end) -- VideoFrame has Pause, not Stop

        -- VideoContent is the Content-typed property on current clients; Video is
        -- the older string property (asset ids only). try modern, fall back.
        local ok = pcall(function()
            video.VideoContent = Content.fromUri(uri)
        end)
        if not ok then
            ok = pcall(function()
                video.Video = uri
            end)
        end
        if not ok then
            status.Text = "SLOT " .. index .. " REJECTED\nno video property on this client"
            warn("[TT] slot " .. index .. " rejected: " .. uri)
            return
        end
        pcall(function() video:Play() end)
        print("[TT] loading slot " .. index .. " -> " .. uri)

        task.spawn(function()
            local deadline = os.clock() + LOAD_WAIT
            while tag == showTag and not video.IsLoaded and os.clock() < deadline do
                task.wait(0.1)
            end
            if tag ~= showTag then
                return
            end
            if video.IsLoaded then
                status.Text = ""
                pcall(function() video:Play() end)
            else
                status.Text = "SLOT " .. index .. " WILL NOT LOAD\n"
                    .. (activeMode == "asset" and "asset id wrong or still moderating"
                        or "this client refuses remote video - upload the clips as roblox assets")
                warn("[TT] slot " .. index .. " never loaded: " .. uri)
            end
        end)
    end

    local function step(direction)
        if not locked then
            return
        end
        if #VIDEOS == 0 then
            status.Text = "NO VIDEOS - FILL FILES OR ASSET_IDS"
            return
        end
        local now = os.clock()
        if now - lastSkip < SKIP_GAP then
            return
        end
        lastSkip = now
        local index = pick(direction)
        if index then
            show(index)
        end
    end

    ------------------------------------------------------------- lock state
    local function setLocked(value)
        locked = value
        if lockBtn then
            lockBtn.Text = locked and "UNLOCK" or "LOCK"
            lockBtn.BackgroundColor3 = locked and ACCENT or GREY
        end
        if hint then
            hint.Text = hintText()
        end
    end
    if lockBtn then
        lockBtn.Activated:Connect(function()
            setLocked(not locked)
        end)
    end

    ------------------------------------------------------------- drag
    local dragging = false
    local dragStart, dragBase
    local touchStart = nil

    local function clampToScreen()
        local cam2 = workspace.CurrentCamera
        local view = cam2 and cam2.ViewportSize or viewport
        local size = window.AbsoluteSize
        local left = math.clamp(window.AbsolutePosition.X, 0, math.max(0, view.X - size.X))
        local top = math.clamp(window.AbsolutePosition.Y, 0, math.max(0, view.Y - size.Y))
        window.Position = UDim2.fromOffset(left + size.X * 0.5, top + size.Y * 0.5)
    end

    local function startDrag(input)
        dragging = true
        dragStart = input.Position
        local size = window.AbsoluteSize
        dragBase = Vector2.new(
            window.AbsolutePosition.X + size.X * 0.5,
            window.AbsolutePosition.Y + size.Y * 0.5
        )
    end

    for _, surface in { window, bar, holder } do
        if surface then
            surface.InputBegan:Connect(function(input)
                local kind = input.UserInputType
                if kind == Enum.UserInputType.Touch then
                    if locked then
                        touchStart = input.Position
                    else
                        startDrag(input)
                    end
                elseif kind == Enum.UserInputType.MouseButton1 and not locked then
                    startDrag(input)
                end
            end)
        end
    end

    ------------------------------------------------------------- input wiring
    local conns = {}

    conns[#conns + 1] = UserInputService.InputChanged:Connect(function(input)
        local kind = input.UserInputType
        if dragging and (kind == Enum.UserInputType.MouseButton1 or kind == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            window.Position = UDim2.fromOffset(dragBase.X + delta.X, dragBase.Y + delta.Y)
            clampToScreen()
        end
    end)

    local function onAnyInput(input)
        -- wheel up = next, wheel down = previous; swap the arguments to flip it
        if input.UserInputType == Enum.UserInputType.MouseWheel then
            if UserInputService:GetFocusedTextBox() then
                return
            end
            step(input.Position.Z >= 0 and 1 or -1)
        end
    end
    conns[#conns + 1] = UserInputService.InputBegan:Connect(onAnyInput)
    conns[#conns + 1] = UserInputService.InputChanged:Connect(onAnyInput)

    conns[#conns + 1] = UserInputService.InputEnded:Connect(function(input)
        local kind = input.UserInputType
        if kind == Enum.UserInputType.MouseButton1 or kind == Enum.UserInputType.Touch then
            dragging = false
        end
        if kind == Enum.UserInputType.Touch and touchStart then
            local dy = input.Position.Y - touchStart.Y
            touchStart = nil
            if locked and math.abs(dy) >= 48 then
                step(dy > 0 and -1 or 1) -- finger up = next
            end
        end
    end)

    if closeBtn then
        closeBtn.Activated:Connect(function()
            for _, conn in conns do
                conn:Disconnect()
            end
            pcall(function() video:Pause() end)
            screen:Destroy()
        end)
    end

    ------------------------------------------------------------- first frame
    setLocked(false)
    if #VIDEOS > 0 then
        show(pick(1) or 1)
    else
        status.Text = "NO VIDEOS - FILL FILES OR ASSET_IDS"
    end

    return screen
end

function Gui.Init(opts)
    opts = opts or {}

    -- Loader.lua hands over the ids from AssetIds.lua when they exist
    if type(opts.assetIds) == "table" and #opts.assetIds > 0 then
        if useAssetIds(opts.assetIds) then
            deck = {}
            lastPlayed = nil
        end
    end

    local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
    local old = playerGui:FindFirstChild(GUI_NAME)
    if old then
        old:Destroy()
    end

    local ok, screen = pcall(build, playerGui)
    if not ok then
        showFatal(playerGui, screen)
        return nil
    end
    return screen
end

return Gui
