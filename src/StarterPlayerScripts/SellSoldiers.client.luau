-- // SellSoldiers, written by KingCreoo on 12-08-2025
-- // Manages soldier selling UI and confirmation flow

-- // Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local LoadPlayerEvent: RemoteEvent = Remotes:WaitForChild("LoadPlayer")
local GetPlayerDataFunction: RemoteFunction = Remotes:WaitForChild("GetPlayerData")

-- // Modules
local SETTINGS = require(ReplicatedStorage:WaitForChild("Settings"))
local SOUND_MANAGER = nil

-- // Variables
local LocalPlayer = Players.LocalPlayer
SOUND_MANAGER = require(ReplicatedStorage:WaitForChild("Settings"):WaitForChild("SoundManager"))

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
local LabelBar: Frame = SellSoldiersFrame:WaitForChild("LabelBar")
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

-- Applies a soldier's shop color and gradient to a ViewTile
local function ApplyViewTileStyle(ViewTile: Frame, SoldierType: string)
	local Data = SETTINGS.SOLDIER_DATA[SoldierType]
	ViewTile.BackgroundColor3 = Data["ShopColor"]

	local Gradient = ViewTile:FindFirstChildOfClass("UIGradient")
	if not Gradient then
		Gradient = Instance.new("UIGradient")
		Gradient.Parent = ViewTile
	end
	Gradient.Color = ColorSequence.new(Data["ShopGradient1"], Data["ShopGradient2"])
end

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
	ApplyViewTileStyle(ConfirmViewTile, SoldierType)
	AmountLabel.Text = "$" .. SellValue
	ConfirmSoldierLabel.Text = "SELL THIS " .. SoldierName

	-- Tween sell view out (MainFrame + LabelBar + Close)
	TweenService:Create(MainFrame, TweenInfo_Slide, {Position = UDim2.fromScale(0.5, 1.8)}):Play()
	TweenService:Create(LabelBar, TweenInfo_Slide, {Position = UDim2.fromScale(0.5, 1.3)}):Play()
	TweenService:Create(CloseButton, TweenInfo_Slide, {Position = UDim2.fromScale(0.7, 1.3)}):Play()

	-- Tween confirm view in from above
	ConfirmFrame.Visible = true
	ConfirmMainFrame.Position = UDim2.fromScale(0.5, -0.5)
	ConfirmFrame.LabelBar.Position = UDim2.fromScale(0.5, -0.5)
	TweenService:Create(ConfirmMainFrame, TweenInfo_Slide, {Position = UDim2.fromScale(0.5, 0.5)}):Play()
	TweenService:Create(ConfirmFrame.LabelBar, TweenInfo_Slide, {Position = UDim2.fromScale(0.5, 0.162668332)}):Play()
end

-- Tweens the confirm frame out and sell view back in
local function HideConfirmation()
	SelectedSoldierID = nil

	-- Tween confirm view out
	TweenService:Create(ConfirmMainFrame, TweenInfo_Slide, {Position = UDim2.fromScale(0.5, -0.5)}):Play()
	TweenService:Create(ConfirmFrame.LabelBar, TweenInfo_Slide, {Position = UDim2.fromScale(0.5, -0.5)}):Play()

	-- Tween sell view back in
	TweenService:Create(MainFrame, TweenInfo_Slide, {Position = UDim2.fromScale(0.5, 0.5)}):Play()
	TweenService:Create(LabelBar, TweenInfo_Slide, {Position = UDim2.fromScale(0.5, 0.162668332)}):Play()
	TweenService:Create(CloseButton, TweenInfo_Slide, {Position = UDim2.fromScale(0.7, 0.163)}):Play()

	-- Hide confirm frame after tween completes
	task.delay(0.3, function()
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
	ApplyViewTileStyle(ViewTile, SoldierType)
	SoldierFrame.Name = SoldierID

	-- Set layout order based on rating (best soldiers first)
	local Index = IsSoldierActive(PlayerData["Inventory"]["ActiveSoldiers"], SoldierID)
	if Index then
		SoldierFrame.LayoutOrder = 100 + Index
		SoldierFrame:WaitForChild("Active").Visible = true
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

-- Processes player data (called from cached data or future events)
local function ProcessPlayerData(PlayerData: table)
	if LatestData == nil then
		InitializeInventory(PlayerData)
	else
		UpdateInventory(PlayerData)
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
		ConfirmFrame.Visible = false
		MainFrame.Position = UDim2.fromScale(0.5, 0.5)
		LabelBar.Position = UDim2.fromScale(0.5, 0.162668332)
		CloseButton.Position = UDim2.fromScale(0.7, 0.163)
		SelectedSoldierID = nil
	end
end)

-- Close button
CloseButton.MouseButton1Click:Connect(function()
	if FrameActive == false then return end
	SOUND_MANAGER:PlayClick()
	CloseFrameBindable:Fire(SellSoldiersFrame)
end)

-- Yes button - confirm sale
YesButton.MouseButton1Click:Connect(function()
	SOUND_MANAGER:PlayClick()
	AttemptSell()
end)

-- No button - cancel and return to main view
NoButton.MouseButton1Click:Connect(function()
	if not SelectedSoldierID then return end
	SOUND_MANAGER:PlayClick()
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

-- Handle future LoadPlayerEvent fires (reconnects, etc)
LoadPlayerEvent.OnClientEvent:Connect(function(PlayerData: table)
	ProcessPlayerData(PlayerData)
end)

UpdateInventoryBindable.Event:Connect(UpdateInventory)

-- Pull player data from server
ProcessPlayerData(GetPlayerDataFunction:InvokeServer())
