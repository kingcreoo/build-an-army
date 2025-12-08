-- // UI, initialized by KingCreoo on 9-6-2025
-- // Manages UI functions for the client :)

-- // Services
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- // Modules

-- // Variables
local LocalPlayer = Players.LocalPlayer
local LocalGui = LocalPlayer:WaitForChild("PlayerGui")

local HUD: ScreenGui = LocalGui:WaitForChild("HUD")
local SoldiersButton: TextButton = HUD:WaitForChild("Soldiers")
local StoreButton: TextButton = HUD:WaitForChild("Store")
local SettingsButton: TextButton = HUD:WaitForChild("Settings")

local FramesGui: ScreenGui = LocalGui:WaitForChild("Frames")
local SoldierShopFrame: Frame = FramesGui:WaitForChild("SoldierShop")
local SoldierInventoryFrame: Frame = FramesGui:WaitForChild("SoldierInventory")
local SettingsFrame: Frame = FramesGui:WaitForChild("SettingsFrame")
local UpgradeTargetFrame: Frame = FramesGui:WaitForChild("UpgradeTargetFrame")

local IdleRewardsFrame: Frame = FramesGui:WaitForChild("IdleRewardsFrame")
local IdleRewardsAmount: TextLabel = IdleRewardsFrame:WaitForChild("MainFrame"):WaitForChild("Amount")
local IdleRewardsHours: TextLabel = IdleRewardsFrame:WaitForChild("MainFrame"):WaitForChild("Hours")
local IdleRewardsPercent: TextLabel = IdleRewardsFrame:WaitForChild("MainFrame"):WaitForChild("Percent")
local IdleRewardsClaimButton: TextButton = IdleRewardsFrame:WaitForChild("MainFrame"):WaitForChild("Claim")

local NotificationFrame: Frame = FramesGui:WaitForChild("NotificationFrame")
local TemplateNotification: TextLabel = NotificationFrame:WaitForChild("TemplateNotification")

local PromptedFrames = {SoldierShopFrame, UpgradeTargetFrame}
local PromptedFrameDebounces = {SoldierShopFrame = false, UpgradeTargetFrame = false}

local HUDButtons = {SoldiersButton, StoreButton, SettingsButton}

local ExpansionTweenInfo = TweenInfo.new(.25, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
local DeflationTweenInfo = TweenInfo.new(.075, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
local OpenTweenInfo = TweenInfo.new(.3, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
local CloseTweenInfo = TweenInfo.new(.1, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local ButtonExpandBindable: BindableEvent = Remotes:WaitForChild("ButtonExpand")
local ButtonDeflateBindable: BindableEvent = Remotes:WaitForChild("ButtonDeflate")
local CloseFrameBindable: BindableEvent = Remotes:WaitForChild("CloseFrame")
local NotifyBindable: BindableEvent = Remotes:WaitForChild("NotifyBindable")
local IdleRewardsEvent: RemoteEvent = Remotes:WaitForChild("IdleRewards")

local SoldierShopPrompt: ProximityPrompt = Workspace:WaitForChild("SoldierShop"):WaitForChild("PromptPart"):WaitForChild("Prompt")
local UpgradeShopPrompt: ProximityPrompt = Workspace:WaitForChild("UpgradeShop"):WaitForChild("PromptPart"):WaitForChild("Prompt")

local ActiveFrame = nil
local ActiveFramePriority = nil
local HUDActive = nil

local SBD = false

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
        for _, Button in pairs(HUDButtons) do
            Button.Visible = false
        end
    else
        for _, Button in pairs(HUDButtons) do
            task.wait(.05)
            ButtonClose(Button)
        end
    end
    HUDActive = false

    return
end

local function OpenHUD(Fast)
    if Fast then
        for _, Button in pairs(HUDButtons) do
            Button.Visible = true
        end
        HUDActive = true
    else
        for _, Button in pairs(HUDButtons) do
            ButtonOpen(Button)
            task.wait(.2)
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

local function Notify(Message: string, Time: number, Color: Color3Value)
    local Notification = TemplateNotification:Clone()
    Notification.Text = Message
    Notification.TextColor3 = Color
    Notification.LayoutOrder = 1
    Notification.Visible = true
    Notification.Parent = NotificationFrame

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
    local HoursAway = FormatHoursFromSeconds(ClampedTimeAway)
    if HasVIP then
        IdleRewardsHours.Text = "In " .. HoursAway .. " hours (72 hours max)"
    else
        IdleRewardsHours.Text = "In " .. HoursAway .. " hours (48 hours max)"
    end

    -- 3) Set the percent text
    -- Default text is "At 50% rate" (100% for VIP)
    if HasVIP then
        IdleRewardsPercent.Text = "At 100% rate"
    else
        IdleRewardsPercent.Text = "At 50% rate"
    end

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

    if ActiveFrame == SettingsDB then
        CloseFrame(SettingsFrame)
    else
        OpenFrame(SettingsFrame)
    end

    task.wait(.5)
    SettingsDB = false
end)

ButtonExpandBindable.Event:Connect(ButtonExpand)
ButtonDeflateBindable.Event:Connect(ButtonDeflate)
CloseFrameBindable.Event:Connect(CloseFrame)

SoldierShopPrompt.PromptShown:Connect(function()
    if PromptedFrameDebounces[SoldierShopFrame] then return end

    if SoldierShopFrame.Visible == true then return end

    PromptedFrameDebounces[SoldierShopFrame] = true
    OpenFrame(SoldierShopFrame)

    task.wait(.5)
    PromptedFrameDebounces[SoldierShopFrame] = false
end)
SoldierShopPrompt.PromptHidden:Connect(function()
	if SoldierShopFrame.Visible == false then return end
	CloseFrame(SoldierShopFrame)
end)

UpgradeShopPrompt.PromptShown:Connect(function()
	if PromptedFrameDebounces[UpgradeTargetFrame] then return end

	if UpgradeTargetFrame.Visible == true then return end

	PromptedFrameDebounces[UpgradeTargetFrame] = true
	OpenFrame(UpgradeTargetFrame)

	task.wait(.5)
	PromptedFrameDebounces[UpgradeTargetFrame] = false
end)
UpgradeShopPrompt.PromptHidden:Connect(function()
	if UpgradeTargetFrame.Visible == false then return end
	CloseFrame(UpgradeTargetFrame)
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

-- TODO Wait for loading screen to finish
HUD.Enabled = true
HUDActive = true