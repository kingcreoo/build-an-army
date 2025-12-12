-- // RobuxStore, initialized by KingCreoo on 12-11-2025
-- // Manages the Robux Store GUI with switchable panes for Credits, Soldiers, and Passes

-- // Services
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- // Variables
local LocalPlayer = Players.LocalPlayer
local SOUND_MANAGER = require(ReplicatedStorage:WaitForChild("Settings"):WaitForChild("SoundManager"))
local LocalGui = LocalPlayer:WaitForChild("PlayerGui")

local FramesGui: ScreenGui = LocalGui:WaitForChild("Frames")
local StoreFrame: Frame = FramesGui:WaitForChild("StoreFrame")

local PanesFolder: Folder = StoreFrame:WaitForChild("Panes")
local CreditsPane: Frame = PanesFolder:WaitForChild("CreditsPane")
local SoldierPane: Frame = PanesFolder:WaitForChild("SoldierPane")
local PassesPane: Frame = PanesFolder:WaitForChild("PassesPane")

local ButtonsFolder: Folder = StoreFrame:WaitForChild("Buttons")
local CreditsButton: TextButton = ButtonsFolder:WaitForChild("Credits")
local SoldiersButton: TextButton = ButtonsFolder:WaitForChild("Soldiers")
local PassesButton: TextButton = ButtonsFolder:WaitForChild("Passes")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local OpenStoreBindable: BindableEvent = Remotes:WaitForChild("OpenStoreBindable")
local HUDBindable: BindableEvent = Remotes:WaitForChild("HUDBindable")

-- State management
local StoreFrameActive = false
local ActivePane = nil
local ActiveButton = nil
local ButtonHoverStates = {}

-- Mapping tables
local PaneMap = {
	[CreditsButton] = CreditsPane,
	[SoldiersButton] = SoldierPane,
	[PassesButton] = PassesPane
}

local ButtonMap = {
	[CreditsPane] = CreditsButton,
	[SoldierPane] = SoldiersButton,
	[PassesPane] = PassesButton
}

-- TweenInfo definitions
local StoreTweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
local StoreCloseTweenInfo = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
local PaneTweenInfo = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
local PaneCloseTweenInfo = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
local ButtonScaleTweenInfo = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
local PulseTweenInfo = TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
local ShrinkTweenInfo = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local PaneFadeTweenInfo = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)

-- // Functions

-- Scale button to 1.2x to show active state
local function SetButtonActive(Button: TextButton)
	local OriginSize: UDim2 = Button:GetAttribute("OriginSize")
	local ActiveSize: UDim2 = UDim2.fromScale(OriginSize.X.Scale * 1.2, OriginSize.Y.Scale * 1.2)
	
	-- Reset hover state for this button
	ButtonHoverStates[Button] = false
	
	local ScaleTween = TweenService:Create(Button, ButtonScaleTweenInfo, {Size = ActiveSize})
	ScaleTween:Play()
	
	ActiveButton = Button
end

-- Return button to normal 1.0x scale
local function SetButtonInactive(Button: TextButton)
	local OriginSize: UDim2 = Button:GetAttribute("OriginSize")
	
	local ScaleTween = TweenService:Create(Button, ButtonScaleTweenInfo, {Size = OriginSize})
	ScaleTween:Play()
end

-- Open a specific pane with tween animation
local function OpenPane(Pane: Frame, Button: TextButton)
	Pane.Visible = true
	Pane.Size = UDim2.fromScale(0, 0)
	
	local PaneTween = TweenService:Create(Pane, PaneTweenInfo, {Size = UDim2.fromScale(1, 1)})
	PaneTween:Play()
	
	ActivePane = Pane
	SetButtonActive(Button)
end

-- Close a pane with tween animation
local function ClosePane(Pane: Frame)
	local CloseTween = TweenService:Create(Pane, PaneCloseTweenInfo, {Size = UDim2.fromScale(0, 0)})
	CloseTween:Play()
	
	CloseTween.Completed:Connect(function()
		Pane.Visible = false
	end)
	
	return 0.15
end

-- Switch from current pane to a new pane
local function SwitchPane(NewButton: TextButton)
	local NewPane = PaneMap[NewButton]
	
	if NewPane == ActivePane then
		return
	end
	
	-- Immediately update button states
	if ActiveButton then
		SetButtonInactive(ActiveButton)
	end
	SetButtonActive(NewButton)
	
	-- Close old pane
	if ActivePane then
		local AnimationDuration = ClosePane(ActivePane)
		task.wait(AnimationDuration)
	end
	
	-- Open new pane
	OpenPane(NewPane, NewButton)
end

-- Open the entire store from HUD with specific pane active
local function OpenStore(TargetPane: Frame)
	-- Setup panes visibility
	CreditsPane.Visible = false
	SoldierPane.Visible = false
	PassesPane.Visible = false
	
	TargetPane.Visible = true
	TargetPane.Size = UDim2.fromScale(1, 1)
	
	-- Setup button states
	local TargetButton = ButtonMap[TargetPane]
	
	-- Set all buttons to normal size
	for Button, _ in pairs(PaneMap) do
		local OriginSize = Button:GetAttribute("OriginSize")
		Button.Size = OriginSize
	end
	
	-- Set target button to active size
	local TargetOriginSize = TargetButton:GetAttribute("OriginSize")
	TargetButton.Size = UDim2.fromScale(TargetOriginSize.X.Scale * 1.2, TargetOriginSize.Y.Scale * 1.2)
	
	-- Close HUD via bindable
	HUDBindable:Fire("Close")
	
	-- Open StoreFrame
	StoreFrame.Visible = true
	StoreFrame.Size = UDim2.fromScale(0, 0)
	
	local StoreTween = TweenService:Create(StoreFrame, StoreTweenInfo, {Size = UDim2.fromScale(1, 1)})
	StoreTween:Play()
	
	-- Set state
	StoreFrameActive = true
	ActivePane = TargetPane
	ActiveButton = TargetButton
end

-- Close the entire store and return to HUD
local function CloseStore()
	-- Reset button states
	if ActiveButton then
		SetButtonInactive(ActiveButton)
		ActiveButton = nil
	end
	
	-- Keep active pane at full size, don't tween it at all
	
	-- Close StoreFrame
	local CloseTween = TweenService:Create(StoreFrame, StoreCloseTweenInfo, {Size = UDim2.fromScale(0, 0)})
	CloseTween:Play()
	
	CloseTween.Completed:Connect(function()
		StoreFrame.Visible = false
		
		-- Hide active pane after store is fully closed
		if ActivePane then
			ActivePane.Visible = false
			ActivePane = nil
		end
		
		StoreFrameActive = false
		
		-- Reopen HUD via bindable
		HUDBindable:Fire("Open")
	end)
end

-- // Initialization

-- Set OriginSize attributes for all buttons
local AllButtons = {CreditsButton, SoldiersButton, PassesButton}
for _, Button in pairs(AllButtons) do
	if not Button:GetAttribute("OriginSize") then
		Button:SetAttribute("OriginSize", Button.Size)
	end
end

-- Setup hover pulse animations
for _, Button in pairs(AllButtons) do
	local OriginSize = Button:GetAttribute("OriginSize")
	local PulseSize = UDim2.fromScale(OriginSize.X.Scale * 1.15, OriginSize.Y.Scale * 1.15)
	
	-- Initialize hover state for this button
	ButtonHoverStates[Button] = false
	
	local PulseTween, ShrinkTween = nil, nil
	
	local function StartPulse()
		if PulseTween then
			PulseTween:Cancel()
		end
		PulseTween = TweenService:Create(Button, PulseTweenInfo, {Size = PulseSize})
		PulseTween:Play()
	end
	
	local function StopPulse()
		if PulseTween then
			PulseTween:Cancel()
			PulseTween = nil
		end
		if ShrinkTween then
			ShrinkTween:Cancel()
		end
		ShrinkTween = TweenService:Create(Button, ShrinkTweenInfo, {Size = OriginSize})
		ShrinkTween:Play()
	end
	
	Button.MouseEnter:Connect(function()
		if Button == ActiveButton then return end
		if not StoreFrameActive then return end
		if ButtonHoverStates[Button] then return end
		ButtonHoverStates[Button] = true
		StartPulse()
	end)
	
	Button.MouseLeave:Connect(function()
		if Button == ActiveButton then return end
		ButtonHoverStates[Button] = false
		StopPulse()
	end)
end

-- Initialize visibility
StoreFrame.Visible = false
CreditsPane.Visible = false
SoldierPane.Visible = false
PassesPane.Visible = false

-- // Event Connections

-- Internal button clicks (switch panes)
CreditsButton.MouseButton1Click:Connect(function()
	if not StoreFrameActive then return end
	SOUND_MANAGER:PlayClick()
	SwitchPane(CreditsButton)
end)

SoldiersButton.MouseButton1Click:Connect(function()
	if not StoreFrameActive then return end
	SOUND_MANAGER:PlayClick()
	SwitchPane(SoldiersButton)
end)

PassesButton.MouseButton1Click:Connect(function()
	if not StoreFrameActive then return end
	SOUND_MANAGER:PlayClick()
	SwitchPane(PassesButton)
end)

-- Close buttons (close entire store)
CreditsPane:WaitForChild("Close").MouseButton1Click:Connect(function()
	if not StoreFrameActive then return end
	SOUND_MANAGER:PlayClick()
	CloseStore()
end)

SoldierPane:WaitForChild("Close").MouseButton1Click:Connect(function()
	if not StoreFrameActive then return end
	SOUND_MANAGER:PlayClick()
	CloseStore()
end)

PassesPane:WaitForChild("Close").MouseButton1Click:Connect(function()
	if not StoreFrameActive then return end
	SOUND_MANAGER:PlayClick()
	CloseStore()
end)

-- Store opening from HUD
OpenStoreBindable.Event:Connect(function(PaneName: string)
	local TargetPane
	
	if PaneName == "Credits" then
		TargetPane = CreditsPane
	elseif PaneName == "Soldiers" then
		TargetPane = SoldierPane
	elseif PaneName == "Passes" then
		TargetPane = PassesPane
	end
	
	if TargetPane then
		OpenStore(TargetPane)
	end
end)
