local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer
local Config = shared.Rockstar.Config

if shared.HatConnection then shared.HatConnection:Disconnect() end
local ActiveHat = nil

local function createHat(char)
    if ActiveHat then ActiveHat:Destroy() end
    local head = char:WaitForChild("Head", 5)
    if not head then return end
    
    local hat = Instance.new("Part")
    hat.Size = Vector3.new(2, 0.5, 2)
    hat.Massless = true
    hat.CanCollide = false
    hat.Material = Enum.Material.ForceField
    hat.Color = Config.AccentColor
    
    local mesh = Instance.new("SpecialMesh", hat)
    mesh.MeshType = Enum.MeshType.FileMesh
    mesh.MeshId = "rbxassetid://1033714"
    mesh.Scale = Config.ChinaHatScale
    
    local weld = Instance.new("Weld", hat)
    weld.Part0 = head
    weld.Part1 = hat
    weld.C0 = CFrame.new(0, 0.85, 0)
    
    hat.Parent = char
    ActiveHat = hat
end

shared.HatConnection = RunService.RenderStepped:Connect(function()
    if not Config.ChinaHatEnabled then
        if ActiveHat then ActiveHat:Destroy() ActiveHat = nil end
        return
    end
    
    local char = player.Character
    if char and not ActiveHat then
        createHat(char)
    elseif ActiveHat then
        local shift = math.sin(tick() * Config.ColorShiftSpeed) * 0.08
        local h, s, v = Config.AccentColor:ToHSV()
        ActiveHat.Color = Color3.fromHSV((h + shift) % 1, s, v)
    end
end)
