local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local camera = workspace.CurrentCamera

-- Универсальный конфиг
local Config = {
    AccentColor = Color3.fromRGB(170, 90, 255),
    ChinaHatEnabled = false,
    TrailsEnabled = false,
    JumpCircleEnabled = false,
    ArrowsEnabled = false,
    ArrowsRadius = 120, 
    ArrowsSize = 14     
}

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
mainFrame.Size = UDim2.new(0, 760, 0, 440) -- Твой оригинальный размер под ПК
mainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
mainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
mainFrame.BackgroundColor3 = COLORS.Background
Instance.new("UICorner", mainFrame).CornerRadius = UDim.new(0, 10)

-- Умный UIScale под мобилки (чтобы не расползалось как на фото 1)
local uiScale = Instance.new("UIScale", mainFrame)
local function updateScale()
    local screen = camera.ViewportSize
    local scaleX = (screen.X * 0.95) / 760
    local scaleY = (screen.Y * 0.95) / 440
    local minScale = math.min(scaleX, scaleY)
    uiScale.Scale = minScale < 1 and minScale or 1
end
updateScale()
camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)

-- Перетаскивание для тач-скрина и мыши
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

-- Сайдбар слева
local sidebar = Instance.new("Frame", mainFrame)
sidebar.Size = UDim2.new(0, 45, 1, 0)
sidebar.BackgroundColor3 = COLORS.Sidebar
Instance.new("UICorner", sidebar).CornerRadius = UDim.new(0, 10)

local logo = Instance.new("ImageLabel", sidebar)
logo.Size = UDim2.new(0, 22, 0, 22)
logo.Position = UDim2.new(0, 11, 0, 12)
logo.BackgroundTransparency = 1
logo.Image = "rbxassetid://16143301809"
logo.ImageColor3 = COLORS.AccentPink

local sidebarIcons = Instance.new("Frame", sidebar)
sidebarIcons.Size = UDim2.new(1, 0, 1, -55)
sidebarIcons.Position = UDim2.new(0, 0, 0, 55)
sidebarIcons.BackgroundTransparency = 1
local sideLayout = Instance.new("UIListLayout", sidebarIcons)
sideLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
sideLayout.Padding = UDim.new(0, 14)

-- Категории (Список модулей)
local moduleList = Instance.new("Frame", mainFrame)
moduleList.Size = UDim2.new(0, 140, 1, 0)
moduleList.Position = UDim2.new(0, 45, 0, 0)
moduleList.BackgroundColor3 = COLORS.ModuleList
moduleList.BorderSizePixel = 0

local moduleHeader = Instance.new("TextLabel", moduleList)
moduleHeader.Size = UDim2.new(1, 0, 0, 45)
moduleHeader.Position = UDim2.new(0, 14, 0, 0)
moduleHeader.BackgroundTransparency = 1
moduleHeader.Text = "Движение"
moduleHeader.TextColor3 = COLORS.TextWhite
moduleHeader.TextSize = 13
moduleHeader.Font = Enum.Font.GothamBold
moduleHeader.TextXAlignment = Enum.TextXAlignment.Left

local scrollModules = Instance.new("ScrollingFrame", moduleList)
scrollModules.Size = UDim2.new(1, 0, 1, -45)
scrollModules.Position = UDim2.new(0, 0, 0, 45)
scrollModules.BackgroundTransparency = 1
scrollModules.ScrollBarThickness = 0
local modLayout = Instance.new("UIListLayout", scrollModules)

-- Добавление элементов списка (как на фото 2, с буквами разделов)
local function addModuleListButton(letter, name, active)
    local lbl = Instance.new("TextLabel", scrollModules)
    lbl.Size = UDim2.new(1, 0, 0, 16)
    lbl.Text = "   " .. letter
    lbl.TextColor3 = COLORS.Lines
    lbl.TextSize = 9
    lbl.Font = Enum.Font.GothamBold
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.BackgroundTransparency = 1
    
    local btn = Instance.new("TextButton", scrollModules)
    btn.Size = UDim2.new(1, 0, 0, 24)
    btn.BackgroundTransparency = 1
    btn.Text = "   " .. name
    btn.TextColor3 = active and COLORS.TextWhite or COLORS.TextGray
    btn.TextSize = 11
    btn.Font = Enum.Font.Gotham
    btn.TextXAlignment = Enum.TextXAlignment.Left
end

addModuleListButton("A", "AutoSprint", false)
addModuleListButton("A", "AutoPilot", false)
addModuleListButton("B", "BootControl", false)
addModuleListButton("F", "Flight", true)

-- Правая рабочая область
local contentFrame = Instance.new("Frame", mainFrame)
contentFrame.Size = UDim2.new(1, -185, 1, 0)
contentFrame.Position = UDim2.new(0, 185, 0, 0)
contentFrame.BackgroundTransparency = 1

-- Верхний бар (Кнопка конфига и лупа)
local topBar = Instance.new("Frame", contentFrame)
topBar.Size = UDim2.new(1, 0, 0, 45)
topBar.BackgroundTransparency = 1

local saveConfig = Instance.new("TextButton", topBar)
saveConfig.Size = UDim2.new(0, 120, 0, 24)
saveConfig.Position = UDim2.new(0, 0, 0.5, -12)
saveConfig.BackgroundColor3 = COLORS.ElementBg
saveConfig.Text = "Сохранить конфиг"
saveConfig.TextColor3 = COLORS.TextWhite
saveConfig.TextSize = 10
saveConfig.Font = Enum.Font.GothamBold
Instance.new("UICorner", saveConfig).CornerRadius = UDim.new(0, 5)

local searchIcon = Instance.new("ImageButton", topBar)
searchIcon.Size = UDim2.new(0, 16, 0, 16)
searchIcon.Position = UDim2.new(1, -30, 0.5, -8)
searchIcon.BackgroundTransparency = 1
searchIcon.Image = "rbxassetid://6031154871"
searchIcon.ImageColor3 = COLORS.TextGray

makeDraggable(mainFrame, sidebar)
makeDraggable(mainFrame, topBar)

-- Основной контейнер скролла настроек
local mainSettingsScroll = Instance.new("ScrollingFrame", contentFrame)
mainSettingsScroll.Size = UDim2.new(1, 0, 1, -45)
mainSettingsScroll.Position = UDim2.new(0, 0, 0, 45)
mainSettingsScroll.BackgroundTransparency = 1
mainSettingsScroll.ScrollBarThickness = 2
mainSettingsScroll.ScrollBarImageColor3 = COLORS.TextGray

local pageLayout = Instance.new("UIListLayout", mainSettingsScroll)
pageLayout.Padding = UDim.new(0, 15)

-- Описание модуля сверху
local infoHeader = Instance.new("Frame", mainSettingsScroll)
infoHeader.Size = UDim2.new(1, -15, 0, 35)
infoHeader.BackgroundTransparency = 1

local mainTitle = Instance.new("TextLabel", infoHeader)
mainTitle.Text = "Настройки ElytraTarget 📂"
mainTitle.TextColor3 = COLORS.TextWhite
mainTitle.TextSize = 14
mainTitle.Font = Enum.Font.GothamBold
mainTitle.TextXAlignment = Enum.TextXAlignment.Left

local mainDesc = Instance.new("TextLabel", infoHeader)
mainDesc.Size = UDim2.new(1, 0, 0, 14)
mainDesc.Position = UDim2.new(0, 0, 0, 18)
mainDesc.Text = "Использует элитру и фейерверки для таргета"
mainDesc.TextColor3 = COLORS.TextGray
mainDesc.TextSize = 10
mainDesc.Font = Enum.Font.Gotham
mainDesc.TextXAlignment = Enum.TextXAlignment.Left
mainDesc.BackgroundTransparency = 1

-- Сетка для карточек настроек (Две колонки ровно как на фото 2)
local cardsContainer = Instance.new("Frame", mainSettingsScroll)
cardsContainer.Size = UDim2.new(1, -15, 0, 0)
cardsContainer.AutomaticSize = Enum.AutomaticSize.Y
cardsContainer.BackgroundTransparency = 1

local columnsGrid = Instance.new("UIGridLayout", cardsContainer)
columnsGrid.CellPadding = UDim2.new(0, 10, 0, 10)
columnsGrid.CellSize = UDim2.new(0.5, -5, 0, 95)

-- Конструктор оригинальных блоков
local function createPCWidget(titleText, subText)
    local card = Instance.new("Frame", cardsContainer)
    card.BackgroundColor3 = COLORS.ElementBg
    Instance.new("UICorner", card).CornerRadius = UDim.new(0, 6)
    
    local t = Instance.new("TextLabel", card)
    t.Size = UDim2.new(0.6, 0, 0, 20)
    t.Position = UDim2.new(0, 10, 0, 6)
    t.BackgroundTransparency = 1
    t.Text = titleText
    t.TextColor3 = COLORS.TextWhite
    t.TextSize = 11
    t.Font = Enum.Font.GothamBold
    t.TextXAlignment = Enum.TextXAlignment.Left
    
    if subText then
        local st = Instance.new("TextLabel", card)
        st.Size = UDim2.new(0.35, 0, 0, 20)
        st.Position = UDim2.new(1, -10, 0, 6)
        st.BackgroundTransparency = 1
        st.Text = subText
        st.TextColor3 = COLORS.TextGray
        st.TextSize = 9
        st.Font = Enum.Font.Gotham
        st.TextXAlignment = Enum.TextXAlignment.Right
    end

    local holder = Instance.new("Frame", card)
    holder.Size = UDim2.new(1, -20, 1, -30)
    holder.Position = UDim2.new(0, 10, 0, 26)
    holder.BackgroundTransparency = 1
    
    local layout = Instance.new("UIListLayout", holder)
    layout.FillDirection = Enum.FillDirection.Horizontal
    layout.Wraps = true
    layout.Padding = UDim.new(0, 4)

    return holder
end

-- Функция создания тегов (нажатых розовых кнопок из Minecraft-меню)
local function addWidgetTag(holder, text, active)
    local btn = Instance.new("TextButton", holder)
    btn.BackgroundColor3 = active and COLORS.AccentPink or COLORS.Background
    btn.Text = text
    btn.TextColor3 = active and Color3.fromRGB(20,20,20) or COLORS.TextGray
    btn.TextSize = 9
    btn.Font = Enum.Font.Gotham
    btn.AutomaticSize = Enum.AutomaticSize.X
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 3)
    Instance.new("UIPadding", btn).PaddingLeft = UDim.new(0, 5)
    Instance.new("UIPadding", btn).PaddingRight = UDim.new(0, 5)
end

-- Функция создания ползунка (Слайдера)
local function addWidgetSlider(holder, progressValue, numText)
    local sBg = Instance.new("Frame", holder)
    sBg.Size = UDim2.new(1, 0, 0, 4)
    sBg.Position = UDim2.new(0, 0, 0, 10)
    sBg.BackgroundColor3 = COLORS.Background
    Instance.new("UICorner", sBg)
    
    local sFill = Instance.new("Frame", sBg)
    sFill.Size = UDim2.new(progressValue, 0, 1, 0)
    sFill.BackgroundColor3 = COLORS.AccentPink
    Instance.new("UICorner", sFill)
end

-- Наполнение блоками один в один как на скрине №2:
local h1 = createPCWidget("Визуалы", "1 из 4")
addWidgetTag(h1, "Линии отлива", false)
addWidgetTag(h1, "Линия полёта", false)
addWidgetTag(h1, "Массы противника", false)
addWidgetTag(h1, "Настоящая позиция противника", true)

local h2 = createPCWidget("Задержка при ливе", "500")
-- Пустое текстовое поле ввода/значения

local h3 = createPCWidget("Десинхронизация при", "1 из 1")
addWidgetTag(h3, "Ударе (Defensive)", true)

local h4 = createPCWidget("Векторы лива", "6 из 6")
addWidgetTag(h4, "Низ", true)
addWidgetTag(h4, "Верх", true)
addWidgetTag(h4, "Восток", true)
addWidgetTag(h4, "Запад", true)
addWidgetTag(h4, "Юг", true)

local h5 = createPCWidget("Смена цели")
addWidgetTag(h5, "...", false)

local h6 = createPCWidget("Менять вектор")
-- Чекбокс справа
local chk = Instance.new("Frame", h6)
chk.Size = UDim2.new(0, 12, 0, 12)
chk.BackgroundColor3 = COLORS.AccentPink
Instance.new("UICorner", chk).CornerRadius = UDim.new(0, 3)

local h7 = createPCWidget("Выбор слота", "3")
addWidgetSlider(h7, 0.4, "3")

-- Боковые иконки табов в сайдбаре
local assetIcons = {6023426915, 6031763426, 6034287525, 6023426915, 6031763426}
for _, id in ipairs(assetIcons) do
    local b = Instance.new("ImageButton", sidebarIcons)
    b.Size = UDim2.new(0, 18, 0, 18)
    b.BackgroundTransparency = 1
    b.Image = "rbxassetid://" .. id
    b.ImageColor3 = COLORS.TextGray
end

-- Автоматический пересчет размера прокрутки под контент
cardsContainer:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
    mainSettingsScroll.CanvasSize = UDim2.new(0, 0, 0, cardsContainer.AbsoluteSize.Y + 60)
end)
