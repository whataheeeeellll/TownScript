if game.PlaceId ~= 4991214437 then return end

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
    nameLabel.Text = player.DisplayName
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
local lastValidTarget = nil -- Запоминаем последнюю валидную цель

local AIM_PART = "Head"
local MAX_DISTANCE = 500
local SMOOTHNESS = 0.1
local TARGET_LOST_DELAY = 0.1 -- Задержка перед сбросом цели (в секундах)
local targetLostTimer = 0

local function isAlive(character)
    if not character then return false end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    -- Дополнительная проверка: персонаж должен существовать и иметь health > 0
    if not humanoid or humanoid.Health <= 0 then return false end
    -- Проверяем, не разваливается ли персонаж
    if humanoid:GetState() == Enum.HumanoidStateType.Dead then return false end
    return true
end

local function isCharacterValid(character)
    if not character then return false end
    if not character.Parent then return false end -- Проверяем, не удалён ли персонаж
    if not character:FindFirstChild(AIM_PART) then return false end -- Проверяем, есть ли целевая часть
    return true
end

local function isOnScreen(targetPart)
    if not targetPart or not targetPart.Parent then return false end
    local screenPos, onScreen = Camera:WorldToViewportPoint(targetPart.Position)
    if not onScreen then return false end
    
    local screenSize = Camera.ViewportSize
    if screenPos.X < 0 or screenPos.X > screenSize.X then return false end
    if screenPos.Y < 0 or screenPos.Y > screenSize.Y then return false end
    
    return true
end

local function isInRange(targetPart)
    if not targetPart then return false end
    local distance = (targetPart.Position - Camera.CFrame.Position).Magnitude
    return distance <= MAX_DISTANCE
end

local function hasLineOfSight(targetPart, targetCharacter)
    if not targetPart or not targetPart.Parent then return false end
    
    local origin = Camera.CFrame.Position
    local targetPos = targetPart.Position
    local direction = (targetPos - origin)
    local distance = direction.Magnitude
    direction = direction.Unit
    
    local rayParams = RaycastParams.new()
    rayParams.FilterType = Enum.RaycastFilterType.Blacklist
    rayParams.IgnoreWater = true
    
    local ignoreList = {}
    
    if LocalPlayer.Character then
        table.insert(ignoreList, LocalPlayer.Character)
    end
    
    if targetCharacter and targetCharacter.Parent then
        table.insert(ignoreList, targetCharacter)
    end
    
    rayParams.FilterDescendantsInstances = ignoreList
    
    local currentPos = origin
    local remainingDist = distance
    local maxIterations = 100
    local iterations = 0
    
    while remainingDist > 0.01 and iterations < maxIterations do
        iterations = iterations + 1
        
        local rayResult = workspace:Raycast(currentPos, direction * remainingDist, rayParams)
        
        if not rayResult then
            return true -- Ничего не встретили, путь свободен
        end
        
        local hitPart = rayResult.Instance
        local hitPos = rayResult.Position
        
        -- Попали в цель
        if hitPart:IsDescendantOf(targetCharacter) then
            return true
        end
        
        -- Любая часть с коллизией блокирует обзор
        if hitPart.CanCollide then
            return false
        end
        
        -- Часть без коллизии — пропускаем и идём дальше
        local hitDist = (hitPos - currentPos).Magnitude
        currentPos = hitPos + direction * 0.01
        remainingDist = remainingDist - hitDist - 0.01
    end
    
    return true
end

local function hasGunScript(character)
    if not character or not character.Parent then return false end
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
    if not isCharacterValid(character) then return false end
    if not isAlive(character) then return false end
    if hasForceField(character) then return false end
    
    local targetPart = character:FindFirstChild(AIM_PART)
    if not targetPart or not targetPart.Parent then return false end
    
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
        if not isCharacterValid(character) then continue end
        if not isAlive(character) then continue end
        if hasForceField(character) then continue end
        
        local targetPart = character:FindFirstChild(AIM_PART)
        if not targetPart or not targetPart.Parent then continue end
        
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

-- Подключаем отслеживание смерти игроков
local function onHumanoidDied(player)
    if currentTarget == player then
        -- Если текущая цель умерла, сразу сбрасываем её
        currentTarget = nil
        lastValidTarget = nil
        targetLostTimer = 0
    end
end

-- Отслеживаем смерти всех игроков
for _, player in pairs(Players:GetPlayers()) do
    if player ~= LocalPlayer then
        local function onCharacterAdded(character)
            local humanoid = character:WaitForChild("Humanoid", 5)
            if humanoid then
                humanoid.Died:Connect(function()
                    onHumanoidDied(player)
                end)
            end
        end
        
        player.CharacterAdded:Connect(onCharacterAdded)
        if player.Character then
            onCharacterAdded(player.Character)
        end
    end
end

Players.PlayerAdded:Connect(function(player)
    if player == LocalPlayer then return end
    player.CharacterAdded:Connect(function(character)
        local humanoid = character:WaitForChild("Humanoid", 5)
        if humanoid then
            humanoid.Died:Connect(function()
                onHumanoidDied(player)
            end)
        end
    end)
end)

local function enableAimbot()
    if aimbotEnabled then return end
    aimbotEnabled = true
    targetLostTimer = 0
    
    currentTarget = findTarget()
    lastValidTarget = currentTarget
    
    aimConnection = RunService.RenderStepped:Connect(function(deltaTime)
        if not aimbotEnabled then return end
        
        if not hasGunScript(LocalPlayer.Character or {}) then
            currentTarget = nil
            lastValidTarget = nil
            return
        end
        
        -- Проверяем валидность текущей цели
        if currentTarget then
            if not isValidTarget(currentTarget) then
                -- Если цель стала невалидной, сразу сбрасываем
                currentTarget = nil
                lastValidTarget = nil
                targetLostTimer = 0
            end
        end
        
        -- Если нет текущей цели, ищем новую
        if not currentTarget then
            currentTarget = findTarget()
            if currentTarget then
                lastValidTarget = currentTarget
            end
        end
        
        -- Аимимся только если есть валидная цель
        if currentTarget and currentTarget.Character then
            local targetPart = currentTarget.Character:FindFirstChild(AIM_PART)
            if targetPart and targetPart.Parent then
                -- Дополнительная проверка: убеждаемся, что персонаж всё ещё жив
                if isAlive(currentTarget.Character) then
                    local targetCFrame = CFrame.lookAt(Camera.CFrame.Position, targetPart.Position)
                    Camera.CFrame = Camera.CFrame:Lerp(targetCFrame, SMOOTHNESS)
                else
                    currentTarget = nil
                    lastValidTarget = nil
                end
            else
                currentTarget = nil
                lastValidTarget = nil
            end
        end
    end)
end

local function disableAimbot()
    aimbotEnabled = false
    currentTarget = nil
    lastValidTarget = nil
    targetLostTimer = 0
    
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
