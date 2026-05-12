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
local TransactionManager = require(ServerScriptService:WaitForChild("Server"):WaitForChild("TransactionManager"))
local RateLimit = require(ServerScriptService:WaitForChild("Server"):WaitForChild("RateLimit"))

-- // Variables
local Plots = Workspace:WaitForChild("Plots")
local PLOT_NAMES = {"Plot1", "Plot2", "Plot3", "Plot4", "Plot5", "Plot6"}
local PlotAssignments = {} -- PlotName -> Player
local PlayerPlots = {}     -- Player.Name -> PlotName
local PlayerPlotManagers = {}
local CurrentStock
local TimeOfStock
local RecentPurchases = {}
local SessionStartTimes = {}
local StarterPackOpenStates = {}
local StarterPackTouchCooldowns = {}
local CommanderPassOpenStates = {}
local CommanderPassTouchCooldowns = {}

local Remotes = ReplicatedStorage:WaitForChild("Remotes")

-- Ensures a RemoteEvent exists even when Studio hierarchy is managed manually
local function EnsureRemoteEvent(Name: string): RemoteEvent
    local Existing = Remotes:FindFirstChild(Name)
    if Existing and Existing:IsA("RemoteEvent") then
        return Existing
    end

    local Event = Instance.new("RemoteEvent")
    Event.Name = Name
    Event.Parent = Remotes
    return Event
end

local UpdateSettingFunction: RemoteFunction = Remotes:WaitForChild("UpdateSetting")
local RestockEvent: RemoteEvent = Remotes:WaitForChild("Restock")
local GetStockFunction: RemoteFunction = Remotes:WaitForChild("GetStock")
local PurchaseSoldierFunction: RemoteFunction = Remotes:WaitForChild("PurchaseSoldier")
local LoadPlayerEvent: RemoteEvent = Remotes:WaitForChild("LoadPlayer")
local StarterPackEvent: RemoteEvent = EnsureRemoteEvent("StarterPackEvent")
local CommanderPassEvent: RemoteEvent = EnsureRemoteEvent("CommanderPassEvent")
local ActivateSoldierFunction: RemoteFunction = Remotes:WaitForChild("ActivateSoldier")
local DeactivateSoldierFunction: RemoteFunction = Remotes:WaitForChild("DeactivateSoldier")
local UpgradeTargetEvent: RemoteEvent = Remotes:WaitForChild("UpgradeTarget")
local SellSoldierEvent: RemoteEvent = Remotes:WaitForChild("SellSoldier")
local UnlockSlotEvent: RemoteEvent = Remotes:WaitForChild("UnlockSlot")
local GetPlayerDataFunction: RemoteFunction = Remotes:WaitForChild("GetPlayerData")
local PlotAssignmentEvent: RemoteEvent = EnsureRemoteEvent("PlotAssignment")
local OpenUIEvent: RemoteEvent = EnsureRemoteEvent("OpenUI")
local CloseUIEvent: RemoteEvent = EnsureRemoteEvent("CloseUI")

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

-- Returns the player's saved playtime plus their current session time
local function GetCurrentPlayTime(Player: Player, PlayerData: table): number
    local SavedSeconds = 0
    if PlayerData.Stats and type(PlayerData.Stats.PlayTimeSeconds) == "number" then
        SavedSeconds = PlayerData.Stats.PlayTimeSeconds
    end

    local SessionStart = SessionStartTimes[Player.Name]
    if not SessionStart then
        return SavedSeconds
    end

    return SavedSeconds + math.max(0, os.time() - SessionStart)
end

-- Formats seconds into M:SS for the starter pack timer billboard
local function FormatStarterPackTime(RemainingSeconds: number): string
    local Minutes = math.floor(RemainingSeconds / 60)
    local Seconds = RemainingSeconds % 60
    return string.format("%d:%02d", Minutes, Seconds)
end

-- Removes the starter pack part from a player's plot if it exists
local function RemoveStarterPackPart(Player: Player)
    local PlotManager = PlayerPlotManagers[Player.Name]
    if not PlotManager or not PlotManager.Plot then
        return
    end

    local StarterPackPart = PlotManager.Plot:FindFirstChild("StarterPack")
    if StarterPackPart then
        StarterPackPart:Destroy()
    end
end

local function RemoveCommanderPassPart(Player: Player)
    local PlotManager = PlayerPlotManagers[Player.Name]
    if not PlotManager or not PlotManager.Plot then
        return
    end

    local CommanderPassPart = PlotManager.Plot:FindFirstChild("CommanderPass")
    if CommanderPassPart then
        CommanderPassPart:Destroy()
    end
end

-- Returns true when the player should still see the starter pack offer
local function CanShowStarterPack(Player: Player, PlayerData: table): boolean
    if not PlayerData then
        return false
    end

    if PlayerData.Offers and PlayerData.Offers.StarterPackPurchased then
        return false
    end

    return GetCurrentPlayTime(Player, PlayerData) < SETTINGS.STARTER_PACK.OfferSeconds
end

local function CanShowCommanderPass(Player: Player): boolean
    return not TransactionManager.IsPassOwned(Player, "CommanderPass")
end

-- STUB: Starter pack used to live as a touchable part on the old plot template.
-- New map uses StarterPackRing in InteractionRings; this whole flow needs a rewrite.
-- Disabled for today's redux pass so the server doesn't error referencing nonexistent parts.
local function SetupStarterPack(Player: Player)
    -- TODO: Rewire to StarterPackRing ProximityPrompt + ring on/off toggling
    return
end



-- STUB: Same situation as SetupStarterPack — old "CommanderPass" part is gone.
-- New map uses CommanderPassRing; this needs a rewrite that's out of scope for today.
local function SetupCommanderPass(Player: Player)
    -- TODO: Rewire to CommanderPassRing ProximityPrompt + ownership check
    return
end



local function AutoEquip(Player: Player)
    -- 1) Get fresh player data
    local PlayerData = Data.Get(Player)

    -- 2) Check if AutoEquip is enabled
    if not PlayerData["Settings"]["AutoEquip"] then
        return false
    end

    -- 3) Collect unlocked lane numbers (1-8). Lane 7 = rebirth, lane 8 = commander.
    local UnlockedLanes = {}
    for Lane = 1, 8 do
        if PlayerData.Plot.Unlocks["Slot" .. Lane] then
            table.insert(UnlockedLanes, Lane)
        end
    end

    -- 4) Get all owned soldiers
    local OwnedSoldiers = {}
    for SoldierID, SoldierData in pairs(PlayerData["Inventory"]["SoldierInventory"]) do
        table.insert(OwnedSoldiers, {
            ID = SoldierID,
            Type = SoldierData.Type
        })
    end

    -- 5) Sort soldiers by rating (best first)
    table.sort(OwnedSoldiers, function(a, b)
        local aIndex = table.find(SETTINGS.RATING_ORDER, a.Type)
        local bIndex = table.find(SETTINGS.RATING_ORDER, b.Type)
        return aIndex < bIndex
    end)

    -- 6) Deactivate every currently active soldier (dict iteration; no reindexing).
    local PlotManager = PlayerPlotManagers[Player.Name]
    local CurrentlyActive = PlayerData["Inventory"]["ActiveSoldiers"]
    local IDsToDeactivate = {}
    for _, SoldierID in pairs(CurrentlyActive) do
        table.insert(IDsToDeactivate, SoldierID)
    end
    for _, SoldierID in ipairs(IDsToDeactivate) do
        PlotManager:Deactivate(SoldierID)
    end

    -- 7) Place best soldiers into unlocked lanes in order. Gaps remain gaps.
    local SlotsToFill = math.min(#UnlockedLanes, #OwnedSoldiers)
    for i = 1, SlotsToFill do
        PlotManager:Activate(OwnedSoldiers[i].ID)
    end

    return true
end

-- Resolves which visual model to clone for a given soldier type (falls back to type name if no Model field)
local function ResolveSoldierModel(Type: string): string
    local SoldierEntry = SETTINGS.SOLDIER_DATA[Type]
    return (SoldierEntry and SoldierEntry.Model) or Type
end

local function CreateSoldier(Type: string)
    local SoldierID = HttpService:GenerateGUID()
    local SoldierData = {["Model"] = ResolveSoldierModel(Type), ["Type"] = Type}

    return SoldierID, SoldierData
end

local function InjectSoldier(Player: Player, Type: string)
    local PlayerData = Data.Get(Player)

    local SoldierID = HttpService:GenerateGUID()
    local SoldierData = {["Model"] = ResolveSoldierModel(Type), ["Type"] = Type}

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
    -- 0) Reject unknown types and premium soldiers (premiums go through Robux only)
    local SoldierEntry = SETTINGS["SOLDIER_DATA"][Type]
    if not SoldierEntry or SoldierEntry["Special"] then
        return "Invalid"
    end

    -- 1) Check if the soldier is in stock for this player
    if not CurrentStock[Type] or CurrentStock[Type] <= 0 then return "Stock" end

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

-- Returns the first unoccupied plot name (Plot1-Plot6) or nil if the server is full.
local function AssignPlot(Player: Player): string?
    for _, PlotName in ipairs(PLOT_NAMES) do
        if not PlotAssignments[PlotName] then
            PlotAssignments[PlotName] = Player
            PlayerPlots[Player.Name] = PlotName
            return PlotName
        end
    end
    return nil
end

-- Broadcasts every active plot assignment to one client (used on player join).
local function BroadcastAssignmentsTo(Player: Player)
    for PlotName, OwnerPlayer in pairs(PlotAssignments) do
        if OwnerPlayer and OwnerPlayer.Parent then
            PlotAssignmentEvent:FireClient(Player, OwnerPlayer.Name, PlotName)
        end
    end
end

-- Maps ring model names to UI identifiers sent to the client.
local RING_TO_UI = {
    ["SoldierShopRing"]        = "SoldierShop",
    ["UpgradeTargetRing"]      = "UpgradeTarget",
    ["TrashCanRing"]           = "SellSoldiers",
    ["UnlockLaneRing"]         = "UnlockSlot",
    ["BoostRing"]              = "Boost",
    ["RebirthRing"]            = "Rebirth",
    ["CommanderPassRing"]      = "CommanderPass",
    ["StarterPackRing"]        = "StarterPack",
    ["UnlockRebirthLaneRing"]  = "UnlockRebirthLane",
    ["UnlockCommanderLaneRing"] = "UnlockCommanderLane",
}

-- Positions the UnlockLaneRing at the requested slot using the nearest SoldierSpawn offset.
local function MoveUnlockLaneRingToSlot(PlotFolder: Instance, Ring: Model, SlotNumber: number)
    local Spawns = PlotFolder:FindFirstChild("Spawns")
    if not Spawns then return end

    local RingPivot = Ring:GetPivot()

    local TargetSpawn = Spawns:FindFirstChild("SoldierSpawn" .. SlotNumber)
    if not (TargetSpawn and TargetSpawn:IsA("BasePart")) then return end

    -- Preserve ring rotation, keep original Y, and place at SoldierSpawn X/Z + 8 studs on X.
    local RotationOnly = RingPivot - RingPivot.Position
    local TargetPosition = Vector3.new(TargetSpawn.Position.X - 8, RingPivot.Position.Y, TargetSpawn.Position.Z)
    local TargetCFrame = CFrame.new(TargetPosition) * RotationOnly
    Ring:PivotTo(TargetCFrame)
end

-- Toggles the UnlockLaneRing on/off and updates its price label based on next unlockable slot.
-- Call this on join and after each successful unlock.
local function RefreshUnlockLaneRing(Player: Player, PlotFolder: Instance)
    local PlayerData = Data.Get(Player)
    local Ring = PlotFolder:FindFirstChild("InteractionRings") and PlotFolder.InteractionRings:FindFirstChild("UnlockLaneRing")
    if not Ring then return end

    local GuiParts = Ring:FindFirstChild("GuiParts")
    local Prompt = GuiParts and GuiParts:FindFirstChildOfClass("ProximityPrompt")
    local RingPart = Ring:FindFirstChild("RingPart")
    local FadePart = Ring:FindFirstChild("FadePart")
    local PriceGui = GuiParts and GuiParts:FindFirstChild("Price")
    local LabelGui = GuiParts and GuiParts:FindFirstChild("Label")

    -- Find next credit-purchasable slot (4-6)
    local NextSlot = nil
    for i = 4, 6 do
        if not PlayerData.Plot.Unlocks["Slot" .. i] then
            NextSlot = i
            break
        end
    end

    local Visible = NextSlot ~= nil

    if Visible and NextSlot then
        MoveUnlockLaneRingToSlot(PlotFolder, Ring, NextSlot)
    end

    -- Toggle ring visibility
    if Prompt then Prompt.Enabled = Visible end
    if RingPart then RingPart.Transparency = Visible and 0 or 1 end
    if FadePart then
        local Decal = FadePart:FindFirstChildOfClass("Decal")
        if Decal then Decal.Transparency = Visible and 0.8 or 1 end
    end
    local Emitter = RingPart and RingPart:FindFirstChildOfClass("ParticleEmitter")
    if Emitter then Emitter.Enabled = Visible end
    if LabelGui then LabelGui.Enabled = Visible end
    if PriceGui then
        PriceGui.Enabled = Visible
        if Visible and NextSlot then
            local PriceLabel = PriceGui:FindFirstChildOfClass("TextLabel")
            if PriceLabel then
                PriceLabel.Text = "$" .. tostring(SETTINGS.SLOT_PRICES[NextSlot])
            end
        end
    end
end

-- Wires every InteractionRing ProximityPrompt in the player's plot.
-- Triggered fires OpenUI; PromptHidden fires CloseUI. Only plot owner can interact.
-- Enables or disables every InteractionRing ProximityPrompt on a plot.
-- Used to ensure only the plot owner can see/trigger prompts.
local function SetPlotPromptsEnabled(PlotFolder: Instance, Enabled: boolean)
    local Rings = PlotFolder:FindFirstChild("InteractionRings")
    if not Rings then return end
    for _, Ring in ipairs(Rings:GetChildren()) do
        local GuiParts = Ring:FindFirstChild("GuiParts")
        if GuiParts then
            local Prompt = GuiParts:FindFirstChildOfClass("ProximityPrompt")
            if Prompt then Prompt.Enabled = Enabled end
        end
    end
end

local function SetupRings(Player: Player, PlotFolder: Instance)
    local Rings = PlotFolder:FindFirstChild("InteractionRings")
    if not Rings then
        warn("[Server] No InteractionRings on " .. PlotFolder.Name)
        return
    end

    for _, Ring in ipairs(Rings:GetChildren()) do
        local UIName = RING_TO_UI[Ring.Name]
        if not UIName then continue end

        local GuiParts = Ring:FindFirstChild("GuiParts")
        local Prompt = GuiParts and GuiParts:FindFirstChildOfClass("ProximityPrompt")
        if not Prompt then continue end

        Prompt.Triggered:Connect(function(Triggerer: Player)
            if Triggerer ~= Player then return end
            OpenUIEvent:FireClient(Player, UIName)
        end)
    end

    -- Set initial state of conditional rings
    RefreshUnlockLaneRing(Player, PlotFolder)
end

local function OnPlayerAdded(Player: Player)
    -- 1) Load player's data. Data.Initialize kicks on a DataStore outage so we never
    --    hand the player default data and overwrite their real save when they leave.
    local PlayerData, NewPlayer = Data.Initialize(Player)
    if not PlayerData then
        return -- Player has been kicked
    end

    SessionStartTimes[Player.Name] = os.time()
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

    -- 2) Assign a plot folder (kick if all 6 occupied)
    local PlotName = AssignPlot(Player)
    if not PlotName then
        Player:Kick("Server full.")
        return
    end

    -- 2a) Tell every client about this player's plot assignment BEFORE populating.
    -- The yield gives clients a frame to process the assignment before SetSoldier/SetTarget arrive.
    PlotAssignmentEvent:FireAllClients(Player.Name, PlotName)
    BroadcastAssignmentsTo(Player)
    task.wait() -- one frame yield

    -- 2b) Create the plot manager (fires SetSoldier/SetTarget to clients during Populate)
    RewardLoop.SetPlotName(Player.Name, PlotName)
    local PlayerPlot = Plot.new(Player, PlayerData, PlotName)
    PlayerPlotManagers[Player.Name] = PlayerPlot

    -- 2c) Wire interaction rings to open UIs for this player.
    -- Also disable prompts on every other plot so they don't show for this player.
    SetupRings(Player, PlayerPlot.Plot)
    for _, OtherPlotName in ipairs(PLOT_NAMES) do
        if OtherPlotName ~= PlotName then
            local OtherPlot = Plots:FindFirstChild(OtherPlotName)
            if OtherPlot then SetPlotPromptsEnabled(OtherPlot, false) end
        end
    end

    -- 3) Initialize player's leaderstats
    InitializeLeaderstats(Player, PlayerData)

    -- 4) Teleport player's character to their plot (ShopAreaBase + 10 studs Y)
    local Character = Player.Character or Player.CharacterAdded:Wait()
    local ShopBase = PlayerPlot.Plot:FindFirstChild("ShopAreaBase")
    if ShopBase then
        Character:PivotTo(CFrame.new(ShopBase.Position + Vector3.new(0, 15, 0)))
    else
        warn("[Server] ShopAreaBase not found on " .. PlotName)
    end

    -- 5) Run AutoEquip in case inventory changed while offline
    AutoEquip(Player)

    -- 6) Apply any gamepass grants the player owns but hasn't had processed yet
    TransactionManager.OnPlayerAdded(Player)

    -- 7) Setup starter pack timer/ad on the player's plot
    SetupStarterPack(Player)

    -- 8) Setup commander pass ad on the player's plot
    SetupCommanderPass(Player)

    -- 9) TODO Present player's offline earnings
    LoadPlayerEvent:FireClient(Player, PlayerData)
end

local function OnPlayerRemoving(Player: Player)
    -- 0) Claim idle rewards if player never did
    IdleRewards.ClaimRewards(Player)

    -- 0a) Persist playtime for this session before saving/removing data
    local PlayerData = Data.Get(Player)
    local SessionStart = SessionStartTimes[Player.Name]
    if PlayerData and SessionStart then
        if not PlayerData.Stats then
            PlayerData.Stats = {}
        end
        PlayerData.Stats.PlayTimeSeconds = (PlayerData.Stats.PlayTimeSeconds or 0) + math.max(0, os.time() - SessionStart)
        Data.Set(Player, PlayerData, true)
    end

    -- 1) Remove player's data (save & write logoff details too)
    Data.Remove(Player)

    -- 2) Cleanup player's plot and free the assignment
    local PlayerPlot = PlayerPlotManagers[Player.Name]
    if PlayerPlot then
        PlayerPlot:Cleanup()
    end

    local PlotName = PlayerPlots[Player.Name]
    if PlotName then
        PlotAssignments[PlotName] = nil
        -- Re-enable prompts on the freed plot so the next player assigned here can use them
        local FreedPlot = Plots:FindFirstChild(PlotName)
        if FreedPlot then SetPlotPromptsEnabled(FreedPlot, true) end
    end
    PlayerPlots[Player.Name] = nil

    PlayerPlotManagers[Player.Name] = nil
    SessionStartTimes[Player.Name] = nil
    StarterPackOpenStates[Player.Name] = nil
    StarterPackTouchCooldowns[Player.Name] = nil
    CommanderPassOpenStates[Player.Name] = nil
    CommanderPassTouchCooldowns[Player.Name] = nil
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
            return true, true, nil, Data.Get(Player)
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

    -- 4) Guard against stale/renamed soldier types that no longer exist in SOLDIER_DATA
    local SoldierType = SoldierData["Type"]
    if not SETTINGS.SOLDIER_DATA[SoldierType] then
        return "Invalid", nil
    end

    -- 5) Check soldier is not special
    if SETTINGS.SOLDIER_DATA[SoldierType]["Special"] then
        return "Special", nil
    end

    -- 6) Get sell value and add credits
    local SellValue = SETTINGS.SOLDIER_DATA[SoldierType]["SellValue"]
    PlayerData["leaderstats"]["Credits"] += SellValue

    -- 7) Remove soldier from inventory
    PlayerData["Inventory"]["SoldierInventory"][SoldierID] = nil

    -- 8) Save data
    Data.Set(Player, PlayerData)

    return "Sold", PlayerData
end

-- Unlocks the next credit-priced lane (4-6 only).
-- Lane 7 = rebirth token (handled by RebirthRing). Lane 8 = commander pass (handled by CommanderRing).
local function UnlockSlot(Player: Player)
    local PlayerData = Data.Get(Player)

    -- Find the next 4-6 lane that's locked
    local NextSlot = nil
    for i = 4, 6 do
        if not PlayerData.Plot.Unlocks["Slot" .. i] then
            NextSlot = i
            break
        end
    end

    if not NextSlot then
        return "MaxSlots", nil
    end

    local Price = SETTINGS.SLOT_PRICES[NextSlot]
    if type(Price) ~= "number" then
        -- Should never hit; lanes 4-6 are pure credit cost.
        return "Invalid", nil
    end

    if PlayerData["leaderstats"]["Credits"] < Price then
        return "Insufficient", nil
    end

    PlayerData["leaderstats"]["Credits"] -= Price
    PlayerData.Plot.Unlocks["Slot" .. NextSlot] = true
    Data.Set(Player, PlayerData)

    -- Show the newly unlocked collect pad and wire its touch handler
    PlayerPlotManagers[Player.Name]:OnLaneUnlocked(NextSlot)

    -- Refresh the unlock ring (may hide it if all 4-6 are now unlocked)
    RefreshUnlockLaneRing(Player, PlayerPlotManagers[Player.Name].Plot)

    -- Refresh targets so the new lane gets a target
    local ActiveTarget = PlayerData.Inventory.ActiveTarget
    PlayerPlotManagers[Player.Name]:SetTarget(ActiveTarget)

    -- AutoEquip into the new lane if enabled
    AutoEquip(Player)

    return "Unlocked", Data.Get(Player)
end

-- // Events & Calling
RewardLoop.Init()
TransactionManager.Initialize()
Players.PlayerAdded:Connect(OnPlayerAdded)
Players.PlayerRemoving:Connect(OnPlayerRemoving)

task.spawn(function()
    while true do
        CurrentStock = Restock()
        TimeOfStock = os.time()

        RestockEvent:FireAllClients(CurrentStock, TimeOfStock)

        task.wait(SETTINGS.STOCK_CONFIG.RotationSeconds)
    end
end)

GetStockFunction.OnServerInvoke = function()
    return CurrentStock, TimeOfStock
end

PurchaseSoldierFunction.OnServerInvoke = function(Player: Player, Type: string)
    -- 3 purchases per 5s — prevents rapid-fire purchase spam
    if not RateLimit.Check(Player, "PurchaseSoldier", 3, 5) then
        return "RateLimit"
    end
    local Arg1, Arg2 = PurchaseSoldier(Player, Type)

    return Arg1, Arg2
end

ActivateSoldierFunction.OnServerInvoke = function(Player: Player, SoldierID: string)
    -- 8 activations per 5s — generous for AutoEquip bulk-placing soldiers
    if not RateLimit.Check(Player, "ActivateSoldier", 8, 5) then
        return false, nil
    end
    local Arg1, Arg2 = PlayerPlotManagers[Player.Name]:Activate(SoldierID)

    return Arg1, Arg2
end

DeactivateSoldierFunction.OnServerInvoke = function(Player: Player, SoldierID: string)
    -- 8 deactivations per 5s — mirrors activate limit
    if not RateLimit.Check(Player, "DeactivateSoldier", 8, 5) then
        return false, nil
    end
    local Arg1, Arg2 = PlayerPlotManagers[Player.Name]:Deactivate(SoldierID)

    return Arg1, Arg2
end

UpdateSettingFunction.OnServerInvoke = function(Player: Player, Item: string)
    -- 5 setting changes per 5s — settings are low-frequency by design
    if not RateLimit.Check(Player, "UpdateSetting", 5, 5) then
        return false, nil, "RateLimit"
    end
	local Arg1, Arg2, Arg3, Arg4 = UpdateSetting(Player, Item)

	return Arg1, Arg2, Arg3, Arg4
end

UpgradeTargetEvent.OnServerEvent:Connect(function(Player: Player)
    -- 2 target upgrades per 5s — upgrades are deliberate one-at-a-time actions
    if not RateLimit.Check(Player, "UpgradeTarget", 2, 5) then
        return
    end
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
    -- 5 sells per 5s — selling a full inventory quickly is legitimate
    if not RateLimit.Check(Player, "SellSoldier", 5, 5) then
        return
    end
	local Response, PlayerData = SellSoldier(Player, SoldierID)
	SellSoldierEvent:FireClient(Player, Response, PlayerData)
end)

UnlockSlotEvent.OnServerEvent:Connect(function(Player: Player)
    -- 1 unlock per 3s — unlocks are one-at-a-time by design
    if not RateLimit.Check(Player, "UnlockSlot", 1, 3) then
        return
    end
	local Response, PlayerData = UnlockSlot(Player)
	UnlockSlotEvent:FireClient(Player, Response, PlayerData)
end)

StarterPackEvent.OnServerEvent:Connect(function(Player: Player, Action: string)
    if Action ~= "Closed" then
        return
    end

    StarterPackOpenStates[Player.Name] = false
    StarterPackTouchCooldowns[Player.Name] = os.clock() + 7
end)

CommanderPassEvent.OnServerEvent:Connect(function(Player: Player, Action: string)
    if Action ~= "Closed" then
        return
    end

    CommanderPassOpenStates[Player.Name] = false
    CommanderPassTouchCooldowns[Player.Name] = os.clock() + 7
end)

-- Returns the player's assigned plot name. Used by client scripts that miss
-- the PlotAssignmentEvent on join due to load order.
local GetPlotNameFunction: RemoteFunction = Remotes:FindFirstChild("GetPlotName") or (function()
    local F = Instance.new("RemoteFunction")
    F.Name = "GetPlotName"
    F.Parent = Remotes
    return F
end)()
GetPlotNameFunction.OnServerInvoke = function(Player: Player)
    local Timeout = 10
    local Elapsed = 0
    while not PlayerPlots[Player.Name] and Elapsed < Timeout do
        task.wait(0.1)
        Elapsed += 0.1
    end
    return PlayerPlots[Player.Name]
end

-- Returns player data, waiting until it is loaded if needed
GetPlayerDataFunction.OnServerInvoke = function(Player: Player)
	local Timeout = 10
	local Elapsed = 0
	while not Data.Get(Player) and Elapsed < Timeout do
		task.wait(0.1)
		Elapsed += 0.1
	end
	return Data.Get(Player)
end
