--[[
    EmberUI - Standalone Roblox UI Library V1
    A LocalScript-based UI library using only standard Roblox APIs.
    Place this as a LocalScript inside StarterPlayerScripts (or any client-side container).

    Usage:
        local Window = EmberUI.CreateWindow("My Window")
        local Tab = Window:CreateTab("Main", "house") -- icon name (lucide by default) or rbxassetid://

        Tab:CreateLabel("Hello there")
        Tab:CreateButton("Click me", function() print("clicked") end)
        Tab:CreateToggle("Enable thing", false, function(state) print(state) end)
        Tab:CreateSlider("Speed", 0, 100, 50, function(value) print(value) end)
        Tab:CreateTextbox("Name", "default text", function(text) print(text) end)
        Tab:CreateDropdown("Mode", {"One","Two","Three"}, "One", function(selected) print(selected) end)

        Window:SetBackgroundImage("rbxassetid://0") -- optional, defaults to black
        Window:SetToggleKey(Enum.KeyCode.K)          -- default is K

    Icons:
        EmberUI uses the Footagesus Icons library (lucide by default) for tab icons.
        Pass an icon name (e.g. "house", "settings") or "rbxassetid://..." directly.
        Icons are loaded lazily on first use via HttpGet - make sure "Allow HTTP Requests"
        is enabled in Game Settings > Security, or pre-load your own copy with
        EmberUI.SetIconsModule(IconsModule).
]]

local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local EmberUI = {}

-- ===================== ICONS =====================
-- Footagesus Icons (MIT licensed icon pack for Roblox UI)
local ICONS_URL = "https://raw.githubusercontent.com/Footagesus/Icons/main/Main-v2.lua"
local Icons = nil
local iconsLoaded = false

local function loadIcons()
    if iconsLoaded then return Icons end
    iconsLoaded = true

    local ok, result = pcall(function()
        return loadstring(game:HttpGet(ICONS_URL))()
    end)

    if ok and result then
        Icons = result
        pcall(function()
            Icons.SetIconsType("lucide") -- default icon set
        end)
    else
        warn("EmberUI: failed to load Icons module - " .. tostring(result))
        Icons = nil
    end

    return Icons
end

-- Allow consumers to inject a pre-loaded Icons module instead of fetching one
function EmberUI.SetIconsModule(iconsModule)
    Icons = iconsModule
    iconsLoaded = true
end

-- Resolve an icon reference into an asset id string.
-- Accepts: "rbxassetid://...", a plain icon name ("house"), or "pack:name" ("sfsymbols:HouseFill")
local function resolveIcon(icon)
    if not icon or icon == "" then
        return nil
    end

    if type(icon) == "string" and icon:match("^rbxassetid://") then
        return icon
    end

    local iconsModule = loadIcons()
    if not iconsModule then
        return nil
    end

    local ok, result = pcall(function()
        return iconsModule.GetIcon(icon)
    end)

    if ok and type(result) == "string" then
        return result
    end

    return nil
end

EmberUI.ResolveIcon = resolveIcon

-- ===================== THEME =====================
local Theme = {
    Background = Color3.fromRGB(20, 20, 20),
    TopbarBackground = Color3.fromRGB(15, 15, 15),
    ElementBackground = Color3.fromRGB(30, 30, 30),
    ElementBackgroundHover = Color3.fromRGB(40, 40, 40),
    Accent = Color3.fromRGB(255, 255, 255),
    ToggleOn = Color3.fromRGB(74, 255, 89),
    ToggleOff = Color3.fromRGB(255, 75, 75),
    Text = Color3.fromRGB(255, 255, 255),
    SubText = Color3.fromRGB(190, 190, 190),
    Font = Enum.Font.Gotham,
    FontBold = Enum.Font.GothamBold,
}

-- ===================== HELPERS =====================
local function create(class, props, children)
    local inst = Instance.new(class)
    for k, v in pairs(props or {}) do
        inst[k] = v
    end
    for _, child in ipairs(children or {}) do
        child.Parent = inst
    end
    return inst
end

local function corner(radius)
    return create("UICorner", { CornerRadius = UDim.new(0, radius or 6) })
end

local function stroke(thickness, color, transparency)
    return create("UIStroke", {
        Thickness = thickness or 1,
        Color = color or Color3.fromRGB(60, 60, 60),
        Transparency = transparency or 0,
    })
end

local function padding(all)
    return create("UIPadding", {
        PaddingTop = UDim.new(0, all),
        PaddingBottom = UDim.new(0, all),
        PaddingLeft = UDim.new(0, all),
        PaddingRight = UDim.new(0, all),
    })
end

local function tween(obj, props, time, style, dir)
    TweenService:Create(
        obj,
        TweenInfo.new(time or 0.15, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out),
        props
    ):Play()
end

-- ===================== WINDOW =====================
function EmberUI.CreateWindow(title)
    local Window = {}

    local screenGui = create("ScreenGui", {
        Name = "EmberUI",
        ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        Parent = PlayerGui,
    })

    -- drop shadow behind the window
    local shadow = create("ImageLabel", {
        Name = "Shadow",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.5, 0, 0.5, 4),
        Size = UDim2.new(1, 60, 1, 60),
        BackgroundTransparency = 1,
        Image = "rbxassetid://1316045217",
        ImageColor3 = Color3.fromRGB(0, 0, 0),
        ImageTransparency = 0.4,
        ScaleType = Enum.ScaleType.Slice,
        SliceCenter = Rect.new(10, 10, 118, 118),
        ZIndex = 0,
        Parent = screenGui,
    })

    local mainFrame = create("Frame", {
        Name = "MainFrame",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.5, 0, 0.5, 0),
        Size = UDim2.new(0.37, 0, 0.407, 0),
        BackgroundColor3 = Theme.Background,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        Parent = screenGui,
    }, { corner(10) })

    -- keep the shadow following/sizing with the main frame
    shadow.Size = UDim2.new(mainFrame.Size.X.Scale, mainFrame.Size.X.Offset + 60, mainFrame.Size.Y.Scale, mainFrame.Size.Y.Offset + 60)
    mainFrame:GetPropertyChangedSignal("Position"):Connect(function()
        shadow.Position = UDim2.new(mainFrame.Position.X.Scale, mainFrame.Position.X.Offset, mainFrame.Position.Y.Scale, mainFrame.Position.Y.Offset + 4)
    end)
    mainFrame:GetPropertyChangedSignal("Size"):Connect(function()
        shadow.Size = UDim2.new(mainFrame.Size.X.Scale, mainFrame.Size.X.Offset + 60, mainFrame.Size.Y.Scale, mainFrame.Size.Y.Offset + 60)
    end)
    mainFrame:GetPropertyChangedSignal("AnchorPoint"):Connect(function()
        shadow.AnchorPoint = mainFrame.AnchorPoint
    end)
    shadow.AnchorPoint = mainFrame.AnchorPoint
    shadow.Position = UDim2.new(mainFrame.Position.X.Scale, mainFrame.Position.X.Offset, mainFrame.Position.Y.Scale, mainFrame.Position.Y.Offset + 4)

    -- optional background image holder (defaults to none -> solid black/theme color)
    local bgImage = create("ImageLabel", {
        Name = "BackgroundImage",
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 1, 0),
        Position = UDim2.new(0, 0, 0, 0),
        Image = "",
        ImageTransparency = 0,
        ScaleType = Enum.ScaleType.Crop,
        ZIndex = 0,
        Parent = mainFrame,
    }, { corner(10) })

    -- ===================== TOPBAR =====================
    local topbar = create("Frame", {
        Name = "Topbar",
        Size = UDim2.new(1, 0, 0, 36),
        BackgroundColor3 = Theme.TopbarBackground,
        BackgroundTransparency = 0.8,
        BorderSizePixel = 0,
        ZIndex = 2,
        Parent = mainFrame,
    }, { corner(10) })

    -- mask the bottom corners of the topbar so it blends into the body
    create("Frame", {
        Name = "TopbarMask",
        Size = UDim2.new(1, 0, 0, 10),
        Position = UDim2.new(0, 0, 1, -10),
        BackgroundColor3 = Theme.TopbarBackground,
        BackgroundTransparency = topbar.BackgroundTransparency,
        BorderSizePixel = 0,
        ZIndex = 2,
        Parent = topbar,
    })

    local titleLabel = create("TextLabel", {
        Name = "Title",
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 12, 0, 0),
        Size = UDim2.new(1, -100, 1, 0),
        Font = Theme.FontBold,
        Text = title or "EmberUI",
        TextColor3 = Theme.Text,
        TextSize = 16,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 3,
        Parent = topbar,
    })

    local btnHolder = create("Frame", {
        Name = "Buttons",
        BackgroundTransparency = 1,
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -8, 0.5, 0),
        Size = UDim2.new(0, 60, 0, 24),
        ZIndex = 3,
        Parent = topbar,
    }, {
        create("UIListLayout", {
            FillDirection = Enum.FillDirection.Horizontal,
            HorizontalAlignment = Enum.HorizontalAlignment.Right,
            VerticalAlignment = Enum.VerticalAlignment.Center,
            Padding = UDim.new(0, 6),
        }),
    })

    local function topbarButton(name, text)
        local btn = create("TextButton", {
            Name = name,
            Size = UDim2.new(0, 24, 0, 24),
            BackgroundColor3 = Theme.ElementBackground,
            BackgroundTransparency = 1,
            AutoButtonColor = false,
            Font = Theme.FontBold,
            Text = text,
            TextColor3 = Theme.Text,
            TextSize = 14,
            ZIndex = 3,
            Parent = btnHolder,
        }, { corner(6) })

        btn.MouseEnter:Connect(function()
            tween(btn, { BackgroundTransparency = 0.8 }, 0.15)
        end)
        btn.MouseLeave:Connect(function()
            tween(btn, { BackgroundTransparency = 1 }, 0.15)
        end)

        return btn
    end

    local closeBtn = topbarButton("Close", "X")
    local minimizeBtn = topbarButton("Minimize", "-")

    topbar.MouseEnter:Connect(function()
        tween(topbar, { BackgroundTransparency = 0.7 }, 0.15)
    end)
    topbar.MouseLeave:Connect(function()
        tween(topbar, { BackgroundTransparency = 0.8 }, 0.15)
    end)

    -- ===================== TABS =====================
    local tabsContainer = create("Frame", {
        Name = "TabsContainer",
        Size = UDim2.new(0, 130, 1, -36),
        Position = UDim2.new(0, 0, 0, 36),
        BackgroundColor3 = Theme.TopbarBackground,
        BackgroundTransparency = 0.85,
        BorderSizePixel = 0,
        ZIndex = 2,
        Parent = mainFrame,
    }, {
        create("UIListLayout", {
            Padding = UDim.new(0, 4),
            SortOrder = Enum.SortOrder.LayoutOrder,
        }),
        padding(8),
    })

    local sectionsHolder = create("Frame", {
        Name = "SectionsHolder",
        Size = UDim2.new(1, -130, 1, -36),
        Position = UDim2.new(0, 130, 0, 36),
        BackgroundTransparency = 1,
        ClipsDescendants = true,
        Parent = mainFrame,
    })

    -- ===================== ENTRANCE ANIMATION =====================
    local fullSize = mainFrame.Size
    do
        local targetSize = fullSize

        mainFrame.Size = UDim2.new(targetSize.X.Scale * 0.85, targetSize.X.Offset * 0.85, targetSize.Y.Scale * 0.85, targetSize.Y.Offset * 0.85)
        mainFrame.BackgroundTransparency = 1
        shadow.ImageTransparency = 1

        tween(mainFrame, { Size = targetSize, BackgroundTransparency = 0 }, 0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
        tween(shadow, { ImageTransparency = 0.4 }, 0.35)
    end
    do
        local dragging = false
        local dragInput, mousePos, framePos

        topbar.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch then
                dragging = true
                mousePos = input.Position
                framePos = mainFrame.Position

                input.Changed:Connect(function()
                    if input.UserInputState == Enum.UserInputState.End then
                        dragging = false
                    end
                end)
            end
        end)

        topbar.InputChanged:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseMovement
                or input.UserInputType == Enum.UserInputType.Touch then
                dragInput = input
            end
        end)

        UserInputService.InputChanged:Connect(function(input)
            if input == dragInput and dragging then
                local delta = input.Position - mousePos
                mainFrame.Position = UDim2.new(
                    framePos.X.Scale,
                    framePos.X.Offset + delta.X,
                    framePos.Y.Scale,
                    framePos.Y.Offset + delta.Y
                )
            end
        end)
    end

    -- ===================== RESIZE HANDLE =====================
    local resizeHandle = create("Frame", {
        Name = "ResizeHandle",
        AnchorPoint = Vector2.new(1, 1),
        Position = UDim2.new(1, -4, 1, -4),
        Size = UDim2.new(0, 16, 0, 16),
        BackgroundTransparency = 1,
        ZIndex = 5,
        Parent = mainFrame,
    })

    create("TextLabel", {
        Name = "Grip",
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 1, 0),
        Font = Theme.FontBold,
        Text = "⌟",
        TextColor3 = Theme.SubText,
        TextTransparency = 0.5,
        TextSize = 16,
        ZIndex = 5,
        Parent = resizeHandle,
    })

    local minSize = Vector2.new(420, 280)

    do
        local resizing = false
        local resizeInput, startMousePos, startSize

        resizeHandle.InputBegan:Connect(function(input)
            if not resizeHandle.Visible then return end
            if input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch then
                resizing = true
                startMousePos = input.Position
                startSize = mainFrame.AbsoluteSize

                input.Changed:Connect(function()
                    if input.UserInputState == Enum.UserInputState.End then
                        resizing = false
                    end
                end)
            end
        end)

        resizeHandle.InputChanged:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseMovement
                or input.UserInputType == Enum.UserInputType.Touch then
                resizeInput = input
            end
        end)

        UserInputService.InputChanged:Connect(function(input)
            if input == resizeInput and resizing then
                local delta = input.Position - startMousePos
                local newWidth = math.max(minSize.X, startSize.X + delta.X)
                local newHeight = math.max(minSize.Y, startSize.Y + delta.Y)
                mainFrame.Size = UDim2.new(0, newWidth, 0, newHeight)
            end
        end)
    end

    -- ===================== WINDOW TOGGLE / CLOSE =====================
    local isOpen = true
    local lastOpenSize = fullSize

    local function setOpen(open)
        if open == isOpen then return end
        isOpen = open

        if open then
            tween(mainFrame, { Size = lastOpenSize }, 0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        else
            lastOpenSize = mainFrame.Size
            tween(mainFrame, { Size = UDim2.new(lastOpenSize.X.Scale, lastOpenSize.X.Offset, 0, 36) }, 0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        end

        resizeHandle.Visible = open
    end

    minimizeBtn.MouseButton1Click:Connect(function()
        setOpen(not isOpen)
    end)

    closeBtn.MouseButton1Click:Connect(function()
        screenGui:Destroy()
    end)

    -- toggle window visibility with K by default
    local toggleKey = Enum.KeyCode.K
    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        if input.KeyCode == toggleKey then
            screenGui.Enabled = not screenGui.Enabled
            shadow.Visible = screenGui.Enabled
        end
    end)

    -- ===================== TABS API =====================
    local tabs = {}
    local currentTab = nil

    function Window:SetBackgroundImage(imageId)
        bgImage.Image = imageId or ""
    end

    function Window:SetToggleKey(keyCode)
        toggleKey = keyCode
    end

    function Window:Destroy()
        screenGui:Destroy()
    end

    function Window:CreateTab(name, icon)
        local Tab = {}

        local tabButton = create("TextButton", {
            Name = name,
            Size = UDim2.new(1, 0, 0, 32),
            BackgroundColor3 = Theme.ElementBackground,
            BackgroundTransparency = 0.8,
            AutoButtonColor = false,
            Text = "",
            Parent = tabsContainer,
        }, { corner(6) })

        local tabLayout = create("Frame", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 1, 0),
            Parent = tabButton,
        }, {
            create("UIListLayout", {
                FillDirection = Enum.FillDirection.Horizontal,
                VerticalAlignment = Enum.VerticalAlignment.Center,
                Padding = UDim.new(0, 6),
            }),
            padding(6),
        })

        local resolvedIcon = resolveIcon(icon)
        if resolvedIcon then
            create("ImageLabel", {
                Name = "Icon",
                Size = UDim2.new(0, 18, 0, 18),
                BackgroundTransparency = 1,
                Image = resolvedIcon,
                ImageColor3 = Theme.SubText,
                Parent = tabLayout,
            })
        end

        create("TextLabel", {
            Name = "TitleLabel",
            BackgroundTransparency = 1,
            Size = UDim2.new(1, -24, 1, 0),
            Font = Theme.Font,
            Text = name,
            TextColor3 = Theme.SubText,
            TextSize = 14,
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = tabLayout,
        })

        local section = create("ScrollingFrame", {
            Name = name .. "Section",
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            ScrollBarThickness = 3,
            ScrollBarImageColor3 = Theme.SubText,
            CanvasSize = UDim2.new(0, 0, 0, 0),
            AutomaticCanvasSize = Enum.AutomaticSize.Y,
            Visible = false,
            Parent = sectionsHolder,
        }, {
            create("UIListLayout", {
                Padding = UDim.new(0, 6),
                SortOrder = Enum.SortOrder.LayoutOrder,
            }),
            padding(10),
        })

        local function select()
            if currentTab == Tab then return end

            if currentTab then
                currentTab._section.Visible = false
                tween(currentTab._button, { BackgroundTransparency = 0.8 }, 0.15)
                currentTab._titleLabel.TextColor3 = Theme.SubText
            end

            section.Visible = true
            tween(tabButton, { BackgroundTransparency = 0.6 }, 0.15)
            tabLayout.TitleLabel.TextColor3 = Theme.Text

            currentTab = Tab
        end

        tabButton.MouseEnter:Connect(function()
            if currentTab ~= Tab then
                tween(tabButton, { BackgroundTransparency = 0.7 }, 0.15)
            end
        end)
        tabButton.MouseLeave:Connect(function()
            if currentTab ~= Tab then
                tween(tabButton, { BackgroundTransparency = 0.8 }, 0.15)
            end
        end)
        tabButton.MouseButton1Click:Connect(select)

        Tab._button = tabButton
        Tab._section = section
        Tab._titleLabel = tabLayout.TitleLabel

        if #tabs == 0 then
            select()
        end

        table.insert(tabs, Tab)

        -- ===================== ELEMENTS =====================
        function Tab:CreateLabel(text)
            local label = create("TextLabel", {
                Size = UDim2.new(1, 0, 0, 24),
                BackgroundTransparency = 1,
                Font = Theme.Font,
                Text = text,
                TextColor3 = Theme.SubText,
                TextSize = 14,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextWrapped = true,
                Parent = section,
            })
            return label
        end

        function Tab:CreateButton(text, callback)
            callback = callback or function() end

            local btn = create("TextButton", {
                Size = UDim2.new(1, 0, 0, 34),
                BackgroundColor3 = Theme.ElementBackground,
                BackgroundTransparency = 0.8,
                AutoButtonColor = false,
                Font = Theme.Font,
                Text = text,
                TextColor3 = Theme.Text,
                TextSize = 14,
                Parent = section,
            }, { corner(6) })

            btn.MouseEnter:Connect(function()
                tween(btn, { BackgroundTransparency = 0.7 }, 0.15)
            end)
            btn.MouseLeave:Connect(function()
                tween(btn, { BackgroundTransparency = 0.8 }, 0.15)
            end)
            btn.MouseButton1Click:Connect(function()
                callback()
            end)

            return btn
        end

        function Tab:CreateToggle(text, default, callback)
            callback = callback or function() end
            local toggled = default or false

            local holder = create("TextButton", {
                Size = UDim2.new(1, 0, 0, 34),
                BackgroundColor3 = Theme.ElementBackground,
                BackgroundTransparency = 0.8,
                AutoButtonColor = false,
                Text = "",
                Parent = section,
            }, { corner(6) })

            create("TextLabel", {
                Name = "Label",
                BackgroundTransparency = 1,
                Position = UDim2.new(0, 12, 0, 0),
                Size = UDim2.new(1, -60, 1, 0),
                Font = Theme.Font,
                Text = text,
                TextColor3 = Theme.Text,
                TextSize = 14,
                TextXAlignment = Enum.TextXAlignment.Left,
                Parent = holder,
            })

            local toggleBg = create("Frame", {
                Name = "ToggleBg",
                AnchorPoint = Vector2.new(1, 0.5),
                Position = UDim2.new(1, -12, 0.5, 0),
                Size = UDim2.new(0, 36, 0, 18),
                BackgroundColor3 = toggled and Theme.ToggleOn or Theme.ToggleOff,
                Parent = holder,
            }, { corner(9) })

            local sideTog = create("Frame", {
                Name = "Knob",
                AnchorPoint = toggled and Vector2.new(1, 0.5) or Vector2.new(0, 0.5),
                Position = toggled and UDim2.new(1, -2, 0.5, 0) or UDim2.new(0, 2, 0.5, 0),
                Size = UDim2.new(0, 14, 0, 14),
                BackgroundColor3 = Color3.fromRGB(255, 255, 255),
                Parent = toggleBg,
            }, { corner(7) })

            holder.MouseEnter:Connect(function()
                tween(holder, { BackgroundTransparency = 0.7 }, 0.15)
            end)
            holder.MouseLeave:Connect(function()
                tween(holder, { BackgroundTransparency = 0.8 }, 0.15)
            end)

            holder.MouseButton1Click:Connect(function()
                toggled = not toggled

                tween(sideTog, {
                    AnchorPoint = toggled and Vector2.new(1, 0.5) or Vector2.new(0, 0.5),
                    Position = toggled and UDim2.new(1, -2, 0.5, 0) or UDim2.new(0, 2, 0.5, 0),
                }, 0.15)

                tween(toggleBg, {
                    BackgroundColor3 = toggled and Theme.ToggleOn or Theme.ToggleOff,
                }, 0.15)

                callback(toggled)
            end)

            if toggled then
                task.defer(callback, toggled)
            end

            return {
                Set = function(_, value)
                    toggled = value
                    sideTog.AnchorPoint = toggled and Vector2.new(1, 0.5) or Vector2.new(0, 0.5)
                    sideTog.Position = toggled and UDim2.new(1, -2, 0.5, 0) or UDim2.new(0, 2, 0.5, 0)
                    toggleBg.BackgroundColor3 = toggled and Theme.ToggleOn or Theme.ToggleOff
                    callback(toggled)
                end,
            }
        end

        function Tab:CreateTextbox(text, default, callback)
            callback = callback or function() end
            default = default or ""

            local holder = create("Frame", {
                Size = UDim2.new(1, 0, 0, 34),
                BackgroundColor3 = Theme.ElementBackground,
                BackgroundTransparency = 0.8,
                Parent = section,
            }, { corner(6) })

            create("TextLabel", {
                Name = "Label",
                BackgroundTransparency = 1,
                Position = UDim2.new(0, 12, 0, 0),
                Size = UDim2.new(0.5, -12, 1, 0),
                Font = Theme.Font,
                Text = text,
                TextColor3 = Theme.Text,
                TextSize = 14,
                TextXAlignment = Enum.TextXAlignment.Left,
                Parent = holder,
            })

            local inputBg = create("Frame", {
                Name = "InputBg",
                AnchorPoint = Vector2.new(1, 0.5),
                Position = UDim2.new(1, -8, 0.5, 0),
                Size = UDim2.new(0.5, -8, 0, 24),
                BackgroundColor3 = Theme.TopbarBackground,
                Parent = holder,
            }, { corner(4) })

            local textBox = create("TextBox", {
                BackgroundTransparency = 1,
                Size = UDim2.new(1, -12, 1, 0),
                Position = UDim2.new(0, 6, 0, 0),
                Font = Theme.Font,
                Text = default,
                PlaceholderText = "...",
                TextColor3 = Theme.Text,
                TextSize = 14,
                ClearTextOnFocus = false,
                TextXAlignment = Enum.TextXAlignment.Left,
                Parent = inputBg,
            })

            if default ~= "" then
                task.defer(callback, default)
            end

            textBox.FocusLost:Connect(function(enterPressed)
                if enterPressed then
                    callback(textBox.Text)
                end
            end)

            return {
                Set = function(_, value)
                    textBox.Text = value
                    callback(value)
                end,
            }
        end

        function Tab:CreateSlider(text, min, max, default, callback)
            callback = callback or function() end
            default = math.clamp(default or min, min, max)

            local holder = create("Frame", {
                Size = UDim2.new(1, 0, 0, 46),
                BackgroundColor3 = Theme.ElementBackground,
                BackgroundTransparency = 0.8,
                Parent = section,
            }, { corner(6) })

            local label = create("TextLabel", {
                Name = "Label",
                BackgroundTransparency = 1,
                Position = UDim2.new(0, 12, 0, 4),
                Size = UDim2.new(1, -24, 0, 18),
                Font = Theme.Font,
                Text = text .. " : " .. tostring(default),
                TextColor3 = Theme.Text,
                TextSize = 14,
                TextXAlignment = Enum.TextXAlignment.Left,
                Parent = holder,
            })

            local track = create("Frame", {
                Name = "Track",
                AnchorPoint = Vector2.new(0.5, 1),
                Position = UDim2.new(0.5, 0, 1, -8),
                Size = UDim2.new(1, -24, 0, 6),
                BackgroundColor3 = Theme.TopbarBackground,
                Parent = holder,
            }, { corner(3) })

            local fill = create("Frame", {
                Name = "Fill",
                Size = UDim2.new((default - min) / (max - min), 0, 1, 0),
                BackgroundColor3 = Theme.Accent,
                Parent = track,
            }, { corner(3) })

            local dragging = false
            local lastValue = default

            local function setFromAlpha(alpha)
                alpha = math.clamp(alpha, 0, 1)
                local value = math.floor(min + (max - min) * alpha + 0.5)
                fill.Size = UDim2.new(alpha, 0, 1, 0)
                label.Text = text .. " : " .. tostring(value)
                lastValue = value
            end

            local function updateFromInput(x)
                local rel = (x - track.AbsolutePosition.X) / track.AbsoluteSize.X
                setFromAlpha(rel)
            end

            track.InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1
                    or input.UserInputType == Enum.UserInputType.Touch then
                    dragging = true
                    updateFromInput(input.Position.X)
                end
            end)

            UserInputService.InputChanged:Connect(function(input)
                if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
                    or input.UserInputType == Enum.UserInputType.Touch) then
                    updateFromInput(input.Position.X)
                end
            end)

            UserInputService.InputEnded:Connect(function(input)
                if dragging and (input.UserInputType == Enum.UserInputType.MouseButton1
                    or input.UserInputType == Enum.UserInputType.Touch) then
                    dragging = false
                    callback(lastValue)
                end
            end)

            return {
                Set = function(_, value)
                    local alpha = (value - min) / (max - min)
                    setFromAlpha(alpha)
                    callback(lastValue)
                end,
            }
        end

        function Tab:CreateDropdown(text, options, default, callback)
            callback = callback or function() end
            options = options or {}
            default = default or options[1]

            local holder = create("Frame", {
                Size = UDim2.new(1, 0, 0, 34),
                BackgroundColor3 = Theme.ElementBackground,
                BackgroundTransparency = 0.8,
                ClipsDescendants = false,
                ZIndex = 5,
                Parent = section,
            }, { corner(6) })

            create("TextLabel", {
                Name = "Label",
                BackgroundTransparency = 1,
                Position = UDim2.new(0, 12, 0, 0),
                Size = UDim2.new(0.5, -12, 1, 0),
                Font = Theme.Font,
                Text = text,
                TextColor3 = Theme.Text,
                TextSize = 14,
                TextXAlignment = Enum.TextXAlignment.Left,
                ZIndex = 5,
                Parent = holder,
            })

            local selectorBtn = create("TextButton", {
                Name = "Selector",
                AnchorPoint = Vector2.new(1, 0.5),
                Position = UDim2.new(1, -8, 0.5, 0),
                Size = UDim2.new(0.5, -8, 0, 24),
                BackgroundColor3 = Theme.TopbarBackground,
                AutoButtonColor = false,
                Font = Theme.Font,
                Text = tostring(default) .. "  v",
                TextColor3 = Theme.Text,
                TextSize = 13,
                ZIndex = 5,
                Parent = holder,
            }, { corner(4) })

            local listFrame = create("Frame", {
                Name = "List",
                BackgroundColor3 = Theme.TopbarBackground,
                Position = UDim2.new(0, 0, 1, 4),
                Size = UDim2.new(1, 0, 0, 0),
                ClipsDescendants = true,
                Visible = false,
                ZIndex = 10,
                Parent = selectorBtn,
            }, {
                corner(4),
                create("UIListLayout", {
                    SortOrder = Enum.SortOrder.LayoutOrder,
                }),
            })

            local open = false
            local optionHeight = 24

            local function close()
                open = false
                tween(listFrame, { Size = UDim2.new(1, 0, 0, 0) }, 0.15)
                task.delay(0.15, function()
                    if not open then
                        listFrame.Visible = false
                    end
                end)
            end

            local function selectOption(value)
                selectorBtn.Text = tostring(value) .. "  v"
                callback(value)
                close()
            end

            for _, option in ipairs(options) do
                local optBtn = create("TextButton", {
                    Size = UDim2.new(1, 0, 0, optionHeight),
                    BackgroundColor3 = Theme.ElementBackground,
                    BackgroundTransparency = 0.5,
                    AutoButtonColor = false,
                    Font = Theme.Font,
                    Text = tostring(option),
                    TextColor3 = Theme.Text,
                    TextSize = 13,
                    ZIndex = 11,
                    Parent = listFrame,
                })

                optBtn.MouseEnter:Connect(function()
                    tween(optBtn, { BackgroundTransparency = 0.2 }, 0.1)
                end)
                optBtn.MouseLeave:Connect(function()
                    tween(optBtn, { BackgroundTransparency = 0.5 }, 0.1)
                end)
                optBtn.MouseButton1Click:Connect(function()
                    selectOption(option)
                end)
            end

            selectorBtn.MouseButton1Click:Connect(function()
                open = not open
                if open then
                    listFrame.Visible = true
                    tween(listFrame, { Size = UDim2.new(1, 0, 0, optionHeight * #options) }, 0.15)
                else
                    close()
                end
            end)

            if default then
                task.defer(callback, default)
            end

            return {
                Set = function(_, value)
                    selectOption(value)
                end,
                Refresh = function(_, newOptions, newDefault)
                    for _, child in ipairs(listFrame:GetChildren()) do
                        if child:IsA("TextButton") then
                            child:Destroy()
                        end
                    end
                    options = newOptions or {}
                    for _, option in ipairs(options) do
                        local optBtn = create("TextButton", {
                            Size = UDim2.new(1, 0, 0, optionHeight),
                            BackgroundColor3 = Theme.ElementBackground,
                            BackgroundTransparency = 0.5,
                            AutoButtonColor = false,
                            Font = Theme.Font,
                            Text = tostring(option),
                            TextColor3 = Theme.Text,
                            TextSize = 13,
                            ZIndex = 11,
                            Parent = listFrame,
                        })
                        optBtn.MouseEnter:Connect(function()
                            tween(optBtn, { BackgroundTransparency = 0.2 }, 0.1)
                        end)
                        optBtn.MouseLeave:Connect(function()
                            tween(optBtn, { BackgroundTransparency = 0.5 }, 0.1)
                        end)
                        optBtn.MouseButton1Click:Connect(function()
                            selectOption(option)
                        end)
                    end
                    if newDefault then
                        selectorBtn.Text = tostring(newDefault) .. "  v"
                    end
                end,
            }
        end

        function Tab:CreateSection(title)
            create("TextLabel", {
                Size = UDim2.new(1, 0, 0, 24),
                BackgroundTransparency = 1,
                Font = Theme.FontBold,
                Text = title,
                TextColor3 = Theme.SubText,
                TextSize = 13,
                TextXAlignment = Enum.TextXAlignment.Left,
                Parent = section,
            })
        end

        return Tab
    end

    return Window
end

return EmberUI
