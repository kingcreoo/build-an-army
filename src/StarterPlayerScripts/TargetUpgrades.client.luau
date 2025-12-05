-- // TargetUpgrades, written by KingCreoo on 12-04-2025
-- // Manages target upgrade display and purchase GUI

-- // Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

-- // Modules
local SETTINGS = require(ReplicatedStorage:WaitForChild("Settings"))

-- // Variables
local LocalPlayer = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local UpgradeTargetFunction: RemoteFunction = Remotes:WaitForChild("UpgradeTarget")
local LoadPlayerEvent: RemoteEvent = Remotes:WaitForChild("LoadPlayer")

local TargetModels = ReplicatedStorage:WaitForChild("Types"):WaitForChild("Targets")

-- // Local functions

-- Displays the next target model and price on upgrade pedestal
local function DisplayTarget(TargetType: string)
    -- 1) Find & delete possible past target
    local PlayerPlot = Workspace:WaitForChild("Plots"):FindFirstChild(LocalPlayer.Name)
    if not PlayerPlot then
        warn("Player not found")
    end

    local ExistingDisplay = PlayerPlot:FindFirstChild("DisplayTarget")
    if ExistingDisplay then
        ExistingDisplay:Destroy()
    end

    -- 2) Clone & display new target
    local TargetModel: Model = TargetModels:FindFirstChild(TargetType)
    local DisplayModel = TargetModel:Clone()
    DisplayModel.Name = "DisplayTarget"

    local UpgradeTargetPart = PlayerPlot:WaitForChild("UpgradeTarget")

    DisplayModel:SetPrimaryPartCFrame(UpgradeTargetPart.CFrame * CFrame.Angles(0, math.rad(180), 0) + Vector3.new(0, 3, 0))

    DisplayModel.Parent = PlayerPlot

    -- 3) Update the price display on the GUI
    local AmountGUI = UpgradeTargetPart:WaitForChild("AmountGui")
    local Amount = AmountGUI:WaitForChild("Amount")
    local Price = SETTINGS.TARGET_DATA[TargetType].Price
    Amount.Text = "$" .. Price
end

-- Displays compelte sign on the upgrade pedastal
local function DisplayComplete()
    -- 1) Find & delete possible past target
    local PlayerPlot = Workspace:WaitForChild("Plots"):FindFirstChild(LocalPlayer.Name)
    if not PlayerPlot then
        warn("Player not found")
    end

    local ExistingDisplay = PlayerPlot:FindFirstChild("DisplayTarget")
    if ExistingDisplay then
        ExistingDisplay:Destroy()
    end

    -- 2) Clone & display complete sign :)
    -- TODO

    -- 3) Update the price display to say "COMPLETE"
    local UpgradeTargetPart = PlayerPlot:WaitForChild("UpgradeTarget")
    local AmountGUI = UpgradeTargetPart:WaitForChild("AmountGui")
    local Amount = AmountGUI:WaitForChild("Amount")
    Amount.Text = "COMPLETE"
end

-- Opens purchase GUI and handles confirmation
local function PromptPurchase(TargetType: string, Price: number)
    
end

-- // Events

LoadPlayerEvent.OnClientEvent:Connect(function(PlayerData: table)
    -- Calculate and display the next target to unlock
    local CurrentTarget = PlayerData.Inventory.ActiveTarget
    local CurrentIndex = table.find(SETTINGS.TARGET_ORDER, CurrentTarget)
    local NextTarget = SETTINGS.TARGET_ORDER[CurrentIndex + 1]

    if NextTarget then
        DisplayTarget(NextTarget)
    else
        DisplayComplete()
    end
end)

-- // Return