-- // Plot Visualizer, initialized by KingCreoo on 8-28-2025
-- // Manages animations of soldiers on a player's plot

-- // Define
local PlotVisualizer = {}

-- // Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")

-- // Modules
local SETTINGS = require(ReplicatedStorage:WaitForChild("Settings"))
local EntityHandlerModule = require(script.Parent.EntityHandler)
local SOUND_MANAGER = require(ReplicatedStorage:WaitForChild("Settings"):WaitForChild("SoundManager"))

-- // Variables
local Lanes = {[Players.LocalPlayer.Name] = {}}
local Soldiers = {[Players.LocalPlayer.Name] = {}}
local Targets = {[Players.LocalPlayer.Name] = {}}
local DueDeaths = {[Players.LocalPlayer.Name] = {}}
local TargetTypes = {}

local PotatoModeEnabled = false

local SoldierTimers = {}

local SoldierModels = ReplicatedStorage:WaitForChild("Types"):WaitForChild("Soldiers")
local TargetModels = ReplicatedStorage:WaitForChild("Types"):WaitForChild("Targets")
local MarkerTemplate = ReplicatedStorage:WaitForChild("Types"):WaitForChild("Marker")

local EntityHandler = EntityHandlerModule.new({"StandardBullet", "StandardExplosion"})

local LocalPlayer = Players.LocalPlayer

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local FireSoldierEvent: RemoteEvent = Remotes:WaitForChild("FireSoldier")
local UpdateSettingBindable: BindableEvent = Remotes:WaitForChild("UpdateSettingBindable")

-- // Functions

local function AddStatusBar(SoldierModel: Model, SoldierData: table)
    -- 1) After soldier model is created and positioned, clone and parent the statusbar
    local StatusBar = ReplicatedStorage:WaitForChild("StatusBar"):Clone()
    StatusBar.Parent = SoldierModel:WaitForChild("Head")

    -- 2) Set the color of the status bar based on soldier type
    local SoldierColor = SETTINGS.SOLDIER_DATA[SoldierData.Type]["Color"]
    StatusBar.Color.BackgroundColor3 = SoldierColor
end

local function AddHealthBar(TargetModel: Model, TargetType: string)
    -- 1) After target model is created, add it's healthbar
    local HealthBar = ReplicatedStorage:WaitForChild("HealthBar"):Clone()
    HealthBar.Parent = TargetModel:WaitForChild("BarParent")

    -- 2)
    local TypeColor = SETTINGS.TARGET_DATA[TargetType]["Color"]
    HealthBar.Color.BackgroundColor3 = TypeColor
end

local function ResetStatusBar(SoldierModel: Model, SoldierData: table)
    -- 1) Define variables
    local StatusBar = SoldierModel:FindFirstChild("Head"):FindFirstChild("StatusBar")
    if not StatusBar then return end

    local WeaponInfo = SETTINGS.SOLDIER_DATA[SoldierData["Type"]]["WeaponInfo"]
    local FireRate = WeaponInfo["FireRate"]
    if not FireRate then return end

    local ColorFrame: Frame = StatusBar:FindFirstChild("Color")
    if not ColorFrame then return end

	-- 2) Calculate starting position after quick reset
	local QuickResetDuration = 0.2
	local FillSpeed = 1 / FireRate
	local DistanceCovered = FillSpeed * QuickResetDuration
	local StartPosition = 0 + DistanceCovered

	-- 3) Quick tween from 1 to StartPosition
	local QuickResetTween = TweenService:Create(ColorFrame, TweenInfo.new(QuickResetDuration, Enum.EasingStyle.Quad), {Size = UDim2.fromScale(StartPosition, 1)})
	QuickResetTween:Play()

	-- 4) After quick reset completes, start main fill tween
	QuickResetTween.Completed:Connect(function()
		local ResetTween = TweenService:Create(ColorFrame, TweenInfo.new(FireRate, Enum.EasingStyle.Quad), {Size = UDim2.fromScale(1, 1)})
		ResetTween:Play()
	end)
end

local function RegenerateHealthBar(TargetModel: Model, TargetType: string)
    -- 1) Get health bar and necessary data
    local HealthBar = TargetModel:FindFirstChild("BarParent"):FindFirstChild("HealthBar")
    if not HealthBar then return end

    local ColorFrame: Frame = HealthBar:FindFirstChild("Color")
    if not ColorFrame then return end

    local RespawnTime = SETTINGS.TARGET_DATA[TargetType]["TotalRespawnTime"]

    -- 2) Reset bar to 0 just in case
    ColorFrame.Size = UDim2.fromScale(0, 1)

    -- 3) Tween from 0 to 1 over the respawn duration
    local RegenerationTween = TweenService:Create(ColorFrame, TweenInfo.new(RespawnTime - 0.15, Enum.EasingStyle.Quad), {Size = UDim2.fromScale(1, 1)})
    RegenerationTween:Play()
end

local function DamageHealthBar(TargetModel: Model, TargetType: string, CurrentHealth: number, Death: boolean)
    -- 1) Get health bar and necessary data
    if not TargetModel or not TargetModel:FindFirstChild("BarParent") then return end
    local HealthBar = TargetModel:FindFirstChild("BarParent"):FindFirstChild("HealthBar")
    if not HealthBar then return end

    local ColorFrame: Frame = HealthBar:FindFirstChild("Color")
    if not ColorFrame then return end

    local MaxHealth = SETTINGS.TARGET_DATA[TargetType]["TotalHealth"]

    -- 2) Calculate new health percentage
    local HealthPercentage = CurrentHealth / MaxHealth

    -- 3) Tween bar down to new health percentage
    local DamageTween = TweenService:Create(ColorFrame, TweenInfo.new(0.15, Enum.EasingStyle.Quad), {Size = UDim2.fromScale(HealthPercentage, 1)})
    DamageTween:Play()

    DamageTween.Completed:Connect(function()
        if Death then
            RegenerateHealthBar(TargetModel, TargetType)
        end
    end)
end

local function EquipWeapon(SoldierModel: Model, WeaponType: string)
    -- 1) Clone and parent weapon
    local Weapon = ReplicatedStorage:WaitForChild("Types"):WaitForChild("Weapons"):WaitForChild(WeaponType):Clone()
    Weapon.Parent = SoldierModel
    Weapon.Name = "Weapon"

    -- 2) Get parts for animation
    local PartsToRegenerate = {}
    local WeaponParts = Weapon:GetChildren()
    for _, Part in pairs(WeaponParts) do
        Part.Transparency = 1
        table.insert(PartsToRegenerate, Part)
    end

    -- 2) Create Motor6D joint to attach weapon to hand
    local Handle = Weapon:WaitForChild("Handle")
    local Joint = Instance.new("Motor6D")
    Joint.Parent = Handle
    Joint.Part0 = SoldierModel:WaitForChild("Right Arm")
    Joint.Part1 = Handle

      -- 3) Set weapon offsets from SETTINGS
    Joint.C0 = SETTINGS["WEAPON_DATA"][WeaponType]["C0"]
    Joint.C1 = SETTINGS["WEAPON_DATA"][WeaponType]["C1"]

    -- 4) Play idle animation
    local Animator = SoldierModel:WaitForChild("AnimationController"):WaitForChild("Animator")
    local IdleAnimation = SoldierModel:WaitForChild("Animations"):WaitForChild(WeaponType .. "Idle")
    local Track = Animator:LoadAnimation(IdleAnimation)
    Track:Play()

    return Weapon, PartsToRegenerate
end

local function AnimateExplosion(Position)
    -- Create explosion effect
    local Explosion = EntityHandler:Create("StandardExplosion")
    Explosion.CFrame = CFrame.new(Position)
    Explosion.Parent = Workspace.Explosions

    -- Configure and trigger explosion particles
    local ParticleEmitter = Explosion:FindFirstChild("ParticleEmitter")
    ParticleEmitter.Color = ColorSequence.new(Color3.fromRGB(255, 70, 70))
    ParticleEmitter:Emit(8)

    -- Play hitmarker sound
    SOUND_MANAGER:PlayHitmarker(Position)

    -- Cleanup explosion after 1 second
    task.delay(1, function()
        EntityHandler:Recycle(Explosion)
    end)
end

-- Animates a single bullet/pellet from fire point to target
local function AnimateSingleBullet(FirePoint, TargetPosition, Distance, BulletSpeed, SoldierCFrame, SpreadAmount)
    -- 1) Create bullet from pool
    local Bullet = EntityHandler:Create("StandardBullet")

    -- 2) Position bullet at weapon fire point
    Bullet.CFrame = FirePoint * CFrame.Angles(0, math.rad(90), 0)
    Bullet.Parent = Workspace.Bullets

    -- 3) Calculate tween duration
    local Duration = Distance / BulletSpeed

    -- 4) Add spread in soldier's local coordinate system
    local RandomSpread = (math.random() - 0.5) * SpreadAmount
    local RandomHeight = (math.random() - 0.5) * SpreadAmount

    local RightDirection = SoldierCFrame.RightVector
    local UpDirection = SoldierCFrame.UpVector

    local FinalTargetPosition = TargetPosition + RightDirection * RandomSpread + UpDirection * RandomHeight

    -- 5) Tween to target
    local Tween = TweenService:Create(
        Bullet,
        TweenInfo.new(Duration, Enum.EasingStyle.Linear),
        {Position = FinalTargetPosition}
    )
    Tween.Parent = Bullet
    Tween:Play()

    -- 6) Explosion and cleanup
    task.delay(Duration, function()
        AnimateExplosion(FinalTargetPosition)
        Tween:Destroy()
        Bullet.AssemblyLinearVelocity = Vector3.zero
        EntityHandler:Recycle(Bullet)
    end)

    return Duration
end

local function AnimateBullet(PlayerName, SoldierID, SoldierData, TargetSlot)
    -- 1) Get soldier and target models
    local Plot = Workspace:WaitForChild("Plots"):WaitForChild(PlayerName)
    if not Plot then
        return 0
    end

    local SoldierModel = Plot.Soldiers:FindFirstChild(SoldierID)
    local TargetModel = Plot.Targets:FindFirstChild("Target" .. string.sub(TargetSlot, 5))

    if not SoldierModel or not TargetModel then
        return 0
    end

    -- 2) Get weapon info
    local WeaponInfo = SETTINGS["SOLDIER_DATA"][SoldierData.Type]["WeaponInfo"]
    local WeaponType = SETTINGS["SOLDIER_DATA"][SoldierData.Type]["WeaponType"]
    local BulletSpeed = WeaponInfo["BulletSpeed"]

    -- 3) Calculate common values
    local TargetPosition = TargetModel.Target.Position
    local Distance = (Plot.Info.Target1.Position - Plot.Info.Slot1.Position).Magnitude
    local SoldierCFrame = SoldierModel:GetPrimaryPartCFrame()

    -- 4) Handle based on weapon type
    if WeaponType == "Shotgun" then
        -- Shotgun fires multiple pellets with random cone spread
        local FirePoint = SoldierModel:WaitForChild("Weapon"):WaitForChild("Fire").CFrame
        local Pellets = WeaponInfo["Pellets"] or 5
        local MaxSpreadIntensity = WeaponInfo["SpreadIntensity"] or 3

        local Duration = 0
        for _ = 1, Pellets do
            -- Each pellet gets random spread between 1 and SpreadIntensity
            local RandomSpreadAmount = math.random() * (MaxSpreadIntensity - 1) + 1
            Duration = AnimateSingleBullet(FirePoint, TargetPosition, Distance, BulletSpeed, SoldierCFrame, RandomSpreadAmount * 2)
        end
        return Duration
    elseif WeaponType == "Dual" then
        -- Dual fires from alternating fire points
        local FirePointIndex = SoldierData.FirePointIndex or 1
        local FirePointName = "Fire" .. FirePointIndex
        local FirePoint = SoldierModel:WaitForChild("Weapon"):WaitForChild(FirePointName).CFrame
        local SpreadIntensity = WeaponInfo["SpreadIntensity"] or 1
        return AnimateSingleBullet(FirePoint, TargetPosition, Distance, BulletSpeed, SoldierCFrame, SpreadIntensity)
    else
        -- Automatic and Burst fire single bullets (burst handled server-side in RewardLoop.luau)
        local FirePoint = SoldierModel:WaitForChild("Weapon"):WaitForChild("Fire").CFrame
        local SpreadIntensity = WeaponInfo["SpreadIntensity"] or 2
        return AnimateSingleBullet(FirePoint, TargetPosition, Distance, BulletSpeed, SoldierCFrame, SpreadIntensity)
    end
end

local DAMAGE_COLOR = Color3.fromRGB(255, 60, 60)
local MarkerCounter = 0

-- Spawns a single floating marker at the given world position with the given text and color
local function SpawnMarker(SpawnPos: Vector3, Text: string, Color: Color3, AngleDeg: number?)
    -- 1) Throwaway anchor so marker survives parent destruction
    local Anchor = Instance.new("Part")
    Anchor.Anchored = true
    Anchor.CanCollide = false
    Anchor.Transparency = 1
    Anchor.Size = Vector3.new(0.1, 0.1, 0.1)
    Anchor.CFrame = CFrame.new(SpawnPos)
    Anchor.Parent = Workspace

    local Marker = MarkerTemplate:Clone()
    Marker.Adornee = Anchor
    Marker.Parent = Anchor

    -- 2) Apply text and color
    local Label: TextLabel = Marker:WaitForChild("Label")
    Label.Text = Text
    Label.TextColor3 = Color

    -- 3) Drift up and to the right, 15-75 degrees from straight up
    local Angle = AngleDeg or math.random(15, 75)
    local AngleRad = math.rad(Angle)
    local Magnitude = math.random(300, 500) / 100 -- 3 to 5 studs

    -- Newer markers get a slightly more negative Z so they render in front of older ones
    MarkerCounter = (MarkerCounter + 1) % 200
    local ZBias = -MarkerCounter * 0.01
    Marker.StudsOffset = Vector3.new(0, 0, ZBias)

    local DriftEnd = Vector3.new(
        math.sin(AngleRad) * Magnitude,
        math.cos(AngleRad) * Magnitude,
        ZBias
    )

    -- 4) Float and fade (slightly variable duration for natural feel)
    local Duration = math.random(80, 100) / 100 -- 0.8 to 1.0 seconds
    TweenService:Create(
        Marker,
        TweenInfo.new(Duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        {StudsOffset = DriftEnd}
    ):Play()
    TweenService:Create(
        Label,
        TweenInfo.new(Duration, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
        {TextTransparency = 1}
    ):Play()

    local Stroke = Label:FindFirstChildOfClass("UIStroke")
    if Stroke then
        TweenService:Create(
            Stroke,
            TweenInfo.new(Duration, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
            {Transparency = 1}
        ):Play()
    end

    -- 5) Cleanup
    task.delay(Duration + 0.1, function()
        Anchor:Destroy()
    end)
end

local function DestroyTarget(InfoTable: table)
    local PlayerName = InfoTable.PlayerName
    local SlotName = InfoTable.SoldierData.Slot

    -- 1) Check if target already dead (prevent double-processing)
    if Targets[PlayerName][SlotName].State ~= "Alive" then
        return
    end

    -- 2) Mark target as dead
    Targets[PlayerName][SlotName].State = "Dead"

    -- 3) Hide target model
    local Plot = Workspace:WaitForChild("Plots"):WaitForChild(PlayerName)
    local TargetSlot = string.sub(SlotName, 5)  -- Extract "1" from "Slot1"
    local TargetModel = Plot.Targets:FindFirstChild("Target" .. TargetSlot)
    local PartsToRegenerate = {}
    if TargetModel then
        for _, Inst in pairs(TargetModel:GetChildren()) do
            if Inst.ClassName == "Part" and Inst.Name ~= "Anchor" and Inst.Name ~= "Target" and Inst.Name ~= "BarParent" then
                Inst.Transparency = 1
                table.insert(PartsToRegenerate, Inst)
            elseif Inst:IsA("Model") then
                for _, iInst in pairs(Inst:GetChildren()) do
                    iInst.Transparency = 1
                    table.insert(PartsToRegenerate, iInst)
                end
            end
        end
    end

    -- 4) Schedule respawn
    local RespawnTime = Targets[PlayerName][SlotName]["RespawnTime"]
    task.delay(RespawnTime, function()
        -- Reset health and state
        local CurrentTargetType = TargetTypes[PlayerName]
        Targets[PlayerName][SlotName].State = "Alive"
        Targets[PlayerName][SlotName].Health = SETTINGS["TARGET_DATA"][CurrentTargetType]["TotalHealth"]
    end)

    -- 5) Animate respawn
    task.delay(.3, function()
        for _, Part in pairs(PartsToRegenerate) do
            local RegenerationTween = TweenService:Create(Part, TweenInfo.new(RespawnTime - .3), {["Transparency"] = 0})
            RegenerationTween:Play()
        end

        task.delay(RespawnTime - .3, function()
            DueDeaths[InfoTable.PlayerName][InfoTable.SoldierData.Slot] = false
        end)
    end)
end

-- Computes the hit origin (2 studs toward the soldier from the target) and spawns damage markers
local function SpawnHitmarkers(TargetModel: Model, SoldierModel: Model, SoldierType: string, Damage: number)
    if not TargetModel or not TargetModel.PrimaryPart then return end
    if Damage <= 0 then return end

    -- Base position: above target, offset 4 studs toward soldier
    local BasePos = TargetModel.PrimaryPart.Position + Vector3.new(0, 1, 0)
    if SoldierModel and SoldierModel.PrimaryPart then
        local ToSoldier = SoldierModel.PrimaryPart.Position - TargetModel.PrimaryPart.Position
        ToSoldier = Vector3.new(ToSoldier.X, 0, ToSoldier.Z)
        if ToSoldier.Magnitude > 0 then
            BasePos += ToSoldier.Unit * 4
        end
    end

    -- Shotguns distribute total damage across pellets
    local WeaponInfo = SETTINGS.SOLDIER_DATA[SoldierType]["WeaponInfo"]
    local WeaponType = SETTINGS.SOLDIER_DATA[SoldierType]["WeaponType"]

    if WeaponType == "Shotgun" and WeaponInfo["Pellets"] then
        local Pellets = WeaponInfo["Pellets"]
        local Base = math.floor(Damage / Pellets)
        local Remainder = Damage % Pellets

        -- Build the list of pellets that will actually spawn
        local PelletDamages = {}
        for i = 1, Pellets do
            local PelletDamage = Base + (i <= Remainder and 1 or 0)
            if PelletDamage > 0 then
                table.insert(PelletDamages, PelletDamage)
            end
        end

        -- Divide 15-75 range into equal buckets, pick random angle within each
        local Count = #PelletDamages
        local BucketSize = 60 / Count
        for i, PelletDamage in ipairs(PelletDamages) do
            local BucketStart = 15 + (i - 1) * BucketSize
            local BucketEnd = BucketStart + BucketSize
            local Angle = BucketStart + math.random() * (BucketEnd - BucketStart)
            SpawnMarker(BasePos, "-" .. tostring(PelletDamage), DAMAGE_COLOR, Angle)
        end
    else
        SpawnMarker(BasePos, "-" .. tostring(Damage), DAMAGE_COLOR)
    end
end

local function AnimateSoldiers(SoldiersToAnimate: table)
    for _, InfoTable in pairs(SoldiersToAnimate) do
        -- 1) Animate soldier
        -- TODO soldier fire animations

        -- 2) Reset status bar
        local Plot = Workspace:WaitForChild("Plots"):WaitForChild(InfoTable.PlayerName)
        local SoldierModel = Plot.Soldiers:FindFirstChild(InfoTable.SoldierID)
        if SoldierModel then
            ResetStatusBar(SoldierModel, InfoTable.SoldierData)
        end

        -- 3) Animate bullet (always animate, even null bullets)
        local TimeToHit = AnimateBullet(InfoTable.PlayerName, InfoTable.SoldierID, InfoTable.SoldierData, InfoTable.SoldierData.Slot)

        -- 4) Skip health bar logic for null bullets
        if InfoTable.SoldierData.NullBullet then
            continue
        end

        -- 5) Health bar logic (only for non-null bullets)
        local Damage = SETTINGS["SOLDIER_DATA"][InfoTable.SoldierData.Type]["WeaponInfo"]["Damage"]
        
        -- Use server's target health for sync (server is source of truth)
        local CurrentHealth = InfoTable.SoldierData.TargetHealth or Targets[InfoTable.PlayerName][InfoTable.SoldierData.Slot]["Health"]

        Targets[InfoTable.PlayerName][InfoTable.SoldierData.Slot].Health = CurrentHealth - Damage

        --Animate healthbar
        local TargetSlot = string.sub(InfoTable.SoldierData.Slot, 5)
        local TargetModel = Plot.Targets:FindFirstChild("Target" .. TargetSlot)
        local TargetType = TargetTypes[InfoTable.PlayerName]

        local SoldierType = InfoTable.SoldierData.Type
        if CurrentHealth - Damage <= 0 and Targets[InfoTable.PlayerName][InfoTable.SoldierData.Slot].State == "Alive" then
            DueDeaths[InfoTable.PlayerName][InfoTable.SoldierData.Slot] = true
            task.delay(TimeToHit, function()
                SpawnHitmarkers(TargetModel, SoldierModel, SoldierType, Damage)
                DestroyTarget(InfoTable)
                DamageHealthBar(TargetModel, TargetType, CurrentHealth - Damage, true)
            end)
        else
            task.delay(TimeToHit, function()
                SpawnHitmarkers(TargetModel, SoldierModel, SoldierType, Damage)
                DamageHealthBar(TargetModel, TargetType, CurrentHealth - Damage, false)
            end)
        end
    end
end

RunService.Heartbeat:Connect(function()
    -- Do not animate any soldiers if player has potato mode enabled
    if PotatoModeEnabled then return end

    -- Early exit if no soldiers exist
    local HasSoldiers = false
    for _, PlayerSoldiers in pairs(Soldiers) do
        if next(PlayerSoldiers) then
            HasSoldiers = true
            break
        end
    end
    if not HasSoldiers then return end

    local CurrentTime = tick()
    local ReadyToFire = {}

    for PlayerName, PlayerSoldiers in pairs(Soldiers) do
        -- Do not animate local soldiers
        if PlayerName == LocalPlayer.Name then continue end

        for SoldierID, SoldierData in pairs(PlayerSoldiers) do
            -- 0) Preliminary checking
            if not Workspace.Plots[PlayerName].Soldiers:FindFirstChild(SoldierID) then
                SoldierTimers[SoldierID] = nil
                continue
            end

            -- If the target in this lane is due to die, then skip
            if DueDeaths[PlayerName][SoldierData.Slot] == true then
                continue
            end

            -- Check to see if the soldier is spawning, if so we skip
            if SoldierData.Spawning then
                continue
            end

            -- 1) Get soldier's base stats
            local BaseFireRate = SETTINGS["SOLDIER_DATA"][SoldierData.Type]["WeaponInfo"]["FireRate"]

            -- 2) Get any boosts
            -- TODO get boosts
            local AbsoluteFireRate = BaseFireRate -- + BOOSTS

            -- 3) Check if this soldier has a timer entry, if not create one
            if not SoldierTimers[SoldierID] then
                SoldierTimers[SoldierID] = CurrentTime + AbsoluteFireRate
            end

            -- 4) Check if ready to fire
            if CurrentTime >= SoldierTimers[SoldierID] then
                -- 4a) If yes, then add the soldier to ReadyToFire and prep the next fire time
                  table.insert(ReadyToFire, {
                      SoldierID = SoldierID,
                      PlayerName = PlayerName,
                      SoldierData = SoldierData
                  })
                  SoldierTimers[SoldierID] = CurrentTime + AbsoluteFireRate
              end
        end
    end

    -- Batch animate if any ready
      if #ReadyToFire > 0 then
          task.spawn(AnimateSoldiers, ReadyToFire)
      end
end)

local function SoldierPromise(Player, SoldierID, SoldierData, SoldierModel, SlotNumber)
    local Promise = require(game:GetService("ReplicatedStorage").Settings.Promise)

    SoldierData.Slot = SlotNumber
    SoldierData.Spawning = true
    Lanes[Player.Name][tonumber(string.sub(SlotNumber, 5))] = SoldierID
    Soldiers[Player.Name][SoldierID] = SoldierData

    local SpawnPromise = Promise.new(function(Resolve, Reject)
        SoldierData.SpawnReject = Reject
        task.delay(2, function()
            if not SoldierData.Cancelled then
                Resolve()
            end
        end)
    end)

    SpawnPromise:andThen(function()
        if SoldierData and not SoldierData.Cancelled then
            SoldierData.Spawning = false
            SoldierData.SpawnReject = nil
            SoldierData.SpawnPromise = nil
        end
    end):catch(function()
        if SoldierData then
            Soldiers[Player.Name][SoldierID] = nil
            Lanes[Player.Name][tonumber(string.sub(SlotNumber, 5))] = nil
            if SoldierModel then
                SoldierModel:Destroy()
            end
            SoldierData.Spawning = nil
            SoldierData.SpawnReject = nil
            SoldierData.SpawnPromise = nil
        end
    end)

    SoldierData.SpawnPromise = SpawnPromise
end

function PlotVisualizer.ClearSoldier(Player: Player, Slot: string)
    -- 0) Check if player exists in tables
    if not Soldiers[Player.Name] then return end

    -- 1) Find and remove soldier in specified slot
    local SoldierIDToRemove
    for SoldierID, SoldierData in pairs(Soldiers[Player.Name]) do
        if SoldierData.Slot == Slot then
            SoldierIDToRemove = SoldierID
            break
        end
    end

    -- 2) Man I don't even know
    if SoldierIDToRemove then
        -- 0) Check for promises
        local TargetSoldierData = Soldiers[Player.Name][SoldierIDToRemove]
        if TargetSoldierData.SpawnReject then
            TargetSoldierData.Cancelled = true
            TargetSoldierData.SpawnReject()
        end

        -- 1) Remove soldier model from workspace
        local Plot = Workspace:WaitForChild("Plots"):WaitForChild(Player.Name)
        local SoldierModel = Plot.Soldiers:FindFirstChild(SoldierIDToRemove)
        if SoldierModel then
            SoldierModel:Destroy()
        end

        -- 2) Remove from data tables
        Soldiers[Player.Name][SoldierIDToRemove] = nil
        SoldierTimers[SoldierIDToRemove] = nil

        -- 3) Update lanes table
        local SlotNumber = tonumber(string.sub(Slot, 5))
        Lanes[Player.Name][SlotNumber] = nil
    end

    -- 3) Reindex remaining soldiers by moving higher slots down
    local RemovedSlotNumber = tonumber(string.sub(Slot, 5))
    for SoldierID, SoldierData in pairs(Soldiers[Player.Name]) do
        local CurrentSlotNumber = tonumber(string.sub(SoldierData.Slot, 5))
        if CurrentSlotNumber > RemovedSlotNumber then
            -- Move soldier down one slot
            local NewSlotNumber = CurrentSlotNumber - 1
            SoldierData.Slot = "Slot" .. NewSlotNumber

            -- Update lanes table
            Lanes[Player.Name][NewSlotNumber] = SoldierID
            Lanes[Player.Name][CurrentSlotNumber] = nil

            -- Animate movement to new position if model exists
            local Plot = Workspace:WaitForChild("Plots"):WaitForChild(Player.Name)
            local SoldierModel = Plot.Soldiers:FindFirstChild(SoldierID)
            if SoldierModel then
                local NewPosition = Plot.SoldierSlots["Slot" .. NewSlotNumber].CFrame * CFrame.Angles(0, math.rad(-90), 0) + Vector3.new(0, 2.5, 0)

                SoldierModel:SetPrimaryPartCFrame(NewPosition)
            end
        end
    end
end

function PlotVisualizer.SetSoldier(Player: Player, SlotNumber: string, SoldierID: string, SoldierData: table)
    -- Initialize tables if player not yet registered
    if not Lanes[Player.Name] then
        Lanes[Player.Name] = {}
        Soldiers[Player.Name] = {}
        Targets[Player.Name] = {}
        DueDeaths[Player.Name] = {}
    end

    -- 1) Define variables
    local Plot = Workspace:WaitForChild("Plots"):WaitForChild(Player.Name)
    local SoldierModel = SoldierModels:WaitForChild(SoldierData["Model"]):Clone()

    -- 2) Remove existing soldier
    local ExistingSoldierID = Lanes[Player.Name][tonumber(string.sub(SlotNumber, 5))]
    if ExistingSoldierID then
        Soldiers[Player.Name][ExistingSoldierID] = nil
        SoldierTimers[ExistingSoldierID] = nil
        Plot:WaitForChild("Soldiers"):WaitForChild(ExistingSoldierID):Destroy()
    end

    -- 3) Promise
    SoldierPromise(Player, SoldierID, SoldierData, SoldierModel, SlotNumber)

    -- 4) Spawn animation
    SoldierModel.Name = SoldierID
    local PartsToRegenerate = {}
    for _, Inst in pairs(SoldierModel:GetChildren()) do
        if Inst.ClassName == "Part" and string.sub(Inst.Name, 1, 3) ~= "NHR" then
            Inst.Transparency = 1
            table.insert(PartsToRegenerate, Inst)
        elseif Inst:IsA("Model") then
            for _, iInst in pairs(Inst:GetChildren()) do
                iInst.Transparency = 1
                table.insert(PartsToRegenerate, iInst)
            end
        end
    end
    SoldierModel:SetPrimaryPartCFrame(Plot:WaitForChild("SoldierSlots"):WaitForChild(SlotNumber).CFrame * CFrame.Angles(0, math.rad(-90), 0) + Vector3.new(0,2.5,0))
    SoldierModel.Parent = Plot:WaitForChild("Soldiers")
    local SoldierStats = SETTINGS.SOLDIER_DATA[SoldierData.Type]
    if not SoldierStats then
        warn("[PlotVisualizer] Unknown soldier type: " .. tostring(SoldierData.Type) .. ", skipping")
        SoldierModel:Destroy()
        return
    end
    local WeaponType = SoldierStats["Weapon"]
    local _, WeaponParts = EquipWeapon(SoldierModel, WeaponType)

    for _, Part in pairs(WeaponParts) do
        Part.Transparency = 1
        table.insert(PartsToRegenerate, Part)
    end 

    for _, Part in pairs(PartsToRegenerate) do
        local RegenerationTween = TweenService:Create(Part, TweenInfo.new(2), {["Transparency"] = 0})
        RegenerationTween:Play()
    end

    -- 5) Add status bar
    AddStatusBar(SoldierModel, SoldierData)

    -- OLD) Set new soldier after animations
    --task.delay(2, function()
    --  Lanes[Player.Name][tonumber(string.sub(SlotNumber, 5))] = SoldierID
    --  SoldierData["Slot"] = SlotNumber
    --  Soldiers[Player.Name][SoldierID] = SoldierData
    --end)
    
end

function PlotVisualizer.SetTarget(Player: Player, UnlockedLanes: table, TargetType: string)
    -- Initialize tables if player not yet registered
    if not Lanes[Player.Name] then
        Lanes[Player.Name] = {}
        Soldiers[Player.Name] = {}
        Targets[Player.Name] = {}
        DueDeaths[Player.Name] = {}
    end

    -- 1) Define variables
    local Plot = Workspace:WaitForChild("Plots"):WaitForChild(Player.Name)
    local ModelName = SETTINGS["TARGET_DATA"][TargetType]["Model"]
    local TargetModelType = TargetModels:WaitForChild(ModelName)

    -- 2) Remove existing targets
    local ExistingTargetType = TargetTypes[Player.Name]
    if ExistingTargetType then
        for _, Target in pairs(Plot:WaitForChild("Targets"):GetChildren()) do
            Target:Destroy()
            -- TODO create clean animation
        end
    end

    -- 3) Set new targets
    TargetTypes[Player.Name] = TargetType
    for _, SlotName in pairs(UnlockedLanes) do
        local TargetModel = TargetModelType:Clone()
        TargetModel:SetPrimaryPartCFrame(Plot:WaitForChild("TargetSlots"):WaitForChild(SlotName).CFrame * CFrame.Angles(0, math.rad(90), 0) + Vector3.new(0, 2.5, 0))
        TargetModel.Name = "Target" .. string.sub(SlotName, 5)
        TargetModel.Parent = Plot:WaitForChild("Targets")
        AddHealthBar(TargetModel, TargetType)

        Targets[Player.Name][SlotName] = {["Health"] = SETTINGS["TARGET_DATA"][TargetType]["TotalHealth"], ["RespawnTime"] = SETTINGS["TARGET_DATA"][TargetType]["TotalRespawnTime"], ["State"] = "Alive"}
    end
end

-- // Events
Players.PlayerAdded:Connect(function(Player: Player) 
    Lanes[Player.Name] = {}
    Soldiers[Player.Name] = {}
    Targets[Player.Name] = {}
    DueDeaths[Player.Name] = {}
end)

Players.PlayerRemoving:Connect(function(Player: Player)
    Lanes[Player.Name] = nil
    Soldiers[Player.Name] = nil
    TargetTypes[Player.Name] = nil
    Targets[Player.Name] = nil
    DueDeaths[Player.Name] = nil
end)

FireSoldierEvent.OnClientEvent:Connect(function(InfoTable: table)
    AnimateSoldiers({{
          PlayerName = LocalPlayer.Name,
          SoldierID = InfoTable.SoldierID,
          SoldierData = InfoTable.SoldierData,
      }})
end)

UpdateSettingBindable.Event:Connect(function(Item, On)
    if Item == "PotatoMode" then
        PotatoModeEnabled = On
    end
end)

-- // Return
return PlotVisualizer