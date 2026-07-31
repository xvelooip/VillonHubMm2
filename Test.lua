--[[
    VILLONHUB TERMINAL ENGINE – Кастомное GUI (без WindUI)
    Полная интеграция: аим, ESP, шот мардер, флинг, KillAll, VisualWorld, ChangeFling, конфиги, растяг
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
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local ContextActionService = game:GetService("ContextActionService")
local HttpService = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera
local Mouse = LocalPlayer:GetMouse()

-- ===== НАСТРОЙКИ ПРЕДИКШЕНА (шот мардер) =====
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
        RoleESP = {
            Enabled = false,
            Boxes = false,
            Skeletons = false,
            Names = false,
            Chams = false,
            Outline = false
        },
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
        SpeedGlitchEnabled = false,
        SpeedGlitchValue = 20,
        StretchEnabled = false
    },
    VisualsWorld = {
        TrailEnabled = false,
        FogEnabled = false,
        JumpCircleEnabled = false,
        ChinaHatEnabled = false,
        Color = Color3.fromRGB(255, 0, 100),
        TrailLifetime = 0.5,
        FogDistance = 200,
        ChinaHatSize = 3.5
    }
}

--// Хранилище позиций кнопок (для конфигов)
local ButtonPositions = {}

--// Локальные переменные
local ScreenCenter = Camera.ViewportSize / 2
local VisualStorage = {}
local Connections = {}
local env = { OldPos = nil, timeout = 2.5 }
local jumpPressed = false
local doubleJumpCount = 0
local lastVisualUpdate = 0
local menuOpen = false

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

--// ScreenGui для биндов (кнопок) – оставим для совместимости
local BindGui = Instance.new("ScreenGui")
BindGui.Name = "VillonHub_MM2_Menu"
BindGui.ResetOnSpawn = false
BindGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
if gethui then
    BindGui.Parent = gethui()
else
    BindGui.Parent = CoreGui
end

-- ============================================================
--   ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ (из deepko)
-- ============================================================
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

local function setupJumpTracker(char)
    local hum = char:WaitForChild("Humanoid")
    hum.Jumping:Connect(function()
        if Options.Misc.DoubleJump then
            if hum:GetState() == Enum.HumanoidStateType.Freefall and doubleJumpCount < 1 then
                hum:ChangeState(Enum.HumanoidStateType.Jumping)
                doubleJumpCount = 1
            end
        end
    end)
end

if LocalPlayer.Character then setupJumpTracker(LocalPlayer.Character) end
LocalPlayer.CharacterAdded:Connect(function(char)
    task.wait(0.5)
    setupJumpTracker(char)
end)

local InputBeganCon = UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.KeyCode == Enum.KeyCode.Space then
        jumpPressed = true
    end
end)
local InputEndedCon = UserInputService.InputEnded:Connect(function(input)
    if input.KeyCode == Enum.KeyCode.Space then
        jumpPressed = false
    end
end)
table.insert(Connections, InputBeganCon)
table.insert(Connections, InputEndedCon)

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
        if Options.MM2.RoleESP.Enabled or Options.MM2.AimMurderOnly or Options.MM2.AutoAimMurder or Options.MM2.ShootMurderButtonEnabled or Options.MM2.FlingButtonEnabled or Options.MM2.KillAllButtonEnabled then
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

-- ============================================================
--   ШОТ МАРДЕР (с кешем, предрасчётом, асинхронным выстрелом)
-- ============================================================
local smCachedRoles = {}
task.spawn(function()
    while true do
        local success, data = pcall(function()
            return ReplicatedStorage:FindFirstChild("GetPlayerData", true):InvokeServer()
        end)
        if success and data then
            local roles = {}
            for plr, plrData in pairs(data) do
                if not plrData.Dead then
                    roles[plr] = plrData.Role
                end
            end
            smCachedRoles = roles
        end
        task.wait(0.15)
    end
end)

local function smGetPing()
    if LocalPlayer and LocalPlayer.GetNetworkPing then
        return LocalPlayer:GetNetworkPing() * 1000
    end
    return 0
end

local smCachedTarget = nil
task.spawn(function()
    while true do
        local myChar = LocalPlayer.Character
        local myPos = myChar and myChar:FindFirstChild("HumanoidRootPart") and myChar.HumanoidRootPart.Position
        if myPos then
            local bestTarget = nil
            local bestScore = math.huge
            for plr, role in pairs(smCachedRoles) do
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
                                local pingMs = smGetPing()
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
            smCachedTarget = bestTarget
        end
        task.wait(0.05)
    end
end)

local function smEquipGun()
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

local smShootRemote = nil
local function smFindShootRemote()
    for _, obj in ipairs(ReplicatedStorage:GetDescendants()) do
        if obj:IsA("RemoteFunction") and (obj.Name:lower():find("shoot") or obj.Name:lower():find("fire") or obj.Name:lower():find("beam")) then
            return obj
        end
    end
    return nil
end
smShootRemote = smFindShootRemote()
task.spawn(function()
    while true do
        local newRemote = smFindShootRemote()
        if newRemote then smShootRemote = newRemote end
        task.wait(2)
    end
end)

local function shootMurderer()
    local char = LocalPlayer.Character
    if not char then
        StarterGui:SetCore("SendNotification", { Title = "Ошибка", Text = "Вы не в игре", Duration = 2 })
        return
    end

    local gun = char:FindFirstChild("Gun")
    if not gun then
        if not smEquipGun() then
            StarterGui:SetCore("SendNotification", { Title = "Ошибка", Text = "Нет пистолета", Duration = 2 })
            return
        end
        gun = char:FindFirstChild("Gun")
        if not gun then return end
    end

    local targetPos = smCachedTarget
    if not targetPos then
        StarterGui:SetCore("SendNotification", { Title = "Ошибка", Text = "Убийца не найден", Duration = 2 })
        return
    end

    task.spawn(function()
        if smShootRemote then
            pcall(function()
                smShootRemote:InvokeServer(1, targetPos, "AH2")
            end)
        else
            local shoot = gun:FindFirstChild("Shoot")
            if shoot then
                local gunCFrame = gun:FindFirstChild("Handle") and gun.Handle.CFrame or gun.CFrame
                pcall(function()
                    shoot:FireServer(gunCFrame, CFrame.new(targetPos))
                end)
            else
                StarterGui:SetCore("SendNotification", { Title = "Ошибка", Text = "Remote не найден", Duration = 2 })
            end
        end
    end)
end

-- ============================================================
--   ОСТАЛЬНЫЕ ФУНКЦИИ (флинг, KillAll, аим, ESP)
-- ============================================================

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
            if targetPart then
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
                if Options.Aimbot.TeamCheck and player.Team == LocalPlayer.Team and not Options.MM2.RoleESP.Enabled then continue end
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
        if Options.MM2.AutoAimMurder then
            local gun = localChar:FindFirstChild("Gun")
            if not gun then equipGun() end
            gun = localChar:FindFirstChild("Gun")
            if gun and gun:FindFirstChild("KnifeLocal") then
                local targetPos = smCachedTarget
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

    -- Бинды кнопок (AIM, TP GUN, etc.) – оставим, но они не нужны в новом GUI, так как всё уже есть
    -- Но чтобы не ломать совместимость, оставляем их создание (они уже есть в BindGui)
end)
table.insert(Connections, MasterRenderLoop)

-- ============================================================
--   РАСТЯГ (тоггл в Misc)
-- ============================================================
local stretchConnection = nil
local function updateStretch()
    if stretchConnection then
        stretchConnection:Disconnect()
        stretchConnection = nil
    end
    if Options.Misc.StretchEnabled then
        local stretchResolution = 0.80
        stretchConnection = RunService.RenderStepped:Connect(function()
            Camera.CFrame = Camera.CFrame * CFrame.new(0, 0, 0, 1, 0, 0, 0, stretchResolution, 0, 0, 0, 1)
        end)
    end
end
updateStretch()

-- ============================================================
--   VISUAL WORLD EFFECTS
-- ============================================================
local ActiveWorldObjects = {
    Trail = nil,
    TrailParticles = nil,
    ChinaHat = nil,
}

local OriginalFog = {
    Color = Lighting.FogColor,
    End = Lighting.FogEnd,
    Start = Lighting.FogStart
}

local function updateWorldEffects()
    local color = Options.VisualsWorld.Color
    if Options.VisualsWorld.TrailEnabled and ActiveWorldObjects.Trail then
        ActiveWorldObjects.Trail.Color = ColorSequence.new(color)
        ActiveWorldObjects.Trail.Lifetime = Options.VisualsWorld.TrailLifetime
    end
    if Options.VisualsWorld.TrailEnabled and ActiveWorldObjects.TrailParticles then
        ActiveWorldObjects.TrailParticles.Color = ColorSequence.new(color)
    end
    if Options.VisualsWorld.FogEnabled then
        Lighting.FogColor = color
        Lighting.FogEnd = Options.VisualsWorld.FogDistance
    end
    if Options.VisualsWorld.ChinaHatEnabled and ActiveWorldObjects.ChinaHat then
        ActiveWorldObjects.ChinaHat.Color = color
        local mesh = ActiveWorldObjects.ChinaHat:FindFirstChildOfClass("SpecialMesh")
        if mesh then
            mesh.Scale = Vector3.new(Options.VisualsWorld.ChinaHatSize, 1.2, Options.VisualsWorld.ChinaHatSize)
        end
        ActiveWorldObjects.ChinaHat.Size = Vector3.new(Options.VisualsWorld.ChinaHatSize, 1.2, Options.VisualsWorld.ChinaHatSize)
    end
end

local function toggleTrail(state)
    Options.VisualsWorld.TrailEnabled = state
    if not state then
        if ActiveWorldObjects.Trail then ActiveWorldObjects.Trail:Destroy() ActiveWorldObjects.Trail = nil end
        if ActiveWorldObjects.TrailParticles then ActiveWorldObjects.TrailParticles:Destroy() ActiveWorldObjects.TrailParticles = nil end
        return
    end

    local char = LocalPlayer.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then return end
    local hrp = char.HumanoidRootPart

    if ActiveWorldObjects.Trail then ActiveWorldObjects.Trail:Destroy() end
    if ActiveWorldObjects.TrailParticles then ActiveWorldObjects.TrailParticles:Destroy() end

    local a0 = hrp:FindFirstChild("TrailA0") or Instance.new("Attachment", hrp)
    a0.Position = Vector3.new(0, 1, 0)
    a0.Name = "TrailA0"

    local a1 = hrp:FindFirstChild("TrailA1") or Instance.new("Attachment", hrp)
    a1.Position = Vector3.new(0, -1, 0)
    a1.Name = "TrailA1"

    local trail = Instance.new("Trail")
    trail.Attachment0 = a0
    trail.Attachment1 = a1
    trail.Color = ColorSequence.new(Options.VisualsWorld.Color)
    trail.Lifetime = Options.VisualsWorld.TrailLifetime
    trail.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.1),
        NumberSequenceKeypoint.new(1, 1)
    })
    trail.Parent = hrp
    ActiveWorldObjects.Trail = trail

    local sparks = Instance.new("ParticleEmitter")
    sparks.Texture = "rbxassetid://258122325"
    sparks.Color = ColorSequence.new(Options.VisualsWorld.Color)
    sparks.Size = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.4),
        NumberSequenceKeypoint.new(1, 0)
    })
    sparks.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0),
        NumberSequenceKeypoint.new(1, 1)
    })
    sparks.Rate = 20
    sparks.Speed = NumberRange.new(1, 3)
    sparks.Lifetime = NumberRange.new(0.3, 0.6)
    sparks.SpreadAngle = Vector2.new(45, 45)
    sparks.Parent = hrp
    ActiveWorldObjects.TrailParticles = sparks
end

local function toggleFog(state)
    Options.VisualsWorld.FogEnabled = state
    if not state then
        Lighting.FogColor = OriginalFog.Color
        Lighting.FogEnd = OriginalFog.End
        Lighting.FogStart = OriginalFog.Start
        return
    end
    Lighting.FogColor = Options.VisualsWorld.Color
    Lighting.FogStart = 0
    Lighting.FogEnd = Options.VisualsWorld.FogDistance
end

local function toggleJumpCircle(state)
    Options.VisualsWorld.JumpCircleEnabled = state
end

local function onJump()
    if not Options.VisualsWorld.JumpCircleEnabled then return end
    local char = LocalPlayer.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then return end
    local hrp = char.HumanoidRootPart

    local ringPart = Instance.new("Part")
    ringPart.Size = Vector3.new(0.05, 0.5, 0.5)
    ringPart.CFrame = (hrp.CFrame * CFrame.new(0, -2.8, 0)) * CFrame.Angles(0, 0, math.rad(90))
    ringPart.Anchored = true
    ringPart.CanCollide = false
    ringPart.Color = Options.VisualsWorld.Color
    ringPart.Material = Enum.Material.Neon

    local mesh = Instance.new("SpecialMesh")
    mesh.MeshType = Enum.MeshType.Cylinder
    mesh.Parent = ringPart
    ringPart.Parent = workspace

    local tweenInfo = TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    local goal = {
        Size = Vector3.new(0.05, 7, 7),
        Transparency = 1
    }
    local tween = TweenService:Create(ringPart, tweenInfo, goal)
    tween.Completed:Connect(function() ringPart:Destroy() end)
    tween:Play()
end

local function toggleChinaHat(state)
    Options.VisualsWorld.ChinaHatEnabled = state
    if not state then
        if ActiveWorldObjects.ChinaHat then
            ActiveWorldObjects.ChinaHat:Destroy()
            ActiveWorldObjects.ChinaHat = nil
        end
        return
    end

    local char = LocalPlayer.Character
    if not char or not char:FindFirstChild("Head") then return end

    if ActiveWorldObjects.ChinaHat then ActiveWorldObjects.ChinaHat:Destroy() end

    local hat = Instance.new("Part")
    hat.Name = "ChinaHat"
    hat.Size = Vector3.new(Options.VisualsWorld.ChinaHatSize, 1.2, Options.VisualsWorld.ChinaHatSize)
    hat.Color = Options.VisualsWorld.Color
    hat.Material = Enum.Material.Neon
    hat.CanCollide = false
    hat.Massless = true

    local mesh = Instance.new("SpecialMesh")
    mesh.MeshType = Enum.MeshType.Cone
    mesh.Scale = Vector3.new(Options.VisualsWorld.ChinaHatSize, 1.2, Options.VisualsWorld.ChinaHatSize)
    mesh.Parent = hat

    local weld = Instance.new("Weld")
    weld.Part0 = char.Head
    weld.Part1 = hat
    weld.C0 = CFrame.new(0, 1.3, 0)
    weld.Parent = hat

    hat.Parent = char
    ActiveWorldObjects.ChinaHat = hat
end

local function updateAllWorldEffects()
    if Options.VisualsWorld.TrailEnabled then
        toggleTrail(true)
    elseif ActiveWorldObjects.Trail then
        ActiveWorldObjects.Trail:Destroy()
        ActiveWorldObjects.Trail = nil
        if ActiveWorldObjects.TrailParticles then
            ActiveWorldObjects.TrailParticles:Destroy()
            ActiveWorldObjects.TrailParticles = nil
        end
    end
    if Options.VisualsWorld.FogEnabled then
        toggleFog(true)
    else
        Lighting.FogColor = OriginalFog.Color
        Lighting.FogEnd = OriginalFog.End
        Lighting.FogStart = OriginalFog.Start
    end
    if Options.VisualsWorld.ChinaHatEnabled then
        toggleChinaHat(true)
    elseif ActiveWorldObjects.ChinaHat then
        ActiveWorldObjects.ChinaHat:Destroy()
        ActiveWorldObjects.ChinaHat = nil
    end
    updateWorldEffects()
end

-- ============================================================
--   CONFIGS (сохранение/загрузка через файл)
-- ============================================================
local function saveConfig(name)
    if name == "" then return showVillonNotice("Введите имя") end
    local configData = {
        Options = Options,
        ButtonPositions = ButtonPositions
    }
    local json = HttpService:JSONEncode(configData)
    local success, err = pcall(function()
        writefile("VillonConfigs/" .. name .. ".json", json)
    end)
    if success then
        showVillonNotice("Конфиг сохранён")
    else
        showVillonNotice("Ошибка сохранения: " .. tostring(err))
    end
end

local function loadConfig(name)
    if name == "" then return showVillonNotice("Введите имя") end
    local success, data = pcall(function()
        return readfile("VillonConfigs/" .. name .. ".json")
    end)
    if not success or not data then
        return showVillonNotice("Конфиг не найден")
    end
    local configData = HttpService:JSONDecode(data)
    if configData.Options then
        for k, v in pairs(configData.Options) do
            Options[k] = v
        end
    end
    if configData.ButtonPositions then
        for name, pos in pairs(configData.ButtonPositions) do
            local btn = BindGui:FindFirstChild(name)
            if btn then
                if pos.OffsetX and pos.OffsetY then
                    btn.Position = UDim2.new(pos.X, pos.OffsetX or 0, pos.Y, pos.OffsetY or 0)
                else
                    btn.Position = UDim2.new(pos.X, 0, pos.Y, 0)
                end
                ButtonPositions[name] = pos
            end
        end
    end
    updateAllWorldEffects()
    updateStretch()
    showVillonNotice("Конфиг загружен")
end

-- ============================================================
--   GUI – КАСТОМНОЕ (полностью из твоего файла, но с нашими названиями и функциями)
-- ============================================================

-- Создаём ScreenGui
local playerGui = LocalPlayer:WaitForChild("PlayerGui")
if playerGui:FindFirstChild("VillonHub") then
    playerGui.VillonHub:Destroy()
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "VillonHub"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = playerGui

------------------------------------------------------------------
-- 1. INTRO (снежинки, кнопка Start)
------------------------------------------------------------------
local intro = Instance.new("Frame")
intro.Size = UDim2.new(1, 0, 1, 0)
intro.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
intro.BorderSizePixel = 0
intro.ZIndex = 50
intro.Parent = screenGui

local snowFolder = Instance.new("Folder")
snowFolder.Name = "Snow"
snowFolder.Parent = intro

local function createSnowflake()
    local flake = Instance.new("Frame")
    flake.Size = UDim2.new(0, math.random(2, 4), 0, math.random(2, 4))
    flake.Position = UDim2.new(math.random(), 0, -0.05, 0)
    flake.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    flake.BackgroundTransparency = math.random(10, 40) / 100
    flake.BorderSizePixel = 0
    flake.ZIndex = 51
    flake.Parent = snowFolder

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(1, 0)
    corner.Parent = flake

    local duration = math.random(4, 8)
    local endPos = UDim2.new(flake.Position.X.Scale + math.random(-10, 10) / 100, 0, 1.1, 0)

    TweenService:Create(flake, TweenInfo.new(duration, Enum.EasingStyle.Linear), {
        Position = endPos,
        BackgroundTransparency = 1
    }):Play()

    task.delay(duration, function()
        if flake and flake.Parent then
            flake:Destroy()
        end
    end)
end

local snowConnection
snowConnection = RunService.Heartbeat:Connect(function()
    if math.random() < 0.35 then
        createSnowflake()
    end
end)

local title = Instance.new("TextLabel")
title.Size = UDim2.new(0, 300, 0, 50)
title.Position = UDim2.new(0.5, -150, 0.42, 0)
title.BackgroundTransparency = 1
title.Text = "VillonHub"
title.Font = Enum.Font.GothamBold
title.TextSize = 36
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.TextTransparency = 1
title.ZIndex = 52
title.Parent = intro

local startBtn = Instance.new("TextButton")
startBtn.Size = UDim2.new(0, 140, 0, 42)
startBtn.Position = UDim2.new(0.5, -70, 0.55, 0)
startBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 48)
startBtn.Text = "Start"
startBtn.Font = Enum.Font.GothamMedium
startBtn.TextSize = 18
startBtn.TextColor3 = Color3.fromRGB(230, 230, 235)
startBtn.TextTransparency = 1
startBtn.BackgroundTransparency = 1
startBtn.AutoButtonColor = false
startBtn.ZIndex = 52
startBtn.Parent = intro

local startCorner = Instance.new("UICorner")
startCorner.CornerRadius = UDim.new(0, 10)
startCorner.Parent = startBtn

local startStroke = Instance.new("UIStroke")
startStroke.Color = Color3.fromRGB(120, 120, 130)
startStroke.Thickness = 1
startStroke.Transparency = 1
startStroke.Parent = startBtn

TweenService:Create(title, TweenInfo.new(1.2, Enum.EasingStyle.Quad), {TextTransparency = 0}):Play()
task.wait(0.4)
TweenService:Create(startBtn, TweenInfo.new(0.8), {TextTransparency = 0, BackgroundTransparency = 0.15}):Play()
TweenService:Create(startStroke, TweenInfo.new(0.8), {Transparency = 0.4}):Play()

startBtn.MouseEnter:Connect(function()
    TweenService:Create(startBtn, TweenInfo.new(0.15), {
        BackgroundColor3 = Color3.fromRGB(55, 55, 65),
        Size = UDim2.new(0, 148, 0, 44)
    }):Play()
end)
startBtn.MouseLeave:Connect(function()
    TweenService:Create(startBtn, TweenInfo.new(0.15), {
        BackgroundColor3 = Color3.fromRGB(40, 40, 48),
        Size = UDim2.new(0, 140, 0, 42)
    }):Play()
end)

------------------------------------------------------------------
-- Блокировка камеры
------------------------------------------------------------------
local function freezeCamera(state)
    if state then
        ContextActionService:BindAction("VillonFreezeCam", function()
            return Enum.ContextActionResult.Sink
        end, false, Enum.UserInputType.MouseMovement, Enum.UserInputType.Touch)
    else
        ContextActionService:UnbindAction("VillonFreezeCam")
    end
end

------------------------------------------------------------------
-- 2. ПУЗЫРЬ (ник убран, перетаскивание только слева)
------------------------------------------------------------------
local bubble = Instance.new("Frame")
bubble.Name = "OpenBubble"
bubble.Size = UDim2.new(0, 140, 0, 36)
bubble.Position = UDim2.new(0.5, -70, 0.08, 0)
bubble.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
bubble.BackgroundTransparency = 0.25
bubble.BorderSizePixel = 0
bubble.Visible = false
bubble.ZIndex = 40
bubble.Parent = screenGui

local bubbleCorner = Instance.new("UICorner")
bubbleCorner.CornerRadius = UDim.new(1, 0)
bubbleCorner.Parent = bubble

local bubbleStroke = Instance.new("UIStroke")
bubbleStroke.Color = Color3.fromRGB(180, 180, 190)
bubbleStroke.Thickness = 1
bubbleStroke.Transparency = 0.6
bubbleStroke.Parent = bubble

-- Левая зона для перетаскивания
local dragZone = Instance.new("Frame")
dragZone.Name = "DragZone"
dragZone.Size = UDim2.new(0, 28, 1, 0)
dragZone.Position = UDim2.new(0, 0, 0, 0)
dragZone.BackgroundTransparency = 1
dragZone.Parent = bubble

local leftArrow = Instance.new("TextLabel")
leftArrow.Size = UDim2.new(1, 0, 1, 0)
leftArrow.BackgroundTransparency = 1
leftArrow.Text = "‹"
leftArrow.Font = Enum.Font.GothamBold
leftArrow.TextSize = 18
leftArrow.TextColor3 = Color3.fromRGB(160, 160, 170)
leftArrow.Parent = dragZone

local rightArrow = Instance.new("TextLabel")
rightArrow.Size = UDim2.new(0, 14, 1, 0)
rightArrow.Position = UDim2.new(1, -18, 0, 0)
rightArrow.BackgroundTransparency = 1
rightArrow.Text = "›"
rightArrow.Font = Enum.Font.GothamBold
rightArrow.TextSize = 16
rightArrow.TextColor3 = Color3.fromRGB(160, 160, 170)
rightArrow.Parent = bubble

local bubbleText = Instance.new("TextLabel")
bubbleText.Size = UDim2.new(1, -40, 1, 0)
bubbleText.Position = UDim2.new(0, 26, 0, 0)
bubbleText.BackgroundTransparency = 1
bubbleText.Text = "VillonHub"
bubbleText.Font = Enum.Font.GothamMedium
bubbleText.TextSize = 14
bubbleText.TextColor3 = Color3.fromRGB(230, 230, 235)
bubbleText.Parent = bubble

-- Перетаскивание ТОЛЬКО за левую зону
local bubbleDragging = false
local bubbleMoved = false
local bubbleDragStart, bubbleStartPos
local dragThreshold = 6

dragZone.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        bubbleDragging = true
        bubbleMoved = false
        bubbleDragStart = input.Position
        bubbleStartPos = bubble.Position
        freezeCamera(true)
    end
end)

dragZone.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        bubbleDragging = false
        freezeCamera(false)
    end
end)

-- Клик по всему пузырю (кроме зоны драга обрабатывается отдельно)
bubble.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        local relativeX = input.Position.X - bubble.AbsolutePosition.X
        if relativeX > 28 then
            bubbleMoved = false
            task.delay(0.05, function()
                if not bubbleMoved and not bubbleDragging then
                    if menuOpen then
                        closeMenu()
                    else
                        openMenu()
                    end
                end
            end)
        end
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if bubbleDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - bubbleDragStart
        if delta.Magnitude > dragThreshold then
            bubbleMoved = true
        end
        bubble.Position = UDim2.new(
            bubbleStartPos.X.Scale,
            bubbleStartPos.X.Offset + delta.X,
            bubbleStartPos.Y.Scale,
            bubbleStartPos.Y.Offset + delta.Y
        )
    end
end)

------------------------------------------------------------------
-- 3. ОСНОВНОЕ МЕНЮ
------------------------------------------------------------------
local main = Instance.new("Frame")
main.Name = "Main"
main.Size = UDim2.new(0, 420, 0, 280)
main.Position = UDim2.new(0.5, -210, 0.5, -140)
main.BackgroundColor3 = Color3.fromRGB(16, 16, 19)
main.BorderSizePixel = 0
main.Visible = false
main.ClipsDescendants = true
main.ZIndex = 30
main.Parent = screenGui

local mainCorner = Instance.new("UICorner")
mainCorner.CornerRadius = UDim.new(0, 11)
mainCorner.Parent = main

local mainStroke = Instance.new("UIStroke")
mainStroke.Color = Color3.fromRGB(50, 50, 58)
mainStroke.Thickness = 1
mainStroke.Parent = main

local header = Instance.new("Frame")
header.Size = UDim2.new(1, 0, 0, 36)
header.BackgroundColor3 = Color3.fromRGB(20, 20, 24)
header.BorderSizePixel = 0
header.Parent = main

local headerCorner = Instance.new("UICorner")
headerCorner.CornerRadius = UDim.new(0, 11)
headerCorner.Parent = header

local logo = Instance.new("TextLabel")
logo.Size = UDim2.new(0, 140, 1, 0)
logo.Position = UDim2.new(0, 12, 0, 0)
logo.BackgroundTransparency = 1
logo.Text = "VILLONHUB"
logo.Font = Enum.Font.GothamBold
logo.TextSize = 15
logo.TextColor3 = Color3.fromRGB(230, 230, 235)
logo.TextXAlignment = Enum.TextXAlignment.Left
logo.Parent = header

local nickFrame = Instance.new("Frame")
nickFrame.Size = UDim2.new(0, 105, 0, 24)
nickFrame.Position = UDim2.new(1, -115, 0.5, -12)
nickFrame.BackgroundColor3 = Color3.fromRGB(32, 32, 38)
nickFrame.BorderSizePixel = 0
nickFrame.Parent = header

local nickCorner = Instance.new("UICorner")
nickCorner.CornerRadius = UDim.new(0, 6)
nickCorner.Parent = nickFrame

local avatar = Instance.new("Frame")
avatar.Size = UDim2.new(0, 18, 0, 18)
avatar.Position = UDim2.new(0, 4, 0.5, -9)
avatar.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
avatar.BorderSizePixel = 0
avatar.Parent = nickFrame

local avatarCorner = Instance.new("UICorner")
avatarCorner.CornerRadius = UDim.new(1, 0)
avatarCorner.Parent = avatar

local nickLabel = Instance.new("TextLabel")
nickLabel.Size = UDim2.new(1, -26, 0, 12)
nickLabel.Position = UDim2.new(0, 26, 0, 1)
nickLabel.BackgroundTransparency = 1
nickLabel.Text = player.Name
nickLabel.Font = Enum.Font.GothamMedium
nickLabel.TextSize = 11
nickLabel.TextColor3 = Color3.fromRGB(230, 230, 235)
nickLabel.TextXAlignment = Enum.TextXAlignment.Left
nickLabel.Parent = nickFrame

local statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.new(1, -26, 0, 10)
statusLabel.Position = UDim2.new(0, 26, 0, 12)
statusLabel.BackgroundTransparency = 1
statusLabel.Text = "Online"
statusLabel.Font = Enum.Font.Gotham
statusLabel.TextSize = 9
statusLabel.TextColor3 = Color3.fromRGB(100, 200, 120)
statusLabel.TextXAlignment = Enum.TextXAlignment.Left
statusLabel.Parent = nickFrame

-- Перетаскивание меню
local mainDragging = false
local mainDragStart, mainStartPos

header.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        mainDragging = true
        mainDragStart = input.Position
        mainStartPos = main.Position
        freezeCamera(true)
    end
end)

header.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        mainDragging = false
        freezeCamera(false)
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if mainDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - mainDragStart
        main.Position = UDim2.new(
            mainStartPos.X.Scale,
            mainStartPos.X.Offset + delta.X,
            mainStartPos.Y.Scale,
            mainStartPos.Y.Offset + delta.Y
        )
    end
end)

-- Контент
local content = Instance.new("Frame")
content.Size = UDim2.new(1, -16, 1, -78)
content.Position = UDim2.new(0, 8, 0, 42)
content.BackgroundTransparency = 1
content.ClipsDescendants = true
content.Parent = main

-- Функция создания панели
local function createPanel(titleText)
    local panel = Instance.new("Frame")
    panel.Size = UDim2.new(1, 0, 1, 0)
    panel.BackgroundColor3 = Color3.fromRGB(24, 24, 29)
    panel.BorderSizePixel = 0
    panel.Visible = false
    panel.Parent = content

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 9)
    corner.Parent = panel

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(48, 48, 55)
    stroke.Thickness = 1
    stroke.Parent = panel

    local titleLabel = Instance.new("TextLabel")
    titleLabel.Size = UDim2.new(1, -14, 0, 22)
    titleLabel.Position = UDim2.new(0, 10, 0, 6)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = titleText
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.TextSize = 13
    titleLabel.TextColor3 = Color3.fromRGB(230, 230, 235)
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.Parent = panel

    local scroll = Instance.new("ScrollingFrame")
    scroll.Size = UDim2.new(1, -12, 1, -32)
    scroll.Position = UDim2.new(0, 6, 0, 28)
    scroll.BackgroundTransparency = 1
    scroll.BorderSizePixel = 0
    scroll.ScrollBarThickness = 3
    scroll.ScrollBarImageColor3 = Color3.fromRGB(90, 90, 100)
    scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    scroll.Parent = panel

    local listLayout = Instance.new("UIListLayout")
    listLayout.SortOrder = Enum.SortOrder.LayoutOrder
    listLayout.Padding = UDim.new(0, 6)
    listLayout.Parent = scroll

    local padding = Instance.new("UIPadding")
    padding.PaddingTop = UDim.new(0, 4)
    padding.PaddingBottom = UDim.new(0, 8)
    padding.PaddingLeft = UDim.new(0, 4)
    padding.PaddingRight = UDim.new(0, 4)
    padding.Parent = scroll

    return panel, scroll
end

-- Создаём панели с нашими названиями
local combatPanel, combatScroll = createPanel("Combat")
local visualsPanel, visualsScroll = createPanel("Visuals")
local mm2Panel, mm2Scroll = createPanel("MM2")
local miscPanel, miscScroll = createPanel("Misc")
local changeFlingPanel, changeFlingScroll = createPanel("Change Fling")
local configsPanel, configsScroll = createPanel("Configs")
local visualWorldPanel, visualWorldScroll = createPanel("VisualWorld")

combatPanel.Visible = true

-- Вкладки
local tabBar = Instance.new("Frame")
tabBar.Size = UDim2.new(1, 0, 0, 34)
tabBar.Position = UDim2.new(0, 0, 1, -34)
tabBar.BackgroundColor3 = Color3.fromRGB(20, 20, 24)
tabBar.BorderSizePixel = 0
tabBar.Parent = main

local tabCorner = Instance.new("UICorner")
tabCorner.CornerRadius = UDim.new(0, 11)
tabCorner.Parent = tabBar

local tabs = {
    {Name = "Combat", Panel = combatPanel},
    {Name = "Visuals", Panel = visualsPanel},
    {Name = "MM2", Panel = mm2Panel},
    {Name = "Misc", Panel = miscPanel},
    {Name = "Change Fling", Panel = changeFlingPanel},
    {Name = "Configs", Panel = configsPanel},
    {Name = "VisualWorld", Panel = visualWorldPanel},
}

local tabButtons = {}
local currentPanel = combatPanel
local tabWidth = 1 / #tabs

for i, data in ipairs(tabs) do
    local tab = Instance.new("TextButton")
    tab.Size = UDim2.new(tabWidth, 0, 1, 0)
    tab.Position = UDim2.new(tabWidth * (i - 1), 0, 0, 0)
    tab.BackgroundTransparency = 1
    tab.Text = data.Name
    tab.Font = Enum.Font.GothamMedium
    tab.TextSize = 10
    tab.TextColor3 = Color3.fromRGB(120, 120, 135)
    tab.AutoButtonColor = false
    tab.Parent = tabBar

    local underline = Instance.new("Frame")
    underline.Size = UDim2.new(0.5, 0, 0, 2)
    underline.Position = UDim2.new(0.25, 0, 1, -3)
    underline.BackgroundColor3 = Color3.fromRGB(160, 160, 170)
    underline.BorderSizePixel = 0
    underline.Visible = (i == 1)
    underline.Parent = tab

    if i == 1 then
        tab.TextColor3 = Color3.fromRGB(230, 230, 235)
    end

    tab.MouseButton1Click:Connect(function()
        if currentPanel == data.Panel then return end

        local oldPanel = currentPanel
        TweenService:Create(oldPanel, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
            Position = UDim2.new(-0.15, 0, 0, 0),
            BackgroundTransparency = 0.4
        }):Play()

        task.delay(0.12, function()
            oldPanel.Visible = false
            oldPanel.Position = UDim2.new(0, 0, 0, 0)
            oldPanel.BackgroundTransparency = 0
        end)

        data.Panel.Visible = true
        data.Panel.Position = UDim2.new(0.15, 0, 0, 0)
        data.Panel.BackgroundTransparency = 0.4

        TweenService:Create(data.Panel, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Position = UDim2.new(0, 0, 0, 0),
            BackgroundTransparency = 0
        }):Play()

        currentPanel = data.Panel

        for _, t in pairs(tabButtons) do
            t.TextColor3 = Color3.fromRGB(120, 120, 135)
            local u = t:FindFirstChildOfClass("Frame")
            if u then u.Visible = false end
        end
        tab.TextColor3 = Color3.fromRGB(230, 230, 235)
        underline.Visible = true
    end)

    tabButtons[i] = tab
end

------------------------------------------------------------------
-- ФУНКЦИИ СОЗДАНИЯ ЭЛЕМЕНТОВ GUI
------------------------------------------------------------------
local function createToggle(parent, text, default, callback)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, -8, 0, 26)
    frame.BackgroundTransparency = 1
    frame.Parent = parent

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -46, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = text
    label.Font = Enum.Font.Gotham
    label.TextSize = 12
    label.TextColor3 = Color3.fromRGB(175, 175, 185)
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = frame

    local toggle = Instance.new("TextButton")
    toggle.Size = UDim2.new(0, 34, 0, 16)
    toggle.Position = UDim2.new(1, -38, 0.5, -8)
    toggle.BackgroundColor3 = default and Color3.fromRGB(85, 85, 95) or Color3.fromRGB(42, 42, 50)
    toggle.Text = ""
    toggle.AutoButtonColor = false
    toggle.Parent = frame

    local toggleCorner = Instance.new("UICorner")
    toggleCorner.CornerRadius = UDim.new(1, 0)
    toggleCorner.Parent = toggle

    local circle = Instance.new("Frame")
    circle.Size = UDim2.new(0, 12, 0, 12)
    circle.Position = default and UDim2.new(1, -14, 0.5, -6) or UDim2.new(0, 2, 0.5, -6)
    circle.BackgroundColor3 = Color3.fromRGB(220, 220, 230)
    circle.BorderSizePixel = 0
    circle.Parent = toggle

    local circleCorner = Instance.new("UICorner")
    circleCorner.CornerRadius = UDim.new(1, 0)
    circleCorner.Parent = circle

    local state = default
    toggle.MouseButton1Click:Connect(function()
        state = not state
        local goalColor = state and Color3.fromRGB(85, 85, 95) or Color3.fromRGB(42, 42, 50)
        local goalPos = state and UDim2.new(1, -14, 0.5, -6) or UDim2.new(0, 2, 0.5, -6)

        TweenService:Create(toggle, TweenInfo.new(0.16), {BackgroundColor3 = goalColor}):Play()
        TweenService:Create(circle, TweenInfo.new(0.16), {Position = goalPos}):Play()

        TweenService:Create(toggle, TweenInfo.new(0.08), {Size = UDim2.new(0, 36, 0, 17)}):Play()
        task.wait(0.08)
        TweenService:Create(toggle, TweenInfo.new(0.08), {Size = UDim2.new(0, 34, 0, 16)}):Play()

        if callback then callback(state) end
    end)

    return toggle
end

local function createSlider(parent, text, value, callback)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, -8, 0, 26)
    frame.BackgroundTransparency = 1
    frame.Parent = parent

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0.6, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = text
    label.Font = Enum.Font.Gotham
    label.TextSize = 12
    label.TextColor3 = Color3.fromRGB(175, 175, 185)
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = frame

    local valueBox = Instance.new("TextLabel")
    valueBox.Size = UDim2.new(0, 40, 0, 20)
    valueBox.Position = UDim2.new(1, -44, 0.5, -10)
    valueBox.BackgroundColor3 = Color3.fromRGB(38, 38, 45)
    valueBox.Text = tostring(value)
    valueBox.Font = Enum.Font.GothamMedium
    valueBox.TextSize = 11
    valueBox.TextColor3 = Color3.fromRGB(220, 220, 230)
    valueBox.Parent = frame

    local valueCorner = Instance.new("UICorner")
    valueCorner.CornerRadius = UDim.new(0, 5)
    valueCorner.Parent = valueBox

    -- Сделаем ползунок – упрощённо (для демонстрации)
    -- Можно добавить кнопки + и -, но для простоты оставим как есть
    -- Мы будем использовать клик по значению для изменения
    valueBox.MouseButton1Click:Connect(function()
        local newVal = value + 5
        if newVal > 100 then newVal = 0 end
        value = newVal
        valueBox.Text = tostring(value)
        if callback then callback(value) end
    end)
end

local function createExecuteButton(parent, text)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, -8, 0, 28)
    btn.BackgroundColor3 = Color3.fromRGB(48, 48, 56)
    btn.Text = text
    btn.Font = Enum.Font.GothamMedium
    btn.TextSize = 12
    btn.TextColor3 = Color3.fromRGB(220, 220, 230)
    btn.AutoButtonColor = false
    btn.Parent = parent

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = btn

    btn.MouseEnter:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.12), {
            BackgroundColor3 = Color3.fromRGB(62, 62, 72)
        }):Play()
    end)

    btn.MouseLeave:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.12), {
            BackgroundColor3 = Color3.fromRGB(48, 48, 56)
        }):Play()
    end)

    btn.MouseButton1Click:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.06), {
            BackgroundColor3 = Color3.fromRGB(90, 90, 105),
            Size = UDim2.new(1, -12, 0, 26)
        }):Play()
        task.wait(0.06)
        TweenService:Create(btn, TweenInfo.new(0.12), {
            BackgroundColor3 = Color3.fromRGB(48, 48, 56),
            Size = UDim2.new(1, -8, 0, 28)
        }):Play()
    end)

    return btn
end

------------------------------------------------------------------
-- ЗАПОЛНЕНИЕ ПАНЕЛЕЙ
------------------------------------------------------------------

-- Combat
createToggle(combatScroll, "Enable Hard Aim", Options.Aimbot.Enabled, function(state)
    Options.Aimbot.Enabled = state
    FOVCircle.Visible = state
end)
createToggle(combatScroll, "Team Check", Options.Aimbot.TeamCheck, function(state) Options.Aimbot.TeamCheck = state end)
createToggle(combatScroll, "Wall Check", Options.Aimbot.WallCheck, function(state) Options.Aimbot.WallCheck = state end)

-- Выбор части тела – через кнопку
local partBtn = createExecuteButton(combatScroll, "Target: Torso")
partBtn.MouseButton1Click:Connect(function()
    local parts = {"Torso", "Head", "LeftFoot"}
    local current = Options.Aimbot.TargetPart
    local idx = table.find(parts, current) or 1
    idx = idx % 3 + 1
    Options.Aimbot.TargetPart = parts[idx]
    partBtn.Text = "Target: " .. parts[idx]
end)

createSlider(combatScroll, "FOV Radius", Options.Aimbot.Radius, function(v)
    Options.Aimbot.Radius = v
    FOVCircle.Radius = v
end)

local shootBtn = createExecuteButton(combatScroll, "Shoot Murderer")
shootBtn.MouseButton1Click:Connect(shootMurderer)

-- Visuals
createToggle(visualsScroll, "Boxes", Options.Visuals.Boxes, function(state) Options.Visuals.Boxes = state end)
createToggle(visualsScroll, "Skeletons", Options.Visuals.Skeletons, function(state) Options.Visuals.Skeletons = state end)
createToggle(visualsScroll, "Chams", Options.Visuals.Chams, function(state) Options.Visuals.Chams = state end)
createToggle(visualsScroll, "Names", Options.Visuals.Names, function(state) Options.Visuals.Names = state end)
createToggle(visualsScroll, "HealthBar", Options.Visuals.HealthBar, function(state) Options.Visuals.HealthBar = state end)
createToggle(visualsScroll, "Tracers", Options.Visuals.Tracers, function(state) Options.Visuals.Tracers = state end)
createToggle(visualsScroll, "Team Check", Options.Visuals.TeamCheck, function(state) Options.Visuals.TeamCheck = state end)

-- MM2
createToggle(mm2Scroll, "Role ESP", Options.MM2.RoleESP.Enabled, function(state)
    Options.MM2.RoleESP.Enabled = state
end)
createToggle(mm2Scroll, "  Role Boxes", Options.MM2.RoleESP.Boxes, function(state) Options.MM2.RoleESP.Boxes = state end)
createToggle(mm2Scroll, "  Role Skeletons", Options.MM2.RoleESP.Skeletons, function(state) Options.MM2.RoleESP.Skeletons = state end)
createToggle(mm2Scroll, "  Role Names", Options.MM2.RoleESP.Names, function(state) Options.MM2.RoleESP.Names = state end)
createToggle(mm2Scroll, "  Role Chams", Options.MM2.RoleESP.Chams, function(state) Options.MM2.RoleESP.Chams = state end)
createToggle(mm2Scroll, "  Role Outline", Options.MM2.RoleESP.Outline, function(state) Options.MM2.RoleESP.Outline = state end)
createToggle(mm2Scroll, "Dropped Gun ESP", Options.MM2.GunESP, function(state) Options.MM2.GunESP = state end)
createToggle(mm2Scroll, "Aim Murderer Only", Options.MM2.AimMurderOnly, function(state) Options.MM2.AimMurderOnly = state end)
createToggle(mm2Scroll, "Auto-Aim Murder", Options.MM2.AutoAimMurder, function(state) Options.MM2.AutoAimMurder = state end)
createToggle(mm2Scroll, "Invisibility", Options.MM2.Invisibility, function(state) toggleInvisibilityLogic(state) end)
createToggle(mm2Scroll, "Touch Fling", Options.MM2.Fling, function(state) Options.MM2.Fling = state end)
createToggle(mm2Scroll, "Auto TP Gun", Options.MM2.AutoTPGun, function(state) Options.MM2.AutoTPGun = state end)
local flingMurderBtn = createExecuteButton(mm2Scroll, "Fling Murderer")
flingMurderBtn.MouseButton1Click:Connect(FlingMurderer)
local flingSheriffBtn = createExecuteButton(mm2Scroll, "Fling Sheriff")
flingSheriffBtn.MouseButton1Click:Connect(FlingSheriff)
local killAllBtn = createExecuteButton(mm2Scroll, "Kill All")
killAllBtn.MouseButton1Click:Connect(KillAll)
local killSheriffBtn = createExecuteButton(mm2Scroll, "Kill Sheriff")
killSheriffBtn.MouseButton1Click:Connect(KillSheriff)
createToggle(mm2Scroll, "Jerk Off", Options.MM2.JerkOffEnabled, function(state) Options.MM2.JerkOffEnabled = state end)

-- Misc
createToggle(miscScroll, "Spin Bot", Options.Misc.SpinBot, function(state) Options.Misc.SpinBot = state end)
createToggle(miscScroll, "Custom WalkSpeed", Options.Misc.WalkSpeedEnabled, function(state) Options.Misc.WalkSpeedEnabled = state end)
createSlider(miscScroll, "WalkSpeed Value", Options.Misc.WalkSpeedValue, function(v) Options.Misc.WalkSpeedValue = v end)
createToggle(miscScroll, "Anti-Fling", Options.Misc.AntiFling, function(state) Options.Misc.AntiFling = state end)
createToggle(miscScroll, "Double Jump", Options.Misc.DoubleJump, function(state) Options.Misc.DoubleJump = state end)
createToggle(miscScroll, "Change Fov", Options.Misc.FovEnabled, function(state) Options.Misc.FovEnabled = state end)
createSlider(miscScroll, "Fov Value", Options.Misc.FovValue, function(v) Options.Misc.FovValue = v end)
createToggle(miscScroll, "Speed Glitch", Options.Misc.SpeedGlitchEnabled, function(state) Options.Misc.SpeedGlitchEnabled = state end)
createSlider(miscScroll, "Speed Glitch Value", Options.Misc.SpeedGlitchValue, function(v) Options.Misc.SpeedGlitchValue = v end)
createToggle(miscScroll, "Stretch", Options.Misc.StretchEnabled, function(state)
    Options.Misc.StretchEnabled = state
    updateStretch()
end)
local unloadBtn = createExecuteButton(miscScroll, "Unload")
unloadBtn.MouseButton1Click:Connect(function()
    for _, connection in ipairs(Connections) do
        if connection then connection:Disconnect() end
    end
    if stretchConnection then stretchConnection:Disconnect() end
    FOVCircle:Remove()
    screenGui:Destroy()
    BindGui:Destroy()
    getgenv().AdvancedCoreLoaded = nil
    showVillonNotice("VillonHub выгружен")
end)

-- Change Fling – список игроков с галочками и кнопки FLING/STOP
local flingContainer = Instance.new("ScrollingFrame")
flingContainer.Size = UDim2.new(1, 0, 0.8, 0)
flingContainer.Position = UDim2.new(0, 0, 0, 0)
flingContainer.BackgroundTransparency = 1
flingContainer.CanvasSize = UDim2.new(0, 0, 0, 0)
flingContainer.ScrollBarThickness = 3
flingContainer.Parent = changeFlingScroll

local flingListLayout = Instance.new("UIListLayout")
flingListLayout.SortOrder = Enum.SortOrder.LayoutOrder
flingListLayout.Padding = UDim.new(0, 4)
flingListLayout.Parent = flingContainer

local selectedPlayers = {}
local checkBoxes = {}

local function updateFlingPlayerList()
    for _, child in ipairs(flingContainer:GetChildren()) do
        if child:IsA("TextButton") then child:Destroy() end
    end
    checkBoxes = {}
    selectedPlayers = {}
    local players = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then table.insert(players, p) end
    end
    table.sort(players, function(a,b) return a.Name < b.Name end)
    for _, p in ipairs(players) do
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, 0, 0, 30)
        btn.BackgroundColor3 = Color3.fromRGB(40, 40, 48)
        btn.Text = p.Name
        btn.Font = Enum.Font.Gotham
        btn.TextSize = 12
        btn.TextColor3 = Color3.fromRGB(200, 200, 200)
        btn.TextXAlignment = Enum.TextXAlignment.Left
        btn.AutoButtonColor = false
        btn.Parent = flingContainer
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 4)
        corner.Parent = btn

        local check = Instance.new("TextLabel")
        check.Size = UDim2.new(0, 30, 1, 0)
        check.Position = UDim2.new(1, -35, 0, 0)
        check.BackgroundTransparency = 1
        check.Text = "☐"
        check.TextColor3 = Color3.fromRGB(255,255,255)
        check.TextSize = 16
        check.Font = Enum.Font.Gotham
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
    flingContainer.CanvasSize = UDim2.new(0, 0, 0, #players * 34 + 10)
end
updateFlingPlayerList()
Players.PlayerAdded:Connect(updateFlingPlayerList)
Players.PlayerRemoving:Connect(updateFlingPlayerList)

local flingBtn = createExecuteButton(changeFlingScroll, "FLING")
flingBtn.MouseButton1Click:Connect(function()
    if #selectedPlayers == 0 then
        showVillonNotice("Выберите игроков")
        return
    end
    for _, p in ipairs(selectedPlayers) do
        if p.Character then
            SHubFling(p)
            task.wait(0.5)
        end
    end
    showVillonNotice("Флинг выполнен")
end)

local stopBtn = createExecuteButton(changeFlingScroll, "STOP")
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
    showVillonNotice("Остановлено")
end)

-- Configs
local nameBox = Instance.new("TextBox")
nameBox.Size = UDim2.new(0.6, 0, 0, 20)
nameBox.Position = UDim2.new(0.2, 0, 0, 0)
nameBox.BackgroundColor3 = Color3.fromRGB(38, 38, 45)
nameBox.Text = "config1"
nameBox.Font = Enum.Font.Gotham
nameBox.TextSize = 12
nameBox.TextColor3 = Color3.fromRGB(220,220,230)
nameBox.Parent = configsScroll
local nameCorner = Instance.new("UICorner")
nameCorner.CornerRadius = UDim.new(0, 4)
nameCorner.Parent = nameBox

local saveBtn = createExecuteButton(configsScroll, "Save Config")
saveBtn.MouseButton1Click:Connect(function()
    saveConfig(nameBox.Text)
end)
local loadBtn = createExecuteButton(configsScroll, "Load Config")
loadBtn.MouseButton1Click:Connect(function()
    loadConfig(nameBox.Text)
end)

-- VisualWorld
createToggle(visualWorldScroll, "Trail", Options.VisualsWorld.TrailEnabled, function(state) toggleTrail(state) end)
createToggle(visualWorldScroll, "Fog", Options.VisualsWorld.FogEnabled, function(state) toggleFog(state) end)
createToggle(visualWorldScroll, "Jump Circle", Options.VisualsWorld.JumpCircleEnabled, function(state) toggleJumpCircle(state) end)
createToggle(visualWorldScroll, "China Hat", Options.VisualsWorld.ChinaHatEnabled, function(state) toggleChinaHat(state) end)
createSlider(visualWorldScroll, "China Hat Size", Options.VisualsWorld.ChinaHatSize, function(v) Options.VisualsWorld.ChinaHatSize = v updateAllWorldEffects() end)
createSlider(visualWorldScroll, "Trail Lifetime", Options.VisualsWorld.TrailLifetime, function(v) Options.VisualsWorld.TrailLifetime = v updateAllWorldEffects() end)
createSlider(visualWorldScroll, "Fog Distance", Options.VisualsWorld.FogDistance, function(v) Options.VisualsWorld.FogDistance = v updateAllWorldEffects() end)

-- Кнопка выбора цвета (упрощённо через системный ColorPicker)
local colorBtn = createExecuteButton(visualWorldScroll, "Color Palette")
colorBtn.MouseButton1Click:Connect(function()
    local colorPicker = game:GetService("GuiService"):GetColorPicker()
    if colorPicker then
        colorPicker:Open(function(selectedColor)
            Options.VisualsWorld.Color = selectedColor
            updateAllWorldEffects()
        end)
    else
        showVillonNotice("ColorPicker не поддерживается")
    end
end)

------------------------------------------------------------------
-- ОТКРЫТИЕ / ЗАКРЫТИЕ МЕНЮ
------------------------------------------------------------------
function openMenu()
    if menuOpen then return end
    menuOpen = true

    main.Visible = true
    main.Size = UDim2.new(0, 0, 0, 0)
    main.Position = UDim2.new(0.5, 0, 0.5, 0)
    main.BackgroundTransparency = 1

    TweenService:Create(main, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Size = UDim2.new(0, 420, 0, 280),
        Position = UDim2.new(0.5, -210, 0.5, -140),
        BackgroundTransparency = 0
    }):Play()
end

function closeMenu()
    if not menuOpen then return end
    menuOpen = false

    TweenService:Create(main, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
        Size = UDim2.new(0, 0, 0, 0),
        Position = UDim2.new(0.5, 0, 0.5, 0),
        BackgroundTransparency = 1
    }):Play()

    task.delay(0.25, function()
        main.Visible = false
    end)
end

------------------------------------------------------------------
-- ЗАПУСК ПОСЛЕ НАЖАТИЯ START
------------------------------------------------------------------
startBtn.MouseButton1Click:Connect(function()
    TweenService:Create(startBtn, TweenInfo.new(0.1), {
        BackgroundColor3 = Color3.fromRGB(70, 70, 85),
        Size = UDim2.new(0, 132, 0, 38)
    }):Play()

    task.wait(0.15)

    snowConnection:Disconnect()
    TweenService:Create(intro, TweenInfo.new(0.7), {BackgroundTransparency = 1}):Play()
    TweenService:Create(title, TweenInfo.new(0.5), {TextTransparency = 1}):Play()
    TweenService:Create(startBtn, TweenInfo.new(0.5), {TextTransparency = 1, BackgroundTransparency = 1}):Play()
    TweenService:Create(startStroke, TweenInfo.new(0.5), {Transparency = 1}):Play()

    for _, flake in pairs(snowFolder:GetChildren()) do
        TweenService:Create(flake, TweenInfo.new(0.4), {BackgroundTransparency = 1}):Play()
    end

    task.wait(0.75)
    intro:Destroy()

    bubble.Visible = true
    bubble.BackgroundTransparency = 1
    bubble.Size = UDim2.new(0, 0, 0, 0)

    TweenService:Create(bubble, TweenInfo.new(0.4, Enum.EasingStyle.Back), {
        Size = UDim2.new(0, 140, 0, 36),
        BackgroundTransparency = 0.25
    }):Play()
end)

print("[VillonHub] Полная интеграция завершена")