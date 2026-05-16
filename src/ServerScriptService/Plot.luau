-- // PlotManager, initialized by KingCreoo on 8-19-2025
-- // Manages a player's pre-built plot (Plot1-Plot6 in workspace.Plots).
-- // Plots are never cloned; we attach to an existing folder and reset it on cleanup.

-- // Define
local PlotManager = {}
PlotManager.__index = PlotManager

-- // Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Players = game:GetService("Players")

-- // Modules
local Data = require(ServerScriptService:WaitForChild("Server"):WaitForChild("Data"))
local RewardLoop = require(ServerScriptService:WaitForChild("Server"):WaitForChild("RewardLoop"))
local SETTINGS = require(ReplicatedStorage:WaitForChild("Settings"))

-- // Variables
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local SetSoldierEvent: RemoteEvent = Remotes:WaitForChild("SetSoldier")
local SetTargetEvent: RemoteEvent = Remotes:WaitForChild("SetTarget")
local ClearSoldierEvent: RemoteEvent = Remotes:WaitForChild("ClearSoldier")

local SetSoldierBindable: BindableEvent = Remotes:WaitForChild("SetSoldierBindable")
local SetTargetBindable: BindableEvent = Remotes:WaitForChild("SetTargetBindable")
local ClearSoldierBindable: BindableEvent = Remotes:WaitForChild("ClearSoldierBindable")

local function EnsureRemoteEvent(Name: string): RemoteEvent
    local Existing = Remotes:FindFirstChild(Name)
    if Existing and Existing:IsA("RemoteEvent") then return Existing end
    local Event = Instance.new("RemoteEvent")
    Event.Name = Name
    Event.Parent = Remotes
    return Event
end

local UpdateCollectPadEvent: RemoteEvent = EnsureRemoteEvent("UpdateCollectPad")
local CollectCashEvent: RemoteEvent = EnsureRemoteEvent("CollectCash")

local TOTAL_LANES = 8

-- // Local helpers

-- Extracts the numeric lane index from "Slot4" -> 4. Returns nil on bad input.
local function LaneNumberFromSlot(SlotName: string): number?
    if type(SlotName) ~= "string" or string.sub(SlotName, 1, 4) ~= "Slot" then
        return nil
    end
    return tonumber(string.sub(SlotName, 5))
end

-- Returns true if the given slot name is currently unlocked in player data.
local function IsSlotUnlocked(PlayerData: table, SlotName: string): boolean
    return PlayerData.Plot.Unlocks[SlotName] == true
end

-- Builds the list of unlocked slot names ("Slot1", "Slot3"...) in numeric order.
local function GetUnlockedSlots(PlayerData: table): {string}
    local Unlocked = {}
    for Lane = 1, TOTAL_LANES do
        local SlotName = "Slot" .. Lane
        if IsSlotUnlocked(PlayerData, SlotName) then
            table.insert(Unlocked, SlotName)
        end
    end
    return Unlocked
end

-- Counts entries in the ActiveSoldiers dict (keyed by lane number).
local function CountActiveSoldiers(ActiveSoldiers: table): number
    local Count = 0
    for _ in pairs(ActiveSoldiers) do
        Count += 1
    end
    return Count
end

-- Finds the slot name a soldier ID is currently equipped in. Returns nil if not active.
local function FindLaneForSoldier(ActiveSoldiers: table, SoldierID: string): string?
    for Lane, ID in pairs(ActiveSoldiers) do
        if ID == SoldierID then
            return "Slot" .. Lane
        end
    end
    return nil
end

-- Ensures runtime container folders exist on a plot (Soldiers/Targets folders for visualizers).
local function EnsureContainers(PlotFolder: Instance)
    if not PlotFolder:FindFirstChild("Soldiers") then
        local Folder = Instance.new("Folder")
        Folder.Name = "Soldiers"
        Folder.Parent = PlotFolder
    end
    if not PlotFolder:FindFirstChild("Targets") then
        local Folder = Instance.new("Folder")
        Folder.Name = "Targets"
        Folder.Parent = PlotFolder
    end
end

-- // Module functions

-- Binds this PlotManager to an existing workspace.Plots.PlotN folder.
function PlotManager.new(Player: Player, PlayerData: table, PlotName: string)
    local self = setmetatable({}, PlotManager)

    local PlotFolder = workspace:WaitForChild("Plots"):FindFirstChild(PlotName)
    assert(PlotFolder, "Plot folder not found: " .. tostring(PlotName))

    self.Player = Player
    self.PlotName = PlotName
    self.Plot = PlotFolder

    -- Mirror tables for RewardLoop and the collect-pad system
    self.RLActiveSoldiers = {}
    self.RLActiveTarget = nil
    self.CollectConnections = {}

    EnsureContainers(self.Plot)

    self:Populate(PlayerData)
    self:SetupCollectPads()
    self:SyncCollectPadAmounts()

    RewardLoop.SetupRewards(self.Player)

    return self
end

-- Re-applies the player's saved active soldiers + active target onto the plot.
function PlotManager:Populate(PlayerData: table)
    -- 1) Active soldiers (dict keyed by lane number)
    local ActiveSoldiers = PlayerData.Inventory.ActiveSoldiers
    for Lane, SoldierID in pairs(ActiveSoldiers) do
        local LaneNum = tonumber(Lane)
        if LaneNum then
            self:SetSoldier("Slot" .. LaneNum, SoldierID)
        end
    end

    -- 2) Active target
    local ActiveTarget = PlayerData.Inventory.ActiveTarget
    if ActiveTarget and ActiveTarget ~= "" then
        self:SetTarget(ActiveTarget)
    end
end

-- Shows or hides a single collect pad based on whether its lane is unlocked.
-- Toggles GUIs, part transparency, and idle particle emitter.
function PlotManager:SetCollectPadVisible(Lane: number, Visible: boolean)
    local CashCollectors = self.Plot:FindFirstChild("CashCollectors")
    if not CashCollectors then return end
    local PadModel = CashCollectors:FindFirstChild("CollectCash" .. Lane)
    if not PadModel then return end

    -- Toggle BillboardGuis
    local GuiParts = PadModel:FindFirstChild("GuiParts")
    if GuiParts then
        for _, Gui in ipairs(GuiParts:GetChildren()) do
            if Gui:IsA("BillboardGui") then
                Gui.Enabled = Visible
            end
        end
    end

    -- Toggle transparency on all BaseParts except GuiParts (the two visible pad parts)
    -- and toggle idle particle emitter on the 0.5-stud part
    for _, Child in ipairs(PadModel:GetChildren()) do
        if Child:IsA("BasePart") and Child.Name ~= "GuiParts" then
            Child.Transparency = Visible and 0 or 1
            if Child.Size.X == 0.5 then
                local Emitter = Child:FindFirstChildOfClass("ParticleEmitter")
                if Emitter then Emitter.Enabled = Visible end
            end
        end
    end
end

-- Fires UpdateCollectPad to the client for every unlocked lane so GUIs show correct amounts on join.
function PlotManager:SyncCollectPadAmounts()
    local PlayerData = Data.Get(self.Player)
    local PendingCash = PlayerData["PendingCash"] or {}
    for Lane = 1, TOTAL_LANES do
        if IsSlotUnlocked(PlayerData, "Slot" .. Lane) then
            local Amount = PendingCash[Lane] or 0
            UpdateCollectPadEvent:FireClient(self.Player, Lane, Amount)
        end
    end
end

-- Wires the per-lane cash collect pads to the claim flow.
-- Shows pads for unlocked lanes, hides locked ones.
function PlotManager:SetupCollectPads()
    local CashCollectors = self.Plot:FindFirstChild("CashCollectors")
    if not CashCollectors then
        warn("[PlotManager] No CashCollectors folder on plot " .. self.PlotName)
        return
    end

    local PlayerData = Data.Get(self.Player)

    for Lane = 1, TOTAL_LANES do
        local PadModel = CashCollectors:FindFirstChild("CollectCash" .. Lane)
        if not PadModel then continue end

        local Unlocked = IsSlotUnlocked(PlayerData, "Slot" .. Lane)
        self:SetCollectPadVisible(Lane, Unlocked)

        if not Unlocked then continue end

        -- Find the 0.5-stud step-on detector part (Size.X == 0.5, Size=(0.5, 5.0, 5.0))
        local StepPart
        for _, Child in ipairs(PadModel:GetChildren()) do
            if Child:IsA("BasePart") and Child.Name ~= "GuiParts" and Child.Size.X == 0.5 then
                StepPart = Child
                break
            end
        end

        if StepPart then
            local Debounce = false
            local LaneNum = Lane -- capture for closure
            local Connection = StepPart.Touched:Connect(function(Hit)
                if Debounce then return end

                local Humanoid = Hit.Parent and Hit.Parent:FindFirstChild("Humanoid")
                if not Humanoid then return end

                local HitPlayer = Players:GetPlayerFromCharacter(Hit.Parent)
                if HitPlayer ~= self.Player then return end

                -- Only collect if there's actually cash waiting
                if RewardLoop.GetPendingCash(self.Player.Name)[LaneNum] and RewardLoop.GetPendingCash(self.Player.Name)[LaneNum] > 0 then
                    Debounce = true
                    RewardLoop.ClaimRewards(self.Player, LaneNum)
                    CollectCashEvent:FireClient(self.Player, LaneNum)
                    task.wait(1)
                    Debounce = false
                end
            end)
            self.CollectConnections[Lane] = Connection
        end
    end
end

-- Called when a new lane is unlocked — shows that lane's collect pad and wires it.
function PlotManager:OnLaneUnlocked(Lane: number)
    self:SetCollectPadVisible(Lane, true)
    local PlayerData = Data.Get(self.Player)
    local Amount = (PlayerData["PendingCash"] and PlayerData["PendingCash"][Lane]) or 0
    UpdateCollectPadEvent:FireClient(self.Player, Lane, Amount)

    -- Wire the touch connection if not already wired
    if self.CollectConnections[Lane] then return end

    local CashCollectors = self.Plot:FindFirstChild("CashCollectors")
    if not CashCollectors then return end
    local PadModel = CashCollectors:FindFirstChild("CollectCash" .. Lane)
    if not PadModel then return end

    local StepPart
    for _, Child in ipairs(PadModel:GetChildren()) do
        if Child:IsA("BasePart") and Child.Name ~= "GuiParts" and Child.Size.X == 0.5 then
            StepPart = Child
            break
        end
    end

    if StepPart then
        local Debounce = false
        local LaneNum = Lane
        self.CollectConnections[Lane] = StepPart.Touched:Connect(function(Hit)
            if Debounce then return end
            local Humanoid = Hit.Parent and Hit.Parent:FindFirstChild("Humanoid")
            if not Humanoid then return end
            local HitPlayer = Players:GetPlayerFromCharacter(Hit.Parent)
            if HitPlayer ~= self.Player then return end
            if RewardLoop.GetPendingCash(self.Player.Name)[LaneNum] and RewardLoop.GetPendingCash(self.Player.Name)[LaneNum] > 0 then
                Debounce = true
                RewardLoop.ClaimRewards(self.Player, LaneNum)
                CollectCashEvent:FireClient(self.Player, LaneNum)
                task.wait(1)
                Debounce = false
            end
        end)
    end
end

-- Deactivates a soldier from whichever lane it occupies. Lane becomes nil (gap allowed).
function PlotManager:Deactivate(SoldierID: string)
    local PlayerData = Data.Get(self.Player)

    -- Player must own the soldier
    if not PlayerData.Inventory.SoldierInventory[SoldierID] then
        return false, PlayerData
    end

    -- Soldier must currently be active
    local SlotName = FindLaneForSoldier(PlayerData.Inventory.ActiveSoldiers, SoldierID)
    if not SlotName then
        return false, PlayerData
    end

    local LaneNum = LaneNumberFromSlot(SlotName)

    -- Clear lane (dict, no reindexing, gaps are valid)
    PlayerData.Inventory.ActiveSoldiers[LaneNum] = nil
    self.RLActiveSoldiers[LaneNum] = nil

    Data.Set(self.Player, PlayerData, true)

    ClearSoldierEvent:FireAllClients(self.Player, SlotName)
    ClearSoldierBindable:Fire(self.Player.Name, SlotName)

    return true, PlayerData
end

-- Activates a soldier by placing it in the lowest empty unlocked lane.
-- AutoEquip-style placement respects gaps and never touches locked slots.
function PlotManager:Activate(SoldierID: string)
    local PlayerData = Data.Get(self.Player)

    -- Player must own the soldier
    if not PlayerData.Inventory.SoldierInventory[SoldierID] then
        return false, PlayerData
    end

    -- Soldier must not already be active
    if FindLaneForSoldier(PlayerData.Inventory.ActiveSoldiers, SoldierID) then
        return false, PlayerData
    end

    -- Find the lowest unlocked, unoccupied lane
    local TargetLane
    for Lane = 1, TOTAL_LANES do
        if IsSlotUnlocked(PlayerData, "Slot" .. Lane) and PlayerData.Inventory.ActiveSoldiers[Lane] == nil then
            TargetLane = Lane
            break
        end
    end

    if not TargetLane then
        return false, PlayerData
    end

    self:SetSoldier("Slot" .. TargetLane, SoldierID)
    return true, PlayerData
end

-- Places a soldier ID into a specific lane. Server-authoritative; caller already validated.
function PlotManager:SetSoldier(SlotName: string, SoldierID: string)
    local PlayerData = Data.Get(self.Player)

    -- Slot must be unlocked
    if not IsSlotUnlocked(PlayerData, SlotName) then
        warn("[PlotManager] SetSoldier called on locked slot " .. SlotName .. " by " .. self.Player.Name)
        return
    end

    -- Soldier must exist in inventory
    local SoldierData = PlayerData.Inventory.SoldierInventory[SoldierID]
    if not SoldierData then
        return
    end

    local LaneNum = LaneNumberFromSlot(SlotName)
    if not LaneNum then return end

    PlayerData.Inventory.ActiveSoldiers[LaneNum] = SoldierID
    self.RLActiveSoldiers[LaneNum] = SoldierID
    Data.Set(self.Player, PlayerData, true)

    SetSoldierEvent:FireAllClients(self.Player, SlotName, SoldierID, SoldierData)
    SetSoldierBindable:Fire(self.Player.Name, SlotName, SoldierID, SoldierData)
end

-- Switches the player's active target type and respawns targets on every unlocked lane.
function PlotManager:SetTarget(TargetType: string)
    if not SETTINGS.TARGET_DATA[TargetType] then
        warn("[PlotManager] SetTarget called with unknown target type: " .. tostring(TargetType))
        return
    end

    local PlayerData = Data.Get(self.Player)

    if not PlayerData.Inventory.TargetInventory[TargetType] then
        warn("[PlotManager] SetTarget called for unowned target " .. TargetType)
        return
    end

    PlayerData.Inventory.ActiveTarget = TargetType
    self.RLActiveTarget = TargetType
    Data.Set(self.Player, PlayerData)

    local UnlockedSlots = GetUnlockedSlots(PlayerData)
    SetTargetEvent:FireAllClients(self.Player, UnlockedSlots, TargetType)
    SetTargetBindable:Fire(self.Player.Name, UnlockedSlots, TargetType)
end

-- Resets the plot's runtime state when a player leaves. Does NOT destroy the plot folder.
function PlotManager:Cleanup()
    -- Disconnect collect pad touch handlers
    for Lane, Connection in pairs(self.CollectConnections) do
        Connection:Disconnect()
        self.CollectConnections[Lane] = nil
    end

    -- Clear any visual children that were parented to runtime containers
    local SoldiersFolder = self.Plot:FindFirstChild("Soldiers")
    if SoldiersFolder then
        SoldiersFolder:ClearAllChildren()
    end
    local TargetsFolder = self.Plot:FindFirstChild("Targets")
    if TargetsFolder then
        TargetsFolder:ClearAllChildren()
    end
end

-- // Return
return PlotManager
