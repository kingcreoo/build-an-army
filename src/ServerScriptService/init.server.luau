-- // Server, initialized by KingCreoo on 8-19-2025
-- // Manages basic server functions & connectivity

-- // Services
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

-- // Modules
local Data = require(ServerScriptService:WaitForChild("Server"):WaitForChild("Data"))
local Plot = require(ServerScriptService:WaitForChild("Server"):WaitForChild("Plot"))
local SETTINGS = require(ReplicatedStorage:WaitForChild("Settings"))
local RewardLoop = require(ServerScriptService:WaitForChild("Server"):WaitForChild("RewardLoop"))
local IdleRewards = require(ServerScriptService:WaitForChild("Server"):WaitForChild("IdleRewards"))

-- // Variables
local Anchors = Workspace:WaitForChild("Anchors")
local OccupiedAnchors = {}
local PlayerPlotManagers = {}
local CurrentStock
local TimeOfStock
local RecentPurchases = {}

local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local UpdateSettingFunction: RemoteFunction = Remotes:WaitForChild("UpdateSetting")
local RestockEvent: RemoteEvent = Remotes:WaitForChild("Restock")
local GetStockFunction: RemoteFunction = Remotes:WaitForChild("GetStock")
local PurchaseSoldierFunction: RemoteFunction = Remotes:WaitForChild("PurchaseSoldier")
local LoadPlayerEvent: RemoteEvent = Remotes:WaitForChild("LoadPlayer")
local ActivateSoldierFunction: RemoteFunction = Remotes:WaitForChild("ActivateSoldier")
local DeactivateSoldierFunction: RemoteFunction = Remotes:WaitForChild("DeactivateSoldier")
local UpgradeTargetEvent: RemoteEvent = Remotes:WaitForChild("UpgradeTarget")
local SellSoldierEvent: RemoteEvent = Remotes:WaitForChild("SellSoldier")

-- // Functions
local function RNGStock(Rarity)
    if math.random() <= Rarity then
        return math.random(1, 10)
    else
        return 0
    end
end

local function Restock()
    local Stocks = {}
    for _, Type in ipairs(SETTINGS.SHOP_ORDER) do
        Stocks[Type] = RNGStock(SETTINGS.SOLDIER_DATA[Type]["Rarity"])
    end

    RecentPurchases = {}

    return Stocks
end

local function AutoEquip(Player: Player)
    -- 1) Get fresh player data
    local PlayerData = Data.Get(Player)

    -- 2) Check if AutoEquip is enabled
    if not PlayerData["Settings"]["AutoEquip"] then
        return false
    end

    -- 3) Get number of unlocked slots
    local UnlockedSlots = {}
    for i = 1, 7 do
        if PlayerData.Plot.Unlocks["Slot" .. tostring(i)] then
            table.insert(UnlockedSlots, i)
        end
    end
    local MaxSlots = #UnlockedSlots

    -- 4) Get all owned soldiers
    local OwnedSoldiers = {}
    for SoldierID, SoldierData in pairs(PlayerData["Inventory"]["SoldierInventory"]) do
        table.insert(OwnedSoldiers, {
            ID = SoldierID,
            Type = SoldierData.Type
        })
    end

    -- 5) Sort soldiers by rating
    table.sort(OwnedSoldiers, function(a, b)
        local aIndex = table.find(SETTINGS.RATING_ORDER, a.Type)
        local bIndex = table.find(SETTINGS.RATING_ORDER, b.Type)

        return aIndex < bIndex
    end)

    -- 6) Deactive all current soldiers in reverse order
    local PlotManager = PlayerPlotManagers[Player.Name]
    local CurrentlyActive = PlayerData["Inventory"]["ActiveSoldiers"]

    for i = #CurrentlyActive, 1, -1 do
        local SoldierID = CurrentlyActive[i]
        PlotManager:Deactivate(SoldierID)
    end

    -- 7) Active new best soldiers in rating order
    local SlotsToFill = math.min(MaxSlots, #OwnedSoldiers)
    for i = 1, SlotsToFill do
        PlotManager:Activate(OwnedSoldiers[i].ID)
    end

    return true
end

local function CreateSoldier(Type: string)
    local SoldierID = HttpService:GenerateGUID()
    local SoldierData = {["Model"] = Type, ["Type"] = Type}

    return SoldierID, SoldierData
end

local function InjectSoldier(Player: Player, Type: string)
    local PlayerData = Data.Get(Player)

    local SoldierID = HttpService:GenerateGUID()
    local SoldierData = {["Model"] = Type, ["Type"] = Type}

    PlayerData["Inventory"]["SoldierInventory"][SoldierID] = SoldierData
    Data.Set(Player, PlayerData)

    PlayerPlotManagers[Player.Name]:SetSoldier("Slot" .. #PlayerData["Inventory"]["ActiveSoldiers"] + 1, SoldierID)
end

local function InjectTarget(Player: Player, TargetType: string)
	local PlayerData = Data.Get(Player)

	if not PlayerData["Inventory"]["TargetInventory"][TargetType] then
		PlayerData["Inventory"]["TargetInventory"][TargetType] = true
	end

	if PlayerData["Inventory"]["ActiveTarget"] ~= TargetType then
		PlayerPlotManagers[Player.Name]:SetTarget(TargetType)
	end
end

local function PurchaseTarget(Player: Player)
	-- 1) Get player data
	local PlayerData = Data.Get(Player)

	-- 2) Find current target and calculate next target
	local CurrentTarget = PlayerData["Inventory"]["ActiveTarget"]
	local CurrentIndex = table.find(SETTINGS.TARGET_ORDER, CurrentTarget)
	local NextTarget = SETTINGS.TARGET_ORDER[CurrentIndex + 1]

	-- 3) Check if there's a next target to purchase
	if not NextTarget then
		return "Complete", nil
	end

	-- 4) Check if player has sufficient funds
	local Price = SETTINGS.TARGET_DATA[NextTarget].Price
	if PlayerData["leaderstats"]["Credits"] < Price then
		return "Insufficient", nil
	end

	-- 5) Deduct credits
	PlayerData["leaderstats"]["Credits"] -= Price

	-- 6) Add target to inventory
	PlayerData["Inventory"]["TargetInventory"][NextTarget] = true
	Data.Set(Player, PlayerData)

	-- 7) Set the new target as active (this fires SetTargetEvent to all clients)
	PlayerPlotManagers[Player.Name]:SetTarget(NextTarget)

	-- 8) Calculate the next-next target for client display update
	local NextNextTarget = SETTINGS.TARGET_ORDER[CurrentIndex + 2]

	return "Purchased", NextNextTarget
end

local function PurchaseSoldier(Player: Player, Type: string)
    -- 1) Check if the soldier is in stock for this player
    if CurrentStock[Type] <= 0 then return "Stock" end

    if not RecentPurchases[Player.Name] then
        RecentPurchases[Player.Name] = {}
    elseif RecentPurchases[Player.Name][Type] and CurrentStock[Type] - RecentPurchases[Player.Name][Type] <= 0 then
        return "Stock"
    end

    -- 2) Check if player has sufficient funds
    local PlayerData = Data.Get(Player)
    if PlayerData["leaderstats"]["Credits"] < SETTINGS["SOLDIER_DATA"][Type]["Price"] then
        return "Insufficient"
    end

    -- 3) Subtract player funds & stock
    PlayerData["leaderstats"]["Credits"] -= SETTINGS["SOLDIER_DATA"][Type]["Price"]

    if not RecentPurchases[Player.Name][Type] then
        RecentPurchases[Player.Name][Type] = 1
    else
        RecentPurchases[Player.Name][Type] += 1
    end

    -- 4) Add soldier to player's inventory
    local SoldierID, SoldierData = CreateSoldier(Type)
    PlayerData["Inventory"]["SoldierInventory"][SoldierID] = SoldierData
    Data.Set(Player, PlayerData)

    -- Trigger AutoEquip if enabled
    AutoEquip(Player)

    return "Purchased", PlayerData
end

local function InitializeLeaderstats(Player: Player, PlayerData: table)
    local leaderstats = Instance.new("Folder")
    leaderstats.Name = "leaderstats"
    leaderstats.Parent = Player

    for StatName, Value in pairs(PlayerData["leaderstats"]) do
        local Stat = Instance.new(string.upper(string.sub(type(Value), 1, 1)) .. string.sub(type(Value), 2) .. "Value")
        Stat.Name = StatName
        Stat.Value = Value
        Stat.Parent = leaderstats
    end
end

local function AssignPlotAnchor()
    local AssignedAnchor
    for _, Anchor in ipairs(Anchors:GetChildren()) do
        if not table.find(OccupiedAnchors, Anchor) then
            AssignedAnchor = Anchor
            table.insert(OccupiedAnchors, AssignedAnchor)

            return AssignedAnchor
        end
    end
end

local function OnPlayerAdded(Player: Player)
    -- 1) Load player's data
    local PlayerData, NewPlayer = Data.Initialize(Player)
    print(Player.Name .. " has joined. Their data:")
    print(PlayerData)

    -- 1a) Tutorial for new players
    if NewPlayer then
        -- For now, skip lol
        print(Player.Name .. " is a new player. Skipping tutorial.")
    end

    -- 1b) Init player in the rewardloop
    RewardLoop.SetupPlayer(Player, PlayerData)

    -- 1c) Load player's idle rewards
    if PlayerData["LogOff"] then
        IdleRewards.OnPlayerAdded(Player, PlayerData)
    end

    -- 2) Create player's plot
    local PlayerPlot = Plot.new(Player, PlayerData, AssignPlotAnchor())
    PlayerPlotManagers[Player.Name] = PlayerPlot

    -- 3) Initialize player's leaderstats
    InitializeLeaderstats(Player, PlayerData)

    -- 4) Teleport player's character to their plot
    local Character = Player.Character or Player.CharacterAdded:Wait()
    Character:SetPrimaryPartCFrame(PlayerPlot.Plot.Spawn.CFrame + Vector3.new(0, 3, 0))

    -- 5) TODO Present player's offline earnings
    LoadPlayerEvent:FireClient(Player, PlayerData)
end

local function OnPlayerRemoving(Player: Player)
    -- 0) Claim idle rewards if player never did
    IdleRewards.ClaimRewards(Player)

    -- 1) Remove player's data (save & write logoff details too)
    Data.Remove(Player)

    -- 2) Cleanup player's plot (& set vacant)
    local PlayerPlot = PlayerPlotManagers[Player.Name]
    table.remove(OccupiedAnchors, table.find(OccupiedAnchors, PlayerPlot.Anchor))
    PlayerPlot:Cleanup()
    PlayerPlotManagers[Player.Name] = nil
end

local function UpdateSetting(Player: Player, Item: string)
    local PlayerData = Data.Get(Player)

    local CurrentValue = PlayerData["Settings"][Item]

    if SETTINGS.DEFAULT_DATA.Settings[Item] == nil then
      return false, nil, "Error, no settings changed!"
    end

    if CurrentValue then
        PlayerData["Settings"][Item] = false
        Data.Set(Player, PlayerData, true)
        return true, false
    else
        PlayerData["Settings"][Item] = true
        Data.Set(Player, PlayerData, true)

        -- If AutoEquip was just enabled, run it immediately
        if Item == "AutoEquip" then
            AutoEquip(Player)
        end

        return true, true
    end
end

-- Processes a soldier sale request from a player
local function SellSoldier(Player: Player, SoldierID: string)
    -- 1) Get player data
    local PlayerData = Data.Get(Player)

    -- 2) Check soldier exists in inventory
    local SoldierData = PlayerData["Inventory"]["SoldierInventory"][SoldierID]
    if not SoldierData then
        return "NotFound", nil
    end

    -- 3) Check soldier is not active
    for _, ActiveID in pairs(PlayerData["Inventory"]["ActiveSoldiers"]) do
        if ActiveID == SoldierID then
            return "Active", nil
        end
    end

    -- 4) Check soldier is not special
    local SoldierType = SoldierData["Type"]
    if SETTINGS.SOLDIER_DATA[SoldierType]["Special"] then
        return "Special", nil
    end

    -- 5) Get sell value and add credits
    local SellValue = SETTINGS.SOLDIER_DATA[SoldierType]["SellValue"]
    PlayerData["leaderstats"]["Credits"] += SellValue

    -- 6) Remove soldier from inventory
    PlayerData["Inventory"]["SoldierInventory"][SoldierID] = nil

    -- 7) Save data
    Data.Set(Player, PlayerData)

    return "Sold", PlayerData
end

-- // Events & Calling
RewardLoop.Init()
Players.PlayerAdded:Connect(OnPlayerAdded)
Players.PlayerRemoving:Connect(OnPlayerRemoving)

task.spawn(function()
    while true do
        CurrentStock = Restock()
        TimeOfStock = os.time()

        RestockEvent:FireAllClients(CurrentStock, TimeOfStock)

        task.wait(180)
    end
end)

GetStockFunction.OnServerInvoke = function()
    return CurrentStock, TimeOfStock
end

PurchaseSoldierFunction.OnServerInvoke = function(Player: Player, Type: string)
    local Arg1, Arg2 = PurchaseSoldier(Player, Type)

    return Arg1, Arg2
end

ActivateSoldierFunction.OnServerInvoke = function(Player: Player, SoldierID: string)
    local Arg1, Arg2 = PlayerPlotManagers[Player.Name]:Activate(SoldierID)

    return Arg1, Arg2
end

DeactivateSoldierFunction.OnServerInvoke = function(Player: Player, SoldierID: string)
    local Arg1, Arg2 = PlayerPlotManagers[Player.Name]:Deactivate(SoldierID)

    return Arg1, Arg2
end

UpdateSettingFunction.OnServerInvoke = function(Player: Player, Item: string)
	local Arg1, Arg2, Arg3 = UpdateSetting(Player, Item)

	return Arg1, Arg2, Arg3
end

UpgradeTargetEvent.OnServerEvent:Connect(function(Player: Player)
	local Response, NextNextTarget = PurchaseTarget(Player)

	if Response == "Purchased" then
		-- Fire back to client with next target to display (or nil if complete)
		UpgradeTargetEvent:FireClient(Player, NextNextTarget)
	elseif Response == "Insufficient" then
		-- Fire error response back to client
		UpgradeTargetEvent:FireClient(Player, "Insufficient")
	elseif Response == "Complete" then
		-- Fire completion status back to client
		UpgradeTargetEvent:FireClient(Player, "Complete")
	end
end)

SellSoldierEvent.OnServerEvent:Connect(function(Player: Player, SoldierID: string)
	local Response, PlayerData = SellSoldier(Player, SoldierID)
	SellSoldierEvent:FireClient(Player, Response, PlayerData)
end)