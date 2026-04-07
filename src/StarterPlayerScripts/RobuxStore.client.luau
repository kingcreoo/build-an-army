-- // RobuxStore, initialized by KingCreoo on 12-11-2025
-- // Manages the Robux Store GUI with switchable panes for Cash, Soldiers, and Passes

-- // Services
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- // Variables
local LocalPlayer = Players.LocalPlayer
local SETTINGS = require(ReplicatedStorage:WaitForChild("Settings"))
local SOUND_MANAGER = require(ReplicatedStorage:WaitForChild("Settings"):WaitForChild("SoundManager"))
local TRANSACTION_CLIENT = require(script.Parent:WaitForChild("TransactionClient"))
local LocalGui = LocalPlayer:WaitForChild("PlayerGui")

local FramesGui: ScreenGui = LocalGui:WaitForChild("Frames")
local StoreFrame: Frame = FramesGui:WaitForChild("StoreFrame")

local PanesFolder: Folder = StoreFrame:WaitForChild("Panes")
local CashPane: Frame = PanesFolder:WaitForChild("CashPane")
local SoldierPane: Frame = PanesFolder:WaitForChild("SoldierPane")
local PassesPane: Frame = PanesFolder:WaitForChild("PassesPane")

-- Each nav button is now a Frame containing a child Button (TextButton) for clicks.
-- Hover animations run on the Frame; clicks are detected on Frame.Button.
local ButtonsFolder: Folder = StoreFrame:WaitForChild("Buttons")
local CashFrame: Frame = ButtonsFolder:WaitForChild("Cash")
local SoldiersFrame: Frame = ButtonsFolder:WaitForChild("Soldiers")
local PassesFrame: Frame = ButtonsFolder:WaitForChild("Passes")

local CashButton: TextButton = CashFrame:WaitForChild("Button")
local SoldiersButton: TextButton = SoldiersFrame:WaitForChild("Button")
local PassesButton: TextButton = PassesFrame:WaitForChild("Button")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local OpenStoreBindable: BindableEvent = Remotes:WaitForChild("OpenStoreBindable")
local HUDBindable: BindableEvent = Remotes:WaitForChild("HUDBindable")
local ButtonExpandBindable: BindableEvent = Remotes:WaitForChild("ButtonExpand")
local ButtonDeflateBindable: BindableEvent = Remotes:WaitForChild("ButtonDeflate")

-- State management
local StoreFrameActive = false
local ActivePane = nil
local ActiveFrame = nil
local FrameHoverStates = {}

-- Maps each nav Frame to the pane it opens, and each pane back to its Frame
local PaneMap = {
	[CashFrame] = CashPane,
	[SoldiersFrame] = SoldierPane,
	[PassesFrame] = PassesPane
}

local FrameMap = {
	[CashPane] = CashFrame,
	[SoldierPane] = SoldiersFrame,
	[PassesPane] = PassesFrame
}

-- TweenInfo definitions
local StoreTweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
local StoreCloseTweenInfo = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
local FrameScaleTweenInfo = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
local PulseTweenInfo = TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
local ShrinkTweenInfo = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local PaneFadeInInfo = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local PaneFadeOutInfo = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.In)

-- Cache of original transparency values per pane descendant, built on script init
local PaneTransparencyCache = {}

-- // Functions

-- Returns the list of transparency-like property names applicable to a given instance
local function GetTransparencyProps(Instance: Instance): {string}
	local Props = {}
	if Instance:IsA("GuiObject") then
		table.insert(Props, "BackgroundTransparency")
	end
	if Instance:IsA("TextLabel") or Instance:IsA("TextButton") or Instance:IsA("TextBox") then
		table.insert(Props, "TextTransparency")
		table.insert(Props, "TextStrokeTransparency")
	end
	if Instance:IsA("ImageLabel") or Instance:IsA("ImageButton") then
		table.insert(Props, "ImageTransparency")
	end
	if Instance:IsA("UIStroke") then
		table.insert(Props, "Transparency")
	end
	return Props
end

-- Records the opaque (original) transparency values for a pane and all its descendants
local function CachePaneTransparencies(Pane: Instance)
	local Cache = {}

	local function Visit(Inst: Instance)
		local Props = GetTransparencyProps(Inst)
		if #Props == 0 then return end
		Cache[Inst] = {}
		for _, Prop in ipairs(Props) do
			Cache[Inst][Prop] = (Inst :: any)[Prop]
		end
	end

	Visit(Pane)
	for _, Descendant in ipairs(Pane:GetDescendants()) do
		Visit(Descendant)
	end

	PaneTransparencyCache[Pane] = Cache
end

-- Snaps a pane to fully visible or fully hidden without tweening
local function SetPaneTransparencyInstant(Pane: Frame, Hidden: boolean)
	-- Use GroupTransparency when the pane is a CanvasGroup (one property, all descendants)
	if Pane:IsA("CanvasGroup") then
		(Pane :: any).GroupTransparency = Hidden and 1 or 0
		return
	end

	local Cache = PaneTransparencyCache[Pane]
	if not Cache then return end
	for Inst, Props in pairs(Cache) do
		for Prop, Original in pairs(Props) do
			(Inst :: any)[Prop] = Hidden and 1 or Original
		end
	end
end

-- Fades a pane to the target state (Hidden true = fade to invisible, false = fade to original)
local function FadePane(Pane: Frame, Hidden: boolean, Info: TweenInfo): number
	-- CanvasGroup fast path
	if Pane:IsA("CanvasGroup") then
		TweenService:Create(Pane, Info, {GroupTransparency = Hidden and 1 or 0}):Play()
		return Info.Time
	end

	local Cache = PaneTransparencyCache[Pane]
	if not Cache then return 0 end

	for Inst, Props in pairs(Cache) do
		for Prop, Original in pairs(Props) do
			local Target = Hidden and 1 or Original
			TweenService:Create(Inst, Info, {[Prop] = Target}):Play()
		end
	end
	return Info.Time
end

-- Scale a nav frame to 1.2x to show active state
local function SetFrameActive(Frame: Frame)
	local OriginSize: UDim2 = Frame:GetAttribute("OriginSize")
	local ActiveSize: UDim2 = UDim2.fromScale(OriginSize.X.Scale * 1.2, OriginSize.Y.Scale * 1.2)

	-- Reset hover state for this frame
	FrameHoverStates[Frame] = false

	local ScaleTween = TweenService:Create(Frame, FrameScaleTweenInfo, {Size = ActiveSize})
	ScaleTween:Play()

	ActiveFrame = Frame
end

-- Return nav frame to normal 1.0x scale
local function SetFrameInactive(Frame: Frame)
	local OriginSize: UDim2 = Frame:GetAttribute("OriginSize")

	local ScaleTween = TweenService:Create(Frame, FrameScaleTweenInfo, {Size = OriginSize})
	ScaleTween:Play()
end

-- Open a specific pane with fade-in
local function OpenPane(Pane: Frame, Frame: Frame)
	SetPaneTransparencyInstant(Pane, true)
	Pane.Visible = true
	FadePane(Pane, false, PaneFadeInInfo)

	ActivePane = Pane
	SetFrameActive(Frame)
end

-- Close a pane with fade-out, returns the fade duration so callers can sequence animations
local function ClosePane(Pane: Frame): number
	local Duration = FadePane(Pane, true, PaneFadeOutInfo)

	task.delay(Duration, function()
		if Pane ~= ActivePane then
			Pane.Visible = false
		end
	end)

	return Duration
end

-- Switch from current pane to a new pane
local function SwitchPane(NewFrame: Frame)
	local NewPane = PaneMap[NewFrame]

	if NewPane == ActivePane then
		return
	end

	-- Immediately update nav frame states
	if ActiveFrame then
		SetFrameInactive(ActiveFrame)
	end
	SetFrameActive(NewFrame)

	-- Close old pane
	local OldPane = ActivePane
	if OldPane then
		local Duration = ClosePane(OldPane)
		task.wait(Duration)
		OldPane.Visible = false
	end

	-- Open new pane
	OpenPane(NewPane, NewFrame)
end

-- Open the entire store from HUD with specific pane active
local function OpenStore(TargetPane: Frame)
	-- Setup panes visibility: target visible + opaque, others hidden
	for Pane, _ in pairs(FrameMap) do
		if Pane == TargetPane then
			SetPaneTransparencyInstant(Pane, false)
			Pane.Visible = true
		else
			Pane.Visible = false
		end
	end

	-- Setup nav frame states
	local TargetFrame = FrameMap[TargetPane]

	-- Set all nav frames to normal size
	for Frame, _ in pairs(PaneMap) do
		local OriginSize = Frame:GetAttribute("OriginSize")
		Frame.Size = OriginSize
	end

	-- Set target nav frame to active size
	local TargetOriginSize = TargetFrame:GetAttribute("OriginSize")
	TargetFrame.Size = UDim2.fromScale(TargetOriginSize.X.Scale * 1.2, TargetOriginSize.Y.Scale * 1.2)

	-- Close HUD via bindable
	HUDBindable:Fire("Close")

	-- Open StoreFrame (outer tween stays as size)
	StoreFrame.Visible = true
	StoreFrame.Size = UDim2.fromScale(0, 0)

	local StoreTween = TweenService:Create(StoreFrame, StoreTweenInfo, {Size = UDim2.fromScale(1, 1)})
	StoreTween:Play()

	-- Set state
	StoreFrameActive = true
	ActivePane = TargetPane
	ActiveFrame = TargetFrame
end

-- Close the entire store and return to HUD
local function CloseStore()
	-- Reset nav frame states
	if ActiveFrame then
		SetFrameInactive(ActiveFrame)
		ActiveFrame = nil
	end

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

-- Set OriginSize attributes for all nav frames
local AllFrames = {CashFrame, SoldiersFrame, PassesFrame}
for _, Frame in pairs(AllFrames) do
	if not Frame:GetAttribute("OriginSize") then
		Frame:SetAttribute("OriginSize", Frame.Size)
	end
end

-- Cache pane transparencies for fade animations
CachePaneTransparencies(CashPane)
CachePaneTransparencies(SoldierPane)
CachePaneTransparencies(PassesPane)

-- Apply ProductId/ProductType attributes to cash pack purchase buttons from SETTINGS
local function ApplyProductAttributes(Btn: GuiButton, ProductId: number, ProductType: string)
	Btn:SetAttribute("ProductId", ProductId)
	Btn:SetAttribute("ProductType", ProductType)
end

local CashPurchases = CashPane:WaitForChild("Purchases")
for _, PackInfo in pairs(SETTINGS.CASH_PACKS) do
	local FrameName = tostring(PackInfo["Credits"])
	local ItemFrame = CashPurchases:FindFirstChild(FrameName)
	if not ItemFrame then continue end

	local ProductId = PackInfo["ProductId"]
	if not ProductId or ProductId == 0 then continue end

	-- Apply to both the image Button and the Purchase button
	local ImageBtn = ItemFrame:FindFirstChild("Button")
	local PurchaseBtn = ItemFrame:FindFirstChild("Purchase")
	if ImageBtn then ApplyProductAttributes(ImageBtn, ProductId, "DevProduct") end
	if PurchaseBtn then ApplyProductAttributes(PurchaseBtn, ProductId, "DevProduct") end
end

-- Apply ProductId/ProductType attributes to premium soldier purchase buttons from SETTINGS
local SoldierPurchases = SoldierPane:WaitForChild("Purchases")
for _, SoldierName in ipairs(SETTINGS.PREMIUM_ORDER) do
	local Data = SETTINGS.SOLDIER_DATA[SoldierName]
	if not Data or not Data["RobuxProductId"] then continue end

	-- Frame names in Studio have no spaces (e.g. "HyperSniper", "ShadowOps")
	local FrameName = string.gsub(SoldierName, " ", "")
	local ItemFrame = SoldierPurchases:FindFirstChild(FrameName)
	if not ItemFrame then continue end

	local ProductId = Data["RobuxProductId"]
	local ImageBtn = ItemFrame:FindFirstChild("Button")
	local PurchaseBtn = ItemFrame:FindFirstChild("Purchase")
	if ImageBtn then ApplyProductAttributes(ImageBtn, ProductId, "DevProduct") end
	if PurchaseBtn then ApplyProductAttributes(PurchaseBtn, ProductId, "DevProduct") end
end

local PassesPurchases = PassesPane:WaitForChild("Purchases")
local CommanderPassFrame = PassesPurchases:FindFirstChild("CommanderPass")
if CommanderPassFrame and SETTINGS.COMMANDER_PASS and SETTINGS.COMMANDER_PASS.ProductId then
	local ProductId = SETTINGS.COMMANDER_PASS.ProductId
	local ImageBtn = CommanderPassFrame:FindFirstChild("Button")
	local PurchaseBtn = CommanderPassFrame:FindFirstChild("Purchase")
	if ImageBtn and ImageBtn:IsA("GuiButton") then ApplyProductAttributes(ImageBtn, ProductId, "Gamepass") end
	if PurchaseBtn and PurchaseBtn:IsA("GuiButton") then ApplyProductAttributes(PurchaseBtn, ProductId, "Gamepass") end
end

-- Wire purchase buttons in each pane
TRANSACTION_CLIENT.BindDescendants(CashPurchases)
TRANSACTION_CLIENT.BindDescendants(SoldierPurchases)
TRANSACTION_CLIENT.BindDescendants(PassesPurchases)

-- Wire hover expand on all interactive buttons inside each pane's Purchases folder
local function BindPurchaseHover(PurchasesFolder: Folder)
	for _, ItemFrame in ipairs(PurchasesFolder:GetChildren()) do
		if not ItemFrame:IsA("Frame") then continue end

		-- Find the clickable button (named "Button" or "Purchase")
		local Btn = ItemFrame:FindFirstChild("Purchase") or ItemFrame:FindFirstChild("Button")
		if not Btn or not Btn:IsA("GuiButton") then continue end

		-- Cache OriginSize if not set
		if not Btn:GetAttribute("OriginSize") then
			Btn:SetAttribute("OriginSize", Btn.Size)
		end

		Btn.MouseEnter:Connect(function()
			if not StoreFrameActive then return end
			ButtonExpandBindable:Fire(Btn, 1.1)
		end)
		Btn.MouseLeave:Connect(function()
			ButtonDeflateBindable:Fire(Btn)
		end)
	end
end

BindPurchaseHover(CashPane:WaitForChild("Purchases"))
BindPurchaseHover(SoldierPane:WaitForChild("Purchases"))
BindPurchaseHover(PassesPurchases)

-- Setup hover pulse animations on each nav frame
for _, Frame in pairs(AllFrames) do
	local OriginSize = Frame:GetAttribute("OriginSize")
	local PulseSize = UDim2.fromScale(OriginSize.X.Scale * 1.15, OriginSize.Y.Scale * 1.15)

	-- Initialize hover state for this frame
	FrameHoverStates[Frame] = false

	local PulseTween, ShrinkTween = nil, nil

	local function StartPulse()
		if PulseTween then
			PulseTween:Cancel()
		end
		PulseTween = TweenService:Create(Frame, PulseTweenInfo, {Size = PulseSize})
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
		ShrinkTween = TweenService:Create(Frame, ShrinkTweenInfo, {Size = OriginSize})
		ShrinkTween:Play()
	end

	-- Hover is detected on the frame itself, not the inner button
	Frame.MouseEnter:Connect(function()
		if Frame == ActiveFrame then return end
		if not StoreFrameActive then return end
		if FrameHoverStates[Frame] then return end
		FrameHoverStates[Frame] = true
		StartPulse()
	end)

	Frame.MouseLeave:Connect(function()
		if Frame == ActiveFrame then return end
		FrameHoverStates[Frame] = false
		StopPulse()
	end)
end

-- Wire hover expand on close buttons
for _, Pane in ipairs({CashPane, SoldierPane, PassesPane}) do
	local CloseBtn = Pane:FindFirstChild("Close")
	if CloseBtn and CloseBtn:IsA("GuiButton") then
		if not CloseBtn:GetAttribute("OriginSize") then
			CloseBtn:SetAttribute("OriginSize", CloseBtn.Size)
		end
		CloseBtn.MouseEnter:Connect(function()
			if not StoreFrameActive then return end
			ButtonExpandBindable:Fire(CloseBtn, 1.1)
		end)
		CloseBtn.MouseLeave:Connect(function()
			ButtonDeflateBindable:Fire(CloseBtn)
		end)
	end
end

-- Initialize visibility
StoreFrame.Visible = false
CashPane.Visible = false
SoldierPane.Visible = false
PassesPane.Visible = false

-- // Event Connections

-- Internal nav button clicks (switch panes). Clicks fire on the inner child button.
CashButton.MouseButton1Click:Connect(function()
	if not StoreFrameActive then return end
	SOUND_MANAGER:PlayClick()
	SwitchPane(CashFrame)
end)

SoldiersButton.MouseButton1Click:Connect(function()
	if not StoreFrameActive then return end
	SOUND_MANAGER:PlayClick()
	SwitchPane(SoldiersFrame)
end)

PassesButton.MouseButton1Click:Connect(function()
	if not StoreFrameActive then return end
	SOUND_MANAGER:PlayClick()
	SwitchPane(PassesFrame)
end)

-- Close buttons (close entire store)
CashPane:WaitForChild("Close").MouseButton1Click:Connect(function()
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

	-- "Credits" key remains for backward compatibility with the HUD's existing button names;
	-- will be renamed to "Cash" alongside the full credits->cash rename later.
	if PaneName == "Credits" or PaneName == "Cash" then
		TargetPane = CashPane
	elseif PaneName == "Soldiers" then
		TargetPane = SoldierPane
	elseif PaneName == "Passes" then
		TargetPane = PassesPane
	end

	if TargetPane then
		OpenStore(TargetPane)
	end
end)
