-- BoostTree.client, initialized by KingCreoo
-- Manages the BoostTreeFrame UI: slot state machine, countdown timers, and claim flow.

-- // Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

-- // Variables
local LocalPlayer = Players.LocalPlayer
local LocalGui = LocalPlayer:WaitForChild("PlayerGui")

local SETTINGS = require(ReplicatedStorage:WaitForChild("Settings"))

local FramesGui: ScreenGui = LocalGui:WaitForChild("Frames")
local BoostTreeFrame: Frame = FramesGui:WaitForChild("BoostTreeFrame")
local SlotsFolder: Folder = BoostTreeFrame:WaitForChild("Slots")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local UpdateBoostTreeEvent: RemoteEvent = Remotes:WaitForChild("UpdateBoostTree")
local ClaimBoostTreeEvent: RemoteEvent = Remotes:WaitForChild("ClaimBoostTree")
local LoadPlayerEvent: RemoteEvent = Remotes:WaitForChild("LoadPlayer")
local CloseFrameBindable: BindableEvent = Remotes:WaitForChild("CloseFrame")

local CloseButton: TextButton = BoostTreeFrame:WaitForChild("Close")

-- Boost type visual mappings (from IMPLEMENTATION_CONTEXT)
local BOOST_VISUALS = {
    ["CashMultiplier"] = {
        Color      = Color3.fromRGB(255, 217, 66),
        Image      = "rbxassetid://74950070306966",
        Gradient1  = Color3.fromRGB(255, 253, 181),
        Gradient2  = Color3.fromRGB(255, 206, 92),
    },
    ["DamageMultiplier"] = {
        Color      = Color3.fromRGB(255, 0, 0),
        Image      = "rbxassetid://107438473232059",
        Gradient1  = Color3.fromRGB(255, 178, 178),
        Gradient2  = Color3.fromRGB(200, 72, 72),
    },
    ["FireRateMultiplier"] = {
        Color      = Color3.fromRGB(85, 255, 0),
        Image      = "rbxassetid://111102292815002",
        Gradient1  = Color3.fromRGB(255, 253, 181),
        Gradient2  = Color3.fromRGB(255, 206, 92),
    },
    ["TargetMultiplier"] = {
        Color      = Color3.fromRGB(62, 245, 255),
        Image      = "rbxassetid://129729627146129",
        Gradient1  = Color3.fromRGB(175, 251, 255),
        Gradient2  = Color3.fromRGB(94, 158, 255),
    },
}

-- Locked/generating state visuals
local LOCKED_COLOR     = Color3.fromRGB(85, 85, 127)
local LOCK_IMAGE       = "rbxassetid://106159424385326"
local QUESTION_IMAGE   = "rbxassetid://122903592348067"

-- Claim button active gradient colors
local CLAIM_COLOR1 = Color3.fromRGB(52, 255, 37)
local CLAIM_COLOR2 = Color3.fromRGB(97, 189, 143)

-- Per-slot state: "Locked" | "Generating" | "Ready"
local SlotStates = { Slot1 = "Locked", Slot2 = "Locked", Slot3 = "Locked" }
-- Per-slot pending boost data (only set when state == "Ready")
local SlotPendingBoosts = {}
-- Per-slot generation start time (tick()) — session-only, reset on join
local SlotTimerStarts = {}
-- Debounce per slot to prevent double-claim
local SlotClaimDebounce = {}

-- Pulse tween handles per slot (for the question mark animation)
local SlotPulseTweens = {}

-- // Local Functions

-- Formats remaining seconds into a countdown string.
local function FormatCountdown(SecondsLeft: number): string
    SecondsLeft = math.max(0, math.floor(SecondsLeft))
    local Minutes = math.floor(SecondsLeft / 60)
    local Seconds = SecondsLeft % 60
    if Minutes > 0 then
        return string.format("%dm %ds", Minutes, Seconds)
    else
        return string.format("%ds", Seconds)
    end
end

-- Formats a multiplier amount as a display string (e.g. 1.5 -> "1.5x").
local function FormatAmount(Amount: number): string
    if Amount == math.floor(Amount) then
        return tostring(math.floor(Amount)) .. "x"
    else
        return string.format("%.1fx", Amount)
    end
end

-- Applies a UIGradient to a GuiObject. Creates one if it doesn't exist.
local function SetGradient(Object: GuiObject, Color1: Color3, Color2: Color3, Enabled: boolean)
    local Gradient = Object:FindFirstChildOfClass("UIGradient")
    if not Gradient then
        Gradient = Instance.new("UIGradient")
        Gradient.Parent = Object
    end
    Gradient.Enabled = Enabled
    if Enabled then
        Gradient.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color1),
            ColorSequenceKeypoint.new(1, Color2),
        })
    end
end

-- Stops the pulse tween for a slot if one is running.
local function StopPulse(SlotKey: string)
    local Tween = SlotPulseTweens[SlotKey]
    if Tween then
        Tween:Cancel()
        SlotPulseTweens[SlotKey] = nil
    end
end

-- Starts the question mark pulse animation on the slot's Image.
local function StartPulse(SlotKey: string, ImageLabel: ImageLabel)
    StopPulse(SlotKey)
    local OriginSize = ImageLabel:GetAttribute("OriginSize") or ImageLabel.Size
    if not ImageLabel:GetAttribute("OriginSize") then
        ImageLabel:SetAttribute("OriginSize", OriginSize)
    end
    local PulseSize = UDim2.fromScale(OriginSize.X.Scale * 1.15, OriginSize.Y.Scale * 1.15)
    local PulseTween = TweenService:Create(
        ImageLabel,
        TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
        { Size = PulseSize }
    )
    PulseTween:Play()
    SlotPulseTweens[SlotKey] = PulseTween
end

-- Applies the Locked visual state to a slot.
local function ApplyLockedState(SlotKey: string, SlotFrame: Frame, RebirthRequired: number)
    StopPulse(SlotKey)

    local ButtonBg = SlotFrame:FindFirstChild("ButtonBackground")
    local ClaimBtn = SlotFrame:FindFirstChild("Claim")
    local AmountLabel = SlotFrame:FindFirstChild("Amount")
    local TimeLabel = SlotFrame:FindFirstChild("Time")
    local ImageLabel = ButtonBg and ButtonBg:FindFirstChildOfClass("ImageLabel")

    if ButtonBg then
        ButtonBg.BackgroundColor3 = LOCKED_COLOR
        SetGradient(ButtonBg, LOCKED_COLOR, LOCKED_COLOR, false)
    end
    if ImageLabel then
        ImageLabel.Image = LOCK_IMAGE
        local OriginSize = ImageLabel:GetAttribute("OriginSize") or ImageLabel.Size
        ImageLabel.Size = OriginSize
    end
    if ClaimBtn then ClaimBtn.Visible = false end
    if AmountLabel then AmountLabel.Visible = false end
    if TimeLabel then
        TimeLabel.Text = "Rebirth " .. RebirthRequired .. " required"
    end
end

-- Applies the Generating visual state to a slot.
local function ApplyGeneratingState(SlotKey: string, SlotFrame: Frame)
    StopPulse(SlotKey)

    local ButtonBg = SlotFrame:FindFirstChild("ButtonBackground")
    local ClaimBtn = SlotFrame:FindFirstChild("Claim")
    local AmountLabel = SlotFrame:FindFirstChild("Amount")
    local TimeLabel = SlotFrame:FindFirstChild("Time")
    local ImageLabel = ButtonBg and ButtonBg:FindFirstChildOfClass("ImageLabel")

    if ButtonBg then
        ButtonBg.BackgroundColor3 = LOCKED_COLOR
        SetGradient(ButtonBg, LOCKED_COLOR, LOCKED_COLOR, false)
    end
    if ImageLabel then
        ImageLabel.Image = QUESTION_IMAGE
        -- Start pulse animation
        StartPulse(SlotKey, ImageLabel)
    end
    if ClaimBtn then ClaimBtn.Visible = false end
    if AmountLabel then AmountLabel.Visible = false end
    if TimeLabel then TimeLabel.Text = "" end
end

-- Applies the Ready visual state to a slot.
local function ApplyReadyState(SlotKey: string, SlotFrame: Frame, PendingBoost: table)
    StopPulse(SlotKey)

    local Visuals = BOOST_VISUALS[PendingBoost.Type]
    if not Visuals then
        warn("[BoostTree] Unknown boost type for visuals: " .. tostring(PendingBoost.Type))
        return
    end

    local ButtonBg = SlotFrame:FindFirstChild("ButtonBackground")
    local ClaimBtn = SlotFrame:FindFirstChild("Claim")
    local AmountLabel = SlotFrame:FindFirstChild("Amount")
    local TimeLabel = SlotFrame:FindFirstChild("Time")
    local ImageLabel = ButtonBg and ButtonBg:FindFirstChildOfClass("ImageLabel")

    if ButtonBg then
        ButtonBg.BackgroundColor3 = Visuals.Color
        SetGradient(ButtonBg, Visuals.Gradient1, Visuals.Gradient2, true)
    end
    if ImageLabel then
        ImageLabel.Image = Visuals.Image
        local OriginSize = ImageLabel:GetAttribute("OriginSize") or ImageLabel.Size
        ImageLabel.Size = OriginSize
    end
    if ClaimBtn then
        ClaimBtn.Visible = true
        ClaimBtn.Text = "Claim"
        ClaimBtn.BackgroundColor3 = CLAIM_COLOR1
        SetGradient(ClaimBtn, CLAIM_COLOR1, CLAIM_COLOR2, true)
        ClaimBtn.Active = true
    end
    if AmountLabel then
        AmountLabel.Visible = true
        AmountLabel.Text = FormatAmount(PendingBoost.Amount)
    end
    if TimeLabel then
        TimeLabel.Text = "Ready!"
    end
end

-- Refreshes a single slot's visual state based on SlotStates.
local function RefreshSlot(SlotKey: string)
    local SlotFrame = SlotsFolder:FindFirstChild(SlotKey)
    if not SlotFrame then return end

    local State = SlotStates[SlotKey]
    local SlotNumber = tonumber(string.sub(SlotKey, 5))
    local SlotConfig = SETTINGS.BOOST_TREE[SlotKey]

    if State == "Locked" then
        ApplyLockedState(SlotKey, SlotFrame, SlotConfig.RebirthRequired)

    elseif State == "Generating" then
        ApplyGeneratingState(SlotKey, SlotFrame)

    elseif State == "Ready" then
        local PendingBoost = SlotPendingBoosts[SlotKey]
        if PendingBoost then
            ApplyReadyState(SlotKey, SlotFrame, PendingBoost)
        end
    end
end

-- Handles a claim action for a slot (from either Claim button or ButtonBackground).
local function OnClaim(SlotKey: string)
    if SlotClaimDebounce[SlotKey] then return end
    if SlotStates[SlotKey] ~= "Ready" then return end

    SlotClaimDebounce[SlotKey] = true

    local SlotNumber = tonumber(string.sub(SlotKey, 5))
    ClaimBoostTreeEvent:FireServer(SlotNumber)

    -- Optimistically switch to Generating state (server will confirm via UpdateBoostTree)
    SlotStates[SlotKey] = "Generating"
    SlotPendingBoosts[SlotKey] = nil
    SlotTimerStarts[SlotKey] = tick()
    RefreshSlot(SlotKey)

    task.delay(1, function()
        SlotClaimDebounce[SlotKey] = false
    end)
end

-- Wires click handlers for a slot's Claim button and ButtonBackground.
local function WireSlotButtons(SlotKey: string, SlotFrame: Frame)
    local ButtonBg = SlotFrame:FindFirstChild("ButtonBackground")
    local ClaimBtn = SlotFrame:FindFirstChild("Claim")

    if ButtonBg and ButtonBg:IsA("TextButton") then
        ButtonBg.MouseButton1Click:Connect(function()
            OnClaim(SlotKey)
        end)
    end

    if ClaimBtn and ClaimBtn:IsA("TextButton") then
        ClaimBtn.MouseButton1Click:Connect(function()
            OnClaim(SlotKey)
        end)
    end
end

-- Seeds slot state from PlayerData on join.
local function SeedFromPlayerData(PlayerData: table)
    if not PlayerData or not PlayerData.BoostTree then return end

    local Rebirths = PlayerData.Rebirths or 0

    for i = 1, 3 do
        local SlotKey = "Slot" .. i
        local SlotConfig = SETTINGS.BOOST_TREE[SlotKey]
        local SlotData = PlayerData.BoostTree[SlotKey]
        if not SlotData then continue end

        if Rebirths < SlotConfig.RebirthRequired then
            -- Slot is locked
            SlotStates[SlotKey] = "Locked"
            SlotPendingBoosts[SlotKey] = nil
            SlotTimerStarts[SlotKey] = nil
        elseif SlotData.PendingBoost then
            -- Slot has a ready boost
            SlotStates[SlotKey] = "Ready"
            SlotPendingBoosts[SlotKey] = SlotData.PendingBoost
            SlotTimerStarts[SlotKey] = nil
        else
            -- Slot is unlocked and generating
            SlotStates[SlotKey] = "Generating"
            SlotPendingBoosts[SlotKey] = nil
            SlotTimerStarts[SlotKey] = tick()  -- start timer from now (session-only)
        end

        RefreshSlot(SlotKey)
    end
end

-- // Events

-- Server fires this when a slot becomes ready (PendingBoost = table) or resets to generating (false).
UpdateBoostTreeEvent.OnClientEvent:Connect(function(SlotKey: string, PendingBoost: any)
    if PendingBoost then
        -- Slot is now ready
        SlotStates[SlotKey] = "Ready"
        SlotPendingBoosts[SlotKey] = PendingBoost
        SlotTimerStarts[SlotKey] = nil
    else
        -- Slot reset to generating (after claim or on join for unlocked non-ready slots)
        SlotStates[SlotKey] = "Generating"
        SlotPendingBoosts[SlotKey] = nil
        SlotTimerStarts[SlotKey] = tick()
    end
    RefreshSlot(SlotKey)
end)

-- Seed from PlayerData on join
LoadPlayerEvent.OnClientEvent:Connect(function(PlayerData: table)
    SeedFromPlayerData(PlayerData)
end)

-- // Wire buttons for all slots
for i = 1, 3 do
    local SlotKey = "Slot" .. i
    local SlotFrame = SlotsFolder:FindFirstChild(SlotKey)
    if SlotFrame then
        WireSlotButtons(SlotKey, SlotFrame)
    end
end

-- Close button fires CloseFrameBindable so UI.client handles the tween and HUD restore
CloseButton.MouseButton1Click:Connect(function()
    CloseFrameBindable:Fire(BoostTreeFrame)
end)

-- // Countdown loop — ticks every second to update Time labels on generating slots
task.spawn(function()
    while true do
        task.wait(1)

        for i = 1, 3 do
            local SlotKey = "Slot" .. i
            local SlotFrame = SlotsFolder:FindFirstChild(SlotKey)
            if not SlotFrame then continue end

            if SlotStates[SlotKey] ~= "Generating" then continue end

            local SlotConfig = SETTINGS.BOOST_TREE[SlotKey]
            local TimerStart = SlotTimerStarts[SlotKey]
            local TimeLabel = SlotFrame:FindFirstChild("Time")
            if not TimeLabel then continue end

            if TimerStart then
                local Remaining = SlotConfig.GenerationSeconds - (tick() - TimerStart)
                -- Only show countdown while time remains; server fires UpdateBoostTree when done
                TimeLabel.Text = Remaining > 0 and FormatCountdown(Remaining) or ""
            else
                TimeLabel.Text = ""
            end
        end
    end
end)
