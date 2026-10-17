-- language: Luau, file: Gui.lua, target: Roblox executor (Synapse/Fluxus/Solara), returns { Init } for Loader.lua
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local Gui = {}

------------------------------------------------------------- configuration
-- one entry per video, list order does not matter (deck is shuffled):
--   "rbxassetid://<id>"   roblox-hosted video (creator dashboard upload, Premium required)
--   "https://<url>.mp4"   direct url, tried as-is before the asset path
local VIDEOS = {
    -- "rbxassetid://0000000000",
}

local GUI_NAME = "TTGui"
local BLACK    = Color3.fromRGB(0, 0, 0)
local DARK     = Color3.fromRGB(16, 16, 16)
local GREY     = Color3.fromRGB(44, 44, 44)
local WHITE    = Color3.fromRGB(255, 255, 255)
local ACCENT   = Color3.fromRGB(254, 44, 85) -- tiktok red
local SKIP_GAP = 0.25                         -- seconds between skips (wheel debounce)

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

-- +1 draws from the front, -1 from the back; both are random order, deck never repeats until empty
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

local function make(class, props)
    local inst = Instance.new(class)
    local parent = props.Parent
    for k, v in pairs(props) do
        if k ~= "Parent" then
            inst[k] = v
        end
    end
    inst.Parent = parent
    return inst
end

function Gui.Init()
    local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
    local old = playerGui:FindFirstChild(GUI_NAME)
    if old then
        old:Destroy()
    end

    local viewport = workspace.CurrentCamera.ViewportSize
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
        Parent = holder,
    })
    pcall(function() video.Looped = true end) -- property name differs across client builds
    pcall(function() video.Loop = true end)
    make("UIAspectRatioConstraint", {
        AspectRatio = 9 / 16,
        AspectType = Enum.AspectType.FitsWithinParent,
        DominantAxis = Enum.DominantAxis.Height,
        Parent = video,
    })

    local status = make("TextLabel", {
        Name = "Status",
        BackgroundTransparency = 1,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.new(1, -24, 0, 44),
        Font = Enum.Font.GothamBold,
        TextSize = 15,
        TextColor3 = WHITE,
        TextStrokeTransparency = 0.4,
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

    ------------------------------------------------------------- playback
    local function show(index)
        local uri = VIDEOS[index]
        showTag += 1
        local tag = showTag

        status.Text = "LOADING"
        counter.Text = index .. " / " .. #VIDEOS
        pcall(function() video:Stop() end)

        -- modern clients stream from Content, older ones still read .Video: try both
        local ok = pcall(function()
            video.Content = Content.fromUri(uri)
        end)
        if not ok then
            ok = pcall(function()
                video.Video = uri
            end)
        end
        if not ok then
            status.Text = "SLOT " .. index .. " REJECTED"
            return
        end
        pcall(function() video:Play() end)

        task.delay(4, function()
            if tag ~= showTag then
                return
            end
            status.Text = video.Playing and "" or "SLOT " .. index .. " NOT LOADING"
        end)
    end

    local function step(direction)
        if not locked then
            return
        end
        if #VIDEOS == 0 then
            status.Text = "NO VIDEOS - FILL VIDEOS IN Gui.lua"
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
        lockBtn.Text = locked and "UNLOCK" or "LOCK"
        lockBtn.BackgroundColor3 = locked and ACCENT or GREY
        hint.Text = locked and "SCROLL OR SWIPE - NEXT VIDEO" or "DRAG TO MOVE - LOCK TO BROWSE"
    end
    lockBtn.Activated:Connect(function()
        setLocked(not locked)
    end)

    ------------------------------------------------------------- drag
    local dragging = false
    local dragStart, dragBase
    local touchStart = nil

    local function clampToScreen()
        local cam = workspace.CurrentCamera
        local view = cam and cam.ViewportSize or Vector2.new(viewport.X, viewport.Y)
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

    closeBtn.Activated:Connect(function()
        for _, conn in conns do
            conn:Disconnect()
        end
        pcall(function() video:Stop() end)
        screen:Destroy()
    end)

    ------------------------------------------------------------- first frame
    setLocked(false)
    if #VIDEOS > 0 then
        show(pick(1) or 1)
    else
        status.Text = "NO VIDEOS - FILL VIDEOS IN Gui.lua"
    end

    return screen
end

return Gui

