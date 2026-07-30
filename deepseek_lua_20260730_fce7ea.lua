--[[
    VILLONHUB TERMINAL ENGINE: PREMIUM CS2 & MM2 REPLICATION CORE
    GUI переделан на WindUI (без AutoFarm в меню)
    С отладкой и защитой от ошибок загрузки
]]

if getgenv().AdvancedCoreLoaded then
    game:GetService("StarterGui"):SetCore("SendNotification", {
        Title = "VillonHub",
        Text = "Архитектура уже active.",
        Duration = 3
    })
    return
end
getgenv().AdvancedCoreLoaded = true

--// Системные сервисы
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local CoreGui = game:GetService("CoreGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

-- ===== НАСТРОЙКИ ПРЕДИКШЕНА =====
local CONFIG_SM = {
    BulletSpeed = 280,
    PredictionFactor = 0.85,
    MaxHorizontalPrediction = 300,
    MaxVerticalPrediction = 50,
    PingCompensation = true,
    UseVerticalCorrection = true
}

--// Глобальная конфигурация
local Options = {
    Aimbot = {
        Enabled = false,
        Radius = 120,
        TargetPart = "Torso",
        TeamCheck = true,
        WallCheck = true,
        BindButtonEnabled = false
    },
    Visuals = {
        Boxes = false,
        BoxColor = Color3.fromRGB(255, 0, 100),
        Skeletons = false,
        SkeletonColor = Color3.fromRGB(255, 255, 255),
        Names = false,
        HealthBar = false,
        Tracers = false,
        Chams = false,
        ChamsColor = Color3.fromRGB(255, 0, 100),
        TeamCheck = true,
        UpdateRate = 0.01
    },
    MM2 = {
        RoleESP = false,
        GunESP = false,
        TPGunButtonEnabled = false,
        ShootMurderButtonEnabled = false,
        ThrowKnifeButtonEnabled = false,
        InvisButtonEnabled = false,
        FlingButtonEnabled = false,
        AimMurderOnly = false,
        AutoAimMurder = false,
        Invisibility = false,
        Fling = false,
        AutoTPGun = false,
        FlingMurder = false,
        FlingSheriff = false,
        KillAllButtonEnabled = false,
        KillSheriffButtonEnabled = false,
        JerkOffEnabled = false
    },
    Misc = {
        SpinBot = false,
        WalkSpeedEnabled = false,
        WalkSpeedValue = 16,
        AntiFling = true,
        DoubleJump = false,
        FovEnabled = false,
        FovValue = 70,
        AspectRatioEnabled = false,
        AspectRatioValue = 1.33,
        SpeedGlitchEnabled = false,
        SpeedGlitchValue = 20
    }
}

--// Локальные переменные
local ScreenCenter = Camera.ViewportSize / 2
local VisualStorage = {}
local Connections = {}
local IsAimBindEditModeActive = false
local IsTPGunEditModeActive = false
local IsShootMurderEditModeActive = false
local IsThrowKnifeEditModeActive = false
local IsInvisEditModeActive = false
local IsFlingEditModeActive = false
local IsKillAllEditModeActive = false
local IsKillSheriffEditModeActive = false
local jumpPressed = false
local doubleJumpCount = 0
local env = { OldPos = nil, timeout = 2.5 }

--// FOV круг
local FOVCircle = Drawing.new("Circle")
FOVCircle.Thickness = 1
FOVCircle.NumSides = 40
FOVCircle.Radius = Options.Aimbot.Radius
FOVCircle.Filled = false
FOVCircle.Visible = false
FOVCircle.Color = Color3.fromRGB(255, 255, 255)
FOVCircle.Position = ScreenCenter

local ViewportConnection = Camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
    ScreenCenter = Camera.ViewportSize / 2
    FOVCircle.Position = ScreenCenter
end)
table.insert(Connections, ViewportConnection)

--// Вспомогательные функции
local function getRoot(char)
    if not char then return nil end
    return char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso") or char:FindFirstChild("UpperTorso")
end

local function getPing()
    if LocalPlayer and LocalPlayer.GetNetworkPing then
        return LocalPlayer:GetNetworkPing() * 1000
    end
    return 0
end

local function doDoubleJumpLogic()
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if hum and Options.Misc.DoubleJump then
        if hum:GetState() == Enum.HumanoidStateType.Freefall and doubleJumpCount < 1 then
            hum:ChangeState(Enum.HumanoidStateType.Jumping)
            doubleJumpCount = 1
        end
    end
end

local InputBeganCon = UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.KeyCode == Enum.KeyCode.Space then
        jumpPressed = true
        doDoubleJumpLogic()
    end
end)
local InputEndedCon = UserInputService.InputEnded:Connect(function(input)
    if input.KeyCode == Enum.KeyCode.Space then
        jumpPressed = false
    end
end)
table.insert(Connections, InputBeganCon)
table.insert(Connections, InputEndedCon)

task.spawn(function()
    while true do
        local pGui = LocalPlayer:WaitForChild("PlayerGui", 5)
        if pGui then
            local touchGui = pGui:FindFirstChild("TouchGui")
            if touchGui then
                local controlFrame = touchGui:FindFirstChild("TouchControlFrame")
                if controlFrame then
                    local jumpBtn = controlFrame:FindFirstChild("JumpButton")
                    if jumpBtn then
                        local mobBegan = jumpBtn.InputBegan:Connect(function()
                            jumpPressed = true
                            doDoubleJumpLogic()
                        end)
                        local mobEnded = jumpBtn.InputEnded:Connect(function() jumpPressed = false end)
                        table.insert(Connections, mobBegan)
                        table.insert(Connections, mobEnded)
                        break
                    end
                end
            end
        end
        task.wait(1)
    end
end)

local JumpResetLoop = RunService.PostSimulation:Connect(function()
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if hum and hum.FloorMaterial ~= Enum.Material.Air then
        doubleJumpCount = 0
    end
end)
table.insert(Connections, JumpResetLoop)

--// Роли (GetPlayerData)
local roleColors = {
    Murderer = Color3.fromRGB(255, 0, 0),
    Sheriff = Color3.fromRGB(0, 0, 255),
    Hero = Color3.fromRGB(255, 255, 0),
    Innocent = Color3.fromRGB(0, 255, 0),
    Default = Color3.fromRGB(200, 200, 200)
}

local function getRoles()
    local success, data = pcall(function()
        return ReplicatedStorage:FindFirstChild("GetPlayerData", true):InvokeServer()
    end)
    if not success or not data then return {} end
    local roles = {}
    for plr, plrData in pairs(data) do
        if not plrData.Dead then
            roles[plr] = plrData.Role
        end
    end
    return roles
end

local cachedRoles = {}
task.spawn(function()
    while true do
        if Options.MM2.RoleESP or Options.MM2.AimMurderOnly or Options.MM2.AutoAimMurder or Options.MM2.ShootMurderButtonEnabled or Options.MM2.FlingMurder or Options.MM2.FlingSheriff then
            cachedRoles = getRoles()
        end
        task.wait(0.25)
    end
end)

local function GetCurrentMurderer()
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and cachedRoles[p.Name] == "Murderer" and p.Character then
            local mHum = p.Character:FindFirstChildOfClass("Humanoid")
            if mHum and mHum.Health > 0 then
                return p.Character
            end
        end
    end
    return nil
end

-- ===== ШОТ МАРДЕР (финальный, твой код) =====
local function getMurdererTarget()
    local roles = getRoles()
    local myChar = LocalPlayer.Character
    local myPos = myChar and myChar:FindFirstChild("HumanoidRootPart") and myChar.HumanoidRootPart.Position
    if not myPos then return nil end

    local bestTarget = nil
    local bestScore = math.huge

    for plr, role in pairs(roles) do
        if role == "Murderer" and plr ~= LocalPlayer.Name then
            local player = Players:FindFirstChild(plr)
            if player and player.Character then
                local hrp = player.Character:FindFirstChild("HumanoidRootPart")
                if hrp then
                    local currentPos = hrp.Position
                    local velocity = hrp.AssemblyLinearVelocity

                    local velXZ = Vector3.new(velocity.X, 0, velocity.Z)
                    local velY = math.clamp(velocity.Y, -10, 10)

                    local dist = (currentPos - myPos).Magnitude
                    local travelTime = dist / CONFIG_SM.BulletSpeed
                    if CONFIG_SM.PingCompensation then
                        local pingMs = getPing()
                        travelTime = travelTime + math.min(pingMs / 1000 * 0.5, 0.08)
                    end

                    local horizPred = velXZ * travelTime * CONFIG_SM.PredictionFactor
                    if horizPred.Magnitude > CONFIG_SM.MaxHorizontalPrediction then
                        horizPred = horizPred.Unit * CONFIG_SM.MaxHorizontalPrediction
                    end

                    local vertPred = Vector3.new(0, velY * travelTime * CONFIG_SM.PredictionFactor, 0)
                    if math.abs(vertPred.Y) > CONFIG_SM.MaxVerticalPrediction then
                        vertPred = Vector3.new(0, math.sign(vertPred.Y) * CONFIG_SM.MaxVerticalPrediction, 0)
                    end

                    local predictedPos = currentPos + horizPred + vertPred

                    if CONFIG_SM.UseVerticalCorrection and math.abs(velocity.Y) > 3 then
                        predictedPos = predictedPos + Vector3.new(0, -0.5, 0)
                    end

                    if dist < bestScore then
                        bestScore = dist
                        bestTarget = predictedPos
                    end
                end
            end
        end
    end
    return bestTarget
end

local function getClosestPlayer()
    local closest = nil
    local minDist = math.huge
    local myChar = LocalPlayer.Character
    local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
    if not myRoot then return nil end
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then
            local char = p.Character
            if char then
                local root = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso")
                local hum = char:FindFirstChildOfClass("Humanoid")
                if root and hum and hum.Health > 0 then
                    local dist = (root.Position - myRoot.Position).Magnitude
                    if dist < minDist then
                        minDist = dist
                        closest = p
                    end
                end
            end
        end
    end
    return closest
end

local function equipKnife()
    local char = LocalPlayer.Character
    if not char then return false end
    local hum = char:FindFirstChild("Humanoid")
    if not hum then return false end
    local backpack = LocalPlayer:FindFirstChild("Backpack")
    if not backpack then return false end
    local knife = backpack:FindFirstChild("Knife")
    if not knife then return false end
    hum:EquipTool(knife)
    return true
end

local function throwKnifeToClosest()
    local char = LocalPlayer.Character
    if not char then return end
    local knife = char:FindFirstChild("Knife")
    if not knife then
        if not equipKnife() then return end
        knife = char:FindFirstChild("Knife")
        if not knife then return end
    end
    local events = knife:FindFirstChild("Events")
    if not events then return end
    local knifeThrown = events:FindFirstChild("KnifeThrown")
    if not knifeThrown or not knifeThrown:IsA("RemoteEvent") then return end
    local target = getClosestPlayer()
    if not target then return end
    local targetChar = target.Character
    if not targetChar then return end
    local targetRoot = targetChar:FindFirstChild("HumanoidRootPart") or targetChar:FindFirstChild("Torso")
    if not targetRoot then return end
    local targetPos = targetRoot.Position
    local vel = targetRoot.AssemblyLinearVelocity
    local myRoot = char:FindFirstChild("HumanoidRootPart")
    if myRoot then
        local dist = (targetPos - myRoot.Position).Magnitude
        local travelTime = dist / CONFIG_SM.BulletSpeed
        if CONFIG_SM.PingCompensation then
            local pingMs = getPing()
            travelTime = travelTime + math.min(pingMs / 1000 * 0.5, 0.1)
        end
        local prediction = vel * travelTime * CONFIG_SM.PredictionFactor
        if prediction.Magnitude > CONFIG_SM.MaxHorizontalPrediction then
            prediction = prediction.Unit * CONFIG_SM.MaxHorizontalPrediction
        end
        targetPos = targetPos + prediction
    end
    local knifeCFrame = knife:FindFirstChild("Handle") and knife.Handle.CFrame or knife.CFrame
    local targetCFrame = CFrame.new(targetPos)
    pcall(function()
        knifeThrown:FireServer(knifeCFrame, targetCFrame)
    end)
end

local function AmIMurderer()
    return cachedRoles[LocalPlayer.Name] == "Murderer"
end

local function GetTorso(character)
    if not character then return nil end
    return character:FindFirstChild("Torso")
        or character:FindFirstChild("UpperTorso")
        or character:FindFirstChild("LowerTorso")
        or character:FindFirstChild("HumanoidRootPart")
end

local function equipGun()
    local char = LocalPlayer.Character
    if not char then return false end
    local hum = char:FindFirstChild("Humanoid")
    if not hum then return false end
    local backpack = LocalPlayer:FindFirstChild("Backpack")
    if not backpack then return false end
    local gun = backpack:FindFirstChild("Gun")
    if not gun then return false end
    hum:EquipTool(gun)
    return true
end

-- ===== ФЛИНГ (SHubFling) =====
local function SHubFling(TargetPlayer)
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local root = getRoot(char)
    if not (char and hum and root) then return end
    local TCharacter = TargetPlayer.Character
    if not TCharacter then return end
    local THumanoid = TCharacter:FindFirstChildOfClass("Humanoid")
    local TRootPart = THumanoid and THumanoid.RootPart
    local THead = TCharacter:FindFirstChild("Head")
    local Accessory = TCharacter:FindFirstChildOfClass("Accessory")
    local Handle = Accessory and Accessory:FindFirstChild("Handle")
    env.OldPos = root.CFrame
    repeat task.wait()
        Workspace.CurrentCamera.CameraSubject = THead or Handle or THumanoid
    until Workspace.CurrentCamera.CameraSubject == THead or Handle or THumanoid
    local function FPos(BasePart, Pos, Ang)
        local targetCF = CFrame.new(BasePart.Position) * Pos * Ang
        root.CFrame = targetCF
        char:SetPrimaryPartCFrame(targetCF)
        root.Velocity = Vector3.new(9e7, 9e8, 9e7)
        root.RotVelocity = Vector3.new(9e8, 9e8, 9e8)
    end
    local function SFBasePart(BasePart)
        local start = tick()
        local angle = 0
        env.timeout = env.timeout or 2.5
        repeat
            if root and THumanoid then
                angle = angle + 100
                for _, offset in ipairs{
                    CFrame.new(0, 1.5, 0),
                    CFrame.new(0, -1.5, 0),
                    CFrame.new(2.25, 1.5, -2.25),
                    CFrame.new(-2.25, -1.5, 2.25)
                } do
                    FPos(BasePart, offset + THumanoid.MoveDirection, CFrame.Angles(math.rad(angle), 0, 0))
                    task.wait()
                end
            end
        until BasePart.Velocity.Magnitude > 500 or tick() - start > env.timeout
    end
    local BV = Instance.new("BodyVelocity")
    BV.Name = "SeYyyVel!?"
    BV.Velocity = Vector3.new(9e8, 9e8, 9e8)
    BV.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    BV.Parent = root
    hum:SetStateEnabled(Enum.HumanoidStateType.Seated, false)
    local target = TRootPart or THead or Handle
    if target then SFBasePart(target) end
    BV:Destroy()
    hum:SetStateEnabled(Enum.HumanoidStateType.Seated, true)
    repeat task.wait()
        Workspace.CurrentCamera.CameraSubject = hum
    until Workspace.CurrentCamera.CameraSubject == hum
    repeat
        local cf = env.OldPos * CFrame.new(0, 0.5, 0)
        root.CFrame = cf
        char:SetPrimaryPartCFrame(cf)
        hum:ChangeState("GettingUp")
        for _, part in ipairs(char:GetChildren()) do
            if part:IsA("BasePart") then
                part.Velocity, part.RotVelocity = Vector3.zero, Vector3.zero
            end
        end
        task.wait()
    until (root.Position - env.OldPos.p).Magnitude < 25
end

local function FlingMurderer()
    local Murderer = nil
    for plr, role in pairs(cachedRoles) do
        if role == "Murderer" then
            Murderer = Players:FindFirstChild(plr)
            break
        end
    end
    if Murderer and Murderer ~= LocalPlayer then
        SHubFling(Murderer)
    else
        warn("Убийца не найден или это вы.")
    end
end

local function FlingSheriff()
    local Target = nil
    for plr, role in pairs(cachedRoles) do
        if role == "Sheriff" or role == "Hero" then
            Target = Players:FindFirstChild(plr)
            break
        end
    end
    if Target and Target ~= LocalPlayer then
        SHubFling(Target)
    else
        warn("Шериф/Герой не найден или это вы.")
    end
end

local function AutoGrabGun()
    local char = LocalPlayer.Character
    local root = getRoot(char)
    if not (char and root) then return end
    local gun = Workspace:FindFirstChild("GunDrop", true)
    if gun then
        if firetouchinterest then
            firetouchinterest(root, gun, 0)
            firetouchinterest(root, gun, 1)
        else
            gun.CFrame = root.CFrame
        end
    end
end

task.spawn(function()
    while true do
        if Options.MM2.AutoTPGun and not AmIMurderer() then
            AutoGrabGun()
        end
        task.wait(0.1)
    end
end)

local function showVillonNotice(txt)
    StarterGui:SetCore("SendNotification", {
        Title = "VillonHub",
        Text = txt,
        Duration = 3
    })
end

local function setCharacterTransparency(char, val)
    for _, p in ipairs(char:GetDescendants()) do
        if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" then
            p.Transparency = val
        end
    end
end

local function toggleInvisibilityLogic(state)
    Options.MM2.Invisibility = state
    local char = LocalPlayer.Character
    if char then
        if state then
            setCharacterTransparency(char, 0.5)
            local savedpos = char.HumanoidRootPart.CFrame
            task.wait()
            char:MoveTo(Vector3.new(-25.95, 84, 3537.55))
            task.wait(0.15)
            local Seat = Instance.new("Seat", workspace)
            Seat.Anchored = false
            Seat.CanCollide = false
            Seat.Name = "invischair"
            Seat.Transparency = 1
            Seat.Position = Vector3.new(-25.95, 84, 3537.55)
            local Weld = Instance.new("Weld", Seat)
            Weld.Part0 = Seat
            Weld.Part1 = char:FindFirstChild("Torso") or char:FindFirstChild("UpperTorso")
            Seat.CFrame = savedpos
            showVillonNotice("Invisible ENABLED")
        else
            setCharacterTransparency(char, 0)
            if workspace:FindFirstChild("invischair") then
                workspace.invischair:Destroy()
            end
            showVillonNotice("Invisible DISABLED")
        end
    end
end

--// Kill All / Kill Sheriff
local function throwKnifeAtTarget(targetPlayer)
    local char = LocalPlayer.Character
    if not char then return end
    local knife = char:FindFirstChild("Knife")
    if not knife then
        if not equipKnife() then return end
        knife = char:FindFirstChild("Knife")
        if not knife then return end
    end
    local events = knife:FindFirstChild("Events")
    if not events then return end
    local knifeThrown = events:FindFirstChild("KnifeThrown")
    if not knifeThrown or not knifeThrown:IsA("RemoteEvent") then return end
    local targetChar = targetPlayer.Character
    if not targetChar then return end
    local targetRoot = targetChar:FindFirstChild("HumanoidRootPart") or targetChar:FindFirstChild("Torso")
    if not targetRoot then return end
    local targetPos = targetRoot.Position
    local vel = targetRoot.AssemblyLinearVelocity
    local myRoot = char:FindFirstChild("HumanoidRootPart")
    if myRoot then
        local dist = (targetPos - myRoot.Position).Magnitude
        local travelTime = dist / CONFIG_SM.BulletSpeed
        if CONFIG_SM.PingCompensation then
            local pingMs = getPing()
            travelTime = travelTime + math.min(pingMs / 1000 * 0.5, 0.1)
        end
        local prediction = vel * travelTime * CONFIG_SM.PredictionFactor
        if prediction.Magnitude > CONFIG_SM.MaxHorizontalPrediction then
            prediction = prediction.Unit * CONFIG_SM.MaxHorizontalPrediction
        end
        targetPos = targetPos + prediction
    end
    local knifeCFrame = knife:FindFirstChild("Handle") and knife.Handle.CFrame or knife.CFrame
    local targetCFrame = CFrame.new(targetPos)
    pcall(function()
        knifeThrown:FireServer(knifeCFrame, targetCFrame)
    end)
end

local function killPlayer(targetPlayer)
    local char = LocalPlayer.Character
    if not char then return false end
    local knife = char:FindFirstChild("Knife")
    if not knife then
        if not equipKnife() then return false end
        knife = char:FindFirstChild("Knife")
        if not knife then return false end
    end
    local targetChar = targetPlayer.Character
    if not targetChar then return false end
    local targetRoot = targetChar:FindFirstChild("HumanoidRootPart") or targetChar:FindFirstChild("Torso")
    if not targetRoot then return false end
    local targetHum = targetChar:FindFirstChildOfClass("Humanoid")
    if not targetHum or targetHum.Health <= 0 then return true
    end
    local myRoot = char:FindFirstChild("HumanoidRootPart")
    if not myRoot then return false end
    local startPosition = myRoot.CFrame
    local attempts = 0
    while targetHum and targetHum.Health > 0 and attempts < 10 do
        attempts = attempts + 1
        myRoot.CFrame = targetRoot.CFrame * CFrame.new(0, 1, 1.5)
        wait(0.05)
        for i = 1, 3 do
            knife:Activate()
            wait(0.08)
            targetHum = targetChar:FindFirstChildOfClass("Humanoid")
            if not targetHum or targetHum.Health <= 0 then
                break
            end
        end
        if targetHum and targetHum.Health > 0 then
            throwKnifeAtTarget(targetPlayer)
            wait(0.1)
            targetHum = targetChar:FindFirstChildOfClass("Humanoid")
        end
        if targetHum and targetHum.Health > 0 then
            wait(0.1)
        end
    end
    myRoot.CFrame = startPosition
    myRoot.Velocity = Vector3.new(0,0,0)
    myRoot.RotVelocity = Vector3.new(0,0,0)
    return true
end

local function KillAll()
    if not AmIMurderer() then
        showVillonNotice("Ты не убийца!")
        return
    end
    local targets = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then
            local role = cachedRoles[p.Name]
            if role and role ~= "Default" then
                local charP = p.Character
                if charP and charP:FindFirstChild("Humanoid") and charP.Humanoid.Health > 0 then
                    table.insert(targets, p)
                end
            end
        end
    end
    if #targets == 0 then
        showVillonNotice("Нет живых игроков")
        return
    end
    showVillonNotice("Убиваем " .. #targets .. " целей")
    for _, target in ipairs(targets) do
        killPlayer(target)
        wait(0.05)
    end
    showVillonNotice("Все цели убиты!")
end

local function KillSheriff()
    if not AmIMurderer() then
        showVillonNotice("Ты не убийца!")
        return
    end
    local sheriffTarget = nil
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then
            local role = cachedRoles[p.Name]
            if role == "Sheriff" or role == "Hero" then
                local charP = p.Character
                if charP and charP:FindFirstChild("Humanoid") and charP.Humanoid.Health > 0 then
                    sheriffTarget = p
                    break
                end
            end
        end
    end
    if not sheriffTarget then
        showVillonNotice("Шериф/Герой не найден")
        return
    end
    showVillonNotice("Убиваем " .. sheriffTarget.Name)
    killPlayer(sheriffTarget)
    showVillonNotice("Шериф/Герой убит!")
end

--// Математика Aimbot
local function CheckWallVisibility(part, character)
    if not Options.Aimbot.WallCheck then return true end
    local raycastParams = RaycastParams.new()
    raycastParams.FilterDescendantsInstances = {LocalPlayer.Character, character}
    raycastParams.FilterType = Enum.RaycastFilterType.Exclude
    local ray = Workspace:Raycast(Camera.CFrame.Position, part.Position - Camera.CFrame.Position, raycastParams)
    return ray == nil
end

local function FetchValidTarget()
    local closestPlayer = nil
    local maxDistance = Options.Aimbot.Radius
    if Options.MM2.AimMurderOnly then
        local murderer = GetCurrentMurderer()
        if murderer then
            local targetPart = murderer:FindFirstChild(Options.Aimbot.TargetPart) or GetTorso(murderer)
            local human = murderer:FindFirstChildOfClass("Humanoid")
            if targetPart and human and human.Health > 0 then
                local screenPos, onScreen = Camera:WorldToViewportPoint(targetPart.Position)
                if onScreen then
                    local distance = (Vector2.new(screenPos.X, screenPos.Y) - ScreenCenter).Magnitude
                    if distance < maxDistance and CheckWallVisibility(targetPart, murderer) then
                        return Players:GetPlayerFromCharacter(murderer)
                    end
                end
            end
        end
        return nil
    end
    for _, player in ipairs(Players:GetPlayers()) do
        if player == LocalPlayer then continue end
        local char = player.Character
        if char then
            local targetPart = char:FindFirstChild(Options.Aimbot.TargetPart) or GetTorso(char)
            local human = char:FindFirstChildOfClass("Humanoid")
            if targetPart and human and human.Health > 0 then
                if Options.Aimbot.TeamCheck and player.Team == LocalPlayer.Team and not Options.MM2.RoleESP then continue end
                local screenPos, onScreen = Camera:WorldToViewportPoint(targetPart.Position)
                if onScreen then
                    local distance = (Vector2.new(screenPos.X, screenPos.Y) - ScreenCenter).Magnitude
                    if distance < maxDistance and CheckWallVisibility(targetPart, char) then
                        maxDistance = distance
                        closestPlayer = player
                    end
                end
            end
        end
    end
    return closestPlayer
end

--// ESP
local function InitializeVisualData(player)
    if VisualStorage[player] or player == LocalPlayer then return end
    VisualStorage[player] = {
        Box = Drawing.new("Square"),
        Name = Drawing.new("Text"),
        HealthBar = Drawing.new("Line"),
        Tracer = Drawing.new("Line"),
        Highlight = nil,
        Skeleton = {
            HeadToTorso = Drawing.new("Line"),
            TorsoToLeftArm = Drawing.new("Line"),
            TorsoToRightArm = Drawing.new("Line"),
            TorsoToLeftLeg = Drawing.new("Line"),
            TorsoToRightLeg = Drawing.new("Line")
        }
    }
    local storage = VisualStorage[player]
    storage.Box.Thickness = 1
    storage.Box.Filled = false
    storage.Name.Size = 10
    storage.Name.Center = true
    storage.Name.Outline = true
    storage.Name.Color = Color3.fromRGB(255, 255, 255)
    storage.HealthBar.Thickness = 2
    storage.Tracer.Thickness = 1
    for _, bone in pairs(storage.Skeleton) do
        bone.Thickness = 1
        bone.Color = Options.Visuals.SkeletonColor
    end
end

local function ClearVisualData(player)
    if VisualStorage[player] then
        for _, obj in pairs(VisualStorage[player]) do
            if type(obj) == "table" then
                for _, bone in pairs(obj) do bone:Remove() end
            elseif type(obj) == "userdata" and obj.Remove then
                obj:Remove()
            end
        end
        if VisualStorage[player].Highlight then
            VisualStorage[player].Highlight:Destroy()
        end
        VisualStorage[player] = nil
    end
end

local pAddedCon = Players.PlayerAdded:Connect(InitializeVisualData)
local pRemovingCon = Players.PlayerRemoving:Connect(ClearVisualData)
table.insert(Connections, pAddedCon)
table.insert(Connections, pRemovingCon)
for _, p in ipairs(Players:GetPlayers()) do InitializeVisualData(p) end

local function GetMM2RoleColor(player)
    local role = cachedRoles[player.Name] or "Default"
    return roleColors[role] or roleColors.Default
end

--// Рендер-лупы
local lastVisualUpdate = 0

local PhysicsLoop = RunService.Heartbeat:Connect(function()
    local myChar = LocalPlayer.Character
    local myRoot = getRoot(myChar)
    local myHum = myChar and myChar:FindFirstChildOfClass("Humanoid")
    if not myRoot or (myHum and myHum.Health <= 0) then return end

    if Options.MM2.Fling then
        local oldVelocity = myRoot.Velocity
        myRoot.Velocity = Vector3.new(0, 999999, 0)
        myRoot.RotVelocity = Vector3.new(999999, 999999, 999999)
        RunService.RenderStepped:Wait()
        if myRoot then
            myRoot.Velocity = oldVelocity
            myRoot.RotVelocity = Vector3.new(0, 0, 0)
        end
    end

    if Options.Misc.AntiFling then
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer and player.Character then
                local pChar = player.Character
                local pRoot = getRoot(pChar)
                if pRoot and (pRoot.Position - myRoot.Position).Magnitude < 25 then
                    for _, part in ipairs(pChar:GetDescendants()) do
                        if part:IsA("BasePart") then
                            part.CanCollide = false
                            part.Velocity = Vector3.new(0, 0, 0)
                            part.RotVelocity = Vector3.new(0, 0, 0)
                        end
                    end
                end
            end
        end
    end

    if Options.Misc.SpeedGlitchEnabled and jumpPressed then
        local moveDir = myHum.MoveDirection
        if moveDir.Magnitude > 0.1 and myHum.FloorMaterial == Enum.Material.Air then
            local speed = Options.Misc.WalkSpeedEnabled and Options.Misc.WalkSpeedValue or 16
            local boostSpeed = speed * Options.Misc.SpeedGlitchValue
            myRoot.Velocity = Vector3.new(moveDir.X * boostSpeed, myRoot.Velocity.Y, moveDir.Z * boostSpeed)
        end
    end
end)
table.insert(Connections, PhysicsLoop)

local MasterRenderLoop = RunService.RenderStepped:Connect(function()
    local localChar = LocalPlayer.Character
    local hum = localChar and localChar:FindFirstChildOfClass("Humanoid")
    local rootPart = localChar and getRoot(localChar)

    if Options.Aimbot.Enabled then
        local activeTarget = FetchValidTarget()
        if activeTarget and activeTarget.Character then
            local part = activeTarget.Character:FindFirstChild(Options.Aimbot.TargetPart) or GetTorso(activeTarget.Character)
            if part then
                Camera.CFrame = CFrame.new(Camera.CFrame.Position, part.Position)
            end
        end
    end

    if localChar and hum then
        if Options.Misc.WalkSpeedEnabled then
            hum.WalkSpeed = Options.Misc.WalkSpeedValue
        end
        if Options.Misc.FovEnabled then
            Camera.FieldOfView = Options.Misc.FovValue
        end
        if Options.Misc.AspectRatioEnabled then
            pcall(function()
                local targetRatio = Options.Misc.AspectRatioValue
                local currentSize = Camera.ViewportSize
                local currentRatio = currentSize.X / currentSize.Y
                local baseFov = Options.Misc.FovEnabled and Options.Misc.FovValue or 70
                local newFov = baseFov * (currentRatio / targetRatio)
                newFov = math.clamp(newFov, 1, 120)
                Camera.FieldOfView = newFov
            end)
        end
        if Options.MM2.AutoAimMurder then
            local gun = localChar:FindFirstChild("Gun")
            if not gun then equipGun() end
            gun = localChar:FindFirstChild("Gun")
            if gun and gun:FindFirstChild("KnifeLocal") then
                local targetPos = getMurdererTarget()
                if targetPos then
                    pcall(function()
                        gun.KnifeLocal.CreateBeam.RemoteFunction:InvokeServer(1, targetPos, "AH2")
                    end)
                end
            end
        end
        if Options.Misc.SpinBot and rootPart then
            rootPart.CFrame = rootPart.CFrame * CFrame.Angles(0, 0.8, 0)
        end
    end

    -- === ВСЕ КНОПКИ (исправленное создание папки) ===
    local menuFolder = CoreGui:FindFirstChild("VillonHub_MM2_Menu")
    if not menuFolder then
        menuFolder = Instance.new("Folder")
        menuFolder.Name = "VillonHub_MM2_Menu"
        menuFolder.Parent = CoreGui
    end

    -- Кнопка Aim
    if Options.Aimbot.BindButtonEnabled then
        if not menuFolder:FindFirstChild("Aim_BindButton") then
            local AimBindButton = Instance.new("TextButton")
            AimBindButton.Name = "Aim_BindButton"
            AimBindButton.Size = UDim2.new(0, 65, 0, 40)
            AimBindButton.Position = UDim2.new(0.1, 0, 0.45, 0)
            AimBindButton.BackgroundColor3 = Options.Aimbot.Enabled and Color3.fromRGB(0, 180, 255) or Color3.fromRGB(40, 40, 45)
            AimBindButton.Text = "AIM"
            AimBindButton.TextColor3 = Color3.fromRGB(255, 255, 255)
            AimBindButton.Font = Enum.Font.SourceSansBold
            AimBindButton.TextSize = 14
            AimBindButton.Active = true
            AimBindButton.Draggable = IsAimBindEditModeActive
            AimBindButton.Parent = menuFolder
            local ABCorner = Instance.new("UICorner")
            ABCorner.CornerRadius = UDim.new(0, 6)
            ABCorner.Parent = AimBindButton
            AimBindButton.MouseButton1Click:Connect(function()
                if IsAimBindEditModeActive then return end
                Options.Aimbot.Enabled = not Options.Aimbot.Enabled
                FOVCircle.Visible = Options.Aimbot.Enabled
                AimBindButton.BackgroundColor3 = Options.Aimbot.Enabled and Color3.fromRGB(0, 180, 255) or Color3.fromRGB(40, 40, 45)
            end)
        else
            local btn = menuFolder.Aim_BindButton
            btn.Visible = true
            btn.Draggable = IsAimBindEditModeActive
            btn.BackgroundColor3 = Options.Aimbot.Enabled and Color3.fromRGB(0, 180, 255) or Color3.fromRGB(40, 40, 45)
        end
    else
        if menuFolder:FindFirstChild("Aim_BindButton") then
            menuFolder.Aim_BindButton.Visible = false
        end
    end

    -- Кнопка TP GUN
    if Options.MM2.TPGunButtonEnabled then
        if not menuFolder:FindFirstChild("MM2_TPGunButton") then
            local TPGunButton = Instance.new("TextButton")
            TPGunButton.Name = "MM2_TPGunButton"
            TPGunButton.Size = UDim2.new(0, 65, 0, 40)
            TPGunButton.Position = UDim2.new(0.1, 0, 0.55, 0)
            TPGunButton.BackgroundColor3 = Color3.fromRGB(0, 180, 100)
            TPGunButton.Text = "TP GUN"
            TPGunButton.TextColor3 = Color3.fromRGB(255, 255, 255)
            TPGunButton.Font = Enum.Font.SourceSansBold
            TPGunButton.TextSize = 13
            TPGunButton.Active = true
            TPGunButton.Draggable = IsTPGunEditModeActive
            TPGunButton.Parent = menuFolder
            local TPBCorner = Instance.new("UICorner")
            TPBCorner.CornerRadius = UDim.new(0, 6)
            TPBCorner.Parent = TPGunButton
            TPGunButton.MouseButton1Click:Connect(function()
                if IsTPGunEditModeActive then return end
                if AmIMurderer() then return end
                local targetGun = Workspace:FindFirstChild("GunDrop", true)
                if targetGun and rootPart then
                    if firetouchinterest then
                        firetouchinterest(rootPart, targetGun, 0)
                        firetouchinterest(rootPart, targetGun, 1)
                    else
                        targetGun.CFrame = rootPart.CFrame
                    end
                end
            end)
        else
            menuFolder.MM2_TPGunButton.Visible = true
            menuFolder.MM2_TPGunButton.Draggable = IsTPGunEditModeActive
        end
    else
        if menuFolder:FindFirstChild("MM2_TPGunButton") then
            menuFolder.MM2_TPGunButton.Visible = false
        end
    end

    -- Кнопка INVIS
    if Options.MM2.InvisButtonEnabled then
        if not menuFolder:FindFirstChild("MM2_InvisButton") then
            local InvisButton = Instance.new("TextButton")
            InvisButton.Name = "MM2_InvisButton"
            InvisButton.Size = UDim2.new(0, 65, 0, 40)
            InvisButton.Position = UDim2.new(0.1, 0, 0.65, 0)
            InvisButton.BackgroundColor3 = Options.MM2.Invisibility and Color3.fromRGB(120, 0, 200) or Color3.fromRGB(40, 40, 45)
            InvisButton.Text = "INVIS"
            InvisButton.TextColor3 = Color3.fromRGB(255, 255, 255)
            InvisButton.Font = Enum.Font.SourceSansBold
            InvisButton.TextSize = 13
            InvisButton.Active = true
            InvisButton.Draggable = IsInvisEditModeActive
            InvisButton.Parent = menuFolder
            local InvCorner = Instance.new("UICorner")
            InvCorner.CornerRadius = UDim.new(0, 6)
            InvCorner.Parent = InvisButton
            InvisButton.MouseButton1Click:Connect(function()
                if IsInvisEditModeActive then return end
                toggleInvisibilityLogic(not Options.MM2.Invisibility)
                InvisButton.BackgroundColor3 = Options.MM2.Invisibility and Color3.fromRGB(120, 0, 200) or Color3.fromRGB(40, 40, 45)
            end)
        else
            menuFolder.MM2_InvisButton.Visible = true
            menuFolder.MM2_InvisButton.Draggable = IsInvisEditModeActive
            menuFolder.MM2_InvisButton.BackgroundColor3 = Options.MM2.Invisibility and Color3.fromRGB(120, 0, 200) or Color3.fromRGB(40, 40, 45)
        end
    else
        if menuFolder:FindFirstChild("MM2_InvisButton") then
            menuFolder.MM2_InvisButton.Visible = false
        end
    end

    -- Кнопка FLING
    if Options.MM2.FlingButtonEnabled then
        if not menuFolder:FindFirstChild("MM2_FlingButton") then
            local FlingButton = Instance.new("TextButton")
            FlingButton.Name = "MM2_FlingButton"
            FlingButton.Size = UDim2.new(0, 65, 0, 40)
            FlingButton.Position = UDim2.new(0.1, 0, 0.75, 0)
            FlingButton.BackgroundColor3 = Options.MM2.Fling and Color3.fromRGB(230, 100, 0) or Color3.fromRGB(40, 40, 45)
            FlingButton.Text = "FLING"
            FlingButton.TextColor3 = Color3.fromRGB(255, 255, 255)
            FlingButton.Font = Enum.Font.SourceSansBold
            FlingButton.TextSize = 13
            FlingButton.Active = true
            FlingButton.Draggable = IsFlingEditModeActive
            FlingButton.Parent = menuFolder
            local FlCorner = Instance.new("UICorner")
            FlCorner.CornerRadius = UDim.new(0, 6)
            FlCorner.Parent = FlingButton
            FlingButton.MouseButton1Click:Connect(function()
                if IsFlingEditModeActive then return end
                Options.MM2.Fling = not Options.MM2.Fling
                FlingButton.BackgroundColor3 = Options.MM2.Fling and Color3.fromRGB(230, 100, 0) or Color3.fromRGB(40, 40, 45)
                showVillonNotice(Options.MM2.Fling and "Fling Mode ENABLED" or "Fling Mode DISABLED")
            end)
        else
            menuFolder.MM2_FlingButton.Visible = true
            menuFolder.MM2_FlingButton.Draggable = IsFlingEditModeActive
            menuFolder.MM2_FlingButton.BackgroundColor3 = Options.MM2.Fling and Color3.fromRGB(230, 100, 0) or Color3.fromRGB(40, 40, 45)
        end
    else
        if menuFolder:FindFirstChild("MM2_FlingButton") then
            menuFolder.MM2_FlingButton.Visible = false
        end
    end

    -- КНОПКА SHOOT MURDER (финальная)
    if Options.MM2.ShootMurderButtonEnabled then
        if not menuFolder:FindFirstChild("MM2_ShootMurderButton") then
            local ShootMurderButton = Instance.new("TextButton")
            ShootMurderButton.Name = "MM2_ShootMurderButton"
            ShootMurderButton.Size = UDim2.new(0, 150, 0, 55)
            ShootMurderButton.Position = UDim2.new(0.5, -75, 0.8, -27.5)
            ShootMurderButton.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
            ShootMurderButton.BackgroundTransparency = 0.2
            ShootMurderButton.Text = "SHOOT MURDER"
            ShootMurderButton.TextColor3 = Color3.new(1, 1, 1)
            ShootMurderButton.Font = Enum.Font.SourceSansBold
            ShootMurderButton.TextSize = 16
            ShootMurderButton.Active = true
            ShootMurderButton.Draggable = IsShootMurderEditModeActive
            ShootMurderButton.Parent = menuFolder
            local SMBCorner = Instance.new("UICorner")
            SMBCorner.CornerRadius = UDim.new(0, 10)
            SMBCorner.Parent = ShootMurderButton
            local SMBStroke = Instance.new("UIStroke")
            SMBStroke.Color = Color3.fromRGB(200, 200, 200)
            SMBStroke.Thickness = 1.5
            SMBStroke.Parent = ShootMurderButton
            ShootMurderButton.MouseButton1Click:Connect(function()
                if IsShootMurderEditModeActive then return end
                local char = LocalPlayer.Character
                if not char then return end
                local gun = char:FindFirstChild("Gun")
                if not gun then
                    if not equipGun() then return end
                    gun = char:FindFirstChild("Gun")
                    if not gun then return end
                end
                local targetPos = getMurdererTarget()
                if not targetPos then
                    StarterGui:SetCore("SendNotification", {
                        Title = "Ошибка",
                        Text = "Убийца не найден!",
                        Duration = 2
                    })
                    return
                end
                local remote = gun:FindFirstChild("KnifeLocal") and gun.KnifeLocal:FindFirstChild("CreateBeam") and gun.KnifeLocal.CreateBeam:FindFirstChild("RemoteFunction")
                if remote then
                    pcall(function()
                        remote:InvokeServer(1, targetPos, "AH2")
                    end)
                else
                    local shoot = gun:FindFirstChild("Shoot")
                    if shoot then
                        local gunCFrame = gun:FindFirstChild("Handle") and gun.Handle.CFrame or gun.CFrame
                        pcall(function()
                            shoot:FireServer(gunCFrame, CFrame.new(targetPos))
                        end)
                    end
                end
            end)
        else
            menuFolder.MM2_ShootMurderButton.Visible = true
            menuFolder.MM2_ShootMurderButton.Draggable = IsShootMurderEditModeActive
        end
    else
        if menuFolder:FindFirstChild("MM2_ShootMurderButton") then
            menuFolder.MM2_ShootMurderButton.Visible = false
        end
    end

    -- КНОПКА THROW KNIFE
    if Options.MM2.ThrowKnifeButtonEnabled then
        if not menuFolder:FindFirstChild("MM2_ThrowKnifeButton") then
            local ThrowKnifeButton = Instance.new("TextButton")
            ThrowKnifeButton.Name = "MM2_ThrowKnifeButton"
            ThrowKnifeButton.Size = UDim2.new(0, 150, 0, 55)
            ThrowKnifeButton.Position = UDim2.new(0.5, -230, 0.8, -27.5)
            ThrowKnifeButton.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
            ThrowKnifeButton.BackgroundTransparency = 0.2
            ThrowKnifeButton.Text = "THROW KNIFE"
            ThrowKnifeButton.TextColor3 = Color3.new(1, 1, 1)
            ThrowKnifeButton.Font = Enum.Font.SourceSansBold
            ThrowKnifeButton.TextSize = 16
            ThrowKnifeButton.Active = true
            ThrowKnifeButton.Draggable = IsThrowKnifeEditModeActive
            ThrowKnifeButton.Parent = menuFolder
            local TKBCorner = Instance.new("UICorner")
            TKBCorner.CornerRadius = UDim.new(0, 10)
            TKBCorner.Parent = ThrowKnifeButton
            local TKBStroke = Instance.new("UIStroke")
            TKBStroke.Color = Color3.fromRGB(200, 200, 200)
            TKBStroke.Thickness = 1.5
            TKBStroke.Parent = ThrowKnifeButton
            ThrowKnifeButton.MouseButton1Click:Connect(function()
                if IsThrowKnifeEditModeActive then return end
                throwKnifeToClosest()
            end)
        else
            menuFolder.MM2_ThrowKnifeButton.Visible = true
            menuFolder.MM2_ThrowKnifeButton.Draggable = IsThrowKnifeEditModeActive
        end
    else
        if menuFolder:FindFirstChild("MM2_ThrowKnifeButton") then
            menuFolder.MM2_ThrowKnifeButton.Visible = false
        end
    end

    -- КНОПКА KILL ALL
    if Options.MM2.KillAllButtonEnabled then
        if not menuFolder:FindFirstChild("KillAllButton") then
            local KillAllBtn = Instance.new("TextButton")
            KillAllBtn.Name = "KillAllButton"
            KillAllBtn.Size = UDim2.new(0, 130, 0, 45)
            KillAllBtn.Position = UDim2.new(0.02, 0, 0.35, 0)
            KillAllBtn.BackgroundColor3 = Color3.fromRGB(200, 30, 30)
            KillAllBtn.Text = "KILL ALL"
            KillAllBtn.TextColor3 = Color3.new(1,1,1)
            KillAllBtn.Font = Enum.Font.SourceSansBold
            KillAllBtn.TextSize = 14
            KillAllBtn.Active = true
            KillAllBtn.Draggable = IsKillAllEditModeActive
            KillAllBtn.Parent = menuFolder
            local corner = Instance.new("UICorner")
            corner.CornerRadius = UDim.new(0, 6)
            corner.Parent = KillAllBtn
            KillAllBtn.MouseButton1Click:Connect(function()
                if IsKillAllEditModeActive then return end
                KillAll()
            end)
        else
            menuFolder.KillAllButton.Visible = true
            menuFolder.KillAllButton.Draggable = IsKillAllEditModeActive
        end
    else
        if menuFolder:FindFirstChild("KillAllButton") then
            menuFolder.KillAllButton.Visible = false
        end
    end

    -- КНОПКА KILL SHERIFF
    if Options.MM2.KillSheriffButtonEnabled then
        if not menuFolder:FindFirstChild("KillSheriffButton") then
            local KillSheriffBtn = Instance.new("TextButton")
            KillSheriffBtn.Name = "KillSheriffButton"
            KillSheriffBtn.Size = UDim2.new(0, 130, 0, 45)
            KillSheriffBtn.Position = UDim2.new(0.02, 0, 0.43, 0)
            KillSheriffBtn.BackgroundColor3 = Color3.fromRGB(0, 80, 200)
            KillSheriffBtn.Text = "KILL SHERIFF"
            KillSheriffBtn.TextColor3 = Color3.new(1,1,1)
            KillSheriffBtn.Font = Enum.Font.SourceSansBold
            KillSheriffBtn.TextSize = 14
            KillSheriffBtn.Active = true
            KillSheriffBtn.Draggable = IsKillSheriffEditModeActive
            KillSheriffBtn.Parent = menuFolder
            local corner = Instance.new("UICorner")
            corner.CornerRadius = UDim.new(0, 6)
            corner.Parent = KillSheriffBtn
            KillSheriffBtn.MouseButton1Click:Connect(function()
                if IsKillSheriffEditModeActive then return end
                KillSheriff()
            end)
        else
            menuFolder.KillSheriffButton.Visible = true
            menuFolder.KillSheriffButton.Draggable = IsKillSheriffEditModeActive
        end
    else
        if menuFolder:FindFirstChild("KillSheriffButton") then
            menuFolder.KillSheriffButton.Visible = false
        end
    end

    -- JERK OFF
    if Options.MM2.JerkOffEnabled then
        task.spawn(function()
            local player = LocalPlayer
            local char = player.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            local backpack = player:FindFirstChild("Backpack")
            if not hum or not backpack then return end
            if not backpack:FindFirstChild("Jerk Off") then
                local tool = Instance.new("Tool")
                tool.Name = "Jerk Off"
                tool.ToolTip = "in the stripped club. straight up \"jorking it\" . and by \"it\" , haha, well. let's just say. My peanits."
                tool.RequiresHandle = false
                tool.Parent = backpack
                local jorkin = false
                local track = nil
                local function stopTomfoolery()
                    jorkin = false
                    if track then
                        track:Stop()
                        track = nil
                    end
                end
                tool.Equipped:Connect(function() jorkin = true end)
                tool.Unequipped:Connect(stopTomfoolery)
                hum.Died:Connect(stopTomfoolery)
                spawn(function()
                    while task.wait() do
                        if not jorkin then continue end
                        local isR15 = char and char.Humanoid.RigType == Enum.HumanoidRigType.R15
                        if not track then
                            local anim = Instance.new("Animation")
                            anim.AnimationId = not isR15 and "rbxassetid://72042024" or "rbxassetid://698251653"
                            track = hum:LoadAnimation(anim)
                        end
                        track:Play()
                        track:AdjustSpeed(isR15 and 1.2 or 1.1)
                        track.TimePosition = 0.6
                        task.wait(0.1)
                        while track and track.TimePosition < (not isR15 and 0.65 or 0.7) do
                            task.wait(0.1)
                        end
                        if track then
                            track:Stop()
                            track = nil
                        end
                    end
                end)
                player.CharacterAdded:Connect(function(newChar)
                    task.wait(0.5)
                    local newBackpack = player:FindFirstChild("Backpack")
                    if newBackpack and not newBackpack:FindFirstChild("Jerk Off") then
                        local newTool = Instance.new("Tool")
                        newTool.Name = "Jerk Off"
                        newTool.ToolTip = tool.ToolTip
                        newTool.RequiresHandle = false
                        newTool.Parent = newBackpack
                    end
                end)
            end
        end)
    else
        local backpack = LocalPlayer:FindFirstChild("Backpack")
        if backpack then
            local tool = backpack:FindFirstChild("Jerk Off")
            if tool then tool:Destroy() end
        end
    end

    -- GUN ESP
    local gunDrop = Workspace:FindFirstChild("GunDrop", true)
    if Options.MM2.GunESP and gunDrop then
        if not gunDrop:FindFirstChild("GunHighlight") then
            local gunh = Instance.new("Highlight")
            gunh.Name = "GunHighlight"
            gunh.FillColor = Color3.new(1, 1, 0)
            gunh.OutlineColor = Color3.new(1, 1, 1)
            gunh.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
            gunh.FillTransparency = 0.4
            gunh.OutlineTransparency = 0.5
            gunh.Parent = gunDrop
        end
        if not gunDrop:FindFirstChild("GunEsp") then
            local esp = Instance.new("BillboardGui")
            esp.Name = "GunEsp"
            esp.Adornee = gunDrop
            esp.Size = UDim2.new(5, 0, 5, 0)
            esp.AlwaysOnTop = true
            local text = Instance.new("TextLabel")
            text.Name = "GunLabel"
            text.Size = UDim2.new(1, 0, 1, 0)
            text.BackgroundTransparency = 1
            text.TextStrokeTransparency = 0
            text.TextColor3 = Color3.fromRGB(255, 255, 0)
            text.Font = Enum.Font.FredokaOne
            text.TextSize = 16
            text.Text = "Gun Drop"
            text.Parent = esp
            esp.Parent = gunDrop
        end
    else
        if gunDrop then
            if gunDrop:FindFirstChild("GunHighlight") then gunDrop.GunHighlight:Destroy() end
            if gunDrop:FindFirstChild("GunEsp") then gunDrop.GunEsp:Destroy() end
        end
    end

    -- ESP игроков
    local currentTime = os.clock()
    if (currentTime - lastVisualUpdate) < Options.Visuals.UpdateRate then return end
    lastVisualUpdate = currentTime
    for player, storage in pairs(VisualStorage) do
        if type(player) == "string" then continue end
        local char = player.Character
        if char then
            local root = getRoot(char)
            local head = char:FindFirstChild("Head")
            local human = char:FindFirstChildOfClass("Humanoid")
            if root and head and human and human.Health > 0 then
                local currentBoxColor = Options.Visuals.BoxColor
                if Options.MM2.RoleESP then
                    currentBoxColor = GetMM2RoleColor(player)
                end
                local isTeammate = Options.Visuals.TeamCheck and player.Team == LocalPlayer.Team and not Options.MM2.RoleESP
                if isTeammate then
                    storage.Box.Visible = false; storage.Name.Visible = false; storage.HealthBar.Visible = false; storage.Tracer.Visible = false
                    for _, bone in pairs(storage.Skeleton) do bone.Visible = false end
                    if storage.Highlight then storage.Highlight.Enabled = false end
                    continue
                end
                if Options.Visuals.Chams or Options.MM2.RoleESP then
                    if not storage.Highlight then
                        storage.Highlight = Instance.new("Highlight")
                        storage.Highlight.Parent = CoreGui
                    end
                    storage.Highlight.Adornee = char
                    storage.Highlight.FillColor = Options.MM2.RoleESP and GetMM2RoleColor(player) or Options.Visuals.ChamsColor
                    storage.Highlight.FillTransparency = 0.4
                    if Options.MM2.RoleESP then
                        storage.Highlight.OutlineTransparency = 1
                    else
                        storage.Highlight.OutlineTransparency = 0
                        storage.Highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
                    end
                    storage.Highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                    storage.Highlight.Enabled = true
                else
                    if storage.Highlight then storage.Highlight.Enabled = false end
                end
                local rootPos, rootOn = Camera:WorldToViewportPoint(root.Position)
                local headPos, headOn = Camera:WorldToViewportPoint(head.Position + Vector3.new(0, 0.5, 0))
                local legPos, legOn = Camera:WorldToViewportPoint(root.Position - Vector3.new(0, 3, 0))
                if rootOn and headOn and legOn then
                    local bHeight = math.abs(headPos.Y - legPos.Y)
                    local bWidth = bHeight / 1.8
                    if Options.Visuals.Boxes and not Options.MM2.RoleESP then
                        storage.Box.Size = Vector2.new(bWidth, bHeight)
                        storage.Box.Position = Vector2.new(rootPos.X - bWidth / 2, headPos.Y)
                        storage.Box.Color = currentBoxColor
                        storage.Box.Visible = true
                    else
                        storage.Box.Visible = false
                    end
                    if Options.Visuals.Names then
                        if Options.MM2.RoleESP then
                            local roleName = cachedRoles[player.Name] or "Innocent"
                            storage.Name.Text = ("Role: %s • Name: %s"):format(roleName, player.Name)
                            storage.Name.Color = GetMM2RoleColor(player)
                        else
                            storage.Name.Text = player.Name
                            storage.Name.Color = Color3.fromRGB(255, 255, 255)
                        end
                        storage.Name.Position = Vector2.new(rootPos.X, headPos.Y - 15)
                        storage.Name.Visible = true
                    else storage.Name.Visible = false end
                    if Options.Visuals.HealthBar then
                        local pct = human.Health / human.MaxHealth
                        storage.HealthBar.From = Vector2.new(rootPos.X - bWidth / 2 - 5, legPos.Y)
                        storage.HealthBar.To = Vector2.new(rootPos.X - bWidth / 2 - 5, legPos.Y - (bHeight * pct))
                        storage.HealthBar.Color = Color3.fromRGB(255 * (1 - pct), 255 * pct, 0)
                        storage.HealthBar.Visible = true
                    else storage.HealthBar.Visible = false end
                    if Options.Visuals.Tracers then
                        storage.Tracer.From = Vector2.new(ScreenCenter.X, ScreenCenter.Y * 2)
                        storage.Tracer.To = Vector2.new(rootPos.X, legPos.Y)
                        storage.Tracer.Color = currentBoxColor
                        storage.Tracer.Thickness = 1
                        storage.Tracer.Visible = true
                    else storage.Tracer.Visible = false end
                    if Options.Visuals.Skeletons and char:FindFirstChild("LeftUpperArm") and char:FindFirstChild("RightUpperArm") then
                        local function GetBoneVector(partName)
                            local p = char[partName]
                            local pos, on = Camera:WorldToViewportPoint(p.Position)
                            return Vector2.new(pos.X, pos.Y)
                        end
                        storage.Skeleton.HeadToTorso.From = Vector2.new(headPos.X, headPos.Y)
                        storage.Skeleton.HeadToTorso.To = Vector2.new(rootPos.X, rootPos.Y); storage.Skeleton.HeadToTorso.Visible = true
                        storage.Skeleton.TorsoToLeftArm.From = Vector2.new(rootPos.X, rootPos.Y)
                        storage.Skeleton.TorsoToLeftArm.To = GetBoneVector("LeftUpperArm"); storage.Skeleton.TorsoToLeftArm.Visible = true
                        storage.Skeleton.TorsoToRightArm.From = Vector2.new(rootPos.X, rootPos.Y)
                        storage.Skeleton.TorsoToRightArm.To = GetBoneVector("RightUpperArm"); storage.Skeleton.TorsoToRightArm.Visible = true
                        storage.Skeleton.TorsoToLeftLeg.From = Vector2.new(rootPos.X, rootPos.Y)
                        storage.Skeleton.TorsoToLeftLeg.To = Vector2.new(rootPos.X - bWidth/4, legPos.Y); storage.Skeleton.TorsoToLeftLeg.Visible = true
                        storage.Skeleton.TorsoToRightLeg.From = Vector2.new(rootPos.X, rootPos.Y)
                        storage.Skeleton.TorsoToRightLeg.To = Vector2.new(rootPos.X + bWidth/4, legPos.Y); storage.Skeleton.TorsoToRightLeg.Visible = true
                    else
                        for _, bone in pairs(storage.Skeleton) do bone.Visible = false end
                    end
                else
                    storage.Box.Visible = false; storage.Name.Visible = false; storage.HealthBar.Visible = false; storage.Tracer.Visible = false
                    for _, bone in pairs(storage.Skeleton) do bone.Visible = false end
                    if storage.Highlight then storage.Highlight.Enabled = false end
                end
            else
                storage.Box.Visible = false; storage.Name.Visible = false; storage.HealthBar.Visible = false; storage.Tracer.Visible = false
                for _, bone in pairs(storage.Skeleton) do bone.Visible = false end
                if storage.Highlight then storage.Highlight.Enabled = false end
            end
        else
            storage.Box.Visible = false; storage.Name.Visible = false; storage.HealthBar.Visible = false; storage.Tracer.Visible = false
            for _, bone in pairs(storage.Skeleton) do bone.Visible = false end
            if storage.Highlight then storage.Highlight.Enabled = false end
        end
    end
end)
table.insert(Connections, MasterRenderLoop)

-- ============================================
-- GUI — WINDUI (загрузка с отладкой)
-- ============================================
showVillonNotice("Загрузка WindUI...")

local WindUI = nil
local loadSuccess, err = pcall(function()
    WindUI = loadstring(game:HttpGet("https://raw.githubusercontent.com/Footagesus/WindUI/main/dist/main.lua"))()
end)

if not loadSuccess or not WindUI then
    showVillonNotice("Ошибка загрузки WindUI: " .. tostring(err))
    warn("WindUI не загрузился:", err)
    return
end

showVillonNotice("WindUI загружен, создаём окно...")

local Window = WindUI:CreateWindow({
    Title = "VillonHub",
    Icon = "",
    Size = { 600, 400 },
    Resizable = false,
    Theme = "Dark"
})

showVillonNotice("Окно создано, добавляем вкладки...")

--// Вкладки
local TabAimbot = Window:Tab({ Title = "Combat (Aim)", Icon = "" })
local TabVisuals = Window:Tab({ Title = "Visuals (ESP)", Icon = "" })
local TabMM2 = Window:Tab({ Title = "MM2", Icon = "" })
local TabMisc = Window:Tab({ Title = "Misc", Icon = "" })
local TabConfigs = Window:Tab({ Title = "Configs", Icon = "" })
local TabChangeFling = Window:Tab({ Title = "Change Fling", Icon = "" })

--// Функция для создания тоггла
local function CreateToggle(tab, text, configTable, configKey)
    local toggle = tab:Toggle({
        Title = text,
        Default = Options[configTable][configKey],
        Callback = function(value)
            Options[configTable][configKey] = value
            if configKey == "Enabled" then
                FOVCircle.Visible = value
            end
            if configTable == "MM2" and configKey == "Invisibility" then
                toggleInvisibilityLogic(value)
            end
            if configTable == "MM2" and configKey == "Fling" then
                showVillonNotice(value and "Touch Fling Mode ACTIVE" or "Touch Fling Mode DISABLED")
            end
            if configTable == "MM2" and configKey == "FlingMurder" and value then
                task.spawn(function()
                    FlingMurderer()
                    Options.MM2.FlingMurder = false
                    toggle:SetDefault(false)
                end)
            end
            if configTable == "MM2" and configKey == "FlingSheriff" and value then
                task.spawn(function()
                    FlingSheriff()
                    Options.MM2.FlingSheriff = false
                    toggle:SetDefault(false)
                end)
            end
        end
    })
    return toggle
end

local function CreateNumericInput(tab, text, configTable, configKey, min, max)
    tab:Input({
        Title = text,
        Default = tostring(Options[configTable][configKey]),
        Placeholder = "Значение",
        Callback = function(value)
            local num = tonumber(value)
            if num then
                Options[configTable][configKey] = num
                if configKey == "Radius" then FOVCircle.Radius = num end
            end
        end
    })
end

--// Aimbot
CreateToggle(TabAimbot, "Enable Hard Aim", "Aimbot", "Enabled")
CreateToggle(TabAimbot, "Show Aim Bind Button", "Aimbot", "BindButtonEnabled")
TabAimbot:Button({
    Title = "Edit AIM Button Position",
    Callback = function()
        IsAimBindEditModeActive = not IsAimBindEditModeActive
        showVillonNotice(IsAimBindEditModeActive and "Режим настройки: Перетащите кнопку AIM!" or "Положение кнопки AIM зафиксировано.")
        local folder = CoreGui:FindFirstChild("VillonHub_MM2_Menu")
        if folder then
            local btn = folder:FindFirstChild("Aim_BindButton")
            if btn then
                btn.Draggable = IsAimBindEditModeActive
                btn.BorderSizePixel = IsAimBindEditModeActive and 1 or 0
                btn.BorderColor3 = Color3.fromRGB(0, 150, 255)
            end
        end
    end
})
CreateToggle(TabAimbot, "Team Check", "Aimbot", "TeamCheck")
CreateToggle(TabAimbot, "Wall Check", "Aimbot", "WallCheck")
TabAimbot:Dropdown({
    Title = "Aim Target Part",
    Options = { "Torso", "Head", "LeftFoot" },
    Default = Options.Aimbot.TargetPart,
    Callback = function(value)
        Options.Aimbot.TargetPart = value
    end
})
CreateNumericInput(TabAimbot, "FOV Radius Size", "Aimbot", "Radius", 1, 500)

--// Visuals
CreateToggle(TabVisuals, "Boxes ESP", "Visuals", "Boxes")
CreateToggle(TabVisuals, "Skeletons ESP", "Visuals", "Skeletons")
CreateToggle(TabVisuals, "Chams Style", "Visuals", "Chams")
CreateToggle(TabVisuals, "Names Rendering", "Visuals", "Names")
CreateToggle(TabVisuals, "Health Bar Indicators", "Visuals", "HealthBar")
CreateToggle(TabVisuals, "Snaplines", "Visuals", "Tracers")
CreateToggle(TabVisuals, "Team Check Filter", "Visuals", "TeamCheck")

--// MM2
CreateToggle(TabMM2, "Role ESP", "MM2", "RoleESP")
CreateToggle(TabMM2, "Dropped Gun ESP", "MM2", "GunESP")
CreateToggle(TabMM2, "Show TP Gun Button", "MM2", "TPGunButtonEnabled")
TabMM2:Button({
    Title = "Edit TP GUN Position",
    Callback = function()
        IsTPGunEditModeActive = not IsTPGunEditModeActive
        showVillonNotice(IsTPGunEditModeActive and "Режим настройки: Перетащите кнопку TP GUN!" or "Позиция зафиксирована.")
        local folder = CoreGui:FindFirstChild("VillonHub_MM2_Menu")
        if folder then
            local btn = folder:FindFirstChild("MM2_TPGunButton")
            if btn then
                btn.Draggable = IsTPGunEditModeActive
                btn.BorderSizePixel = IsTPGunEditModeActive and 1 or 0
                btn.BorderColor3 = Color3.fromRGB(0, 150, 255)
            end
        end
    end
})
CreateToggle(TabMM2, "Show Shoot Murder Button", "MM2", "ShootMurderButtonEnabled")
TabMM2:Button({
    Title = "Edit SHOOT MURDER Position",
    Callback = function()
        IsShootMurderEditModeActive = not IsShootMurderEditModeActive
        showVillonNotice(IsShootMurderEditModeActive and "Режим настройки: Перетащите кнопку SHOOT MURDER!" or "Позиция зафиксирована.")
        local folder = CoreGui:FindFirstChild("VillonHub_MM2_Menu")
        if folder then
            local btn = folder:FindFirstChild("MM2_ShootMurderButton")
            if btn then
                btn.Draggable = IsShootMurderEditModeActive
                btn.BorderSizePixel = IsShootMurderEditModeActive and 1 or 0
                btn.BorderColor3 = Color3.fromRGB(0, 150, 255)
            end
        end
    end
})
CreateToggle(TabMM2, "Show Throw Knife Button", "MM2", "ThrowKnifeButtonEnabled")
TabMM2:Button({
    Title = "Edit THROW KNIFE Position",
    Callback = function()
        IsThrowKnifeEditModeActive = not IsThrowKnifeEditModeActive
        showVillonNotice(IsThrowKnifeEditModeActive and "Режим настройки: Перетащите кнопку THROW KNIFE!" or "Позиция зафиксирована.")
        local folder = CoreGui:FindFirstChild("VillonHub_MM2_Menu")
        if folder then
            local btn = folder:FindFirstChild("MM2_ThrowKnifeButton")
            if btn then
                btn.Draggable = IsThrowKnifeEditModeActive
                btn.BorderSizePixel = IsThrowKnifeEditModeActive and 1 or 0
                btn.BorderColor3 = Color3.fromRGB(0, 150, 255)
            end
        end
    end
})
CreateToggle(TabMM2, "Show Invis Bind Button", "MM2", "InvisButtonEnabled")
TabMM2:Button({
    Title = "Edit INVIS Position",
    Callback = function()
        IsInvisEditModeActive = not IsInvisEditModeActive
        showVillonNotice(IsInvisEditModeActive and "Режим настройки: Перетащите кнопку INVIS!" or "Позиция зафиксирована.")
        local folder = CoreGui:FindFirstChild("VillonHub_MM2_Menu")
        if folder then
            local btn = folder:FindFirstChild("MM2_InvisButton")
            if btn then
                btn.Draggable = IsInvisEditModeActive
                btn.BorderSizePixel = IsInvisEditModeActive and 1 or 0
                btn.BorderColor3 = Color3.fromRGB(0, 150, 255)
            end
        end
    end
})
CreateToggle(TabMM2, "Show Fling Bind Button", "MM2", "FlingButtonEnabled")
TabMM2:Button({
    Title = "Edit FLING Position",
    Callback = function()
        IsFlingEditModeActive = not IsFlingEditModeActive
        showVillonNotice(IsFlingEditModeActive and "Режим настройки: Перетащите кнопку FLING!" or "Позиция зафиксирована.")
        local folder = CoreGui:FindFirstChild("VillonHub_MM2_Menu")
        if folder then
            local btn = folder:FindFirstChild("MM2_FlingButton")
            if btn then
                btn.Draggable = IsFlingEditModeActive
                btn.BorderSizePixel = IsFlingEditModeActive and 1 or 0
                btn.BorderColor3 = Color3.fromRGB(0, 150, 255)
            end
        end
    end
})
CreateToggle(TabMM2, "Fling Murderer", "MM2", "FlingMurder")
CreateToggle(TabMM2, "Fling Sheriff", "MM2", "FlingSheriff")
CreateToggle(TabMM2, "Aim Murderer Only", "MM2", "AimMurderOnly")
CreateToggle(TabMM2, "Auto-Aim murder", "MM2", "AutoAimMurder")
CreateToggle(TabMM2, "Invisibility", "MM2", "Invisibility")
CreateToggle(TabMM2, "Touch Fling", "MM2", "Fling")
CreateToggle(TabMM2, "Auto TP Gun on Drop", "MM2", "AutoTPGun")
CreateToggle(TabMM2, "Show Kill All Button", "MM2", "KillAllButtonEnabled")
TabMM2:Button({
    Title = "Edit KILL ALL Position",
    Callback = function()
        IsKillAllEditModeActive = not IsKillAllEditModeActive
        showVillonNotice(IsKillAllEditModeActive and "Режим настройки: Перетащите кнопку KILL ALL!" or "Позиция зафиксирована.")
        local folder = CoreGui:FindFirstChild("VillonHub_MM2_Menu")
        if folder then
            local btn = folder:FindFirstChild("KillAllButton")
            if btn then
                btn.Draggable = IsKillAllEditModeActive
                btn.BorderSizePixel = IsKillAllEditModeActive and 1 or 0
                btn.BorderColor3 = Color3.fromRGB(0, 150, 255)
            end
        end
    end
})
CreateToggle(TabMM2, "Show Kill Sheriff Button", "MM2", "KillSheriffButtonEnabled")
TabMM2:Button({
    Title = "Edit KILL SHERIFF Position",
    Callback = function()
        IsKillSheriffEditModeActive = not IsKillSheriffEditModeActive
        showVillonNotice(IsKillSheriffEditModeActive and "Режим настройки: Перетащите кнопку KILL SHERIFF!" or "Позиция зафиксирована.")
        local folder = CoreGui:FindFirstChild("VillonHub_MM2_Menu")
        if folder then
            local btn = folder:FindFirstChild("KillSheriffButton")
            if btn then
                btn.Draggable = IsKillSheriffEditModeActive
                btn.BorderSizePixel = IsKillSheriffEditModeActive and 1 or 0
                btn.BorderColor3 = Color3.fromRGB(0, 150, 255)
            end
        end
    end
})
CreateToggle(TabMM2, "Jerk Off (инструмент)", "MM2", "JerkOffEnabled")

--// Misc
CreateToggle(TabMisc, "Spin Bot", "Misc", "SpinBot")
CreateToggle(TabMisc, "Enable Custom WalkSpeed", "Misc", "WalkSpeedEnabled")
CreateNumericInput(TabMisc, "WalkSpeed Value", "Misc", "WalkSpeedValue", 1, 100)
CreateToggle(TabMisc, "Anti-Fling Protection", "Misc", "AntiFling")
CreateToggle(TabMisc, "Double Jump", "Misc", "DoubleJump")
CreateToggle(TabMisc, "Enable Change Fov", "Misc", "FovEnabled")
CreateNumericInput(TabMisc, "Fov Value", "Misc", "FovValue", 1, 120)
CreateToggle(TabMisc, "Enable Aspect Ratio", "Misc", "AspectRatioEnabled")
CreateNumericInput(TabMisc, "Aspect Ratio Value", "Misc", "AspectRatioValue", 0.1, 3)
CreateToggle(TabMisc, "Speed Glitch (BHOP)", "Misc", "SpeedGlitchEnabled")
CreateNumericInput(TabMisc, "Speed Glitch Value", "Misc", "SpeedGlitchValue", 1, 50)

--// Configs (полноценная)
do
    local useFileSystem = pcall(function() return writefile end)
    local configFolder = "VillonConfigs/"
    if useFileSystem then
        pcall(function()
            if not isfolder(configFolder) then
                makefolder(configFolder)
            end
        end)
    end

    local nameInput = TabConfigs:Input({
        Title = "Имя конфига",
        Default = "config1",
        Placeholder = "Введите имя",
        Callback = function(value) end
    })

    TabConfigs:Button({
        Title = "Сохранить конфиг",
        Callback = function()
            local name = nameInput:GetValue()
            if name == "" then
                showVillonNotice("Введите имя конфига")
                return
            end
            local configData = {}
            for k, v in pairs(Options) do
                configData[k] = v
            end
            local json = game:GetService("HttpService"):JSONEncode(configData)
            if useFileSystem then
                local path = configFolder .. name .. ".json"
                pcall(function()
                    writefile(path, json)
                end)
                showVillonNotice("Конфиг '" .. name .. "' сохранён в файл")
            else
                if not getgenv().VillonConfigs then getgenv().VillonConfigs = {} end
                getgenv().VillonConfigs[name] = configData
                showVillonNotice("Конфиг '" .. name .. "' сохранён (в памяти)")
            end
        end
    })

    TabConfigs:Button({
        Title = "Загрузить конфиг",
        Callback = function()
            local name = nameInput:GetValue()
            if name == "" then
                showVillonNotice("Введите имя конфига")
                return
            end
            local configData = nil
            if useFileSystem then
                local path = configFolder .. name .. ".json"
                local success, data = pcall(function()
                    return readfile(path)
                end)
                if success and data then
                    configData = game:GetService("HttpService"):JSONDecode(data)
                end
            else
                if getgenv().VillonConfigs and getgenv().VillonConfigs[name] then
                    configData = getgenv().VillonConfigs[name]
                end
            end
            if not configData then
                showVillonNotice("Конфиг не найден")
                return
            end
            for k, v in pairs(configData) do
                Options[k] = v
            end
            showVillonNotice("Конфиг '" .. name .. "' загружен")
        end
    })
end

--// Change Fling (полноценный)
do
    local selectedPlayers = {}
    local playerButtons = {}

    local function updateFlingPlayerList()
        for _, btn in ipairs(playerButtons) do
            -- в WindUI нет прямого удаления, можно скрыть, но проще пересоздать
        end
        playerButtons = {}
        selectedPlayers = {}
        local players = {}
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer then
                table.insert(players, p)
            end
        end
        table.sort(players, function(a,b) return a.Name < b.Name end)
        for _, p in ipairs(players) do
            local btn = TabChangeFling:Button({
                Title = p.Name .. "  ☐",
                Callback = function()
                    if selectedPlayers[p] then
                        selectedPlayers[p] = nil
                        btn:SetTitle(p.Name .. "  ☐")
                    else
                        selectedPlayers[p] = p
                        btn:SetTitle(p.Name .. "  ☑")
                    end
                end
            })
            table.insert(playerButtons, btn)
        end
    end

    updateFlingPlayerList()

    TabChangeFling:Button({
        Title = "FLING (выбранные)",
        Callback = function()
            local targets = {}
            for _, p in pairs(selectedPlayers) do
                if p and p.Character then
                    table.insert(targets, p)
                end
            end
            if #targets == 0 then
                showVillonNotice("Выберите игроков")
                return
            end
            for _, p in ipairs(targets) do
                SHubFling(p)
                task.wait(1)
            end
            showVillonNotice("Флинг выполнен")
        end
    })

    TabChangeFling:Button({
        Title = "STOP (выбранные)",
        Callback = function()
            local targets = {}
            for _, p in pairs(selectedPlayers) do
                if p and p.Character then
                    table.insert(targets, p)
                end
            end
            if #targets == 0 then
                showVillonNotice("Выберите игроков")
                return
            end
            for _, p in ipairs(targets) do
                local root = p.Character:FindFirstChild("HumanoidRootPart")
                if root then
                    root.Velocity = Vector3.new(0,0,0)
                    root.RotVelocity = Vector3.new(0,0,0)
                    for _, bv in ipairs(root:GetDescendants()) do
                        if bv:IsA("BodyVelocity") then bv:Destroy() end
                    end
                    local hum = p.Character:FindFirstChildOfClass("Humanoid")
                    if hum then hum:ChangeState("GettingUp") end
                end
            end
            showVillonNotice("Остановлено")
        end
    })

    Players.PlayerAdded:Connect(updateFlingPlayerList)
    Players.PlayerRemoving:Connect(updateFlingPlayerList)
end

--// Unload
TabMisc:Button({
    Title = "UNLOAD CHEAT",
    Callback = function()
        for _, connection in ipairs(Connections) do
            if connection then connection:Disconnect() end
        end
        local gunDrop = Workspace:FindFirstChild("GunDrop", true)
        if gunDrop then
            if gunDrop:FindFirstChild("GunHighlight") then gunDrop.GunHighlight:Destroy() end
            if gunDrop:FindFirstChild("GunEsp") then gunDrop.GunEsp:Destroy() end
        end
        if workspace:FindFirstChild("invischair") then
            workspace.invischair:Destroy()
        end
        for _, storage in pairs(VisualStorage) do
            if type(storage) == "table" then
                for _, obj in pairs(storage) do
                    if type(obj) == "userdata" and obj.Remove then obj:Remove() end
                end
            end
        end
        FOVCircle:Remove()
        Window:Destroy()
        local folder = CoreGui:FindFirstChild("VillonHub_MM2_Menu")
        if folder then folder:Destroy() end
        getgenv().AdvancedCoreLoaded = nil
        showVillonNotice("VillonHub выгружен.")
    end
})

showVillonNotice("VillonHub с WindUI (полная версия) загружена!")

print("VillonHub с WindUI (полная версия, без AutoFarm) загружен.")