-- // RewardLoop, initialized on 9-2-2025 by KingCreoo
-- // Manages rewarding the players for their soldiers kills

-- // Define
local RewardLoop = {}

-- // Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

-- // Modules
local SETTINGS = require(ReplicatedStorage:WaitForChild("Settings"))

-- // Variables
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local SetSoldierBindable: BindableEvent = Remotes:WaitForChild("SetSoldierBindable")
local SetTargetBindable: BindableEvent = Remotes:WaitForChild("SetTargetBindable")
local SyncTablesFunction: RemoteFunction = Remotes:WaitForChild("SyncTables")
local FireSoldierEvent: RemoteEvent = Remotes:WaitForChild("FireSoldier")
local ClearSoldierBindable: BindableEvent = Remotes:WaitForChild("ClearSoldierBindable")

local Soldiers = {}
local Targets = {}
local TargetTypes = {}
local Timers = {}
local PendingCash = {}  -- [PlayerName][LaneNum] = number
local DueDeaths = {}
local PlayerPlotNames = {} -- Player.Name -> "Plot1".."Plot6"

local UpdateCollectPadEvent -- resolved lazily to avoid circular require timing issues

-- Returns the workspace plot folder for a given player, or nil if not assigned yet.
local function GetPlotForPlayer(PlayerName: string)
    local PlotName = PlayerPlotNames[PlayerName]
    if not PlotName then return nil end
    return Workspace:WaitForChild("Plots"):FindFirstChild(PlotName)
end

-- // Local Functions

local function OnPlayerRemoving(Player)
    Soldiers[Player.Name] = nil
    Targets[Player.Name] = nil
    TargetTypes[Player.Name] = nil
    Timers[Player.Name] = nil
    DueDeaths[Player.Name] = nil
    PlayerPlotNames[Player.Name] = nil
    task.delay(5, function()
        PendingCash[Player.Name] = nil
    end)
end

-- Fires UpdateCollectPad to the player's client for a specific lane.
local function NotifyCollectPad(Player: Player, LaneNum: number)
    if not UpdateCollectPadEvent then
        UpdateCollectPadEvent = game:GetService("ReplicatedStorage"):WaitForChild("Remotes"):WaitForChild("UpdateCollectPad")
    end
    local Amount = PendingCash[Player.Name] and PendingCash[Player.Name][LaneNum] or 0
    UpdateCollectPadEvent:FireClient(Player, LaneNum, Amount)
end

local function CalculateTimeToHit(Plot: Instance, BulletSpeed: number)
    -- New map: distance derived from SoldierSpawn1 -> TargetSpawn1 in plot.Spawns.
    -- TODO: per-lane variance if lane lengths ever differ.
    local Spawns = Plot:FindFirstChild("Spawns")
    if not Spawns then return 0 end
    local SoldierSpawn = Spawns:FindFirstChild("SoldierSpawn1")
    local TargetSpawn = Spawns:FindFirstChild("TargetSpawn1")
    if not SoldierSpawn or not TargetSpawn then return 0 end

    local Distance = (TargetSpawn.Position - SoldierSpawn.Position).Magnitude
    return Distance / BulletSpeed
end

local function AddReward(InfoTable: table)
    local PlayerName = InfoTable.PlayerName
    local Slot = InfoTable.SoldierData.Slot

    -- 0) Check that this target is still applied
    if TargetTypes[PlayerName] ~= Targets[PlayerName][Slot].Type then
        return
    end

    -- 1) Mark target as dead
    Targets[PlayerName][Slot].State = "Dead"

    -- 2) Calculate and add reward to this lane's pending cash bucket
    local TargetType = Targets[PlayerName][Slot].Type
    local RewardAmount = SETTINGS["TARGET_DATA"][TargetType]["Reward"]
    local LaneNum = tonumber(string.sub(Slot, 5))
    if LaneNum then
        PendingCash[PlayerName][LaneNum] = (PendingCash[PlayerName][LaneNum] or 0) + RewardAmount
        -- Notify client to update this lane's collect pad display
        local Player = game:GetService("Players"):FindFirstChild(PlayerName)
        if Player then
            NotifyCollectPad(Player, LaneNum)
        end
    end

    -- 3) Schedule respawn
    local RespawnTime = SETTINGS["TARGET_DATA"][TargetType]["TotalRespawnTime"]
    task.delay(RespawnTime, function()
        Targets[PlayerName][Slot].State = "Alive"
        Targets[PlayerName][Slot].Health = SETTINGS["TARGET_DATA"][TargetType]["TotalHealth"]
    end)
end

-- Applies damage and handles death/reward logic for a single bullet
local function ApplyBulletDamage(InfoTable: table, WeaponInfo: table)
	local Damage = WeaponInfo["Damage"]
	local CurrentHealth = Targets[InfoTable.PlayerName][InfoTable.SoldierData.Slot]["Health"]

	-- Set damage
	Targets[InfoTable.PlayerName][InfoTable.SoldierData.Slot].Health = CurrentHealth - Damage

	-- If the target died, give rewards at the right time
	if CurrentHealth - Damage <= 0 and Targets[InfoTable.PlayerName][InfoTable.SoldierData.Slot].State == "Alive" then
		DueDeaths[InfoTable.PlayerName][InfoTable.SoldierData.Slot] = true
		local BulletSpeed = WeaponInfo["BulletSpeed"]
		local TimeToHit = CalculateTimeToHit(GetPlotForPlayer(InfoTable.PlayerName), BulletSpeed)
		task.delay(TimeToHit, function()
			AddReward(InfoTable)
			task.delay(SETTINGS["TARGET_DATA"][TargetTypes[InfoTable.PlayerName]]["TotalRespawnTime"], function()
				DueDeaths[InfoTable.PlayerName][InfoTable.SoldierData.Slot] = false
			end)
		end)
	end
end

local function FireSoldiers(SoldiersToFire)
	for _, InfoTable in pairs(SoldiersToFire) do
		local WeaponType = SETTINGS["SOLDIER_DATA"][InfoTable.SoldierData.Type]["WeaponType"]
		local WeaponInfo = SETTINGS["SOLDIER_DATA"][InfoTable.SoldierData.Type]["WeaponInfo"]

		if WeaponType == "Burst" then
			-- Fire multiple bullets with delays
			for i = 1, WeaponInfo.Bullets do
				-- Check if target already dead from previous bullet
				local TargetData = Targets[InfoTable.PlayerName][InfoTable.SoldierData.Slot]
				local IsNullBullet = TargetData.State ~= "Alive" or DueDeaths[InfoTable.PlayerName][InfoTable.SoldierData.Slot] == true
				InfoTable.SoldierData.NullBullet = IsNullBullet
				
				-- Send current target health to client for sync
				InfoTable.SoldierData.TargetHealth = TargetData.Health

				FireSoldierEvent:FireClient(Players:FindFirstChild(InfoTable.PlayerName), InfoTable)

				if not IsNullBullet then
					ApplyBulletDamage(InfoTable, WeaponInfo)
				end

				if i < WeaponInfo.Bullets then
					task.wait(WeaponInfo.DelayBetweenBullets)
				end
			end
		elseif WeaponType == "Dual" then
			-- Fire 2 bullets from alternating fire points
			for i = 1, 2 do
				InfoTable.SoldierData.FirePointIndex = i

				-- Check if target already dead from previous bullet
				local TargetData = Targets[InfoTable.PlayerName][InfoTable.SoldierData.Slot]
				local IsNullBullet = TargetData.State ~= "Alive" or DueDeaths[InfoTable.PlayerName][InfoTable.SoldierData.Slot] == true
				InfoTable.SoldierData.NullBullet = IsNullBullet
				
				-- Send current target health to client for sync
				InfoTable.SoldierData.TargetHealth = TargetData.Health

				FireSoldierEvent:FireClient(Players:FindFirstChild(InfoTable.PlayerName), InfoTable)

				if not IsNullBullet then
					ApplyBulletDamage(InfoTable, WeaponInfo)
				end

				if i < 2 then
					task.wait(WeaponInfo.DelayBetweenBullets)
				end
			end
		else
			-- Auto/Shotgun: fire once, client handles visuals
			local TargetData = Targets[InfoTable.PlayerName][InfoTable.SoldierData.Slot]
			InfoTable.SoldierData.TargetHealth = TargetData.Health
			
			FireSoldierEvent:FireClient(Players:FindFirstChild(InfoTable.PlayerName), InfoTable)
			ApplyBulletDamage(InfoTable, WeaponInfo)
		end
	end
end

local function SoldierPromise(PlayerName, SoldierID, SoldierData)
    local Promise = require(game:GetService("ReplicatedStorage").Settings.Promise)

    SoldierData.Spawning = true
    Soldiers[PlayerName][SoldierID] = SoldierData

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
        end
    end):catch(function()
        if SoldierData then
            Soldiers[PlayerName][SoldierID] = nil
            Timers[PlayerName][SoldierID] = nil
            SoldierData.Spawning = nil
            SoldierData.SpawnReject = nil
        end
    end)
end

-- // Module Functions

-- Returns the full per-lane pending cash dict for saving on logoff.
function RewardLoop.GetPendingCash(PlayerName: string)
    return PendingCash[PlayerName] or {}
end

-- Returns total pending cash across all lanes (used by IdleRewards lump sum).
function RewardLoop.GetTotalPendingCash(PlayerName: string)
    local Total = 0
    if PendingCash[PlayerName] then
        for _, Amount in pairs(PendingCash[PlayerName]) do
            Total += Amount
        end
    end
    return Total
end

function RewardLoop.ClearSoldier(PlayerName: string, Slot: string)
    -- 0) Check if player exists in tables
    if not Soldiers[PlayerName] then return end

    -- 1) Find and remove soldier in specified slot
    local SoldierIDToRemove
    for ExistingSoldierID, ExistingSoldierData in pairs(Soldiers[PlayerName]) do
        if ExistingSoldierData.Slot == Slot then
            SoldierIDToRemove = ExistingSoldierID
            break
        end
    end

    if SoldierIDToRemove then
        -- Check for promises
        local TargetSoldierData = Soldiers[PlayerName][SoldierIDToRemove]
        if TargetSoldierData and TargetSoldierData.SpawnReject then
            TargetSoldierData.Cancelled = true
            TargetSoldierData.SpawnReject()
        end
        
        Soldiers[PlayerName][SoldierIDToRemove] = nil
        Timers[PlayerName][SoldierIDToRemove] = nil
    end

    -- No reindexing: slots are positional dict keys, gaps are valid.
end

function RewardLoop.SetSoldier(PlayerName: string, Slot: string, SoldierID: string, SoldierData: table)
    -- 0) If the player doesn't have tables yet for whatever reason, we set them
    if not Soldiers[PlayerName] then
        Soldiers[PlayerName] = {}
        Targets[PlayerName] = {}
        TargetTypes[PlayerName] = ""
        PendingCash[PlayerName] = {}
        DueDeaths[PlayerName] = {}
    end

    -- 1) Remove existing soldier in that slot
    for ExistingSoldierID, ExistingSoldierData in pairs(Soldiers[PlayerName]) do
        if ExistingSoldierData.Slot == Slot then
            Soldiers[PlayerName][ExistingSoldierID] = nil
            Timers[PlayerName][ExistingSoldierID] = nil
            break
        end
    end

    -- 2) Add new soldier
    SoldierData.Slot = Slot
    SoldierPromise(PlayerName, SoldierID, SoldierData)
end

function RewardLoop.SetTarget(PlayerName: string, UnlockedLanes: table, TargetType: string)
    -- 1) Clear existing targets, and set new type
    Targets[PlayerName] = {}
    TargetTypes[PlayerName] = TargetType

    -- 2) Create new targets for each unlocked lane
    for _, SlotName in pairs(UnlockedLanes) do
        Targets[PlayerName][SlotName] = {
            Health = SETTINGS["TARGET_DATA"][TargetType]["TotalHealth"],
            State = "Alive",
            Type = TargetType
        }
    end
end

function RewardLoop.SetupPlayer(Player, PlayerData)
    Soldiers[Player.Name] = {}
    Targets[Player.Name] = {}
    TargetTypes[Player.Name] = ""
    Timers[Player.Name] = {}
    DueDeaths[Player.Name] = {}
    -- Restore per-lane pending cash from saved data (or start fresh)
    PendingCash[Player.Name] = {}
    if PlayerData["PendingCash"] then
        for Lane, Amount in pairs(PlayerData["PendingCash"]) do
            PendingCash[Player.Name][tonumber(Lane)] = Amount
        end
    end
end

-- Stores the player's plot name so RewardLoop can resolve the workspace folder.
-- Called from init.server after plot assignment, before SetupRewards.
function RewardLoop.SetPlotName(PlayerName: string, PlotName: string)
    PlayerPlotNames[PlayerName] = PlotName
end

function RewardLoop.SetupRewards(Player)
    -- Collect pad GUIs are driven client-side; nothing to set up server-side here.
end

function RewardLoop.Init()
    RunService.Heartbeat:Connect(function()
        -- 1) Get time and set variables
        local CurrentTime = tick()
        local ReadyToFire = {}

        -- 2) Run loop for each player
        for PlayerName, PlayerSoldiers in pairs(Soldiers) do
            for SoldierID, SoldierData in pairs(PlayerSoldiers) do
                -- 0) Check if target is alive
                if not Targets[PlayerName][SoldierData.Slot] or Targets[PlayerName][SoldierData.Slot].State ~= "Alive" then
                    continue
                end

                -- Check if the target is due to die
                if DueDeaths[PlayerName][SoldierData.Slot] == true then
                    continue
                end

                -- Check to see if the soldier is spawning, if so we skip
                if SoldierData.Spawning then
                    continue
                end

                -- 1) Get soldier's base stats
                local SoldierStats = SETTINGS["SOLDIER_DATA"][SoldierData.Type]
                if not SoldierStats then continue end
                local BaseFireRate = SoldierStats["WeaponInfo"]["FireRate"]

                -- 2) Get any boosts
                -- TODO get boosts
                local AbsoluteFireRate = BaseFireRate -- + BOOSTS

                -- 3) Check if this soldier has a timer entry, if not create one
                if not Timers[PlayerName][SoldierID] then
                    Timers[PlayerName][SoldierID] = CurrentTime + AbsoluteFireRate
                end

                -- 4) Check if ready to fire
                if CurrentTime >= Timers[PlayerName][SoldierID] then
                    -- 4a) If yes, then add the soldier to ReadyToFire and prep the next fire time
                    table.insert(ReadyToFire, {
                        SoldierID = SoldierID,
                        PlayerName = PlayerName,
                        SoldierData = SoldierData
                    })
                    Timers[PlayerName][SoldierID] = CurrentTime + AbsoluteFireRate
                end
            end
        end

        -- Batch animate if any ready
        if #ReadyToFire > 0 then
            task.spawn(FireSoldiers, ReadyToFire)
        end
    end)
end

-- Claims pending cash for a specific lane. Called when player steps on that lane's collect pad.
function RewardLoop.ClaimRewards(Player: Player, LaneNum: number)
    if not PendingCash[Player.Name] then return end
    local Amount = PendingCash[Player.Name][LaneNum] or 0
    if Amount <= 0 then return end

    local Data = require(script.Parent.Data)
    local PlayerData = Data.Get(Player)

    PlayerData["leaderstats"]["Credits"] += Amount
    PendingCash[Player.Name][LaneNum] = 0
    if not PlayerData["PendingCash"] then PlayerData["PendingCash"] = {} end
    PlayerData["PendingCash"][LaneNum] = 0

    Data.Set(Player, PlayerData)

    -- Tell client this lane's pad is now empty
    NotifyCollectPad(Player, LaneNum)
end

function RewardLoop.SyncTables()
    return Soldiers, Targets, Timers, PendingRewards
end

-- // Events
Players.PlayerRemoving:Connect(OnPlayerRemoving)
SetSoldierBindable.Event:Connect(function(PlayerName: string, Slot: string, SoldierID: string, SoldierData: table)
    RewardLoop.SetSoldier(PlayerName, Slot, SoldierID, SoldierData)
end)
SetTargetBindable.Event:Connect(function(PlayerName: string, UnlockedLanes: table, TargetType: string)
    RewardLoop.SetTarget(PlayerName, UnlockedLanes, TargetType)
end)
SyncTablesFunction.OnServerInvoke = function()
    return RewardLoop.SyncTables()
end
ClearSoldierBindable.Event:Connect(function(PlayerName: string, Slot: string)
    RewardLoop.ClearSoldier(PlayerName, Slot)
end)

-- // Return
return RewardLoop