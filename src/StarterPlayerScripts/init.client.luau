-- // Client, initialized by KingCreoo on 8-19-2025
-- // Manages basic client-side functions

-- // Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

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

-- Maps Player.Name -> PlotName for resolving the local player's plot folder.
local LocalPlayerPlot = nil

PlotAssignmentEvent.OnClientEvent:Connect(function(PlayerName: string, PlotName: string)
    if PlayerName == LocalPlayer.Name then
        LocalPlayerPlot = PlotName
    end
end)

-- // Functions

local function OnSetSoldier(Player: Player, SlotNumber: string, SoldierID: string, SoldierData: table)
    -- 1) Check for public animations being disabled
    if Player ~= LocalPlayer and not PublicAnimations then return end

    -- 2) Set the soldier
    PlotVisualizer.SetSoldier(Player, SlotNumber, SoldierID, SoldierData)

    -- 3) Start soldier animation loop
end

local function OnSetTarget(Player: Player, UnlockedLanes: table, TargetType: string)
    -- 1) Check for public animations being disabled
    if Player ~= LocalPlayer and not PublicAnimations then return end

    -- 2) Set the targets
    PlotVisualizer.SetTarget(Player, UnlockedLanes, TargetType)
end

local function OnClearSoldier(Player: Player, Slot: string)
    -- 1) Check for public animations being disabled
    if Player ~= LocalPlayer and not PublicAnimations then return end

    -- 2) Clear the soldier
    PlotVisualizer.ClearSoldier(Player, Slot)
end

-- Updates a single collect pad's CashToCollectGui with the current pending amount.
local function OnUpdateCollectPad(LaneNum: number, Amount: number)
    if not LocalPlayerPlot then return end
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

-- Fires particle burst and plays cash sound when a lane's collect pad is stepped on.
CollectCashEvent.OnClientEvent:Connect(function(LaneNum: number)
    if not LocalPlayerPlot then return end
    local Plot = workspace:WaitForChild("Plots"):FindFirstChild(LocalPlayerPlot)
    if not Plot then return end
    local CashCollectors = Plot:FindFirstChild("CashCollectors")
    if not CashCollectors then return end
    local PadModel = CashCollectors:FindFirstChild("CollectCash" .. LaneNum)
    if not PadModel then return end

    -- Burst the particle emitter on the 0.5-stud part
    for _, Child in ipairs(PadModel:GetChildren()) do
        if Child:IsA("BasePart") and Child.Size.X == 0.5 then
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