-- // UnlockSlots, written by KingCreoo on 12-08-2025
-- // Manages slot unlocking UI and purchase flow

-- // Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local LoadPlayerEvent: RemoteEvent = Remotes:WaitForChild("LoadPlayer")

-- // Modules
local SETTINGS = require(ReplicatedStorage:WaitForChild("Settings"))
local SOUND_MANAGER = nil

-- // Variables
local LocalPlayer = Players.LocalPlayer
SOUND_MANAGER = require(ReplicatedStorage:WaitForChild("Settings"):WaitForChild("SoundManager"))

local UnlockSlotEvent: RemoteEvent = Remotes:WaitForChild("UnlockSlot")

local ButtonExpandBindable: BindableEvent = Remotes:WaitForChild("ButtonExpand")
local ButtonDeflateBindable: BindableEvent = Remotes:WaitForChild("ButtonDeflate")
local CloseFrameBindable: BindableEvent = Remotes:WaitForChild("CloseFrame")
local NotifyBindable: BindableEvent = Remotes:WaitForChild("NotifyBindable")
local UpdateInventoryBindable: BindableEvent = Remotes:WaitForChild("UpdateInventory")

local LocalGui = LocalPlayer:WaitForChild("PlayerGui")
local FramesGui = LocalGui:WaitForChild("Frames")

local UnlockSlotFrame: Frame = FramesGui:WaitForChild("UnlockSlotFrame")
local MainFrame: Frame = UnlockSlotFrame:WaitForChild("MainFrame")
local YesButton: TextButton = MainFrame:WaitForChild("Yes")
local NoButton: TextButton = MainFrame:WaitForChild("No")
local AmountLabel: TextLabel = MainFrame:WaitForChild("Amount")
local TextLabel: TextLabel = MainFrame:WaitForChild("Text")

-- TODO: Old workspace UnlockSlots model removed in new map. Ring-based unlock UI replaces this.
local UnlockSlotsModel = Workspace:FindFirstChild("UnlockSlots")

local Buttons = {YesButton, NoButton}

local FrameActive = false
local LatestData = nil
local NextSlotToUnlock = nil
local PurchaseDebounce = false

-- // Functions

-- Finds the next credit-priced slot (4-7) the player has not yet unlocked.
-- Lanes 6 and 7 require a rebirth prereq that's still enforced server-side; the UI shows the
-- gate text instead of a purchase prompt when the prereq isn't met (see UpdateDisplay).
local function GetNextSlotToUnlock(PlayerData: table)
	local Unlocks = PlayerData.Plot.Unlocks

	for i = 4, 7 do
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

-- Returns the rebirth requirement for a slot, or nil if none.
local function GetRebirthRequirement(Slot: number): number?
	return SETTINGS.SLOT_REBIRTH_REQUIREMENTS and SETTINGS.SLOT_REBIRTH_REQUIREMENTS[Slot] or nil
end

-- Updates the display with the next slot info. When the next slot is gated on a rebirth
-- the player hasn't reached, the amount label shows "Requires Rebirth N" instead of a price.
local function UpdateDisplay()
	if not NextSlotToUnlock then return end
	if not LatestData then return end

	local Price = SETTINGS.SLOT_PRICES[NextSlotToUnlock]
	TextLabel.Text = "UNLOCK SLOT " .. NextSlotToUnlock

	local RebirthReq = GetRebirthRequirement(NextSlotToUnlock)
	local CurrentRebirths = LatestData.Rebirths or 0
	if RebirthReq and CurrentRebirths < RebirthReq then
		AmountLabel.Text = "Requires Rebirth " .. RebirthReq
	else
		AmountLabel.Text = "$" .. FormatNumber(Price)
	end
end

-- Cleans up when player has all purchasable slots (4-6)
local function CleanupForMaxedPlayer()
	-- Close frame if open
	if UnlockSlotFrame.Visible then
		CloseFrameBindable:Fire(UnlockSlotFrame)
	end
	
	-- TODO: Ring-based unlock UI cleanup goes here when rings are wired.
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

	-- Client-side rebirth prereq check (server re-validates)
	local RebirthReq = GetRebirthRequirement(NextSlotToUnlock)
	local CurrentRebirths = LatestData.Rebirths or 0
	if RebirthReq and CurrentRebirths < RebirthReq then
		NotifyBindable:Fire("Requires Rebirth " .. RebirthReq .. "!", 0.8, Color3.fromRGB(255, 100, 100))
		PurchaseDebounce = false
		return
	end

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
YesButton.MouseButton1Click:Connect(function()
	SOUND_MANAGER:PlayClick()
	AttemptPurchase()
end)

-- No button - close frame
NoButton.MouseButton1Click:Connect(function()
	if FrameActive == false then return end
	SOUND_MANAGER:PlayClick()
	CloseFrameBindable:Fire(UnlockSlotFrame)
end)

-- Server response handler
UnlockSlotEvent.OnClientEvent:Connect(function(Response: string, PlayerData: table?)
	PurchaseDebounce = false
	
	if Response == "Unlocked" and PlayerData then
		-- Successful unlock — cache data, notify, refresh display, and close the frame so the
		-- player has to walk over to the next lane's ring rather than chain-buying from here.
		SOUND_MANAGER:PlayPurchase()
		NotifyBindable:Fire("Slot " .. NextSlotToUnlock .. " unlocked!", 0.8, Color3.fromRGB(0, 255, 0))
		LatestData = PlayerData
		UpdateInventoryBindable:Fire(PlayerData)

		-- Recompute next slot so the display is correct the NEXT time the frame opens
		NextSlotToUnlock = GetNextSlotToUnlock(PlayerData)
		if NextSlotToUnlock then
			UpdateDisplay()
		else
			-- No more credit-priced lanes left; cleanup hook handles any maxed-out UI state
			CleanupForMaxedPlayer()
		end

		-- Always close the frame on success — player must approach the new ring to buy more
		if UnlockSlotFrame.Visible then
			CloseFrameBindable:Fire(UnlockSlotFrame)
		end
	elseif Response == "Insufficient" then
		NotifyBindable:Fire("Insufficient funds!", 0.8, Color3.fromRGB(255, 0, 0))
	elseif Response == "AlreadyUnlocked" then
		NotifyBindable:Fire("Slot already unlocked!", 0.8, Color3.fromRGB(255, 0, 0))
	elseif Response == "MaxSlots" then
		NotifyBindable:Fire("All slots unlocked!", 0.8, Color3.fromRGB(255, 255, 0))
		CleanupForMaxedPlayer()
	elseif Response == "RebirthRequired" then
		-- Server returned this because the lane needs a rebirth the player hasn't done yet
		local Req = GetRebirthRequirement(NextSlotToUnlock or 0) or 1
		NotifyBindable:Fire("Requires Rebirth " .. Req .. "!", 0.8, Color3.fromRGB(255, 100, 100))
	else
		NotifyBindable:Fire("Error unlocking slot!", 0.8, Color3.fromRGB(255, 0, 0))
	end
end)

LoadPlayerEvent.OnClientEvent:Connect(function(PlayerData: table)
	ProcessPlayerData(PlayerData)
end)


