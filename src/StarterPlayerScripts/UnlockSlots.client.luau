-- // UnlockSlots, written by KingCreoo on 12-08-2025
-- // Manages slot unlocking UI and purchase flow

-- // Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

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

local UnlockSlotEvent: RemoteEvent = Remotes:WaitForChild("UnlockSlot")

local ButtonExpandBindable: BindableEvent = Remotes:WaitForChild("ButtonExpand")
local ButtonDeflateBindable: BindableEvent = Remotes:WaitForChild("ButtonDeflate")
local CloseFrameBindable: BindableEvent = Remotes:WaitForChild("CloseFrame")
local NotifyBindable: BindableEvent = Remotes:WaitForChild("NotifyBindable")

local LocalGui = LocalPlayer:WaitForChild("PlayerGui")
local FramesGui = LocalGui:WaitForChild("Frames")

local UnlockSlotFrame: Frame = FramesGui:WaitForChild("UnlockSlotFrame")
local MainFrame: Frame = UnlockSlotFrame:WaitForChild("MainFrame")
local YesButton: TextButton = MainFrame:WaitForChild("Yes")
local NoButton: TextButton = MainFrame:WaitForChild("No")
local AmountLabel: TextLabel = MainFrame:WaitForChild("Amount")
local TextLabel: TextLabel = MainFrame:WaitForChild("Text")

local UnlockSlotsModel = Workspace:WaitForChild("UnlockSlots")

local Buttons = {YesButton, NoButton}

local FrameActive = false
local LatestData = nil
local NextSlotToUnlock = nil
local PurchaseDebounce = false

-- // Functions

-- Finds the next slot (4, 5, or 6) that can be unlocked
local function GetNextSlotToUnlock(PlayerData: table)
	local Unlocks = PlayerData.Plot.Unlocks
	
	for i = 4, 6 do
		if not Unlocks["Slot" .. i] then
			return i
		end
	end
	
	return nil
end

-- Formats number with commas for display
local function FormatNumber(Number: number)
	local Formatted = tostring(Number)
	local K = #Formatted % 3
	if K == 0 then
		K = 3
	end
	
	local Result = string.sub(Formatted, 1, K)
	for i = K + 1, #Formatted, 3 do
		Result = Result .. "," .. string.sub(Formatted, i, i + 2)
	end
	
	return Result
end

-- Updates the display with the next slot info
local function UpdateDisplay()
	if not NextSlotToUnlock then return end
	if not LatestData then return end
	
	local Price = SETTINGS.SLOT_PRICES[NextSlotToUnlock]
	
	TextLabel.Text = "UNLOCK SLOT " .. NextSlotToUnlock
	AmountLabel.Text = "$" .. FormatNumber(Price)
end

-- Cleans up when player has all purchasable slots (4-6)
local function CleanupForMaxedPlayer()
	-- Close frame if open
	if UnlockSlotFrame.Visible then
		CloseFrameBindable:Fire(UnlockSlotFrame)
	end
	
	-- Move the workspace model down instead of destroying
	if UnlockSlotsModel then
		UnlockSlotsModel:SetPrimaryPartCFrame(UnlockSlotsModel:GetPrimaryPartCFrame() * CFrame.new(0, -100, 0))
	end
	
	-- TODO: Check if player has VIP gamepass
	-- If not VIP, show separate VIP advertisement model for slot 7
end

-- Processes player data (called from cached data or future events)
local function ProcessPlayerData(PlayerData: table)
	LatestData = PlayerData
	NextSlotToUnlock = GetNextSlotToUnlock(PlayerData)
	
	if NextSlotToUnlock then
		-- Player has slots to unlock, update display
		UpdateDisplay()
	else
		-- Player already has all purchasable slots (4-6)
		-- TODO: Check if player has VIP gamepass for slot 7 advertisement
		CleanupForMaxedPlayer()
	end
end

-- Attempts to purchase the next slot
local function AttemptPurchase()
	if PurchaseDebounce then
		NotifyBindable:Fire("Slow down!", 0.8, Color3.fromRGB(255, 0, 0))
		return
	end
	
	-- Check if data has loaded yet
	if not LatestData then
		NotifyBindable:Fire("Loading...", 0.8, Color3.fromRGB(255, 255, 0))
		return
	end
	
	if not NextSlotToUnlock then
		NotifyBindable:Fire("All slots unlocked!", 0.8, Color3.fromRGB(255, 255, 0))
		return
	end
	
	PurchaseDebounce = true
	
	-- Client-side fund check
	local Price = SETTINGS.SLOT_PRICES[NextSlotToUnlock]
	if LocalPlayer:WaitForChild("leaderstats"):WaitForChild("Credits").Value < Price then
		NotifyBindable:Fire("Insufficient funds!", 0.8, Color3.fromRGB(255, 0, 0))
		PurchaseDebounce = false
		return
	end
	
	-- Fire server to process purchase
	UnlockSlotEvent:FireServer()
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
UnlockSlotFrame:GetPropertyChangedSignal("Visible"):Connect(function()
	FrameActive = UnlockSlotFrame.Visible
end)

-- Yes button - attempt purchase
YesButton.MouseButton1Click:Connect(AttemptPurchase)

-- No button - close frame
NoButton.MouseButton1Click:Connect(function()
	if FrameActive == false then return end
	CloseFrameBindable:Fire(UnlockSlotFrame)
end)

-- Server response handler
UnlockSlotEvent.OnClientEvent:Connect(function(Response: string, PlayerData: table?)
	PurchaseDebounce = false
	
	if Response == "Unlocked" and PlayerData then
		-- Successful unlock
		NotifyBindable:Fire("Slot " .. NextSlotToUnlock .. " unlocked!", 0.8, Color3.fromRGB(0, 255, 0))
		LatestData = PlayerData
		
		-- Check for next slot
		NextSlotToUnlock = GetNextSlotToUnlock(PlayerData)
		
		if NextSlotToUnlock then
			-- More slots available, update display
			UpdateDisplay()
		else
			-- All purchasable slots unlocked
			task.wait(0.15)
			CleanupForMaxedPlayer()
		end
	elseif Response == "Insufficient" then
		NotifyBindable:Fire("Insufficient funds!", 0.8, Color3.fromRGB(255, 0, 0))
	elseif Response == "AlreadyUnlocked" then
		NotifyBindable:Fire("Slot already unlocked!", 0.8, Color3.fromRGB(255, 0, 0))
	elseif Response == "MaxSlots" then
		NotifyBindable:Fire("All slots unlocked!", 0.8, Color3.fromRGB(255, 255, 0))
		CleanupForMaxedPlayer()
	elseif Response == "VIPRequired" then
		NotifyBindable:Fire("VIP required for slot 7!", 0.8, Color3.fromRGB(255, 255, 0))
		-- TODO: Prompt VIP gamepass purchase
	else
		NotifyBindable:Fire("Error unlocking slot!", 0.8, Color3.fromRGB(255, 0, 0))
	end
end)

-- Handle future LoadPlayerEvent fires (reconnects, etc)
LoadPlayerEvent.OnClientEvent:Connect(function(PlayerData: table)
	ProcessPlayerData(PlayerData)
end)

-- Process cached data if event fired before we finished initializing
if CachedPlayerData then
	ProcessPlayerData(CachedPlayerData)
end
