local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local camera = workspace.CurrentCamera

-- ==========================================
-- НАСТРОЙКИ МОДУЛЕЙ (Оригинальный конфиг)
-- ==========================================
local Config = {
    AccentColor = Color3.fromRGB(170, 90, 255),
    ChinaHatScale = Vector3.new(2.0, 0.5, 2.0),
    TrailLifetime = 0.5,                        
    ColorShiftSpeed = 2,                        
    
    ChinaHatEnabled = false,
    TrailsEnabled = false,
    JumpCircleEnabled = false,
    ArrowsEnabled = false,
    
    ArrowsRadius = 120, 
    ArrowsSize = 14     
}

local ActiveChinaHat = nil
local HatLoop = nil
local TrailConnection = nil
local JumpConnection = nil
local ActiveAttachments = {}
local ArrowElements = {} 

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

-- Очистка старых UI
if playerGui:FindFirstChild("Rockstar") then playerGui.Rockstar:Destroy() end
if playerGui:FindFirstChild("RockstarArrowsRadar") then playerGui.RockstarArrowsRadar:Destroy() end

local rockstarGui = Instance.new("ScreenGui", playerGui)
rockstarGui.Name = "Rockstar"
rockstarGui.ResetOnSpawn = false

local radarRobloxGui = Instance.new("ScreenGui", playerGui)
radarRobloxGui.Name = "RockstarArrowsRadar"
radarRobloxGui.ResetOnSpawn = false

-- Главное окно
local mainFrame = Instance.new("Frame", rockstarGui)
mainFrame.Name = "MainFrame"
mainFrame.Size = UDim2.new(0, 760, 0, 440)
mainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
mainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
mainFrame.BackgroundColor3 = COLORS.Background
mainFrame.BorderSizePixel = 0
mainFrame.ClipsDescendants = true

-- Жесткий UIScale для мобилок, чтобы ничего не нализало
local uiScale = Instance.new("UIScale", mainFrame)
local function updateScale()
    local viewportSize = camera.ViewportSize
    uiScale.Scale = math.min(viewportSize.X / 780, viewportSize.Y / 460, 1)
end
camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
updateScale()

Instance.new("UICorner", mainFrame).CornerRadius = UDim.new(0, 10)

-- Драггер
local function makeDraggable(gui, dragHandle)
    local dragging, dragInput, dragStart, startPos
    dragHandle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = gui.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    dragHandle.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            local delta = input.Position - dragStart
            gui.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
end

-- ==========================================
-- ОРИГИНАЛЬНАЯ ЛОГИКА ФУНКЦИЙ
-- ==========================================
local function ToggleChinaHat(enable)
    Config.ChinaHatEnabled = enable
    if HatLoop then HatLoop:Disconnect() HatLoop = nil end
    if not enable then
        if ActiveChinaHat then ActiveChinaHat:Destroy() ActiveChinaHat = nil end
        return
    end
    if ActiveChinaHat then ActiveChinaHat:Destroy() end
    
    local character = player.Character or player.CharacterAdded:Wait()
    local head = character:WaitForChild("Head", 5)
    if not head then return end
    
    local hat = Instance.new("Part")
    hat.Name = "CelestialHat"
    hat.Size = Config.ChinaHatScale
    hat.Massless = true
    hat.CanCollide = false
    hat.Material = Enum.Material.ForceField
    hat.Color = Config.AccentColor
    
    local mesh = Instance.new("SpecialMesh", hat)
    mesh.MeshType = Enum.MeshType.FileMesh
    mesh.MeshId = "rbxassetid://1033714" 
    mesh.TextureId = "rbxassetid://1033714"
    mesh.Scale = Vector3.new(Config.ChinaHatScale.X, Config.ChinaHatScale.Y * 2, Config.ChinaHatScale.Z)

    local weld = Instance.new("Weld", hat)
    weld.Part0 = head
    weld.Part1 = hat
    weld.C0 = CFrame.new(0, 0.8, 0)
    
    hat.Parent = character
    ActiveChinaHat = hat
    
    local baseH, baseS, baseV = Config.AccentColor:ToHSV()
    HatLoop = RunService.RenderStepped:Connect(function()
        if not hat or not hat.Parent then HatLoop:Disconnect() return end
        local shift = math.sin(tick() * Config.ColorShiftSpeed) * 0.08
        hat.Color = Color3.fromHSV((baseH + shift) % 1, baseS, baseV)
    end)
end

local function ClearTrails()
    if TrailConnection then TrailConnection:Disconnect() TrailConnection = nil end
    for _, obj in ipairs(ActiveAttachments) do if obj then obj:Destroy() end end
    ActiveAttachments = {}
end

local function ApplyTrailToCharacter(char)
    local root = char:WaitForChild("HumanoidRootPart", 5)
    if not root then return end
    
    local attTop = Instance.new("Attachment", root)
    attTop.Position = Vector3.new(0, 1, 0)
    local attBottom = Instance.new("Attachment", root)
    attBottom.Position = Vector3.new(0, -1, 0)
    
    local trail = Instance.new("Trail", root)
    trail.Attachment0 = attTop
    trail.Attachment1 = attBottom
    trail.Color = ColorSequence.new(Config.AccentColor)
    trail.Lifetime = Config.TrailLifetime
    trail.LightEmission = 0.5
    trail.WidthScale = NumberSequence.new({NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0)})
    
    table.insert(ActiveAttachments, attTop)
    table.insert(ActiveAttachments, attBottom)
    table.insert(ActiveAttachments, trail)
end

local function ToggleTrails(enable)
    Config.TrailsEnabled = enable
    ClearTrails()
    if not enable then return end
    if player.Character then ApplyTrailToCharacter(player.Character) end
    TrailConnection = player.CharacterAdded:Connect(ApplyTrailToCharacter)
end

local function SpawnJumpCircle(rootPart)
    if not rootPart then return end
    local circle = Instance.new("Part", workspace)
    circle.Shape = Enum.PartType.Cylinder
    circle.Size = Vector3.new(0.1, 0.5, 0.5)
    circle.Position = rootPart.Position - Vector3.new(0, 2.5, 0) 
    circle.Orientation = Vector3.new(0, 0, 90) 
    circle.Color = Config.AccentColor
    circle.Material = Enum.Material.ForceField
    circle.Anchored = true
    circle.CanCollide = false
    
    TweenService:Create(circle, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Size = Vector3.new(0.1, 6, 6)
    }):Play()
    task.delay(0.4, function() circle:Destroy() end)
end

local function ListenToJump(char)
    if JumpConnection then JumpConnection:Disconnect() JumpConnection = nil end
    local humanoid = char:WaitForChild("Humanoid", 5)
    local root = char:WaitForChild("HumanoidRootPart", 5)
    if humanoid and root then
        JumpConnection = humanoid.Jumping:Connect(function(isActive)
            if isActive and Config.JumpCircleEnabled then SpawnJumpCircle(root) end
        end)
    end
end

local function ToggleJumpCircle(enable)
    Config.JumpCircleEnabled = enable
    if not enable then
        if JumpConnection then JumpConnection:Disconnect() JumpConnection = nil end
        return
    end
    if player.Character then ListenToJump(player.Character) end
    player.CharacterAdded:Connect(ListenToJump)
end

-- Логика Arrows
local function ClearArrows()
    for _, arrow in pairs(ArrowElements) do arrow:Destroy() end
    ArrowElements = {}
end

RunService.RenderStepped:Connect(function()
    if not Config.ArrowsEnabled then ClearArrows() return end
    local screenCenter = camera.ViewportSize / 2

    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= player and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
            local rootPart = p.Character.HumanoidRootPart
            local screenPos, onScreen = camera:WorldToViewportPoint(rootPart.Position)
            local arrow = ArrowElements[p.Name]
            
            if not arrow then
                arrow = Instance.new("ImageLabel", radarRobloxGui)
                arrow.Size = UDim2.new(0, Config.ArrowsSize, 0, Config.ArrowsSize)
                arrow.AnchorPoint = Vector2.new(0.5, 0.5)
                arrow.BackgroundTransparency = 1
                arrow.Image = "rbxassetid://7072706663" 
                arrow.ImageColor3 = COLORS.AccentPink
                ArrowElements[p.Name] = arrow
            end

            local direction = Vector2.new(screenPos.X - screenCenter.X, screenPos.Y - screenCenter.Y)
            if screenPos.Z < 0 then direction = -direction end
            local angle = math.atan2(direction.Y, direction.X)
            
            if onScreen and direction.Magnitude < Config.ArrowsRadius then
                arrow.Visible = false
            else
                arrow.Visible = true
                arrow.Position = UDim2.new(0, screenCenter.X + math.cos(angle) * Config.ArrowsRadius, 0, screenCenter.Y + math.sin(angle) * Config.ArrowsRadius)
                arrow.Rotation = math.deg(angle) + 90 
            end
        else
            if ArrowElements[p.Name] then ArrowElements[p.Name]:Destroy() ArrowElements[p.Name] = nil end
        end
    end
end)

-- ==========================================
-- СБОРКА ИНТЕРФЕЙСА (ПК Стиль)
-- ==========================================

-- Левый сайдбар
local sidebar = Instance.new("Frame", mainFrame)
sidebar.Size = UDim2.new(0, 45, 1, 0)
sidebar.BackgroundColor3 = COLORS.Sidebar
sidebar.BorderSizePixel = 0

local logo = Instance.new("ImageLabel", sidebar)
logo.Size = UDim2.new(0, 24, 0, 24)
logo.Position = UDim2.new(0, 10, 0, 12)
logo.BackgroundTransparency = 1
logo.Image = "rbxassetid://16143301809"
logo.ImageColor3 = COLORS.AccentPink

local sidebarIcons = Instance.new("Frame", sidebar)
sidebarIcons.Size = UDim2.new(1, 0, 1, -55)
sidebarIcons.Position = UDim2.new(0, 0, 0, 55)
sidebarIcons.BackgroundTransparency = 1

local sideLayout = Instance.new("UIListLayout", sidebarIcons)
sideLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
sideLayout.Padding = UDim.new(0, 12)

-- Средний модульный список категорий
local moduleList = Instance.new("Frame", mainFrame)
moduleList.Size = UDim2.new(0, 140, 1, 0)
moduleList.Position = UDim2.new(0, 45, 0, 0)
moduleList.BackgroundColor3 = COLORS.ModuleList
moduleList.BorderSizePixel = 0

local moduleHeader = Instance.new("TextLabel", moduleList)
moduleHeader.Size = UDim2.new(1, -15, 0, 45)
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
Instance.new("UIListLayout", scrollModules)

-- Правая часть (Контент страниц)
local contentFrame = Instance.new("Frame", mainFrame)
contentFrame.Size = UDim2.new(1, -185, 1, 0)
contentFrame.Position = UDim2.new(0, 185, 0, 0)
contentFrame.BackgroundTransparency = 1

local topBar = Instance.new("Frame", contentFrame)
topBar.Size = UDim2.new(1, 0, 0, 45)
topBar.BackgroundTransparency = 1

-- Кнопка Сохранить Конфиг и Лупа
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

-- Конструктор страниц скролла настроек
local function createSettingsPage(titleText, descText)
    local page = Instance.new("ScrollingFrame", contentFrame)
    page.Size = UDim2.new(1, 0, 1, -45)
    page.Position = UDim2.new(0, 0, 0, 45)
    page.BackgroundTransparency = 1
    page.ScrollBarThickness = 2
    page.ScrollBarImageColor3 = COLORS.TextGray
    page.Visible = false
    
    local padding = Instance.new("UIPadding", page)
    padding.PaddingLeft = UDim.new(0, 15)
    padding.PaddingRight = UDim.new(0, 15)
    
    local layout = Instance.new("UIListLayout", page)
    layout.Padding = UDim.new(0, 12)

    local header = Instance.new("Frame", page)
    header.Size = UDim2.new(1, 0, 0, 40)
    header.BackgroundTransparency = 1

    local t = Instance.new("TextLabel", header)
    t.Size = UDim2.new(1, -40, 0, 22)
    t.BackgroundTransparency = 1
    t.Text = titleText
    t.TextColor3 = COLORS.TextWhite
    t.TextSize = 15
    t.Font = Enum.Font.GothamBold
    t.TextXAlignment = Enum.TextXAlignment.Left

    local closeBtn = Instance.new("TextButton", header)
    closeBtn.Size = UDim2.new(0, 25, 0, 25)
    closeBtn.Position = UDim2.new(1, -10, 0, 0)
    closeBtn.AnchorPoint = Vector2.new(1, 0)
    closeBtn.BackgroundTransparency = 1
    closeBtn.Text = "X"
    closeBtn.TextColor3 = COLORS.TextGray
    closeBtn.TextSize = 14
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.MouseButton1Click:Connect(function() rockstarGui:Destroy() radarRobloxGui:Destroy() end)

    local d = Instance.new("TextLabel", header)
    d.Size = UDim2.new(1, 0, 0, 14)
    d.Position = UDim2.new(0, 0, 0, 22)
    d.BackgroundTransparency = 1
    d.Text = descText
    d.TextColor3 = COLORS.TextGray
    d.TextSize = 10
    d.Font = Enum.Font.Gotham
    d.TextXAlignment = Enum.TextXAlignment.Left
    
    local cardsContainer = Instance.new("Frame", page)
    cardsContainer.Size = UDim2.new(1, 0, 0, 0)
    cardsContainer.AutomaticSize = Enum.AutomaticSize.Y
    cardsContainer.BackgroundTransparency = 1
    
    local columnsGrid = Instance.new("UIGridLayout", cardsContainer)
    columnsGrid.CellPadding = UDim2.new(0, 12, 0, 12)
    columnsGrid.CellSize = UDim2.new(0.5, -6, 0, 100)

    cardsContainer:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
        page.CanvasSize = UDim2.new(0, 0, 0, cardsContainer.AbsoluteSize.Y + 60)
    end)

    return page, cardsContainer
end

local pages = {}
pages["Visuals"], visualsCards = createSettingsPage("Настройки Визуалов 📁", "Кастомизация отображения эффектов персонажа")
pages["Movement"], movementCards = createSettingsPage("Настройки Движения 📁", "Параметры перемещения и физики")
pages["Render"], renderCards = createSettingsPage("Настройки Рендера 📁", "Стрелочки, трейсеры и ESP радары")

pages["Visuals"].Visible = true

-- Функция создания КАРТОЧЕК С ТУМБЛЕРАМИ ПРЯМО В СЕТКЕ
local function createToggleCard(container, titleText, startState, callback)
    local card = Instance.new("Frame", container)
    card.BackgroundColor3 = COLORS.ElementBg
    Instance.new("UICorner", card).CornerRadius = UDim.new(0, 8)
    
    local t = Instance.new("TextLabel", card)
    t.Size = UDim2.new(1, -24, 0, 24)
    t.Position = UDim2.new(0, 12, 0, 8)
    t.BackgroundTransparency = 1
    t.Text = titleText
    t.TextColor3 = COLORS.TextWhite
    t.TextSize = 11
    t.Font = Enum.Font.GothamBold
    t.TextXAlignment = Enum.TextXAlignment.Left

    local toggleBtn = Instance.new("TextButton", card)
    toggleBtn.Size = UDim2.new(0, 34, 0, 18)
    toggleBtn.Position = UDim2.new(0, 12, 0, 40)
    toggleBtn.BackgroundColor3 = startState and COLORS.AccentPink or COLORS.Background
    toggleBtn.Text = ""
    Instance.new("UICorner", toggleBtn).CornerRadius = UDim.new(1, 0)

    local toggleCircle = Instance.new("Frame", toggleBtn)
    toggleCircle.Size = UDim2.new(0, 14, 0, 14)
    toggleCircle.Position = startState and UDim2.new(1, -16, 0, 2) or UDim2.new(0, 2, 0, 2)
    toggleCircle.BackgroundColor3 = startState and Color3.fromRGB(15,15,15) or COLORS.TextGray
    Instance.new("UICorner", toggleCircle).CornerRadius = UDim.new(1, 0)

    local active = startState
    toggleBtn.MouseButton1Click:Connect(function()
        active = not active
        if active then
            TweenService:Create(toggleBtn, TweenInfo.new(0.15), {BackgroundColor3 = COLORS.AccentPink}):Play()
            TweenService:Create(toggleCircle, TweenInfo.new(0.15), {Position = UDim2.new(1, -16, 0, 2), BackgroundColor3 = Color3.fromRGB(15,15,15)}):Play()
        else
            TweenService:Create(toggleBtn, TweenInfo.new(0.15), {BackgroundColor3 = COLORS.Background}):Play()
            TweenService:Create(toggleCircle, TweenInfo.new(0.15), {Position = UDim2.new(0, 2, 0, 2), BackgroundColor3 = COLORS.TextGray}):Play()
        end
        callback(active)
    end)
end

-- ЗАПОЛНЕНИЕ РАБОЧИХ КАРТОЧЕК (Оригинальные функции)
createToggleCard(visualsCards, "ElytraTarget (ChinaHat)", Config.ChinaHatEnabled, function(state) ToggleChinaHat(state) end)
createToggleCard(visualsCards, "Character Trails (Шлейф)", Config.TrailsEnabled, function(state) ToggleTrails(state) end)
createToggleCard(visualsCards, "JumpCircle (Круги при прыжке)", Config.JumpCircleEnabled, function(state) ToggleJumpCircle(state) end)
createToggleCard(renderCards, "Arrows (Стрелочки на игроков)", Config.ArrowsEnabled, function(state) Config.ArrowsEnabled = state end)

-- Заглушки под Движение, чтобы сетка не была пустой
createToggleCard(movementCards, "SpeedBoost (Ускорение)", false, function() end)
createToggleCard(movementCards, "Flight (Полет)", false, function() end)

-- ПЕРЕКЛЮЧЕНИЕ МОДУЛЕЙ СЛЕВА
local function rebuildModuleList(category)
    for _, child in ipairs(scrollModules:GetChildren()) do
        if child:IsA("TextButton") or child:IsA("TextLabel") then child:Destroy() end
    end
    
    moduleHeader.Text = (category == "Visuals" and "Визуалы") or (category == "Movement" and "Движение") or "Рендер"
    local list = category == "Visuals" and {"ChinaHat", "Trails", "JumpCircle"} or category == "Movement" and {"SpeedBoost", "Flight"} or {"Arrows"}
    
    -- Добавляем красивую заглавную букву подгруппы
    local letterLabel = Instance.new("TextLabel", scrollModules)
    letterLabel.Size = UDim2.new(1, 0, 0, 18)
    letterLabel.Text = "   " .. string.sub(list[1], 1, 1)
    letterLabel.TextColor3 = COLORS.Lines
    letterLabel.TextSize = 10
    letterLabel.Font = Enum.Font.GothamBold
    letterLabel.TextXAlignment = Enum.TextXAlignment.Left
    letterLabel.BackgroundTransparency = 1

    for _, name in ipairs(list) do
        local btn = Instance.new("TextButton", scrollModules)
        btn.Size = UDim2.new(1, 0, 0, 26)
        btn.BackgroundTransparency = 1
        btn.Text = "   " .. name
        btn.TextColor3 = COLORS.TextGray
        btn.TextSize = 12
        btn.Font = Enum.Font.Gotham
        btn.TextXAlignment = Enum.TextXAlignment.Left
    end
end

rebuildModuleList("Visuals")

-- СМЕН
