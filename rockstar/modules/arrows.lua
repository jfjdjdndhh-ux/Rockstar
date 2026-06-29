local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local camera = workspace.CurrentCamera
local player = Players.LocalPlayer

local Config = shared.Rockstar.Config

if shared.ArrowsConnection then shared.ArrowsConnection:Disconnect() end
if game:GetService("CoreGui"):FindFirstChild("RockstarRadar") then game:GetService("CoreGui").RockstarRadar:Destroy() end

local radarGui = Instance.new("ScreenGui", game:GetService("CoreGui"))
radarGui.Name = "RockstarRadar"

local ArrowElements = {}

shared.ArrowsConnection = RunService.RenderStepped:Connect(function()
    if not Config.ArrowsEnabled then
        for _, arrow in pairs(ArrowElements) do arrow:Destroy() end
        ArrowElements = {}
        return
    end
    
    local center = camera.ViewportSize / 2
    
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= player and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
            local root = p.Character.HumanoidRootPart
            local pos, onScreen = camera:WorldToViewportPoint(root.Position)
            local arrow = ArrowElements[p.Name]
            
            if not arrow then
                arrow = Instance.new("ImageLabel", radarGui)
                arrow.Size = UDim2.new(0, Config.ArrowsSize, 0, Config.ArrowsSize)
                arrow.AnchorPoint = Vector2.new(0.5, 0.5)
                arrow.BackgroundTransparency = 1
                arrow.Image = "rbxassetid://7072706663" 
                arrow.ImageColor3 = Config.AccentColor
                ArrowElements[p.Name] = arrow
            end
            
            local dir = Vector2.new(pos.X - center.X, pos.Y - center.Y)
            if pos.Z < 0 then dir = -dir end
            local angle = math.atan2(dir.Y, dir.X)
            
            if onScreen and dir.Magnitude < Config.ArrowsRadius then
                arrow.Visible = false
            else
                arrow.Visible = true
                arrow.Size = UDim2.new(0, Config.ArrowsSize, 0, Config.ArrowsSize)
                arrow.Position = UDim2.new(0, center.X + math.cos(angle) * Config.ArrowsRadius, 0, center.Y + math.sin(angle) * Config.ArrowsRadius)
                arrow.Rotation = math.deg(angle) + 90
            end
        else
            if ArrowElements[p.Name] then ArrowElements[p.Name]:Destroy() ArrowElements[p.Name] = nil end
        end
    end
end)
