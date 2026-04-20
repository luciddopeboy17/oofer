-- Wait for player to load
local PlayerService = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local player = PlayerService.LocalPlayer
if not player then
    player = PlayerService.PlayerAdded:Wait()
end

-- Wait for player GUI to be ready
player:WaitForChild("PlayerGui")

-- Create ScreenGui
local screenGui = Instance.new("ScreenGui")
screenGui.Parent = player.PlayerGui
screenGui.ResetOnSpawn = false
screenGui.Name = "GuiVersion_SmoothArc_V2"

-- Create Main Frame
local frame = Instance.new("Frame")
frame.Parent = screenGui
frame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
frame.Size = UDim2.new(0, 200, 0, 140)
frame.Position = UDim2.new(0.3, 0, 0.5, -70)
frame.Active = true
frame.BorderSizePixel = 0

-- UI Corners
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 8)
corner.Parent = frame

-- ==============================================================================
-- UI HELPER FUNCTIONS
-- ==============================================================================

local function makeDraggable(guiObject)
    local dragging, dragInput, dragStart, startPos
    guiObject.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = guiObject.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    guiObject.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            local delta = input.Position - dragStart
            guiObject.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
end

makeDraggable(frame)

local function createSafeButton(parent, position, size, text, defaultColor)
    local container = Instance.new("Frame")
    container.Parent = parent
    container.Position = position
    container.Size = size
    container.BackgroundColor3 = defaultColor
    container.BorderSizePixel = 0
    
    local uic = Instance.new("UICorner")
    uic.CornerRadius = UDim.new(0, 4)
    uic.Parent = container

    local label = Instance.new("TextLabel")
    label.Parent = container
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = Color3.fromRGB(255, 255, 255)
    label.TextScaled = true
    label.Font = Enum.Font.GothamBold
    
    local button = Instance.new("TextButton")
    button.Parent = container
    button.Size = UDim2.new(1, 0, 1, 0)
    button.BackgroundTransparency = 1
    button.Text = ""
    button.ZIndex = 10
    
    return container, button, label
end

-- Create Buttons
local powerFrame, powerBtn, powerLabel = createSafeButton(frame, UDim2.new(0, 10, 0, 10), UDim2.new(0, 180, 0, 35), "Power: OFF", Color3.fromRGB(200, 50, 50))
local circleFrame, circleBtn, circleLabel = createSafeButton(frame, UDim2.new(0, 10, 0, 50), UDim2.new(0, 180, 0, 35), "Mode: DYNAMIC ARC", Color3.fromRGB(80, 80, 80))
local destroyFrame, destroyBtn = createSafeButton(frame, UDim2.new(0, 10, 0, 95), UDim2.new(0, 180, 0, 35), "Remove Script", Color3.fromRGB(50, 50, 50))

-- Status Label
local statusLabel = Instance.new("TextLabel")
statusLabel.Parent = frame
statusLabel.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
statusLabel.Size = UDim2.new(1, 0, 0, 25)
statusLabel.Position = UDim2.new(0, 0, 1, 0)
statusLabel.Text = "Status: Idle"
statusLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
statusLabel.TextScaled = true
local statusCorner = Instance.new("UICorner")
statusCorner.CornerRadius = UDim.new(0, 4)
statusCorner.Parent = statusLabel

-- Help Label (Keybind Info)
local helpLabel = Instance.new("TextLabel")
helpLabel.Parent = frame
helpLabel.Size = UDim2.new(1, 0, 0, 15)
helpLabel.Position = UDim2.new(0, 0, 0, -15)
helpLabel.BackgroundTransparency = 1
helpLabel.Text = "Press [Right Ctrl] to Toggle Menu"
helpLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
helpLabel.TextSize = 10
helpLabel.Font = Enum.Font.SourceSansItalic

-- ==============================================================================
-- DYNAMIC ARC LOGIC
-- ==============================================================================

local HOOPS = {
    Home = Vector3.new(146.76, 17.33, -297.95),
    Away = Vector3.new(-146.53, 15.97, -297.43)
}

-- CONFIGURATION
local basketballName = "Basketball"
local minShotTime = 0.8 -- Shortest flight time (for layups)
local timePerStud = 0.008 -- How much time to add per stud of distance (adjust for "higher" arcs)

-- State
local isSystemActive = false
local isCircleMode = false
local activeConnections = {}

local function findBasketball()
    local ball = workspace:FindFirstChild(basketballName)
    if ball and ball:IsA("BasePart") then return ball end
    for _, tool in ipairs(workspace:GetChildren()) do
        if tool:IsA("Tool") and tool.Name == basketballName then
            local handle = tool:FindFirstChild("Handle")
            if handle and handle:IsA("BasePart") then return handle end
        end
    end
    return nil
end

local function getEnemyHoop()
    local myTeamName = player.Team and player.Team.Name or "Neutral"
    if myTeamName == "Home" then return HOOPS.Away else return HOOPS.Home end
end

-- Physics calculation for a smooth arc
local function calculateArcVelocity(startPos, endPos, t)
    local gravity = workspace.Gravity
    local displacement = endPos - startPos
    
    local velocityY = (displacement.Y + 0.5 * gravity * t * t) / t
    local velocityXZ = Vector3.new(displacement.X, 0, displacement.Z) / t
    
    return Vector3.new(velocityXZ.X, velocityY, velocityXZ.Z)
end

local function handleBall()
    if not isSystemActive then return end
    
    local ball = findBasketball()
    if not ball then
        statusLabel.Text = "Status: Searching for Ball..."
        return
    end

    local char = player.Character
    if char and char:FindFirstChild("HumanoidRootPart") then
        local distToPlayer = (ball.Position - char.HumanoidRootPart.Position).Magnitude
        
        -- Trigger shot when ball is within reach
        if distToPlayer < 15 then
            local target = getEnemyHoop() + Vector3.new(0, 2.5, 0) -- Aim slightly higher for swish
            
            -- DYNAMIC ARCH CALCULATION
            local horizontalDist = (Vector3.new(target.X, 0, target.Z) - Vector3.new(ball.Position.X, 0, ball.Position.Z)).Magnitude
            local dynamicShotTime = minShotTime + (horizontalDist * timePerStud)
            
            statusLabel.Text = "Status: Shot Taken (Dist: " .. math.floor(horizontalDist) .. ")"
            statusLabel.TextColor3 = Color3.fromRGB(255, 200, 0)
            
            -- Set physics properties
            ball.Velocity = calculateArcVelocity(ball.Position, target, dynamicShotTime)
            ball.RotVelocity = Vector3.new(15, 0, 0) -- Add some backspin
            
            -- Debounce
            task.wait(dynamicShotTime * 0.9) 
        end
    end
end

-- ==============================================================================
-- HANDLERS
-- ==============================================================================

local function togglePower()
    isSystemActive = not isSystemActive
    powerLabel.Text = isSystemActive and "Power: ON" or "Power: OFF"
    powerFrame.BackgroundColor3 = isSystemActive and Color3.fromRGB(50, 200, 50) or Color3.fromRGB(200, 50, 50)
    
    if isSystemActive then
        local conn = RunService.Heartbeat:Connect(handleBall)
        table.insert(activeConnections, conn)
    else
        for _, c in ipairs(activeConnections) do c:Disconnect() end
        activeConnections = {}
        statusLabel.Text = "Status: Offline"
    end
end

-- Keybind Toggle for GUI Visibility
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end -- Ignore if typing in chat
    if input.KeyCode == Enum.KeyCode.RightControl then
        frame.Visible = not frame.Visible
    end
end)

powerBtn.MouseButton1Click:Connect(togglePower)

destroyBtn.MouseButton1Click:Connect(function()
    if isSystemActive then togglePower() end
    screenGui:Destroy()
end)

circleBtn.MouseButton1Click:Connect(function()
    isCircleMode = not isCircleMode
    circleLabel.Text = isCircleMode and "Mode: RANDOM" or "Mode: DYNAMIC ARC"
end)
