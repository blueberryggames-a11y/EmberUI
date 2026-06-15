-- AppleLibrary Enhanced v2.0
-- Original by GoHamza | Enhanced with: Key System, Armor Keys, Slider, Dropdown,
-- Colorpicker stub, improved animations, TweenService, performance fixes,
-- debounce guards, and modern executor compatibility

-- ─────────────────────────────────────────────────
-- Services
-- ─────────────────────────────────────────────────
local TweenService    = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService      = game:GetService("RunService")
local Debris          = game:GetService("Debris")
local CoreGui         = game:GetService("CoreGui")

-- ─────────────────────────────────────────────────
-- Helpers
-- ─────────────────────────────────────────────────
local function tween(instance, properties, duration, style, direction)
    style     = style     or Enum.EasingStyle.Quart
    direction = direction or Enum.EasingDirection.InOut
    local info = TweenInfo.new(duration, style, direction)
    local t = TweenService:Create(instance, info, properties)
    t:Play()
    return t
end

local function tweenPos(instance, pos, duration, style, direction)
    return tween(instance, {Position = pos}, duration, style, direction)
end

local function tweenTransparency(instance, value, duration)
    return tween(instance, {BackgroundTransparency = value}, duration)
end

-- Safe Destroy with pcall
local function safeDestroy(obj)
    pcall(function() obj:Destroy() end)
end

-- ─────────────────────────────────────────────────
-- Color Constants (Apple palette)
-- ─────────────────────────────────────────────────
local C = {
    White       = Color3.fromRGB(255, 255, 255),
    OffWhite    = Color3.fromRGB(245, 245, 247),
    LightGray   = Color3.fromRGB(216, 216, 216),
    MidGray     = Color3.fromRGB(180, 180, 180),
    DarkGray    = Color3.fromRGB(95, 95, 95),
    Black       = Color3.fromRGB(0, 0, 0),
    Blue        = Color3.fromRGB(21, 103, 251),
    LightBlue   = Color3.fromRGB(90, 150, 255),
    Red         = Color3.fromRGB(254, 94, 86),
    Yellow      = Color3.fromRGB(255, 189, 46),
    Green       = Color3.fromRGB(39, 200, 63),
    KeyGold     = Color3.fromRGB(255, 215, 0),
    KeyGoldDark = Color3.fromRGB(200, 160, 0),
    Danger      = Color3.fromRGB(255, 59, 48),
    Success     = Color3.fromRGB(52, 199, 89),
}

-- ─────────────────────────────────────────────────
-- Font Constants
-- ─────────────────────────────────────────────────
local F = {
    Regular = Enum.Font.Gotham,
    Medium  = Enum.Font.GothamMedium,
    Bold    = Enum.Font.GothamBold,
    Source  = Enum.Font.SourceSans,
}

-- ─────────────────────────────────────────────────
-- UICorner helper
-- ─────────────────────────────────────────────────
local function addCorner(parent, radius)
    local uc = Instance.new("UICorner")
    uc.CornerRadius = UDim.new(0, radius or 9)
    uc.Parent = parent
    return uc
end

local function addStroke(parent, color, thickness)
    local us = Instance.new("UIStroke")
    us.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    us.Color = color or C.Blue
    us.Thickness = thickness or 1
    us.Parent = parent
    return us
end

local function addShadow(parent, zindex)
    local shadow = Instance.new("ImageLabel")
    shadow.Name = "Shadow"
    shadow.AnchorPoint = Vector2.new(0.5, 0.5)
    shadow.BackgroundTransparency = 1
    shadow.Position = UDim2.new(0.5, 0, 0.5, 0)
    shadow.Size = UDim2.new(1.15, 0, 1.20, 0)
    shadow.ZIndex = zindex or 0
    shadow.Image = "rbxassetid://313486536"
    shadow.ImageColor3 = C.Black
    shadow.ImageTransparency = 0.5
    shadow.Parent = parent
    return shadow
end

-- ─────────────────────────────────────────────────
-- Main Library Table
-- ─────────────────────────────────────────────────
local lib = {}

-- ══════════════════════════════════════════════════
-- KEY SYSTEM
-- ══════════════════════════════════════════════════
--[[
    lib:KeySystem({
        Title       = "Authorization",
        Subtitle    = "Enter your key to continue",
        Keys        = {"key-abc-123", "key-xyz-789"},   -- valid keys
        ArmorKeys   = {"armor-vip-001"},                -- armor/VIP tier keys
        KeyLabel    = "Key",                            -- textbox placeholder label
        OnSuccess   = function(key, isArmor) end,
        OnFail      = function(key) end,
        SaveKey     = true,                             -- save key using writefile if available
        SavePath    = "applibkey.txt",
    })
    Returns: approved (bool), isArmor (bool)
]]
function lib:KeySystem(config)
    config = config or {}
    local title    = config.Title    or "Authorization"
    local subtitle = config.Subtitle or "Enter your key to continue"
    local keys     = config.Keys     or {}
    local armorKeys= config.ArmorKeys or {}
    local label    = config.KeyLabel  or "Key"
    local onSuccess= config.OnSuccess
    local onFail   = config.OnFail
    local savePath = config.SavePath or "applibkey.txt"
    local saveKey  = config.SaveKey  ~= false

    -- Check saved key first
    if saveKey and isfile and isfile(savePath) then
        local saved = readfile(savePath):match("^%s*(.-)%s*$") -- trim
        for _, k in ipairs(armorKeys) do
            if saved == k then
                if onSuccess then pcall(onSuccess, saved, true) end
                return true, true
            end
        end
        for _, k in ipairs(keys) do
            if saved == k then
                if onSuccess then pcall(onSuccess, saved, false) end
                return true, false
            end
        end
    end

    -- Build Key GUI
    local approved  = false
    local isArmor   = false
    local keyGui    = Instance.new("ScreenGui")
    keyGui.Name     = "AppleKeySystem"
    keyGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    keyGui.DisplayOrder = 200

    if syn and syn.protect_gui then
        syn.protect_gui(keyGui)
        keyGui.Parent = CoreGui
    elseif gethui then
        keyGui.Parent = gethui()
    else
        keyGui.Parent = CoreGui
    end

    -- Backdrop blur overlay
    local overlay = Instance.new("Frame")
    overlay.Name = "Overlay"
    overlay.Size = UDim2.new(1,0,1,0)
    overlay.BackgroundColor3 = C.Black
    overlay.BackgroundTransparency = 0.4
    overlay.ZIndex = 10
    overlay.Parent = keyGui

    -- Card
    local card = Instance.new("Frame")
    card.Name = "Card"
    card.AnchorPoint = Vector2.new(0.5, 0.5)
    card.Size = UDim2.new(0, 380, 0, 310)
    card.Position = UDim2.new(0.5, 0, 2, 0)  -- start off-screen
    card.BackgroundColor3 = C.White
    card.BackgroundTransparency = 0.05
    card.ZIndex = 11
    card.Parent = keyGui
    addCorner(card, 18)
    addShadow(card, 10)

    -- Lock icon
    local lockIcon = Instance.new("ImageLabel")
    lockIcon.Name = "LockIcon"
    lockIcon.AnchorPoint = Vector2.new(0.5, 0)
    lockIcon.Position = UDim2.new(0.5, 0, 0, 26)
    lockIcon.Size = UDim2.new(0, 54, 0, 54)
    lockIcon.BackgroundTransparency = 1
    lockIcon.Image = "rbxassetid://6031094678"  -- lock icon
    lockIcon.ImageColor3 = C.Blue
    lockIcon.ScaleType = Enum.ScaleType.Fit
    lockIcon.ZIndex = 12
    lockIcon.Parent = card

    -- Title
    local keyTitle = Instance.new("TextLabel")
    keyTitle.Name = "Title"
    keyTitle.AnchorPoint = Vector2.new(0.5, 0)
    keyTitle.Position = UDim2.new(0.5, 0, 0, 92)
    keyTitle.Size = UDim2.new(0.9, 0, 0, 32)
    keyTitle.BackgroundTransparency = 1
    keyTitle.Font = F.Bold
    keyTitle.Text = title
    keyTitle.TextColor3 = C.Black
    keyTitle.TextSize = 26
    keyTitle.ZIndex = 12
    keyTitle.Parent = card

    -- Subtitle
    local keySub = Instance.new("TextLabel")
    keySub.Name = "Subtitle"
    keySub.AnchorPoint = Vector2.new(0.5, 0)
    keySub.Position = UDim2.new(0.5, 0, 0, 128)
    keySub.Size = UDim2.new(0.85, 0, 0, 22)
    keySub.BackgroundTransparency = 1
    keySub.Font = F.Regular
    keySub.Text = subtitle
    keySub.TextColor3 = C.DarkGray
    keySub.TextSize = 16
    keySub.TextWrapped = true
    keySub.ZIndex = 12
    keySub.Parent = card

    -- Input frame
    local inputFrame = Instance.new("Frame")
    inputFrame.Name = "InputFrame"
    inputFrame.AnchorPoint = Vector2.new(0.5, 0)
    inputFrame.Position = UDim2.new(0.5, 0, 0, 160)
    inputFrame.Size = UDim2.new(0.85, 0, 0, 40)
    inputFrame.BackgroundColor3 = C.OffWhite
    inputFrame.ZIndex = 12
    inputFrame.Parent = card
    addCorner(inputFrame, 10)
    addStroke(inputFrame, C.MidGray, 1)

    local keyInput = Instance.new("TextBox")
    keyInput.Name = "KeyInput"
    keyInput.AnchorPoint = Vector2.new(0, 0.5)
    keyInput.Position = UDim2.new(0, 12, 0.5, 0)
    keyInput.Size = UDim2.new(1, -24, 1, 0)
    keyInput.BackgroundTransparency = 1
    keyInput.ClearTextOnFocus = false
    keyInput.Font = F.Regular
    keyInput.PlaceholderText = label .. "..."
    keyInput.PlaceholderColor3 = C.MidGray
    keyInput.Text = ""
    keyInput.TextColor3 = C.Black
    keyInput.TextSize = 17
    keyInput.TextXAlignment = Enum.TextXAlignment.Left
    keyInput.ZIndex = 13
    keyInput.Parent = inputFrame

    -- Status label
    local statusLabel = Instance.new("TextLabel")
    statusLabel.Name = "Status"
    statusLabel.AnchorPoint = Vector2.new(0.5, 0)
    statusLabel.Position = UDim2.new(0.5, 0, 0, 208)
    statusLabel.Size = UDim2.new(0.85, 0, 0, 20)
    statusLabel.BackgroundTransparency = 1
    statusLabel.Font = F.Regular
    statusLabel.Text = ""
    statusLabel.TextColor3 = C.Danger
    statusLabel.TextSize = 14
    statusLabel.ZIndex = 12
    statusLabel.Parent = card

    -- Confirm button
    local confirmBtn = Instance.new("TextButton")
    confirmBtn.Name = "Confirm"
    confirmBtn.AnchorPoint = Vector2.new(0.5, 0)
    confirmBtn.Position = UDim2.new(0.5, 0, 0, 238)
    confirmBtn.Size = UDim2.new(0.85, 0, 0, 44)
    confirmBtn.BackgroundColor3 = C.Blue
    confirmBtn.AutoButtonColor = false
    confirmBtn.Font = F.Medium
    confirmBtn.Text = "Confirm"
    confirmBtn.TextColor3 = C.White
    confirmBtn.TextSize = 18
    confirmBtn.ZIndex = 12
    confirmBtn.Parent = card
    addCorner(confirmBtn, 10)

    -- Animate card in
    task.delay(0.05, function()
        tweenPos(card, UDim2.new(0.5, 0, 0.5, 0), 0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
    end)

    -- Button hover effect
    confirmBtn.MouseEnter:Connect(function()
        tween(confirmBtn, {BackgroundColor3 = C.LightBlue}, 0.15)
    end)
    confirmBtn.MouseLeave:Connect(function()
        tween(confirmBtn, {BackgroundColor3 = C.Blue}, 0.15)
    end)

    -- Shake animation on fail
    local function shakeCard()
        local orig = card.Position
        for i = 1, 4 do
            tweenPos(card, orig + UDim2.new(0, i % 2 == 0 and 8 or -8, 0, 0), 0.05)
            task.wait(0.055)
        end
        tweenPos(card, orig, 0.1)
    end

    local function attemptKey()
        local input = keyInput.Text:match("^%s*(.-)%s*$")
        if input == "" then
            statusLabel.Text = "Please enter a key."
            return
        end

        -- Check armor keys first
        for _, k in ipairs(armorKeys) do
            if input == k then
                approved = true
                isArmor  = true
                statusLabel.TextColor3 = C.Success
                statusLabel.Text = "✓ Armor key accepted!"
                tween(confirmBtn, {BackgroundColor3 = C.Success}, 0.2)
                if saveKey and writefile then pcall(writefile, savePath, input) end
                task.delay(0.6, function()
                    tweenPos(card, UDim2.new(0.5, 0, 2, 0), 0.4)
                    task.wait(0.45)
                    safeDestroy(keyGui)
                    if onSuccess then pcall(onSuccess, input, true) end
                end)
                return
            end
        end

        -- Check regular keys
        for _, k in ipairs(keys) do
            if input == k then
                approved = true
                isArmor  = false
                statusLabel.TextColor3 = C.Success
                statusLabel.Text = "✓ Key accepted!"
                tween(confirmBtn, {BackgroundColor3 = C.Success}, 0.2)
                if saveKey and writefile then pcall(writefile, savePath, input) end
                task.delay(0.6, function()
                    tweenPos(card, UDim2.new(0.5, 0, 2, 0), 0.4)
                    task.wait(0.45)
                    safeDestroy(keyGui)
                    if onSuccess then pcall(onSuccess, input, false) end
                end)
                return
            end
        end

        -- Failed
        statusLabel.TextColor3 = C.Danger
        statusLabel.Text = "✗ Invalid key. Try again."
        shakeCard()
        tween(inputFrame, {BackgroundColor3 = Color3.fromRGB(255, 235, 235)}, 0.15)
        task.delay(0.5, function()
            tween(inputFrame, {BackgroundColor3 = C.OffWhite}, 0.3)
        end)
        if onFail then pcall(onFail, input) end
    end

    confirmBtn.MouseButton1Click:Connect(attemptKey)
    keyInput.FocusLost:Connect(function(enterPressed)
        if enterPressed then attemptKey() end
    end)

    -- Wait for resolution
    repeat task.wait(0.1) until (not keyGui.Parent or not keyGui.Parent.Parent) or approved
    return approved, isArmor
end

-- ══════════════════════════════════════════════════
-- INIT (Main Window)
-- ══════════════════════════════════════════════════
function lib:init(ti, dosplash, visiblekey, deleteprevious)
    local sections = {}
    local workareas = {}
    local visible = true
    local toggleDebounce = false
    local scrgui

    -- ── GUI root ────────────────────────────────────
    scrgui = Instance.new("ScreenGui")
    scrgui.Name = "AppleLibraryUI"
    scrgui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    scrgui.DisplayOrder = 100

    local function destroyPrev(guiContainer)
        local prev = guiContainer:FindFirstChild("AppleLibraryUI")
        if prev and deleteprevious then
            local m = prev:FindFirstChild("main")
            if m then
                tweenPos(m, m.Position + UDim2.new(0, 0, 2, 0), 0.5)
            end
            Debris:AddItem(prev, 0.6)
        end
    end

    if syn and syn.protect_gui then
        destroyPrev(CoreGui)
        syn.protect_gui(scrgui)
        scrgui.Parent = CoreGui
    elseif gethui then
        destroyPrev(gethui())
        scrgui.Parent = gethui()
    else
        destroyPrev(CoreGui)
        scrgui.Parent = CoreGui
    end

    -- ── Splash ──────────────────────────────────────
    if dosplash then
        local splash = Instance.new("Frame")
        splash.Name = "splash"
        splash.AnchorPoint = Vector2.new(0.5, 0.5)
        splash.BackgroundColor3 = C.White
        splash.BackgroundTransparency = 0.1
        splash.Position = UDim2.new(0.5, 0, 2, 0)
        splash.Size = UDim2.new(0, 320, 0, 320)
        splash.ZIndex = 40
        splash.Parent = scrgui
        addCorner(splash, 20)

        local sicon = Instance.new("ImageLabel")
        sicon.AnchorPoint = Vector2.new(0.5, 0.5)
        sicon.BackgroundTransparency = 1
        sicon.Position = UDim2.new(0.5, 0, 0.5, 0)
        sicon.Size = UDim2.new(0, 160, 0, 160)
        sicon.ZIndex = 41
        sicon.Image = "rbxassetid://12621719043"
        sicon.ScaleType = Enum.ScaleType.Fit
        sicon.Parent = splash

        local ug = Instance.new("UIGradient")
        ug.Color = ColorSequence.new{
            ColorSequenceKeypoint.new(0.00, C.White),
            ColorSequenceKeypoint.new(0.05, Color3.fromRGB(60, 60, 60)),
            ColorSequenceKeypoint.new(0.50, Color3.fromRGB(40, 40, 40)),
            ColorSequenceKeypoint.new(1.00, C.Black),
        }
        ug.Rotation = 90
        ug.Parent = sicon

        addShadow(splash, 39)

        tweenPos(splash, UDim2.new(0.5, 0, 0.5, 0), 0.7, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
        task.wait(2.2)
        tweenPos(splash, UDim2.new(0.5, 0, 2, 0), 0.5)
        Debris:AddItem(splash, 0.6)
        task.wait(0.3)
    end

    -- ── Main Window Frame ────────────────────────────
    local main = Instance.new("Frame")
    main.Name = "main"
    main.AnchorPoint = Vector2.new(0.5, 0.5)
    main.BackgroundColor3 = C.White
    main.BackgroundTransparency = 0.08
    main.Position = UDim2.new(0.5, 0, 2, 0)
    main.Size = UDim2.new(0, 721, 0, 584)
    main.Parent = scrgui
    addCorner(main, 18)
    addShadow(main, -1)

    -- ── Drag ────────────────────────────────────────
    do
        local dragging, dragInput, dragStart, startPos
        main.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
                dragging  = true
                dragStart = input.Position
                startPos  = main.Position
                input.Changed:Connect(function()
                    if input.UserInputState == Enum.UserInputState.End then
                        dragging = false
                    end
                end)
            end
        end)
        main.InputChanged:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch then
                dragInput = input
            end
        end)
        UserInputService.InputChanged:Connect(function(input)
            if input == dragInput and dragging then
                local delta = input.Position - dragStart
                main.Position = UDim2.new(
                    startPos.X.Scale, startPos.X.Offset + delta.X,
                    startPos.Y.Scale, startPos.Y.Offset + delta.Y
                )
            end
        end)
    end

    -- ── Workarea (right panel) ────────────────────────
    local workarea = Instance.new("Frame")
    workarea.Name = "workarea"
    workarea.BackgroundColor3 = C.White
    workarea.Position = UDim2.new(0.364, 0, 0, 0)
    workarea.Size = UDim2.new(0, 458, 0, 584)
    workarea.Parent = main
    addCorner(workarea, 18)

    -- Corner hider (left edge of workarea to mask double-radius)
    local wch = Instance.new("Frame")
    wch.Name = "workareaCornerHider"
    wch.BackgroundColor3 = C.White
    wch.BorderSizePixel = 0
    wch.Size = UDim2.new(0, 18, 1, 0)
    wch.Parent = workarea

    -- ── Search bar ───────────────────────────────────
    local search = Instance.new("Frame")
    search.Name = "search"
    search.BackgroundColor3 = C.OffWhite
    search.Position = UDim2.new(0.026, 0, 0.096, 0)
    search.Size = UDim2.new(0, 225, 0, 34)
    search.Parent = main
    addCorner(search, 9)
    addStroke(search, C.LightGray, 1)

    local searchicon = Instance.new("ImageLabel")
    searchicon.BackgroundTransparency = 1
    searchicon.Position = UDim2.new(0.04, 0, 0.12, 0)
    searchicon.Size = UDim2.new(0, 22, 0, 22)
    searchicon.Image = "rbxassetid://2804603863"
    searchicon.ImageColor3 = C.DarkGray
    searchicon.ScaleType = Enum.ScaleType.Fit
    searchicon.Parent = search

    local searchtextbox = Instance.new("TextBox")
    searchtextbox.Name = "searchtextbox"
    searchtextbox.BackgroundTransparency = 1
    searchtextbox.ClipsDescendants = true
    searchtextbox.Position = UDim2.new(0.18, 0, 0, 0)
    searchtextbox.Size = UDim2.new(0, 176, 0, 34)
    searchtextbox.Font = F.Regular
    searchtextbox.PlaceholderText = "Search"
    searchtextbox.PlaceholderColor3 = C.MidGray
    searchtextbox.Text = ""
    searchtextbox.TextColor3 = C.DarkGray
    searchtextbox.TextSize = 18
    searchtextbox.ClearTextOnFocus = false
    searchtextbox.TextXAlignment = Enum.TextXAlignment.Left
    searchtextbox.Parent = search

    -- Search logic (uses RunService but only ticks on text change for perf)
    local lastSearch = ""
    RunService:BindToRenderStep("AppleSearch", 1, function()
        local text = searchtextbox.Text
        if text == lastSearch then return end
        lastSearch = text
        local upper = string.upper(text)
        for _, btn in ipairs(sidebar:GetChildren()) do
            if btn:IsA("TextButton") then
                btn.Visible = upper == "" or string.find(string.upper(btn.Text), upper, 1, true) ~= nil
            end
        end
    end)

    -- ── Sidebar ─────────────────────────────────────
    sidebar = Instance.new("ScrollingFrame")
    sidebar.Name = "sidebar"
    sidebar.Active = true
    sidebar.BackgroundTransparency = 1
    sidebar.BorderSizePixel = 0
    sidebar.Position = UDim2.new(0.025, 0, 0.182, 0)
    sidebar.Size = UDim2.new(0, 233, 0, 463)
    sidebar.AutomaticCanvasSize = Enum.AutomaticSize.Y
    sidebar.CanvasSize = UDim2.new(0, 0, 0, 0)
    sidebar.ScrollBarThickness = 2
    sidebar.ScrollBarImageColor3 = C.MidGray
    sidebar.Parent = main

    local sidebarLayout = Instance.new("UIListLayout")
    sidebarLayout.SortOrder = Enum.SortOrder.LayoutOrder
    sidebarLayout.Padding = UDim.new(0, 5)
    sidebarLayout.Parent = sidebar

    -- ── Traffic light buttons ────────────────────────
    local buttons = Instance.new("Frame")
    buttons.BackgroundTransparency = 1
    buttons.Size = UDim2.new(0, 105, 0, 57)
    buttons.Parent = main

    local bLayout = Instance.new("UIListLayout")
    bLayout.FillDirection = Enum.FillDirection.Horizontal
    bLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    bLayout.VerticalAlignment = Enum.VerticalAlignment.Center
    bLayout.SortOrder = Enum.SortOrder.LayoutOrder
    bLayout.Padding = UDim.new(0, 10)
    bLayout.Parent = buttons

    local function trafficBtn(color, order)
        local btn = Instance.new("TextButton")
        btn.BackgroundColor3 = color
        btn.Size = UDim2.new(0, 16, 0, 16)
        btn.LayoutOrder = order
        btn.AutoButtonColor = false
        btn.Font = F.Source
        btn.Text = ""
        addCorner(btn, 99)
        btn.Parent = buttons
        -- Subtle hover dim
        btn.MouseEnter:Connect(function()
            tween(btn, {BackgroundTransparency = 0.25}, 0.1)
        end)
        btn.MouseLeave:Connect(function()
            tween(btn, {BackgroundTransparency = 0}, 0.1)
        end)
        return btn
    end

    local closeBtn    = trafficBtn(C.Red,    1)
    local minimizeBtn = trafficBtn(C.Yellow, 2)
    local resizeBtn   = trafficBtn(C.Green,  3)

    closeBtn.MouseButton1Click:Connect(function()
        tweenPos(main, main.Position + UDim2.new(0, 0, 2, 0), 0.4)
        task.wait(0.42)
        safeDestroy(scrgui)
    end)

    -- ── Title ─────────────────────────────────────
    local titleLabel = Instance.new("TextLabel")
    titleLabel.Name = "title"
    titleLabel.BackgroundTransparency = 1
    titleLabel.Position = UDim2.new(0.389, 0, 0.035, 0)
    titleLabel.Size = UDim2.new(0, 400, 0, 30)
    titleLabel.Font = F.Bold
    titleLabel.Text = ti or ""
    titleLabel.TextColor3 = C.Black
    titleLabel.TextSize = 26
    titleLabel.TextWrapped = true
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.Parent = main

    -- ── Notification (1-button) ────────────────────
    local notif = Instance.new("Frame")
    notif.Name = "notif"
    notif.AnchorPoint = Vector2.new(0.5, 0.5)
    notif.BackgroundColor3 = C.White
    notif.Position = UDim2.new(0.5, 0, 0.5, 0)
    notif.Size = UDim2.new(0, 304, 0, 340)
    notif.Visible = false
    notif.ZIndex = 5
    notif.Parent = main
    addCorner(notif, 18)
    addShadow(notif, 4)

    local notifDarkness = Instance.new("Frame")
    notifDarkness.AnchorPoint = Vector2.new(0.5, 0.5)
    notifDarkness.BackgroundColor3 = C.Black
    notifDarkness.BackgroundTransparency = 0.5
    notifDarkness.Position = UDim2.new(0.5, 0, 0.5, 0)
    notifDarkness.Size = UDim2.new(0, 721, 0, 584)
    notifDarkness.ZIndex = 4
    notifDarkness.Parent = notif
    addCorner(notifDarkness, 18)

    local notifIcon = Instance.new("ImageLabel")
    notifIcon.BackgroundTransparency = 1
    notifIcon.Position = UDim2.new(0.335, 0, 0.09, 0)
    notifIcon.Size = UDim2.new(0, 100, 0, 100)
    notifIcon.ZIndex = 6
    notifIcon.ImageColor3 = C.DarkGray
    notifIcon.ScaleType = Enum.ScaleType.Fit
    notifIcon.Parent = notif

    local notifTitle = Instance.new("TextLabel")
    notifTitle.BackgroundTransparency = 1
    notifTitle.Position = UDim2.new(0.17, 0, 0.375, 0)
    notifTitle.Size = UDim2.new(0, 200, 0, 50)
    notifTitle.ZIndex = 6
    notifTitle.Font = F.Bold
    notifTitle.Text = "Notice"
    notifTitle.TextColor3 = C.DarkGray
    notifTitle.TextSize = 26
    notifTitle.Parent = notif

    local notifText = Instance.new("TextLabel")
    notifText.BackgroundTransparency = 1
    notifText.Position = UDim2.new(0.08, 0, 0.51, 0)
    notifText.Size = UDim2.new(0, 254, 0, 66)
    notifText.ZIndex = 6
    notifText.Font = F.Regular
    notifText.Text = ""
    notifText.TextColor3 = C.DarkGray
    notifText.TextSize = 16
    notifText.TextWrapped = true
    notifText.Parent = notif

    local notifBtn1 = Instance.new("TextButton")
    notifBtn1.BackgroundColor3 = C.Blue
    notifBtn1.Position = UDim2.new(0.056, 0, 0.818, 0)
    notifBtn1.Size = UDim2.new(0, 270, 0, 50)
    notifBtn1.ZIndex = 6
    notifBtn1.AutoButtonColor = false
    notifBtn1.Font = F.Medium
    notifBtn1.Text = "OK"
    notifBtn1.TextColor3 = C.White
    notifBtn1.TextSize = 21
    notifBtn1.Parent = notif
    addCorner(notifBtn1, 9)

    -- ── Notification 2 (two-button) ─────────────────
    local notif2 = Instance.new("Frame")
    notif2.Name = "notif2"
    notif2.AnchorPoint = Vector2.new(0.5, 0.5)
    notif2.BackgroundColor3 = C.White
    notif2.Position = UDim2.new(0.5, 0, 0.5, 0)
    notif2.Size = UDim2.new(0, 304, 0, 340)
    notif2.Visible = false
    notif2.ZIndex = 5
    notif2.Parent = main
    addCorner(notif2, 18)
    addShadow(notif2, 4)

    local notif2Darkness = Instance.new("Frame")
    notif2Darkness.AnchorPoint = Vector2.new(0.5, 0.5)
    notif2Darkness.BackgroundColor3 = C.Black
    notif2Darkness.BackgroundTransparency = 0.5
    notif2Darkness.Position = UDim2.new(0.5, 0, 0.5, 0)
    notif2Darkness.Size = UDim2.new(0, 721, 0, 584)
    notif2Darkness.ZIndex = 4
    notif2Darkness.Parent = notif2
    addCorner(notif2Darkness, 18)

    local notif2Icon = Instance.new("ImageLabel")
    notif2Icon.BackgroundTransparency = 1
    notif2Icon.Position = UDim2.new(0.335, 0, 0.09, 0)
    notif2Icon.Size = UDim2.new(0, 100, 0, 100)
    notif2Icon.ZIndex = 6
    notif2Icon.ImageColor3 = C.DarkGray
    notif2Icon.ScaleType = Enum.ScaleType.Fit
    notif2Icon.Parent = notif2

    local notif2Title = Instance.new("TextLabel")
    notif2Title.BackgroundTransparency = 1
    notif2Title.Position = UDim2.new(0.17, 0, 0.375, 0)
    notif2Title.Size = UDim2.new(0, 200, 0, 50)
    notif2Title.ZIndex = 6
    notif2Title.Font = F.Bold
    notif2Title.Text = "Notice"
    notif2Title.TextColor3 = C.DarkGray
    notif2Title.TextSize = 26
    notif2Title.Parent = notif2

    local notif2Text = Instance.new("TextLabel")
    notif2Text.BackgroundTransparency = 1
    notif2Text.Position = UDim2.new(0.08, 0, 0.51, 0)
    notif2Text.Size = UDim2.new(0, 254, 0, 66)
    notif2Text.ZIndex = 6
    notif2Text.Font = F.Regular
    notif2Text.Text = ""
    notif2Text.TextColor3 = C.DarkGray
    notif2Text.TextSize = 16
    notif2Text.TextWrapped = true
    notif2Text.Parent = notif2

    local notif2Btn1 = Instance.new("TextButton")
    notif2Btn1.BackgroundColor3 = C.Blue
    notif2Btn1.Position = UDim2.new(0.056, 0, 0.715, 0)
    notif2Btn1.Size = UDim2.new(0, 270, 0, 44)
    notif2Btn1.ZIndex = 6
    notif2Btn1.AutoButtonColor = false
    notif2Btn1.Font = F.Medium
    notif2Btn1.Text = "Confirm"
    notif2Btn1.TextColor3 = C.White
    notif2Btn1.TextSize = 20
    notif2Btn1.Parent = notif2
    addCorner(notif2Btn1, 9)

    local notif2Btn2 = Instance.new("TextButton")
    notif2Btn2.BackgroundColor3 = C.Blue
    notif2Btn2.BackgroundTransparency = 1
    notif2Btn2.Position = UDim2.new(0.053, 0, 0.842, 0)
    notif2Btn2.Size = UDim2.new(0, 270, 0, 40)
    notif2Btn2.ZIndex = 6
    notif2Btn2.AutoButtonColor = false
    notif2Btn2.Font = F.Medium
    notif2Btn2.Text = "Cancel"
    notif2Btn2.TextColor3 = C.DarkGray
    notif2Btn2.TextSize = 20
    notif2Btn2.Parent = notif2
    addCorner(notif2Btn2, 9)

    -- ── Animate window in ────────────────────────────
    tweenPos(main, UDim2.new(0.5, 0, 0.5, 0), 0.65, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

    -- ══════════════════════════════════════════════
    -- WINDOW OBJECT
    -- ══════════════════════════════════════════════
    local window = {}

    -- Toggle visibility
    function window:ToggleVisible()
        if toggleDebounce then return end
        toggleDebounce = true
        visible = not visible
        if visible then
            tweenPos(main, UDim2.new(0.5, 0, 0.5, 0), 0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
        else
            tweenPos(main, main.Position + UDim2.new(0, 0, 2, 0), 0.4)
        end
        task.delay(0.5, function() toggleDebounce = false end)
    end

    -- Minimize button + keybind
    if visiblekey then
        minimizeBtn.MouseButton1Click:Connect(function()
            window:ToggleVisible()
        end)
        UserInputService.InputBegan:Connect(function(input, gameProcessed)
            if gameProcessed then return end
            if input.KeyCode == visiblekey then
                window:ToggleVisible()
            end
        end)
    end

    -- Green button callback
    function window:GreenButton(callback)
        resizeBtn.MouseButton1Click:Connect(callback)
    end

    -- ── Temporary Notification (toast) ─────────────
    local toastQueue = {}

    function window:TempNotify(text1, text2, icon, duration)
        duration = duration or 5

        -- Shift existing toasts down
        for _, tf in ipairs(toastQueue) do
            if tf and tf.Parent then
                tweenPos(tf, tf.Position + UDim2.new(0, 0, 0, 130), 0.3)
            end
        end

        local toast = Instance.new("Frame")
        toast.Name = "tempnotif"
        toast.AnchorPoint = Vector2.new(1, 0)
        toast.BackgroundColor3 = C.White
        toast.BackgroundTransparency = 0.06
        toast.Position = UDim2.new(1, 20, 0.06, 0)   -- start off right edge
        toast.Size = UDim2.new(0, 380, 0, 110)
        toast.ZIndex = 20
        toast.Parent = scrgui
        addCorner(toast, 16)
        addShadow(toast, 19)

        local tIcon = Instance.new("ImageLabel")
        tIcon.BackgroundTransparency = 1
        tIcon.Position = UDim2.new(0, 14, 0.5, -30)
        tIcon.Size = UDim2.new(0, 60, 0, 60)
        tIcon.ZIndex = 21
        tIcon.Image = icon or "rbxassetid://4871684504"
        tIcon.ImageColor3 = C.DarkGray
        tIcon.ScaleType = Enum.ScaleType.Fit
        tIcon.Parent = toast

        local t1 = Instance.new("TextLabel")
        t1.BackgroundTransparency = 1
        t1.Position = UDim2.new(0, 86, 0, 14)
        t1.Size = UDim2.new(0, 278, 0, 26)
        t1.ZIndex = 21
        t1.Font = F.Bold
        t1.Text = text1 or ""
        t1.TextColor3 = C.Black
        t1.TextSize = 18
        t1.TextXAlignment = Enum.TextXAlignment.Left
        t1.Parent = toast

        local t2 = Instance.new("TextLabel")
        t2.BackgroundTransparency = 1
        t2.Position = UDim2.new(0, 86, 0, 44)
        t2.Size = UDim2.new(0, 278, 0, 54)
        t2.ZIndex = 21
        t2.Font = F.Regular
        t2.Text = text2 or ""
        t2.TextColor3 = C.DarkGray
        t2.TextSize = 15
        t2.TextWrapped = true
        t2.TextXAlignment = Enum.TextXAlignment.Left
        t2.TextYAlignment = Enum.TextYAlignment.Top
        t2.Parent = toast

        table.insert(toastQueue, toast)

        -- Slide in
        tweenPos(toast, UDim2.new(1, -20, 0.06, 0), 0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

        task.delay(duration, function()
            -- Remove from queue
            for i, tf in ipairs(toastQueue) do
                if tf == toast then table.remove(toastQueue, i) break end
            end
            -- Slide out
            local slideTween = tweenPos(toast, UDim2.new(1, 20, toast.Position.Y.Scale, toast.Position.Y.Offset), 0.35)
            slideTween.Completed:Connect(function()
                safeDestroy(toast)
            end)
        end)
    end

    -- ── Modal Notify (1 button) ─────────────────────
    function window:Notify(txt1, txt2, b1, icon, callback)
        if notif.Visible or notif2.Visible then return "Already visible" end
        notifTitle.Text  = txt1 or "Notice"
        notifText.Text   = txt2 or ""
        notifIcon.Image  = icon or "rbxassetid://4871684504"
        notifBtn1.Text   = b1   or "OK"
        notif.Visible    = true
        tween(notif, {Size = UDim2.new(0, 280, 0, 310)}, 0)
        tween(notif, {Size = UDim2.new(0, 304, 0, 340)}, 0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

        local con
        con = notifBtn1.MouseButton1Click:Connect(function()
            con:Disconnect()
            tween(notif, {Size = UDim2.new(0, 280, 0, 310)}, 0.15)
            task.delay(0.15, function() notif.Visible = false end)
            if callback then pcall(callback) end
        end)
    end

    -- ── Modal Notify (2 buttons) ────────────────────
    function window:Notify2(txt1, txt2, b1, b2, icon, callback, callback2)
        if notif.Visible or notif2.Visible then return "Already visible" end
        notif2Title.Text = txt1 or "Notice"
        notif2Text.Text  = txt2 or ""
        notif2Icon.Image = icon or "rbxassetid://12608260095"
        notif2Btn1.Text  = b1  or "Confirm"
        notif2Btn2.Text  = b2  or "Cancel"
        notif2.Visible   = true
        tween(notif2, {Size = UDim2.new(0, 280, 0, 310)}, 0)
        tween(notif2, {Size = UDim2.new(0, 304, 0, 340)}, 0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

        local con1, con2
        local function dismiss()
            tween(notif2, {Size = UDim2.new(0, 280, 0, 310)}, 0.15)
            task.delay(0.15, function() notif2.Visible = false end)
        end
        con1 = notif2Btn1.MouseButton1Click:Connect(function()
            con1:Disconnect(); con2:Disconnect()
            dismiss()
            if callback then pcall(callback) end
        end)
        con2 = notif2Btn2.MouseButton1Click:Connect(function()
            con1:Disconnect(); con2:Disconnect()
            dismiss()
            if callback2 then pcall(callback2) end
        end)
    end

    -- ── Sidebar Divider ─────────────────────────────
    function window:Divider(name)
        local lbl = Instance.new("TextLabel")
        lbl.Name = "SidebarDivider"
        lbl.BackgroundTransparency = 1
        lbl.Size = UDim2.new(0, 226, 0, 26)
        lbl.Font = F.Medium
        lbl.Text = name or ""
        lbl.TextColor3 = C.DarkGray
        lbl.TextSize = 13
        lbl.TextWrapped = true
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.TextYAlignment = Enum.TextYAlignment.Bottom
        lbl.Parent = sidebar
    end

    -- ══════════════════════════════════════════════
    -- SECTION
    -- ══════════════════════════════════════════════
    function window:Section(name)
        -- Sidebar tab
        local tabBtn = Instance.new("TextButton")
        tabBtn.Name = name
        tabBtn.BackgroundColor3 = C.Blue
        tabBtn.BackgroundTransparency = 1
        tabBtn.Size = UDim2.new(0, 226, 0, 37)
        tabBtn.ZIndex = 2
        tabBtn.AutoButtonColor = false
        tabBtn.Font = F.Regular
        tabBtn.Text = name
        tabBtn.TextColor3 = C.Black
        tabBtn.TextSize = 18
        addCorner(tabBtn, 9)
        tabBtn.Parent = sidebar
        table.insert(sections, tabBtn)

        -- Work area scroll
        local wam = Instance.new("ScrollingFrame")
        wam.Name = "workareamain_" .. name
        wam.Active = true
        wam.BackgroundTransparency = 1
        wam.BorderSizePixel = 0
        wam.Position = UDim2.new(0.039, 0, 0.096, 0)
        wam.Size = UDim2.new(0, 422, 0, 512)
        wam.ZIndex = 2
        wam.AutomaticCanvasSize = Enum.AutomaticSize.Y
        wam.CanvasSize = UDim2.new(0, 0, 0, 0)
        wam.ScrollBarThickness = 2
        wam.ScrollBarImageColor3 = C.MidGray
        wam.Visible = false
        wam.Parent = workarea

        local wamLayout = Instance.new("UIListLayout")
        wamLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
        wamLayout.SortOrder = Enum.SortOrder.LayoutOrder
        wamLayout.Padding = UDim.new(0, 6)
        wamLayout.Parent = wam

        local wamPad = Instance.new("UIPadding")
        wamPad.PaddingTop = UDim.new(0, 4)
        wamPad.Parent = wam

        table.insert(workareas, wam)

        local sec = {}

        function sec:Select()
            for _, v in ipairs(sections) do
                tween(v, {BackgroundTransparency = 1, TextColor3 = C.Black}, 0.15)
            end
            tween(tabBtn, {BackgroundTransparency = 0, TextColor3 = C.White}, 0.15)
            for _, v in ipairs(workareas) do
                v.Visible = false
            end
            wam.Visible = true
        end

        tabBtn.MouseButton1Click:Connect(function() sec:Select() end)

        -- Hover effect when not selected
        tabBtn.MouseEnter:Connect(function()
            if tabBtn.BackgroundTransparency ~= 0 then
                tween(tabBtn, {BackgroundTransparency = 0.85}, 0.12)
            end
        end)
        tabBtn.MouseLeave:Connect(function()
            if tabBtn.BackgroundTransparency ~= 0 then
                tween(tabBtn, {BackgroundTransparency = 1}, 0.12)
            end
        end)

        -- ── Section Divider ────────────────────────
        function sec:Divider(name)
            local lbl = Instance.new("TextLabel")
            lbl.BackgroundTransparency = 1
            lbl.Size = UDim2.new(0, 418, 0, 42)
            lbl.Font = F.Medium
            lbl.Text = name or ""
            lbl.TextColor3 = C.Black
            lbl.TextSize = 20
            lbl.TextWrapped = true
            lbl.TextXAlignment = Enum.TextXAlignment.Left
            lbl.TextYAlignment = Enum.TextYAlignment.Bottom
            lbl.Parent = wam
        end

        -- ── Label ──────────────────────────────────
        function sec:Label(name)
            local lbl = Instance.new("TextLabel")
            lbl.BackgroundTransparency = 1
            lbl.Size = UDim2.new(0, 418, 0, 37)
            lbl.Font = F.Regular
            lbl.Text = name or ""
            lbl.TextColor3 = C.DarkGray
            lbl.TextSize = 18
            lbl.TextWrapped = true
            lbl.Parent = wam
            return {
                SetText = function(_, t) lbl.Text = t end
            }
        end

        -- ── Button ─────────────────────────────────
        function sec:Button(name, callback)
            local btn = Instance.new("TextButton")
            btn.BackgroundColor3 = C.OffWhite
            btn.Size = UDim2.new(0, 418, 0, 40)
            btn.ZIndex = 2
            btn.AutoButtonColor = false
            btn.Font = F.Medium
            btn.Text = name or "Button"
            btn.TextColor3 = C.Blue
            btn.TextSize = 18
            addCorner(btn, 9)
            addStroke(btn, C.Blue, 1)
            btn.Parent = wam

            btn.MouseEnter:Connect(function()
                tween(btn, {BackgroundColor3 = C.Blue}, 0.15)
                tween(btn, {TextColor3 = C.White}, 0.15)
            end)
            btn.MouseLeave:Connect(function()
                tween(btn, {BackgroundColor3 = C.OffWhite}, 0.15)
                tween(btn, {TextColor3 = C.Blue}, 0.15)
            end)

            if callback then
                local debounce = false
                btn.MouseButton1Click:Connect(function()
                    if debounce then return end
                    debounce = true
                    -- Tap animation
                    tween(btn, {TextTransparency = 0.4}, 0.06)
                    task.delay(0.06, function()
                        tween(btn, {TextTransparency = 0}, 0.08)
                    end)
                    coroutine.wrap(callback)()
                    task.delay(0.15, function() debounce = false end)
                end)
            end

            return {
                SetText = function(_, t) btn.Text = t end,
                SetEnabled = function(_, enabled)
                    btn.Active = enabled
                    tween(btn, {TextTransparency = enabled and 0 or 0.5}, 0.2)
                end,
            }
        end

        -- ── Switch ─────────────────────────────────
        function sec:Switch(name, defaultmode, callback)
            local mode = defaultmode == true
            local row = Instance.new("TextLabel")
            row.BackgroundTransparency = 1
            row.Size = UDim2.new(0, 418, 0, 40)
            row.Font = F.Regular
            row.Text = name or "Switch"
            row.TextColor3 = C.DarkGray
            row.TextSize = 18
            row.TextWrapped = true
            row.TextXAlignment = Enum.TextXAlignment.Left
            row.Parent = wam

            local track = Instance.new("TextButton")
            track.AnchorPoint = Vector2.new(1, 0.5)
            track.Position = UDim2.new(1, 0, 0.5, 0)
            track.Size = UDim2.new(0, 56, 0, 30)
            track.AutoButtonColor = false
            track.Text = ""
            track.BackgroundColor3 = mode and C.Green or C.LightGray
            addCorner(track, 99)
            track.Parent = row

            local knob = Instance.new("Frame")
            knob.Size = UDim2.new(0, 26, 0, 26)
            knob.Position = mode and UDim2.new(0, 28, 0, 2) or UDim2.new(0, 2, 0, 2)
            knob.BackgroundColor3 = C.White
            addCorner(knob, 99)
            addShadow(knob, 0)
            knob.Parent = track

            local function setMode(val, fire)
                mode = val
                tween(knob, {Position = mode and UDim2.new(0, 28, 0, 2) or UDim2.new(0, 2, 0, 2)}, 0.2, Enum.EasingStyle.Quart)
                tween(track, {BackgroundColor3 = mode and C.Green or C.LightGray}, 0.2)
                if fire and callback then pcall(callback, mode) end
            end

            track.MouseButton1Click:Connect(function() setMode(not mode, true) end)

            return {
                Get = function() return mode end,
                Set = function(_, val) setMode(val, false) end,
                SetCallback = function(_, cb) callback = cb end,
            }
        end

        -- ── TextField ─────────────────────────────
        function sec:TextField(name, placeholder, callback)
            local row = Instance.new("TextLabel")
            row.BackgroundTransparency = 1
            row.Size = UDim2.new(0, 418, 0, 40)
            row.Font = F.Regular
            row.Text = name or "Input"
            row.TextColor3 = C.DarkGray
            row.TextSize = 18
            row.TextWrapped = true
            row.TextXAlignment = Enum.TextXAlignment.Left
            row.Parent = wam

            local inputFrame = Instance.new("Frame")
            inputFrame.AnchorPoint = Vector2.new(1, 0.5)
            inputFrame.Position = UDim2.new(1, 0, 0.5, 0)
            inputFrame.Size = UDim2.new(0, 210, 0, 32)
            inputFrame.BackgroundColor3 = C.OffWhite
            addCorner(inputFrame, 8)
            addStroke(inputFrame, C.LightGray, 1)
            inputFrame.Parent = row

            local tb = Instance.new("TextBox")
            tb.BackgroundTransparency = 1
            tb.BorderSizePixel = 0
            tb.ClipsDescendants = true
            tb.Position = UDim2.new(0, 8, 0, 0)
            tb.Size = UDim2.new(1, -16, 1, 0)
            tb.ClearTextOnFocus = false
            tb.Font = F.Regular
            tb.PlaceholderText = placeholder or "Type..."
            tb.PlaceholderColor3 = C.MidGray
            tb.Text = ""
            tb.TextColor3 = C.Black
            tb.TextSize = 16
            tb.TextXAlignment = Enum.TextXAlignment.Left
            tb.Parent = inputFrame

            tb.Focused:Connect(function()
                tween(inputFrame, {BackgroundColor3 = C.White}, 0.15)
                addStroke(inputFrame, C.Blue, 1.5)
            end)
            tb.FocusLost:Connect(function(enter)
                tween(inputFrame, {BackgroundColor3 = C.OffWhite}, 0.15)
                if callback then pcall(callback, tb.Text, enter) end
            end)

            return {
                Get  = function() return tb.Text end,
                Set  = function(_, v) tb.Text = v end,
            }
        end

        -- ── Slider ─────────────────────────────────
        function sec:Slider(name, min, max, default, callback)
            min     = min     or 0
            max     = max     or 100
            default = math.clamp(default or min, min, max)

            local row = Instance.new("TextLabel")
            row.BackgroundTransparency = 1
            row.Size = UDim2.new(0, 418, 0, 50)
            row.Font = F.Regular
            row.Text = name or "Slider"
            row.TextColor3 = C.DarkGray
            row.TextSize = 18
            row.TextWrapped = true
            row.TextXAlignment = Enum.TextXAlignment.Left
            row.Parent = wam

            -- Value readout
            local valLbl = Instance.new("TextLabel")
            valLbl.AnchorPoint = Vector2.new(1, 0)
            valLbl.Position = UDim2.new(1, 0, 0, 0)
            valLbl.Size = UDim2.new(0, 50, 0, 22)
            valLbl.BackgroundTransparency = 1
            valLbl.Font = F.Medium
            valLbl.TextColor3 = C.Blue
            valLbl.TextSize = 15
            valLbl.Text = tostring(default)
            valLbl.Parent = row

            -- Track
            local trackBg = Instance.new("Frame")
            trackBg.AnchorPoint = Vector2.new(0, 1)
            trackBg.Position = UDim2.new(0, 0, 1, -4)
            trackBg.Size = UDim2.new(1, 0, 0, 5)
            trackBg.BackgroundColor3 = C.LightGray
            addCorner(trackBg, 99)
            trackBg.Parent = row

            local fill = Instance.new("Frame")
            fill.Size = UDim2.new((default - min) / (max - min), 0, 1, 0)
            fill.BackgroundColor3 = C.Blue
            addCorner(fill, 99)
            fill.Parent = trackBg

            -- Knob
            local knob = Instance.new("TextButton")
            knob.Name = "Knob"
            knob.AnchorPoint = Vector2.new(0.5, 0.5)
            knob.Size = UDim2.new(0, 18, 0, 18)
            knob.Position = UDim2.new((default - min) / (max - min), 0, 0.5, 0)
            knob.BackgroundColor3 = C.White
            knob.AutoButtonColor = false
            knob.Text = ""
            addCorner(knob, 99)
            addShadow(knob, 0)
            addStroke(knob, C.Blue, 1.5)
            knob.Parent = trackBg

            local current = default
            local sliding = false

            local function updateSlider(absX)
                local rel = math.clamp((absX - trackBg.AbsolutePosition.X) / trackBg.AbsoluteSize.X, 0, 1)
                current = math.floor(min + rel * (max - min) + 0.5)
                local t = (current - min) / (max - min)
                fill.Size = UDim2.new(t, 0, 1, 0)
                knob.Position = UDim2.new(t, 0, 0.5, 0)
                valLbl.Text = tostring(current)
                if callback then pcall(callback, current) end
            end

            knob.MouseButton1Down:Connect(function()
                sliding = true
            end)
            UserInputService.InputChanged:Connect(function(input)
                if sliding and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                    updateSlider(input.Position.X)
                end
            end)
            UserInputService.InputEnded:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                    sliding = false
                end
            end)
            trackBg.InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 then
                    updateSlider(input.Position.X)
                end
            end)

            return {
                Get = function() return current end,
                Set = function(_, v)
                    current = math.clamp(v, min, max)
                    local t = (current - min) / (max - min)
                    fill.Size  = UDim2.new(t, 0, 1, 0)
                    knob.Position = UDim2.new(t, 0, 0.5, 0)
                    valLbl.Text = tostring(current)
                end,
            }
        end

        -- ── Dropdown ──────────────────────────────
        function sec:Dropdown(name, options, default, callback)
            options = options or {}
            local selected = default or options[1] or ""
            local open = false

            local container = Instance.new("Frame")
            container.BackgroundTransparency = 1
            container.Size = UDim2.new(0, 418, 0, 40)
            container.ClipsDescendants = false
            container.ZIndex = 3
            container.Parent = wam

            local row = Instance.new("TextLabel")
            row.BackgroundTransparency = 1
            row.Size = UDim2.new(1, 0, 1, 0)
            row.ZIndex = 3
            row.Font = F.Regular
            row.Text = name or "Dropdown"
            row.TextColor3 = C.DarkGray
            row.TextSize = 18
            row.TextWrapped = true
            row.TextXAlignment = Enum.TextXAlignment.Left
            row.Parent = container

            local dropBtn = Instance.new("TextButton")
            dropBtn.AnchorPoint = Vector2.new(1, 0.5)
            dropBtn.Position = UDim2.new(1, 0, 0.5, 0)
            dropBtn.Size = UDim2.new(0, 160, 0, 32)
            dropBtn.BackgroundColor3 = C.OffWhite
            dropBtn.AutoButtonColor = false
            dropBtn.ZIndex = 4
            dropBtn.Font = F.Regular
            dropBtn.Text = selected .. " ▾"
            dropBtn.TextColor3 = C.Black
            dropBtn.TextSize = 16
            addCorner(dropBtn, 8)
            addStroke(dropBtn, C.LightGray, 1)
            dropBtn.Parent = row

            local panel = Instance.new("Frame")
            panel.AnchorPoint = Vector2.new(1, 0)
            panel.Position = UDim2.new(1, 0, 1, 4)
            panel.Size = UDim2.new(0, 160, 0, 0)
            panel.BackgroundColor3 = C.White
            panel.ClipsDescendants = true
            panel.Visible = false
            panel.ZIndex = 10
            addCorner(panel, 8)
            addShadow(panel, 9)
            panel.Parent = dropBtn

            local panelLayout = Instance.new("UIListLayout")
            panelLayout.SortOrder = Enum.SortOrder.LayoutOrder
            panelLayout.Parent = panel

            local function closePanel()
                open = false
                tween(panel, {Size = UDim2.new(0, 160, 0, 0)}, 0.15)
                task.delay(0.16, function() panel.Visible = false end)
                dropBtn.Text = selected .. " ▾"
            end

            local function openPanel()
                open = true
                panel.Visible = true
                local targetH = math.min(#options * 34, 200)
                tween(panel, {Size = UDim2.new(0, 160, 0, targetH)}, 0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
                dropBtn.Text = selected .. " ▴"
            end

            -- Populate options
            for _, opt in ipairs(options) do
                local optBtn = Instance.new("TextButton")
                optBtn.Size = UDim2.new(1, 0, 0, 34)
                optBtn.BackgroundColor3 = C.White
                optBtn.BackgroundTransparency = 0
                optBtn.AutoButtonColor = false
                optBtn.ZIndex = 11
                optBtn.Font = F.Regular
                optBtn.Text = opt
                optBtn.TextColor3 = opt == selected and C.Blue or C.Black
                optBtn.TextSize = 15
                optBtn.Parent = panel

                optBtn.MouseEnter:Connect(function()
                    tween(optBtn, {BackgroundColor3 = C.OffWhite}, 0.1)
                end)
                optBtn.MouseLeave:Connect(function()
                    tween(optBtn, {BackgroundColor3 = C.White}, 0.1)
                end)
                optBtn.MouseButton1Click:Connect(function()
                    selected = opt
                    closePanel()
                    -- Update all option colors
                    for _, ch in ipairs(panel:GetChildren()) do
                        if ch:IsA("TextButton") then
                            ch.TextColor3 = ch.Text == selected and C.Blue or C.Black
                        end
                    end
                    if callback then pcall(callback, selected) end
                end)
            end

            dropBtn.MouseButton1Click:Connect(function()
                if open then closePanel() else openPanel() end
            end)

            return {
                Get = function() return selected end,
                Set = function(_, v) selected = v; dropBtn.Text = v .. " ▾" end,
                Refresh = function(_, newOpts)
                    for _, ch in ipairs(panel:GetChildren()) do
                        if ch:IsA("TextButton") then ch:Destroy() end
                    end
                    for _, opt in ipairs(newOpts) do
                        local ob = Instance.new("TextButton")
                        ob.Size = UDim2.new(1,0,0,34)
                        ob.BackgroundTransparency = 0
                        ob.BackgroundColor3 = C.White
                        ob.AutoButtonColor = false
                        ob.ZIndex = 11
                        ob.Font = F.Regular
                        ob.Text = opt
                        ob.TextColor3 = C.Black
                        ob.TextSize = 15
                        ob.Parent = panel
                        ob.MouseButton1Click:Connect(function()
                            selected = opt; closePanel()
                            if callback then pcall(callback, selected) end
                        end)
                    end
                end,
            }
        end

        -- ── Keybind ─────────────────────────────────
        --[[
            Displays a row with a clickable button showing the current keybind.
            User clicks it, then presses any key to set a new binding.
            callback(key: Enum.KeyCode) fires on each activation.
        ]]
        function sec:Keybind(name, defaultKey, callback)
            local boundKey = defaultKey or Enum.KeyCode.Unknown
            local listening = false

            local row = Instance.new("TextLabel")
            row.BackgroundTransparency = 1
            row.Size = UDim2.new(0, 418, 0, 40)
            row.Font = F.Regular
            row.Text = name or "Keybind"
            row.TextColor3 = C.DarkGray
            row.TextSize = 18
            row.TextXAlignment = Enum.TextXAlignment.Left
            row.Parent = wam

            local keyBtn = Instance.new("TextButton")
            keyBtn.AnchorPoint = Vector2.new(1, 0.5)
            keyBtn.Position = UDim2.new(1, 0, 0.5, 0)
            keyBtn.Size = UDim2.new(0, 120, 0, 30)
            keyBtn.BackgroundColor3 = C.OffWhite
            keyBtn.AutoButtonColor = false
            keyBtn.ZIndex = 3
            keyBtn.Font = F.Medium
            keyBtn.Text = boundKey.Name
            keyBtn.TextColor3 = C.Blue
            keyBtn.TextSize = 14
            addCorner(keyBtn, 8)
            addStroke(keyBtn, C.Blue, 1)
            keyBtn.Parent = row

            keyBtn.MouseButton1Click:Connect(function()
                if listening then return end
                listening = true
                keyBtn.Text = "Press key..."
                keyBtn.TextColor3 = C.DarkGray
                tween(keyBtn, {BackgroundColor3 = Color3.fromRGB(240, 240, 255)}, 0.1)

                local con
                con = UserInputService.InputBegan:Connect(function(input, gp)
                    if gp then return end
                    if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
                    con:Disconnect()
                    boundKey = input.KeyCode
                    keyBtn.Text = boundKey.Name
                    keyBtn.TextColor3 = C.Blue
                    tween(keyBtn, {BackgroundColor3 = C.OffWhite}, 0.15)
                    listening = false
                end)
            end)

            -- Activate the keybind in-game
            UserInputService.InputBegan:Connect(function(input, gp)
                if gp then return end
                if input.KeyCode == boundKey and not listening then
                    if callback then pcall(callback, boundKey) end
                end
            end)

            return {
                Get = function() return boundKey end,
                Set = function(_, k) boundKey = k; keyBtn.Text = k.Name end,
            }
        end

        -- ── Armor Key Badge ─────────────────────────
        --[[
            Shows a gold "Armor" badge in the section when the user
            holds an armor key. Pass isArmor = true (from KeySystem).
            Usage: sec:ArmorBadge(isArmor, "VIP Member")
        ]]
        function sec:ArmorBadge(isArmor, label)
            if not isArmor then return end
            label = label or "⚔ Armor Key Active"

            local badge = Instance.new("Frame")
            badge.Size = UDim2.new(0, 418, 0, 42)
            badge.BackgroundColor3 = Color3.fromRGB(255, 245, 195)
            badge.ZIndex = 2
            badge.Parent = wam
            addCorner(badge, 10)
            addStroke(badge, C.KeyGold, 1.5)

            local icon = Instance.new("TextLabel")
            icon.BackgroundTransparency = 1
            icon.Position = UDim2.new(0, 10, 0, 0)
            icon.Size = UDim2.new(0, 36, 1, 0)
            icon.ZIndex = 3
            icon.Font = F.Bold
            icon.Text = "★"
            icon.TextColor3 = C.KeyGoldDark
            icon.TextSize = 22
            icon.Parent = badge

            local lbl = Instance.new("TextLabel")
            lbl.BackgroundTransparency = 1
            lbl.Position = UDim2.new(0, 44, 0, 0)
            lbl.Size = UDim2.new(1, -54, 1, 0)
            lbl.ZIndex = 3
            lbl.Font = F.Bold
            lbl.Text = label
            lbl.TextColor3 = C.KeyGoldDark
            lbl.TextSize = 16
            lbl.TextXAlignment = Enum.TextXAlignment.Left
            lbl.Parent = badge

            -- Shimmer animation
            local shimmer = Instance.new("Frame")
            shimmer.BackgroundColor3 = C.White
            shimmer.BackgroundTransparency = 0.65
            shimmer.Position = UDim2.new(-0.2, 0, 0, 0)
            shimmer.Size = UDim2.new(0.15, 0, 1, 0)
            shimmer.Rotation = 15
            shimmer.ZIndex = 4
            shimmer.Parent = badge
            addCorner(badge, 10)

            task.spawn(function()
                while badge.Parent do
                    tweenPos(shimmer, UDim2.new(1.1, 0, 0, 0), 0.9, Enum.EasingStyle.Sine)
                    task.wait(2.5)
                    shimmer.Position = UDim2.new(-0.2, 0, 0, 0)
                end
            end)
        end

        -- ── Color Display (read-only swatch) ─────────
        function sec:ColorDisplay(name, color)
            local row = Instance.new("TextLabel")
            row.BackgroundTransparency = 1
            row.Size = UDim2.new(0, 418, 0, 40)
            row.Font = F.Regular
            row.Text = name or "Color"
            row.TextColor3 = C.DarkGray
            row.TextSize = 18
            row.TextXAlignment = Enum.TextXAlignment.Left
            row.Parent = wam

            local swatch = Instance.new("Frame")
            swatch.AnchorPoint = Vector2.new(1, 0.5)
            swatch.Position = UDim2.new(1, 0, 0.5, 0)
            swatch.Size = UDim2.new(0, 50, 0, 28)
            swatch.BackgroundColor3 = color or C.Blue
            addCorner(swatch, 7)
            addStroke(swatch, C.LightGray, 1)
            swatch.Parent = row

            return {
                Set = function(_, c)
                    tween(swatch, {BackgroundColor3 = c}, 0.2)
                end,
            }
        end

        return sec
    end -- window:Section

    -- ── Destroy ───────────────────────────────────
    function window:Destroy()
        tweenPos(main, main.Position + UDim2.new(0, 0, 2, 0), 0.4)
        task.delay(0.42, function()
            RunService:UnbindFromRenderStep("AppleSearch")
            safeDestroy(scrgui)
        end)
    end

    return window
end -- lib:init

return lib
