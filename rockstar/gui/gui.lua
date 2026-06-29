local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Rockstar = shared.Rockstar
local Config = Rockstar.Config

local COLORS = {
    Bg = Color3.fromRGB(15, 15, 19),
    Sidebar = Color3.fromRGB(11, 11, 14),
    MidList = Color3.fromRGB(13, 13, 16),
    RightBg = Color3.fromRGB(21, 21, 26),
    AccentPink = Color3.fromRGB(242, 155, 180),
    TextWhite = Color3.fromRGB(255, 255, 255),
    TextGray = Color3.fromRGB(140, 140, 145)
}

if game:GetService("CoreGui"):FindFirstChild("RockstarMenu") then 
    game:GetService("CoreGui").RockstarMenu:Destroy() 
end

local mainGui = Instance.new("ScreenGui", game:GetService("CoreGui"))
mainGui.Name = "RockstarMenu"

-- Главное окно: теперь размеры адаптивные (аккуратно по центру экрана)
local mainFrame = Instance.new("Frame", mainGui)
mainFrame.Size = UDim2.new(0.55, 0, 0.6, 0) -- Занимает 55% ширины и 60% высоты экрана мобилы
mainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
mainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
mainFrame.BackgroundColor3 = COLORS.Bg
Instance.new("UICorner", mainFrame).CornerRadius = UDim.new(0, 10)

-- Ограничитель размеров (чтобы меню не ломалось на слишком маленьких/больших экранах)
local sizeConstraint = Instance.new("UISizeConstraint", mainFrame)
sizeConstraint.MinSize = Vector2.new(480, 280)
sizeConstraint.MaxSize = Vector2.new(700, 400)

-- Функция перетаскивания (Драггер)
local function makeDraggable(gui)
    local dragging, dragInput, dragStart, startPos
    gui.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true; dragStart = input.Position; startPos = gui.Position
            input.Changed:Connect(function() if input.UserInputState == Enum.UserInputState.End then dragging = false end end)
        end
    end)
    gui.InputChanged:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then dragInput = input end end)
    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            local delta = input.Position - dragStart
            gui.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
end
makeDraggable(mainFrame)

-- Сайдбар (Вкладки слева) — фиксированная ширина в пикселях, высота 100%
local sidebar = Instance.new("Frame", mainFrame)
sidebar.Size = UDim2.new(0, 45, 1, 0)
sidebar.BackgroundColor3 = COLORS.Sidebar
Instance.new("UICorner", sidebar).CornerRadius = UDim.new(0, 10)

local sidebarLayout = Instance.new("UIListLayout", sidebar)
sidebarLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
sidebarLayout.Padding = UDim.new(0, 12)

-- Центральный список модулей — тоже фиксированная ширина
local midPanel = Instance.new("Frame", mainFrame)
midPanel.Size = UDim2.new(0, 135, 1, 0)
midPanel.Position = UDim2.new(0, 45, 0, 0)
midPanel.BackgroundColor3 = COLORS.MidList
midPanel.BorderSizePixel = 0

local midScroll = Instance.new("ScrollingFrame", midPanel)
midScroll.Size = UDim2.new(1, -8, 1, -16)
midScroll.Position = UDim2.new(0, 4, 0, 8)
midScroll.BackgroundTransparency = 1
midScroll.ScrollBarThickness = 0
local midLayout = Instance.new("UIListLayout", midScroll)
midLayout.Padding = UDim.new(0, 5)

-- Правая панель настроек — занимает ВСЁ оставшееся динамическое место
local rightPanel = Instance.new("Frame", mainFrame)
rightPanel.Size = UDim2.new(1, -180, 1, 0) -- Авто-вычисление ширины
rightPanel.Position = UDim2.new(0, 180, 0, 0)
rightPanel.BackgroundTransparency = 1

local rightScroll = Instance.new("ScrollingFrame", rightPanel)
rightScroll.Size = UDim2.new(1, -12, 1, -16)
rightScroll.Position = UDim2.new(0, 6, 0, 8)
rightScroll.BackgroundTransparency = 1
rightScroll.ScrollBarThickness = 2
rightScroll.ScrollBarImageColor3 = COLORS.TextGray
local rightLayout = Instance.new("UIListLayout", rightScroll)
rightLayout.Padding = UDim.new(0, 8)

local function clearSettings()
    for _, item in ipairs(rightScroll:GetChildren()) do
        if not item:IsA("UIListLayout") then item:Destroy() end
    end
end

-- Сборщик Чекбоксов/Тумблеров
local function createToggleSetting(title, configKey, callback)
    local row = Instance.new("Frame", rightScroll)
    row.Size = UDim2.new(1, 0, 0, 36)
    row.BackgroundColor3 = COLORS.RightBg
    local corner = Instance.new("UICorner", row).CornerRadius = UDim.new(0, 6)
    
    local lbl = Instance.new("TextLabel", row)
    lbl.Size = UDim2.new(1, -60, 1, 0)
    lbl.Position = UDim2.new(0, 10, 0, 0)
    lbl.Text = title
    lbl.TextColor3 = COLORS.TextWhite
    lbl.Font = Enum.Font.GothamMedium
    lbl.TextSize = 11
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.BackgroundTransparency = 1
    
    local btn = Instance.new("TextButton", row)
    btn.Size = UDim2.new(0, 34, 0, 18)
    btn.Position = UDim2.new(1, -44, 0.5, -9)
    btn.BackgroundColor3 = Config[configKey] and COLORS.AccentPink or COLORS.Bg
    btn.Text = ""
    Instance.new("UICorner", btn).CornerRadius = UDim.new(1, 0)
    
    local circle = Instance.new("Frame", btn)
    circle.Size = UDim2.new(0, 12, 0, 12)
    circle.Position = Config[configKey] and UDim2.new(1, -14, 0, 3) or UDim2.new(0, 2, 0, 3)
    circle.BackgroundColor3 = COLORS.TextWhite
    Instance.new("UICorner", circle).CornerRadius = UDim.new(1, 0)
    
    btn.MouseButton1Click:Connect(function()
        Config[configKey] = not Config[configKey]
        if Config[configKey] then
            TweenService:Create(btn, TweenInfo.new(0.12), {BackgroundColor3 = COLORS.AccentPink}):Play()
            TweenService:Create(circle, TweenInfo.new(0.12), {Position = UDim2.new(1, -14, 0, 3)}):Play()
        else
            TweenService:Create(btn, TweenInfo.new(0.12), {BackgroundColor3 = COLORS.Bg}):Play()
            TweenService:Create(circle, TweenInfo.new(0.12), {Position = UDim2.new(0, 2, 0, 3)}):Play()
        end
        if callback then callback(Config[configKey]) end
    end)
end

-- Сборщик Ползунков (Слайдеров)
local function createSliderSetting(title, min, max, configKey, callback)
    local row = Instance.new("Frame", rightScroll)
    row.Size = UDim2.new(1, 0, 0, 48)
    row.BackgroundColor3 = COLORS.RightBg
    Instance.new("UICorner", row).CornerRadius = UDim.new(0, 6)
    
    local lbl = Instance.new("TextLabel", row)
    lbl.Size = UDim2.new(1, -15, 0, 18)
    lbl.Position = UDim2.new(0, 10, 0, 4)
    lbl.Text = title .. ": " .. tostring(Config[configKey])
    lbl.TextColor3 = COLORS.TextWhite
    lbl.Font = Enum.Font.GothamMedium
    lbl.TextSize = 11
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.BackgroundTransparency = 1
    
    local sliderBg = Instance.new("Frame", row)
    sliderBg.Size = UDim2.new(1, -20, 0, 4)
    sliderBg.Position = UDim2.new(0, 10, 0, 30)
    sliderBg.BackgroundColor3 = COLORS.Bg
    Instance.new("UICorner", sliderBg)
    
    local fill = Instance.new("Frame", sliderBg)
    fill.Size = UDim2.new((Config[configKey] - min)/(max - min), 0, 1, 0)
    fill.BackgroundColor3 = COLORS.AccentPink
    Instance.new("UICorner", fill)
    
    local trigger = Instance.new("TextButton", sliderBg)
    trigger.Size = UDim2.new(1, 0, 1, 0)
    trigger.BackgroundTransparency = 1
    trigger.Text = ""
    
    trigger.MouseButton1Down:Connect(function()
        local moveConn
        moveConn = UserInputService.InputChanged:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
                local relativeX = math.clamp((input.Position.X - sliderBg.AbsolutePosition.X) / sliderBg.AbsoluteSize.X, 0, 1)
                fill.Size = UDim2.new(relativeX, 0, 1, 0)
                local val = math.floor(min + (max - min) * relativeX)
                lbl.Text = title .. ": " .. tostring(val)
                Config[configKey] = val
                if callback then callback(val) end
            end
        end)
        UserInputService.InputEnded:Connect(function(endInput)
            if endInput.UserInputType == Enum.UserInputType.MouseButton1 or endInput.UserInputType == Enum.UserInputType.Touch then 
                moveConn:Disconnect() 
            end
        end)
    end)
end

-- Автозагрузка модулей
local loadedModules = {}
local function ensureModuleLoaded(name)
    if not loadedModules[name] then
        loadedModules[name] = true
        task.spawn(function()
            loadstring(game:HttpGet(Rockstar.BaseUrl .. "modules/" .. name .. ".lua"))()
        end)
    end
end

-- Открытие настроек
local function openModuleSettings(modName)
    clearSettings()
    ensureModuleLoaded(modName)
    
    if modName == "chinaHat" then
        createToggleSetting("Включить ChinaHat", "ChinaHat")
    elseif modName == "jumpCircle" then
        createToggleSetting("Включить JumpCircle", "JumpCircle")
    elseif modName == "arrows" then
        createToggleSetting("Включить Стрелочки", "Arrows")
        createSliderSetting("Радиус от прицела", 50, 300, "ArrowsRadius")
        createSliderSetting("Размер стрелочек", 8, 35, "ArrowsSize")
        createToggleSetting("Цель: Игроки", "ArrowsShowPlayers")
        createToggleSetting("Цель: Друзья", "ArrowsShowFriends")
    end
end

-- Смена табов
local function loadCategoryModules(cat)
    for _, c in ipairs(midScroll:GetChildren()) do if c:IsA("TextButton") then c:Destroy() end end
    local list = (cat == "Visuals") and {"chinaHat", "jumpCircle"} or {"arrows"}
    
    for _, name in ipairs(list) do
        local btn = Instance.new("TextButton", midScroll)
        btn.Size = UDim2.new(1, 0, 0, 30)
        btn.BackgroundColor3 = COLORS.Bg
        btn.Text = "  " .. name
        btn.TextColor3 = COLORS.TextWhite
        btn.Font = Enum.Font.GothamMedium
        btn.TextSize = 11
        btn.TextXAlignment = Enum.TextXAlignment.Left
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)
        
        btn.MouseButton1Click:Connect(function()
            openModuleSettings(name)
        end)
    end
end

-- Левые табы
local tabs = { {Name = "Visuals", Icon = "rbxassetid://6023426915"}, {Name = "Render", Icon = "rbxassetid://6034287525"} }
for _, tabData in ipairs(tabs) do
    local tabBtn = Instance.new("ImageButton", sidebar)
    tabBtn.Size = UDim2.new(0, 26, 0, 26)
    tabBtn.BackgroundTransparency = 1
    tabBtn.Image = tabData.Icon
    tabBtn.ImageColor3 = (tabData.Name == "Visuals") and COLORS.AccentPink or COLORS.TextGray
    
    tabBtn.MouseButton1Click:Connect(function()
        for _, b in ipairs(sidebar:GetChildren()) do if b:IsA("ImageButton") then b.ImageColor3 = COLORS.TextGray end end
        tabBtn.ImageColor3 = COLORS.AccentPink
        loadCategoryModules(tabData.Name)
    end)
end

loadCategoryModules("Visuals")
