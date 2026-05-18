-- BoostManager, initialized by KingCreoo
-- Manages all player boost state: timed active boosts, permanent boosts, and boost tree slots.

local BoostManager = {}

-- // Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Players = game:GetService("Players")

-- // Modules
local SETTINGS = require(ReplicatedStorage:WaitForChild("Settings"))
-- Data is required at top level — no circular risk since Data does not require BoostManager.
local Data = require(ServerScriptService:WaitForChild("Server"):WaitForChild("Data"))

-- // Variables
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

-- In-memory state (all keyed by Player.Name)
local EffectiveMultipliers = {}  -- [PlayerName][BoostType] = effective multiplier (1 = no boost)
local ActivePlayers = {}         -- [PlayerName] = true
local TreeTimers = {}            -- [PlayerName][SlotKey] = tick() when generation started

-- // Helpers

-- Ensures a RemoteEvent exists in Remotes (creates it if missing, same pattern as init.server)
local function EnsureRemote(Name: string, Class: string): Instance
    local Existing = Remotes:FindFirstChild(Name)
    if Existing and Existing:IsA(Class) then return Existing end
    local R = Instance.new(Class)
    R.Name = Name
    R.Parent = Remotes
    return R
end

local UpdateBoostsEvent: RemoteEvent    = EnsureRemote("UpdateBoosts",    "RemoteEvent")
local UpdateBoostTreeEvent: RemoteEvent = EnsureRemote("UpdateBoostTree", "RemoteEvent")

-- // Private functions

-- Rebuilds the effective multiplier cache for a player from their current PlayerData.
-- Must be called after any mutation to Boosts.Active or Boosts.Permanent.
local function RebuildCache(Player: Player)
    local PlayerData = Data.Get(Player)
    if not PlayerData then return end

    local Now = os.time()
    local Cache = {}

    for _, BoostType in ipairs(SETTINGS.BOOST_TYPES) do
        -- Permanent floor (from rebirths). Defaults to 1 (no boost) if not set.
        local PermAmount = PlayerData.Boosts.Permanent[BoostType] or 1

        -- Timed boost on top of permanent. Only counts if not expired.
        local ActiveEntry = PlayerData.Boosts.Active[BoostType]
        local TimedAmount = (ActiveEntry and ActiveEntry.ExpiresAt > Now) and ActiveEntry.Amount or 1

        Cache[BoostType] = PermAmount * TimedAmount
    end

    EffectiveMultipliers[Player.Name] = Cache
end

-- Walks Boosts.Active and removes any entries whose ExpiresAt has passed.
-- Pure mutation — caller is responsible for Data.Set and RebuildCache.
-- Returns true if any entry was removed.
local function MutPurgeExpired(PlayerData: table): boolean
    local Now = os.time()
    local Changed = false
    for BoostType, Entry in pairs(PlayerData.Boosts.Active) do
        if Entry.ExpiresAt <= Now then
            PlayerData.Boosts.Active[BoostType] = nil
            Changed = true
        end
    end
    return Changed
end

-- Core merge logic for a single boost type. Pure mutation — no Data.Set.
-- ExpiresAt is an absolute os.time() timestamp.
-- When two boosts of the same type collide, the higher-amount one wins.
-- The lower is converted to bonus time on the winner using the confirmed stacking formula.
local function MutMergeBoost(PlayerData: table, BoostType: string, Amount: number, ExpiresAt: number, Source: string)
    -- A 1x boost is a no-op and would cause division by zero in merge math.
    if Amount <= 1 then return end

    local Now = os.time()
    local Existing = PlayerData.Boosts.Active[BoostType]

    local WinnerAmount, WinnerExpiry

    if Existing and Existing.ExpiresAt > Now then
        local ExistingRemaining = Existing.ExpiresAt - Now
        local IncomingDuration  = ExpiresAt - Now

        if Amount >= Existing.Amount then
            -- Incoming wins. Convert existing remaining time to bonus on the incoming.
            local BonusTime = ExistingRemaining * (Existing.Amount - 1) / (Amount - 1)
            WinnerAmount = Amount
            WinnerExpiry = ExpiresAt + BonusTime
        else
            -- Existing wins. Convert incoming duration to bonus on the existing.
            local BonusTime = IncomingDuration * (Amount - 1) / (Existing.Amount - 1)
            WinnerAmount = Existing.Amount
            WinnerExpiry = Existing.ExpiresAt + BonusTime
        end
    else
        -- No live existing boost for this type — just set it directly.
        WinnerAmount = Amount
        WinnerExpiry = ExpiresAt
    end

    PlayerData.Boosts.Active[BoostType] = {
        Amount    = WinnerAmount,
        ExpiresAt = math.floor(WinnerExpiry),
        Source    = Source,
    }
end

-- Builds a clean table of non-expired active boosts for the client.
-- Strips the Source field (server-internal) and skips expired entries.
local function GetActiveBoostsForClient(PlayerData: table): table
    local Now = os.time()
    local Result = {}
    for BoostType, Entry in pairs(PlayerData.Boosts.Active) do
        if Entry.ExpiresAt > Now then
            Result[BoostType] = { Amount = Entry.Amount, ExpiresAt = Entry.ExpiresAt }
        end
    end
    return Result
end

-- 5-second server loop. Checks all active players for:
--   1) Expired active boosts (purge + rebuild cache + notify client)
--   2) Tree slots that have finished generating (generate PendingBoost + persist + notify client)
local function StartServerLoop()
    task.spawn(function()
        while true do
            task.wait(5)

            for PlayerName in pairs(ActivePlayers) do
                local Player = Players:FindFirstChild(PlayerName)
                if not Player then continue end

                local PlayerData = Data.Get(Player)
                if not PlayerData then continue end

                local Dirty = false

                -- 1) Purge any active boosts that expired while the player was online
                if MutPurgeExpired(PlayerData) then
                    Dirty = true
                end

                -- 2) Check each boost tree slot for generation completion
                local ReadySlots = {}
                local Now = tick()
                local Rebirths = PlayerData.Rebirths or 0

                for i = 1, 3 do
                    local SlotKey = "Slot" .. i
                    local SlotConfig = SETTINGS.BOOST_TREE[SlotKey]
                    local SlotData = PlayerData.BoostTree and PlayerData.BoostTree[SlotKey]
                    if not SlotData then continue end

                    -- Skip locked slots (rebirth prereq not met)
                    if Rebirths < SlotConfig.RebirthRequired then continue end
                    -- Skip slots that already have a ready boost waiting to be claimed
                    if SlotData.PendingBoost then continue end
                    -- Skip slots with no active timer (not yet started this session)
                    local TimerStart = TreeTimers[PlayerName] and TreeTimers[PlayerName][SlotKey]
                    if not TimerStart then continue end

                    -- Check if generation time has elapsed
                    if Now >= TimerStart + SlotConfig.GenerationSeconds then
                        local BoostTypeIndex = math.random(1, #SETTINGS.BOOST_TYPES)
                        local PendingBoost = {
                            Type     = SETTINGS.BOOST_TYPES[BoostTypeIndex],
                            Amount   = SlotConfig.BoostAmount,
                            Duration = SlotConfig.BoostDuration,
                        }
                        PlayerData.BoostTree[SlotKey].PendingBoost = PendingBoost
                        table.insert(ReadySlots, { Slot = SlotKey, Boost = PendingBoost })
                        Dirty = true
                    end
                end

                if Dirty then
                    Data.Set(Player, PlayerData, true)
                    RebuildCache(Player)
                    UpdateBoostsEvent:FireClient(Player, GetActiveBoostsForClient(PlayerData))
                end

                -- Notify client of each newly ready slot (separate from the boost state update)
                for _, Info in ipairs(ReadySlots) do
                    UpdateBoostTreeEvent:FireClient(Player, Info.Slot, Info.Boost)
                end
            end
        end
    end)
end

-- // Public API

-- Called on player join (before RewardLoop.SetupPlayer). Initializes cache and tree timers.
-- Purges any boosts that expired while the player was offline.
function BoostManager.SetupPlayer(Player: Player, PlayerData: table)
    ActivePlayers[Player.Name] = true
    EffectiveMultipliers[Player.Name] = {}
    TreeTimers[Player.Name] = {}

    -- Purge boosts that expired offline and persist the cleaned data
    local Purged = MutPurgeExpired(PlayerData)
    if Purged then
        Data.Set(Player, PlayerData, true)
    end

    -- Build the effective multiplier cache from the cleaned data
    RebuildCache(Player)

    -- Start generation timers for all unlocked, non-ready slots
    local Rebirths = PlayerData.Rebirths or 0
    for i = 1, 3 do
        local SlotKey = "Slot" .. i
        local SlotConfig = SETTINGS.BOOST_TREE[SlotKey]
        local SlotData = PlayerData.BoostTree and PlayerData.BoostTree[SlotKey]
        if not SlotData then continue end
        if Rebirths < SlotConfig.RebirthRequired then continue end  -- locked
        if SlotData.PendingBoost then continue end                  -- already ready to claim
        TreeTimers[Player.Name][SlotKey] = tick()                   -- start generating now
    end
end

-- Called on player leave. Clears all in-memory state for this player.
function BoostManager.CleanupPlayer(PlayerName: string)
    ActivePlayers[PlayerName] = nil
    EffectiveMultipliers[PlayerName] = nil
    TreeTimers[PlayerName] = nil
end

-- Adds a timed boost for a player. Server-side only — never exposed via client remote.
-- Validates the boost type, merges with any existing boost of the same type, saves, and notifies client.
-- Returns true on success, false on validation failure.
function BoostManager.AddBoost(Player: Player, BoostType: string, Amount: number, DurationSeconds: number, Source: string): boolean
    -- Validate boost type against the known list
    local Valid = false
    for _, T in ipairs(SETTINGS.BOOST_TYPES) do
        if T == BoostType then Valid = true; break end
    end
    if not Valid then
        warn("[BoostManager] Unknown boost type: " .. tostring(BoostType))
        return false
    end

    local PlayerData = Data.Get(Player)
    if not PlayerData then return false end

    MutMergeBoost(PlayerData, BoostType, Amount, os.time() + DurationSeconds, Source)
    Data.Set(Player, PlayerData)
    RebuildCache(Player)
    UpdateBoostsEvent:FireClient(Player, GetActiveBoostsForClient(PlayerData))
    return true
end

-- Pure mutation for use inside ProductConfig OnGrant callbacks.
-- No Data.Set — the caller (TransactionManager/ProductConfig) handles the atomic save.
-- After calling this, the caller must invoke RebuildCache if the player is mid-session.
function BoostManager.MergeActiveBoost(PlayerData: table, BoostType: string, Amount: number, ExpiresAt: number, Source: string)
    MutMergeBoost(PlayerData, BoostType, Amount, ExpiresAt, Source)
end

-- Adds a permanent boost from a rebirth. No Data.Set — RebirthManager handles the atomic save.
-- Overwrites any existing permanent boost of the same type (each type has one permanent slot).
function BoostManager.AddPermanentBoost(PlayerData: table, BoostType: string, Amount: number)
    PlayerData.Boosts.Permanent[BoostType] = Amount
end

-- Starts in-memory generation timers for any tree slots that became newly unlocked
-- (e.g. after a rebirth). Idempotent — slots that are still locked, already ready,
-- or already timing keep their current state. Caller must already hold a session
-- entry for the player (BoostManager.SetupPlayer must have run).
function BoostManager.RefreshTreeTimers(Player: Player, PlayerData: table)
    local Timers = TreeTimers[Player.Name]
    if not Timers then return end

    local Rebirths = PlayerData.Rebirths or 0
    for i = 1, 3 do
        local SlotKey = "Slot" .. i
        local SlotConfig = SETTINGS.BOOST_TREE[SlotKey]
        local SlotData = PlayerData.BoostTree and PlayerData.BoostTree[SlotKey]
        if not SlotData then continue end
        if Rebirths < SlotConfig.RebirthRequired then continue end -- still locked
        if SlotData.PendingBoost then continue end                 -- already ready to claim
        if Timers[SlotKey] then continue end                       -- already generating this session
        Timers[SlotKey] = tick()
        -- Tell the client this slot transitioned from Locked -> Generating
        UpdateBoostTreeEvent:FireClient(Player, SlotKey, false)
    end
end

-- Hot-path read used by RewardLoop Heartbeat. Falls back to 1 (no boost) if not set up.
function BoostManager.GetCachedMultiplier(PlayerName: string, BoostType: string): number
    local PlayerCache = EffectiveMultipliers[PlayerName]
    if not PlayerCache then return 1 end
    return PlayerCache[BoostType] or 1
end

-- Rebuilds the cache for a player after an external mutation (e.g. ProductConfig OnGrant).
-- Only needed when the player is mid-session and the caller mutated PlayerData directly.
function BoostManager.RebuildCacheForPlayer(Player: Player)
    RebuildCache(Player)
end

-- Sends the current active boost state to the client. Used after ProductConfig grants a boost.
function BoostManager.NotifyClient(Player: Player)
    local PlayerData = Data.Get(Player)
    if not PlayerData then return end
    UpdateBoostsEvent:FireClient(Player, GetActiveBoostsForClient(PlayerData))
end

-- Validates and applies a boost tree slot claim. Called from init.server.luau.
-- Returns (success: boolean, reason: string).
function BoostManager.ClaimBoostTreeSlot(Player: Player, SlotNumber: any): (boolean, string)
    -- Validate slot number
    if type(SlotNumber) ~= "number" or SlotNumber < 1 or SlotNumber > 3 then
        return false, "Invalid"
    end

    local SlotKey = "Slot" .. SlotNumber
    local SlotConfig = SETTINGS.BOOST_TREE[SlotKey]

    local PlayerData = Data.Get(Player)
    if not PlayerData then return false, "NoData" end

    -- Rebirth gate
    if (PlayerData.Rebirths or 0) < SlotConfig.RebirthRequired then
        return false, "Locked"
    end

    -- Must have a pending boost ready to claim
    local SlotData = PlayerData.BoostTree and PlayerData.BoostTree[SlotKey]
    local PendingBoost = SlotData and SlotData.PendingBoost
    if not PendingBoost then
        return false, "NotReady"
    end

    -- Apply the pending boost (merge into Active) and clear the slot in one mutation
    MutMergeBoost(
        PlayerData,
        PendingBoost.Type,
        PendingBoost.Amount,
        os.time() + PendingBoost.Duration,
        "BoostTree_" .. SlotKey
    )
    PlayerData.BoostTree[SlotKey].PendingBoost = false

    -- Save, rebuild cache, notify client of new active boost state
    Data.Set(Player, PlayerData)
    RebuildCache(Player)
    UpdateBoostsEvent:FireClient(Player, GetActiveBoostsForClient(PlayerData))

    -- Restart generation timer for this slot
    if not TreeTimers[Player.Name] then TreeTimers[Player.Name] = {} end
    TreeTimers[Player.Name][SlotKey] = tick()

    -- Tell client this slot is now generating again (PendingBoost = false = generating)
    UpdateBoostTreeEvent:FireClient(Player, SlotKey, false)

    return true, "Claimed"
end

-- // Init
StartServerLoop()

return BoostManager
