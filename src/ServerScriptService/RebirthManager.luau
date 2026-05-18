-- RebirthManager, initialized by KingCreoo
-- Handles the rebirth flow: validation, atomic data mutation, soldier wipe + grant,
-- permanent boost grant through BoostManager, and the post-rebirth client refresh.
--
-- A rebirth is committed by a single Data.Set after every PlayerData mutation is staged,
-- so the player either lands fully rebirthed or unchanged. PendingCash is auto-claimed
-- to credits BEFORE the cost check to prevent the "earn pending, rebirth to dodge cost"
-- exploit. PlotManager state (active soldiers, target) is reset after the save lands.

local RebirthManager = {}

-- // Services
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

-- // Modules
local SETTINGS = require(ReplicatedStorage:WaitForChild("Settings"))
local Data = require(ServerScriptService:WaitForChild("Server"):WaitForChild("Data"))
local BoostManager = require(ServerScriptService:WaitForChild("Server"):WaitForChild("BoostManager"))
local RewardLoop = require(ServerScriptService:WaitForChild("Server"):WaitForChild("RewardLoop"))

-- // Variables
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local ClearSoldierEvent: RemoteEvent = Remotes:WaitForChild("ClearSoldier")
local ClearSoldierBindable: BindableEvent = Remotes:WaitForChild("ClearSoldierBindable")
local LoadPlayerEvent: RemoteEvent = Remotes:WaitForChild("LoadPlayer")
local UpdateCollectPadEvent: RemoteEvent = Remotes:WaitForChild("UpdateCollectPad")

local TOTAL_LANES = 8

-- // Local helpers

-- Ensures PlayerData.Rebirth shape exists. ApplyDefaults already covers this at load
-- time; this is a belt-and-braces guard in case the table was wiped.
local function EnsureRebirthState(PlayerData: table)
    if not PlayerData.Rebirth then
        PlayerData.Rebirth = { PickedSoldiers = {}, PickedBoosts = {} }
    end
    if not PlayerData.Rebirth.PickedSoldiers then PlayerData.Rebirth.PickedSoldiers = {} end
    if not PlayerData.Rebirth.PickedBoosts then PlayerData.Rebirth.PickedBoosts = {} end
end

-- // Module functions

-- Returns the credit cost the player owes for their next rebirth, or nil if at the cap.
function RebirthManager.GetNextCost(PlayerData: table): number?
    local Next = (PlayerData.Rebirths or 0) + 1
    if Next > SETTINGS.REBIRTH_CONFIG.MaxRebirths then return nil end
    return SETTINGS.REBIRTH_CONFIG.Costs[Next]
end

-- Returns two dicts describing which wizard slots are still available to this player.
--   SoldiersAvailable[SoldierSlotKey] = boolean
--   BoostsAvailable[BoostFrameKey]    = boolean
-- A slot is "available" if its underlying soldier type / boost type was not picked
-- in a prior rebirth.
function RebirthManager.GetAvailableOptions(PlayerData: table): ({[string]: boolean}, {[string]: boolean})
    EnsureRebirthState(PlayerData)

    local Soldiers = {}
    for SlotKey, SoldierType in pairs(SETTINGS.REBIRTH_SOLDIERS) do
        Soldiers[SlotKey] = not (PlayerData.Rebirth.PickedSoldiers[SoldierType] == true)
    end

    local Boosts = {}
    for FrameKey, BoostConfig in pairs(SETTINGS.REBIRTH_BOOSTS) do
        Boosts[FrameKey] = not (PlayerData.Rebirth.PickedBoosts[BoostConfig.Type] == true)
    end

    return Soldiers, Boosts
end

-- Performs a single rebirth atomically.
-- PlotManager is the PlayerPlotManager instance from init.server (used to re-target lanes
-- and reset the collect pad GUIs after the reset). Pass nil if not yet available.
--
-- Returns (success: boolean, reason: string).
function RebirthManager.PerformRebirth(Player: Player, PickedSoldierSlot: any, PickedBoostFrame: any, PlotManager: any): (boolean, string)
    local PlayerData = Data.Get(Player)
    if not PlayerData then return false, "NoData" end
    EnsureRebirthState(PlayerData)

    -- 1) Cap check
    local CurrentRebirths = PlayerData.Rebirths or 0
    if CurrentRebirths >= SETTINGS.REBIRTH_CONFIG.MaxRebirths then
        return false, "MaxRebirths"
    end

    -- 2) Validate selections (must be valid wizard keys)
    if type(PickedSoldierSlot) ~= "string" or type(PickedBoostFrame) ~= "string" then
        return false, "Invalid"
    end
    local SoldierType = SETTINGS.REBIRTH_SOLDIERS[PickedSoldierSlot]
    local BoostConfig = SETTINGS.REBIRTH_BOOSTS[PickedBoostFrame]
    if not SoldierType or not BoostConfig then
        return false, "Invalid"
    end
    if not SETTINGS.SOLDIER_DATA[SoldierType] then
        -- Should never happen; rebirth soldiers are baked into SOLDIER_DATA.
        return false, "Invalid"
    end

    -- 3) Picked-already check (each option is one-shot per player)
    if PlayerData.Rebirth.PickedSoldiers[SoldierType] then return false, "SoldierUnavailable" end
    if PlayerData.Rebirth.PickedBoosts[BoostConfig.Type] then return false, "BoostUnavailable" end

    -- 4) Cost — auto-claim pending cash first so it can contribute to the cost check
    --    (also closes the "stash to dodge cost" exploit: pending is wiped either way).
    local Cost = SETTINGS.REBIRTH_CONFIG.Costs[CurrentRebirths + 1]
    if not Cost then return false, "NoCost" end

    local PendingTotal = RewardLoop.GetTotalPendingCash(Player.Name)
    local SpendableCredits = PlayerData.leaderstats.Credits + PendingTotal
    if SpendableCredits < Cost then
        return false, "Insufficient"
    end

    -- ====== Past all validation; from here on the rebirth WILL commit. ======

    -- 5) Drain pending cash to credits and clear pending state (in-memory + persistent + client)
    PlayerData.leaderstats.Credits += PendingTotal
    RewardLoop.ClearPendingCash(Player.Name)
    PlayerData.PendingCash = {}

    -- 6) Charge the rebirth cost
    PlayerData.leaderstats.Credits -= Cost

    -- 7) Broadcast ClearSoldier for every currently active lane so all clients drop visuals.
    --    Also notify RewardLoop's heartbeat tables via the bindable.
    for Lane in pairs(PlayerData.Inventory.ActiveSoldiers) do
        local Slot = "Slot" .. Lane
        ClearSoldierEvent:FireAllClients(Player, Slot)
        ClearSoldierBindable:Fire(Player.Name, Slot)
    end
    PlayerData.Inventory.ActiveSoldiers = {}

    -- 8) Wipe owned soldiers EXCEPT premium / rebirth (anything marked Special survives).
    local PreservedInventory = {}
    for SoldierID, SoldierData in pairs(PlayerData.Inventory.SoldierInventory) do
        local Entry = SETTINGS.SOLDIER_DATA[SoldierData.Type]
        if Entry and Entry.Special then
            PreservedInventory[SoldierID] = SoldierData
        end
    end
    PlayerData.Inventory.SoldierInventory = PreservedInventory

    -- 9) Grant the chosen rebirth soldier (Special=true means it survives every future rebirth)
    local NewSoldierID = HttpService:GenerateGUID()
    local SoldierEntry = SETTINGS.SOLDIER_DATA[SoldierType]
    PlayerData.Inventory.SoldierInventory[NewSoldierID] = {
        ["Model"] = SoldierEntry.Model or SoldierType,
        ["Type"] = SoldierType
    }

    -- 10) Reset target progression back to Target1
    PlayerData.Inventory.ActiveTarget = "Target1"
    PlayerData.Inventory.TargetInventory = { Target1 = true }

    -- 11) Reset lanes 4-6. Lane 7 once earned PERSISTS; lane 8 (commander pass) PERSISTS.
    PlayerData.Plot.Unlocks.Slot4 = false
    PlayerData.Plot.Unlocks.Slot5 = false
    PlayerData.Plot.Unlocks.Slot6 = false

    -- 12) Clear timed boosts. Permanent boosts (Boosts.Permanent) are untouched.
    PlayerData.Boosts.Active = {}

    -- 13) Apply the permanent boost via BoostManager (each boost type has one permanent slot
    --     and each type can only be picked once across rebirths, so simple assignment is safe).
    BoostManager.AddPermanentBoost(PlayerData, BoostConfig.Type, BoostConfig.Amount)

    -- 14) Mark the picked options as consumed so they vanish from the next rebirth pool
    PlayerData.Rebirth.PickedSoldiers[SoldierType] = true
    PlayerData.Rebirth.PickedBoosts[BoostConfig.Type] = true

    -- 15) Reset credits to the starting value AFTER paying the cost (clean-slate per design)
    PlayerData.leaderstats.Credits = SETTINGS.REBIRTH_CONFIG.StartingCredits

    -- 16) Bump rebirth counters
    PlayerData.Rebirths = CurrentRebirths + 1
    if not PlayerData.Stats then PlayerData.Stats = {} end
    PlayerData.Stats.HighestRebirth = math.max(PlayerData.Stats.HighestRebirth or 0, PlayerData.Rebirths)

    -- 17) Single atomic write
    Data.Set(Player, PlayerData)

    -- 18) Rebuild boost cache (Boosts.Permanent changed) and notify client of the new active state
    BoostManager.RebuildCacheForPlayer(Player)
    BoostManager.NotifyClient(Player)

    -- 19) Re-target unlocked lanes so visuals respawn on the reset plot
    if PlotManager and PlotManager.SetTarget then
        PlotManager:SetTarget("Target1")
    end

    -- 20) Refresh every collect pad for the new lane layout.
    --     Now-locked lanes (4-6 after the reset) get fully hidden via PlotManager:SetCollectPadVisible
    --     (parts go transparent + every BillboardGui Enabled=false + idle emitter off).
    --     Lanes that are still unlocked get a UpdateCollectPad fire with $0 so their CashToCollectGui
    --     reflects the drained state. We intentionally skip the fire for locked lanes because the
    --     client's OnUpdateCollectPad sets CashToCollectGui.Enabled=true unconditionally — firing it
    --     for a locked lane would re-show its label.
    if PlotManager and PlotManager.SetCollectPadVisible then
        for Lane = 1, TOTAL_LANES do
            local Unlocked = PlayerData.Plot.Unlocks["Slot" .. Lane] == true
            PlotManager:SetCollectPadVisible(Lane, Unlocked)
            if Unlocked then
                UpdateCollectPadEvent:FireClient(Player, Lane, 0)
            end
        end
    end

    -- 21) Start in-memory tree generation timers for any tree slots that just unlocked
    BoostManager.RefreshTreeTimers(Player, PlayerData)

    -- 22) Push fresh data so every client UI rebuilds (inventory, lanes, credits, etc.)
    LoadPlayerEvent:FireClient(Player, PlayerData, "Rebirth")

    return true, "Rebirthed"
end

return RebirthManager
