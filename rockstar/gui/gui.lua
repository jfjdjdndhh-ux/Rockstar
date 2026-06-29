local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local Rockstar = shared.Rockstar
local Config = Rockstar.Config

local COLORS = {
    Background = Color3.fromRGB(15, 15, 19),
    Sidebar = Color3.fromRGB(11, 11, 14),
    ModuleList = Color3.fromRGB(13, 13, 16),
    ElementBg = Color3.fromRGB(21, 21, 26),
    AccentPink = Color3.fromRGB(242, 155, 180),
    TextWhite = Color3.fromRGB(255, 255, 255),
    TextGray = Color3.fromRGB(140, 140, 145),
    ButtonHover = Color3.fromRGB(30, 30, 38),
    Lines = Color3.fromRGB(25, 25, 32)
}

if playerGui:FindFirstChild("RockstarGui") then playerGui.RockstarGui:Destroy() end

local rockstarGui = Instance.new("ScreenGui", playerGui)
rockstarGui.Name = "RockstarGui"
rockstarGui.ResetOnSpawn = false

local mainFrame = Instance.new("Frame", rockstarGui)
mainFrame.Name = "MainFrame"
mainFrame.Size = UDim2.new(0, 760, 0, 440)
mainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
mainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
mainFrame.BackgroundColor3 = COLORS.Background
Instance.new("UICorner", mainFrame).CornerRadius = UDim.new(0, 10)

-- Универсальный Драггер Touch + Mouse для телефонов
local function makeDraggable(gui, dragHandle)
    local dragging, dragInput, dragStart, startPos
    dragHandle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true; dragStart = input.Position; startPos = gui.Position
            input.Changed:Connect(function() if input.UserInputState == Enum.UserInputState.End then dragging = false end end)
        end
    end)
    dragHandle.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then dragInput = input end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            local delta = input.Position - dragStart
            gui.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
end

-- Сайдбар
local sidebar = Instance.new("Frame", mainFrame)
sidebar.Size = UDim2.new(0, 45, 1, 0)
sidebar.BackgroundColor3 = COLORS.Sidebar
Instance.new("UICorner", sidebar).CornerRadius = UDim.new(0, 10)

local sidebarIcons = Instance.new("Frame", sidebar)
sidebarIcons.Size = UDim2.new(1, 0, 1, -55)
sidebarIcons.Position = UDim2.new(0, 0, 0, 55)
sidebarIcons.BackgroundTransparency = 1
local sideLayout = Instance.new("UIListLayout", sidebarIcons)
sideLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
sideLayout.Padding = UDim.new(0, 15)

-- Список Модулей
local moduleList = Instance.new("Frame", mainFrame)
moduleList.Size = UDim2.new(0, 140, 1, 0)
moduleList.Position = UDim2.new(0, 45, 0, 0)
moduleList.BackgroundColor3 = COLORS.ModuleList
moduleList.BorderSizePixel = 0

local moduleHeader = Instance.new("TextLabel", moduleList)
moduleHeader.Size = UDim2.new(1, 0, 0, 45)
moduleHeader.Position = UDim2.new(0, 12, 0, 0)
moduleHeader.BackgroundTransparency = 1
moduleHeader.Text = "Визуалы"
moduleHeader.TextColor3 = COLORS.TextWhite
moduleHeader.TextSize = 14
moduleHeader.Font = Enum.Font.GothamBold
moduleHeader.TextXAlignment = Enum.TextXAlignment.Left

local scrollModules = Instance.new("ScrollingFrame", moduleList)
scrollModules.Size = UDim2.new(1, 0, 1, -45)
scrollModules.Position = UDim2.new(0, 0, 0, 45)
scrollModules.BackgroundTransparency = 1
scrollModules.ScrollBarThickness = 0
local modLayout = Instance.new("UIListLayout", scrollModules)
modLayout.Padding = UDim.new(0, 2)

-- Настройки (Правая часть)
local contentFrame = Instance.new("Frame", mainFrame)
contentFrame.Size = UDim2.new(1, -185, 1, 0)
contentFrame.Position = UDim2.new(0, 185, 0, 0)
contentFrame.BackgroundTransparency = 1

local topBar = Instance.new("Frame", contentFrame)
topBar.Size = UDim2.new(1, 0, 0, 45)
topBar.BackgroundTransparency = 1

local mainSettingsScroll = Instance.new("ScrollingFrame", contentFrame)
mainSettingsScroll.Size = UDim2.new(1, 0, 1, -45)
mainSettingsScroll.Position = UDim2.new(0, 0, 0, 45)
mainSettingsScroll.BackgroundTransparency = 1
mainSettingsScroll.ScrollBarThickness = 2
mainSettingsScroll.ScrollBarImageColor3 = COLORS.TextGray
Instance.new("UIPadding", mainSettingsScroll).PaddingLeft = UDim.new(0, 15)

local columnsContainer = Instance.new("Frame", mainSettingsScroll)
columnsContainer.Size = UDim2.new(1, -15, 0, 0)
columnsContainer.AutomaticSize = Enum.AutomaticSize.Y
columnsContainer.BackgroundTransparency = 1
local columnsGrid = Instance.new("UIGridLayout", columnsContainer)
columnsGrid.CellPadding = UDim2.new(0, 12, 0, 12)
columnsGrid.CellSize = UDim2.new(0.5, -6, 0, 110)

makeDraggable(mainFrame, sidebar)
makeDraggable(mainFrame, topBar)

local function clearRightPanel()
    for _, item in ipairs(columnsContainer:GetChildren()) do
        if not item:IsA("UIGridLayout") then item:Destroy() end
    end
end

-- Оригинальный конструктор карточек
local function createCard(titleText, rightText)
    local card = Instance.new("Frame", columnsContainer)
    card.BackgroundColor3 = COLORS.ElementBg
    Instance.new("UICorner", card).CornerRadius = UDim.new(0, 8)
    
    local t = Instance.new("TextLabel", card)
    t.Size = UDim2.new(0.6, 0, 0, 24)
    t.Position = UDim2.new(0, 12, 0, 6)
    t.BackgroundTransparency = 1
    t.Text = titleText
    t.TextColor3 = COLORS.TextWhite
    t.TextSize = 12
    t.Font = Enum.Font.GothamBold
    t.TextXAlignment = Enum.TextXAlignment.Left
    
    local rt = nil
    if rightText then
        rt = Instance.new("TextLabel", card)
        rt.Size = UDim2.new(0.35, 0, 0, 24)
        rt.Position = UDim2.new(1, -12, 0, 6)
        rt.BackgroundTransparency = 1
        rt.Text = rightText
        rt.TextColor3 = COLORS.TextGray
        rt.TextSize = 11
        rt.Font = Enum.Font.Gotham
        rt.TextXAlignment = Enum.TextXAlignment.Right
    end

    local holder = Instance.new("Frame", card)
    holder.Size = UDim2.new(1, -24, 1, -34)
    holder.Position = UDim2.new(0, 12, 0, 32)
    holder.BackgroundTransparency = 1
    
    local layout = Instance.new("UIListLayout", holder)
    layout.FillDirection = Enum.FillDirection.Horizontal
    layout.Wraps = true
    layout.Padding = UDim.new(0, 5)

    return card, holder, rt
end

-- Оригинальные теги/кнопки
local function createCardTag(holder, text, configKey)
    local btn = Instance.new("TextButton", holder)
    btn.BackgroundColor3 = Config[configKey] and COLORS.AccentPink or COLORS.Background
    btn.Text = text
    btn.TextColor3 = Config[configKey] and Color3.fromRGB(15,15,15) or COLORS.TextGray
    btn.TextSize = 10
    btn.Font = Enum.Font.Gotham
    btn.AutomaticSize = Enum.AutomaticSize.X
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)
    Instance.new("UIPadding", btn).PaddingLeft = UDim.new(0, 6)

    btn.MouseButton1Click:Connect(function()
        Config[configKey] = not Config[configKey]
        if Config[configKey] then
            TweenService:Create(btn, TweenInfo.new(0.12), {BackgroundColor3 = COLORS.AccentPink, TextColor3 = Color3.fromRGB(15,15,15)}):Play()
        else
            TweenService:Create(btn, TweenInfo.new(0.12), {BackgroundColor3 = COLORS.Background, TextColor3 = COLORS.TextGray}):Play()
        end
    end)
end

-- Оригинальный Слайдер
local function createCardSlider(holder, min, max, configKey, lbl)
    local sBg = Instance.new("Frame", holder)
    sBg.Size = UDim2.new(1, 0, 0, 4)
    sBg.Position = UDim2.new(0, 0, 0, 14)
    sBg.BackgroundColor3 = COLORS.Background
    
    local sFill = Instance.new("Frame", sBg)
    sFill.Size = UDim2.new((Config[configKey] - min)/(max - min), 0, 1, 0)
    sFill.BackgroundColor3 = COLORS.AccentPink
    
    local sBtn = Instance.new("TextButton", sBg)
    sBtn.Size = UDim2.new(1, 0, 1, 14)
    sBtn.Position = UDim2.new(0, 0, 0, -7)
    sBtn.BackgroundTransparency = 1
    sBtn.Text = ""
    
    local dragging = false
    local function update(input)
        local pct = math.clamp((input.Position.X - sBg.AbsolutePosition.X) / sBg.AbsoluteSize.X, 0, 1)
        sFill.Size = UDim2.new(pct, 0, 1, 0)
        local val = math.floor(min + (pct * (max - min)))
        Config[configKey] = val
        if lbl then lbl.Text = tostring(val) end
    end
    
    sBtn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then dragging = true; update(input) end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then update(input) end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then dragging = false end
    end)
end

local loadedModules = {}
local function loadModuleScript(name)
    if not loadedModules[name] then
        loadedModules[name] = true
        task.spawn(function()
            loadstring(game:HttpGet(Rockstar.BaseUrl .. "modules/" .. name .. ".lua"))()
        end)
    end
end

-- Динамическое обновление настроек при клике
local function openSettingsFor(modName)
    clearRightPanel()
    loadModuleScript(modName)
    
    if modName == "chinaHat" then
        local _, h = createCard("ElytraTarget", nil)
        createCardTag(h, "Активировать ChinaHat", "ChinaHatEnabled")
    elseif modName == "jumpCircle" then
        local _, h = createCard("ElytraTarget", nil)
        createCardTag(h, "Активировать JumpCircle", "JumpCircleEnabled")
    elseif modName == "arrows" then
        local _, h1 = createCard("ElytraTarget", nil)
        createCardTag(h1, "Активировать Стрелочки", "ArrowsEnabled")
        
        local _, h2, l2 = createCard("Радиус стрелок", tostring(Config.ArrowsRadius))
        createCardSlider(h2, 50, 300, "ArrowsRadius", l2)
        
        local _, h3, l3 = createCard("Размер элементов", tostring(Config.ArrowsSize))
        createCardSlider(h3, 8, 35, "ArrowsSize", l3)
    end
end

-- Модули в списке
local modules = {"chinaHat", "jumpCircle", "arrows"}
for _, name in ipairs(modules) do
    local btn = Instance.new("TextButton", scrollModules)
    btn.Size = UDim2.new(1, 0, 0, 26)
    btn.BackgroundTransparency = 1
    btn.Text = "   " .. name
    btn.TextColor3 = COLORS.TextGray
    btn.TextSize = 12
    btn.Font = Enum.Font.Gotham
    btn.TextXAlignment = Enum.TextXAlignment.Left
    
    btn.MouseButton1Click:Connect(function()
        for _, c in ipairs(scrollModules:GetChildren()) do if c:IsA("TextButton") then c.TextColor3 = COLORS.TextGray end end
        btn.TextColor3 = COLORS.TextWhite
        openSettingsFor(name)
    end)
end

-- Иконки табов
local assetIcons = {106812709821478, 120146441316947, 125523121468315}
for _, id in ipairs(assetIcons) do
    local b = Instance.new("ImageButton", sidebarIcons)
    b.Size = UDim2.new(0, 24, 0, 24)
    b.BackgroundTransparency = 1
    b.Image = "rbxassetid://" .. id
    b.ImageColor3 = COLORS.TextGray
end

openSettingsFor("chinaHat")

-- Фикс скролла под контент
columnsContainer:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
    mainSettingsScroll.CanvasSize = UDim2.new(0, 0, 0, columnsContainer.AbsoluteSize.Y + 30)
end)
