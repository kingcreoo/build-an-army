-- // SellSoldiers, written by KingCreoo on 12-08-2025
-- // Manages soldier selling UI and confirmation flow

-- // Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

-- // Modules
local SETTINGS = require(ReplicatedStorage:WaitForChild("Settings"))

-- // Variables
local LocalPlayer = Players.LocalPlayer

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local LoadPlayerEvent: RemoteEvent = Remotes:WaitForChild("LoadPlayer")
local SellSoldierEvent: RemoteEvent = Remotes:WaitForChild("SellSoldier")
local UpdateInventoryBindable: BindableEvent = Remotes:WaitForChild("UpdateInventory")

local ButtonExpandBindable: BindableEvent = Remotes:WaitForChild("ButtonExpand")
local ButtonDeflateBindable: BindableEvent = Remotes:WaitForChild("ButtonDeflate")
local CloseFrameBindable: BindableEvent = Remotes:WaitForChild("CloseFrame")
local NotifyBindable: BindableEvent = Remotes:WaitForChild("NotifyBindable")

local LocalGui = LocalPlayer:WaitForChild("PlayerGui")
local FramesGui = LocalGui:WaitForChild("Frames")

local SellSoldiersFrame: Frame = FramesGui:WaitForChild("SellSoldiersFrame")
local MainFrame: Frame = SellSoldiersFrame:WaitForChild("MainFrame")
local CloseButton: TextButton = SellSoldiersFrame:WaitForChild("Close")
local InventoryFrame: Frame = MainFrame:WaitForChild("Inventory")
local ScrollingFrame: ScrollingFrame = InventoryFrame:WaitForChild("ScrollingFrame")
local Template: Frame = ScrollingFrame:WaitForChild("Template")

local ConfirmFrame: Frame = SellSoldiersFrame:WaitForChild("SellSoldierConfirmationFrame")
local ConfirmMainFrame: Frame = ConfirmFrame:WaitForChild("MainFrame")
local YesButton: TextButton = ConfirmMainFrame:WaitForChild("Yes")
local NoButton: TextButton = ConfirmMainFrame:WaitForChild("No")
local AmountLabel: TextLabel = ConfirmMainFrame:WaitForChild("Amount")
local ConfirmViewTile: Frame = ConfirmMainFrame:WaitForChild("ViewTile")
local ConfirmViewImage: ImageLabel = ConfirmViewTile:WaitForChild("Image")
local ConfirmSoldierLabel: TextLabel = ConfirmFrame:WaitForChild("LabelBar"):WaitForChild("TextLabel")

local Buttons = {CloseButton, YesButton, NoButton}

local TweenInfo_Slide = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)

local FrameActive = false
local SoldiersDisplayed = {}
local LatestData = nil
local SelectedSoldierID = nil
local SellDebounce = false

-- // Functions

-- Creates a reversed lookup table for soldier ratings
local function CreateReversedTable(Table)
	local LookUp = {}
	local MaxIndex = #Table
	for i, Type in ipairs(Table) do
		LookUp[Type] = MaxIndex - i + 1
	end
	return LookUp
end
local RATING_ORDER_REVERSED = CreateReversedTable(SETTINGS.RATING_ORDER)

-- Checks if a soldier is currently active
local function IsSoldierActive(ActiveSoldiers, SoldierID)
	for Index, ID in pairs(ActiveSoldiers) do
		if ID == SoldierID then
			return Index
		end
	end
	return false
end

-- Tweens the main frame to reveal confirmation frame
local function ShowConfirmation(SoldierID: string)
	SelectedSoldierID = SoldierID

	-- Get soldier data for display
	local SoldierData = LatestData["Inventory"]["SoldierInventory"][SoldierID]
	local SoldierType = SoldierData["Type"]
	local SellValue = SETTINGS.SOLDIER_DATA[SoldierType]["SellValue"]

	-- Format soldier name (remove "The" prefix if present)
	local SoldierName = string.upper(SoldierType)
	if string.sub(SoldierName, 1, 4) == "THE " then
		SoldierName = string.sub(SoldierName, 5)
	end

	-- Populate confirmation frame
	ConfirmViewImage.Image = SETTINGS.SOLDIER_DATA[SoldierType]["Image"]
	AmountLabel.Text = "$" .. SellValue
	ConfirmSoldierLabel.Text = "SELL THIS " .. SoldierName

	-- Make confirmation frame visible
	ConfirmFrame.Visible = true

	-- Tween main frame down to reveal confirmation
	local SlideTween = TweenService:Create(SellSoldiersFrame, TweenInfo_Slide, {Position = UDim2.fromScale(0.5, 1.5)})
	SlideTween:Play()
end

-- Tweens the main frame back to center, hiding confirmation
local function HideConfirmation()
	SelectedSoldierID = nil

	-- Tween main frame back to center
	local SlideTween = TweenService:Create(SellSoldiersFrame, TweenInfo_Slide, {Position = UDim2.fromScale(0.5, 0.5)})
	SlideTween:Play()

	-- Hide confirmation frame after SlideTween completes
	SlideTween.Completed:Connect(function()
		ConfirmFrame.Visible = false
	end)
end

-- Creates a soldier frame in the sell list
local function CreateFrame(SoldierID: string, SoldierData: table, PlayerData: table)
	local SoldierFrame = Template:Clone()
	local ViewTile = SoldierFrame:WaitForChild("ViewTile")
	local Button: TextButton = SoldierFrame:WaitForChild("Button")
	local SoldierType = SoldierData["Type"]

	ViewTile:WaitForChild("Image").Image = SETTINGS.SOLDIER_DATA[SoldierType]["Image"]
	SoldierFrame.Name = SoldierID

	-- Set layout order based on rating (best soldiers first)
	local Index = IsSoldierActive(PlayerData["Inventory"]["ActiveSoldiers"], SoldierID)
	if Index then
		SoldierFrame.LayoutOrder = 100 + Index
		SoldierFrame:WaitForChild("Active").Visible = true
		SoldierFrame:WaitForChild("Active").TextLabel.Text = "ACTIVE" .. tostring(Index)
	else
		SoldierFrame.LayoutOrder = RATING_ORDER_REVERSED[SoldierType] or 999
		SoldierFrame:WaitForChild("Active").Visible = false
	end

	SoldierFrame.Visible = true
	SoldierFrame.Parent = ScrollingFrame

	SoldiersDisplayed[SoldierID] = SoldierFrame

	-- Wire button click to show confirmation
	Button.MouseButton1Click:Connect(function()
		if not FrameActive then return end
		if SelectedSoldierID then return end

		-- Client-side check: is soldier active?
		if IsSoldierActive(LatestData["Inventory"]["ActiveSoldiers"], SoldierID) then
			NotifyBindable:Fire("Deactivate soldier first!", 0.8, Color3.fromRGB(255, 0, 0))
			return
		end

		-- Client-side check: is soldier special?
		local Type = LatestData["Inventory"]["SoldierInventory"][SoldierID]["Type"]
		if SETTINGS.SOLDIER_DATA[Type]["Special"] then
			NotifyBindable:Fire("Cannot sell special soldiers!", 0.8, Color3.fromRGB(255, 0, 0))
			return
		end

		ShowConfirmation(SoldierID)
	end)
end

-- Syncs displayed soldiers with current player data
local function UpdateInventory(PlayerData: table)
	LatestData = PlayerData

	-- Add new soldiers
	for SoldierID, SoldierData in pairs(PlayerData["Inventory"]["SoldierInventory"]) do
		if not SoldiersDisplayed[SoldierID] then
			CreateFrame(SoldierID, SoldierData, PlayerData)
		end
	end

	-- Remove sold soldiers
	for SoldierID, SoldierFrame in pairs(SoldiersDisplayed) do
		if not PlayerData["Inventory"]["SoldierInventory"][SoldierID] then
			SoldierFrame:Destroy()
			SoldiersDisplayed[SoldierID] = nil
		end
	end

	-- Sync active status and layout order
	for SoldierID, SoldierFrame in pairs(SoldiersDisplayed) do
		local Index = IsSoldierActive(PlayerData["Inventory"]["ActiveSoldiers"], SoldierID)
		if Index then
			SoldierFrame.LayoutOrder = 100 + Index
			SoldierFrame:WaitForChild("Active").Visible = true
			SoldierFrame:WaitForChild("Active").TextLabel.Text = "ACTIVE" .. tostring(Index)
		else
			local SoldierData = PlayerData["Inventory"]["SoldierInventory"][SoldierID]
			SoldierFrame.LayoutOrder = RATING_ORDER_REVERSED[SoldierData["Type"]] or 999
			SoldierFrame:WaitForChild("Active").Visible = false
		end
	end
end

-- Attempts to sell the selected soldier
local function AttemptSell()
	if SellDebounce then
		NotifyBindable:Fire("Slow down!", 0.8, Color3.fromRGB(255, 0, 0))
		return
	end

	if not SelectedSoldierID then return end

	SellDebounce = true

	-- Final client-side checks before firing server
	local SoldierData = LatestData["Inventory"]["SoldierInventory"][SelectedSoldierID]
	if not SoldierData then
		NotifyBindable:Fire("Soldier not found!", 0.8, Color3.fromRGB(255, 0, 0))
		HideConfirmation()
		SellDebounce = false
		return
	end

	if IsSoldierActive(LatestData["Inventory"]["ActiveSoldiers"], SelectedSoldierID) then
		NotifyBindable:Fire("Deactivate soldier first!", 0.8, Color3.fromRGB(255, 0, 0))
		HideConfirmation()
		SellDebounce = false
		return
	end

	if SETTINGS.SOLDIER_DATA[SoldierData["Type"]]["Special"] then
		NotifyBindable:Fire("Cannot sell special soldiers!", 0.8, Color3.fromRGB(255, 0, 0))
		HideConfirmation()
		SellDebounce = false
		return
	end

	-- Fire server to process sale
	SellSoldierEvent:FireServer(SelectedSoldierID)
end

-- Initializes inventory display with current soldiers
local function InitializeInventory(PlayerData: table)
	LatestData = PlayerData
	for SoldierID, SoldierData in pairs(PlayerData["Inventory"]["SoldierInventory"]) do
		CreateFrame(SoldierID, SoldierData, PlayerData)
	end
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
SellSoldiersFrame:GetPropertyChangedSignal("Visible"):Connect(function()
	FrameActive = SellSoldiersFrame.Visible

	-- Reset to main view when frame opens
	if FrameActive then
		SellSoldiersFrame.Position = UDim2.fromScale(0.5, 0.5)
		SelectedSoldierID = nil
	end
end)

-- Close button
CloseButton.MouseButton1Click:Connect(function()
	if FrameActive == false then return end
	CloseFrameBindable:Fire(SellSoldiersFrame)
end)

-- Yes button - confirm sale
YesButton.MouseButton1Click:Connect(AttemptSell)

-- No button - cancel and return to main view
NoButton.MouseButton1Click:Connect(function()
	if not SelectedSoldierID then return end
	HideConfirmation()
end)

-- Server response handler
SellSoldierEvent.OnClientEvent:Connect(function(Response: string, PlayerData: table?)
	SellDebounce = false

	if Response == "Sold" and PlayerData then
		-- Successful sale - notify immediately, tween back after brief delay
		NotifyBindable:Fire("Soldier sold!", 0.8, Color3.fromRGB(0, 255, 0))
		UpdateInventory(PlayerData)
		UpdateInventoryBindable:Fire(PlayerData)
		
		task.wait(0.15)
		HideConfirmation()
	elseif Response == "NotFound" then
		NotifyBindable:Fire("Soldier not found!", 0.8, Color3.fromRGB(255, 0, 0))
		HideConfirmation()
	elseif Response == "Active" then
		NotifyBindable:Fire("Deactivate soldier first!", 0.8, Color3.fromRGB(255, 0, 0))
		HideConfirmation()
	elseif Response == "Special" then
		NotifyBindable:Fire("Cannot sell special soldiers!", 0.8, Color3.fromRGB(255, 0, 0))
		HideConfirmation()
	else
		NotifyBindable:Fire("Error selling soldier!", 0.8, Color3.fromRGB(255, 0, 0))
		HideConfirmation()
	end
end)

-- Player data events
LoadPlayerEvent.OnClientEvent:Connect(function(PlayerData: table)
	if LatestData == nil then
		InitializeInventory(PlayerData)
	else
		UpdateInventory(PlayerData)
	end
end)

UpdateInventoryBindable.Event:Connect(UpdateInventory)
