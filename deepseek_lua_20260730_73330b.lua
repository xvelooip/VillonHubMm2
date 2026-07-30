--[[
    VILLONHUB TERMINAL ENGINE: PREMIUM CS2 & MM2 REPLICATION CORE
    TARGET ENVIRONMENT: DELTA MOBILE / HYDROGEN / ALL EXECUTORS
    STABILITY FACTOR: 100% LIGHTWEIGHT SYSTEM FONTS & INSTANT LOW-LATENCY ESP
]]
 
if getgenv().AdvancedCoreLoaded then
    game:GetService("StarterGui"):SetCore("SendNotification", {
        Title = "VillonHub",
        Text = "Архитектура уже active в текущей сессии.",
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
 
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera
local Mouse = LocalPlayer:GetMouse()
 
-- ===== НАСТРОЙКИ АДАПТИВНОГО ПРЕДИКШЕНА (для шот мардера) =====
local CONFIG_SM = {
    BulletSpeed = 280,
    PredictionFactor = 0.85,
    MaxHorizontalPrediction = 300,
    MaxVerticalPrediction = 50,
    PingCompensation = true,
    UseVerticalCorrection = true,
    VerticalCorrectionFactor = 0.3
}
local velocityHistory = {}
 
--// Глобальная база конфигурации
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
 
--// Локальные кэш-переменные
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
 
--// Настройка статичного FOV кольца
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
 
--// Вспомогательная функция для получения рута
local function getRoot(char)
    if not char then return nil end
    return char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso") or char:FindFirstChild("UpperTorso")
end
 
--// Получение пинга
local function getPing()
    if LocalPlayer and LocalPlayer.GetNetworkPing then
        return LocalPlayer:GetNetworkPing() * 1000
    end
    return 0
end
 
--// Навешивание обработчика прыжков для Double Jump
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
 
--// Логика получения ролей из Open Source
local roleColors = {
    Murderer = Color3.fromRGB(255, 0, 0),
    Sheriff = Color3.fromRGB(0, 0, 255),
    Hero = Color3.fromRGB(255, 255, 0),
    Innocent = Color3.fromRGB(0, 255, 0),
    Default = Color3.fromRGB(200, 200, 200)
}
 
-- ===== ИСПРАВЛЕННАЯ getRoles (добавлен end) =====
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
 
-- ===== ТВОЙ ФИНАЛЬНЫЙ ШОТ МАРДЕР (БЕЗ ПРОВЕРКИ ВИДИМОСТИ) =====
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
 
-- Поиск ближайшего живого игрока для Throw Knife
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
 
-- Экипировка ножа
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
 
-- Функция броска ножа в ближайшего
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
 
-- ===== ОРИГИНАЛЬНАЯ ФУНКЦИЯ ФЛИНГА (SHubFling) =====
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
    game:GetService("StarterGui"):SetCore("SendNotification", {
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
 
--// Функции Kill All / Kill Sheriff (из Func.txt)
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
 
--// Графический интерфейс управления (GUI)
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "VillonHub_MM2_Menu"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
if gethui then ScreenGui.Parent = gethui() else ScreenGui.Parent = CoreGui end
 
local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 500, 0, 315)
MainFrame.Position = UDim2.new(0.5, -250, 0.5, -157)
MainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 22)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.Parent = ScreenGui
local UICorner = Instance.new("UICorner")
UICorner.CornerRadius = UDim.new(0, 8)
UICorner.Parent = MainFrame
local UIStroke = Instance.new("UIStroke")
UIStroke.Color = Color3.fromRGB(45, 45, 50)
UIStroke.Thickness = 1
UIStroke.Parent = MainFrame
 
local TabPanel = Instance.new("Frame")
TabPanel.Size = UDim2.new(0, 130, 1, 0)
TabPanel.BackgroundColor3 = Color3.fromRGB(15, 15, 17)
TabPanel.BorderSizePixel = 0
TabPanel.Parent = MainFrame
local TabCorner = Instance.new("UICorner")
TabCorner.CornerRadius = UDim.new(0, 8)
TabCorner.Parent = TabPanel
 
local ContentContainer = Instance.new("Frame")
ContentContainer.Size = UDim2.new(1, -140, 1, -20)
ContentContainer.Position = UDim2.new(0, 140, 0, 10)
ContentContainer.BackgroundTransparency = 1
ContentContainer.Parent = MainFrame
 
local Tabs = {
    Aimbot = Instance.new("ScrollingFrame"),
    Visuals = Instance.new("ScrollingFrame"),
    MM2 = Instance.new("ScrollingFrame"),
    Misc = Instance.new("ScrollingFrame"),
    Configs = Instance.new("ScrollingFrame"),
    ChangeFling = Instance.new("ScrollingFrame")
    -- Вкладка AutoFarm УДАЛЕНА
}
for Name, Frame in pairs(Tabs) do
    Frame.Name = Name .. "Tab"
    Frame.Size = UDim2.new(1, 0, 1, 0)
    Frame.BackgroundTransparency = 1
    Frame.CanvasSize = UDim2.new(0, 0, 0, 800)
    Frame.ScrollBarThickness = 2
    Frame.Visible = false
    Frame.Parent = ContentContainer
    local UIListLayout = Instance.new("UIListLayout")
    UIListLayout.SortOrder = Enum.SortOrder.LayoutOrder
    UIListLayout.Padding = UDim.new(0, 8)
    UIListLayout.Parent = Frame
end
Tabs.Aimbot.Visible = true
 
local function CreateTabButton(name, order, targetTab)
    local Button = Instance.new("TextButton")
    Button.Size = UDim2.new(1, -10, 0, 35)
    Button.Position = UDim2.new(0, 5, 0, 10 + (order * 40))
    Button.BackgroundColor3 = Color3.fromRGB(25, 25, 28)
    Button.Text = name
    Button.TextColor3 = Color3.fromRGB(200, 200, 200)
    Button.Font = Enum.Font.SourceSans
    Button.TextSize = 14
    Button.BorderSizePixel = 0
    Button.Parent = TabPanel
    local BTCorner = Instance.new("UICorner")
    BTCorner.CornerRadius = UDim.new(0, 4)
    BTCorner.Parent = Button
 
    Button.MouseButton1Click:Connect(function()
        for _, tFrame in pairs(Tabs) do tFrame.Visible = false end
        Tabs[targetTab].Visible = true
        for _, child in ipairs(TabPanel:GetChildren()) do
            if child:IsA("TextButton") then
                child.BackgroundColor3 = Color3.fromRGB(25, 25, 28)
                child.TextColor3 = Color3.fromRGB(200, 200, 200)
            end
        end
        Button.BackgroundColor3 = Color3.fromRGB(0, 150, 255)
        Button.TextColor3 = Color3.fromRGB(255, 255, 255)
    end)
end
 
CreateTabButton("COMBAT (AIM)", 0, "Aimbot")
CreateTabButton("VISUALS (ESP)", 1, "Visuals")
CreateTabButton("MM2", 2, "MM2")
CreateTabButton("MISC", 3, "Misc")
CreateTabButton("CONFIGS", 4, "Configs")
CreateTabButton("CHANGE FLING", 5, "ChangeFling")
-- Кнопка AUTOFARM УДАЛЕНА
 
local MenuHeader = Instance.new("TextLabel")
MenuHeader.Size = UDim2.new(0, 120, 0, 30)
MenuHeader.Position = UDim2.new(0, 5, 1, -35)
MenuHeader.BackgroundTransparency = 1
MenuHeader.Text = "VillonHub"
MenuHeader.TextColor3 = Color3.fromRGB(255, 255, 255)
MenuHeader.Font = Enum.Font.SourceSansBold
MenuHeader.TextSize = 16
MenuHeader.Parent = TabPanel
 
local CloseButton = Instance.new("TextButton")
CloseButton.Size = UDim2.new(0, 20, 0, 20)
CloseButton.Position = UDim2.new(1, -25, 0, 5)
CloseButton.BackgroundColor3 = Color3.fromRGB(35, 25, 25)
CloseButton.Text = "X"
CloseButton.TextColor3 = Color3.fromRGB(255, 80, 80)
CloseButton.Font = Enum.Font.SourceSansBold
CloseButton.TextSize = 14
CloseButton.BorderSizePixel = 0
CloseButton.Parent = MainFrame
local CBCorner = Instance.new("UICorner")
CBCorner.CornerRadius = UDim.new(0, 4)
CBCorner.Parent = CloseButton
CloseButton.MouseButton1Click:Connect(function()
    MainFrame.Visible = false
end)
 
local MenuToggle = Instance.new("TextButton")
MenuToggle.Size = UDim2.new(0, 80, 0, 30)
MenuToggle.Position = UDim2.new(0, 10, 0, 10)
MenuToggle.BackgroundColor3 = Color3.fromRGB(20, 20, 22)
MenuToggle.Text = "VILLONHUB"
MenuToggle.TextColor3 = Color3.fromRGB(255, 255, 255)
MenuToggle.Font = Enum.Font.SourceSansBold
MenuToggle.TextSize = 13
MenuToggle.Parent = ScreenGui
local MTCorner = Instance.new("UICorner")
MTCorner.CornerRadius = UDim.new(0, 6)
MTCorner.Parent = MenuToggle
MenuToggle.MouseButton1Click:Connect(function()
    MainFrame.Visible = not MainFrame.Visible
end)
 
--// UI Компоненты
local function CreateToggle(parentTab, text, configTable, configKey, hasSettings)
    local Frame = Instance.new("Frame")
    Frame.Size = UDim2.new(1, -10, 0, 40)
    Frame.BackgroundColor3 = Color3.fromRGB(25, 25, 28)
    Frame.BorderSizePixel = 0
    Frame.Parent = Tabs[parentTab]
    local Corner = Instance.new("UICorner")
    Corner.CornerRadius = UDim.new(0, 4)
    Corner.Parent = Frame
    local Label = Instance.new("TextLabel")
    Label.Size = UDim2.new(0.6, 0, 1, 0)
    Label.Position = UDim2.new(0, 10, 0, 0)
    Label.BackgroundTransparency = 1
    Label.Text = text
    Label.TextColor3 = Color3.fromRGB(230, 230, 230)
    Label.Font = Enum.Font.SourceSans
    Label.TextSize = 15
    Label.TextXAlignment = Enum.TextXAlignment.Left
    Label.Parent = Frame
    local Button = Instance.new("TextButton")
    Button.Size = UDim2.new(0, 40, 0, 20)
    Button.Position = UDim2.new(1, hasSettings and -85 or -50, 0.5, -10)
    Button.BackgroundColor3 = Options[configTable][configKey] and Color3.fromRGB(0, 200, 100) or Color3.fromRGB(60, 60, 65)
    Button.Text = ""
    Button.BorderSizePixel = 0
    Button.Parent = Frame
    local BCorner = Instance.new("UICorner")
    BCorner.CornerRadius = UDim.new(0, 4)
    BCorner.Parent = Button
    Button.MouseButton1Click:Connect(function()
        Options[configTable][configKey] = not Options[configTable][configKey]
        Button.BackgroundColor3 = Options[configTable][configKey] and Color3.fromRGB(0, 200, 100) or Color3.fromRGB(60, 60, 65)
        if configKey == "Enabled" then
            FOVCircle.Visible = Options.Aimbot.Enabled
        end
        if configTable == "MM2" and configKey == "Invisibility" then
            toggleInvisibilityLogic(Options.MM2.Invisibility)
        end
        if configTable == "MM2" and configKey == "Fling" then
            if Options.MM2.Fling then
                showVillonNotice("Touch Fling Mode ACTIVE")
            else
                showVillonNotice("Touch Fling Mode DISABLED")
            end
        end
        if configTable == "MM2" and configKey == "FlingMurder" then
            if Options.MM2.FlingMurder then
                task.spawn(function()
                    FlingMurderer()
                    Options.MM2.FlingMurder = false
                    Button.BackgroundColor3 = Color3.fromRGB(60, 60, 65)
                end)
            end
        end
        if configTable == "MM2" and configKey == "FlingSheriff" then
            if Options.MM2.FlingSheriff then
                task.spawn(function()
                    FlingSheriff()
                    Options.MM2.FlingSheriff = false
                    Button.BackgroundColor3 = Color3.fromRGB(60, 60, 65)
                end)
            end
        end
    end)
    if hasSettings then
        local GearButton = Instance.new("TextButton")
        GearButton.Size = UDim2.new(0, 25, 0, 25)
        GearButton.Position = UDim2.new(1, -40, 0.5, -12)
        GearButton.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
        GearButton.Text = "⚙"
        GearButton.TextColor3 = Color3.fromRGB(200, 200, 200)
        GearButton.Font = Enum.Font.SourceSans
        GearButton.TextSize = 15
        GearButton.BorderSizePixel = 0
        GearButton.Parent = Frame
        GearButton.MouseButton1Click:Connect(function()
            if configKey == "BindButtonEnabled" then
                local aimBtn = ScreenGui:FindFirstChild("Aim_BindButton")
                if aimBtn then
                    IsAimBindEditModeActive = not IsAimBindEditModeActive
                    aimBtn.Draggable = IsAimBindEditModeActive
                    GearButton.BackgroundColor3 = IsAimBindEditModeActive and Color3.fromRGB(0, 150, 255) or Color3.fromRGB(40, 40, 45)
                    aimBtn.BorderSizePixel = IsAimBindEditModeActive and 1 or 0
                    aimBtn.BorderColor3 = Color3.fromRGB(0, 150, 255)
                    showVillonNotice(IsAimBindEditModeActive and "Режим настройки: Перетащите кнопку AIM!" or "Положение кнопки AIM зафиксировано.")
                end
            elseif configKey == "TPGunButtonEnabled" then
                local tpBtn = ScreenGui:FindFirstChild("MM2_TPGunButton")
                if tpBtn then
                    IsTPGunEditModeActive = not IsTPGunEditModeActive
                    tpBtn.Draggable = IsTPGunEditModeActive
                    GearButton.BackgroundColor3 = IsTPGunEditModeActive and Color3.fromRGB(0, 150, 255) or Color3.fromRGB(40, 40, 45)
                    tpBtn.BorderSizePixel = IsTPGunEditModeActive and 1 or 0
                    tpBtn.BorderColor3 = Color3.fromRGB(0, 150, 255)
                    showVillonNotice(IsTPGunEditModeActive and "Режим настройки: Перетащите кнопку TP GUN!" or "Положение кнопки TP GUN зафиксировано.")
                end
            elseif configKey == "ShootMurderButtonEnabled" then
                local shootBtn = ScreenGui:FindFirstChild("MM2_ShootMurderButton")
                if shootBtn then
                    IsShootMurderEditModeActive = not IsShootMurderEditModeActive
                    shootBtn.Draggable = IsShootMurderEditModeActive
                    GearButton.BackgroundColor3 = IsShootMurderEditModeActive and Color3.fromRGB(0, 150, 255) or Color3.fromRGB(40, 40, 45)
                    shootBtn.BorderSizePixel = IsShootMurderEditModeActive and 1 or 0
                    shootBtn.BorderColor3 = Color3.fromRGB(0, 150, 255)
                    showVillonNotice(IsShootMurderEditModeActive and "Режим настройки: Перетащите кнопку SHOOT MURDER!" or "Положение кнопки SHOOT MURDER зафиксировано.")
                end
            elseif configKey == "ThrowKnifeButtonEnabled" then
                local throwBtn = ScreenGui:FindFirstChild("MM2_ThrowKnifeButton")
                if throwBtn then
                    IsThrowKnifeEditModeActive = not IsThrowKnifeEditModeActive
                    throwBtn.Draggable = IsThrowKnifeEditModeActive
                    GearButton.BackgroundColor3 = IsThrowKnifeEditModeActive and Color3.fromRGB(0, 150, 255) or Color3.fromRGB(40, 40, 45)
                    throwBtn.BorderSizePixel = IsThrowKnifeEditModeActive and 1 or 0
                    throwBtn.BorderColor3 = Color3.fromRGB(0, 150, 255)
                    showVillonNotice(IsThrowKnifeEditModeActive and "Режим настройки: Перетащите кнопку THROW KNIFE!" or "Положение кнопки THROW KNIFE зафиксировано.")
                end
            elseif configKey == "InvisButtonEnabled" then
                local invBtn = ScreenGui:FindFirstChild("MM2_InvisButton")
                if invBtn then
                    IsInvisEditModeActive = not IsInvisEditModeActive
                    invBtn.Draggable = IsInvisEditModeActive
                    GearButton.BackgroundColor3 = IsInvisEditModeActive and Color3.fromRGB(0, 150, 255) or Color3.fromRGB(40, 40, 45)
                    invBtn.BorderSizePixel = IsInvisEditModeActive and 1 or 0
                    invBtn.BorderColor3 = Color3.fromRGB(0, 150, 255)
                    showVillonNotice(IsInvisEditModeActive and "Режим настройки: Перетащите кнопку INVIS!" or "Положение кнопки INVIS зафиксировано.")
                end
            elseif configKey == "FlingButtonEnabled" then
                local flBtn = ScreenGui:FindFirstChild("MM2_FlingButton")
                if flBtn then
                    IsFlingEditModeActive = not IsFlingEditModeActive
                    flBtn.Draggable = IsFlingEditModeActive
                    GearButton.BackgroundColor3 = IsFlingEditModeActive and Color3.fromRGB(0, 150, 255) or Color3.fromRGB(40, 40, 45)
                    flBtn.BorderSizePixel = IsFlingEditModeActive and 1 or 0
                    flBtn.BorderColor3 = Color3.fromRGB(0, 150, 255)
                    showVillonNotice(IsFlingEditModeActive and "Режим настройки: Перетащите кнопку FLING!" or "Положение кнопки FLING зафиксировано.")
                end
            elseif configKey == "KillAllButtonEnabled" then
                local kaBtn = ScreenGui:FindFirstChild("KillAllButton")
                if kaBtn then
                    IsKillAllEditModeActive = not IsKillAllEditModeActive
                    kaBtn.Draggable = IsKillAllEditModeActive
                    GearButton.BackgroundColor3 = IsKillAllEditModeActive and Color3.fromRGB(0, 150, 255) or Color3.fromRGB(40, 40, 45)
                    kaBtn.BorderSizePixel = IsKillAllEditModeActive and 1 or 0
                    kaBtn.BorderColor3 = Color3.fromRGB(0, 150, 255)
                    showVillonNotice(IsKillAllEditModeActive and "Режим настройки: Перетащите кнопку KILL ALL!" or "Положение кнопки KILL ALL зафиксировано.")
                end
            elseif configKey == "KillSheriffButtonEnabled" then
                local ksBtn = ScreenGui:FindFirstChild("KillSheriffButton")
                if ksBtn then
                    IsKillSheriffEditModeActive = not IsKillSheriffEditModeActive
                    ksBtn.Draggable = IsKillSheriffEditModeActive
                    GearButton.BackgroundColor3 = IsKillSheriffEditModeActive and Color3.fromRGB(0, 150, 255) or Color3.fromRGB(40, 40, 45)
                    ksBtn.BorderSizePixel = IsKillSheriffEditModeActive and 1 or 0
                    ksBtn.BorderColor3 = Color3.fromRGB(0, 150, 255)
                    showVillonNotice(IsKillSheriffEditModeActive and "Режим настройки: Перетащите кнопку KILL SHERIFF!" or "Положение кнопки KILL SHERIFF зафиксировано.")
                end
            end
        end)
    end
end
 
local function CreateNumericInput(parentTab, text, configTable, configKey)
    local Frame = Instance.new("Frame")
    Frame.Size = UDim2.new(1, -10, 0, 45)
    Frame.BackgroundColor3 = Color3.fromRGB(25, 25, 28)
    Frame.BorderSizePixel = 0
    Frame.Parent = Tabs[parentTab]
    local Corner = Instance.new("UICorner")
    Corner.CornerRadius = UDim.new(0, 4)
    Corner.Parent = Frame
    local Label = Instance.new("TextLabel")
    Label.Size = UDim2.new(0.6, 0, 1, 0)
    Label.Position = UDim2.new(0, 10, 0, 0)
    Label.BackgroundTransparency = 1
    Label.Text = text
    Label.TextColor3 = Color3.fromRGB(230, 230, 230)
    Label.Font = Enum.Font.SourceSans
    Label.TextSize = 15
    Label.TextXAlignment = Enum.TextXAlignment.Left
    Label.Parent = Frame
    local TextBox = Instance.new("TextBox")
    TextBox.Size = UDim2.new(0, 70, 0, 25)
    TextBox.Position = UDim2.new(1, -80, 0.5, -12)
    TextBox.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
    TextBox.BorderSizePixel = 0
    TextBox.Text = tostring(Options[configTable][configKey])
    TextBox.TextColor3 = Color3.fromRGB(0, 200, 100)
    TextBox.Font = Enum.Font.SourceSans
    TextBox.TextSize = 14
    TextBox.ClearTextOnFocus = false
    TextBox.Parent = Frame
    local TBCorner = Instance.new("UICorner")
    TBCorner.CornerRadius = UDim.new(0, 4)
    TBCorner.Parent = TextBox
    TextBox.FocusLost:Connect(function(enterPressed)
        local num = tonumber(TextBox.Text)
        if num then
            Options[configTable][configKey] = num
            if configKey == "Radius" then FOVCircle.Radius = num end
        else
            TextBox.Text = tostring(Options[configTable][configKey])
        end
    end)
end
 
local function CreatePartSelector(parentTab)
    local Frame = Instance.new("Frame")
    Frame.Size = UDim2.new(1, -10, 0, 45)
    Frame.BackgroundColor3 = Color3.fromRGB(25, 25, 28)
    Frame.BorderSizePixel = 0
    Frame.Parent = Tabs[parentTab]
    local Corner = Instance.new("UICorner")
    Corner.CornerRadius = UDim.new(0, 4)
    Corner.Parent = Frame
    local Label = Instance.new("TextLabel")
    Label.Size = UDim2.new(0.6, 0, 1, 0)
    Label.Position = UDim2.new(0, 10, 0, 0)
    Label.BackgroundTransparency = 1
    Label.Text = "Aim Target Part"
    Label.TextColor3 = Color3.fromRGB(230, 230, 230)
    Label.Font = Enum.Font.SourceSans
    Label.TextSize = 15
    Label.TextXAlignment = Enum.TextXAlignment.Left
    Label.Parent = Frame
    local PartButton = Instance.new("TextButton")
    PartButton.Size = UDim2.new(0, 80, 0, 25)
    PartButton.Position = UDim2.new(1, -90, 0.5, -12)
    PartButton.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
    PartButton.Text = "Torso"
    PartButton.TextColor3 = Color3.fromRGB(0, 200, 100)
    PartButton.Font = Enum.Font.SourceSans
    PartButton.TextSize = 14
    PartButton.BorderSizePixel = 0
    PartButton.Parent = Frame
    local PBCorner = Instance.new("UICorner")
    PBCorner.CornerRadius = UDim.new(0, 4)
    PBCorner.Parent = PartButton
    local parts = {"Torso", "Head", "LeftFoot"}
    local partLabels = {Torso = "Torso", Head = "Head", LeftFoot = "Legs"}
    local currentIndex = 1
    PartButton.MouseButton1Click:Connect(function()
        currentIndex = currentIndex + 1
        if currentIndex > #parts then currentIndex = 1 end
        local selected = parts[currentIndex]
        Options.Aimbot.TargetPart = selected
        PartButton.Text = partLabels[selected]
    end)
end
 
--// СОЗДАНИЕ ТОГГЛОВ
CreateToggle("Aimbot", "Enable Hard Aim", "Aimbot", "Enabled", false)
CreateToggle("Aimbot", "Show Aim Bind Button", "Aimbot", "BindButtonEnabled", true)
CreateToggle("Aimbot", "Team Check", "Aimbot", "TeamCheck", false)
CreateToggle("Aimbot", "Wall Check", "Aimbot", "WallCheck", false)
CreatePartSelector("Aimbot")
CreateNumericInput("Aimbot", "FOV Radius Size", "Aimbot", "Radius")
 
CreateToggle("Visuals", "Boxes ESP", "Visuals", "Boxes", false)
CreateToggle("Visuals", "Skeletons ESP", "Visuals", "Skeletons", false)
CreateToggle("Visuals", "Chams Style", "Visuals", "Chams", false)
CreateToggle("Visuals", "Names Rendering", "Visuals", "Names", false)
CreateToggle("Visuals", "Health Bar Indicators", "Visuals", "HealthBar", false)
CreateToggle("Visuals", "Snaplines", "Visuals", "Tracers", false)
CreateToggle("Visuals", "Team Check Filter", "Visuals", "TeamCheck", false)
 
CreateToggle("MM2", "Role ESP", "MM2", "RoleESP", false)
CreateToggle("MM2", "Dropped Gun ESP", "MM2", "GunESP", false)
CreateToggle("MM2", "Show TP Gun Button", "MM2", "TPGunButtonEnabled", true)
CreateToggle("MM2", "Show Shoot Murder Button", "MM2", "ShootMurderButtonEnabled", true)
CreateToggle("MM2", "Show Throw Knife Button", "MM2", "ThrowKnifeButtonEnabled", true)
CreateToggle("MM2", "Show Invis Bind Button", "MM2", "InvisButtonEnabled", true)
CreateToggle("MM2", "Show Fling Bind Button", "MM2", "FlingButtonEnabled", true)
CreateToggle("MM2", "Fling Murderer", "MM2", "FlingMurder", false)
CreateToggle("MM2", "Fling Sheriff", "MM2", "FlingSheriff", false)
CreateToggle("MM2", "Aim Murderer Only", "MM2", "AimMurderOnly", false)
CreateToggle("MM2", "Auto-Aim murder", "MM2", "AutoAimMurder", false)
CreateToggle("MM2", "Invisibility", "MM2", "Invisibility", false)
CreateToggle("MM2", "Touch Fling", "MM2", "Fling", false)
CreateToggle("MM2", "Auto TP Gun on Drop", "MM2", "AutoTPGun", false)
CreateToggle("MM2", "Show Kill All Button", "MM2", "KillAllButtonEnabled", true)
CreateToggle("MM2", "Show Kill Sheriff Button", "MM2", "KillSheriffButtonEnabled", true)
CreateToggle("MM2", "Jerk Off (инструмент)", "MM2", "JerkOffEnabled", false)
 
CreateToggle("Misc", "Spin Bot", "Misc", "SpinBot", false)
CreateToggle("Misc", "Enable Custom WalkSpeed", "Misc", "WalkSpeedEnabled", false)
CreateNumericInput("Misc", "WalkSpeed Value", "Misc", "WalkSpeedValue")
CreateToggle("Misc", "Anti-Fling Protection", "Misc", "AntiFling", false)
CreateToggle("Misc", "Double Jump", "Misc", "DoubleJump", false)
CreateToggle("Misc", "Enable Change Fov", "Misc", "FovEnabled", false)
CreateNumericInput("Misc", "Fov Value", "Misc", "FovValue")
CreateToggle("Misc", "Enable Aspect Ratio", "Misc", "AspectRatioEnabled", false)
CreateNumericInput("Misc", "Aspect Ratio Value", "Misc", "AspectRatioValue")
CreateToggle("Misc", "Speed Glitch (BHOP)", "Misc", "SpeedGlitchEnabled", false)
CreateNumericInput("Misc", "Speed Glitch Value", "Misc", "SpeedGlitchValue")
 
local UnloadButton = Instance.new("TextButton")
UnloadButton.Size = UDim2.new(1, -10, 0, 45)
UnloadButton.BackgroundColor3 = Color3.fromRGB(150, 30, 30)
UnloadButton.Text = "UNLOAD CHEAT"
UnloadButton.TextColor3 = Color3.fromRGB(255, 255, 255)
UnloadButton.Font = Enum.Font.SourceSansBold
UnloadButton.TextSize = 16
UnloadButton.BorderSizePixel = 0
UnloadButton.Parent = Tabs.Misc
local UBCorner = Instance.new("UICorner")
UBCorner.CornerRadius = UDim.new(0, 6)
UBCorner.Parent = UnloadButton
 
--// Математический движок и Silent Aim Core
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
 
--// Инициализация ESP элементов
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
 
--// Главный рендер-луп + Физический хартбит
local lastVisualUpdate = 0
 
local PhysicsLoop = RunService.Heartbeat:Connect(function()
    local myChar = LocalPlayer.Character
    local myRoot = getRoot(myChar)
    local myHum = myChar and myChar:FindFirstChildOfClass("Humanoid")
    if not myRoot or (myHum and myHum.Health <= 0) then return end
 
    -- TOUCH FLING
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
 
    -- ANTI-FLING
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
 
    -- SPEED GLITCH (BHOP)
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
 
    -- Кнопка Aim
    if Options.Aimbot.BindButtonEnabled then
        if not ScreenGui:FindFirstChild("Aim_BindButton") then
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
            AimBindButton.Parent = ScreenGui
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
            ScreenGui.Aim_BindButton.Visible = true
            ScreenGui.Aim_BindButton.Draggable = IsAimBindEditModeActive
            ScreenGui.Aim_BindButton.BackgroundColor3 = Options.Aimbot.Enabled and Color3.fromRGB(0, 180, 255) or Color3.fromRGB(40, 40, 45)
        end
    else
        if ScreenGui:FindFirstChild("Aim_BindButton") then ScreenGui.Aim_BindButton.Visible = false end
    end
 
    -- Кнопка TP GUN
    if Options.MM2.TPGunButtonEnabled then
        if not ScreenGui:FindFirstChild("MM2_TPGunButton") then
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
            TPGunButton.Parent = ScreenGui
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
            ScreenGui.MM2_TPGunButton.Visible = true
            ScreenGui.MM2_TPGunButton.Draggable = IsTPGunEditModeActive
        end
    else
        if ScreenGui:FindFirstChild("MM2_TPGunButton") then ScreenGui.MM2_TPGunButton.Visible = false end
    end
 
    -- Кнопка INVIS
    if Options.MM2.InvisButtonEnabled then
        if not ScreenGui:FindFirstChild("MM2_InvisButton") then
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
            InvisButton.Parent = ScreenGui
            local InvCorner = Instance.new("UICorner")
            InvCorner.CornerRadius = UDim.new(0, 6)
            InvCorner.Parent = InvisButton
            InvisButton.MouseButton1Click:Connect(function()
                if IsInvisEditModeActive then return end
                toggleInvisibilityLogic(not Options.MM2.Invisibility)
                InvisButton.BackgroundColor3 = Options.MM2.Invisibility and Color3.fromRGB(120, 0, 200) or Color3.fromRGB(40, 40, 45)
            end)
        else
            ScreenGui.MM2_InvisButton.Visible = true
            ScreenGui.MM2_InvisButton.Draggable = IsInvisEditModeActive
            ScreenGui.MM2_InvisButton.BackgroundColor3 = Options.MM2.Invisibility and Color3.fromRGB(120, 0, 200) or Color3.fromRGB(40, 40, 45)
        end
    else
        if ScreenGui:FindFirstChild("MM2_InvisButton") then ScreenGui.MM2_InvisButton.Visible = false end
    end
 
    -- Кнопка FLING
    if Options.MM2.FlingButtonEnabled then
        if not ScreenGui:FindFirstChild("MM2_FlingButton") then
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
            FlingButton.Parent = ScreenGui
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
            ScreenGui.MM2_FlingButton.Visible = true
            ScreenGui.MM2_FlingButton.Draggable = IsFlingEditModeActive
            ScreenGui.MM2_FlingButton.BackgroundColor3 = Options.MM2.Fling and Color3.fromRGB(230, 100, 0) or Color3.fromRGB(40, 40, 45)
        end
    else
        if ScreenGui:FindFirstChild("MM2_FlingButton") then ScreenGui.MM2_FlingButton.Visible = false end
    end
 
    -- КНОПКА SHOOT MURDER (ТВОЙ ФИНАЛЬНЫЙ)
    if Options.MM2.ShootMurderButtonEnabled then
        if not ScreenGui:FindFirstChild("MM2_ShootMurderButton") then
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
            ShootMurderButton.Parent = ScreenGui
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
                    game:GetService("StarterGui"):SetCore("SendNotification", {
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
            ScreenGui.MM2_ShootMurderButton.Visible = true
            ScreenGui.MM2_ShootMurderButton.Draggable = IsShootMurderEditModeActive
        end
    else
        if ScreenGui:FindFirstChild("MM2_ShootMurderButton") then ScreenGui.MM2_ShootMurderButton.Visible = false end
    end
 
    -- КНОПКА THROW KNIFE
    if Options.MM2.ThrowKnifeButtonEnabled then
        if not ScreenGui:FindFirstChild("MM2_ThrowKnifeButton") then
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
            ThrowKnifeButton.Parent = ScreenGui
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
            ScreenGui.MM2_ThrowKnifeButton.Visible = true
            ScreenGui.MM2_ThrowKnifeButton.Draggable = IsThrowKnifeEditModeActive
        end
    else
        if ScreenGui:FindFirstChild("MM2_ThrowKnifeButton") then ScreenGui.MM2_ThrowKnifeButton.Visible = false end
    end
 
    -- КНОПКА KILL ALL
    if Options.MM2.KillAllButtonEnabled then
        if not ScreenGui:FindFirstChild("KillAllButton") then
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
            KillAllBtn.Parent = ScreenGui
            local corner = Instance.new("UICorner")
            corner.CornerRadius = UDim.new(0, 6)
            corner.Parent = KillAllBtn
            KillAllBtn.MouseButton1Click:Connect(function()
                if IsKillAllEditModeActive then return end
                KillAll()
            end)
        else
            ScreenGui.KillAllButton.Visible = true
            ScreenGui.KillAllButton.Draggable = IsKillAllEditModeActive
        end
    else
        if ScreenGui:FindFirstChild("KillAllButton") then
            ScreenGui.KillAllButton.Visible = false
        end
    end
 
    -- КНОПКА KILL SHERIFF
    if Options.MM2.KillSheriffButtonEnabled then
        if not ScreenGui:FindFirstChild("KillSheriffButton") then
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
            KillSheriffBtn.Parent = ScreenGui
            local corner = Instance.new("UICorner")
            corner.CornerRadius = UDim.new(0, 6)
            corner.Parent = KillSheriffBtn
            KillSheriffBtn.MouseButton1Click:Connect(function()
                if IsKillSheriffEditModeActive then return end
                KillSheriff()
            end)
        else
            ScreenGui.KillSheriffButton.Visible = true
            ScreenGui.KillSheriffButton.Draggable = IsKillSheriffEditModeActive
        end
    else
        if ScreenGui:FindFirstChild("KillSheriffButton") then
            ScreenGui.KillSheriffButton.Visible = false
        end
    end
 
    -- JERK OFF (инструмент в рюкзаке) – без текста на экране
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
 
    -- РЕНДЕР GUN ESP
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
 
    -- ESP ИГРОКОВ
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
 
--// ВКЛАДКА CONFIGS (с сохранением в файлы)
do
    local configTab = Tabs.Configs

    local useFileSystem = pcall(function() return writefile end)
    local configFolder = "VillonConfigs/"
    if useFileSystem then
        pcall(function()
            if not isfolder(configFolder) then
                makefolder(configFolder)
            end
        end)
    end

    local nameFrame = Instance.new("Frame")
    nameFrame.Size = UDim2.new(1, -10, 0, 45)
    nameFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 28)
    nameFrame.BorderSizePixel = 0
    nameFrame.Parent = configTab
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 4)
    corner.Parent = nameFrame

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0.4, 0, 1, 0)
    label.Position = UDim2.new(0, 10, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = "Имя конфига:"
    label.TextColor3 = Color3.fromRGB(230,230,230)
    label.Font = Enum.Font.SourceSans
    label.TextSize = 15
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = nameFrame

    local nameBox = Instance.new("TextBox")
    nameBox.Size = UDim2.new(0.5, 0, 0.7, 0)
    nameBox.Position = UDim2.new(0.45, 0, 0.15, 0)
    nameBox.BackgroundColor3 = Color3.fromRGB(40,40,45)
    nameBox.BorderSizePixel = 0
    nameBox.Text = "config1"
    nameBox.TextColor3 = Color3.fromRGB(200,200,200)
    nameBox.Font = Enum.Font.SourceSans
    nameBox.TextSize = 14
    nameBox.ClearTextOnFocus = false
    nameBox.Parent = nameFrame
    local tbc = Instance.new("UICorner")
    tbc.CornerRadius = UDim.new(0, 4)
    tbc.Parent = nameBox

    local function SaveConfig(name)
        if name == "" then
            showVillonNotice("Введите имя конфига")
            return false
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
        updateConfigList()
        return true
    end

    local function LoadConfig(name)
        if name == "" then
            showVillonNotice("Введите имя конфига")
            return false
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
            return false
        end
        for k, v in pairs(configData) do
            Options[k] = v
        end
        showVillonNotice("Конфиг '" .. name .. "' загружен")
        return true
    end

    local function createConfigBtn(text, pos, color, callback)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(0.3, 0, 0.25, 0)
        btn.Position = pos
        btn.BackgroundColor3 = color
        btn.Text = text
        btn.TextColor3 = Color3.new(1,1,1)
        btn.Font = Enum.Font.SourceSansBold
        btn.TextSize = 14
        btn.BorderSizePixel = 0
        btn.Parent = configTab
        local c = Instance.new("UICorner")
        c.CornerRadius = UDim.new(0, 4)
        c.Parent = btn
        btn.MouseButton1Click:Connect(callback)
        return btn
    end

    createConfigBtn("SAVE", UDim2.new(0.02, 0, 0.1, 0), Color3.fromRGB(0, 180, 80), function()
        SaveConfig(nameBox.Text)
    end)

    createConfigBtn("LOAD", UDim2.new(0.58, 0, 0.1, 0), Color3.fromRGB(0, 80, 200), function()
        LoadConfig(nameBox.Text)
    end)

    local listFrame = Instance.new("ScrollingFrame")
    listFrame.Size = UDim2.new(1, -10, 0, 200)
    listFrame.Position = UDim2.new(0, 5, 0.2, 0)
    listFrame.BackgroundTransparency = 1
    listFrame.CanvasSize = UDim2.new(0,0,0,0)
    listFrame.ScrollBarThickness = 5
    listFrame.Parent = configTab
    local listLayout = Instance.new("UIListLayout")
    listLayout.Padding = UDim.new(0, 4)
    listLayout.SortOrder = Enum.SortOrder.LayoutOrder
    listLayout.Parent = listFrame

    local function updateConfigList()
        for _, child in ipairs(listFrame:GetChildren()) do
            if child:IsA("TextButton") then
                child:Destroy()
            end
        end
        local names = {}
        if useFileSystem then
            pcall(function()
                local files = listfiles(configFolder)
                for _, file in ipairs(files) do
                    if file:match("%.json$") then
                        local name = file:match("([^/\\]+)%.json$")
                        table.insert(names, name)
                    end
                end
            end)
        else
            if getgenv().VillonConfigs then
                for name, _ in pairs(getgenv().VillonConfigs) do
                    table.insert(names, name)
                end
            end
        end
        table.sort(names)
        for _, name in ipairs(names) do
            local btn = Instance.new("TextButton")
            btn.Size = UDim2.new(1, 0, 0, 30)
            btn.BackgroundColor3 = Color3.fromRGB(40,40,45)
            btn.BackgroundTransparency = 0.3
            btn.Text = name
            btn.TextColor3 = Color3.fromRGB(200,200,200)
            btn.Font = Enum.Font.SourceSans
            btn.TextSize = 14
            btn.TextXAlignment = Enum.TextXAlignment.Left
            btn.BorderSizePixel = 0
            btn.Parent = listFrame
            local corner = Instance.new("UICorner")
            corner.CornerRadius = UDim.new(0, 4)
            corner.Parent = btn
            btn.MouseButton1Click:Connect(function()
                nameBox.Text = name
            end)
        end
        local count = #listFrame:GetChildren() - 1
        listFrame.CanvasSize = UDim2.new(0, 0, 0, count * 34 + 10)
    end
    updateConfigList()
end
 
--// ВКЛАДКА CHANGE FLING
do
    local flingTab = Tabs.ChangeFling
    local selectedPlayers = {}
    local checkBoxes = {}
 
    local function updateFlingPlayerList()
        for _, child in ipairs(flingTab:GetChildren()) do
            if child:IsA("TextButton") then
                child:Destroy()
            end
        end
        checkBoxes = {}
        selectedPlayers = {}
        local players = {}
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer then
                table.insert(players, p)
            end
        end
        table.sort(players, function(a,b) return a.Name < b.Name end)
        for _, p in ipairs(players) do
            local btn = Instance.new("TextButton")
            btn.Size = UDim2.new(1, 0, 0, 30)
            btn.BackgroundColor3 = Color3.fromRGB(40,40,45)
            btn.BackgroundTransparency = 0.3
            btn.Text = p.Name
            btn.TextColor3 = Color3.fromRGB(200,200,200)
            btn.Font = Enum.Font.SourceSans
            btn.TextSize = 14
            btn.TextXAlignment = Enum.TextXAlignment.Left
            btn.BorderSizePixel = 0
            btn.Parent = flingTab
            local corner = Instance.new("UICorner")
            corner.CornerRadius = UDim.new(0, 4)
            corner.Parent = btn
            local check = Instance.new("TextLabel")
            check.Size = UDim2.new(0, 30, 1, 0)
            check.Position = UDim2.new(1, -35, 0, 0)
            check.BackgroundTransparency = 1
            check.Text = "☐"
            check.TextColor3 = Color3.fromRGB(255,255,255)
            check.TextSize = 20
            check.Font = Enum.Font.SourceSans
            check.TextXAlignment = Enum.TextXAlignment.Center
            check.Parent = btn
            local selected = false
            checkBoxes[p] = { btn = btn, check = check, selected = false }
            btn.MouseButton1Click:Connect(function()
                selected = not selected
                checkBoxes[p].selected = selected
                if selected then
                    check.Text = "☑"
                    check.TextColor3 = Color3.fromRGB(0,255,0)
                    table.insert(selectedPlayers, p)
                else
                    check.Text = "☐"
                    check.TextColor3 = Color3.fromRGB(255,255,255)
                    for i, v in ipairs(selectedPlayers) do
                        if v == p then
                            table.remove(selectedPlayers, i)
                            break
                        end
                    end
                end
            end)
        end
        local count = #flingTab:GetChildren() - 1
        flingTab.CanvasSize = UDim2.new(0, 0, 0, count * 34 + 50)
    end
    updateFlingPlayerList()
 
    local buttonFrame = Instance.new("Frame")
    buttonFrame.Size = UDim2.new(1, -10, 0, 50)
    buttonFrame.Position = UDim2.new(0, 5, 0.9, 0)
    buttonFrame.BackgroundTransparency = 1
    buttonFrame.Parent = flingTab
 
    local flingBtn = Instance.new("TextButton")
    flingBtn.Size = UDim2.new(0.45, 0, 1, 0)
    flingBtn.Position = UDim2.new(0, 0, 0, 0)
    flingBtn.BackgroundColor3 = Color3.fromRGB(200,30,30)
    flingBtn.Text = "FLING"
    flingBtn.TextColor3 = Color3.new(1,1,1)
    flingBtn.Font = Enum.Font.SourceSansBold
    flingBtn.TextSize = 16
    flingBtn.BorderSizePixel = 0
    flingBtn.Parent = buttonFrame
    local c1 = Instance.new("UICorner")
    c1.CornerRadius = UDim.new(0, 4)
    c1.Parent = flingBtn
 
    local stopBtn = Instance.new("TextButton")
    stopBtn.Size = UDim2.new(0.45, 0, 1, 0)
    stopBtn.Position = UDim2.new(0.55, 0, 0, 0)
    stopBtn.BackgroundColor3 = Color3.fromRGB(0,80,200)
    stopBtn.Text = "STOP"
    stopBtn.TextColor3 = Color3.new(1,1,1)
    stopBtn.Font = Enum.Font.SourceSansBold
    stopBtn.TextSize = 16
    stopBtn.BorderSizePixel = 0
    stopBtn.Parent = buttonFrame
    local c2 = Instance.new("UICorner")
    c2.CornerRadius = UDim.new(0, 4)
    c2.Parent = stopBtn
 
    flingBtn.MouseButton1Click:Connect(function()
        if #selectedPlayers == 0 then
            showVillonNotice("Выберите игроков")
            return
        end
        for _, p in ipairs(selectedPlayers) do
            if p.Character then
                local startPos = p.Character:FindFirstChild("HumanoidRootPart") and p.Character.HumanoidRootPart.CFrame
                SHubFling(p)
                task.wait(5)
                if p.Character then
                    local root = p.Character:FindFirstChild("HumanoidRootPart")
                    if root and startPos then
                        local dist = (root.Position - startPos.Position).Magnitude
                        if dist < 50 then
                            root.CFrame = startPos
                            root.Velocity = Vector3.new(0,0,0)
                            root.RotVelocity = Vector3.new(0,0,0)
                            local hum = p.Character:FindFirstChildOfClass("Humanoid")
                            if hum then hum:ChangeState("GettingUp") end
                            for _, bv in ipairs(root:GetDescendants()) do
                                if bv:IsA("BodyVelocity") then bv:Destroy() end
                            end
                        end
                    end
                end
            end
        end
    end)
 
    stopBtn.MouseButton1Click:Connect(function()
        if #selectedPlayers == 0 then
            showVillonNotice("Выберите игроков")
            return
        end
        for _, p in ipairs(selectedPlayers) do
            if p.Character then
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
        end
    end)
 
    Players.PlayerAdded:Connect(updateFlingPlayerList)
    Players.PlayerRemoving:Connect(updateFlingPlayerList)
end
 
--// Функция выгрузки
UnloadButton.MouseButton1Click:Connect(function()
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
    ScreenGui:Destroy()
    getgenv().AdvancedCoreLoaded = nil
    showVillonNotice("VillonHub выгружен.")
end)
 
print("VillonHub обновлён. Удалена вкладка AutoFarm, исправлена getRoles, шот мардер – твой финальный.")