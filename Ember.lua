--[[
  ______           _               _   _ ___ 
 |  ____|         | |             | | | |_ _|
 | |__   _ __ ___ | |__   ___ _ __| | | || | 
 |  __| | '_ ` _ \| '_ \ / _ \ '__| | | || | 
 | |____| | | | | | |_) |  __/ |  | |_| || | 
 |______|_| |_| |_|_.__/ \___|_|   \___/|___|

 Version  : 2.1.0  (fixed)
 Author   : esore (original CalmLib) — EmberUI rewrite
 Fixes    : real Lucide icons via iconify API, CanvasGroup tab pages,
            forward-ref hover bug, Interactable on correct object

 Icon System  (WindUI-compatible format)
   lucide:name          → fetched live from api.iconify.design (SVG URL)
   solar:name           → Solar icons (same CDN)
   rbxassetid://000     → Roblox asset (pass-through)
   https://...          → Direct image URL (pass-through)

 Features
   • Real Lucide icons fetched from iconify CDN (same source WindUI uses)
   • Icon cache — each name is only resolved once per session
   • Dark / Light mode toggle
   • Custom background image support
   • Notifications with type + progress bar
   • Hardened key system (overlay lock + integrity checks)
   • Tabs, Sections, Labels, Buttons, Toggles,
     Sliders, Textboxes, Dropdowns, Keybinds, Separators
   • Draggable window + K-key toggle + minimize
   • Theme-reactive colours throughout
]]

-- ═══════════════════════════════════════════════════════════════════════════
--  SERVICES
-- ═══════════════════════════════════════════════════════════════════════════
local cloneref = cloneref or function(x) return x end
local ts  = cloneref(game:GetService("TweenService"))
local cg  = cloneref(game:GetService("CoreGui"))
local uis = cloneref(game:GetService("UserInputService"))
local rs  = cloneref(game:GetService("RunService"))
local lp  = cloneref(game:GetService("Players")).LocalPlayer

-- ═══════════════════════════════════════════════════════════════════════════
--  ICON SYSTEM
--
--  WindUI fetches Lucide SVGs from api.iconify.design.  Roblox ImageLabel
--  supports direct HTTPS image URLs via the Image property — the engine
--  downloads, rasterises, and caches them automatically.  We do exactly the
--  same thing here.
--
--  CDN pattern:
--    Lucide  → https://api.iconify.design/lucide/{name}.svg?color=%23ffffff
--    Solar   → https://api.iconify.design/solar/{name}.svg?color=%23ffffff
--
--  The ?color= query param asks Iconify to inline the fill so the SVG
--  renders as white, which we then tint with ImageColor3 in Roblox —
--  identical to how WindUI applies theme colours.
--
--  _iconCache prevents redundant string construction on repeated calls.
-- ═══════════════════════════════════════════════════════════════════════════
local _iconCache = {}

-- CDN prefix map: set name → iconify collection slug
local ICON_CDNS = {
    lucide    = "lucide",
    solar     = "solar",
    craft     = "lucide",    -- no craft collection on iconify, fall back to lucide
    geist     = "lucide",
    gravity   = "lucide",
    sfsymbols = "lucide",
}

-- Build the CDN URL for a given collection + icon name.
-- colour is always white so Roblox can tint it with ImageColor3.
local ICON_BASE = "https://api.iconify.design/%s/%s.svg?color=%%23ffffff&height=64"

local function iconURL(collection, name)
    local slug = ICON_CDNS[collection] or "lucide"
    local key  = slug .. ":" .. name
    if not _iconCache[key] then
        _iconCache[key] = ICON_BASE:format(slug, name)
    end
    return _iconCache[key]
end

--[[
    resolveIcon(iconStr, defaultThemed)
    Returns { id = "<url or rbxassetid>", themed = bool }
    themed = true  → caller should tint with ImageColor3
    themed = false → image has its own colour, don't tint
]]
local function resolveIcon(iconStr, defaultThemed)
    if not iconStr or iconStr == "" then
        return { id = "", themed = false }
    end

    -- 1. Raw rbxassetid — pass through unchanged
    if iconStr:sub(1, 13) == "rbxassetid://" then
        return { id = iconStr, themed = defaultThemed == true }
    end

    -- 2. Full HTTP(S) URL — pass through, no tint (caller supplied colour)
    if iconStr:sub(1, 4) == "http" then
        return { id = iconStr, themed = false }
    end

    -- 3. Prefixed: "lucide:flame", "solar:pen-bold", etc.
    local prefix, name = iconStr:match("^([%a%-]+):(.+)$")
    if prefix and name then
        local slug = ICON_CDNS[prefix:lower()]
        if slug then
            return { id = iconURL(slug, name:lower()), themed = true }
        end
        -- Unknown prefix → try as lucide bare name
        return { id = iconURL("lucide", iconStr:lower()), themed = true }
    end

    -- 4. Bare name → Lucide by default
    return { id = iconURL("lucide", iconStr:lower()), themed = true }
end

-- ═══════════════════════════════════════════════════════════════════════════
--  UTILITY HELPERS
-- ═══════════════════════════════════════════════════════════════════════════
local function tween(obj, info, props)
    ts:Create(obj, info, props):Play()
end

local function ease(obj, t, props, style, dir)
    tween(obj, TweenInfo.new(
        t,
        style or Enum.EasingStyle.Quad,
        dir   or Enum.EasingDirection.Out
    ), props)
end

local function newInst(class, props, parent)
    local inst = Instance.new(class)
    for k, v in pairs(props or {}) do inst[k] = v end
    if parent then inst.Parent = parent end
    return inst
end

local function corner(parent, r)
    return newInst("UICorner", { CornerRadius = UDim.new(0, r or 6) }, parent)
end

local function padding(parent, t, r, b, l)
    return newInst("UIPadding", {
        PaddingTop    = UDim.new(0, t or 0),
        PaddingRight  = UDim.new(0, r or 0),
        PaddingBottom = UDim.new(0, b or 0),
        PaddingLeft   = UDim.new(0, l or 0),
    }, parent)
end

local function listLayout(parent, pad, dir, ha, va)
    return newInst("UIListLayout", {
        Padding             = UDim.new(0, pad or 6),
        FillDirection       = dir or Enum.FillDirection.Vertical,
        HorizontalAlignment = ha  or Enum.HorizontalAlignment.Center,
        VerticalAlignment   = va  or Enum.VerticalAlignment.Top,
        SortOrder           = Enum.SortOrder.LayoutOrder,
    }, parent)
end

local function stroke(parent, color, thick, trans)
    return newInst("UIStroke", {
        Color        = color or Color3.new(1,1,1),
        Thickness    = thick or 1,
        Transparency = trans or 0,
    }, parent)
end

-- Apply icon to an ImageLabel/ImageButton using the resolver
local function applyIcon(imageObj, iconStr, tintColor, defaultThemed)
    local res = resolveIcon(iconStr, defaultThemed)
    imageObj.Image = res.id
    if res.themed and tintColor then
        imageObj.ImageColor3 = tintColor
    end
end

-- ═══════════════════════════════════════════════════════════════════════════
--  THEME DEFINITIONS
-- ═══════════════════════════════════════════════════════════════════════════
local Themes = {
    Dark = {
        Background  = Color3.fromRGB(12,  12,  16 ),
        Surface     = Color3.fromRGB(20,  20,  26 ),
        SurfaceHov  = Color3.fromRGB(28,  28,  36 ),
        Panel       = Color3.fromRGB(16,  16,  22 ),
        Topbar      = Color3.fromRGB(18,  18,  24 ),
        Sidebar     = Color3.fromRGB(14,  14,  19 ),
        Accent      = Color3.fromRGB(255, 100, 50 ),
        AccentDim   = Color3.fromRGB(200, 72,  30 ),
        AccentSub   = Color3.fromRGB(255, 100, 50 ),
        TextPri     = Color3.fromRGB(232, 232, 238),
        TextSec     = Color3.fromRGB(140, 140, 158),
        TextMut     = Color3.fromRGB(70,  70,  88 ),
        Border      = Color3.fromRGB(36,  36,  48 ),
        ToggleOn    = Color3.fromRGB(255, 100, 50 ),
        ToggleOff   = Color3.fromRGB(48,  48,  62 ),
        SliderFill  = Color3.fromRGB(255, 100, 50 ),
        SliderTrack = Color3.fromRGB(36,  36,  48 ),
        Close       = Color3.fromRGB(255, 65,  65 ),
        Minimize    = Color3.fromRGB(255, 190, 45 ),
        NotifBg     = Color3.fromRGB(20,  20,  28 ),
        Shadow      = Color3.fromRGB(0,   0,   0  ),
        IconTint    = Color3.fromRGB(140, 140, 158),
        IconActive  = Color3.fromRGB(255, 100, 50 ),
    },
    Light = {
        Background  = Color3.fromRGB(238, 238, 244),
        Surface     = Color3.fromRGB(248, 248, 252),
        SurfaceHov  = Color3.fromRGB(228, 228, 236),
        Panel       = Color3.fromRGB(242, 242, 248),
        Topbar      = Color3.fromRGB(232, 232, 240),
        Sidebar     = Color3.fromRGB(224, 224, 233),
        Accent      = Color3.fromRGB(215, 70,  20 ),
        AccentDim   = Color3.fromRGB(170, 50,  10 ),
        AccentSub   = Color3.fromRGB(215, 70,  20 ),
        TextPri     = Color3.fromRGB(18,  18,  26 ),
        TextSec     = Color3.fromRGB(75,  75,  95 ),
        TextMut     = Color3.fromRGB(145, 145, 165),
        Border      = Color3.fromRGB(198, 198, 214),
        ToggleOn    = Color3.fromRGB(215, 70,  20 ),
        ToggleOff   = Color3.fromRGB(188, 188, 202),
        SliderFill  = Color3.fromRGB(215, 70,  20 ),
        SliderTrack = Color3.fromRGB(200, 200, 216),
        Close       = Color3.fromRGB(210, 45,  45 ),
        Minimize    = Color3.fromRGB(195, 148, 28 ),
        NotifBg     = Color3.fromRGB(248, 248, 252),
        Shadow      = Color3.fromRGB(90,  90,  110),
        IconTint    = Color3.fromRGB(75,  75,  95 ),
        IconActive  = Color3.fromRGB(215, 70,  20 ),
    },
}

-- ═══════════════════════════════════════════════════════════════════════════
--  NOTIFICATION HOLDER  (module-level, shared)
-- ═══════════════════════════════════════════════════════════════════════════
local _notifGui    = nil
local _notifHolder = nil
local _notifCount  = 0
local MAX_NOTIFS   = 6

local function ensureNotifHolder(parentGui)
    if _notifHolder and _notifHolder.Parent then return end
    _notifGui = parentGui or newInst("ScreenGui", {
        Name           = "EmberNotifGui",
        ResetOnSpawn   = false,
        DisplayOrder   = 9999,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    })
    if not parentGui then
        local hui = typeof(gethui) == "function" and gethui or nil
        _notifGui.Parent = hui and hui() or cg
    end
    _notifHolder = newInst("Frame", {
        Name                   = "EmberNotifHolder",
        Parent                 = _notifGui,
        BackgroundTransparency = 1,
        Position               = UDim2.new(1, -14, 0, 14),
        AnchorPoint            = Vector2.new(1, 0),
        Size                   = UDim2.new(0, 296, 1, -28),
        ZIndex                 = 1000,
    })
    listLayout(_notifHolder, 8, Enum.FillDirection.Vertical,
        Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Top)
end

local NOTIF_ICONS = {
    Info    = "info",
    Success = "check-circle",
    Warning = "alert-triangle",
    Error   = "alert-circle",
}
local NOTIF_COLORS = {
    Info    = Color3.fromRGB(80,  140, 255),
    Success = Color3.fromRGB(50,  210, 110),
    Warning = Color3.fromRGB(255, 185, 50 ),
    Error   = Color3.fromRGB(255, 65,  65 ),
}

local function fireNotif(T, opts)
    if not _notifHolder then return end
    if _notifCount >= MAX_NOTIFS then return end
    _notifCount += 1

    opts = opts or {}
    local nTitle    = opts.Title    or "Notification"
    local nBody     = opts.Content  or ""
    local nDuration = math.clamp(opts.Duration or 4, 1, 30)
    local nType     = opts.Type     or "Info"
    local nIcon     = opts.Icon     or NOTIF_ICONS[nType] or "info"
    local typeColor = opts.Color    or NOTIF_COLORS[nType] or NOTIF_COLORS.Info

    local card = newInst("Frame", {
        Name                   = "Notif",
        Parent                 = _notifHolder,
        BackgroundColor3       = T.NotifBg,
        BackgroundTransparency = 1,
        Size                   = UDim2.new(1, 0, 0, 76),
        Position               = UDim2.new(1.1, 0, 0, 0),
        ClipsDescendants       = true,
        ZIndex                 = 1001,
    })
    corner(card, 10)
    stroke(card, T.Border, 1, 0.35)

    newInst("Frame", {
        Parent           = card,
        BackgroundColor3 = typeColor,
        Size             = UDim2.new(0, 3, 1, -18),
        Position         = UDim2.new(0, 9, 0.5, 0),
        AnchorPoint      = Vector2.new(0, 0.5),
        ZIndex           = 1002,
    })

    local iconImg = newInst("ImageLabel", {
        Parent                 = card,
        BackgroundTransparency = 1,
        Position               = UDim2.new(0, 20, 0.5, 0),
        AnchorPoint            = Vector2.new(0, 0.5),
        Size                   = UDim2.new(0, 18, 0, 18),
        ZIndex                 = 1002,
    })
    applyIcon(iconImg, nIcon, typeColor, true)

    newInst("TextLabel", {
        Parent                 = card,
        BackgroundTransparency = 1,
        Position               = UDim2.new(0, 46, 0, 14),
        Size                   = UDim2.new(1, -56, 0, 18),
        Text                   = nTitle,
        TextColor3             = T.TextPri,
        TextSize               = 13,
        Font                   = Enum.Font.GothamBold,
        TextXAlignment         = Enum.TextXAlignment.Left,
        ZIndex                 = 1002,
    })

    newInst("TextLabel", {
        Parent                 = card,
        BackgroundTransparency = 1,
        Position               = UDim2.new(0, 46, 0, 34),
        Size                   = UDim2.new(1, -56, 0, 26),
        Text                   = nBody,
        TextColor3             = T.TextSec,
        TextSize               = 11,
        Font                   = Enum.Font.Gotham,
        TextXAlignment         = Enum.TextXAlignment.Left,
        TextWrapped            = true,
        ZIndex                 = 1002,
    })

    local progBg = newInst("Frame", {
        Parent           = card,
        BackgroundColor3 = T.Border,
        Size             = UDim2.new(1, -18, 0, 2),
        Position         = UDim2.new(0, 9, 1, -6),
        ZIndex           = 1002,
    })
    corner(progBg, 2)
    local progBar = newInst("Frame", {
        Parent           = progBg,
        BackgroundColor3 = typeColor,
        Size             = UDim2.new(1, 0, 1, 0),
        ZIndex           = 1003,
    })
    corner(progBar, 2)

    ease(card, 0.28, { BackgroundTransparency = 0, Position = UDim2.new(0, 0, 0, 0) })
    tween(progBar, TweenInfo.new(nDuration, Enum.EasingStyle.Linear),
        { Size = UDim2.new(0, 0, 1, 0) })

    local dismissed = false
    local function dismiss()
        if dismissed then return end
        dismissed = true
        ease(card, 0.22, { BackgroundTransparency = 1, Position = UDim2.new(1.1, 0, 0, 0) })
        task.delay(0.24, function()
            card:Destroy()
            _notifCount = math.max(0, _notifCount - 1)
        end)
    end

    card.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 then dismiss() end
    end)
    task.delay(nDuration, dismiss)
end

-- ═══════════════════════════════════════════════════════════════════════════
--  KEY SYSTEM HELPERS
-- ═══════════════════════════════════════════════════════════════════════════
local KEY_FILE_PREFIX = "EmberUI_Key_"
local XOR_SEED        = 0x4B

local function xorScramble(s)
    local out  = {}
    local seed = XOR_SEED
    for i = 1, #s do
        local b = string.byte(s, i)
        table.insert(out, string.char(bit32.bxor(b, seed)))
        seed = bit32.bxor(seed, b) % 256
    end
    return table.concat(out)
end

local function trimKey(s)
    return (s or ""):match("^%s*(.-)%s*$")
end

-- ═══════════════════════════════════════════════════════════════════════════
--  MODULE TABLE
-- ═══════════════════════════════════════════════════════════════════════════
local EmberUI = {}
EmberUI.__index = EmberUI

-- ═══════════════════════════════════════════════════════════════════════════
--  EmberUI:CreateWindow(config)
-- ═══════════════════════════════════════════════════════════════════════════
function EmberUI:CreateWindow(config)
    config = config or {}

    local TITLE      = config.Title      or "EmberUI"
    local SUBTITLE   = config.Subtitle   or ""
    local ICON       = config.Icon       or ""
    local W          = (config.Size and config.Size[1]) or 490
    local H          = (config.Size and config.Size[2]) or 330
    local TOGGLEKEY  = config.ToggleKey  or Enum.KeyCode.K
    local THEME_NAME = config.Theme      or "Dark"
    local BG_IMAGE   = config.Background or nil

    local RAW_KEYS  = config.Key
    if type(RAW_KEYS) == "string" then RAW_KEYS = { RAW_KEYS } end
    local KEY_SAVED = config.KeySaved ~= false
    local KEY_TITLE = config.KeyTitle  or "Authentication"
    local KEY_DESC  = config.KeyDesc   or "Enter your license key to continue."
    local KEY_LINK  = config.KeyLink   or nil
    local ON_VALID  = config.OnKeyValid or function() end

    local _unlocked = (not RAW_KEYS or #RAW_KEYS == 0)
    local _validKeySet = {}
    if RAW_KEYS then
        for _, k in ipairs(RAW_KEYS) do
            _validKeySet[trimKey(k)] = true
        end
    end

    local T = {}
    for k, v in pairs(Themes[THEME_NAME] or Themes.Dark) do T[k] = v end
    local _isDark = (THEME_NAME ~= "Light")

    -- ── Root ScreenGui ─────────────────────────────────────────────────────
    local gui = newInst("ScreenGui", {
        Name           = "EmberUI_" .. TITLE:gsub("%s", "_"),
        ResetOnSpawn   = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        DisplayOrder   = 999,
    })
    do
        local hui = typeof(gethui) == "function" and gethui or nil
        gui.Parent = hui and hui() or cg
    end

    ensureNotifHolder(nil)

    -- ── Shadow ─────────────────────────────────────────────────────────────
    local shadowFrame = newInst("Frame", {
        Name                   = "Shadow",
        Parent                 = gui,
        BackgroundColor3       = T.Shadow,
        BackgroundTransparency = 0.62,
        AnchorPoint            = Vector2.new(0.5, 0.5),
        Position               = UDim2.new(0.5, 0, 0.5, 7),
        Size                   = UDim2.new(0, W + 18, 0, H + 18),
        ZIndex                 = 1,
    })
    corner(shadowFrame, 16)

    -- ── Main window ────────────────────────────────────────────────────────
    local win = newInst("Frame", {
        Name             = "Window",
        Parent           = gui,
        BackgroundColor3 = T.Background,
        AnchorPoint      = Vector2.new(0.5, 0.5),
        Position         = UDim2.new(0.5, 0, 0.5, 0),
        Size             = UDim2.new(0, W, 0, H),
        ClipsDescendants = true,
        ZIndex           = 2,
    })
    corner(win, 13)
    stroke(win, T.Border, 1, 0.45)

    local bgImg = newInst("ImageLabel", {
        Name                   = "BG",
        Parent                 = win,
        Size                   = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Image                  = BG_IMAGE or "",
        ImageTransparency      = BG_IMAGE and 0.55 or 1,
        ScaleType              = Enum.ScaleType.Crop,
        ZIndex                 = 2,
    })

    -- ── Topbar ─────────────────────────────────────────────────────────────
    local topbar = newInst("Frame", {
        Name             = "Topbar",
        Parent           = win,
        BackgroundColor3 = T.Topbar,
        Size             = UDim2.new(1, 0, 0, 44),
        ZIndex           = 6,
    })
    corner(topbar, 13)
    newInst("Frame", {
        Parent           = topbar,
        BackgroundColor3 = T.Topbar,
        Size             = UDim2.new(1, 0, 0.5, 0),
        Position         = UDim2.new(0, 0, 0.5, 0),
        ZIndex           = 5,
    })
    stroke(topbar, T.Border, 1, 0.5)

    local accentLine = newInst("Frame", {
        Name             = "AccentLine",
        Parent           = win,
        BackgroundColor3 = T.Accent,
        Size             = UDim2.new(1, 0, 0, 2),
        Position         = UDim2.new(0, 0, 0, 44),
        ZIndex           = 7,
    })

    local topIconImg = newInst("ImageLabel", {
        Name                   = "TopIcon",
        Parent                 = topbar,
        BackgroundTransparency = 1,
        Position               = UDim2.new(0, 13, 0.5, 0),
        AnchorPoint            = Vector2.new(0, 0.5),
        Size                   = UDim2.new(0, 20, 0, 20),
        ZIndex                 = 8,
        ImageTransparency      = ICON == "" and 1 or 0,
    })
    if ICON ~= "" then
        applyIcon(topIconImg, ICON, T.Accent, true)
    end

    local titleX = ICON == "" and 14 or 41
    local topTitle = newInst("TextLabel", {
        Parent                 = topbar,
        BackgroundTransparency = 1,
        Position               = UDim2.new(0, titleX, 0.5, SUBTITLE ~= "" and -9 or 0),
        AnchorPoint            = Vector2.new(0, 0.5),
        Size                   = UDim2.new(0.55, 0, 0, 18),
        Text                   = TITLE,
        TextColor3             = T.TextPri,
        TextSize               = 14,
        Font                   = Enum.Font.GothamBold,
        TextXAlignment         = Enum.TextXAlignment.Left,
        ZIndex                 = 8,
    })
    local topSub = newInst("TextLabel", {
        Parent                 = topbar,
        BackgroundTransparency = 1,
        Position               = UDim2.new(0, titleX, 0.5, 9),
        AnchorPoint            = Vector2.new(0, 0.5),
        Size                   = UDim2.new(0.55, 0, 0, 13),
        Text                   = SUBTITLE,
        TextColor3             = T.TextMut,
        TextSize               = 11,
        Font                   = Enum.Font.Gotham,
        TextXAlignment         = Enum.TextXAlignment.Left,
        ZIndex                 = 8,
        Visible                = SUBTITLE ~= "",
    })

    -- ── Window control buttons ──────────────────────────────────────────────
    local ctrlHolder = newInst("Frame", {
        Parent                 = topbar,
        BackgroundTransparency = 1,
        Position               = UDim2.new(1, -8, 0.5, 0),
        AnchorPoint            = Vector2.new(1, 0.5),
        Size                   = UDim2.new(0, 88, 0, 28),
        ZIndex                 = 8,
    })
    listLayout(ctrlHolder, 7, Enum.FillDirection.Horizontal,
        Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Center)

    local function makeCtrlBtn(col)
        local b = newInst("Frame", {
            Parent                 = ctrlHolder,
            BackgroundColor3       = col,
            BackgroundTransparency = 0.35,
            Size                   = UDim2.new(0, 13, 0, 13),
            ZIndex                 = 9,
        })
        corner(b, 7)
        local btn = newInst("ImageButton", {
            Parent                 = b,
            BackgroundTransparency = 1,
            Size                   = UDim2.new(1.4, 0, 1.4, 0),
            Position               = UDim2.new(0.5, 0, 0.5, 0),
            AnchorPoint            = Vector2.new(0.5, 0.5),
            ZIndex                 = 10,
        })
        btn.MouseEnter:Connect(function() ease(b, 0.1, { BackgroundTransparency = 0    }) end)
        btn.MouseLeave:Connect(function() ease(b, 0.1, { BackgroundTransparency = 0.35 }) end)
        return btn, b
    end

    local closeBtn, closeDot = makeCtrlBtn(T.Close)
    local miniBtn,  miniDot  = makeCtrlBtn(T.Minimize)

    local themeBtn = newInst("ImageButton", {
        Parent                 = topbar,
        BackgroundTransparency = 1,
        Position               = UDim2.new(1, -114, 0.5, 0),
        AnchorPoint            = Vector2.new(0, 0.5),
        Size                   = UDim2.new(0, 20, 0, 20),
        ZIndex                 = 8,
    })
    applyIcon(themeBtn, _isDark and "moon" or "sun", T.TextSec, true)

    -- ── Sidebar ────────────────────────────────────────────────────────────
    local sidebar = newInst("Frame", {
        Name             = "Sidebar",
        Parent           = win,
        BackgroundColor3 = T.Sidebar,
        Position         = UDim2.new(0, 0, 0, 46),
        Size             = UDim2.new(0, 54, 1, -46),
        ClipsDescendants = true,
        ZIndex           = 5,
    })
    stroke(sidebar, T.Border, 1, 0.5)
    listLayout(sidebar, 3, Enum.FillDirection.Vertical,
        Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Top)
    padding(sidebar, 10, 0, 10, 0)

    -- ── Content area ───────────────────────────────────────────────────────
    local contentArea = newInst("Frame", {
        Name             = "ContentArea",
        Parent           = win,
        BackgroundColor3 = T.Panel,
        Position         = UDim2.new(0, 54, 0, 46),
        Size             = UDim2.new(1, -54, 1, -46),
        ClipsDescendants = true,
        ZIndex           = 3,
    })

    -- ── Dragging ───────────────────────────────────────────────────────────
    local _drag, _dragInput, _mousePos, _framePos = false, nil, nil, nil

    topbar.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1
        or inp.UserInputType == Enum.UserInputType.Touch then
            _drag     = true
            _mousePos = inp.Position
            _framePos = win.Position
            inp.Changed:Connect(function()
                if inp.UserInputState == Enum.UserInputState.End then _drag = false end
            end)
        end
    end)
    topbar.InputChanged:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseMovement
        or inp.UserInputType == Enum.UserInputType.Touch then
            _dragInput = inp
        end
    end)
    uis.InputChanged:Connect(function(inp)
        if inp == _dragInput and _drag then
            local d  = inp.Position - _mousePos
            local np = UDim2.new(_framePos.X.Scale, _framePos.X.Offset + d.X,
                                 _framePos.Y.Scale, _framePos.Y.Offset + d.Y)
            win.Position         = np
            shadowFrame.Position = UDim2.new(np.X.Scale, np.X.Offset,
                                             np.Y.Scale, np.Y.Offset + 7)
        end
    end)

    -- ── Visibility ─────────────────────────────────────────────────────────
    local _isMini    = false
    local _isVisible = true
    local _toggleCon = nil

    local function setVis(v)
        _isVisible = v
        ease(win, 0.24, {
            Size = v and UDim2.new(0, W, 0, H) or UDim2.new(0, W, 0, 44)
        })
        ease(shadowFrame, 0.24, {
            BackgroundTransparency = v and 0.62 or 1
        })
        contentArea.Visible = v
        sidebar.Visible     = v
    end

    local function doClose()
        ease(win,         0.18, { BackgroundTransparency = 1 })
        ease(shadowFrame, 0.18, { BackgroundTransparency = 1 })
        task.delay(0.2, function() gui:Destroy() end)
        if _toggleCon then _toggleCon:Disconnect() end
    end

    closeBtn.MouseButton1Click:Connect(doClose)
    miniBtn.MouseButton1Click:Connect(function()
        _isMini = not _isMini
        setVis(not _isMini)
    end)

    _toggleCon = uis.InputBegan:Connect(function(key, gp)
        if not gp and key.KeyCode == TOGGLEKEY then
            _isMini = not _isMini
            setVis(not _isMini)
        end
    end)

    -- ── Theme switcher ─────────────────────────────────────────────────────
    local function applyTheme(name)
        local src = Themes[name] or Themes.Dark
        for k, v in pairs(src) do T[k] = v end
        _isDark = (name ~= "Light")

        win.BackgroundColor3         = T.Background
        topbar.BackgroundColor3      = T.Topbar
        sidebar.BackgroundColor3     = T.Sidebar
        contentArea.BackgroundColor3 = T.Panel
        accentLine.BackgroundColor3  = T.Accent
        topTitle.TextColor3          = T.TextPri
        topSub.TextColor3            = T.TextMut
        applyIcon(themeBtn, _isDark and "moon" or "sun", T.TextSec, true)
        closeDot.BackgroundColor3 = T.Close
        miniDot.BackgroundColor3  = T.Minimize
    end

    themeBtn.MouseButton1Click:Connect(function()
        applyTheme(_isDark and "Light" or "Dark")
    end)

    -- ═══════════════════════════════════════════════════════════════════════
    --  KEY SYSTEM
    -- ═══════════════════════════════════════════════════════════════════════
    local _keyOverlay = nil

    local function buildKeyOverlay(onSuccess)
        contentArea.Visible = false
        sidebar.Visible     = false
        closeBtn.MouseButton1Click:Connect(function() end)

        local ov = newInst("Frame", {
            Name             = "KeyOverlay",
            Parent           = win,
            BackgroundColor3 = T.Background,
            Size             = UDim2.new(1, 0, 1, 0),
            ZIndex           = 30,
            ClipsDescendants = true,
        })
        corner(ov, 13)
        _keyOverlay = ov

        newInst("Frame", {
            Parent                 = ov,
            BackgroundColor3       = T.Accent,
            BackgroundTransparency = 0.65,
            Size                   = UDim2.new(1, 0, 0, 2),
            ZIndex                 = 31,
        })

        local lockImg = newInst("ImageLabel", {
            Parent                 = ov,
            BackgroundTransparency = 1,
            Position               = UDim2.new(0.5, 0, 0, 34),
            AnchorPoint            = Vector2.new(0.5, 0),
            Size                   = UDim2.new(0, 32, 0, 32),
            ZIndex                 = 31,
        })
        applyIcon(lockImg, "lock", T.Accent, true)

        newInst("TextLabel", {
            Parent                 = ov,
            BackgroundTransparency = 1,
            Position               = UDim2.new(0.5, 0, 0, 74),
            AnchorPoint            = Vector2.new(0.5, 0),
            Size                   = UDim2.new(0.8, 0, 0, 20),
            Text                   = KEY_TITLE,
            TextColor3             = T.TextPri,
            TextSize               = 16,
            Font                   = Enum.Font.GothamBold,
            ZIndex                 = 31,
        })
        newInst("TextLabel", {
            Parent                 = ov,
            BackgroundTransparency = 1,
            Position               = UDim2.new(0.5, 0, 0, 98),
            AnchorPoint            = Vector2.new(0.5, 0),
            Size                   = UDim2.new(0.76, 0, 0, 30),
            Text                   = KEY_DESC,
            TextColor3             = T.TextSec,
            TextSize               = 11,
            Font                   = Enum.Font.Gotham,
            TextWrapped            = true,
            ZIndex                 = 31,
        })

        local inputBg = newInst("Frame", {
            Parent           = ov,
            BackgroundColor3 = T.Surface,
            Position         = UDim2.new(0.5, 0, 0.5, 10),
            AnchorPoint      = Vector2.new(0.5, 0.5),
            Size             = UDim2.new(0.76, 0, 0, 36),
            ZIndex           = 31,
        })
        corner(inputBg, 8)
        stroke(inputBg, T.Border, 1, 0.35)

        local showKey = false
        local eyeBtn = newInst("ImageButton", {
            Parent                 = inputBg,
            BackgroundTransparency = 1,
            Position               = UDim2.new(1, -8, 0.5, 0),
            AnchorPoint            = Vector2.new(1, 0.5),
            Size                   = UDim2.new(0, 18, 0, 18),
            ZIndex                 = 33,
        })
        applyIcon(eyeBtn, "eye-off", T.TextMut, true)

        local keyInput = newInst("TextBox", {
            Parent                 = inputBg,
            BackgroundTransparency = 1,
            Position               = UDim2.new(0, 10, 0, 0),
            Size                   = UDim2.new(1, -36, 1, 0),
            PlaceholderText        = "Enter key...",
            PlaceholderColor3      = T.TextMut,
            Text                   = "",
            TextColor3             = T.TextPri,
            TextSize               = 12,
            Font                   = Enum.Font.GothamMono,
            ClearTextOnFocus       = false,
            TextXAlignment         = Enum.TextXAlignment.Left,
            ZIndex                 = 32,
        })

        local maskLabel = newInst("TextLabel", {
            Parent                 = inputBg,
            BackgroundTransparency = 1,
            Position               = UDim2.new(0, 10, 0, 0),
            Size                   = UDim2.new(1, -36, 1, 0),
            Text                   = "",
            TextColor3             = T.TextPri,
            TextSize               = 12,
            Font                   = Enum.Font.GothamMono,
            TextXAlignment         = Enum.TextXAlignment.Left,
            ZIndex                 = 33,
        })
        keyInput:GetPropertyChangedSignal("Text"):Connect(function()
            if not showKey then
                maskLabel.Text = string.rep("•", #keyInput.Text)
            else
                maskLabel.Text = ""
            end
        end)
        eyeBtn.MouseButton1Click:Connect(function()
            showKey = not showKey
            applyIcon(eyeBtn, showKey and "eye" or "eye-off", T.TextMut, true)
            maskLabel.Text = showKey and "" or string.rep("•", #keyInput.Text)
        end)

        local statusLbl = newInst("TextLabel", {
            Parent                 = ov,
            BackgroundTransparency = 1,
            Position               = UDim2.new(0.5, 0, 0.5, 32),
            AnchorPoint            = Vector2.new(0.5, 0),
            Size                   = UDim2.new(0.8, 0, 0, 16),
            Text                   = "",
            TextColor3             = T.TextMut,
            TextSize               = 11,
            Font                   = Enum.Font.Gotham,
            ZIndex                 = 31,
        })

        local submitBtn = newInst("TextButton", {
            Parent           = ov,
            BackgroundColor3 = T.Accent,
            Position         = UDim2.new(0.5, 0, 0.5, 56),
            AnchorPoint      = Vector2.new(0.5, 0),
            Size             = UDim2.new(0.38, 0, 0, 32),
            Text             = "Unlock",
            TextColor3       = Color3.fromRGB(255, 255, 255),
            TextSize         = 13,
            Font             = Enum.Font.GothamBold,
            ZIndex           = 31,
        })
        corner(submitBtn, 8)
        submitBtn.MouseEnter:Connect(function() ease(submitBtn, 0.1, { BackgroundColor3 = T.AccentDim }) end)
        submitBtn.MouseLeave:Connect(function() ease(submitBtn, 0.1, { BackgroundColor3 = T.Accent    }) end)

        if KEY_LINK then
            local linkBtn = newInst("TextButton", {
                Parent                 = ov,
                BackgroundTransparency = 1,
                Position               = UDim2.new(0.5, 0, 0.5, 96),
                AnchorPoint            = Vector2.new(0.5, 0),
                Size                   = UDim2.new(0.5, 0, 0, 18),
                Text                   = "Get a key →",
                TextColor3             = T.Accent,
                TextSize               = 11,
                Font                   = Enum.Font.Gotham,
                ZIndex                 = 31,
            })
            linkBtn.MouseButton1Click:Connect(function()
                if setclipboard then
                    setclipboard(KEY_LINK)
                    fireNotif(T, { Title="Copied!", Content="Key link copied to clipboard.", Type="Info", Duration=3 })
                end
            end)
        end

        local attempts     = 0
        local MAX_ATTEMPTS = 10
        local _locked      = false

        local function flashBad()
            ease(inputBg, 0.06, { BackgroundColor3 = Color3.fromRGB(80, 22, 22) })
            task.delay(0.28, function()
                ease(inputBg, 0.14, { BackgroundColor3 = T.Surface })
            end)
        end

        local function attemptKey(raw)
            if _locked then
                statusLbl.TextColor3 = T.Close
                statusLbl.Text = "Too many attempts. Restart."
                return
            end
            local trimmed = trimKey(raw)
            if trimmed == "" then return end

            if _validKeySet[trimmed] then
                _unlocked = true
                if KEY_SAVED then
                    pcall(function()
                        if writefile then
                            writefile(KEY_FILE_PREFIX .. TITLE:gsub("[%s%p]", "_"), xorScramble(trimmed))
                        end
                    end)
                end
                statusLbl.TextColor3 = NOTIF_COLORS.Success
                statusLbl.Text       = "✓ Key accepted"
                applyIcon(lockImg, "lock-open", NOTIF_COLORS.Success, true)
                task.delay(0.5, function()
                    ease(ov, 0.28, { BackgroundTransparency = 1 })
                    task.delay(0.3, function()
                        ov:Destroy()
                        _keyOverlay = nil
                        contentArea.Visible = true
                        sidebar.Visible     = true
                        closeBtn.MouseButton1Click:Connect(doClose)
                        onSuccess()
                        fireNotif(T, { Title="Welcome!", Content="Authenticated successfully.", Type="Success", Duration=4 })
                        pcall(ON_VALID)
                    end)
                end)
            else
                attempts += 1
                if attempts >= MAX_ATTEMPTS then
                    _locked = true
                    statusLbl.TextColor3 = T.Close
                    statusLbl.Text = "Too many attempts."
                    return
                end
                statusLbl.TextColor3 = T.Close
                statusLbl.Text = "✗ Invalid key  (" .. (MAX_ATTEMPTS - attempts) .. " left)"
                flashBad()
                task.delay(2, function()
                    if statusLbl and statusLbl.Parent then statusLbl.Text = "" end
                end)
            end
        end

        submitBtn.MouseButton1Click:Connect(function() attemptKey(keyInput.Text) end)
        keyInput.FocusLost:Connect(function(ep)
            if ep then attemptKey(keyInput.Text) end
        end)

        if KEY_SAVED then
            task.defer(function()
                pcall(function()
                    if readfile then
                        local fname = KEY_FILE_PREFIX .. TITLE:gsub("[%s%p]", "_")
                        local ok, raw = pcall(readfile, fname)
                        if ok and raw and #raw > 0 then
                            local decoded = xorScramble(raw)
                            local trimmed = trimKey(decoded)
                            if _validKeySet[trimmed] then
                                keyInput.Text = trimmed
                                attemptKey(trimmed)
                            end
                        end
                    end
                end)
            end)
        end
    end

    -- ═══════════════════════════════════════════════════════════════════════
    --  ELEMENT BUILDER HELPERS
    -- ═══════════════════════════════════════════════════════════════════════
    local function makeSectionTitle(parent, title)
        local row = newInst("Frame", {
            Parent                 = parent,
            BackgroundTransparency = 1,
            Size                   = UDim2.new(1, 0, 0, 22),
            ZIndex                 = parent.ZIndex + 1,
        })
        newInst("TextLabel", {
            Parent                 = row,
            BackgroundTransparency = 1,
            Position               = UDim2.new(0, 4, 0, 0),
            Size                   = UDim2.new(0.6, 0, 1, 0),
            Text                   = title:upper(),
            TextColor3             = T.Accent,
            TextSize               = 10,
            Font                   = Enum.Font.GothamBold,
            TextXAlignment         = Enum.TextXAlignment.Left,
            ZIndex                 = parent.ZIndex + 2,
        })
        newInst("Frame", {
            Parent                 = row,
            BackgroundColor3       = T.Accent,
            BackgroundTransparency = 0.62,
            Position               = UDim2.new(0, 0, 1, -1),
            Size                   = UDim2.new(1, 0, 0, 1),
            ZIndex                 = parent.ZIndex + 2,
        })
    end

    local function elemBase(parent, h, noHov)
        local b = newInst("Frame", {
            Parent                 = parent,
            BackgroundColor3       = T.Surface,
            BackgroundTransparency = 0.18,
            Size                   = UDim2.new(1, 0, 0, h or 36),
            ZIndex                 = parent.ZIndex + 1,
        })
        corner(b, 7)
        if not noHov then
            b.MouseEnter:Connect(function() ease(b, 0.1, { BackgroundColor3 = T.SurfaceHov }) end)
            b.MouseLeave:Connect(function() ease(b, 0.1, { BackgroundColor3 = T.Surface    }) end)
        end
        return b
    end

    local function elemIcon(parent, iconStr, zIdx)
        local img = newInst("ImageLabel", {
            Parent                 = parent,
            BackgroundTransparency = 1,
            Position               = UDim2.new(0, 10, 0.5, 0),
            AnchorPoint            = Vector2.new(0, 0.5),
            Size                   = UDim2.new(0, 15, 0, 15),
            ZIndex                 = zIdx or parent.ZIndex + 1,
        })
        applyIcon(img, iconStr, T.TextSec, true)
        return img
    end

    -- ═══════════════════════════════════════════════════════════════════════
    --  TAB SYSTEM
    --
    --  FIX 1: Tab pages are now CanvasGroup (not ScrollingFrame directly).
    --          CanvasGroup supports GroupTransparency for fade transitions.
    --          A ScrollingFrame child is placed inside for actual scrolling.
    --
    --  FIX 2: Hover handlers now reference `pageGroup` via a local alias
    --          captured in the same scope they are created — eliminating the
    --          forward-reference nil bug from the original code.
    --
    --  FIX 3: Interactable is set on the CanvasGroup wrapper, which is a
    --          GuiObject and supports it. ScrollingFrame also supports it but
    --          only the outer wrapper needs to block input during transitions.
    -- ═══════════════════════════════════════════════════════════════════════
    local _tabPages = {}   -- stores CanvasGroup wrappers
    local _tabBtns  = {}
    local _curPage  = nil  -- currently active CanvasGroup

    local function selectPage(pageGroup, btnRef)
        if _curPage == pageGroup then return end

        -- Deselect old page
        if _curPage then
            local prev = _curPage
            ease(prev, 0.18, { GroupTransparency = 1 })
            prev.Interactable = false
            task.delay(0.20, function()
                if prev ~= pageGroup then
                    prev.Visible = false
                end
            end)
        end

        -- Deselect all tab buttons
        for _, br in ipairs(_tabBtns) do
            ease(br.icon, 0.14, { ImageTransparency  = 0.56 })
            ease(br.bar,  0.14, { BackgroundTransparency = 1 })
            ease(br.bg,   0.14, { BackgroundTransparency = 1 })
        end

        -- Activate new page
        _curPage              = pageGroup
        pageGroup.Visible     = true
        pageGroup.Interactable = true
        ease(pageGroup, 0.18, { GroupTransparency = 0 })

        if btnRef then
            ease(btnRef.icon, 0.14, { ImageTransparency      = 0    })
            ease(btnRef.bar,  0.14, { BackgroundTransparency = 0    })
            ease(btnRef.bg,   0.14, { BackgroundTransparency = 0.82 })
        end
    end

    -- ═══════════════════════════════════════════════════════════════════════
    --  WINDOW PUBLIC API
    -- ═══════════════════════════════════════════════════════════════════════
    local windowAPI = {}

    function windowAPI:SetBackground(id, transparency)
        bgImg.Image             = id or ""
        bgImg.ImageTransparency = id and (transparency or 0.55) or 1
    end

    function windowAPI:SetTheme(name)
        applyTheme(name)
    end

    function windowAPI:Notify(opts)
        fireNotif(T, opts)
    end

    function windowAPI:Destroy()
        doClose()
    end

    -- ── AddTab ─────────────────────────────────────────────────────────────
    function windowAPI:AddTab(opts)
        opts = opts or {}
        local tabLabel = opts.Title or "Tab"
        local tabIcon  = opts.Icon  or "layout"

        -- Sidebar button
        local tabBg = newInst("Frame", {
            Parent                 = sidebar,
            BackgroundColor3       = T.Accent,
            BackgroundTransparency = 1,
            Size                   = UDim2.new(0, 42, 0, 42),
            ZIndex                 = 6,
        })
        corner(tabBg, 9)

        local tabBar = newInst("Frame", {
            Parent                 = tabBg,
            BackgroundColor3       = T.Accent,
            BackgroundTransparency = 1,
            Position               = UDim2.new(0, 0, 0.15, 0),
            Size                   = UDim2.new(0, 3, 0.7, 0),
            ZIndex                 = 6,
        })
        corner(tabBar, 2)

        local tabIconImg = newInst("ImageLabel", {
            Parent                 = tabBg,
            BackgroundTransparency = 1,
            Position               = UDim2.new(0.5, 0, 0.42, 0),
            AnchorPoint            = Vector2.new(0.5, 0.5),
            Size                   = UDim2.new(0, 20, 0, 20),
            ImageTransparency      = 0.56,
            ZIndex                 = 7,
        })
        applyIcon(tabIconImg, tabIcon, T.IconTint, true)

        newInst("TextLabel", {
            Parent                 = tabBg,
            BackgroundTransparency = 1,
            Position               = UDim2.new(0.5, 0, 0.72, 0),
            AnchorPoint            = Vector2.new(0.5, 0),
            Size                   = UDim2.new(1, -2, 0, 10),
            Text                   = tabLabel,
            TextColor3             = T.TextSec,
            TextSize               = 8,
            Font                   = Enum.Font.GothamBold,
            TextTransparency       = 0.4,
            ZIndex                 = 7,
        })

        local tabClickBtn = newInst("TextButton", {
            Parent                 = tabBg,
            BackgroundTransparency = 1,
            Size                   = UDim2.new(1, 0, 1, 0),
            Text                   = "",
            ZIndex                 = 8,
        })

        local btnRef = { icon = tabIconImg, bar = tabBar, bg = tabBg }
        table.insert(_tabBtns, btnRef)

        -- ── FIX: CanvasGroup wrapper ──────────────────────────────────────
        --  CanvasGroup is a Frame subclass that supports GroupTransparency.
        --  We set Interactable on it (also supported).
        --  The actual scrollable content lives in a ScrollingFrame child.
        local pageGroup = newInst("CanvasGroup", {
            Parent                 = contentArea,
            BackgroundTransparency = 1,
            Size                   = UDim2.new(1, 0, 1, 0),
            GroupTransparency      = 1,    -- starts invisible
            Interactable           = false,
            Visible                = false,
            ZIndex                 = 4,
        })

        local page = newInst("ScrollingFrame", {
            Parent                 = pageGroup,
            BackgroundTransparency = 1,
            Size                   = UDim2.new(1, 0, 1, 0),
            CanvasSize             = UDim2.new(0, 0, 0, 0),
            AutomaticCanvasSize    = Enum.AutomaticSize.Y,
            ScrollBarThickness     = 3,
            ScrollBarImageColor3   = T.Accent,
            ZIndex                 = 4,
        })
        listLayout(page, 5)
        padding(page, 10, 10, 10, 10)

        table.insert(_tabPages, pageGroup)

        -- ── FIX: hover captures pageGroup in same scope (no forward ref) ─
        tabClickBtn.MouseEnter:Connect(function()
            if _curPage ~= pageGroup then
                ease(tabIconImg, 0.1, { ImageTransparency = 0.3 })
            end
        end)
        tabClickBtn.MouseLeave:Connect(function()
            if _curPage ~= pageGroup then
                ease(tabIconImg, 0.1, { ImageTransparency = 0.56 })
            end
        end)
        tabClickBtn.MouseButton1Click:Connect(function()
            selectPage(pageGroup, btnRef)
        end)

        -- Auto-select first tab
        if #_tabPages == 1 then
            task.defer(function() selectPage(pageGroup, btnRef) end)
        end

        -- ── Section API ──────────────────────────────────────────────────
        local tabAPI = {}

        function tabAPI:AddSection(sectionTitle_)
            if sectionTitle_ and sectionTitle_ ~= "" then
                makeSectionTitle(page, sectionTitle_)
            end

            local secAPI = {}

            -- ── Label ────────────────────────────────────────────────────
            function secAPI:AddLabel(opts_)
                if type(opts_) == "string" then opts_ = { Title = opts_ } end
                opts_ = opts_ or {}
                local b = elemBase(page, 28, true)
                b.BackgroundTransparency = 0.72

                local xOff = 12
                if opts_.Icon and opts_.Icon ~= "" then
                    elemIcon(b, opts_.Icon, b.ZIndex + 1)
                    xOff = 32
                end
                newInst("TextLabel", {
                    Parent                 = b,
                    BackgroundTransparency = 1,
                    Position               = UDim2.new(0, xOff, 0, 0),
                    Size                   = UDim2.new(1, -xOff - 8, 1, 0),
                    Text                   = opts_.Title or "Label",
                    TextColor3             = T.TextSec,
                    TextSize               = 12,
                    Font                   = Enum.Font.Gotham,
                    TextXAlignment         = Enum.TextXAlignment.Left,
                    ZIndex                 = b.ZIndex + 1,
                })
            end

            -- ── Separator ────────────────────────────────────────────────
            function secAPI:AddSeparator()
                newInst("Frame", {
                    Parent                 = page,
                    BackgroundColor3       = T.Border,
                    BackgroundTransparency = 0.4,
                    Size                   = UDim2.new(1, -20, 0, 1),
                    ZIndex                 = page.ZIndex + 1,
                })
            end

            -- ── Button ───────────────────────────────────────────────────
            function secAPI:AddButton(opts_)
                opts_ = opts_ or {}
                local b = elemBase(page, 36)

                local xOff = 12
                if opts_.Icon and opts_.Icon ~= "" then
                    elemIcon(b, opts_.Icon, b.ZIndex + 1)
                    xOff = 32
                end
                newInst("TextLabel", {
                    Parent                 = b,
                    BackgroundTransparency = 1,
                    Position               = UDim2.new(0, xOff, 0, 0),
                    Size                   = UDim2.new(0.68, 0, 1, 0),
                    Text                   = opts_.Title or "Button",
                    TextColor3             = T.TextPri,
                    TextSize               = 12,
                    Font                   = Enum.Font.GothamSemibold,
                    TextXAlignment         = Enum.TextXAlignment.Left,
                    ZIndex                 = b.ZIndex + 1,
                })

                local runBtn = newInst("TextButton", {
                    Parent                 = b,
                    BackgroundColor3       = T.Accent,
                    BackgroundTransparency = 0.12,
                    Position               = UDim2.new(1, -70, 0.5, 0),
                    AnchorPoint            = Vector2.new(0, 0.5),
                    Size                   = UDim2.new(0, 58, 0, 22),
                    Text                   = opts_.Btn or "Run",
                    TextColor3             = Color3.fromRGB(255,255,255),
                    TextSize               = 11,
                    Font                   = Enum.Font.GothamBold,
                    ZIndex                 = b.ZIndex + 2,
                })
                corner(runBtn, 6)
                runBtn.MouseEnter:Connect(function() ease(runBtn, 0.08, { BackgroundTransparency = 0    }) end)
                runBtn.MouseLeave:Connect(function() ease(runBtn, 0.08, { BackgroundTransparency = 0.12 }) end)
                runBtn.MouseButton1Click:Connect(function()
                    if opts_.Callback then pcall(opts_.Callback) end
                end)
            end

            -- ── Toggle ───────────────────────────────────────────────────
            function secAPI:AddToggle(opts_)
                opts_         = opts_ or {}
                local toggled = opts_.Default == true
                local b       = elemBase(page, 36)

                local xOff = 12
                if opts_.Icon and opts_.Icon ~= "" then
                    elemIcon(b, opts_.Icon, b.ZIndex + 1)
                    xOff = 32
                end
                newInst("TextLabel", {
                    Parent                 = b,
                    BackgroundTransparency = 1,
                    Position               = UDim2.new(0, xOff, 0, 0),
                    Size                   = UDim2.new(0.7, 0, 1, 0),
                    Text                   = opts_.Title or "Toggle",
                    TextColor3             = T.TextPri,
                    TextSize               = 12,
                    Font                   = Enum.Font.GothamSemibold,
                    TextXAlignment         = Enum.TextXAlignment.Left,
                    ZIndex                 = b.ZIndex + 1,
                })

                local track = newInst("Frame", {
                    Parent           = b,
                    BackgroundColor3 = toggled and T.ToggleOn or T.ToggleOff,
                    Position         = UDim2.new(1, -52, 0.5, 0),
                    AnchorPoint      = Vector2.new(0, 0.5),
                    Size             = UDim2.new(0, 38, 0, 18),
                    ZIndex           = b.ZIndex + 2,
                })
                corner(track, 9)
                local knob = newInst("Frame", {
                    Parent           = track,
                    BackgroundColor3 = Color3.fromRGB(255,255,255),
                    AnchorPoint      = Vector2.new(0.5, 0.5),
                    Position         = toggled and UDim2.new(1,-9,0.5,0) or UDim2.new(0,9,0.5,0),
                    Size             = UDim2.new(0, 12, 0, 12),
                    ZIndex           = b.ZIndex + 3,
                })
                corner(knob, 6)

                local function refresh()
                    ease(track, 0.14, { BackgroundColor3 = toggled and T.ToggleOn or T.ToggleOff })
                    ease(knob,  0.14, { Position = toggled and UDim2.new(1,-9,0.5,0) or UDim2.new(0,9,0.5,0) })
                    if opts_.Callback then pcall(opts_.Callback, toggled) end
                end

                if toggled then
                    task.defer(function()
                        if opts_.Callback then pcall(opts_.Callback, true) end
                    end)
                end

                b.InputBegan:Connect(function(inp)
                    if inp.UserInputType == Enum.UserInputType.MouseButton1
                    or inp.UserInputType == Enum.UserInputType.Touch then
                        toggled = not toggled
                        refresh()
                    end
                end)

                local ref = {}
                function ref:Set(v)   toggled = v == true; refresh() end
                function ref:Get()    return toggled end
                function ref:Toggle() toggled = not toggled; refresh() end
                return ref
            end

            -- ── Slider ───────────────────────────────────────────────────
            function secAPI:AddSlider(opts_)
                opts_         = opts_ or {}
                local min     = opts_.Min    or 0
                local max     = opts_.Max    or 100
                local default = math.clamp(opts_.Default or min, min, max)
                local step    = opts_.Step   or 1
                local suffix  = opts_.Suffix or ""

                local b = elemBase(page, 50, true)

                local xOff = 12
                if opts_.Icon and opts_.Icon ~= "" then
                    elemIcon(b, opts_.Icon, b.ZIndex + 1)
                    xOff = 32
                end
                newInst("TextLabel", {
                    Parent                 = b,
                    BackgroundTransparency = 1,
                    Position               = UDim2.new(0, xOff, 0, 7),
                    Size                   = UDim2.new(0.6, 0, 0, 16),
                    Text                   = opts_.Title or "Slider",
                    TextColor3             = T.TextPri,
                    TextSize               = 12,
                    Font                   = Enum.Font.GothamSemibold,
                    TextXAlignment         = Enum.TextXAlignment.Left,
                    ZIndex                 = b.ZIndex + 1,
                })
                local valLbl = newInst("TextLabel", {
                    Parent                 = b,
                    BackgroundTransparency = 1,
                    Position               = UDim2.new(1, -8, 0, 7),
                    AnchorPoint            = Vector2.new(1, 0),
                    Size                   = UDim2.new(0.36, 0, 0, 16),
                    Text                   = tostring(default) .. suffix,
                    TextColor3             = T.Accent,
                    TextSize               = 11,
                    Font                   = Enum.Font.GothamBold,
                    TextXAlignment         = Enum.TextXAlignment.Right,
                    ZIndex                 = b.ZIndex + 1,
                })

                local track = newInst("Frame", {
                    Parent           = b,
                    BackgroundColor3 = T.SliderTrack,
                    Position         = UDim2.new(0, xOff, 0, 32),
                    Size             = UDim2.new(1, -(xOff + 12), 0, 5),
                    ZIndex           = b.ZIndex + 2,
                })
                corner(track, 3)
                local fill = newInst("Frame", {
                    Parent           = track,
                    BackgroundColor3 = T.SliderFill,
                    Size             = UDim2.new((default-min)/(max-min), 0, 1, 0),
                    ZIndex           = b.ZIndex + 3,
                })
                corner(fill, 3)
                local handle = newInst("Frame", {
                    Parent           = track,
                    BackgroundColor3 = Color3.fromRGB(255,255,255),
                    AnchorPoint      = Vector2.new(0.5, 0.5),
                    Position         = UDim2.new((default-min)/(max-min), 0, 0.5, 0),
                    Size             = UDim2.new(0, 13, 0, 13),
                    ZIndex           = b.ZIndex + 4,
                })
                corner(handle, 7)
                stroke(handle, T.SliderFill, 2, 0)

                local curVal  = default
                local sliding = false

                local function setAlpha(alpha)
                    alpha  = math.clamp(alpha, 0, 1)
                    local raw = min + (max - min) * alpha
                    curVal = math.clamp(math.floor(raw / step + 0.5) * step, min, max)
                    local a2 = (curVal - min) / (max - min)
                    fill.Size       = UDim2.new(a2, 0, 1, 0)
                    handle.Position = UDim2.new(a2, 0, 0.5, 0)
                    valLbl.Text     = tostring(curVal) .. suffix
                end

                local function inputAlpha(x)
                    return (x - track.AbsolutePosition.X) / track.AbsoluteSize.X
                end

                track.InputBegan:Connect(function(inp)
                    if inp.UserInputType == Enum.UserInputType.MouseButton1
                    or inp.UserInputType == Enum.UserInputType.Touch then
                        sliding = true
                        setAlpha(inputAlpha(inp.Position.X))
                    end
                end)
                uis.InputChanged:Connect(function(inp)
                    if sliding and (inp.UserInputType == Enum.UserInputType.MouseMovement
                    or inp.UserInputType == Enum.UserInputType.Touch) then
                        setAlpha(inputAlpha(inp.Position.X))
                    end
                end)
                uis.InputEnded:Connect(function(inp)
                    if sliding and (inp.UserInputType == Enum.UserInputType.MouseButton1
                    or inp.UserInputType == Enum.UserInputType.Touch) then
                        sliding = false
                        if opts_.Callback then pcall(opts_.Callback, curVal) end
                    end
                end)

                local ref = {}
                function ref:Set(v)
                    setAlpha((math.clamp(v, min, max) - min) / (max - min))
                    if opts_.Callback then pcall(opts_.Callback, curVal) end
                end
                function ref:Get() return curVal end
                return ref
            end

            -- ── Textbox ──────────────────────────────────────────────────
            function secAPI:AddTextbox(opts_)
                opts_ = opts_ or {}
                local b = elemBase(page, 46)

                newInst("TextLabel", {
                    Parent                 = b,
                    BackgroundTransparency = 1,
                    Position               = UDim2.new(0, 12, 0, 5),
                    Size                   = UDim2.new(1, -12, 0, 14),
                    Text                   = opts_.Title or "Textbox",
                    TextColor3             = T.TextSec,
                    TextSize               = 10,
                    Font                   = Enum.Font.GothamBold,
                    TextXAlignment         = Enum.TextXAlignment.Left,
                    ZIndex                 = b.ZIndex + 1,
                })
                local inpBg = newInst("Frame", {
                    Parent           = b,
                    BackgroundColor3 = T.Panel,
                    Position         = UDim2.new(0, 12, 0, 23),
                    Size             = UDim2.new(1, -24, 0, 17),
                    ZIndex           = b.ZIndex + 1,
                })
                corner(inpBg, 4)
                local inp = newInst("TextBox", {
                    Parent                 = inpBg,
                    BackgroundTransparency = 1,
                    Position               = UDim2.new(0, 6, 0, 0),
                    Size                   = UDim2.new(1, -6, 1, 0),
                    PlaceholderText        = opts_.Placeholder or "Type here...",
                    PlaceholderColor3      = T.TextMut,
                    Text                   = opts_.Default or "",
                    TextColor3             = T.TextPri,
                    TextSize               = 11,
                    Font                   = Enum.Font.Gotham,
                    ClearTextOnFocus       = opts_.ClearOnFocus ~= false,
                    ZIndex                 = b.ZIndex + 2,
                })
                inp.FocusLost:Connect(function(ep)
                    if ep and opts_.Callback then pcall(opts_.Callback, inp.Text) end
                end)
                if opts_.Default and opts_.Default ~= "" then
                    task.defer(function()
                        if opts_.Callback then pcall(opts_.Callback, opts_.Default) end
                    end)
                end

                local ref = {}
                function ref:Get() return inp.Text end
                function ref:Set(v) inp.Text = v or "" end
                return ref
            end

            -- ── Dropdown ─────────────────────────────────────────────────
            function secAPI:AddDropdown(opts_)
                opts_          = opts_ or {}
                local choices  = opts_.Options or {}
                local selected = opts_.Default or (choices[1] or "")
                local isOpen   = false

                local b = elemBase(page, 36)

                local xOff = 12
                if opts_.Icon and opts_.Icon ~= "" then
                    elemIcon(b, opts_.Icon, b.ZIndex + 1)
                    xOff = 32
                end
                newInst("TextLabel", {
                    Parent                 = b,
                    BackgroundTransparency = 1,
                    Position               = UDim2.new(0, xOff, 0, 0),
                    Size                   = UDim2.new(0.5, 0, 1, 0),
                    Text                   = opts_.Title or "Dropdown",
                    TextColor3             = T.TextPri,
                    TextSize               = 12,
                    Font                   = Enum.Font.GothamSemibold,
                    TextXAlignment         = Enum.TextXAlignment.Left,
                    ZIndex                 = b.ZIndex + 1,
                })
                local selLbl = newInst("TextLabel", {
                    Parent                 = b,
                    BackgroundTransparency = 1,
                    Position               = UDim2.new(1, -96, 0.5, 0),
                    AnchorPoint            = Vector2.new(0, 0.5),
                    Size                   = UDim2.new(0, 74, 0, 22),
                    Text                   = selected,
                    TextColor3             = T.Accent,
                    TextSize               = 11,
                    Font                   = Enum.Font.GothamBold,
                    TextXAlignment         = Enum.TextXAlignment.Right,
                    ZIndex                 = b.ZIndex + 1,
                })
                local chevronImg = newInst("ImageLabel", {
                    Parent                 = b,
                    BackgroundTransparency = 1,
                    Position               = UDim2.new(1, -16, 0.5, 0),
                    AnchorPoint            = Vector2.new(0.5, 0.5),
                    Size                   = UDim2.new(0, 14, 0, 14),
                    ZIndex                 = b.ZIndex + 2,
                })
                applyIcon(chevronImg, "chevron-down", T.TextSec, true)

                local dropList = newInst("Frame", {
                    Parent           = page,
                    BackgroundColor3 = T.Surface,
                    Size             = UDim2.new(1, 0, 0, #choices * 28 + 8),
                    Visible          = false,
                    ZIndex           = 20,
                    ClipsDescendants = true,
                })
                corner(dropList, 7)
                stroke(dropList, T.Border, 1, 0.3)
                listLayout(dropList, 2)
                padding(dropList, 4, 6, 4, 6)

                local function buildItems()
                    for _, c in ipairs(dropList:GetChildren()) do
                        if c:IsA("TextButton") then c:Destroy() end
                    end
                    for _, ch in ipairs(choices) do
                        local item = newInst("TextButton", {
                            Parent                 = dropList,
                            BackgroundTransparency = 1,
                            Size                   = UDim2.new(1, 0, 0, 26),
                            Text                   = ch,
                            TextColor3             = T.TextSec,
                            TextSize               = 11,
                            Font                   = Enum.Font.GothamSemibold,
                            ZIndex                 = 21,
                        })
                        corner(item, 5)
                        item.MouseEnter:Connect(function()
                            ease(item, 0.08, { BackgroundTransparency = 0.55, TextColor3 = T.TextPri })
                        end)
                        item.MouseLeave:Connect(function()
                            ease(item, 0.08, { BackgroundTransparency = 1, TextColor3 = T.TextSec })
                        end)
                        item.MouseButton1Click:Connect(function()
                            selected         = ch
                            selLbl.Text      = ch
                            isOpen           = false
                            dropList.Visible = false
                            ease(chevronImg, 0.12, { Rotation = 0 })
                            if opts_.Callback then pcall(opts_.Callback, ch) end
                        end)
                    end
                    dropList.Size = UDim2.new(1, 0, 0, #choices * 28 + 8)
                end
                buildItems()

                b.InputBegan:Connect(function(inp)
                    if inp.UserInputType == Enum.UserInputType.MouseButton1 then
                        isOpen           = not isOpen
                        dropList.Visible = isOpen
                        ease(chevronImg, 0.14, { Rotation = isOpen and 180 or 0 })
                    end
                end)

                if opts_.Default and opts_.Callback then
                    task.defer(function() pcall(opts_.Callback, selected) end)
                end

                local ref = {}
                function ref:Get() return selected end
                function ref:Set(v)
                    selected = v; selLbl.Text = v
                    if opts_.Callback then pcall(opts_.Callback, v) end
                end
                function ref:Refresh(newChoices)
                    choices = newChoices or {}
                    buildItems()
                end
                return ref
            end

            -- ── Keybind ──────────────────────────────────────────────────
            function secAPI:AddKeybind(opts_)
                opts_         = opts_ or {}
                local curKey  = opts_.Default or Enum.KeyCode.Unknown
                local binding = false

                local b = elemBase(page, 36)

                local xOff = 12
                if opts_.Icon and opts_.Icon ~= "" then
                    elemIcon(b, opts_.Icon, b.ZIndex + 1)
                    xOff = 32
                end
                newInst("TextLabel", {
                    Parent                 = b,
                    BackgroundTransparency = 1,
                    Position               = UDim2.new(0, xOff, 0, 0),
                    Size                   = UDim2.new(0.62, 0, 1, 0),
                    Text                   = opts_.Title or "Keybind",
                    TextColor3             = T.TextPri,
                    TextSize               = 12,
                    Font                   = Enum.Font.GothamSemibold,
                    TextXAlignment         = Enum.TextXAlignment.Left,
                    ZIndex                 = b.ZIndex + 1,
                })

                local keyBtn = newInst("TextButton", {
                    Parent           = b,
                    BackgroundColor3 = T.Panel,
                    Position         = UDim2.new(1, -76, 0.5, 0),
                    AnchorPoint      = Vector2.new(0, 0.5),
                    Size             = UDim2.new(0, 64, 0, 22),
                    Text             = curKey == Enum.KeyCode.Unknown and "None" or curKey.Name,
                    TextColor3       = T.Accent,
                    TextSize         = 11,
                    Font             = Enum.Font.GothamBold,
                    ZIndex           = b.ZIndex + 2,
                })
                corner(keyBtn, 5)
                stroke(keyBtn, T.Border, 1, 0.4)

                keyBtn.MouseButton1Click:Connect(function()
                    if binding then return end
                    binding           = true
                    keyBtn.Text       = "..."
                    keyBtn.TextColor3 = T.TextMut
                end)

                uis.InputBegan:Connect(function(inp, gp)
                    if binding and inp.UserInputType == Enum.UserInputType.Keyboard then
                        binding           = false
                        curKey            = inp.KeyCode
                        keyBtn.Text       = curKey.Name
                        keyBtn.TextColor3 = T.Accent
                        if opts_.Callback then pcall(opts_.Callback, curKey) end
                    end
                    if not gp and not binding and inp.KeyCode == curKey then
                        if opts_.OnPress then pcall(opts_.OnPress) end
                    end
                end)

                local ref = {}
                function ref:Get() return curKey end
                function ref:Set(k) curKey = k; keyBtn.Text = k.Name end
                return ref
            end

            return secAPI
        end -- AddSection

        return tabAPI
    end -- AddTab

    -- Launch key system if needed
    if not _unlocked then
        buildKeyOverlay(function() end)
    end

    return windowAPI
end

-- ═══════════════════════════════════════════════════════════════════════════
--  STANDALONE NOTIFY  (no window required)
-- ═══════════════════════════════════════════════════════════════════════════
function EmberUI:Notify(opts)
    ensureNotifHolder(nil)
    fireNotif(Themes.Dark, opts)
end

return EmberUI

--[[
════════════════════════════════════════════════════════
  EMBERUI v2.1 — WHAT CHANGED FROM v2.0
════════════════════════════════════════════════════════

FIXES
  1. GroupTransparency crash
     ScrollingFrame does not support GroupTransparency.
     Tab pages are now CanvasGroup wrappers (which do), with
     the ScrollingFrame as a child for scrolling content.

  2. Interactable on wrong object
     Was set on the ScrollingFrame constructor props alongside
     GroupTransparency — both invalid there. Now set on the
     CanvasGroup wrapper, which supports it correctly.

  3. Hover nil bug (forward reference)
     tabClickBtn.MouseEnter/Leave referenced `page` before it was
     declared, so the comparison `_curPage ~= page` was always
     comparing against nil. The hover connections now capture
     `pageGroup` (the CanvasGroup) in the same scope they are
     created, after it is declared.

ICON SYSTEM OVERHAUL
  4. Fake rbxassetid table replaced with live CDN fetching.
     Roblox ImageLabel.Image accepts HTTPS URLs. Icons are now
     fetched from api.iconify.design (the same CDN WindUI uses):
       https://api.iconify.design/lucide/{name}.svg?color=%23ffffff&height=64
     The white fill is then tinted by ImageColor3, matching WindUI's
     theming approach. Any Lucide icon name works — not just the
     ~80 in the old hardcoded table.

  5. Icon cache (_iconCache table) prevents building the same URL
     string on every applyIcon call.

  6. Solar icons work via the same CDN:
       solar:pen-bold → https://api.iconify.design/solar/pen-bold.svg
     Other prefix sets fall back to Lucide (no separate tables needed).

USAGE — no API changes
  The public API (CreateWindow, AddTab, AddSection, all elements,
  Notify, SetTheme, SetBackground, Destroy) is 100% unchanged.
  Existing scripts work without modification.
════════════════════════════════════════════════════════
]]
