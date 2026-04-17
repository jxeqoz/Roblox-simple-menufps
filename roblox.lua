local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Teams = game:GetService("Teams")

local LocalPlayer = Players.LocalPlayer
local camera = workspace.CurrentCamera

local mousemoverel = mousemoverel or (Input and Input.MouseMove) or nil

local Config = {
    ESP_Enabled = true,
    ESP_Box = true,
    ESP_Name = true,
    ESP_Distance = true,
    ESP_Tracer = true,
    ESP_Rainbow = false,
    ESP_TeamCheck = true,
    ESP_Bots = true,

    AIM_Enabled = true,
    AIM_FOVEnabled = true,
    AIM_FOV = 120,
    AIM_Smooth = 3.5,
    AIM_HoldKey = {isMouse = true, code = Enum.UserInputType.MouseButton2, display = "RMB"},

    RADAR_Enabled = false,
    RADAR_Size = 140,
    RADAR_Range = 200,

    MISC_Watermark = true,
    MISC_ActiveList = false,
    MISC_InfAmmo = false
}

local Tuning = {
    PanelWidth = 145,
    PanelHeaderH = 24,
    ItemHeight = 20,
    FontSize = 13,
    SliderHeight = 38,
    RadarDotSize = 6
}

local Palette = {
    PanelBg = Color3.fromRGB(18, 18, 20),
    PanelHeader = Color3.fromRGB(25, 25, 28),
    PanelBorder = Color3.fromRGB(45, 45, 50),
    ItemOn = Color3.fromRGB(255, 65, 65),
    ItemOff = Color3.fromRGB(180, 180, 185),
    ItemHover = Color3.fromRGB(35, 35, 40),
    Text = Color3.fromRGB(230, 230, 235),
    TextDim = Color3.fromRGB(130, 130, 140),
    Accent = Color3.fromRGB(255, 65, 65),

    ESP_Enemy = Color3.fromRGB(255, 65, 65),
    ESP_Visible = Color3.fromRGB(85, 255, 127),

    FOV_Circle = Color3.fromRGB(255, 255, 255),
    FOV_Active = Color3.fromRGB(85, 255, 127),

    RadarBg = Color3.fromRGB(12, 12, 14),
    RadarBorder = Color3.fromRGB(255, 65, 65),
    RadarGrid = Color3.fromRGB(35, 35, 40),
    RadarYou = Color3.fromRGB(255, 65, 65),
    RadarEnemy = Color3.fromRGB(85, 255, 127)
}

local State = {
    Unloaded = false,
    RainbowHue = 0,
    Aiming = false,
    MenuOpen = true,
    Rebinding = false
}

local Cache = {
    Teams = {},
    TeamUpdateTime = 0,
    Visibility = {},
    VisUpdateTime = 0,
    CharactersFolder = nil,
    CharactersFolderTime = 0,
    LocalChar = nil,
    LocalCharTime = 0
}

local CacheIntervals = {
    Team = 0.5,
    Visibility = 0.1,
    LocalChar = 0.2,
    CharactersFolder = 1.0
}

local Connections = {}
local espObjects = {}
local radarDots = {}
local targetEnemy = nil

local ammoHooks = {}
local AMMO_NAMES = {
    "Ammo", "ammo",
    "CurrentAmmo", "currentAmmo",
    "Bullets", "bullets",
    "Magazine", "magazine",
    "MagAmmo", "magAmmo",
    "Clip", "clip",
    "AmmoInClip", "ammoInClip",
    "LoadedAmmo", "StoredAmmo",
    "BulletsLeft", "ShotsLeft",
    "ammoCount", "AmmoCount",
}

local UI = {}
UI.ScreenGui = Instance.new("ScreenGui")
UI.ScreenGui.Name = "RiotfallXeno"
UI.ScreenGui.ResetOnSpawn = false
UI.ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
UI.ScreenGui.DisplayOrder = 999
UI.ScreenGui.IgnoreGuiInset = true

pcall(function() UI.ScreenGui.Parent = game:GetService("CoreGui") end)
if not UI.ScreenGui.Parent then
    UI.ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
end

UI.ESPFolder = Instance.new("Folder")
UI.ESPFolder.Name = "ESP"
UI.ESPFolder.Parent = UI.ScreenGui

local function GetPlayerTeamRaw(player)
    if not player then return nil end
    if workspace:FindFirstChild("VoiceOrigins") then
        local vo = workspace.VoiceOrigins
        if vo:FindFirstChild("ORANGE") and vo.ORANGE:FindFirstChild(player.Name) then
            return Teams:FindFirstChild("ORANGE") or "ORANGE"
        elseif vo:FindFirstChild("BLUE") and vo.BLUE:FindFirstChild(player.Name) then
            return Teams:FindFirstChild("BLUE") or "BLUE"
        end
    end
    return nil
end

local function GetPlayerTeam(player)
    if not player then return nil end
    local now = tick()
    if now - Cache.TeamUpdateTime > CacheIntervals.Team then
        Cache.Teams = {}
        Cache.TeamUpdateTime = now
    end
    if Cache.Teams[player] == nil then
        Cache.Teams[player] = GetPlayerTeamRaw(player) or false
    end
    local result = Cache.Teams[player]
    return result ~= false and result or nil
end

local function GetCharactersFolder()
    local now = tick()
    if not Cache.CharactersFolder or not Cache.CharactersFolder.Parent
        or (now - Cache.CharactersFolderTime > CacheIntervals.CharactersFolder) then
        Cache.CharactersFolder = workspace:FindFirstChild("Characters")
        Cache.CharactersFolderTime = now
    end
    return Cache.CharactersFolder
end

local function GetBotModels()
    local playerNames = {}
    playerNames[LocalPlayer.Name] = true
    for _, p in ipairs(Players:GetPlayers()) do
        playerNames[p.Name] = true
    end

    local bots = {}

    local charsFolder = GetCharactersFolder()
    if charsFolder then
        for _, child in ipairs(charsFolder:GetChildren()) do
            if child:IsA("Model") and not playerNames[child.Name] then
                table.insert(bots, child)
            end
        end
    end

    for _, child in ipairs(workspace:GetChildren()) do
        if child:IsA("Model") and not playerNames[child.Name]
            and child ~= charsFolder
            and child.Name ~= "Camera"
            and child.Name ~= "Terrain" then
            local hasBotHumanoid = child:FindFirstChildOfClass("Humanoid")
            if hasBotHumanoid then
                table.insert(bots, child)
            end
        end
    end

    return bots
end

local function GetLocalCharacter()
    local now = tick()
    if now - Cache.LocalCharTime > CacheIntervals.LocalChar or not Cache.LocalChar or not Cache.LocalChar.Parent then
        local chars = GetCharactersFolder()
        Cache.LocalChar = chars and chars:FindFirstChild(LocalPlayer.Name)
        Cache.LocalCharTime = now
    end
    return Cache.LocalChar
end

local function GetTargetPart(character)
    local parts = {"head_only", "Head", "RootPart", "HumanoidRootPart", "helmet", "pelvis"}
    for _, name in ipairs(parts) do
        local part = character:FindFirstChild(name)
        if part then return part end
    end
    for _, part in ipairs(character:GetChildren()) do
        if part:IsA("BasePart") then return part end
    end
    return nil
end

local function IsVisibleRaw(targetPart)
    local localChar = GetLocalCharacter()
    if not localChar or not targetPart then return false end
    local localPart = GetTargetPart(localChar)
    if not localPart then return false end

    local targetChar = targetPart:FindFirstAncestorOfClass("Model")

    local origin = localPart.Position
    local direction = (targetPart.Position - origin)
    local params = RaycastParams.new()
    params.FilterDescendantsInstances = {localChar, targetChar}
    params.FilterType = Enum.RaycastFilterType.Blacklist

    local result = workspace:Raycast(origin, direction, params)
    return result == nil
end

local function IsVisible(targetPart)
    if not targetPart then return false end
    local now = tick()
    if now - Cache.VisUpdateTime > CacheIntervals.Visibility then
        Cache.Visibility = {}
        Cache.VisUpdateTime = now
    end
    if Cache.Visibility[targetPart] == nil then
        Cache.Visibility[targetPart] = IsVisibleRaw(targetPart)
    end
    return Cache.Visibility[targetPart]
end

local function GetDistance(pos)
    local char = GetLocalCharacter()
    if not char then return 0 end
    local root = GetTargetPart(char)
    if not root then return 0 end
    return (pos - root.Position).Magnitude
end

local function GetRainbow()
    return Color3.fromHSV(State.RainbowHue, 1, 1)
end

local function GetPlayerNameSet()
    local names = {}
    names[LocalPlayer.Name] = true
    for _, p in ipairs(Players:GetPlayers()) do
        names[p.Name] = true
    end
    return names
end

local function CreateESP(key, displayName)
    if espObjects[key] then return end
    if not displayName then
        displayName = typeof(key) == "Instance" and key.Name or tostring(key)
    end

    local container = Instance.new("Frame")
    container.Name = displayName
    container.BackgroundTransparency = 1
    container.BorderSizePixel = 0
    container.Size = UDim2.new(0, 0, 0, 0)
    container.Parent = UI.ESPFolder

    local box = Instance.new("Frame")
    box.Name = "Box"
    box.BackgroundTransparency = 1
    box.BorderSizePixel = 0
    box.Parent = container

    local boxStroke = Instance.new("UIStroke")
    boxStroke.Name = "Stroke"
    boxStroke.Color = Palette.ESP_Enemy
    boxStroke.Thickness = 1
    boxStroke.Parent = box

    local nameLabel = Instance.new("TextLabel")
    nameLabel.Name = "Name"
    nameLabel.BackgroundTransparency = 1
    nameLabel.Font = Enum.Font.RobotoMono
    nameLabel.TextSize = 14
    nameLabel.TextColor3 = Color3.new(1, 1, 1)
    nameLabel.TextStrokeTransparency = 0
    nameLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
    nameLabel.Text = displayName
    nameLabel.Size = UDim2.new(0, 200, 0, 16)
    nameLabel.Parent = container

    local distLabel = Instance.new("TextLabel")
    distLabel.Name = "Distance"
    distLabel.BackgroundTransparency = 1
    distLabel.Font = Enum.Font.RobotoMono
    distLabel.TextSize = 12
    distLabel.TextColor3 = Color3.new(1, 1, 1)
    distLabel.TextStrokeTransparency = 0
    distLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
    distLabel.Size = UDim2.new(0, 200, 0, 14)
    distLabel.Parent = container

    local tracer = Instance.new("Frame")
    tracer.Name = "Tracer"
    tracer.BackgroundColor3 = Palette.ESP_Enemy
    tracer.BorderSizePixel = 0
    tracer.AnchorPoint = Vector2.new(0.5, 0)
    tracer.Parent = container

    espObjects[key] = {
        Container = container,
        Box = box,
        BoxStroke = boxStroke,
        Name = nameLabel,
        Distance = distLabel,
        Tracer = tracer
    }
end

local function RemoveESP(player)
    if espObjects[player] then
        if espObjects[player].Container then
            espObjects[player].Container:Destroy()
        end
        espObjects[player] = nil
    end
end

local function CleanupAllESP()
    for player, esp in pairs(espObjects) do
        if esp.Container then
            esp.Container:Destroy()
        end
    end
    espObjects = {}
end

local function GetClosestEnemyScreenPos()
    camera = workspace.CurrentCamera
    if not camera then return nil end

    local localTeam = GetPlayerTeam(LocalPlayer)
    local closestPos = nil
    local closestDist = Config.AIM_FOVEnabled and Config.AIM_FOV or math.huge
    local mousePos = UserInputService:GetMouseLocation()
    local charsFolder = GetCharactersFolder()

    for _, player in ipairs(Players:GetPlayers()) do
        if player == LocalPlayer then continue end

        local character = charsFolder and charsFolder:FindFirstChild(player.Name)
        if not character then continue end

        local playerTeam = GetPlayerTeam(player)

        local isEnemy = true
        if Config.ESP_TeamCheck and localTeam and playerTeam then
            isEnemy = localTeam ~= playerTeam
        end

        if isEnemy then
            local part = GetTargetPart(character)
            if part and IsVisible(part) then
                local screenPos, onScreen = camera:WorldToViewportPoint(part.Position)
                if onScreen then
                    local screenVec = Vector2.new(screenPos.X, screenPos.Y)
                    local dist = (mousePos - screenVec).Magnitude
                    if dist < closestDist then
                        closestDist = dist
                        closestPos = screenVec
                        targetEnemy = part
                    end
                end
            end
        end
    end

    if Config.ESP_Bots then
        for _, botModel in ipairs(GetBotModels()) do
            local part = GetTargetPart(botModel)
            if part and IsVisible(part) then
                local screenPos, onScreen = camera:WorldToViewportPoint(part.Position)
                if onScreen then
                    local screenVec = Vector2.new(screenPos.X, screenPos.Y)
                    local dist = (mousePos - screenVec).Magnitude
                    if dist < closestDist then
                        closestDist = dist
                        closestPos = screenVec
                        targetEnemy = part
                    end
                end
            end
        end
    end

    return closestPos
end

local function UpdateAimbot()
    camera = workspace.CurrentCamera
    if not camera then return end

    if not Config.AIM_Enabled or not State.Aiming then
        targetEnemy = nil
        return
    end

    local mousePos = UserInputService:GetMouseLocation()
    local aimPos = nil

    if targetEnemy and targetEnemy.Parent then
        if not IsVisible(targetEnemy) then
            targetEnemy = nil
        else
            local screenPos, onScreen = camera:WorldToViewportPoint(targetEnemy.Position)
            if onScreen then
                aimPos = Vector2.new(screenPos.X, screenPos.Y)
            else
                targetEnemy = nil
            end
        end
    end

    if not aimPos then
        aimPos = GetClosestEnemyScreenPos()
    end

    if not aimPos then return end

    local deltaX = (aimPos.X - mousePos.X) / Config.AIM_Smooth
    local deltaY = (aimPos.Y - mousePos.Y) / Config.AIM_Smooth

    if mousemoverel then
        mousemoverel(deltaX, deltaY)
    else
        local currentCFrame = camera.CFrame
        local worldPos = camera:ViewportPointToRay(aimPos.X, aimPos.Y).Origin
        local goalCFrame = CFrame.lookAt(currentCFrame.Position, worldPos)
        camera.CFrame = currentCFrame:Lerp(goalCFrame, 0.1)
    end
end

local function UpdateESP()
    camera = workspace.CurrentCamera
    if not camera then return end

    if not Config.ESP_Enabled then
        for _, esp in pairs(espObjects) do
            esp.Container.Visible = false
        end
        return
    end

    local localTeam = GetPlayerTeam(LocalPlayer)
    local charsFolder = GetCharactersFolder()
    local screenSize = camera.ViewportSize

    for _, player in ipairs(Players:GetPlayers()) do
        if player == LocalPlayer then continue end

        local character = charsFolder and charsFolder:FindFirstChild(player.Name)
        local playerTeam = GetPlayerTeam(player)

        if not character then
            if espObjects[player] then
                espObjects[player].Container.Visible = false
            end
            continue
        end

        if not espObjects[player] then
            CreateESP(player)
        end

        local esp = espObjects[player]
        if not esp then continue end

        local targetPart = GetTargetPart(character)
        if not targetPart then
            esp.Container.Visible = false
            continue
        end

        local rootPos, onScreen = camera:WorldToViewportPoint(targetPart.Position)
        if not onScreen or rootPos.Z <= 0 then
            esp.Container.Visible = false
            continue
        end

        local distance = GetDistance(targetPart.Position)

        local isEnemy = true
        if Config.ESP_TeamCheck and localTeam and playerTeam then
            isEnemy = localTeam ~= playerTeam
        end

        if not isEnemy then
            esp.Container.Visible = false
            continue
        end

        esp.Container.Visible = true

        local visible = IsVisible(targetPart)
        local col = Config.ESP_Rainbow and GetRainbow() or (visible and Palette.ESP_Visible or Palette.ESP_Enemy)

        local boxHeight = 1400 / math.max(rootPos.Z, 1)
        boxHeight = math.clamp(boxHeight, 20, 400)
        local boxWidth = boxHeight * 0.55

        local boxX = rootPos.X - boxWidth / 2
        local boxY = rootPos.Y - boxHeight * 0.55

        if Config.ESP_Box then
            esp.Box.Position = UDim2.new(0, boxX, 0, boxY)
            esp.Box.Size = UDim2.new(0, boxWidth, 0, boxHeight)
            esp.BoxStroke.Color = col
            esp.Box.Visible = true
        else
            esp.Box.Visible = false
        end

        if Config.ESP_Name then
            esp.Name.Position = UDim2.new(0, rootPos.X - 100, 0, boxY - 18)
            esp.Name.Visible = true
        else
            esp.Name.Visible = false
        end

        if Config.ESP_Distance then
            esp.Distance.Text = math.floor(distance) .. "m"
            esp.Distance.Position = UDim2.new(0, rootPos.X - 100, 0, boxY + boxHeight + 2)
            esp.Distance.Visible = true
        else
            esp.Distance.Visible = false
        end

        if Config.ESP_Tracer then
            local tracerStartY = boxY + boxHeight
            local tracerEndY = screenSize.Y
            local tracerHeight = tracerEndY - tracerStartY
            esp.Tracer.Position = UDim2.new(0, rootPos.X, 0, tracerStartY)
            esp.Tracer.Size = UDim2.new(0, 1, 0, tracerHeight)
            esp.Tracer.BackgroundColor3 = col
            esp.Tracer.Visible = true
        else
            esp.Tracer.Visible = false
        end
    end

    if Config.ESP_Bots then
        local activeBotKeys = {}

        for _, child in ipairs(GetBotModels()) do

            local botKey = "bot_" .. tostring(child)
            activeBotKeys[botKey] = child

            if not espObjects[botKey] then
                CreateESP(botKey, child.Name)
            end

            local esp = espObjects[botKey]
            if not esp then continue end

            local targetPart = GetTargetPart(child)
            if not targetPart or not child.Parent then
                esp.Container.Visible = false
                continue
            end

            local rootPos, onScreen = camera:WorldToViewportPoint(targetPart.Position)
            if not onScreen or rootPos.Z <= 0 then
                esp.Container.Visible = false
                continue
            end

            local distance = GetDistance(targetPart.Position)
            esp.Container.Visible = true

            local visible = IsVisible(targetPart)
            local col = Config.ESP_Rainbow and GetRainbow() or (visible and Palette.ESP_Visible or Palette.ESP_Enemy)

            local boxHeight = 1400 / math.max(rootPos.Z, 1)
            boxHeight = math.clamp(boxHeight, 20, 400)
            local boxWidth = boxHeight * 0.55

            local boxX = rootPos.X - boxWidth / 2
            local boxY = rootPos.Y - boxHeight * 0.55

            if Config.ESP_Box then
                esp.Box.Position = UDim2.new(0, boxX, 0, boxY)
                esp.Box.Size = UDim2.new(0, boxWidth, 0, boxHeight)
                esp.BoxStroke.Color = col
                esp.Box.Visible = true
            else
                esp.Box.Visible = false
            end

            if Config.ESP_Name then
                esp.Name.Position = UDim2.new(0, rootPos.X - 100, 0, boxY - 18)
                esp.Name.Visible = true
            else
                esp.Name.Visible = false
            end

            if Config.ESP_Distance then
                esp.Distance.Text = math.floor(distance) .. "m"
                esp.Distance.Position = UDim2.new(0, rootPos.X - 100, 0, boxY + boxHeight + 2)
                esp.Distance.Visible = true
            else
                esp.Distance.Visible = false
            end

            if Config.ESP_Tracer then
                local tracerStartY = boxY + boxHeight
                local tracerEndY = screenSize.Y
                local tracerHeight = tracerEndY - tracerStartY
                esp.Tracer.Position = UDim2.new(0, rootPos.X, 0, tracerStartY)
                esp.Tracer.Size = UDim2.new(0, 1, 0, tracerHeight)
                esp.Tracer.BackgroundColor3 = col
                esp.Tracer.Visible = true
            else
                esp.Tracer.Visible = false
            end
        end

        local toRemove = {}
        for key, _ in pairs(espObjects) do
            if typeof(key) == "string" and string.sub(key, 1, 4) == "bot_" then
                if not activeBotKeys[key] then
                    table.insert(toRemove, key)
                end
            end
        end
        for _, key in ipairs(toRemove) do
            if espObjects[key] and espObjects[key].Container then
                espObjects[key].Container:Destroy()
            end
            espObjects[key] = nil
        end
    else

        local toRemove = {}
        for key, _ in pairs(espObjects) do
            if typeof(key) == "string" and string.sub(key, 1, 4) == "bot_" then
                table.insert(toRemove, key)
            end
        end
        for _, key in ipairs(toRemove) do
            if espObjects[key] and espObjects[key].Container then
                espObjects[key].Container:Destroy()
            end
            espObjects[key] = nil
        end
    end
end

local FOVCircle = Instance.new("Frame")
FOVCircle.Name = "FOVCircle"
FOVCircle.BackgroundTransparency = 1
FOVCircle.BorderSizePixel = 0
FOVCircle.AnchorPoint = Vector2.new(0.5, 0.5)
FOVCircle.Parent = UI.ScreenGui

local FOVStroke = Instance.new("UIStroke")
FOVStroke.Color = Palette.FOV_Circle
FOVStroke.Thickness = 1
FOVStroke.Parent = FOVCircle

local FOVCorner = Instance.new("UICorner")
FOVCorner.CornerRadius = UDim.new(1, 0)
FOVCorner.Parent = FOVCircle

local function UpdateFOV()
    if Config.AIM_Enabled and Config.AIM_FOVEnabled then
        local mousePos = UserInputService:GetMouseLocation()
        local guiInset = game:GetService("GuiService"):GetGuiInset()
        FOVCircle.Position = UDim2.new(0, mousePos.X, 0, mousePos.Y + guiInset.Y)
        FOVCircle.Size = UDim2.new(0, Config.AIM_FOV * 2, 0, Config.AIM_FOV * 2)
        FOVStroke.Color = State.Aiming and Palette.FOV_Active or Palette.FOV_Circle
        FOVCircle.Visible = true
    else
        FOVCircle.Visible = false
    end
end

local RadarFrame = Instance.new("Frame")
RadarFrame.Name = "Radar"
RadarFrame.BackgroundColor3 = Palette.RadarBg
RadarFrame.BackgroundTransparency = 0.15
RadarFrame.BorderSizePixel = 0
RadarFrame.AnchorPoint = Vector2.new(1, 0)
RadarFrame.Parent = UI.ScreenGui

local RadarStroke = Instance.new("UIStroke")
RadarStroke.Color = Palette.RadarBorder
RadarStroke.Thickness = 1
RadarStroke.Parent = RadarFrame

local RadarCross1 = Instance.new("Frame")
RadarCross1.Name = "Cross1"
RadarCross1.BackgroundColor3 = Palette.RadarGrid
RadarCross1.BorderSizePixel = 0
RadarCross1.AnchorPoint = Vector2.new(0.5, 0)
RadarCross1.Parent = RadarFrame

local RadarCross2 = Instance.new("Frame")
RadarCross2.Name = "Cross2"
RadarCross2.BackgroundColor3 = Palette.RadarGrid
RadarCross2.BorderSizePixel = 0
RadarCross2.AnchorPoint = Vector2.new(0, 0.5)
RadarCross2.Parent = RadarFrame

local RadarCenter = Instance.new("Frame")
RadarCenter.Name = "Center"
RadarCenter.BackgroundColor3 = Palette.RadarYou
RadarCenter.BorderSizePixel = 0
RadarCenter.AnchorPoint = Vector2.new(0.5, 0.5)
RadarCenter.Size = UDim2.new(0, 6, 0, 6)
RadarCenter.Parent = RadarFrame

local RadarCenterCorner = Instance.new("UICorner")
RadarCenterCorner.CornerRadius = UDim.new(1, 0)
RadarCenterCorner.Parent = RadarCenter

local RadarDotsFolder = Instance.new("Folder")
RadarDotsFolder.Name = "Dots"
RadarDotsFolder.Parent = RadarFrame

for i = 1, 30 do
    local dot = Instance.new("Frame")
    dot.Name = "Dot" .. i
    dot.BackgroundColor3 = Palette.RadarEnemy
    dot.BorderSizePixel = 0
    dot.AnchorPoint = Vector2.new(0.5, 0.5)
    dot.Size = UDim2.new(0, Tuning.RadarDotSize, 0, Tuning.RadarDotSize)
    dot.Visible = false
    dot.Parent = RadarDotsFolder

    local dotCorner = Instance.new("UICorner")
    dotCorner.CornerRadius = UDim.new(1, 0)
    dotCorner.Parent = dot

    radarDots[i] = dot
end

local function UpdateRadar()
    camera = workspace.CurrentCamera
    if not camera then
        RadarFrame.Visible = false
        return
    end

    if not Config.RADAR_Enabled then
        RadarFrame.Visible = false
        return
    end

    local myChar = GetLocalCharacter()
    if not myChar then
        RadarFrame.Visible = false
        return
    end
    local myRoot = GetTargetPart(myChar)
    if not myRoot then
        RadarFrame.Visible = false
        return
    end

    local charsFolder = GetCharactersFolder()
    local size = Config.RADAR_Size
    local screenSize = camera.ViewportSize

    RadarFrame.Position = UDim2.new(1, -10, 0, 10)
    RadarFrame.Size = UDim2.new(0, size, 0, size)
    RadarFrame.Visible = true

    RadarCross1.Position = UDim2.new(0.5, 0, 0, 6)
    RadarCross1.Size = UDim2.new(0, 1, 1, -12)

    RadarCross2.Position = UDim2.new(0, 6, 0.5, 0)
    RadarCross2.Size = UDim2.new(1, -12, 0, 1)

    RadarCenter.Position = UDim2.new(0.5, 0, 0.5, 0)

    local myLook = camera.CFrame.LookVector
    local myAngle = math.atan2(-myLook.X, -myLook.Z)
    local cosA, sinA = math.cos(myAngle), math.sin(myAngle)
    local scale = (size/2 - 6) / Config.RADAR_Range

    local localTeam = GetPlayerTeam(LocalPlayer)
    local dotIdx = 1

    for _, player in ipairs(Players:GetPlayers()) do
        if player == LocalPlayer then continue end

        local character = charsFolder and charsFolder:FindFirstChild(player.Name)
        local playerTeam = GetPlayerTeam(player)

        if not character or not playerTeam then continue end

        local isEnemy = true
        if Config.ESP_TeamCheck and localTeam and playerTeam then
            isEnemy = localTeam ~= playerTeam
        end

        if not isEnemy then continue end

        local root = GetTargetPart(character)
        if not root then continue end

        local rx = root.Position.X - myRoot.Position.X
        local rz = root.Position.Z - myRoot.Position.Z
        local dist2D = math.sqrt(rx^2 + rz^2)

        if dist2D < Config.RADAR_Range then
            local rotX = rx * cosA - rz * sinA
            local rotZ = rx * sinA + rz * cosA
            local radarX, radarY = rotX * scale, rotZ * scale
            local maxD = size/2 - 6
            local rDist = math.sqrt(radarX^2 + radarY^2)
            if rDist > maxD then
                radarX, radarY = radarX/rDist * maxD, radarY/rDist * maxD
            end

            if dotIdx <= #radarDots then
                local dot = radarDots[dotIdx]
                dot.Position = UDim2.new(0.5, radarX, 0.5, radarY)

                local visible = IsVisible(root)
                dot.BackgroundColor3 = visible and Palette.ESP_Visible or Palette.ESP_Enemy
                dot.Visible = true
                dotIdx = dotIdx + 1
            end
        end
    end

    if Config.ESP_Bots then
        for _, child in ipairs(GetBotModels()) do
            local root = GetTargetPart(child)
            if root then
                local rx = root.Position.X - myRoot.Position.X
                local rz = root.Position.Z - myRoot.Position.Z
                local dist2D = math.sqrt(rx^2 + rz^2)

                if dist2D < Config.RADAR_Range then
                    local rotX = rx * cosA - rz * sinA
                    local rotZ = rx * sinA + rz * cosA
                    local radarX, radarY = rotX * scale, rotZ * scale
                    local maxD = size/2 - 6
                    local rDist = math.sqrt(radarX^2 + radarY^2)
                    if rDist > maxD then
                        radarX, radarY = radarX/rDist * maxD, radarY/rDist * maxD
                    end

                    if dotIdx <= #radarDots then
                        local dot = radarDots[dotIdx]
                        dot.Position = UDim2.new(0.5, radarX, 0.5, radarY)
                        local visible = IsVisible(root)
                        dot.BackgroundColor3 = visible and Palette.ESP_Visible or Palette.ESP_Enemy
                        dot.Visible = true
                        dotIdx = dotIdx + 1
                    end
                end
            end
        end
    end

    for i = dotIdx, #radarDots do
        radarDots[i].Visible = false
    end
end

local function CreateWatermark()
    local container = Instance.new("Frame")
    container.Name = "WatermarkContainer"
    container.BackgroundTransparency = 1
    container.Position = UDim2.new(0, 10, 0, 10)
    container.Size = UDim2.new(0, 250, 0, 40)
    container.Parent = UI.ScreenGui

    local label = Instance.new("TextLabel")
    label.Name = "Watermark"
    label.BackgroundTransparency = 1
    label.Position = UDim2.new(0, 0, 0, 0)
    label.Size = UDim2.new(1, 0, 0, 20)
    label.Font = Enum.Font.RobotoMono
    label.TextSize = 14
    label.TextColor3 = Palette.Accent
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.TextStrokeTransparency = 0.6
    label.Text = "Roblox Simple"
    label.Parent = container

    local xenoLabel = Instance.new("TextLabel")
    xenoLabel.Name = "Roblox Simple"
    xenoLabel.BackgroundTransparency = 1
    xenoLabel.Position = UDim2.new(0, 0, 0, 18)
    xenoLabel.Size = UDim2.new(1, 0, 0, 16)
    xenoLabel.Font = Enum.Font.RobotoMono
    xenoLabel.TextSize = 11
    xenoLabel.TextColor3 = Color3.fromRGB(85, 255, 127)
    xenoLabel.TextXAlignment = Enum.TextXAlignment.Left
    xenoLabel.TextStrokeTransparency = 0.6
    xenoLabel.Text = "Roblox Simple"
    xenoLabel.Parent = container

    return container
end

local function CreateActiveList()
    local frame = Instance.new("Frame")
    frame.Name = "ActiveList"
    frame.BackgroundTransparency = 1
    frame.AnchorPoint = Vector2.new(1, 0)
    frame.Position = UDim2.new(1, -160, 0, 10)
    frame.Size = UDim2.new(0, 150, 0, 300)
    frame.Parent = UI.ScreenGui

    local layout = Instance.new("UIListLayout")
    layout.FillDirection = Enum.FillDirection.Vertical
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Right
    layout.SortOrder = Enum.SortOrder.Name
    layout.Padding = UDim.new(0, 1)
    layout.Parent = frame

    return frame
end

local function RefreshActiveList(frame)
    for _, child in ipairs(frame:GetChildren()) do
        if child:IsA("TextLabel") then child:Destroy() end
    end

    if not Config.MISC_ActiveList then return end

    local features = {}
    if Config.ESP_Enabled then table.insert(features, "ESP") end
    if Config.ESP_Box then table.insert(features, "Box") end
    if Config.ESP_Name then table.insert(features, "Names") end
    if Config.ESP_Distance then table.insert(features, "Distance") end
    if Config.ESP_Tracer then table.insert(features, "Tracers") end
    if Config.AIM_Enabled then table.insert(features, "Aimbot") end
    if Config.RADAR_Enabled then table.insert(features, "Radar") end

    for i, name in ipairs(features) do
        local lbl = Instance.new("TextLabel")
        lbl.Name = string.format("%02d", i) .. name
        lbl.BackgroundTransparency = 1
        lbl.Size = UDim2.new(1, 0, 0, 16)
        lbl.Font = Enum.Font.RobotoMono
        lbl.TextSize = 13
        lbl.TextColor3 = Palette.ItemOn
        lbl.TextXAlignment = Enum.TextXAlignment.Right
        lbl.TextStrokeTransparency = 0.6
        lbl.Text = name
        lbl.Parent = frame
    end
end

local function CreatePanel(title, items, pos)
    local totalHeight = Tuning.PanelHeaderH
    for _, item in ipairs(items) do
        if item.type == "slider" then
            totalHeight = totalHeight + Tuning.SliderHeight
        else
            totalHeight = totalHeight + Tuning.ItemHeight
        end
    end
    totalHeight = totalHeight + 6

    local panel = Instance.new("Frame")
    panel.Name = title
    panel.BackgroundColor3 = Palette.PanelBg
    panel.BackgroundTransparency = 0.08
    panel.BorderSizePixel = 0
    panel.Position = pos
    panel.Size = UDim2.new(0, Tuning.PanelWidth, 0, totalHeight)
    panel.Active = true
    panel.Draggable = true
    panel.Parent = UI.ScreenGui

    local stroke = Instance.new("UIStroke")
    stroke.Color = Palette.PanelBorder
    stroke.Thickness = 1
    stroke.Parent = panel

    local header = Instance.new("Frame")
    header.Name = "Header"
    header.BackgroundColor3 = Palette.PanelHeader
    header.BackgroundTransparency = 0.05
    header.BorderSizePixel = 0
    header.Size = UDim2.new(1, 0, 0, Tuning.PanelHeaderH)
    header.Parent = panel

    local titleLabel = Instance.new("TextLabel")
    titleLabel.Name = "Title"
    titleLabel.BackgroundTransparency = 1
    titleLabel.Size = UDim2.new(1, 0, 1, 0)
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.TextSize = Tuning.FontSize
    titleLabel.TextColor3 = Palette.Text
    titleLabel.Text = title
    titleLabel.Parent = header

    local yOffset = Tuning.PanelHeaderH + 3

    for _, item in ipairs(items) do
        if item.type == "toggle" then
            local btn = Instance.new("TextButton")
            btn.Name = item.key
            btn.BackgroundColor3 = Palette.ItemHover
            btn.BackgroundTransparency = 1
            btn.BorderSizePixel = 0
            btn.Position = UDim2.new(0, 0, 0, yOffset)
            btn.Size = UDim2.new(1, 0, 0, Tuning.ItemHeight)
            btn.Font = Enum.Font.RobotoMono
            btn.TextSize = Tuning.FontSize
            btn.TextXAlignment = Enum.TextXAlignment.Left
            btn.AutoButtonColor = false
            btn.Parent = panel

            local pad = Instance.new("UIPadding")
            pad.PaddingLeft = UDim.new(0, 10)
            pad.Parent = btn

            local function Update()
                btn.TextColor3 = Config[item.key] and Palette.ItemOn or Palette.ItemOff
                btn.Text = item.name
            end
            Update()

            btn.MouseEnter:Connect(function() btn.BackgroundTransparency = 0.5 end)
            btn.MouseLeave:Connect(function() btn.BackgroundTransparency = 1 end)
            btn.MouseButton1Click:Connect(function()
                Config[item.key] = not Config[item.key]
                Update()
                if UI.ActiveList then RefreshActiveList(UI.ActiveList) end
            end)

            yOffset = yOffset + Tuning.ItemHeight

        elseif item.type == "slider" then
            local container = Instance.new("Frame")
            container.Name = item.key
            container.BackgroundTransparency = 1
            container.Position = UDim2.new(0, 10, 0, yOffset)
            container.Size = UDim2.new(1, -20, 0, Tuning.SliderHeight - 4)
            container.Parent = panel

            local label = Instance.new("TextLabel")
            label.Name = "Label"
            label.BackgroundTransparency = 1
            label.Size = UDim2.new(1, 0, 0, 16)
            label.Font = Enum.Font.RobotoMono
            label.TextSize = 12
            label.TextColor3 = Palette.TextDim
            label.TextXAlignment = Enum.TextXAlignment.Left
            label.Parent = container

            local track = Instance.new("Frame")
            track.Name = "Track"
            track.BackgroundColor3 = Color3.fromRGB(45, 45, 50)
            track.BorderSizePixel = 0
            track.Position = UDim2.new(0, 0, 0, 18)
            track.Size = UDim2.new(1, 0, 0, 8)
            track.Parent = container

            local trackCorner = Instance.new("UICorner")
            trackCorner.CornerRadius = UDim.new(0, 4)
            trackCorner.Parent = track

            local fill = Instance.new("Frame")
            fill.Name = "Fill"
            fill.BackgroundColor3 = Palette.Accent
            fill.BorderSizePixel = 0
            fill.Size = UDim2.new(0, 0, 1, 0)
            fill.Parent = track

            local fillCorner = Instance.new("UICorner")
            fillCorner.CornerRadius = UDim.new(0, 4)
            fillCorner.Parent = fill

            local function UpdateSlider()
                local val = Config[item.key]
                local pct = (val - item.min) / (item.max - item.min)
                fill.Size = UDim2.new(pct, 0, 1, 0)
                label.Text = item.name .. ": " .. tostring(math.floor(val * 10) / 10)
            end
            UpdateSlider()

            local dragging = false

            track.InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 then
                    dragging = true
                end
            end)

            track.InputEnded:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 then
                    dragging = false
                end
            end)

            Connections["slider_" .. item.key] = RunService.RenderStepped:Connect(function()
                if dragging then
                    local mx = UserInputService:GetMouseLocation().X
                    local tx = track.AbsolutePosition.X
                    local tw = track.AbsoluteSize.X
                    local pct = math.clamp((mx - tx) / tw, 0, 1)
                    local val = item.min + pct * (item.max - item.min)
                    val = math.floor(val / item.step + 0.5) * item.step
                    Config[item.key] = math.clamp(val, item.min, item.max)
                    UpdateSlider()
                end
            end)

            yOffset = yOffset + Tuning.SliderHeight

        elseif item.type == "keybind" then
            local btn = Instance.new("TextButton")
            btn.Name = item.key
            btn.BackgroundColor3 = Palette.ItemHover
            btn.BackgroundTransparency = 1
            btn.BorderSizePixel = 0
            btn.Position = UDim2.new(0, 0, 0, yOffset)
            btn.Size = UDim2.new(1, 0, 0, Tuning.ItemHeight)
            btn.Font = Enum.Font.RobotoMono
            btn.TextSize = Tuning.FontSize
            btn.TextXAlignment = Enum.TextXAlignment.Left
            btn.AutoButtonColor = false
            btn.Parent = panel

            local kpad = Instance.new("UIPadding")
            kpad.PaddingLeft = UDim.new(0, 10)
            kpad.Parent = btn

            local isListening = false

            local function SetLabel()
                local k = Config[item.key]
                if isListening then
                    btn.Text = item.name .. ": ..."
                    btn.TextColor3 = Color3.fromRGB(255, 200, 50)
                else
                    btn.Text = item.name .. ": " .. (k and k.display or "?")
                    btn.TextColor3 = Palette.ItemOn
                end
            end
            SetLabel()

            local listenConn = nil

            local function StartListen()
                if isListening then return end
                isListening = true
                SetLabel()

                task.defer(function()
                    if listenConn then
                        pcall(function() listenConn:Disconnect() end)
                    end

                    local function GetMouseDisplay(ut)
                        local name = tostring(ut):match("MouseButton(%d+)")
                        if not name then return nil end
                        local aliases = {["1"]="LMB", ["2"]="RMB", ["3"]="MMB"}
                        return aliases[name] or ("MB"..name)
                    end

                    local function CommitBind(inp)
                        local mbDisplay = GetMouseDisplay(inp.UserInputType)
                        local isKey = inp.UserInputType == Enum.UserInputType.Keyboard
                            and inp.KeyCode ~= Enum.KeyCode.Unknown
                            and inp.KeyCode ~= Enum.KeyCode.Escape

                        if not mbDisplay and not isKey then return false end

                        if mbDisplay then
                            Config[item.key] = {
                                isMouse = true,
                                code = inp.UserInputType,
                                display = mbDisplay
                            }
                        else
                            Config[item.key] = {
                                isMouse = false,
                                code = inp.KeyCode,
                                display = tostring(inp.KeyCode):gsub("Enum%.KeyCode%.", "")
                            }
                        end

                        pcall(function() listenConn:Disconnect() end)
                        listenConn = nil
                        isListening = false
                        SetLabel()
                        return true
                    end

                    listenConn = UserInputService.InputBegan:Connect(function(inp)
                        local isKey = inp.UserInputType == Enum.UserInputType.Keyboard
                            and inp.KeyCode ~= Enum.KeyCode.Unknown

                        if inp.KeyCode == Enum.KeyCode.Escape then
                            pcall(function() listenConn:Disconnect() end)
                            listenConn = nil
                            isListening = false
                            SetLabel()
                            return
                        end

                        if isKey then
                            CommitBind(inp)
                            return
                        end

                        if GetMouseDisplay(inp.UserInputType) then
                            local capturedType = inp.UserInputType
                            local upConn
                            upConn = UserInputService.InputEnded:Connect(function(inp2)
                                if inp2.UserInputType ~= capturedType then return end
                                pcall(function() upConn:Disconnect() end)
                                CommitBind(inp)
                            end)
                        end
                    end)
                end)
            end

            btn.MouseEnter:Connect(function() btn.BackgroundTransparency = 0.5 end)
            btn.MouseLeave:Connect(function() btn.BackgroundTransparency = 1 end)
            btn.MouseButton1Click:Connect(StartListen)

            yOffset = yOffset + Tuning.ItemHeight
        end
    end

    return panel
end

UI.Watermark = CreateWatermark()
UI.ActiveList = CreateActiveList()
RefreshActiveList(UI.ActiveList)

UI.Panels = {}

UI.Panels.ESP = CreatePanel("ESP", {
    {type = "toggle", name = "Enabled", key = "ESP_Enabled"},
    {type = "toggle", name = "Box", key = "ESP_Box"},
    {type = "toggle", name = "Names", key = "ESP_Name"},
    {type = "toggle", name = "Distance", key = "ESP_Distance"},
    {type = "toggle", name = "Tracers", key = "ESP_Tracer"},
    {type = "toggle", name = "Rainbow", key = "ESP_Rainbow"},
    {type = "toggle", name = "TeamCheck", key = "ESP_TeamCheck"},
    {type = "toggle", name = "Bots", key = "ESP_Bots"}
}, UDim2.new(0, 10, 0, 55))

UI.Panels.Aimbot = CreatePanel("Aimbot", {
    {type = "toggle", name = "Enabled", key = "AIM_Enabled"},
    {type = "toggle", name = "ShowFOV", key = "AIM_FOVEnabled"},
    {type = "keybind", name = "Key", key = "AIM_HoldKey"},
    {type = "slider", name = "FOV", key = "AIM_FOV", min = 30, max = 400, step = 5},
    {type = "slider", name = "Smooth", key = "AIM_Smooth", min = 1, max = 15, step = 0.5}
}, UDim2.new(0, 165, 0, 55))

UI.Panels.Radar = CreatePanel("Radar", {
    {type = "toggle", name = "Enabled", key = "RADAR_Enabled"},
    {type = "slider", name = "Size", key = "RADAR_Size", min = 100, max = 200, step = 10},
    {type = "slider", name = "Range", key = "RADAR_Range", min = 50, max = 500, step = 25}
}, UDim2.new(0, 320, 0, 55))

UI.Panels.Misc = CreatePanel("Misc", {
    {type = "toggle", name = "Watermark", key = "MISC_Watermark"},
    {type = "toggle", name = "ActiveList", key = "MISC_ActiveList"},
    {type = "toggle", name = "InfAmmo", key = "MISC_InfAmmo"}
}, UDim2.new(0, 475, 0, 55))

local function IsAmmoName(name)
    for _, n in ipairs(AMMO_NAMES) do
        if n == name then return true end
    end
    local low = name:lower()
    return low:find("ammo") or low:find("bullet") or low:find("magazine")
        or low:find("clip") or low:find("shots") or low:find("round")
end

local function HookAmmoValue(val)
    if ammoHooks[val] then return end
    local ok = val:IsA("IntValue") or val:IsA("NumberValue") or val:IsA("IntConstrainedValue")
    if not ok then return end
    if not IsAmmoName(val.Name) then return end

    local maxVal = math.max(val.Value, 1)

    local conn = val.Changed:Connect(function(newVal)
        if not Config.MISC_InfAmmo then return end
        if newVal > maxVal then maxVal = newVal end
        if newVal < maxVal then
            pcall(function() val.Value = maxVal end)
        end
    end)

    ammoHooks[val] = { conn = conn, maxRef = function() return maxVal end }
end

local function ScanInstanceForAmmo(inst)
    if not inst or not inst.Parent then return end
    pcall(function()
        for _, desc in ipairs(inst:GetDescendants()) do
            HookAmmoValue(desc)
        end
        inst.DescendantAdded:Connect(function(desc)
            task.defer(function() HookAmmoValue(desc) end)
        end)
    end)
end

local function ScanCharacterTools(char)
    if not char then return end
    ScanInstanceForAmmo(char)
    char.ChildAdded:Connect(function(child)
        task.wait()
        ScanInstanceForAmmo(child)
    end)
end

local function SetupInfAmmo()
    local char = LocalPlayer.Character
    ScanCharacterTools(char)

    local backpack = LocalPlayer:FindFirstChild("Backpack")
    if backpack then
        ScanInstanceForAmmo(backpack)
        backpack.ChildAdded:Connect(function(tool)
            task.wait()
            ScanInstanceForAmmo(tool)
        end)
    end
end

local function CleanupInfAmmo()
    for val, _ in pairs(ammoHooks) do
        pcall(function() ammoHooks[val].conn:Disconnect() end)
    end
    ammoHooks = {}
end

Connections.infAmmoHb = RunService.Heartbeat:Connect(function()
    if not Config.MISC_InfAmmo then return end
    for val, data in pairs(ammoHooks) do
        pcall(function()
            if val and val.Parent then
                local maxVal = data.maxRef()
                if val.Value < maxVal then
                    val.Value = maxVal
                end
            end
        end)
    end
end)

Connections.charAdded = LocalPlayer.CharacterAdded:Connect(function(char)
    task.wait(1)
    ScanCharacterTools(char)
end)

SetupInfAmmo()

local function Unload()
    if State.Unloaded then return end
    State.Unloaded = true

    for _, conn in pairs(Connections) do
        pcall(function() conn:Disconnect() end)
    end

    CleanupAllESP()
    CleanupInfAmmo()

    pcall(function() UI.ScreenGui:Destroy() end)
end

Connections.inputDown = UserInputService.InputBegan:Connect(function(input, gp)
    if input.KeyCode == Enum.KeyCode.Home then
        Unload()
        return
    end


    if (input.KeyCode == Enum.KeyCode.Zero or input.KeyCode == Enum.KeyCode.KeypadZero) then
        State.MenuOpen = not State.MenuOpen
        for _, panel in pairs(UI.Panels) do
            panel.Visible = State.MenuOpen
        end
        return
    end

    if input.KeyCode == Enum.KeyCode.Insert and not gp then
        State.MenuOpen = not State.MenuOpen
        for _, panel in pairs(UI.Panels) do
            panel.Visible = State.MenuOpen
        end
        return
    end

    local holdKey = Config.AIM_HoldKey
    if holdKey then
        if holdKey.isMouse and input.UserInputType == holdKey.code then
            State.Aiming = true
        elseif not holdKey.isMouse and input.KeyCode == holdKey.code then
            State.Aiming = true
        end
    end
end)

Connections.inputUp = UserInputService.InputEnded:Connect(function(input)
    local holdKey = Config.AIM_HoldKey
    if holdKey then
        if holdKey.isMouse and input.UserInputType == holdKey.code then
            State.Aiming = false
            targetEnemy = nil
        elseif not holdKey.isMouse and input.KeyCode == holdKey.code then
            State.Aiming = false
            targetEnemy = nil
        end
    end
end)

Connections.render = RunService.RenderStepped:Connect(function()
    if State.Unloaded then return end

    State.RainbowHue = (State.RainbowHue + 0.004) % 1

    UpdateESP()
    UpdateAimbot()
    UpdateFOV()
    UpdateRadar()

    if UI.Watermark then
        UI.Watermark.Visible = Config.MISC_Watermark
    end
end)

for _, player in ipairs(Players:GetPlayers()) do
    if player ~= LocalPlayer then
        CreateESP(player)
    end
end

Connections.playerAdded = Players.PlayerAdded:Connect(function(player)
    CreateESP(player)
end)

Connections.playerRemoving = Players.PlayerRemoving:Connect(function(player)
    RemoveESP(player)
end)
