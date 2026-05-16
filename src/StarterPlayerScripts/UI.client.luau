-- // UI, initialized by KingCreoo on 9-6-2025
-- // Manages UI functions for the client :)

-- // Services
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- // Variables
local LocalPlayer = Players.LocalPlayer
local SOUND_MANAGER = nil
local LocalGui = LocalPlayer:WaitForChild("PlayerGui")

local function GetClickableButton(Target: Instance): GuiButton
    if Target:IsA("GuiButton") then
        return Target
    end

    return Target:WaitForChild("Button") :: GuiButton
end

local HUD: ScreenGui = LocalGui:WaitForChild("HUD")
local SoldiersButton: TextButton = HUD:WaitForChild("Soldiers")
local SettingsButton: TextButton = HUD:WaitForChild("Settings")
local CreditsButton: TextButton = HUD:WaitForChild("CreditsButton")
local CreditsText: TextLabel = HUD:WaitForChild("CreditsText")
local StoreContainer: GuiObject = HUD:WaitForChild("Store")
local CommanderPassHUD: GuiObject = HUD:WaitForChild("CommanderPass")
local TeleportsDisplay: GuiObject = HUD:WaitForChild("TeleportsDisplay")
local TeleportHomeButton: TextButton = TeleportsDisplay:WaitForChild("Home"):WaitForChild("Button")
local TeleportShopButton: TextButton = TeleportsDisplay:WaitForChild("Shop"):WaitForChild("Button")
local StoreButton: GuiButton = GetClickableButton(StoreContainer)
local CommanderPassHUDButton: GuiButton = GetClickableButton(CommanderPassHUD)

local FramesGui: ScreenGui = LocalGui:WaitForChild("Frames")
local SoldierShopFrame: Frame = FramesGui:WaitForChild("SoldierShop")
local SoldierInventoryFrame: Frame = FramesGui:WaitForChild("SoldierInventory")
local SettingsFrame: Frame = FramesGui:WaitForChild("SettingsFrame")
local UpgradeTargetFrame: Frame = FramesGui:WaitForChild("UpgradeTargetFrame")
local SellSoldiersFrame: Frame = FramesGui:WaitForChild("SellSoldiersFrame")
local UnlockSlotFrame: Frame = FramesGui:WaitForChild("UnlockSlotFrame")
local StarterPackFrame: Frame = FramesGui:WaitForChild("StarterPackFrame")
local CommanderPassFrame: Frame = FramesGui:WaitForChild("CommanderPassFrame")
local BoostTreeFrame: Frame = FramesGui:WaitForChild("BoostTreeFrame")

local IdleRewardsFrame: Frame = FramesGui:WaitForChild("IdleRewardsFrame")
local IdleRewardsAmount: TextLabel = IdleRewardsFrame:WaitForChild("MainFrame"):WaitForChild("Amount")
--local IdleRewardsHours: TextLabel = IdleRewardsFrame:WaitForChild("MainFrame"):WaitForChild("Hours")
--local IdleRewardsPercent: TextLabel = IdleRewardsFrame:WaitForChild("MainFrame"):WaitForChild("Percent")
local IdleRewardsClaimButton: TextButton = IdleRewardsFrame:WaitForChild("MainFrame"):WaitForChild("Claim")

local NotificationFrame: Frame = FramesGui:WaitForChild("NotificationFrame")
local TemplateNotification: TextLabel = NotificationFrame:WaitForChild("TemplateNotification")

local PromptedFrames = {SoldierShopFrame, UpgradeTargetFrame, SellSoldiersFrame, UnlockSlotFrame, BoostTreeFrame}
local PromptedFrameDebounces = {SoldierShopFrame = false, UpgradeTargetFrame = false, SellSoldiersFrame = false, UnlockSlotFrame = false, BoostTreeFrame = false}

local HUDButtons = {SoldiersButton}
local HUDButtonsPulse = {StoreContainer, SettingsButton, CreditsButton, CommanderPassHUD}
local HUDElements = {SoldiersButton, SettingsButton, CommanderPassHUD, StoreContainer, CreditsButton, CreditsText, TeleportsDisplay}

for _, Element in ipairs(HUDElements) do
    if Element:IsA("GuiObject") and not Element:GetAttribute("OriginSize") then
        Element:SetAttribute("OriginSize", Element.Size)
    end
end

local ExpansionTweenInfo = TweenInfo.new(.25, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
local DeflationTweenInfo = TweenInfo.new(.075, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
local OpenTweenInfo = TweenInfo.new(.3, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
local CloseTweenInfo = TweenInfo.new(.1, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local SETTINGS = require(ReplicatedStorage:WaitForChild("Settings"))
SOUND_MANAGER = require(ReplicatedStorage:WaitForChild("Settings"):WaitForChild("SoundManager"))

local ButtonExpandBindable: BindableEvent = Remotes:WaitForChild("ButtonExpand")
local ButtonDeflateBindable: BindableEvent = Remotes:WaitForChild("ButtonDeflate")
local CloseFrameBindable: BindableEvent = Remotes:WaitForChild("CloseFrame")
local NotifyBindable: BindableEvent = Remotes:WaitForChild("NotifyBindable")
local IdleRewardsEvent: RemoteEvent = Remotes:WaitForChild("IdleRewards")
local LoadPlayerEvent: RemoteEvent = Remotes:WaitForChild("LoadPlayer")
local OpenStoreBindable: BindableEvent = Remotes:WaitForChild("OpenStoreBindable")
local HUDBindable: BindableEvent = Remotes:WaitForChild("HUDBindable")
local StarterPackEvent: RemoteEvent = Remotes:WaitForChild("StarterPackEvent")
local CommanderPassEvent: RemoteEvent = Remotes:WaitForChild("CommanderPassEvent")
local OpenUIEvent: RemoteEvent = Remotes:WaitForChild("OpenUI")
local CloseUIEvent: RemoteEvent = Remotes:WaitForChild("CloseUI")
local PlotAssignmentEvent: RemoteEvent = Remotes:WaitForChild("PlotAssignment")

-- TODO: Old workspace shop/prompt models removed in new map. Interactions now use
-- ProximityPrompts on InteractionRings inside each plot. Wire these up when rings are implemented.
local SoldierShopPrompt = nil
local UpgradeShopPrompt = nil
local SellSoldiersPrompt = nil
local UnlockSlotsPrompt = nil

local ActiveFrame = nil
local ActiveFramePriority = nil
local HUDActive = nil
local CommanderPassHidden = false
local LocalPlayerPlot = nil

local SBD = false
local StarterPackOpenDebounce = false
local CommanderPassOpenDebounce = false

local StarterPackCloseButton: TextButton = StarterPackFrame:WaitForChild("Close")
local StarterPackPurchaseButton: TextButton = StarterPackFrame:WaitForChild("Purchase")
local CommanderPassCloseButton: TextButton = CommanderPassFrame:WaitForChild("Close")
local CommanderPassPurchaseButton: TextButton = CommanderPassFrame:WaitForChild("Purchase")

-- // Functions

local function ButtonExpand(Button, Amplification)
    local OriginSize: UDim2 = Button:GetAttribute("OriginSize")
    local ExpansionSize: UDim2 = UDim2.fromScale(OriginSize.X.Scale * Amplification, OriginSize.Y.Scale * Amplification)

    local ExpansionTween = TweenService:Create(Button, ExpansionTweenInfo, {Size = ExpansionSize})
    ExpansionTween:Play()
end

local function ButtonDeflate(Button)
    local OriginSize = Button:GetAttribute("OriginSize")

    local DeflationTween = TweenService:Create(Button, DeflationTweenInfo, {Size = OriginSize})
    DeflationTween:Play()
end

local function ButtonClose(Button)
    local CloseButtonTween = TweenService:Create(Button, DeflationTweenInfo, {Size = UDim2.fromScale(0,0)})
    CloseButtonTween:Play()
    CloseButtonTween.Completed:Connect(function()
        Button.Visible = false
    end)
end

local function ButtonOpen(Button)
    Button.Visible = true
    Button.Size = UDim2.fromScale(0,0)
    local OpenButtonTween = TweenService:Create(Button, ExpansionTweenInfo, {Size = Button:GetAttribute("OriginSize")})
    OpenButtonTween:Play()
end

local function CloseHUD(Fast: boolean)
    if Fast then
        for _, Button in pairs(HUDElements) do
            Button.Visible = false
        end
    else
        for _, Button in pairs(HUDElements) do
            ButtonClose(Button)
        end
    end
    HUDActive = false

    return
end

local function OpenHUD(Fast)
    if Fast then
        for _, Button in pairs(HUDElements) do
            if Button == CommanderPassHUD and CommanderPassHidden then
                Button.Visible = false
            else
                Button.Visible = true
            end
        end
        HUDActive = true
    else
        for _, Button in pairs(HUDElements) do
            if Button == CommanderPassHUD and CommanderPassHidden then
                Button.Visible = false
            else
                ButtonOpen(Button)
            end
        end
        HUDActive = true
    end
end

local function CloseFrame(Frame, NextFrame)
    if table.find(PromptedFrames, Frame) then
        PromptedFrameDebounces[Frame] = true
        task.delay(1, function()
            PromptedFrameDebounces[Frame] = false
        end)
    end

    local CloseTween = TweenService:Create(Frame, CloseTweenInfo, {Size = UDim2.fromScale(0,0)})
    CloseTween:Play()
    ActiveFrame = nil
    CloseTween.Completed:Connect(function()
        Frame.Visible = false
        if not NextFrame then
            task.delay(.1, OpenHUD)
        end
    end)

    return .1
end

local function OpenFrame(Frame: Frame)

    if ActiveFrame and ActiveFramePriority then
        return
    elseif ActiveFrame and not ActiveFramePriority then
        local AnimationTime = CloseFrame(ActiveFrame, true)
        task.wait(AnimationTime)
    elseif not ActiveFrame then
        if HUDActive then
            CloseHUD()
        end
    end

    ActiveFrame = Frame
    local OpenTween = TweenService:Create(Frame, OpenTweenInfo, {Size = UDim2.fromScale(1, 1)})
    Frame.Size = UDim2.fromScale(0,0)
    Frame.Visible = true
    OpenTween:Play()
end

local function CloseStarterPackFrame(NotifyServer: boolean)
    local CloseTween = TweenService:Create(StarterPackFrame, CloseTweenInfo, {Size = UDim2.fromScale(0, 0)})
    CloseTween:Play()
    ActiveFrame = nil

    if NotifyServer then
        StarterPackEvent:FireServer("Closed")
    end

    CloseTween.Completed:Connect(function()
        StarterPackFrame.Visible = false
        task.delay(.1, OpenHUD)
    end)
end

local function OpenStarterPackFrame()
    if StarterPackOpenDebounce then return end
    StarterPackOpenDebounce = true

    if ActiveFrame and ActiveFramePriority then
        StarterPackOpenDebounce = false
        return
    elseif ActiveFrame and ActiveFrame ~= StarterPackFrame and not ActiveFramePriority then
        local AnimationTime = CloseFrame(ActiveFrame, true)
        task.wait(AnimationTime)
    elseif not ActiveFrame and HUDActive then
        CloseHUD()
    end

    ActiveFrame = StarterPackFrame
    StarterPackFrame.Size = UDim2.fromScale(0, 0)
    StarterPackFrame.Visible = true

    local OriginSize = StarterPackFrame:GetAttribute("OriginSize") or UDim2.fromScale(1, 1)
    local OpenTween = TweenService:Create(StarterPackFrame, OpenTweenInfo, {Size = OriginSize})
    OpenTween:Play()

    task.delay(.2, function()
        StarterPackOpenDebounce = false
    end)
end

local function CloseCommanderPassFrame(NotifyServer: boolean)
    local CloseTween = TweenService:Create(CommanderPassFrame, CloseTweenInfo, {Size = UDim2.fromScale(0, 0)})
    CloseTween:Play()
    ActiveFrame = nil

    if NotifyServer then
        CommanderPassEvent:FireServer("Closed")
    end

    CloseTween.Completed:Connect(function()
        CommanderPassFrame.Visible = false
        task.delay(.1, OpenHUD)
    end)
end

local function OpenCommanderPassFrame()
    if CommanderPassOpenDebounce then return end
    CommanderPassOpenDebounce = true

    if ActiveFrame and ActiveFramePriority then
        CommanderPassOpenDebounce = false
        return
    elseif ActiveFrame and ActiveFrame ~= CommanderPassFrame and not ActiveFramePriority then
        local AnimationTime = CloseFrame(ActiveFrame, true)
        task.wait(AnimationTime)
    elseif not ActiveFrame and HUDActive then
        CloseHUD()
    end

    ActiveFrame = CommanderPassFrame
    CommanderPassFrame.Size = UDim2.fromScale(0, 0)
    CommanderPassFrame.Visible = true

    local OriginSize = CommanderPassFrame:GetAttribute("OriginSize") or UDim2.fromScale(1, 1)
    local OpenTween = TweenService:Create(CommanderPassFrame, OpenTweenInfo, {Size = OriginSize})
    OpenTween:Play()

    task.delay(.2, function()
        CommanderPassOpenDebounce = false
    end)
end

local function Notify(Message: string, Time: number, Color: Color3Value)
	local Notification = TemplateNotification:Clone()
	Notification.Text = Message
	Notification.TextColor3 = Color
	Notification.LayoutOrder = 1
	Notification.Visible = true
	Notification.Parent = NotificationFrame

	-- Play error sound if notification is red (error)
	if Color == Color3.fromRGB(255, 0, 0) then
		SOUND_MANAGER:PlayError()
	end

	task.delay(Time, function()
		local FadeTween1 = TweenService:Create(Notification, TweenInfo.new(.4), {TextTransparency = 1})
		FadeTween1:Play()
		local FadeTween2 = TweenService:Create(Notification:WaitForChild("UIStroke"), TweenInfo.new(.4), {Transparency = 1})
		FadeTween2:Play()

		FadeTween2.Completed:Connect(function()
			Notification:Destroy()
		end)
	end)
end

local function FormatHoursFromSeconds(Seconds: number)
    local Hours = Seconds / 3600

    if Hours >= 1 then
        return tostring(math.floor(Hours))
    else
        return string.format("%.1f", Hours)
    end
end

local function ShowIdleRewards(Amount: number, HasVIP: boolean, ClampedTimeAway: number)
    -- 1) Set the amount text
    IdleRewardsAmount.Text = "$" .. Amount

    -- 2) Set the hours text
    -- Default text is "In x hour (48 hours max)"
    -- local HoursAway = FormatHoursFromSeconds(ClampedTimeAway)
    -- if HasVIP then
    --     IdleRewardsHours.Text = "In " .. HoursAway .. " hours (72 hours max)"
    -- else
    --     IdleRewardsHours.Text = "In " .. HoursAway .. " hours (48 hours max)"
    -- end

    -- 3) Set the percent text
    -- Default text is "At 50% rate" (100% for VIP)
    --  if HasVIP then
    --    IdleRewardsPercent.Text = "At 100% rate"
    -- else
    --     IdleRewardsPercent.Text = "At 50% rate"
    -- end

    -- 4) Show VIP advertisement if player isn't VIP
    -- TODO

    -- 5) Open the frame as priority
    ActiveFramePriority = true
    OpenFrame(IdleRewardsFrame)
end

-- // Events
for _, Button in pairs(HUDButtons) do
    Button.MouseEnter:Connect(function()
        if HUDActive == false then return end
        ButtonExpand(Button, 1.1)
    end)
    Button.MouseLeave:Connect(function()
        if HUDActive == false then return end
        ButtonDeflate(Button)
    end)
end

SoldiersButton.MouseButton1Click:Connect(function()
	if not HUDActive then return end

	if SBD then return end
	SBD = true

	SOUND_MANAGER:PlayClick()

	if ActiveFrame == SoldierInventoryFrame then
		CloseFrame(SoldierInventoryFrame)
	else
		OpenFrame(SoldierInventoryFrame)
	end

	task.wait(.5)
	SBD = false
end)

local SettingsDB = false
SettingsButton.MouseButton1Click:Connect(function()
	if not HUDActive then return end

	if SettingsDB then return end
	SettingsDB = true

	SOUND_MANAGER:PlayClick()

	if ActiveFrame == SettingsFrame then
		CloseFrame(SettingsFrame)
	else
		OpenFrame(SettingsFrame)
	end

	task.wait(.5)
	SettingsDB = false
end)

-- Credits button opens store with Credits pane
CreditsButton.MouseButton1Click:Connect(function()
	if not HUDActive then return end
	SOUND_MANAGER:PlayClick()
	OpenStoreBindable:Fire("Credits")
end)

-- Store button opens store with Passes pane
StoreButton.MouseButton1Click:Connect(function()
	if not HUDActive then return end
	SOUND_MANAGER:PlayClick()
	OpenStoreBindable:Fire("Passes")
end)

CommanderPassHUDButton.MouseButton1Click:Connect(function()
	if not HUDActive then return end
	SOUND_MANAGER:PlayClick()
	OpenCommanderPassFrame()
end)

if not StarterPackPurchaseButton:GetAttribute("OriginSize") then
    StarterPackPurchaseButton:SetAttribute("OriginSize", StarterPackPurchaseButton.Size)
end
if not StarterPackCloseButton:GetAttribute("OriginSize") then
    StarterPackCloseButton:SetAttribute("OriginSize", StarterPackCloseButton.Size)
end

StarterPackPurchaseButton.MouseEnter:Connect(function()
    if not StarterPackFrame.Visible then return end
    ButtonExpand(StarterPackPurchaseButton, 1.1)
end)
StarterPackPurchaseButton.MouseLeave:Connect(function()
    if not StarterPackFrame.Visible then return end
    ButtonDeflate(StarterPackPurchaseButton)
end)

StarterPackCloseButton.MouseEnter:Connect(function()
    if not StarterPackFrame.Visible then return end
    ButtonExpand(StarterPackCloseButton, 1.1)
end)
StarterPackCloseButton.MouseLeave:Connect(function()
    if not StarterPackFrame.Visible then return end
    ButtonDeflate(StarterPackCloseButton)
end)

StarterPackCloseButton.MouseButton1Click:Connect(function()
    if not StarterPackFrame.Visible then return end
    SOUND_MANAGER:PlayClick()
    CloseStarterPackFrame(true)
end)

StarterPackPurchaseButton.MouseButton1Click:Connect(function()
    if not StarterPackFrame.Visible then return end
    SOUND_MANAGER:PlayClick()

    if not SETTINGS.STARTER_PACK.ProductId or SETTINGS.STARTER_PACK.ProductId == 0 then
        SOUND_MANAGER:PlayError()
        return
    end

    MarketplaceService:PromptProductPurchase(LocalPlayer, SETTINGS.STARTER_PACK.ProductId)
end)

if not CommanderPassPurchaseButton:GetAttribute("OriginSize") then
    CommanderPassPurchaseButton:SetAttribute("OriginSize", CommanderPassPurchaseButton.Size)
end
if not CommanderPassCloseButton:GetAttribute("OriginSize") then
    CommanderPassCloseButton:SetAttribute("OriginSize", CommanderPassCloseButton.Size)
end

CommanderPassPurchaseButton.MouseEnter:Connect(function()
    if not CommanderPassFrame.Visible then return end
    ButtonExpand(CommanderPassPurchaseButton, 1.1)
end)
CommanderPassPurchaseButton.MouseLeave:Connect(function()
    if not CommanderPassFrame.Visible then return end
    ButtonDeflate(CommanderPassPurchaseButton)
end)

CommanderPassCloseButton.MouseEnter:Connect(function()
    if not CommanderPassFrame.Visible then return end
    ButtonExpand(CommanderPassCloseButton, 1.1)
end)
CommanderPassCloseButton.MouseLeave:Connect(function()
    if not CommanderPassFrame.Visible then return end
    ButtonDeflate(CommanderPassCloseButton)
end)

CommanderPassCloseButton.MouseButton1Click:Connect(function()
    if not CommanderPassFrame.Visible then return end
    SOUND_MANAGER:PlayClick()
    CloseCommanderPassFrame(true)
end)

CommanderPassPurchaseButton.MouseButton1Click:Connect(function()
    if not CommanderPassFrame.Visible then return end
    SOUND_MANAGER:PlayClick()

    if not SETTINGS.COMMANDER_PASS.ProductId or SETTINGS.COMMANDER_PASS.ProductId == 0 then
        SOUND_MANAGER:PlayError()
        return
    end

    MarketplaceService:PromptGamePassPurchase(LocalPlayer, SETTINGS.COMMANDER_PASS.ProductId)
end)

ButtonExpandBindable.Event:Connect(ButtonExpand)
ButtonDeflateBindable.Event:Connect(ButtonDeflate)
CloseFrameBindable.Event:Connect(CloseFrame)

HUDBindable.Event:Connect(function(Action: string)
	if Action == "Close" then
		CloseHUD(false)
	elseif Action == "Open" then
		OpenHUD(false)
	end
end)

StarterPackEvent.OnClientEvent:Connect(function(Action: string)
    if Action == "Open" then
        OpenStarterPackFrame()
    elseif Action == "Close" then
        if StarterPackFrame.Visible then
            CloseStarterPackFrame(false)
        end
    end
end)

CommanderPassEvent.OnClientEvent:Connect(function(Action: string)
    if Action == "Open" then
        OpenCommanderPassFrame()
    elseif Action == "Close" then
        if CommanderPassFrame.Visible then
            CloseCommanderPassFrame(false)
        end
    end
end)

LoadPlayerEvent.OnClientEvent:Connect(function(PlayerData: table, EntryName: string?)
    -- Close purchase frames whose flow just completed
    if EntryName == "StarterPack" and StarterPackFrame.Visible then
        CloseStarterPackFrame(false)
    elseif EntryName == "CommanderPass" and CommanderPassFrame.Visible then
        CloseCommanderPassFrame(false)
    end

    -- Show/hide commander pass HUD button based on ownership
    local OwnsCommanderPass = false
    if PlayerData.Plot and PlayerData.Plot.Unlocks then
        OwnsCommanderPass = PlayerData.Plot.Unlocks.Slot8 == true
    end

    CommanderPassHidden = OwnsCommanderPass
    if OwnsCommanderPass then
        CommanderPassHUD.Visible = false
    elseif HUDActive then
        CommanderPassHUD.Visible = true
    end
end)

-- Maps UI identifiers (sent from server via OpenUIEvent) to their frame instances.
local UI_NAME_TO_FRAME = {
    ["SoldierShop"]    = SoldierShopFrame,
    ["UpgradeTarget"]  = UpgradeTargetFrame,
    ["SellSoldiers"]   = SellSoldiersFrame,
    ["UnlockSlot"]     = UnlockSlotFrame,
    ["StarterPack"]    = StarterPackFrame,
    ["CommanderPass"]  = CommanderPassFrame,
    ["Boost"]          = BoostTreeFrame,
    -- Rebirth, UnlockRebirthLane, UnlockCommanderLane: stubs until those systems exist
}

-- When the local player's plot is assigned, wire PromptHidden on every ring
-- to close the corresponding frame when the player walks away.
local RING_NAME_TO_UI = {
    ["SoldierShopRing"]    = "SoldierShop",
    ["UpgradeTargetRing"]  = "UpgradeTarget",
    ["TrashCanRing"]       = "SellSoldiers",
    ["UnlockLaneRing"]     = "UnlockSlot",
    ["StarterPackRing"]    = "StarterPack",
    ["CommanderPassRing"]  = "CommanderPass",
    ["BoostRing"]          = "Boost",
}

PlotAssignmentEvent.OnClientEvent:Connect(function(PlayerName: string, PlotName: string)
    if PlayerName ~= LocalPlayer.Name then return end
    LocalPlayerPlot = PlotName

    task.spawn(function()
        local Plot = workspace:WaitForChild("Plots"):WaitForChild(PlotName, 10)
        if not Plot then return end
        local Rings = Plot:WaitForChild("InteractionRings", 10)
        if not Rings then return end

        print("[UI] Wiring PromptHidden for plot " .. PlotName)
        local WiredCount = 0
        for _, Ring in ipairs(Rings:GetChildren()) do
            local UIName = RING_NAME_TO_UI[Ring.Name]
            if not UIName then continue end
            local GuiParts = Ring:FindFirstChild("GuiParts")
            local Prompt = GuiParts and GuiParts:FindFirstChildOfClass("ProximityPrompt")
            if not Prompt then continue end

            WiredCount += 1
            Prompt.PromptHidden:Connect(function()
                print("[UI] PromptHidden fired for " .. Ring.Name .. " -> " .. UIName)
                local Frame = UI_NAME_TO_FRAME[UIName]
                if Frame and Frame.Visible then
                    CloseFrame(Frame)
                end
            end)
        end
        print("[UI] Wired " .. WiredCount .. " ring prompts")
    end)
end)

-- Receives ring trigger from server and opens the corresponding UI frame.
OpenUIEvent.OnClientEvent:Connect(function(UIName: string)
    local Frame = UI_NAME_TO_FRAME[UIName]
    if Frame then
        if PromptedFrameDebounces[Frame] then return end
        if Frame.Visible then return end
        PromptedFrameDebounces[Frame] = true
        OpenFrame(Frame)
        task.wait(0.5)
        PromptedFrameDebounces[Frame] = false
    else
        -- Stub rings (Boost, Rebirth, etc.) — do nothing for now
        warn("[UI] No frame mapped for UI: " .. tostring(UIName))
    end
end)

-- Resolves the local player's plot folder. Prefers the cached name from the
-- PlotAssignment event, but falls back to scanning the Owner attribute the
-- server stamps on the folder, so this works even if the event was missed.
local function ResolveLocalPlot(): Instance?
    local Plots = workspace:FindFirstChild("Plots")
    if not Plots then return nil end

    if LocalPlayerPlot then
        local Cached = Plots:FindFirstChild(LocalPlayerPlot)
        if Cached then return Cached end
    end

    for _, Plot in ipairs(Plots:GetChildren()) do
        if Plot:GetAttribute("Owner") == LocalPlayer.Name then
            LocalPlayerPlot = Plot.Name
            return Plot
        end
    end
    return nil
end

-- Pivots the full character model to the given world position.
local function TeleportTo(Position: Vector3)
    local Character = LocalPlayer.Character
    if not Character then
        Notify("No character!", 1, Color3.fromRGB(255, 0, 0))
        return
    end
    Character:PivotTo(CFrame.new(Position))
end

TeleportHomeButton.MouseButton1Click:Connect(function()
    local Plot = ResolveLocalPlot()
    if not Plot then
        Notify("Plot not assigned yet", 1, Color3.fromRGB(255, 100, 0))
        return
    end
    local SpawnsFolder = Plot:FindFirstChild("Spawns")
    local Spawn4 = SpawnsFolder and SpawnsFolder:FindFirstChild("SoldierSpawn4")
    local Spawn5 = SpawnsFolder and SpawnsFolder:FindFirstChild("SoldierSpawn5")
    local ShopBase = Plot:FindFirstChild("ShopAreaBase")
    local RangeBase = Plot:FindFirstChild("RangeAreaBase")
    if not (Spawn4 and Spawn5 and ShopBase and RangeBase) then
        Notify("Missing spawn parts", 1, Color3.fromRGB(255, 0, 0))
        return
    end

    -- Average of the two spawn positions, then push 10 studs toward the shop
    local MidPos = (Spawn4.Position + Spawn5.Position) / 2
    local TowardShop = (ShopBase.Position - RangeBase.Position).Unit
    TeleportTo(Vector3.new(MidPos.X, MidPos.Y + 5, MidPos.Z) + TowardShop * 10)
end)

TeleportShopButton.MouseButton1Click:Connect(function()
    local Plot = ResolveLocalPlot()
    if not Plot then
        Notify("Plot not assigned yet", 1, Color3.fromRGB(255, 100, 0))
        return
    end
    local Rings = Plot:FindFirstChild("InteractionRings")
    local ShopRing = Rings and Rings:FindFirstChild("SoldierShopRing")
    local ShopBase = Plot:FindFirstChild("ShopAreaBase")
    if not (ShopRing and ShopBase) then
        Notify("Missing shop ring/base", 1, Color3.fromRGB(255, 0, 0))
        return
    end

    -- Start at the ring pivot, push 6 studs toward the shop floor center
    local RingPos = ShopRing:GetPivot().Position
    local TowardShop = (ShopBase.Position - RingPos)
    TowardShop = Vector3.new(TowardShop.X, 0, TowardShop.Z).Unit
    TeleportTo(RingPos + TowardShop * 6 + Vector3.new(0, 5, 0))
end)

NotifyBindable.Event:Connect(Notify)

IdleRewardsEvent.OnClientEvent:Connect(ShowIdleRewards)
IdleRewardsClaimButton.MouseButton1Click:Connect(function()
    -- Fire server to claim
    IdleRewardsEvent:FireServer()

    -- Close the frame
    ActiveFramePriority = false
    CloseFrame(IdleRewardsFrame)
end)

StarterPackFrame.Visible = false
CommanderPassFrame.Visible = false
BoostTreeFrame.Visible = false
HUD:WaitForChild("BoostsDisplay").Visible = false

-- Animation stuff

-- Pulse animation for store button
for _, Target in pairs(HUDButtonsPulse) do
    -- Original size recorded as scale for responsive UIs
    local OriginSize = Target:GetAttribute("OriginSize")
    local PulseSize = UDim2.fromScale(OriginSize.X.Scale * 1.15, OriginSize.Y.Scale * 1.15)

    local PulseTweenInfo = TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
    local ShrinkTweenInfo = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

    local PulseTween, ShrinkTween, IsHovering = nil, nil, false

    local function StartPulse()
        if PulseTween then
            PulseTween:Cancel()
        end
        PulseTween = TweenService:Create(Target, PulseTweenInfo, {Size = PulseSize})
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
        ShrinkTween = TweenService:Create(Target, ShrinkTweenInfo, {Size = OriginSize})
        ShrinkTween:Play()
    end

    Target.MouseEnter:Connect(function()
        if IsHovering then return end
        IsHovering = true
        StartPulse()
    end)
    Target.MouseLeave:Connect(function()
        IsHovering = false
        StopPulse()
    end)
end

-- TODO Wait for loading screen to finish
HUD.Enabled = true
HUDActive = true
