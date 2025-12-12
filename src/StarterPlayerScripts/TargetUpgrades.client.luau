-- // TargetUpgrades, written by KingCreoo on 12-04-2025
-- // Manages target upgrade display and purchase GUI

-- // Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

-- // Modules
local SETTINGS = require(ReplicatedStorage:WaitForChild("Settings"))
local SOUND_MANAGER = nil

-- // Variables
local LocalPlayer = Players.LocalPlayer

-- Connect to remotes FIRST to avoid race condition
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
SOUND_MANAGER = require(ReplicatedStorage:WaitForChild("Settings"):WaitForChild("SoundManager"))
local LoadPlayerEvent: RemoteEvent = Remotes:WaitForChild("LoadPlayer")
local UpgradeTargetEvent: RemoteEvent = Remotes:WaitForChild("UpgradeTarget")

-- Store PlayerData if event fires before we're ready
local CachedPlayerData = nil

LoadPlayerEvent.OnClientEvent:Connect(function(PlayerData: table)
	CachedPlayerData = PlayerData
end)

local LocalGui = LocalPlayer:WaitForChild("PlayerGui")
local FramesGui = LocalGui:WaitForChild("Frames")

local UpgradeTargetFrame: Frame = FramesGui:WaitForChild("UpgradeTargetFrame")
local MainFrame: Frame = UpgradeTargetFrame:WaitForChild("MainFrame")

local YesButton: TextButton = MainFrame:WaitForChild("Yes")
local NoButton: TextButton = MainFrame:WaitForChild("No")
local AmountLabel: TextLabel = MainFrame:WaitForChild("Amount")

local ViewTile: Frame = MainFrame:WaitForChild("ViewTile")
local ViewImage: ImageLabel = ViewTile:WaitForChild("Image")

local ButtonExpandBindable: BindableEvent = Remotes:WaitForChild("ButtonExpand")
local ButtonDeflateBindable: BindableEvent = Remotes:WaitForChild("ButtonDeflate")
local CloseFrameBindable: BindableEvent = Remotes:WaitForChild("CloseFrame")
local NotifyBindable: BindableEvent = Remotes:WaitForChild("NotifyBindable")

local TargetModels = ReplicatedStorage:WaitForChild("Types"):WaitForChild("Targets")

local UpgradeShop = Workspace:WaitForChild("UpgradeShop")
local UpgradeShopBase: Part = UpgradeShop:WaitForChild("Base")
local GuiParts = UpgradeShop:WaitForChild("GuiParts")
local ShopAmountGui = GuiParts:WaitForChild("AmountGui")
local ShopAmountLabel: TextLabel = ShopAmountGui:WaitForChild("Amount")

local Buttons = {YesButton, NoButton}

local FrameActive = false
local NextTargetType = nil

local PurchaseDebounce = false

-- // Functions

-- Displays the next target model and price at the UpgradeShop
local function DisplayTarget(TargetType: string)
	-- Store next target for purchase reference
	NextTargetType = TargetType

	-- 1) Find & delete possible past display target
	local ExistingDisplay = UpgradeShop:FindFirstChild("DisplayTarget")
	if ExistingDisplay then
		ExistingDisplay:Destroy()
	end

	-- 2) Clone & display new target at UpgradeShop
	local TargetModel: Model = TargetModels:FindFirstChild(TargetType)
	if not TargetModel then
		warn("Target model not found: " .. TargetType)
		return
	end

	local DisplayModel = TargetModel:Clone()
	DisplayModel.Name = "DisplayTarget"

	DisplayModel:SetPrimaryPartCFrame(UpgradeShopBase.CFrame * CFrame.Angles(0, math.rad(180), 0) + Vector3.new(0, 3, 0))
	DisplayModel.Parent = UpgradeShop

	-- 3) Update the price display on the shop GUI
	local Price = SETTINGS.TARGET_DATA[TargetType].Price
	ShopAmountLabel.Text = "$" .. Price

	-- 4) Update the frame GUI elements
	AmountLabel.Text = "$" .. Price
	-- ViewImage.Image = SETTINGS.TARGET_DATA[TargetType].Image -- TODO: Add images to TARGET_DATA if needed
end

-- Displays complete sign when all targets are unlocked
local function DisplayComplete()
	-- Clear next target reference
	NextTargetType = nil

	-- 1) Find & delete possible past display target
	local ExistingDisplay = UpgradeShop:FindFirstChild("DisplayTarget")
	if ExistingDisplay then
		ExistingDisplay:Destroy()
	end

	-- 2) Clone & display complete sign
	-- TODO: Add complete sign model

	-- 3) Update the price display to say "COMPLETE"
	ShopAmountLabel.Text = "COMPLETE"
	AmountLabel.Text = "COMPLETE"
end

-- Handles purchase attempt when Yes button is clicked
local function AttemptPurchase()
	-- 1) Check debounce
	if PurchaseDebounce then
		NotifyBindable:Fire("Slow down!", 0.8, Color3.fromRGB(255, 0, 0))
		return
	end
	PurchaseDebounce = true

	-- 2) Check if there's a next target to purchase
	if not NextTargetType then
		NotifyBindable:Fire("All targets unlocked!", 0.8, Color3.fromRGB(255, 0, 0))
		PurchaseDebounce = false
		return
	end

	-- 3) Check if player has enough credits
	local Price = SETTINGS.TARGET_DATA[NextTargetType].Price
	if LocalPlayer:WaitForChild("leaderstats"):WaitForChild("Credits").Value < Price then
		NotifyBindable:Fire("Insufficient funds!", 0.8, Color3.fromRGB(255, 0, 0))
		PurchaseDebounce = false
		return
	end

	-- 4) Fire server to process purchase
	UpgradeTargetEvent:FireServer()

	task.wait(0.2)
	PurchaseDebounce = false
end

-- // Events

-- Button hover effects
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

-- Track frame visibility
UpgradeTargetFrame:GetPropertyChangedSignal("Visible"):Connect(function()
	FrameActive = UpgradeTargetFrame.Visible
end)

-- Yes button - attempt purchase
YesButton.MouseButton1Click:Connect(function()
	SOUND_MANAGER:PlayClick()
	AttemptPurchase()
end)

-- No button - close frame
NoButton.MouseButton1Click:Connect(function()
	if FrameActive == false then return end
	SOUND_MANAGER:PlayClick()
	CloseFrameBindable:Fire(UpgradeTargetFrame)
end)

-- Server response after successful purchase or error
UpgradeTargetEvent.OnClientEvent:Connect(function(Response: string?)
	-- Handle error responses
	if Response == "Insufficient" then
		NotifyBindable:Fire("Insufficient funds!", 0.8, Color3.fromRGB(255, 0, 0))
		PurchaseDebounce = false
		return
	elseif Response == "Complete" then
		NotifyBindable:Fire("All targets unlocked!", 0.8, Color3.fromRGB(255, 255, 0))
		PurchaseDebounce = false
		return
	end

	-- Play purchase sound on success
	SOUND_MANAGER:PlayPurchase()

	-- Close the frame
	CloseFrameBindable:Fire(UpgradeTargetFrame)

	-- Update display for next target
	if Response then
		DisplayTarget(Response)
	else
		DisplayComplete()
	end
end)

-- Process player data (either cached or from future events)
local function ProcessPlayerData(PlayerData: table)
	-- Calculate and display the next target to unlock
	local CurrentTarget = PlayerData.Inventory.ActiveTarget
	local CurrentIndex = table.find(SETTINGS.TARGET_ORDER, CurrentTarget)
	local NextTarget = SETTINGS.TARGET_ORDER[CurrentIndex + 1]

	if NextTarget then
		DisplayTarget(NextTarget)
	else
		DisplayComplete()
	end
end

-- Handle future LoadPlayerEvent fires (reconnects, etc)
LoadPlayerEvent.OnClientEvent:Connect(function(PlayerData: table)
	ProcessPlayerData(PlayerData)
end)

-- Process cached data if event fired before we finished initializing
if CachedPlayerData then
	ProcessPlayerData(CachedPlayerData)
end
