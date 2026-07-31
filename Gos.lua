--[[
    VILLONHUB TERMINAL ENGINE – Custom New UI Edition (финальная)
    Полная версия с новым UI (анимации, две колонки), все функции сохранены.
    VisualWorld полностью удалена. Aspect Ratio в Misc.
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
local TweenService = game:GetService("TweenService")
local ContextActionService = game:GetService("ContextActionService")
local Lighting = game:GetService("Lighting")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera
local Mouse = LocalPlayer:GetMouse()

-- ===== НАСТРОЙКИ ПРЕДИКШЕНА (для шот мардера) =====
local CONFIG_SM = {
    BulletSpeed = 280,
    PredictionFactor = 0.85,
    MaxHorizontalPrediction = 300,
    MaxVerticalPrediction = 50,
    PingCompensation = true,
    UseVerticalCorrection = true
}

--// Глобальная конфигурация (без VisualWorld, с AspectRatio)
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
        SpeedGlitchEnabled = false,
        SpeedGlitchValue = 20,
        StretchEnabled = false,
        AspectRatioEnabled = false,
        AspectRatioValue = 0.80
    }
}

--// Хранилище позиций кнопок (для конфигов)
local ButtonPositions = {}

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

--// ScreenGui для биндов (кнопок)
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
--   ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ (из frek.lua)
-- ============================================================

local function showVillonNotice(txt)
    StarterGui:SetCore("SendNotification", {
        Title = "VillonHub",
        Text = txt,
        Duration = 3
    })
end

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

-- ============================================================
--   ШОТ МАРДЕР (из frek.lua)
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
--   ОСТАЛЬНЫЕ ИГРОВЫЕ ФУНКЦИИ (из frek.lua)
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

-- ===== ФЛИНГ =====
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
    if not targetHum or targetHum.Health <= 0 then return true end
    local myRoot = char:FindFirstChild("HumanoidRootPart")
    if not myRoot then return false end
    local startPosition = myRoot.CFrame
    local attempts = 0
    while targetHum and targetHum.Health > 0 and attempts < 10 do
        attempts = attempts + 1
        myRoot.CFrame = targetRoot.CFrame * CFrame.new(0, 1, 1.5)
        task.wait(0.05)
        for i = 1, 3 do
            knife:Activate()
            task.wait(0.08)
            targetHum = targetChar:FindFirstChildOfClass("Humanoid")
            if not targetHum or targetHum.Health <= 0 then break end
        end
        if targetHum and targetHum.Health > 0 then
            throwKnifeAtTarget(targetPlayer)
            task.wait(0.1)
            targetHum = targetChar:FindFirstChildOfClass("Humanoid")
        end
        if targetHum and targetHum.Health > 0 then task.wait(0.1) end
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
        task.wait(0.05)
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

--// ESP System
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

--// Рендер-лупы (физика и мастер-рендер)
local lastVisualUpdate = 0

--// Aspect Ratio Connection
local aspectConnection = nil
local function updateAspectRatio()
    if aspectConnection then
        aspectConnection:Disconnect()
        aspectConnection = nil
    end
    if Options.Misc.AspectRatioEnabled then
        local res = Options.Misc.AspectRatioValue
        aspectConnection = RunService.RenderStepped:Connect(function()
            Camera.CFrame = Camera.CFrame * CFrame.new(0, 0, 0, 1, 0, 0, 0, res, 0, 0, 0, 1)
        end)
    end
end
updateAspectRatio()

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

    -- // === БИНДЫ (КНОПКИ) ===
    if Options.Aimbot.BindButtonEnabled then
        if not BindGui:FindFirstChild("Aim_BindButton") then
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
            AimBindButton.Parent = BindGui
            local ABCorner = Instance.new("UICorner")
            ABCorner.CornerRadius = UDim.new(0, 6)
            ABCorner.Parent = AimBindButton
            AimBindButton.MouseButton1Click:Connect(function()
                if IsAimBindEditModeActive then return end
                Options.Aimbot.Enabled = not Options.Aimbot.Enabled
                FOVCircle.Visible = Options.Aimbot.Enabled
                AimBindButton.BackgroundColor3 = Options.Aimbot.Enabled and Color3.fromRGB(0, 180, 255) or Color3.fromRGB(40, 40, 45)
            end)
            ButtonPositions.Aim = {X = 0.1, Y = 0.45}
        else
            local btn = BindGui.Aim_BindButton
            btn.Visible = true
            btn.Draggable = IsAimBindEditModeActive
            btn.BackgroundColor3 = Options.Aimbot.Enabled and Color3.fromRGB(0, 180, 255) or Color3.fromRGB(40, 40, 45)
            local pos = btn.Position
            ButtonPositions.Aim = {X = pos.X.Scale, Y = pos.Y.Scale}
        end
    else
        if BindGui:FindFirstChild("Aim_BindButton") then
            BindGui.Aim_BindButton.Visible = false
        end
    end

    -- Кнопка TP GUN
    if Options.MM2.TPGunButtonEnabled then
        if not BindGui:FindFirstChild("MM2_TPGunButton") then
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
            TPGunButton.Parent = BindGui
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
            ButtonPositions.TPGun = {X = 0.1, Y = 0.55}
        else
            BindGui.MM2_TPGunButton.Visible = true
            BindGui.MM2_TPGunButton.Draggable = IsTPGunEditModeActive
            local pos = BindGui.MM2_TPGunButton.Position
            ButtonPositions.TPGun = {X = pos.X.Scale, Y = pos.Y.Scale}
        end
    else
        if BindGui:FindFirstChild("MM2_TPGunButton") then
            BindGui.MM2_TPGunButton.Visible = false
        end
    end

    -- Кнопка INVIS
    if Options.MM2.InvisButtonEnabled then
        if not BindGui:FindFirstChild("MM2_InvisButton") then
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
            InvisButton.Parent = BindGui
            local InvCorner = Instance.new("UICorner")
            InvCorner.CornerRadius = UDim.new(0, 6)
            InvCorner.Parent = InvisButton
            InvisButton.MouseButton1Click:Connect(function()
                if IsInvisEditModeActive then return end
                toggleInvisibilityLogic(not Options.MM2.Invisibility)
                InvisButton.BackgroundColor3 = Options.MM2.Invisibility and Color3.fromRGB(120, 0, 200) or Color3.fromRGB(40, 40, 45)
            end)
            ButtonPositions.Invis = {X = 0.1, Y = 0.65}
        else
            BindGui.MM2_InvisButton.Visible = true
            BindGui.MM2_InvisButton.Draggable = IsInvisEditModeActive
            BindGui.MM2_InvisButton.BackgroundColor3 = Options.MM2.Invisibility and Color3.fromRGB(120, 0, 200) or Color3.fromRGB(40, 40, 45)
            local pos = BindGui.MM2_InvisButton.Position
            ButtonPositions.Invis = {X = pos.X.Scale, Y = pos.Y.Scale}
        end
    else
        if BindGui:FindFirstChild("MM2_InvisButton") then
            BindGui.MM2_InvisButton.Visible = false
        end
    end

    -- Кнопка FLING
    if Options.MM2.FlingButtonEnabled then
        if not BindGui:FindFirstChild("MM2_FlingButton") then
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
            FlingButton.Parent = BindGui
            local FlCorner = Instance.new("UICorner")
            FlCorner.CornerRadius = UDim.new(0, 6)
            FlCorner.Parent = FlingButton
            FlingButton.MouseButton1Click:Connect(function()
                if IsFlingEditModeActive then return end
                Options.MM2.Fling = not Options.MM2.Fling
                FlingButton.BackgroundColor3 = Options.MM2.Fling and Color3.fromRGB(230, 100, 0) or Color3.fromRGB(40, 40, 45)
                showVillonNotice(Options.MM2.Fling and "Fling Mode ENABLED" or "Fling Mode DISABLED")
            end)
            ButtonPositions.Fling = {X = 0.1, Y = 0.75}
        else
            BindGui.MM2_FlingButton.Visible = true
            BindGui.MM2_FlingButton.Draggable = IsFlingEditModeActive
            BindGui.MM2_FlingButton.BackgroundColor3 = Options.MM2.Fling and Color3.fromRGB(230, 100, 0) or Color3.fromRGB(40, 40, 45)
            local pos = BindGui.MM2_FlingButton.Position
            ButtonPositions.Fling = {X = pos.X.Scale, Y = pos.Y.Scale}
        end
    else
        if BindGui:FindFirstChild("MM2_FlingButton") then
            BindGui.MM2_FlingButton.Visible = false
        end
    end

    -- SHOOT MURDER
    if Options.MM2.ShootMurderButtonEnabled then
        if not BindGui:FindFirstChild("MM2_ShootMurderButton") then
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
            ShootMurderButton.Parent = BindGui
            local SMBCorner = Instance.new("UICorner")
            SMBCorner.CornerRadius = UDim.new(0, 10)
            SMBCorner.Parent = ShootMurderButton
            local SMBStroke = Instance.new("UIStroke")
            SMBStroke.Color = Color3.fromRGB(200, 200, 200)
            SMBStroke.Thickness = 1.5
            SMBStroke.Parent = ShootMurderButton
            ShootMurderButton.MouseButton1Click:Connect(function()
                if IsShootMurderEditModeActive then return end
                shootMurderer()
            end)
            ButtonPositions.ShootMurder = {X = 0.5, Y = 0.8, OffsetX = -75, OffsetY = -27.5}
        else
            BindGui.MM2_ShootMurderButton.Visible = true
            BindGui.MM2_ShootMurderButton.Draggable = IsShootMurderEditModeActive
            local pos = BindGui.MM2_ShootMurderButton.Position
            ButtonPositions.ShootMurder = {X = pos.X.Scale, Y = pos.Y.Scale, OffsetX = pos.X.Offset, OffsetY = pos.Y.Offset}
        end
    else
        if BindGui:FindFirstChild("MM2_ShootMurderButton") then
            BindGui.MM2_ShootMurderButton.Visible = false
        end
    end

    -- THROW KNIFE
    if Options.MM2.ThrowKnifeButtonEnabled then
        if not BindGui:FindFirstChild("MM2_ThrowKnifeButton") then
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
            ThrowKnifeButton.Parent = BindGui
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
            ButtonPositions.ThrowKnife = {X = 0.5, Y = 0.8, OffsetX = -230, OffsetY = -27.5}
        else
            BindGui.MM2_ThrowKnifeButton.Visible = true
            BindGui.MM2_ThrowKnifeButton.Draggable = IsThrowKnifeEditModeActive
            local pos = BindGui.MM2_ThrowKnifeButton.Position
            ButtonPositions.ThrowKnife = {X = pos.X.Scale, Y = pos.Y.Scale, OffsetX = pos.X.Offset, OffsetY = pos.Y.Offset}
        end
    else
        if BindGui:FindFirstChild("MM2_ThrowKnifeButton") then
            BindGui.MM2_ThrowKnifeButton.Visible = false
        end
    end

    -- KILL ALL
    if Options.MM2.KillAllButtonEnabled then
        if not BindGui:FindFirstChild("KillAllButton") then
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
            KillAllBtn.Parent = BindGui
            local corner = Instance.new("UICorner")
            corner.CornerRadius = UDim.new(0, 6)
            corner.Parent = KillAllBtn
            KillAllBtn.MouseButton1Click:Connect(function()
                if IsKillAllEditModeActive then return end
                KillAll()
            end)
            ButtonPositions.KillAll = {X = 0.02, Y = 0.35}
        else
            BindGui.KillAllButton.Visible = true
            BindGui.KillAllButton.Draggable = IsKillAllEditModeActive
            local pos = BindGui.KillAllButton.Position
            ButtonPositions.KillAll = {X = pos.X.Scale, Y = pos.Y.Scale}
        end
    else
        if BindGui:FindFirstChild("KillAllButton") then
            BindGui.KillAllButton.Visible = false
        end
    end

    -- KILL SHERIFF
    if Options.MM2.KillSheriffButtonEnabled then
        if not BindGui:FindFirstChild("KillSheriffButton") then
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
            KillSheriffBtn.Parent = BindGui
            local corner = Instance.new("UICorner")
            corner.CornerRadius = UDim.new(0, 6)
            corner.Parent = KillSheriffBtn
            KillSheriffBtn.MouseButton1Click:Connect(function()
                if IsKillSheriffEditModeActive then return end
                KillSheriff()
            end)
            ButtonPositions.KillSheriff = {X = 0.02, Y = 0.43}
        else
            BindGui.KillSheriffButton.Visible = true
            BindGui.KillSheriffButton.Draggable = IsKillSheriffEditModeActive
            local pos = BindGui.KillSheriffButton.Position
            ButtonPositions.KillSheriff = {X = pos.X.Scale, Y = pos.Y.Scale}
        end
    else
        if BindGui:FindFirstChild("KillSheriffButton") then
            BindGui.KillSheriffButton.Visible = false
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
                task.spawn(function()
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

-- ============================================================
--   НОВЫЙ ПОЛЬЗОВАТЕЛЬСКИЙ ИНТЕРФЕЙС (исправленный)
-- ============================================================
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
-- 1. INTRO
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
    Instance.new("UICorner", flake).CornerRadius = UDim.new(1, 0)

    local duration = math.random(4, 8)
    local endPos = UDim2.new(flake.Position.X.Scale + math.random(-10, 10) / 100, 0, 1.1, 0)
    TweenService:Create(flake, TweenInfo.new(duration, Enum.EasingStyle.Linear), {
        Position = endPos,
        BackgroundTransparency = 1
    }):Play()
    task.delay(duration, function()
        if flake and flake.Parent then flake:Destroy() end
    end)
end

local snowConnection = RunService.Heartbeat:Connect(function()
    if math.random() < 0.35 then createSnowflake() end
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
startBtn.BackgroundColor3 = Color3.fromRGB(35, 35, 42)
startBtn.Text = "Start"
startBtn.Font = Enum.Font.GothamMedium
startBtn.TextSize = 18
startBtn.TextColor3 = Color3.fromRGB(230, 230, 235)
startBtn.TextTransparency = 1
startBtn.BackgroundTransparency = 1
startBtn.AutoButtonColor = false
startBtn.ZIndex = 52
startBtn.Parent = intro
Instance.new("UICorner", startBtn).CornerRadius = UDim.new(0, 10)

local startStroke = Instance.new("UIStroke")
startStroke.Color = Color3.fromRGB(100, 100, 110)
startStroke.Thickness = 1
startStroke.Transparency = 1
startStroke.Parent = startBtn

TweenService:Create(title, TweenInfo.new(1.2, Enum.EasingStyle.Quad), {TextTransparency = 0}):Play()
task.wait(0.4)
TweenService:Create(startBtn, TweenInfo.new(0.8), {TextTransparency = 0, BackgroundTransparency = 0.2}):Play()
TweenService:Create(startStroke, TweenInfo.new(0.8), {Transparency = 0.5}):Play()

startBtn.MouseEnter:Connect(function()
    TweenService:Create(startBtn, TweenInfo.new(0.15), {
        BackgroundColor3 = Color3.fromRGB(50, 50, 60),
        Size = UDim2.new(0, 148, 0, 44)
    }):Play()
end)
startBtn.MouseLeave:Connect(function()
    TweenService:Create(startBtn, TweenInfo.new(0.15), {
        BackgroundColor3 = Color3.fromRGB(35, 35, 42),
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
-- 2. ПУЗЫРЬ
------------------------------------------------------------------
local bubble = Instance.new("Frame")
bubble.Name = "OpenBubble"
bubble.Size = UDim2.new(0, 140, 0, 36)
bubble.Position = UDim2.new(0.5, -70, 0.08, 0)
bubble.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
bubble.BackgroundTransparency = 0.3
bubble.BorderSizePixel = 0
bubble.Visible = false
bubble.ZIndex = 40
bubble.Parent = screenGui
Instance.new("UICorner", bubble).CornerRadius = UDim.new(1, 0)

local bubbleStroke = Instance.new("UIStroke")
bubbleStroke.Color = Color3.fromRGB(140, 140, 150)
bubbleStroke.Thickness = 1
bubbleStroke.Transparency = 0.65
bubbleStroke.Parent = bubble

local dragZone = Instance.new("Frame")
dragZone.Name = "DragZone"
dragZone.Size = UDim2.new(0, 28, 1, 0)
dragZone.BackgroundTransparency = 1
dragZone.Parent = bubble

local leftArrow = Instance.new("TextLabel")
leftArrow.Size = UDim2.new(1, 0, 1, 0)
leftArrow.BackgroundTransparency = 1
leftArrow.Text = "‹"
leftArrow.Font = Enum.Font.GothamBold
leftArrow.TextSize = 18
leftArrow.TextColor3 = Color3.fromRGB(150, 150, 160)
leftArrow.Parent = dragZone

local rightArrow = Instance.new("TextLabel")
rightArrow.Size = UDim2.new(0, 14, 1, 0)
rightArrow.Position = UDim2.new(1, -18, 0, 0)
rightArrow.BackgroundTransparency = 1
rightArrow.Text = "›"
rightArrow.Font = Enum.Font.GothamBold
rightArrow.TextSize = 16
rightArrow.TextColor3 = Color3.fromRGB(150, 150, 160)
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

bubble.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        local relativeX = input.Position.X - bubble.AbsolutePosition.X
        if relativeX > 28 then
            bubbleMoved = false
            task.delay(0.05, function()
                if not bubbleMoved and not bubbleDragging then
                    if menuOpen then closeMenu() else openMenu() end
                end
            end)
        end
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if bubbleDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - bubbleDragStart
        if delta.Magnitude > dragThreshold then bubbleMoved = true end
        bubble.Position = UDim2.new(
            bubbleStartPos.X.Scale, bubbleStartPos.X.Offset + delta.X,
            bubbleStartPos.Y.Scale, bubbleStartPos.Y.Offset + delta.Y
        )
    end
end)

------------------------------------------------------------------
-- 3. ОСНОВНОЕ МЕНЮ (с двумя колонками и переключаемыми вкладками)
------------------------------------------------------------------
local main = Instance.new("Frame")
main.Name = "Main"
main.Size = UDim2.new(0, 480, 0, 300)
main.Position = UDim2.new(0.5, -240, 0.5, -150)
main.BackgroundColor3 = Color3.fromRGB(12, 12, 14)
main.BorderSizePixel = 0
main.Visible = false
main.ClipsDescendants = true
main.ZIndex = 30
main.Parent = screenGui
Instance.new("UICorner", main).CornerRadius = UDim.new(0, 12)

local mainStroke = Instance.new("UIStroke")
mainStroke.Color = Color3.fromRGB(35, 35, 42)
mainStroke.Thickness = 1
mainStroke.Parent = main

local header = Instance.new("Frame")
header.Size = UDim2.new(1, 0, 0, 38)
header.BackgroundColor3 = Color3.fromRGB(16, 16, 19)
header.BorderSizePixel = 0
header.Parent = main
Instance.new("UICorner", header).CornerRadius = UDim.new(0, 12)

local logo = Instance.new("TextLabel")
logo.Size = UDim2.new(0, 150, 1, 0)
logo.Position = UDim2.new(0, 14, 0, 0)
logo.BackgroundTransparency = 1
logo.Text = "VILLONHUB"
logo.Font = Enum.Font.GothamBold
logo.TextSize = 16
logo.TextColor3 = Color3.fromRGB(235, 235, 240)
logo.TextXAlignment = Enum.TextXAlignment.Left
logo.Parent = header

-- Аватар (голова игрока)
local nickFrame = Instance.new("Frame")
nickFrame.Size = UDim2.new(0, 110, 0, 26)
nickFrame.Position = UDim2.new(1, -122, 0.5, -13)
nickFrame.BackgroundColor3 = Color3.fromRGB(28, 28, 34)
nickFrame.BorderSizePixel = 0
nickFrame.Parent = header
Instance.new("UICorner", nickFrame).CornerRadius = UDim.new(0, 7)

local avatarImage = Instance.new("ImageLabel")
avatarImage.Size = UDim2.new(0, 18, 0, 18)
avatarImage.Position = UDim2.new(0, 5, 0.5, -9)
avatarImage.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
avatarImage.BackgroundTransparency = 1
avatarImage.Image = "rbxthumb://type=AvatarHead&id=" .. LocalPlayer.UserId
avatarImage.Parent = nickFrame
Instance.new("UICorner", avatarImage).CornerRadius = UDim.new(1, 0)

local nickLabel = Instance.new("TextLabel")
nickLabel.Size = UDim2.new(1, -28, 0, 13)
nickLabel.Position = UDim2.new(0, 28, 0, 2)
nickLabel.BackgroundTransparency = 1
nickLabel.Text = LocalPlayer.Name
nickLabel.Font = Enum.Font.GothamMedium
nickLabel.TextSize = 12
nickLabel.TextColor3 = Color3.fromRGB(235, 235, 240)
nickLabel.TextXAlignment = Enum.TextXAlignment.Left
nickLabel.Parent = nickFrame

local statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.new(1, -28, 0, 11)
statusLabel.Position = UDim2.new(0, 28, 0, 14)
statusLabel.BackgroundTransparency = 1
statusLabel.Text = "Online"
statusLabel.Font = Enum.Font.Gotham
statusLabel.TextSize = 10
statusLabel.TextColor3 = Color3.fromRGB(90, 200, 120)
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
            mainStartPos.X.Scale, mainStartPos.X.Offset + delta.X,
            mainStartPos.Y.Scale, mainStartPos.Y.Offset + delta.Y
        )
    end
end)

-- Контент
local content = Instance.new("Frame")
content.Size = UDim2.new(1, -16, 1, -82)
content.Position = UDim2.new(0, 8, 0, 44)
content.BackgroundTransparency = 1
content.ClipsDescendants = true
content.Parent = main

-- Левая колонка – содержит панели для каждой вкладки
local leftColumn = Instance.new("Frame")
leftColumn.Name = "LeftColumn"
leftColumn.Size = UDim2.new(0.485, 0, 1, 0)
leftColumn.Position = UDim2.new(0, 0, 0, 0)
leftColumn.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
leftColumn.BorderSizePixel = 0
leftColumn.Parent = content
Instance.new("UICorner", leftColumn).CornerRadius = UDim.new(0, 10)

local leftStroke = Instance.new("UIStroke")
leftStroke.Color = Color3.fromRGB(32, 32, 40)
leftStroke.Thickness = 1
leftStroke.Parent = leftColumn

-- Правая колонка – содержит панели для каждой вкладки
local rightColumn = Instance.new("Frame")
rightColumn.Name = "RightColumn"
rightColumn.Size = UDim2.new(0.485, 0, 1, 0)
rightColumn.Position = UDim2.new(0.515, 0, 0, 0)
rightColumn.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
rightColumn.BorderSizePixel = 0
rightColumn.Parent = content
Instance.new("UICorner", rightColumn).CornerRadius = UDim.new(0, 10)

local rightStroke = Instance.new("UIStroke")
rightStroke.Color = Color3.fromRGB(32, 32, 40)
rightStroke.Thickness = 1
rightStroke.Parent = rightColumn

-- Функция создания панели внутри колонки
local function createTabPanel(column)
    local panel = Instance.new("Frame")
    panel.Size = UDim2.new(1, 0, 1, 0)
    panel.BackgroundTransparency = 1
    panel.Visible = false
    panel.Parent = column

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -16, 0, 24)
    title.Position = UDim2.new(0, 12, 0, 6)
    title.BackgroundTransparency = 1
    title.Text = ""
    title.Font = Enum.Font.GothamBold
    title.TextSize = 14
    title.TextColor3 = Color3.fromRGB(235, 235, 240)
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = panel

    local scroll = Instance.new("ScrollingFrame")
    scroll.Size = UDim2.new(1, -12, 1, -36)
    scroll.Position = UDim2.new(0, 6, 0, 32)
    scroll.BackgroundTransparency = 1
    scroll.BorderSizePixel = 0
    scroll.ScrollBarThickness = 3
    scroll.ScrollBarImageColor3 = Color3.fromRGB(70, 70, 80)
    scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    scroll.Parent = panel

    local layout = Instance.new("UIListLayout")
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, 8)
    layout.Parent = scroll

    local padding = Instance.new("UIPadding")
    padding.PaddingTop = UDim.new(0, 4)
    padding.PaddingBottom = UDim.new(0, 10)
    padding.PaddingLeft = UDim.new(0, 6)
    padding.PaddingRight = UDim.new(0, 6)
    padding.Parent = scroll

    return panel, scroll, title
end

-- Создаём панели для каждой вкладки (левая и правая)
local leftPanels = {}
local rightPanels = {}
local leftScrolls = {}
local rightScrolls = {}
local leftTitles = {}
local rightTitles = {}

local tabNames = {"Combat", "Visuals", "MM2", "Misc"}

for _, name in ipairs(tabNames) do
    local lp, ls, lt = createTabPanel(leftColumn)
    local rp, rs, rt = createTabPanel(rightColumn)
    leftPanels[name] = lp
    rightPanels[name] = rp
    leftScrolls[name] = ls
    rightScrolls[name] = rs
    leftTitles[name] = lt
    rightTitles[name] = rt
end

-- Делаем видимой первую вкладку
leftPanels["Combat"].Visible = true
rightPanels["Combat"].Visible = true
leftTitles["Combat"].Text = "Combat"
rightTitles["Combat"].Text = "Actions"

------------------------------------------------------------------
-- Элементы UI (createToggle, createSlider, createExecuteButton)
------------------------------------------------------------------
local function createToggle(parent, text, default, callback)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 0, 26)
    frame.BackgroundTransparency = 1
    frame.Parent = parent

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -50, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = text
    label.Font = Enum.Font.Gotham
    label.TextSize = 13
    label.TextColor3 = Color3.fromRGB(185, 185, 195)
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = frame

    local toggle = Instance.new("TextButton")
    toggle.Size = UDim2.new(0, 38, 0, 18)
    toggle.Position = UDim2.new(1, -40, 0.5, -9)
    toggle.BackgroundColor3 = default and Color3.fromRGB(85, 85, 95) or Color3.fromRGB(35, 35, 42)
    toggle.Text = ""
    toggle.AutoButtonColor = false
    toggle.Parent = frame
    Instance.new("UICorner", toggle).CornerRadius = UDim.new(1, 0)

    local circle = Instance.new("Frame")
    circle.Size = UDim2.new(0, 14, 0, 14)
    circle.Position = default and UDim2.new(1, -16, 0.5, -7) or UDim2.new(0, 2, 0.5, -7)
    circle.BackgroundColor3 = Color3.fromRGB(230, 230, 235)
    circle.BorderSizePixel = 0
    circle.Parent = toggle
    Instance.new("UICorner", circle).CornerRadius = UDim.new(1, 0)

    local state = default
    toggle.MouseButton1Click:Connect(function()
        state = not state
        local goalColor = state and Color3.fromRGB(85, 85, 95) or Color3.fromRGB(35, 35, 42)
        local goalPos = state and UDim2.new(1, -16, 0.5, -7) or UDim2.new(0, 2, 0.5, -7)
        TweenService:Create(toggle, TweenInfo.new(0.15), {BackgroundColor3 = goalColor}):Play()
        TweenService:Create(circle, TweenInfo.new(0.15), {Position = goalPos}):Play()
        if callback then callback(state) end
    end)
end

local function createSlider(parent, text, min, max, default, callback)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 0, 44)
    frame.BackgroundTransparency = 1
    frame.Parent = parent

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0.65, 0, 0, 18)
    label.BackgroundTransparency = 1
    label.Text = text
    label.Font = Enum.Font.Gotham
    label.TextSize = 13
    label.TextColor3 = Color3.fromRGB(185, 185, 195)
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = frame

    local valueLabel = Instance.new("TextLabel")
    valueLabel.Size = UDim2.new(0.35, 0, 0, 18)
    valueLabel.Position = UDim2.new(0.65, 0, 0, 0)
    valueLabel.BackgroundTransparency = 1
    valueLabel.Text = tostring(default)
    valueLabel.Font = Enum.Font.GothamMedium
    valueLabel.TextSize = 13
    valueLabel.TextColor3 = Color3.fromRGB(220, 220, 230)
    valueLabel.TextXAlignment = Enum.TextXAlignment.Right
    valueLabel.Parent = frame

    local track = Instance.new("Frame")
    track.Size = UDim2.new(1, 0, 0, 6)
    track.Position = UDim2.new(0, 0, 0, 28)
    track.BackgroundColor3 = Color3.fromRGB(35, 35, 42)
    track.BorderSizePixel = 0
    track.Parent = frame
    Instance.new("UICorner", track).CornerRadius = UDim.new(1, 0)

    local fill = Instance.new("Frame")
    local startPct = (default - min) / (max - min)
    fill.Size = UDim2.new(math.clamp(startPct, 0, 1), 0, 1, 0)
    fill.BackgroundColor3 = Color3.fromRGB(130, 130, 145)
    fill.BorderSizePixel = 0
    fill.Parent = track
    Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)

    local thumb = Instance.new("TextButton")
    thumb.Size = UDim2.new(0, 16, 0, 16)
    thumb.Position = UDim2.new(math.clamp(startPct, 0, 1), -8, 0.5, -8)
    thumb.BackgroundColor3 = Color3.fromRGB(220, 220, 230)
    thumb.Text = ""
    thumb.AutoButtonColor = false
    thumb.Parent = track
    Instance.new("UICorner", thumb).CornerRadius = UDim.new(1, 0)

    local dragging = false
    local function update(value)
        value = math.clamp(value, min, max)
        local percent = (value - min) / (max - min)
        fill.Size = UDim2.new(percent, 0, 1, 0)
        thumb.Position = UDim2.new(percent, -8, 0.5, -8)
        valueLabel.Text = tostring(math.floor(value + 0.5))
        if callback then callback(value) end
    end

    thumb.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
        end
    end)

    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local trackAbs = track.AbsolutePosition.X
            local trackSize = track.AbsoluteSize.X
            local percent = math.clamp((input.Position.X - trackAbs) / trackSize, 0, 1)
            update(min + (max - min) * percent)
        end
    end)

    track.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            local trackAbs = track.AbsolutePosition.X
            local trackSize = track.AbsoluteSize.X
            local percent = math.clamp((input.Position.X - trackAbs) / trackSize, 0, 1)
            update(min + (max - min) * percent)
        end
    end)
end

local function createExecuteButton(parent, text, callback)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 32)
    btn.BackgroundColor3 = Color3.fromRGB(40, 40, 48)
    btn.Text = text
    btn.Font = Enum.Font.GothamMedium
    btn.TextSize = 13
    btn.TextColor3 = Color3.fromRGB(220, 220, 230)
    btn.AutoButtonColor = false
    btn.Parent = parent
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 7)

    btn.MouseEnter:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.12), {BackgroundColor3 = Color3.fromRGB(55, 55, 65)}):Play()
    end)
    btn.MouseLeave:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.12), {BackgroundColor3 = Color3.fromRGB(40, 40, 48)}):Play()
    end)
    btn.MouseButton1Click:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.08), {BackgroundColor3 = Color3.fromRGB(70, 70, 85)}):Play()
        task.wait(0.08)
        TweenService:Create(btn, TweenInfo.new(0.12), {BackgroundColor3 = Color3.fromRGB(40, 40, 48)}):Play()
        if callback then callback() end
    end)
end

------------------------------------------------------------------
-- Заполнение вкладок (каждая вкладка имеет свои элементы)
------------------------------------------------------------------

-- 1. COMBAT
local function fillCombat()
    local ls = leftScrolls["Combat"]
    local rs = rightScrolls["Combat"]
    -- Левая колонка
    createToggle(ls, "Enable Hard Aim", Options.Aimbot.Enabled, function(state)
        Options.Aimbot.Enabled = state
        FOVCircle.Visible = state
    end)
    createToggle(ls, "Show Aim Bind Button", Options.Aimbot.BindButtonEnabled)
    createExecuteButton(ls, "Edit AIM Button Position", function()
        IsAimBindEditModeActive = not IsAimBindEditModeActive
        showVillonNotice(IsAimBindEditModeActive and "Режим настройки: Перетащите кнопку AIM!" or "Положение кнопки AIM зафиксировано.")
        local btn = BindGui:FindFirstChild("Aim_BindButton")
        if btn then
            btn.Draggable = IsAimBindEditModeActive
            btn.BorderSizePixel = IsAimBindEditModeActive and 1 or 0
            btn.BorderColor3 = Color3.fromRGB(0, 150, 255)
        end
    end)
    createToggle(ls, "Team Check", Options.Aimbot.TeamCheck)
    createToggle(ls, "Wall Check", Options.Aimbot.WallCheck)
    createSlider(ls, "FOV Radius", 10, 500, Options.Aimbot.Radius, function(val)
        Options.Aimbot.Radius = val
        FOVCircle.Radius = val
    end)
    -- Правая колонка
    createExecuteButton(rs, "Shoot Murderer", shootMurderer)
end
fillCombat()

-- 2. VISUALS
local function fillVisuals()
    local ls = leftScrolls["Visuals"]
    createToggle(ls, "Boxes ESP", Options.Visuals.Boxes)
    createToggle(ls, "Skeletons ESP", Options.Visuals.Skeletons)
    createToggle(ls, "Chams Style", Options.Visuals.Chams)
    createToggle(ls, "Names Rendering", Options.Visuals.Names)
    createToggle(ls, "Health Bar", Options.Visuals.HealthBar)
    createToggle(ls, "Snaplines", Options.Visuals.Tracers)
    createToggle(ls, "Team Check Filter", Options.Visuals.TeamCheck)
end
fillVisuals()

-- 3. MM2
local function fillMM2()
    local ls = leftScrolls["MM2"]
    local rs = rightScrolls["MM2"]
    createToggle(ls, "Role ESP", Options.MM2.RoleESP)
    createToggle(ls, "Dropped Gun ESP", Options.MM2.GunESP)
    createToggle(ls, "Show TP Gun Button", Options.MM2.TPGunButtonEnabled)
    createExecuteButton(ls, "Edit TP GUN Position", function()
        IsTPGunEditModeActive = not IsTPGunEditModeActive
        showVillonNotice(IsTPGunEditModeActive and "Режим настройки: Перетащите кнопку TP GUN!" or "Позиция зафиксирована.")
        local btn = BindGui:FindFirstChild("MM2_TPGunButton")
        if btn then
            btn.Draggable = IsTPGunEditModeActive
            btn.BorderSizePixel = IsTPGunEditModeActive and 1 or 0
            btn.BorderColor3 = Color3.fromRGB(0, 150, 255)
        end
    end)
    createToggle(ls, "Show Shoot Murder Button", Options.MM2.ShootMurderButtonEnabled)
    createExecuteButton(ls, "Edit SHOOT MURDER Position", function()
        IsShootMurderEditModeActive = not IsShootMurderEditModeActive
        showVillonNotice(IsShootMurderEditModeActive and "Режим настройки: Перетащите кнопку SHOOT MURDER!" or "Позиция зафиксирована.")
        local btn = BindGui:FindFirstChild("MM2_ShootMurderButton")
        if btn then
            btn.Draggable = IsShootMurderEditModeActive
            btn.BorderSizePixel = IsShootMurderEditModeActive and 1 or 0
            btn.BorderColor3 = Color3.fromRGB(0, 150, 255)
        end
    end)
    createToggle(ls, "Show Throw Knife Button", Options.MM2.ThrowKnifeButtonEnabled)
    createExecuteButton(ls, "Edit THROW KNIFE Position", function()
        IsThrowKnifeEditModeActive = not IsThrowKnifeEditModeActive
        showVillonNotice(IsThrowKnifeEditModeActive and "Режим настройки: Перетащите кнопку THROW KNIFE!" or "Позиция зафиксирована.")
        local btn = BindGui:FindFirstChild("MM2_ThrowKnifeButton")
        if btn then
            btn.Draggable = IsThrowKnifeEditModeActive
            btn.BorderSizePixel = IsThrowKnifeEditModeActive and 1 or 0
            btn.BorderColor3 = Color3.fromRGB(0, 150, 255)
        end
    end)
    createToggle(ls, "Show Invis Bind Button", Options.MM2.InvisButtonEnabled)
    createExecuteButton(ls, "Edit INVIS Position", function()
        IsInvisEditModeActive = not IsInvisEditModeActive
        showVillonNotice(IsInvisEditModeActive and "Режим настройки: Перетащите кнопку INVIS!" or "Позиция зафиксирована.")
        local btn = BindGui:FindFirstChild("MM2_InvisButton")
        if btn then
            btn.Draggable = IsInvisEditModeActive
            btn.BorderSizePixel = IsInvisEditModeActive and 1 or 0
            btn.BorderColor3 = Color3.fromRGB(0, 150, 255)
        end
    end)
    createToggle(ls, "Show Fling Bind Button", Options.MM2.FlingButtonEnabled)
    createExecuteButton(ls, "Edit FLING Position", function()
        IsFlingEditModeActive = not IsFlingEditModeActive
        showVillonNotice(IsFlingEditModeActive and "Режим настройки: Перетащите кнопку FLING!" or "Позиция зафиксирована.")
        local btn = BindGui:FindFirstChild("MM2_FlingButton")
        if btn then
            btn.Draggable = IsFlingEditModeActive
            btn.BorderSizePixel = IsFlingEditModeActive and 1 or 0
            btn.BorderColor3 = Color3.fromRGB(0, 150, 255)
        end
    end)
    createToggle(ls, "Aim Murderer Only", Options.MM2.AimMurderOnly)
    createToggle(ls, "Auto-Aim murder", Options.MM2.AutoAimMurder)
    createToggle(ls, "Invisibility", Options.MM2.Invisibility, function(state)
        toggleInvisibilityLogic(state)
    end)
    createToggle(ls, "Touch Fling", Options.MM2.Fling, function(state)
        showVillonNotice(state and "Touch Fling Mode ACTIVE" or "Touch Fling Mode DISABLED")
    end)
    createToggle(ls, "Auto TP Gun on Drop", Options.MM2.AutoTPGun)
    createToggle(ls, "Show Kill All Button", Options.MM2.KillAllButtonEnabled)
    createExecuteButton(ls, "Edit KILL ALL Position", function()
        IsKillAllEditModeActive = not IsKillAllEditModeActive
        showVillonNotice(IsKillAllEditModeActive and "Режим настройки: Перетащите кнопку KILL ALL!" or "Позиция зафиксирована.")
        local btn = BindGui:FindFirstChild("KillAllButton")
        if btn then
            btn.Draggable = IsKillAllEditModeActive
            btn.BorderSizePixel = IsKillAllEditModeActive and 1 or 0
            btn.BorderColor3 = Color3.fromRGB(0, 150, 255)
        end
    end)
    createToggle(ls, "Show Kill Sheriff Button", Options.MM2.KillSheriffButtonEnabled)
    createExecuteButton(ls, "Edit KILL SHERIFF Position", function()
        IsKillSheriffEditModeActive = not IsKillSheriffEditModeActive
        showVillonNotice(IsKillSheriffEditModeActive and "Режим настройки: Перетащите кнопку KILL SHERIFF!" or "Позиция зафиксирована.")
        local btn = BindGui:FindFirstChild("KillSheriffButton")
        if btn then
            btn.Draggable = IsKillSheriffEditModeActive
            btn.BorderSizePixel = IsKillSheriffEditModeActive and 1 or 0
            btn.BorderColor3 = Color3.fromRGB(0, 150, 255)
        end
    end)
    createToggle(ls, "Jerk Off", Options.MM2.JerkOffEnabled)

    -- Правая колонка
    createExecuteButton(rs, "Fling Murderer", FlingMurderer)
    createExecuteButton(rs, "Fling Sheriff", FlingSheriff)
    createExecuteButton(rs, "Kill All", KillAll)
    createExecuteButton(rs, "Kill Sheriff", KillSheriff)
end
fillMM2()

-- 4. MISC (включая Configs, ChangeFling, AspectRatio)
local function fillMisc()
    local ls = leftScrolls["Misc"]
    local rs = rightScrolls["Misc"]
    -- Левая колонка
    createToggle(ls, "Spin Bot", Options.Misc.SpinBot)
    createToggle(ls, "Custom WalkSpeed", Options.Misc.WalkSpeedEnabled)
    createSlider(ls, "WalkSpeed Value", 16, 200, Options.Misc.WalkSpeedValue, function(val)
        Options.Misc.WalkSpeedValue = val
    end)
    createToggle(ls, "Anti-Fling Protection", Options.Misc.AntiFling)
    createToggle(ls, "Double Jump", Options.Misc.DoubleJump)
    createToggle(ls, "Change Fov", Options.Misc.FovEnabled)
    createSlider(ls, "Fov Value", 30, 120, Options.Misc.FovValue, function(val)
        Options.Misc.FovValue = val
    end)
    createToggle(ls, "Speed Glitch (BHOP)", Options.Misc.SpeedGlitchEnabled)
    createSlider(ls, "Speed Glitch Value", 1, 50, Options.Misc.SpeedGlitchValue, function(val)
        Options.Misc.SpeedGlitchValue = val
    end)
    createToggle(ls, "Stretch (растяг)", Options.Misc.StretchEnabled)
    createToggle(ls, "Aspect Ratio", Options.Misc.AspectRatioEnabled, function(state)
        Options.Misc.AspectRatioEnabled = state
        updateAspectRatio()
    end)
    createSlider(ls, "Aspect Ratio Value", 0.5, 1.5, Options.Misc.AspectRatioValue, function(val)
        Options.Misc.AspectRatioValue = val
        if Options.Misc.AspectRatioEnabled then updateAspectRatio() end
    end)

    -- Правая колонка: Configs + ChangeFling + Unload
    -- Configs
    local nameBox = Instance.new("TextBox")
    nameBox.Size = UDim2.new(1, 0, 0, 26)
    nameBox.BackgroundColor3 = Color3.fromRGB(35, 35, 42)
    nameBox.Text = "config1"
    nameBox.Font = Enum.Font.GothamMedium
    nameBox.TextSize = 13
    nameBox.TextColor3 = Color3.fromRGB(220, 220, 230)
    nameBox.Parent = rs
    Instance.new("UICorner", nameBox).CornerRadius = UDim.new(0, 7)

    local function saveConfig(name)
        if name == "" then
            showVillonNotice("Введите имя конфига")
            return
        end
        local configData = {
            Options = Options,
            ButtonPositions = ButtonPositions
        }
        local json = game:GetService("HttpService"):JSONEncode(configData)
        local useFileSystem = pcall(function() return writefile end)
        local configFolder = "VillonConfigs/"
        if useFileSystem then
            pcall(function()
                if not isfolder(configFolder) then makefolder(configFolder) end
                writefile(configFolder .. name .. ".json", json)
            end)
            showVillonNotice("Конфиг сохранён")
        else
            if not getgenv().VillonConfigs then getgenv().VillonConfigs = {} end
            getgenv().VillonConfigs[name] = configData
            showVillonNotice("Конфиг сохранён (в памяти)")
        end
    end

    local function loadConfig(name)
        if name == "" then
            showVillonNotice("Введите имя конфига")
            return
        end
        local configData = nil
        local useFileSystem = pcall(function() return readfile end)
        local configFolder = "VillonConfigs/"
        if useFileSystem then
            local success, data = pcall(function()
                return readfile(configFolder .. name .. ".json")
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
        if configData.Options then
            for k, v in pairs(configData.Options) do
                Options[k] = v
            end
        end
        if configData.ButtonPositions then
            for bName, pos in pairs(configData.ButtonPositions) do
                local btn = BindGui:FindFirstChild(bName)
                if btn then
                    if pos.OffsetX and pos.OffsetY then
                        btn.Position = UDim2.new(pos.X, pos.OffsetX or 0, pos.Y, pos.OffsetY or 0)
                    else
                        btn.Position = UDim2.new(pos.X, 0, pos.Y, 0)
                    end
                    ButtonPositions[bName] = pos
                end
            end
        end
        showVillonNotice("Конфиг загружен")
    end

    createExecuteButton(rs, "Save Config", function() saveConfig(nameBox.Text) end)
    createExecuteButton(rs, "Load Config", function() loadConfig(nameBox.Text) end)

    -- Change Fling
    local flingContainer = Instance.new("Frame")
    flingContainer.Size = UDim2.new(1, 0, 0, 0)
    flingContainer.AutomaticSize = Enum.AutomaticSize.Y
    flingContainer.BackgroundTransparency = 1
    flingContainer.Parent = rs

    local flingLayout = Instance.new("UIListLayout")
    flingLayout.SortOrder = Enum.SortOrder.LayoutOrder
    flingLayout.Padding = UDim.new(0, 6)
    flingLayout.Parent = flingContainer

    local flingTitle = Instance.new("TextLabel")
    flingTitle.Size = UDim2.new(1, 0, 0, 22)
    flingTitle.BackgroundTransparency = 1
    flingTitle.Text = "Change Fling"
    flingTitle.Font = Enum.Font.GothamBold
    flingTitle.TextSize = 13
    flingTitle.TextColor3 = Color3.fromRGB(235, 235, 240)
    flingTitle.TextXAlignment = Enum.TextXAlignment.Left
    flingTitle.Parent = flingContainer

    local selectedPlayers = {}
    local checkBoxes = {}

    local function updateFlingPlayerList()
        for _, child in ipairs(flingContainer:GetChildren()) do
            if child:IsA("TextButton") and child ~= flingTitle then
                child:Destroy()
            end
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
            btn.Size = UDim2.new(1, 0, 0, 26)
            btn.BackgroundColor3 = Color3.fromRGB(32, 32, 38)
            btn.Text = "  " .. p.Name
            btn.TextColor3 = Color3.fromRGB(200, 200, 200)
            btn.Font = Enum.Font.Gotham
            btn.TextSize = 12
            btn.TextXAlignment = Enum.TextXAlignment.Left
            btn.BorderSizePixel = 0
            btn.AutoButtonColor = false
            btn.Parent = flingContainer
            Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 5)

            local check = Instance.new("TextLabel")
            check.Size = UDim2.new(0, 26, 1, 0)
            check.Position = UDim2.new(1, -26, 0, 0)
            check.BackgroundTransparency = 1
            check.Text = "☐"
            check.TextColor3 = Color3.fromRGB(255,255,255)
            check.TextSize = 14
            check.Font = Enum.Font.Gotham
            check.Parent = btn

            local selected = false
            checkBoxes[p] = { btn = btn, check = check, selected = false }

            btn.MouseButton1Click:Connect(function()
                selected = not selected
                checkBoxes[p].selected = selected
                if selected then
                    check.Text = "☑"
                    check.TextColor3 = Color3.fromRGB(0,255,100)
                    btn.BackgroundColor3 = Color3.fromRGB(42, 42, 52)
                    table.insert(selectedPlayers, p)
                else
                    check.Text = "☐"
                    check.TextColor3 = Color3.fromRGB(255,255,255)
                    btn.BackgroundColor3 = Color3.fromRGB(32, 32, 38)
                    for i, v in ipairs(selectedPlayers) do
                        if v == p then
                            table.remove(selectedPlayers, i)
                            break
                        end
                    end
                end
            end)
        end
    end

    updateFlingPlayerList()
    Players.PlayerAdded:Connect(updateFlingPlayerList)
    Players.PlayerRemoving:Connect(updateFlingPlayerList)

    createExecuteButton(flingContainer, "FLING SELECTED", function()
        if #selectedPlayers == 0 then
            showVillonNotice("Выберите игроков")
            return
        end
        task.spawn(function()
            for _, p in ipairs(selectedPlayers) do
                if p and p.Character then
                    SHubFling(p)
                    task.wait(0.5)
                end
            end
            showVillonNotice("Флинг выбранных завершен")
        end)
    end)

    createExecuteButton(flingContainer, "STOP FLING", function()
        if #selectedPlayers == 0 then
            showVillonNotice("Выберите игроков")
            return
        end
        for _, p in ipairs(selectedPlayers) do
            if p and p.Character then
                local root = p.Character:FindFirstChild("HumanoidRootPart")
                if root then
                    root.Velocity = Vector3.new(0, 0, 0)
                    root.RotVelocity = Vector3.new(0, 0, 0)
                    for _, bv in ipairs(root:GetDescendants()) do
                        if bv:IsA("BodyVelocity") or bv:IsA("BodyAngularVelocity") or bv.Name == "SeYyyVel!?" then
                            bv:Destroy()
                        end
                    end
                    local hum = p.Character:FindFirstChildOfClass("Humanoid")
                    if hum then hum:ChangeState("GettingUp") end
                end
            end
        end
        showVillonNotice("Флинг остановлен")
    end)

    -- Unload
    createExecuteButton(rs, "UNLOAD CHEAT", function()
        for _, connection in ipairs(Connections) do
            if connection then connection:Disconnect() end
        end
        if aspectConnection then aspectConnection:Disconnect() end
        local gunDrop = Workspace:FindFirstChild("GunDrop", true)
        if gunDrop then
            if gunDrop:FindFirstChild("GunHighlight") then gunDrop.GunHighlight:Destroy() end
            if gunDrop:FindFirstChild("GunEsp") then gunDrop.GunEsp:Destroy() end
        end
        if workspace:FindFirstChild("invischair") then workspace.invischair:Destroy() end
        for _, storage in pairs(VisualStorage) do
            if type(storage) == "table" then
                for _, obj in pairs(storage) do
                    if type(obj) == "userdata" and obj.Remove then obj:Remove() end
                end
            end
        end
        FOVCircle:Remove()
        screenGui:Destroy()
        BindGui:Destroy()
        getgenv().AdvancedCoreLoaded = nil
        showVillonNotice("VillonHub выгружен.")
    end)
end
fillMisc()

------------------------------------------------------------------
-- Вкладки + анимации (переключают панели)
------------------------------------------------------------------
local tabBar = Instance.new("Frame")
tabBar.Size = UDim2.new(1, 0, 0, 36)
tabBar.Position = UDim2.new(0, 0, 1, -36)
tabBar.BackgroundColor3 = Color3.fromRGB(16, 16, 19)
tabBar.BorderSizePixel = 0
tabBar.Parent = main
Instance.new("UICorner", tabBar).CornerRadius = UDim.new(0, 12)

local tabButtons = {}
local tabWidth = 1 / #tabNames
local currentTab = "Combat"

local function switchTab(name)
    if currentTab == name then return end
    currentTab = name

    -- Анимация смены (сдвиг и прозрачность)
    local leftPanelsToHide = leftPanels[currentTab]
    local rightPanelsToHide = rightPanels[currentTab]
    local leftPanelsToShow = leftPanels[name]
    local rightPanelsToShow = rightPanels[name]

    if leftPanelsToHide then
        TweenService:Create(leftPanelsToHide, TweenInfo.new(0.15), {BackgroundTransparency = 0.4, Position = UDim2.new(-0.1, 0, 0, 0)}):Play()
        TweenService:Create(rightPanelsToHide, TweenInfo.new(0.15), {BackgroundTransparency = 0.4, Position = UDim2.new(0.6, 0, 0, 0)}):Play()
        task.delay(0.15, function()
            leftPanelsToHide.Visible = false
            rightPanelsToHide.Visible = false
            leftPanelsToHide.BackgroundTransparency = 0
            rightPanelsToHide.BackgroundTransparency = 0
            leftPanelsToHide.Position = UDim2.new(0, 0, 0, 0)
            rightPanelsToHide.Position = UDim2.new(0.515, 0, 0, 0)
        end)
    end

    task.delay(0.05, function()
        leftPanelsToShow.Visible = true
        rightPanelsToShow.Visible = true
        leftPanelsToShow.Position = UDim2.new(-0.1, 0, 0, 0)
        rightPanelsToShow.Position = UDim2.new(0.6, 0, 0, 0)
        leftPanelsToShow.BackgroundTransparency = 0.4
        rightPanelsToShow.BackgroundTransparency = 0.4
        TweenService:Create(leftPanelsToShow, TweenInfo.new(0.22), {Position = UDim2.new(0, 0, 0, 0), BackgroundTransparency = 0}):Play()
        TweenService:Create(rightPanelsToShow, TweenInfo.new(0.22), {Position = UDim2.new(0.515, 0, 0, 0), BackgroundTransparency = 0}):Play()
    end)

    -- Обновляем заголовки
    local titles = {
        Combat = { left = "Combat", right = "Actions" },
        Visuals = { left = "Visuals", right = "ESP" },
        MM2 = { left = "MM2", right = "Kills" },
        Misc = { left = "Misc", right = "Utils" }
    }
    if titles[name] then
        leftTitles[name].Text = titles[name].left
        rightTitles[name].Text = titles[name].right
    end

    -- Обновляем подсветку вкладок
    for _, t in pairs(tabButtons) do
        t.TextColor3 = Color3.fromRGB(120, 120, 135)
        local u = t:FindFirstChildOfClass("Frame")
        if u then u.Visible = false end
    end
    for _, t in pairs(tabButtons) do
        if t.Text == name then
            t.TextColor3 = Color3.fromRGB(235, 235, 240)
            local u = t:FindFirstChildOfClass("Frame")
            if u then u.Visible = true end
        end
    end
end

for i, name in ipairs(tabNames) do
    local tab = Instance.new("TextButton")
    tab.Size = UDim2.new(tabWidth, 0, 1, 0)
    tab.Position = UDim2.new(tabWidth * (i - 1), 0, 0, 0)
    tab.BackgroundTransparency = 1
    tab.Text = name
    tab.Font = Enum.Font.GothamMedium
    tab.TextSize = 11
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
        tab.TextColor3 = Color3.fromRGB(235, 235, 240)
    end

    tab.MouseButton1Click:Connect(function()
        switchTab(name)
    end)

    tabButtons[i] = tab
end

------------------------------------------------------------------
-- ОТКРЫТИЕ / ЗАКРЫТИЕ
------------------------------------------------------------------
menuOpen = false

function openMenu()
    if menuOpen then return end
    menuOpen = true

    main.Visible = true
    main.Size = UDim2.new(0, 0, 0, 0)
    main.Position = UDim2.new(0.5, 0, 0.5, 0)
    main.BackgroundTransparency = 1

    TweenService:Create(main, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Size = UDim2.new(0, 480, 0, 300),
        Position = UDim2.new(0.5, -240, 0.5, -150),
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
        BackgroundColor3 = Color3.fromRGB(55, 55, 70),
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
        BackgroundTransparency = 0.3
    }):Play()
end)

print("[VillonHub] Финальная версия загружена")