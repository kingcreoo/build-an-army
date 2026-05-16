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
local UpdateBoostsEvent: RemoteEvent = Remotes:WaitForChild("UpdateBoosts")

local SOUND_MANAGER = require(ReplicatedStorage:WaitForChild("Settings"):WaitForChild("SoundManager"))
local SETTINGS = require(ReplicatedStorage:WaitForChild("Settings"))

-- Maps Player.Name -> PlotName for resolving the local player's plot folder.
local LocalPlayerPlot = nil

-- Tracks local player's active soldiers per lane and active target for DPS display.
-- { [LaneNum] = SoldierData } and ActiveTarget string
local LocalActiveSoldiers = {}
local LocalActiveTarget = nil

-- Mirrors the active boost state sent by the server. Used to compute boosted DPS client-side.
-- [BoostType] = { Amount, ExpiresAt } — same shape as UpdateBoosts payload.
local LocalActiveBoosts = {}

-- Returns the local player's Plot folder. Prefers the cached name from PlotAssignmentEvent,
-- but scans the Owner attribute if the event was missed (e.g. require() blocked the handler).
local function ResolveLocalPlot(): Instance?
    local Plots = workspace:FindFirstChild("Plots")
    if not Plots then return nil end
    if LocalPlayerPlot then
        local Cached = Plots:FindFirstChild(LocalPlayerPlot)
        if Cached then return Cached end
    end
    for _, Plot in ipairs(Plots:GetChildren()) do
        if Plot:GetAttribute("Owner") == LocalPlayer.Name then
            LocalPlayerPlot = Plot.Name
            return Plot
        end
    end
    return nil
end

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
-- Multipliers table is optional: pass nil for base (unboosted) DPS.
-- Mirrors the server's RewardLoop math exactly so the display matches actual earnings.
local function CalculateLaneDPS(SoldierType: string, TargetType: string, Multipliers: table?): number
    local SoldierStats = SETTINGS.SOLDIER_DATA[SoldierType]
    local TargetData = SETTINGS.TARGET_DATA[TargetType]
    if not SoldierStats or not TargetData then return 0 end

    local WeaponInfo = SoldierStats.WeaponInfo
    local WeaponType = SoldierStats.WeaponType

    -- Pull multipliers (default 1 = no boost)
    local DamageMulti   = Multipliers and (Multipliers["DamageMultiplier"]   or 1) or 1
    local FireRateMulti = Multipliers and (Multipliers["FireRateMultiplier"] or 1) or 1
    local TargetMulti   = Multipliers and (Multipliers["TargetMultiplier"]   or 1) or 1
    local CashMulti     = Multipliers and (Multipliers["CashMultiplier"]     or 1) or 1

    -- Bullets per trigger pull (mirrors RewardLoop/IdleRewards logic)
    local BulletsPerShot = 1
    if WeaponType == "Burst" then
        BulletsPerShot = WeaponInfo.Bullets or 1
    elseif WeaponType == "Dual" then
        BulletsPerShot = 2
    end

    -- DamageMultiplier increases damage per bullet → fewer shots to kill
    local EffectiveDamage = WeaponInfo.Damage * DamageMulti * BulletsPerShot
    local ShotsToKill = math.ceil(TargetData.TotalHealth / EffectiveDamage)

    -- FireRateMultiplier divides fire interval → faster shots
    local EffectiveFireRate = WeaponInfo.FireRate / FireRateMulti
    local KillTime = (ShotsToKill - 1) * EffectiveFireRate

    local TravelTime = SETTINGS.DISTANCES.Worlds.Default / WeaponInfo.BulletSpeed

    -- TargetMultiplier divides respawn time → faster cycle
    local EffectiveRespawn = TargetData.TotalRespawnTime / TargetMulti
    local CycleTime = KillTime + TravelTime + EffectiveRespawn

    -- TargetMultiplier and CashMultiplier both multiply reward per kill
    local EffectiveReward = TargetData.Reward * TargetMulti * CashMulti

    return EffectiveReward / CycleTime
end

-- Returns a flat multipliers table from LocalActiveBoosts (Amount per type, expired entries = 1).
-- Used to pass into CalculateLaneDPS for the boosted display.
local function GetCurrentMultipliers(): table
    local Now = os.time()
    local M = {}
    for _, BoostType in ipairs(SETTINGS.BOOST_TYPES) do
        local Entry = LocalActiveBoosts[BoostType]
        M[BoostType] = (Entry and Entry.ExpiresAt > Now) and Entry.Amount or 1
    end
    return M
end

-- Returns true if any boost multiplier is currently above 1.
local function AnyBoostActive(): boolean
    local Now = os.time()
    for _, Entry in pairs(LocalActiveBoosts) do
        if Entry.ExpiresAt > Now then return true end
    end
    return false
end

-- Finds or creates the BaseDPS label inside a CashPerSecondGui BillboardGui.
-- The existing Studio TextLabel is renamed "BoostedDPS" on first access and pinned to the right half.
-- A new "BaseDPS" label is cloned from it, darkened, and pinned to the left half.
-- Both labels fill the full billboard height; each takes half the width side by side.
local function GetOrCreateDPSLabels(DPSGui: BillboardGui): (TextLabel?, TextLabel?)
    local BoostedLabel = DPSGui:FindFirstChild("BoostedDPS")
    local BaseLabel    = DPSGui:FindFirstChild("BaseDPS")

    if not BoostedLabel then
        -- First time: rename the existing label and reposition it to the right half
        local Existing = DPSGui:FindFirstChildOfClass("TextLabel")
        if not Existing then return nil, nil end
        Existing.Name = "BoostedDPS"
        Existing.Size = UDim2.fromScale(0.5, 1)
        Existing.Position = UDim2.fromScale(0.5, 0)
        Existing.AnchorPoint = Vector2.new(0, 0)
        BoostedLabel = Existing
    end

    if not BaseLabel then
        -- Clone the boosted label, pin it to the left half, and darken it
        BaseLabel = BoostedLabel:Clone()
        BaseLabel.Name = "BaseDPS"
        BaseLabel.Size = UDim2.fromScale(0.5, 1)
        BaseLabel.Position = UDim2.fromScale(0, 0)
        BaseLabel.AnchorPoint = Vector2.new(0, 0)
        BaseLabel.TextColor3 = Color3.fromRGB(160, 160, 160)
        BaseLabel.Visible = false
        BaseLabel.Parent = DPSGui
    end

    return BoostedLabel, BaseLabel
end

-- Updates both DPS labels on a single lane's collect pad.
-- BoostedDPS shows the current effective DPS (with all active boosts applied).
-- BaseDPS shows the raw unboosted DPS and is only visible when a boost is active.
local function RefreshLaneDPS(LaneNum: number)
    local Plot = ResolveLocalPlot()
    if not Plot then
        task.spawn(function()
            local Elapsed = 0
            while not ResolveLocalPlot() and Elapsed < 5 do
                task.wait(0.1)
                Elapsed += 0.1
            end
            RefreshLaneDPS(LaneNum)
        end)
        return
    end
    local CashCollectors = Plot:FindFirstChild("CashCollectors")
    if not CashCollectors then return end
    local PadModel = CashCollectors:FindFirstChild("CollectCash" .. LaneNum)
    if not PadModel then return end
    local GuiParts = PadModel:FindFirstChild("GuiParts")
    if not GuiParts then return end
    local DPSGui = GuiParts:FindFirstChild("CashPerSecondGui")
    if not DPSGui then return end

    local BoostedLabel, BaseLabel = GetOrCreateDPSLabels(DPSGui)
    if not BoostedLabel then return end

    DPSGui.Enabled = true

    local SoldierData = LocalActiveSoldiers[LaneNum]
    if not SoldierData or not LocalActiveTarget then
        BoostedLabel.Text = "$0/s"
        if BaseLabel then BaseLabel.Visible = false end
        return
    end

    local BoostActive = AnyBoostActive()
    local Multipliers = GetCurrentMultipliers()

    -- Boosted label always shows the effective (boosted) DPS
    local BoostedDPS = CalculateLaneDPS(SoldierData.Type, LocalActiveTarget, Multipliers)
    BoostedLabel.Text = "$" .. string.format("%.1f", BoostedDPS) .. "/s"

    -- Base label shows unboosted DPS, only visible when a boost is actually active.
    -- When hidden, restore BoostedLabel to full width so it recenters.
    if BaseLabel then
        if BoostActive then
            local BaseDPS = CalculateLaneDPS(SoldierData.Type, LocalActiveTarget, nil)
            BaseLabel.Text = "$" .. string.format("%.1f", BaseDPS) .. "/s"
            BaseLabel.Visible = true
            -- BoostedLabel occupies right half when base is visible
            BoostedLabel.Size = UDim2.fromScale(0.5, 1)
            BoostedLabel.Position = UDim2.fromScale(0.5, 0)
        else
            BaseLabel.Visible = false
            -- BoostedLabel recenters to full width when no boost is active
            BoostedLabel.Size = UDim2.fromScale(1, 1)
            BoostedLabel.Position = UDim2.fromScale(0, 0)
        end
    end
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
    local Plot = ResolveLocalPlot()
    if not Plot then
        task.spawn(function()
            local Elapsed = 0
            while not ResolveLocalPlot() and Elapsed < 5 do
                task.wait(0.1)
                Elapsed += 0.1
            end
            OnUpdateCollectPad(LaneNum, Amount)
        end)
        return
    end
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
        CashToCollectGui.Enabled = true
        Label.Text = "$" .. tostring(Amount)
    end
end

-- // Events
SetSoldierEvent.OnClientEvent:Connect(OnSetSoldier)
SetTargetEvent.OnClientEvent:Connect(OnSetTarget)
ClearSoldierEvent.OnClientEvent:Connect(OnClearSoldier)
UpdateCollectPadEvent.OnClientEvent:Connect(OnUpdateCollectPad)

-- When boost state changes, update LocalActiveBoosts and refresh all active lane DPS displays
UpdateBoostsEvent.OnClientEvent:Connect(function(BoostState: table)
    LocalActiveBoosts = BoostState or {}
    for LaneNum in pairs(LocalActiveSoldiers) do
        RefreshLaneDPS(LaneNum)
    end
end)

-- Fires button tween, white flash, particle burst, and cash sound when a collect pad is stepped on.
CollectCashEvent.OnClientEvent:Connect(function(LaneNum: number)
    local Plot = ResolveLocalPlot()
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
            local OrigColor = Child.Color
            local OrigTransparency = Child.Transparency
            local PressIn = TweenService:Create(Child, TweenInfo.new(0.05, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
                CFrame = OrigCFrame * CFrame.new(0, -0.05, 0),
                Color = Color3.new(1, 1, 1),
                Transparency = 0,
            })
            -- Spring back: restore original position, color, and transparency
            local PressOut = TweenService:Create(Child, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                CFrame = OrigCFrame,
                Color = OrigColor,
                Transparency = OrigTransparency,
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