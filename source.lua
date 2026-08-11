local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local Terrain = workspace:FindFirstChildWhichIsA("Terrain")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

if Terrain then
    Terrain.WaterWaveSize = 0
    Terrain.WaterWaveSpeed = 0
    Terrain.WaterReflectance = 0
    Terrain.WaterTransparency = 1
end

Lighting.GlobalShadows = false
Lighting.FogEnd = 9e9
Lighting.FogStart = 9e9
Lighting.Ambient = Color3.fromRGB(255, 255, 255)
Lighting.Brightness = 2
Lighting.ColorShift_Bottom = Color3.fromRGB(255, 255, 255)
Lighting.ColorShift_Top = Color3.fromRGB(255, 255, 255)
Lighting.EnvironmentDiffuseScale = 1
Lighting.EnvironmentSpecularScale = 0
Lighting.OutdoorAmbient = Color3.fromRGB(255, 255, 255)
Lighting.ClockTime = 12
Lighting.ExposureCompensation = 0.5

settings().Rendering.QualityLevel = 1

for _, v in pairs(game:GetDescendants()) do
    if v:IsA("BasePart") then
        v.CastShadow = false
        v.Material = Enum.Material.Plastic
        v.Reflectance = 0

    elseif v:IsA("Decal") then
        v.Transparency = 1

    elseif v:IsA("ParticleEmitter") or v:IsA("Trail") then
        v.Lifetime = NumberRange.new(0)
    end
end

for _, v in pairs(Lighting:GetDescendants()) do
    if v:IsA("PostEffect") then
        v.Enabled = false
    end
end

workspace.DescendantAdded:Connect(function(child)
    task.spawn(function()
        if child:IsA("Sparkles")
            or child:IsA("Smoke")
            or child:IsA("Fire")
            or child:IsA("Beam") then

            RunService.Heartbeat:Wait()
            child:Destroy()

        elseif child:IsA("BasePart") then
            child.CastShadow = false
        end
    end)
end)

-- ==================== ESP ====================

local playerData = {}

local HIGHLIGHT_TRANSPARENCY = 0.5
local FORCEFIELD_COLOR = Color3.fromRGB(0, 255, 0)

local function getTeamColor(player)
    if player.Team and player.Team.TeamColor then
        return player.Team.TeamColor.Color
    end
    return Color3.fromRGB(128, 128, 128)
end

local function hasForceField(character)
    for _, child in pairs(character:GetChildren()) do
        if child:IsA("ForceField") then
            return true
        end
    end
    return false
end

local function getColorForCharacter(character, player)
    if hasForceField(character) then
        return FORCEFIELD_COLOR
    end
    return getTeamColor(player)
end

local function updateHighlightColor(player)
    local data = playerData[player]
    if not data then return end
    if not data.highlight then return end
    
    local character = player.Character
    if not character then return end
    
    local color = getColorForCharacter(character, player)
    
    data.highlight.OutlineColor = color
    data.highlight.FillColor = color
    
    if data.nametag then
        local nameLabel = data.nametag:FindFirstChild("Name")
        if nameLabel then
            nameLabel.TextColor3 = color
        end
    end
end

local function createNametag(character, player)
    local billboard = Instance.new("BillboardGui")
    billboard.Name = "ESP_Nametag"
    billboard.AlwaysOnTop = true
    billboard.Size = UDim2.new(0, 200, 0, 30)
    billboard.StudsOffset = Vector3.new(0, 1.5, 0)
    billboard.MaxDistance = 9e9
    billboard.Parent = character

    local head = character:FindFirstChild("Head") or character:FindFirstChild("HumanoidRootPart")
    if head then
        billboard.Adornee = head
    end

    local nameLabel = Instance.new("TextLabel")
    nameLabel.Name = "Name"
    nameLabel.Size = UDim2.new(1, 0, 1, 0)
    nameLabel.BackgroundTransparency = 1
    nameLabel.TextColor3 = getColorForCharacter(character, player)
    nameLabel.TextStrokeTransparency = 0.3
    nameLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
    nameLabel.Text = player.Name
    nameLabel.Font = Enum.Font.GothamBold
    nameLabel.TextSize = 14
    nameLabel.Parent = billboard

    return billboard
end

local function cleanupPlayerData(player)
    local data = playerData[player]
    if not data then return end
    
    if data.highlight then data.highlight:Destroy() end
    if data.nametag then data.nametag:Destroy() end
    if data.descendantAddedConn then data.descendantAddedConn:Disconnect() end
    if data.descendantRemovingConn then data.descendantRemovingConn:Disconnect() end
    if data.teamConn then data.teamConn:Disconnect() end
    if data.destroyingConn then data.destroyingConn:Disconnect() end
    
    playerData[player] = nil
end

local function createESP(player, character)
    cleanupPlayerData(player)
    
    local color = getColorForCharacter(character, player)

    local highlight = Instance.new("Highlight")
    highlight.Name = "ESP"
    highlight.FillTransparency = HIGHLIGHT_TRANSPARENCY
    highlight.OutlineTransparency = 0
    highlight.OutlineColor = color
    highlight.FillColor = color
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.Adornee = character
    highlight.Parent = character

    local nametag = createNametag(character, player)

    local descendantAddedConn = character.DescendantAdded:Connect(function(child)
        if child:IsA("ForceField") then
            task.wait()
            updateHighlightColor(player)
        end
    end)

    local descendantRemovingConn = character.DescendantRemoving:Connect(function(child)
        if child:IsA("ForceField") then
            task.wait()
            updateHighlightColor(player)
        end
    end)

    local teamConn = player:GetPropertyChangedSignal("Team"):Connect(function()
        updateHighlightColor(player)
    end)

    local destroyingConn = character.Destroying:Connect(function()
        cleanupPlayerData(player)
    end)

    playerData[player] = {
        highlight = highlight,
        nametag = nametag,
        descendantAddedConn = descendantAddedConn,
        descendantRemovingConn = descendantRemovingConn,
        teamConn = teamConn,
        destroyingConn = destroyingConn,
        character = character
    }
end

local function onPlayerAdded(player)
    if player == LocalPlayer then return end

    local function onCharacterAdded(character)
        task.wait(0.1)
        createESP(player, character)
    end

    player.CharacterAdded:Connect(onCharacterAdded)

    if player.Character then
        onCharacterAdded(player.Character)
    end
end

for _, player in pairs(Players:GetPlayers()) do
    onPlayerAdded(player)
end

Players.PlayerAdded:Connect(onPlayerAdded)

Players.PlayerRemoving:Connect(function(player)
    cleanupPlayerData(player)
end)

-- ==================== AIMBOT ====================

local aimbotEnabled = false
local aimConnection = nil
local currentTarget = nil

local AIM_PART = "Head"
local MAX_DISTANCE = 500

local function isAlive(character)
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    return humanoid and humanoid.Health > 0
end

local function isOnScreen(targetPart)
    local screenPos, onScreen = Camera:WorldToViewportPoint(targetPart.Position)
    if not onScreen then return false end
    
    local screenSize = Camera.ViewportSize
    if screenPos.X < 0 or screenPos.X > screenSize.X then return false end
    if screenPos.Y < 0 or screenPos.Y > screenSize.Y then return false end
    
    return true
end

local function isInRange(targetPart)
    local distance = (targetPart.Position - Camera.CFrame.Position).Magnitude
    return distance <= MAX_DISTANCE
end

local function hasLineOfSight(targetPart, targetCharacter)
    local origin = Camera.CFrame.Position
    local direction = (targetPart.Position - origin)
    local distance = direction.Magnitude
    direction = direction.Unit
    
    local rayParams = RaycastParams.new()
    rayParams.FilterType = Enum.RaycastFilterType.Blacklist
    rayParams.IgnoreWater = true
    
    local ignoreList = {}
    
    if LocalPlayer.Character then
        table.insert(ignoreList, LocalPlayer.Character)
    end
    
    if targetCharacter then
        table.insert(ignoreList, targetCharacter)
    end
    
    rayParams.FilterDescendantsInstances = ignoreList
    
    local rayResult = workspace:Raycast(origin, direction * distance, rayParams)
    
    if rayResult then
        local part = rayResult.Instance
        if part and part.CanCollide then
            return false
        end
    end
    
    return true
end

local function hasGunScript(character)
    for _, child in pairs(character:GetChildren()) do
        if child:IsA("Tool") then
            local gunScript = child:FindFirstChild("GunScript")
            if gunScript and gunScript:IsA("LocalScript") then
                return true
            end
        end
    end
    return false
end

local function isValidTarget(player)
    if not player then return false end
    
    local character = player.Character
    if not character then return false end
    
    if not isAlive(character) then return false end
    
    if hasForceField(character) then return false end
    
    local targetPart = character:FindFirstChild(AIM_PART)
    if not targetPart then return false end
    
    if not isOnScreen(targetPart) then return false end
    
    if not isInRange(targetPart) then return false end
    
    if not hasLineOfSight(targetPart, character) then return false end
    
    return true
end

local function findTarget()
    if not hasGunScript(LocalPlayer.Character or {}) then return nil end
    
    local closestPlayer = nil
    local closestDistance = math.huge
    
    local screenCenter = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    
    for _, player in pairs(Players:GetPlayers()) do
        if player == LocalPlayer then continue end
        
        local character = player.Character
        if not character then continue end
        
        if not isAlive(character) then continue end
        
        if hasForceField(character) then continue end
        
        local targetPart = character:FindFirstChild(AIM_PART)
        if not targetPart then continue end
        
        if not isOnScreen(targetPart) then continue end
        
        if not isInRange(targetPart) then continue end
        
        if not hasLineOfSight(targetPart, character) then continue end
        
        local screenPos = Camera:WorldToViewportPoint(targetPart.Position)
        local distance = (Vector2.new(screenPos.X, screenPos.Y) - screenCenter).Magnitude
        
        if distance < closestDistance then
            closestDistance = distance
            closestPlayer = player
        end
    end
    
    return closestPlayer
end

local function enableAimbot()
    if aimbotEnabled then return end
    aimbotEnabled = true
    
    currentTarget = findTarget()
    
    aimConnection = RunService.RenderStepped:Connect(function()
        if not aimbotEnabled then return end
        
        if not hasGunScript(LocalPlayer.Character or {}) then
            currentTarget = nil
            return
        end
        
        if currentTarget and currentTarget.Character then
            if hasForceField(currentTarget.Character) then
                currentTarget = nil
            end
        end
        
        if not isValidTarget(currentTarget) then
            currentTarget = nil
            currentTarget = findTarget()
        end
        
        if currentTarget and currentTarget.Character then
            local targetPart = currentTarget.Character:FindFirstChild(AIM_PART)
            if targetPart then
                Camera.CFrame = CFrame.lookAt(Camera.CFrame.Position, targetPart.Position)
            end
        end
    end)
end

local function disableAimbot()
    aimbotEnabled = false
    currentTarget = nil
    
    if aimConnection then
        aimConnection:Disconnect()
        aimConnection = nil
    end
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    
    if input.UserInputType == Enum.UserInputType.MouseButton2 then
        enableAimbot()
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton2 then
        disableAimbot()
    end
end)

local TextChatService = game:GetService("TextChatService")

local function chat(msg)
    pcall(function()
        local channel = TextChatService.TextChannels.RBXGeneral
        channel:SendAsync(msg)
    end)
end

task.wait(0.5)
chat("!sts " .. getgenv().AutoGive.Tools)

task.wait(1)
chat("!sta " .. getgenv().AutoGive.Armor)
