--[[
    LUMINA UNIVERSAL ESP (V5 - STABILITY UPDATE)
    Upgrades: 
    - Minimize/Maximize Toggle (Compact Mode)
    - Dynamic Keybind System (Change toggle key in-game)
    - Death Sync Logic (Fixes ESP breaking after respawn)
    - Auto-Cleanup (Removes stale drawings automatically)
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

-- Configuration
local Settings = {
    Enabled = true,
    BoxColor = Color3.fromRGB(0, 255, 150),
    EntityColor = Color3.fromRGB(255, 100, 0),
    SkeletonColor = Color3.fromRGB(255, 255, 255),
    TextSize = 13,
    Thickness = 1.5,
    ScanInterval = 2,
    MaxDistance = 2500,
    ToggleKey = Enum.KeyCode.F -- Default Keybind
}

local SkeletonMesh = {
    {"Head", "UpperTorso"}, {"UpperTorso", "LowerTorso"},
    {"UpperTorso", "LeftUpperArm"}, {"LeftUpperArm", "LeftLowerArm"}, {"LeftLowerArm", "LeftHand"},
    {"UpperTorso", "RightUpperArm"}, {"RightUpperArm", "RightLowerArm"}, {"RightLowerArm", "RightHand"},
    {"LowerTorso", "LeftUpperLeg"}, {"LeftUpperLeg", "LeftLowerLeg"}, {"LeftLowerLeg", "LeftFoot"},
    {"LowerTorso", "RightUpperLeg"}, {"RightUpperLeg", "RightLowerLeg"}, {"RightLowerLeg", "RightFoot"}
}

local ESP_Cache = {}
local EntityList = {}
local LastScan = 0
local IsMinimized = false
local IsBinding = false

-- UI Setup
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "LuminaESP_V5"
ScreenGui.Parent = CoreGui
ScreenGui.ResetOnSpawn = false

local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 210, 0, 190)
MainFrame.Position = UDim2.new(0.1, 0, 0.1, 0)
MainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Parent = ScreenGui

local UICorner = Instance.new("UICorner")
UICorner.CornerRadius = UDim.new(0, 8)
UICorner.Parent = MainFrame

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, -40, 0, 35)
Title.Position = UDim2.new(0, 10, 0, 0)
Title.BackgroundTransparency = 1
Title.Text = "LUMINA ESP V5"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.Font = Enum.Font.GothamBold
Title.TextSize = 14
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = MainFrame

-- Minimize Button
local MinBtn = Instance.new("TextButton")
MinBtn.Size = UDim2.new(0, 30, 0, 30)
MinBtn.Position = UDim2.new(1, -35, 0, 2)
MinBtn.BackgroundTransparency = 1
MinBtn.Text = "-"
MinBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
MinBtn.Font = Enum.Font.GothamBold
MinBtn.TextSize = 20
MinBtn.Parent = MainFrame

local ContentFrame = Instance.new("Frame")
ContentFrame.Size = UDim2.new(1, 0, 1, -40)
ContentFrame.Position = UDim2.new(0, 0, 0, 40)
ContentFrame.BackgroundTransparency = 1
ContentFrame.Parent = MainFrame

local ToggleBtn = Instance.new("TextButton")
ToggleBtn.Size = UDim2.new(0.9, 0, 0, 35)
ToggleBtn.Position = UDim2.new(0.05, 0, 0.05, 0)
ToggleBtn.BackgroundColor3 = Color3.fromRGB(0, 180, 100)
ToggleBtn.Text = "ESP: ON"
ToggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
ToggleBtn.Font = Enum.Font.Gotham
ToggleBtn.Parent = ContentFrame
Instance.new("UICorner", ToggleBtn).CornerRadius = UDim.new(0, 6)

local BindBtn = Instance.new("TextButton")
BindBtn.Size = UDim2.new(0.9, 0, 0, 35)
BindBtn.Position = UDim2.new(0.05, 0, 0.35, 0)
BindBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
BindBtn.Text = "Bind: " .. Settings.ToggleKey.Name
BindBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
BindBtn.Font = Enum.Font.Gotham
BindBtn.Parent = ContentFrame
Instance.new("UICorner", BindBtn).CornerRadius = UDim.new(0, 6)

local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0.9, 0, 0, 35)
CloseBtn.Position = UDim2.new(0.05, 0, 0.65, 0)
CloseBtn.BackgroundColor3 = Color3.fromRGB(150, 40, 40)
CloseBtn.Text = "Destroy Script"
CloseBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
CloseBtn.Font = Enum.Font.Gotham
CloseBtn.Parent = ContentFrame
Instance.new("UICorner", CloseBtn).CornerRadius = UDim.new(0, 6)

-- Logic Functions
local function CreateDrawing(class, properties)
    local draw = Drawing.new(class)
    for i, v in pairs(properties) do draw[i] = v end
    return draw
end

local function ClearAllDrawings()
    for obj, components in pairs(ESP_Cache) do
        components.Box.Visible = false
        components.Label.Visible = false
        for _, line in pairs(components.Skeleton) do line.Visible = false end
    end
end

local function RemoveESP(obj)
    if ESP_Cache[obj] then
        local comp = ESP_Cache[obj]
        comp.Box:Remove()
        comp.Label:Remove()
        for _, line in pairs(comp.Skeleton) do line:Remove() end
        ESP_Cache[obj] = nil
    end
end

local function AddESP(obj)
    if obj == LocalPlayer.Character or ESP_Cache[obj] then return end
    local color = Players:GetPlayerFromCharacter(obj) and Settings.BoxColor or Settings.EntityColor
    
    local components = {
        Box = CreateDrawing("Square", {Thickness = Settings.Thickness, Color = color, Filled = false, Visible = false}),
        Label = CreateDrawing("Text", {Size = Settings.TextSize, Color = Color3.new(1, 1, 1), Outline = true, Center = true, Visible = false}),
        Skeleton = {}
    }
    for i = 1, #SkeletonMesh do
        table.insert(components.Skeleton, CreateDrawing("Line", {Thickness = 1, Color = Settings.SkeletonColor, Visible = false}))
    end
    ESP_Cache[obj] = components
end

local function GetEntities()
    local targets = {}
    for _, p in pairs(Players:GetPlayers()) do
        if p.Character and p.Character:FindFirstChild("HumanoidRootPart") then table.insert(targets, p.Character) end
    end
    for _, v in pairs(workspace:GetDescendants()) do
        if v:IsA("Model") and v:FindFirstChild("Humanoid") and v:FindFirstChild("HumanoidRootPart") then
            if not Players:GetPlayerFromCharacter(v) and v ~= LocalPlayer.Character then table.insert(targets, v) end
        end
    end
    return targets
end

-- Update Loop
local Connection
Connection = RunService.RenderStepped:Connect(function()
    if not Settings.Enabled then
        ClearAllDrawings()
        return
    end

    if tick() - LastScan > Settings.ScanInterval then
        LastScan = tick()
        EntityList = GetEntities()
        -- Sync Check: Remove drawings for things that no longer exist
        for obj, _ in pairs(ESP_Cache) do
            if not obj or not obj.Parent or not obj:FindFirstChild("HumanoidRootPart") then
                RemoveESP(obj)
            end
        end
    end

    for _, ent in pairs(EntityList) do
        if not ent or not ent.Parent then continue end
        if not ESP_Cache[ent] then AddESP(ent) end
        
        local components = ESP_Cache[ent]
        local root = ent:FindFirstChild("HumanoidRootPart")
        local hum = ent:FindFirstChild("Humanoid")
        
        if root and hum and hum.Health > 0 then
            local pos, onScreen = Camera:WorldToViewportPoint(root.Position)
            local dist = (Camera.CFrame.Position - root.Position).Magnitude

            if onScreen and dist < Settings.MaxDistance then
                local headPos = Camera:WorldToViewportPoint(root.Position + Vector3.new(0, 2.5, 0))
                local legPos = Camera:WorldToViewportPoint(root.Position - Vector3.new(0, 3, 0))
                local sizeY = math.abs(headPos.Y - legPos.Y)
                local sizeX = sizeY / 1.5

                components.Box.Size = Vector2.new(sizeX, sizeY)
                components.Box.Position = Vector2.new(pos.X - sizeX / 2, pos.Y - sizeY / 2)
                components.Box.Visible = true

                components.Label.Text = string.format("%s [%d]", ent.Name, math.floor(hum.Health))
                components.Label.Position = Vector2.new(pos.X, pos.Y + (sizeY / 2) + 2)
                components.Label.Visible = true

                for i, bone in pairs(SkeletonMesh) do
                    local pA, pB = ent:FindFirstChild(bone[1]), ent:FindFirstChild(bone[2])
                    local line = components.Skeleton[i]
                    if pA and pB then
                        local posA, visA = Camera:WorldToViewportPoint(pA.Position)
                        local posB, visB = Camera:WorldToViewportPoint(pB.Position)
                        if visA and visB then
                            line.From = Vector2.new(posA.X, posA.Y)
                            line.To = Vector2.new(posB.X, posB.Y)
                            line.Visible = true
                        else line.Visible = false end
                    else line.Visible = false end
                end
            else
                components.Box.Visible = false
                components.Label.Visible = false
                for _, l in pairs(components.Skeleton) do l.Visible = false end
            end
        else
            if ESP_Cache[ent] then
                ESP_Cache[ent].Box.Visible = false
                ESP_Cache[ent].Label.Visible = false
                for _, l in pairs(ESP_Cache[ent].Skeleton) do l.Visible = false end
            end
        end
    end
end)

-- UI Button Events
ToggleBtn.MouseButton1Click:Connect(function()
    Settings.Enabled = not Settings.Enabled
    ToggleBtn.Text = Settings.Enabled and "ESP: ON" or "ESP: OFF"
    ToggleBtn.BackgroundColor3 = Settings.Enabled and Color3.fromRGB(0, 180, 100) or Color3.fromRGB(180, 100, 0)
    if not Settings.Enabled then ClearAllDrawings() end
end)

MinBtn.MouseButton1Click:Connect(function()
    IsMinimized = not IsMinimized
    ContentFrame.Visible = not IsMinimized
    MainFrame.Size = IsMinimized and UDim2.new(0, 210, 0, 35) or UDim2.new(0, 210, 0, 190)
    MinBtn.Text = IsMinimized and "+" or "-"
end)

BindBtn.MouseButton1Click:Connect(function()
    IsBinding = true
    BindBtn.Text = "Press any key..."
    BindBtn.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
end)

UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    if IsBinding and input.UserInputType == Enum.UserInputType.Keyboard then
        Settings.ToggleKey = input.KeyCode
        BindBtn.Text = "Bind: " .. input.KeyCode.Name
        BindBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
        IsBinding = false
    elseif input.KeyCode == Settings.ToggleKey and not IsBinding then
        Settings.Enabled = not Settings.Enabled
        ToggleBtn.Text = Settings.Enabled and "ESP: ON" or "ESP: OFF"
        ToggleBtn.BackgroundColor3 = Settings.Enabled and Color3.fromRGB(0, 180, 100) or Color3.fromRGB(180, 100, 0)
        if not Settings.Enabled then ClearAllDrawings() end
    end
end)

CloseBtn.MouseButton1Click:Connect(function()
    Connection:Disconnect()
    for obj, _ in pairs(ESP_Cache) do RemoveESP(obj) end
    ScreenGui:Destroy()
end)

-- Respawn Sync: Re-scan when player dies/respawns
LocalPlayer.CharacterAdded:Connect(function()
    task.wait(1) -- Wait for character to fully load
    ClearAllDrawings()
    EntityList = GetEntities()
end)

-- Draggable UI
local dragging, dragInput, dragStart, startPos
MainFrame.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = true
        dragStart = input.Position
        startPos = MainFrame.Position
    end
end)
MainFrame.InputChanged:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseMovement then dragInput = input end end)
UserInputService.InputChanged:Connect(function(input)
    if input == dragInput and dragging then
        local delta = input.Position - dragStart
        MainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)
UserInputService.InputEnded:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end end)
