-- // Client, initialized by KingCreoo on 8-19-2025
-- // Manages basic client-side functions

-- // Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

-- // Modules
local PlotVisualizer = require(script.PlotVisualizer)

-- // Variables
local LocalPlayer = Players.LocalPlayer

local PublicAnimations = true

local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local SetSoldierEvent: RemoteEvent = Remotes:WaitForChild("SetSoldier")
local SetTargetEvent: RemoteEvent = Remotes:WaitForChild("SetTarget")
local ClearSoldierEvent = Remotes:WaitForChild("ClearSoldier")
local UpdateCollectPadEvent: RemoteEvent = Remotes:WaitForChild("UpdateCollectPad")
local CollectCashEvent: RemoteEvent = Remotes:WaitForChild("CollectCash")
local PlotAssignmentEvent: RemoteEvent = Remotes:WaitForChild("PlotAssignment")

local SOUND_MANAGER = require(ReplicatedStorage:WaitForChild("Settings"):WaitForChild("SoundManager"))
local SETTINGS = require(ReplicatedStorage:WaitForChild("Settings"))

-- Maps Player.Name -> PlotName for resolving the local player's plot folder.
local LocalPlayerPlot = nil

-- Tracks local player's active soldiers per lane and active target for DPS display.
-- { [LaneNum] = SoldierData } and ActiveTarget string
local LocalActiveSoldiers = {}
local LocalActiveTarget = nil

PlotAssignmentEvent.OnClientEvent:Connect(function(PlayerName: string, PlotName: string)
    if PlayerName == LocalPlayer.Name then
        LocalPlayerPlot = PlotName
        print("[Client] Plot assigned: " .. PlotName)

        -- Reset all CashToCollectGui labels to $0 immediately on join, overriding Studio placeholder
        task.spawn(function()
            local Plot = workspace:WaitForChild("Plots"):WaitForChild(PlotName, 10)
            if not Plot then return end
            local CashCollectors = Plot:WaitForChild("CashCollectors", 10)
            if not CashCollectors then return end
            for _, PadModel in ipairs(CashCollectors:GetChildren()) do
                local GuiParts = PadModel:FindFirstChild("GuiParts")
                if GuiParts then
                    local CashToCollectGui = GuiParts:FindFirstChild("CashToCollectGui")
                    if CashToCollectGui then
                        local Label = CashToCollectGui:FindFirstChildOfClass("TextLabel")
                        if Label then Label.Text = "$0" end
                    end
                end
            end
            print("[Client] Reset all collect pad labels to $0")
        end)
    end
end)

-- // Functions

-- Calculates cash-per-second for a soldier type against the current active target.
local function CalculateLaneDPS(SoldierType: string, TargetType: string): number
    local SoldierStats = SETTINGS.SOLDIER_DATA[SoldierType]
    local TargetData = SETTINGS.TARGET_DATA[TargetType]
    if not SoldierStats or not TargetData then return 0 end

    local WeaponInfo = SoldierStats.WeaponInfo
    local WeaponType = SoldierStats.WeaponType
    local Damage = WeaponInfo.Damage

    -- Bullets per trigger pull (mirrors RewardLoop/IdleRewards logic)
    local BulletsPerShot = 1
    if WeaponType == "Burst" then
        BulletsPerShot = WeaponInfo.Bullets or 1
    elseif WeaponType == "Dual" then
        BulletsPerShot = 2
    end

    local EffectiveDamage = Damage * BulletsPerShot
    local ShotsToKill = math.ceil(TargetData.TotalHealth / EffectiveDamage)
    local KillTime = (ShotsToKill - 1) * WeaponInfo.FireRate
    local TravelTime = SETTINGS.DISTANCES.Worlds.Default / WeaponInfo.BulletSpeed
    local CycleTime = KillTime + TravelTime + TargetData.TotalRespawnTime

    return TargetData.Reward / CycleTime
end

-- Updates the CashPerSecondGui on a single lane's collect pad.
local function RefreshLaneDPS(LaneNum: number)
    if not LocalPlayerPlot then
        -- Plot not assigned yet; retry once it is
        task.spawn(function()
            local Elapsed = 0
            while not LocalPlayerPlot and Elapsed < 5 do
                task.wait(0.1)
                Elapsed += 0.1
            end
            RefreshLaneDPS(LaneNum)
        end)
        return
    end
    local Plot = workspace:WaitForChild("Plots"):FindFirstChild(LocalPlayerPlot)
    if not Plot then return end
    local CashCollectors = Plot:FindFirstChild("CashCollectors")
    if not CashCollectors then return end
    local PadModel = CashCollectors:FindFirstChild("CollectCash" .. LaneNum)
    if not PadModel then return end
    local GuiParts = PadModel:FindFirstChild("GuiParts")
    if not GuiParts then return end
    local DPSGui = GuiParts:FindFirstChild("CashPerSecondGui")
    if not DPSGui then return end
    local Label = DPSGui:FindFirstChildOfClass("TextLabel")
    if not Label then return end

    local SoldierData = LocalActiveSoldiers[LaneNum]
    if not SoldierData or not LocalActiveTarget then
        Label.Text = "$0/s"
        return
    end

    local DPS = CalculateLaneDPS(SoldierData.Type, LocalActiveTarget)
    Label.Text = "$" .. string.format("%.1f", DPS) .. "/s"
end

local function OnSetSoldier(Player: Player, SlotNumber: string, SoldierID: string, SoldierData: table)
    if Player ~= LocalPlayer and not PublicAnimations then return end
    PlotVisualizer.SetSoldier(Player, SlotNumber, SoldierID, SoldierData)

    -- Track for DPS display and refresh that lane
    if Player == LocalPlayer then
        local LaneNum = tonumber(string.sub(SlotNumber, 5))
        if LaneNum then
            LocalActiveSoldiers[LaneNum] = SoldierData
            RefreshLaneDPS(LaneNum)
        end
    end
end

local function OnSetTarget(Player: Player, UnlockedLanes: table, TargetType: string)
    if Player ~= LocalPlayer and not PublicAnimations then return end
    PlotVisualizer.SetTarget(Player, UnlockedLanes, TargetType)

    -- Track target and refresh all active lanes
    if Player == LocalPlayer then
        LocalActiveTarget = TargetType
        for LaneNum in pairs(LocalActiveSoldiers) do
            RefreshLaneDPS(LaneNum)
        end
    end
end

local function OnClearSoldier(Player: Player, Slot: string)
    if Player ~= LocalPlayer and not PublicAnimations then return end
    PlotVisualizer.ClearSoldier(Player, Slot)

    -- Clear tracking and reset DPS display
    if Player == LocalPlayer then
        local LaneNum = tonumber(string.sub(Slot, 5))
        if LaneNum then
            LocalActiveSoldiers[LaneNum] = nil
            RefreshLaneDPS(LaneNum)
        end
    end
end

-- Updates a single collect pad's CashToCollectGui with the current pending amount.
local function OnUpdateCollectPad(LaneNum: number, Amount: number)
    if not LocalPlayerPlot then
        -- Plot not assigned yet; retry once it is
        task.spawn(function()
            local Elapsed = 0
            while not LocalPlayerPlot and Elapsed < 5 do
                task.wait(0.1)
                Elapsed += 0.1
            end
            OnUpdateCollectPad(LaneNum, Amount)
        end)
        return
    end
    local Plot = workspace:WaitForChild("Plots"):FindFirstChild(LocalPlayerPlot)
    if not Plot then return end
    local CashCollectors = Plot:FindFirstChild("CashCollectors")
    if not CashCollectors then return end
    local PadModel = CashCollectors:FindFirstChild("CollectCash" .. LaneNum)
    if not PadModel then return end
    local GuiParts = PadModel:FindFirstChild("GuiParts")
    if not GuiParts then return end
    local CashToCollectGui = GuiParts:FindFirstChild("CashToCollectGui")
    if not CashToCollectGui then return end
    local Label = CashToCollectGui:FindFirstChildOfClass("TextLabel")
    if Label then
        Label.Text = "$" .. tostring(Amount)
    end
end

-- // Events
SetSoldierEvent.OnClientEvent:Connect(OnSetSoldier)
SetTargetEvent.OnClientEvent:Connect(OnSetTarget)
ClearSoldierEvent.OnClientEvent:Connect(OnClearSoldier)
UpdateCollectPadEvent.OnClientEvent:Connect(OnUpdateCollectPad)

-- Fires button tween, white flash, particle burst, and cash sound when a collect pad is stepped on.
CollectCashEvent.OnClientEvent:Connect(function(LaneNum: number)
    if not LocalPlayerPlot then return end
    local Plot = workspace:WaitForChild("Plots"):FindFirstChild(LocalPlayerPlot)
    if not Plot then return end
    local CashCollectors = Plot:FindFirstChild("CashCollectors")
    if not CashCollectors then return end
    local PadModel = CashCollectors:FindFirstChild("CollectCash" .. LaneNum)
    if not PadModel then return end

    for _, Child in ipairs(PadModel:GetChildren()) do
        if not Child:IsA("BasePart") then continue end

        -- Button face (thin 0.2-stud part): tween down then spring back + flash white
        if Child.Size.X < 0.3 then
            local OrigCFrame = Child.CFrame
            local PressIn = TweenService:Create(Child, TweenInfo.new(0.05, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
                CFrame = OrigCFrame * CFrame.new(0, -0.05, 0),
                Color = Color3.new(1, 1, 1),
                Transparency = 0,
            })
            local PressOut = TweenService:Create(Child, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                CFrame = OrigCFrame,
                Transparency = 1,
            })
            PressIn:Play()
            PressIn.Completed:Connect(function()
                PressOut:Play()
            end)
        end

        -- Particle burst on the 0.5-stud emitter part
        if Child.Size.X > 0.4 and Child.Size.X < 0.6 then
            local Emitter = Child:FindFirstChildOfClass("ParticleEmitter")
            if Emitter then
                local OrigSpeed = Emitter.Speed
                local OrigLifetime = Emitter.Lifetime

                Emitter.Speed = NumberRange.new(3, 5)
                Emitter.Lifetime = NumberRange.new(0.4, 0.7)
                Emitter:Emit(25)

                task.delay(0.05, function()
                    Emitter.Speed = OrigSpeed
                    Emitter.Lifetime = OrigLifetime
                end)
            end
        end
    end

    -- Play cash collection sound
    SOUND_MANAGER:PlayPurchase()
end)