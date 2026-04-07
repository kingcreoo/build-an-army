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

-- // Variables
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local IdleRewardsEvent: RemoteEvent = Remotes:WaitForChild("IdleRewards")

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

-- Calculates if player is valid for rewards & assigns rewards to valid players
function IdleRewards.OnPlayerAdded(Player: Player, PlayerData: table)
    -- 1) PRE CHECKS

    -- 1a)
    if not PlayerData["LogOff"] then return end

    -- 1b)
    if #PlayerData["Inventory"]["ActiveSoldiers"] <= 0 then return end

    -- 1c)
    if PlayerData["Inventory"]["ActiveTarget"] == nil then return end

    -- 2) Get player's timings
    local LogOffTime = PlayerData["LogOff"]
    local CurrentTime = os.time()
    local RawTimeAway = CurrentTime - LogOffTime

    -- If player was away for less than the minimum threshold, skip
    if RawTimeAway < Settings.IDLE_CONFIG.MinTimeAway then return end

    -- 2a) Clamp player's away time to Commander or free-tier cap
    local HasVIP = false -- TODO check Commander Pass ownership via TransactionManager
    local MaxTime = HasVIP and Settings.IDLE_CONFIG.CommanderCap or Settings.IDLE_CONFIG.FreeCap
    local ClampedTimeAway = math.min(RawTimeAway, MaxTime)

    -- 3) Calculate raw live-equivalent rewards, then apply idle rate multiplier
    local PlayerRewards = CalculateRewards(PlayerData, ClampedTimeAway)
    local RateMultiplier = HasVIP and Settings.IDLE_CONFIG.CommanderRate or Settings.IDLE_CONFIG.FreeRate
    PlayerRewards = math.floor(PlayerRewards * RateMultiplier)

    -- 4) Store player's rewards in the rewards table
    Rewards[Player.Name] = PlayerRewards

    -- 5) Fire client to show rewards GUI frame
    IdleRewardsEvent:FireClient(Player, PlayerRewards, HasVIP, ClampedTimeAway)
end

function IdleRewards.ClaimRewards(Player: Player)
    if not Rewards[Player.Name] then return end

    local PlayerData = Data.Get(Player)

    PlayerData["leaderstats"]["Credits"] += Rewards[Player.Name]
    Rewards[Player.Name] = nil

    Data.Set(Player, PlayerData)
end

-- // Events

IdleRewardsEvent.OnServerEvent:Connect(IdleRewards.ClaimRewards)

-- // Return
return IdleRewards