-- Idle Rewards, created by Creoo on 11-24-2025
-- Manages calculating and distributing idle rewards

-- // Define
local IdleRewards = {}

-- // Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Players = game:GetService("Players")

-- // Modules
local Settings = require(ReplicatedStorage:WaitForChild("Settings"))
local Data = require(ServerScriptService:WaitForChild("Server"):WaitForChild("Data"))
local RateLimit = require(ServerScriptService:WaitForChild("Server"):WaitForChild("RateLimit"))
local TransactionManager = require(ServerScriptService:WaitForChild("TransactionManager"))

-- // Variables
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local IdleRewardsEvent: RemoteEvent = Remotes:WaitForChild("IdleRewards")
local UpdateCollectPadEvent: RemoteEvent = Remotes:WaitForChild("UpdateCollectPad")

local Rewards = {}

-- // Local Functions

-- Computes how many damage-dealing bullets a soldier fires per trigger pull
-- Mirrors RewardLoop's weapon type branching so online/offline rates match.
-- Shotgun is treated as a slug server-side (Pellets is visual-only), so it returns 1.
local function GetBulletsPerShot(SoldierStats: table): number
    local WeaponType = SoldierStats["WeaponType"]
    local WeaponInfo = SoldierStats["WeaponInfo"]

    if WeaponType == "Burst" then
        return WeaponInfo["Bullets"] or 1
    elseif WeaponType == "Dual" then
        return 2
    end

    return 1
end

local function CalculateRewards(PlayerData: table, TimeAway: number)
    local TotalPossibleRewards = 0

    -- Get player's active setup
    local ActiveSoldiers = PlayerData["Inventory"]["ActiveSoldiers"]
    local SoldierInventory = PlayerData["Inventory"]["SoldierInventory"]
    local ActiveTarget = PlayerData["Inventory"]["ActiveTarget"]

    -- Get target stats
    local TargetData = Settings["TARGET_DATA"][ActiveTarget]
    local TargetHealth = TargetData["TotalHealth"]
    local TargetRespawnTime = TargetData["TotalRespawnTime"]
    local TargetReward = TargetData["Reward"]

    -- Get distance
    local Distance = Settings["DISTANCES"]["Worlds"]["Default"]

    for _, SoldierID in pairs(ActiveSoldiers) do
        local SoldierData = SoldierInventory[SoldierID]

        if SoldierData then
            local SoldierStats = Settings["SOLDIER_DATA"][SoldierData["Type"]]
            if not SoldierStats then
                warn("[IdleRewards] Unknown soldier type: " .. tostring(SoldierData["Type"]) .. ", skipping")
                continue
            end
            local WeaponInfo = SoldierStats["WeaponInfo"]

            -- Account for multi-bullet weapons (Burst fires N, Dual fires 2)
            local EffectiveDamage = WeaponInfo["Damage"] * GetBulletsPerShot(SoldierStats)

            -- Calculate how many shots to kill the target
            local ShotsToKill = math.ceil(TargetHealth / EffectiveDamage)

            -- Time when the last bullet fires
            local LastShotTime = (ShotsToKill - 1) * WeaponInfo["FireRate"]

            -- Calculate travel time for last bullet
            local TravelTime = Distance / WeaponInfo["BulletSpeed"]

            -- Calculate total kill cycle time
            local CycleTime = LastShotTime + TravelTime + TargetRespawnTime

            -- Calculate rewards per second for this soldier, then multiply by time away
            local SoldierRPS = TargetReward / CycleTime
            local SoldierTotal = SoldierRPS * TimeAway

            -- Add total soldier rewards to the running total
            TotalPossibleRewards += SoldierTotal
        end
    end

    return math.floor(TotalPossibleRewards)
end

-- // Module Functions

-- Calculates if player is eligible for idle earnings + folds in uncollected pad cash.
-- Shows the popup if there is anything to collect (idle earnings OR leftover pad cash).
function IdleRewards.OnPlayerAdded(Player: Player, PlayerData: table)
    -- 1) Sum uncollected pad cash from the previous session
    local StoredPending = PlayerData["PendingCash"] or {}
    local TotalPendingCash = 0
    for _, Amount in pairs(StoredPending) do
        TotalPendingCash += Amount
    end

    -- 2) Attempt to calculate idle earnings (requires soldiers, target, and minimum time away)
    local HasVIP = TransactionManager.IsPassOwned(Player, "CommanderPass")
    local ClampedTimeAway = 0
    local IdleEarnings = 0

    local CanEarnIdle = PlayerData["LogOff"]
        and next(PlayerData["Inventory"]["ActiveSoldiers"])
        and PlayerData["Inventory"]["ActiveTarget"] ~= nil

    if CanEarnIdle then
        local RawTimeAway = os.time() - PlayerData["LogOff"]
        if RawTimeAway >= Settings.IDLE_CONFIG.MinTimeAway then
            local MaxTime = HasVIP and Settings.IDLE_CONFIG.CommanderCap or Settings.IDLE_CONFIG.FreeCap
            ClampedTimeAway = math.min(RawTimeAway, MaxTime)
            local RateMultiplier = HasVIP and Settings.IDLE_CONFIG.CommanderRate or Settings.IDLE_CONFIG.FreeRate
            IdleEarnings = math.floor(CalculateRewards(PlayerData, ClampedTimeAway) * RateMultiplier)
        end
    end

    -- 3) Nothing to show if both are zero
    local TotalDisplay = IdleEarnings + TotalPendingCash
    if TotalDisplay <= 0 then return end

    -- 4) Store only idle earnings here; pending cash is paid via GetTotalPendingCash in ClaimRewards
    Rewards[Player.Name] = IdleEarnings

    -- 5) Fire client showing the combined total so the player sees the full picture
    IdleRewardsEvent:FireClient(Player, TotalDisplay, HasVIP, ClampedTimeAway)
end

function IdleRewards.ClaimRewards(Player: Player)
    if not Rewards[Player.Name] then return end

    local PlayerData = Data.Get(Player)
    local RewardLoop = require(ServerScriptService:WaitForChild("Server"):WaitForChild("RewardLoop"))

    local UncollectedCash = RewardLoop.GetTotalPendingCash(Player.Name)
    PlayerData["leaderstats"]["Credits"] += Rewards[Player.Name] + UncollectedCash

    -- Clear pending cash in DataStore, in RewardLoop's in-memory table, and in the popup store
    PlayerData["PendingCash"] = {}
    RewardLoop.ClearPendingCash(Player.Name)
    Rewards[Player.Name] = nil

    Data.Set(Player, PlayerData)

    -- Reset all collect pad labels to $0 on the client so they reflect the claim
    for Lane = 1, 8 do
        UpdateCollectPadEvent:FireClient(Player, Lane, 0)
    end
end

-- // Events

-- 1 idle claim per 10s — this is a one-time-per-session action; repeated fires are spam
IdleRewardsEvent.OnServerEvent:Connect(function(Player: Player)
    if not RateLimit.Check(Player, "IdleRewards", 1, 10) then
        return
    end
    IdleRewards.ClaimRewards(Player)
end)

-- // Return
return IdleRewards