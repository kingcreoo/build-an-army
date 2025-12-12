-- // SoldierInventory, initialized by KingCreoo on 9-7-2025
-- // Manages UI functions for the client's soldier inventory :)

-- // Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- // CRITICAL: Connect to LoadPlayerEvent FIRST before any WaitForChild calls
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local LoadPlayerEvent: RemoteEvent = Remotes:WaitForChild("LoadPlayer")

-- Cache player data if event fires before we finish initializing
local CachedPlayerData = nil

LoadPlayerEvent.OnClientEvent:Connect(function(PlayerData: table)
	CachedPlayerData = PlayerData
end)

-- // Modules
local SETTINGS = require(ReplicatedStorage:WaitForChild("Settings"))

-- // Variables
local LocalPlayer = Players.LocalPlayer
local UI = LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("Client"):WaitForChild("UI")

local LocalGui = LocalPlayer:WaitForChild("PlayerGui")
local FramesGui = LocalGui:WaitForChild("Frames")

local SoldierInventoryFrame: Frame = FramesGui:WaitForChild("SoldierInventory")
local CloseButton: TextButton = SoldierInventoryFrame:WaitForChild("Close")
local AutoEquipButton: TextButton = SoldierInventoryFrame:WaitForChild("AutoEquip")

local ScrollingFrame = SoldierInventoryFrame:WaitForChild("Inventory"):WaitForChild("ScrollingFrame")
local Template = ScrollingFrame:WaitForChild("Template")

local Buttons = {CloseButton, AutoEquipButton}

local ActivateSoldierFunction: RemoteFunction = Remotes:WaitForChild("ActivateSoldier")
local DeactivateSoldierFunction: RemoteFunction = Remotes:WaitForChild("DeactivateSoldier")
local UpdateSettingFunction: RemoteFunction = Remotes:WaitForChild("UpdateSetting")

local UpdateSettingBindable: BindableEvent = Remotes:WaitForChild("UpdateSettingBindable")
local ButtonExpandBindable: BindableEvent = Remotes:WaitForChild("ButtonExpand")
local ButtonDeflateBindable: BindableEvent = Remotes:WaitForChild("ButtonDeflate")
local CloseFrameBindable: BindableEvent = Remotes:WaitForChild("CloseFrame")
local UpdateInventoryBindable: BindableEvent = Remotes:WaitForChild("UpdateInventory")
local NotifyBindable: BindableEvent = Remotes:WaitForChild("NotifyBindable")

local ActivateBindable = Instance.new("BindableEvent")
ActivateBindable.Parent = script
ActivateBindable.Name = "DeactivateBindable"
local DeactivateBindable = Instance.new("BindableEvent")
DeactivateBindable.Parent = script
DeactivateBindable.Name = "DeactivateBindable"

local FrameActive = false
local SoldiersDisplayed = {}
local LatestData

-- // Functions

local function CreateReversedTable(Table)
    local LookUp = {}
    local MaxIndex = #Table
    for i, Type in ipairs(Table) do
        -- Map each soldier type to its reversed position
        LookUp[Type] = MaxIndex - i + 1
    end
    return LookUp
end
local SHOP_ORDER_REVERSED = CreateReversedTable(SETTINGS.SHOP_ORDER)

local function IsSoldierActive(ActiveSoldiers, SoldierID)
    for Index, ID in pairs(ActiveSoldiers) do
        if ID == SoldierID then
            return Index
        end
    end
    return false
end

local function CreateFrame(SoldierID, SoldierData, PlayerData)
    local SoldierFrame = Template:Clone()
    local ViewTile = SoldierFrame:WaitForChild("ViewTile")
    local Button: TextButton = SoldierFrame:WaitForChild("Button")
    local SoldierType = SoldierData["Type"]
    
    ViewTile.Image.Image = SETTINGS.SOLDIER_DATA[SoldierType]["Image"]
    ViewTile.BackgroundColor3 = SETTINGS.SOLDIER_DATA[SoldierType]["ShopColor"]
    SoldierFrame.Name = SoldierID

    local Index = IsSoldierActive(PlayerData["Inventory"]["ActiveSoldiers"], SoldierID)
    if Index then
        SoldierFrame.LayoutOrder = Index
        SoldierFrame:WaitForChild("Active").Visible = true
    else
        SoldierFrame.LayoutOrder = 100 + (SHOP_ORDER_REVERSED[SoldierData["Type"]] or 999)
        SoldierFrame:WaitForChild("Active").Visible = false
    end

    SoldierFrame.Visible = true
    SoldierFrame.Parent = ScrollingFrame

    SoldiersDisplayed[SoldierID] = SoldierFrame

    Button.MouseButton1Click:Connect(function()
        -- Check if this soldier is currently active or inactive
        local Active = IsSoldierActive(LatestData["Inventory"]["ActiveSoldiers"], SoldierID)
        if Active then
            -- Soldier is active, fire deactivate function
            DeactivateBindable:Fire(SoldierID)
        else
            -- Soldier is inactive, fire activate function
            ActivateBindable:Fire(SoldierID)
        end
    end)
end

local function UpdateInventory(PlayerData: table)
    LatestData = PlayerData

    -- Check to see if a soldier has been added
    for SoldierID, SoldierData in pairs(PlayerData["Inventory"]["SoldierInventory"]) do
        -- If a new soldier has been added, create their frame
        if not SoldiersDisplayed[SoldierID] then
            CreateFrame(SoldierID, SoldierData, PlayerData)
        end
    end

    -- Check to see if a soldier has been removed
    for SoldierID, SoldierFrame in pairs(SoldiersDisplayed) do
        -- If we have an extra soldier, destroy it
        if not PlayerData["Inventory"]["SoldierInventory"][SoldierID] then
            SoldierFrame:Destroy()
            SoldiersDisplayed[SoldierID] = nil
        end
    end

    -- Sync soldier layout order / active soldiers
    for SoldierID, SoldierFrame in pairs(SoldiersDisplayed) do
        local Index = IsSoldierActive(PlayerData["Inventory"]["ActiveSoldiers"], SoldierID)
        if Index then
            SoldierFrame.LayoutOrder = Index
            SoldierFrame:WaitForChild("Active").Visible = true
        else
            local SoldierData = PlayerData["Inventory"]["SoldierInventory"][SoldierID]
            SoldierFrame.LayoutOrder = 100 + (SHOP_ORDER_REVERSED[SoldierData["Type"]] or 999)
            SoldierFrame:WaitForChild("Active").Visible = false
        end
    end
end

local function DeactivateSoldier(SoldierID)
    -- 1) Simply ask server to deactivate this soldier
    local Result, PlayerData = DeactivateSoldierFunction:InvokeServer(SoldierID)

    -- 2) If the response is bad, warn the player
    if Result == false then
        NotifyBindable:Fire("Couldn't deactivate soldier!", .8, Color3.fromRGB(255, 0, 0))
        -- TODO create notification GUI
        return
    end

    -- 3) If the response is good, simply update the inventory with the new data
    UpdateInventory(PlayerData)
end

local function ActivateSoldier(SoldierID)
    -- 1) Check if there is ample room to activate soldier
    local UnlockedLanes = {}
    local PlotUnlocks = LatestData.Plot.Unlocks
    for i = 1, 7 do
        if PlotUnlocks["Slot" .. tostring(i)] then
            table.insert(UnlockedLanes, "Slot" .. tostring(i))
        end
    end

    if #LatestData["Inventory"]["ActiveSoldiers"] >= #UnlockedLanes then
        -- If not, warn player
        -- TODO prompt player to purchase gamepass for more lanes
        NotifyBindable:Fire("Maximum soldiers!", .8, Color3.fromRGB(255, 0, 0))
        return
    end

    -- 2) Ask server to activate this soldier
    local Response, PlayerData = ActivateSoldierFunction:InvokeServer(SoldierID)

    -- 3) If the repsonse is bad, warn the player
    if not Response then
        NotifyBindable:Fire("Couldn't activate soldier!", .8, Color3.fromRGB(255, 0, 0))
        return
    end

    -- 4) If the response is good, update the inventory
    UpdateInventory(PlayerData)
end

local function UpdateAE(On: boolean)
    UpdateSettingBindable:Fire("AutoEquip", On)

    if On then
        local Color1 = AutoEquipButton:GetAttribute("OnColor1")
        local Color2 = AutoEquipButton:GetAttribute("OnColor2")

        AutoEquipButton.BackgroundColor3 = Color1
        AutoEquipButton.UIStroke.Color = Color2
        AutoEquipButton.TextLabel.UIStroke.Color = Color2
    else
        local Color1 = AutoEquipButton:GetAttribute("OffColor1")
        local Color2 = AutoEquipButton:GetAttribute("OffColor2")

        AutoEquipButton.BackgroundColor3 = Color1
        AutoEquipButton.UIStroke.Color = Color2
        AutoEquipButton.TextLabel.UIStroke.Color = Color2
    end
end

local Bounces = 0
local function ChangeAE()
    if Bounces >= 3 then
        NotifyBindable:Fire("Slow down!", .8, Color3.fromRGB(255, 0, 0))
        return
    end

    Bounces += 1

    local Success, On, ErrorMessage = UpdateSettingFunction:InvokeServer("AutoEquip")

    if not Success then
        NotifyBindable:Fire(ErrorMessage, .8, Color3.fromRGB(255, 0, 0))

        task.delay(1, function()
            Bounces -= 1
        end)

        return
    end

    UpdateAE(On)

    task.delay(1, function()
        Bounces -= 1
    end)
end

local function InitializeInventory(PlayerData: table)
    for SoldierID, SoldierData in pairs(PlayerData["Inventory"]["SoldierInventory"]) do
        CreateFrame(SoldierID, SoldierData, PlayerData)
    end
end

-- Processes player data (called from cached data or future events)
local function ProcessPlayerData(PlayerData: table)
	LatestData = PlayerData
	InitializeInventory(PlayerData)
	UpdateAE(PlayerData.Settings.AutoEquip)
end

-- // Events

for _, Button in pairs(Buttons) do
    Button.MouseEnter:Connect(function()
        if FrameActive == false then return end
        ButtonExpandBindable:Fire(Button, 1.1)
    end)
    Button.MouseLeave:Connect(function()
        if FrameActive == false then return end
        ButtonDeflateBindable:Fire(Button)
    end)
end

CloseButton.MouseButton1Click:Connect(function()
    if FrameActive == false then return end
    CloseFrameBindable:Fire(SoldierInventoryFrame)
end)

SoldierInventoryFrame:GetPropertyChangedSignal("Visible"):Connect(function()
    FrameActive = SoldierInventoryFrame.Visible
end)

-- Handle future LoadPlayerEvent fires (reconnects, etc)
LoadPlayerEvent.OnClientEvent:Connect(function(PlayerData: table)
    ProcessPlayerData(PlayerData)
end)

AutoEquipButton.MouseButton1Click:Connect(ChangeAE)

UpdateInventoryBindable.Event:Connect(UpdateInventory)
ActivateBindable.Event:Connect(ActivateSoldier)
DeactivateBindable.Event:Connect(DeactivateSoldier)

-- Process cached data if event fired before we finished initializing
if CachedPlayerData then
	ProcessPlayerData(CachedPlayerData)
end
