-- RebirthWizard.client, initialized by KingCreoo
-- Drives the RebirthWizardFrame UI: lock/unselected/selected states for the soldier and boost
-- slots, the cost label, the Rebirth commit button, and the PerformRebirth remote round-trip.
--
-- Selection model: at most one soldier and one boost can be selected at a time. Clicking a
-- different option swaps the selection. The Rebirth button is gated to green-and-enabled only
-- when both a soldier and a boost are selected (and the player isn't at the cap).

-- // Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- // Variables
local LocalPlayer = Players.LocalPlayer
local LocalGui = LocalPlayer:WaitForChild("PlayerGui")

local SETTINGS = require(ReplicatedStorage:WaitForChild("Settings"))
local SOUND_MANAGER = require(ReplicatedStorage:WaitForChild("Settings"):WaitForChild("SoundManager"))

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local LoadPlayerEvent: RemoteEvent = Remotes:WaitForChild("LoadPlayer")
local PerformRebirthEvent: RemoteEvent = Remotes:WaitForChild("PerformRebirth")
local NotifyBindable: BindableEvent = Remotes:WaitForChild("NotifyBindable")
local CloseFrameBindable: BindableEvent = Remotes:WaitForChild("CloseFrame")

local FramesGui: ScreenGui = LocalGui:WaitForChild("Frames")
local RebirthWizardFrame: Frame = FramesGui:WaitForChild("RebirthWizardFrame")
local SoldiersFolder: Folder = RebirthWizardFrame:WaitForChild("Soldiers")
local BoostsFolder: Folder = RebirthWizardFrame:WaitForChild("Boosts")
local RebirthButton: TextButton = RebirthWizardFrame:WaitForChild("Rebirth")
local CloseButton: TextButton = RebirthWizardFrame:WaitForChild("Close")

-- // Visual constants

local LOCKED_COLOR    = Color3.fromRGB(85, 85, 127)  -- used for the gated Rebirth commit button
local UNSELECTED_BTN  = Color3.fromRGB(85, 85, 127)  -- gray Select button background
local SELECTED_BTN    = Color3.fromRGB(55, 212, 55)  -- green "Selected" base color
local CLAIM_COLOR1    = Color3.fromRGB(52, 255, 37)  -- claim gradient top
local CLAIM_COLOR2    = Color3.fromRGB(97, 189, 143) -- claim gradient bottom

-- Cached references to slot frames keyed by their wizard slot name
local SoldierSlots: {[string]: Frame} = {}
for SlotKey in pairs(SETTINGS.REBIRTH_SOLDIERS) do
    local Frame = SoldiersFolder:FindFirstChild(SlotKey)
    if Frame then SoldierSlots[SlotKey] = Frame end
end

local BoostSlots: {[string]: Frame} = {}
for FrameKey in pairs(SETTINGS.REBIRTH_BOOSTS) do
    local Frame = BoostsFolder:FindFirstChild(FrameKey)
    if Frame then BoostSlots[FrameKey] = Frame end
end

-- Latest server-truthed state used to compute lock vs unselected
local LatestData: any = nil
local CurrentSoldierAvailability: {[string]: boolean} = {} -- SlotKey  -> available
local CurrentBoostAvailability: {[string]: boolean} = {}   -- FrameKey -> available

-- Client selection (cleared on every fresh open and after a successful rebirth)
local SelectedSoldierSlot: string? = nil
local SelectedBoostFrame: string? = nil
local CommitDebounce = false

-- // Helpers

-- Gets or creates a UIGradient on the given GuiObject. Used to toggle the green "selected" gradient.
local function GetOrCreateGradient(Object: GuiObject): UIGradient
    local Existing = Object:FindFirstChildOfClass("UIGradient")
    if Existing then return Existing end
    local NewGradient = Instance.new("UIGradient")
    NewGradient.Parent = Object
    return NewGradient
end

-- Formats a number with comma separators, matching the existing UnlockSlots formatter.
local function FormatNumber(Value: number): string
    local Text = tostring(math.floor(Value))
    local K = #Text % 3
    if K == 0 then K = 3 end
    local Result = string.sub(Text, 1, K)
    for i = K + 1, #Text, 3 do
        Result = Result .. "," .. string.sub(Text, i, i + 2)
    end
    return Result
end

-- Three Select-button presentations. ButtonBackground / ImageLabel are NEVER touched by code
-- so the Studio-baked color, gradient, and image stay intact in every state.
--   "Select"        — gray bg, no gradient, label "Select"          (default unselected)
--   "Selected"      — green bg+gradient,  label "Selected"           (current pick)
--   "AlreadyOwned"  — gray bg, no gradient, label "Already owned"   (used in a prior rebirth)
local function SetSelectButtonPresentation(SelectButton: TextButton, Mode: string)
    local Gradient = GetOrCreateGradient(SelectButton)
    local Label = SelectButton:FindFirstChildOfClass("TextLabel")

    if Mode == "Selected" then
        SelectButton.BackgroundColor3 = SELECTED_BTN
        Gradient.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, CLAIM_COLOR1),
            ColorSequenceKeypoint.new(1, CLAIM_COLOR2)
        })
        Gradient.Enabled = true
        SelectButton.Active = true
        SelectButton.AutoButtonColor = true
        if Label then Label.Text = "Selected" end

    elseif Mode == "AlreadyOwned" then
        SelectButton.BackgroundColor3 = UNSELECTED_BTN
        Gradient.Enabled = false
        SelectButton.Active = false
        SelectButton.AutoButtonColor = false
        if Label then Label.Text = "Already owned" end

    else -- "Select"
        SelectButton.BackgroundColor3 = UNSELECTED_BTN
        Gradient.Enabled = false
        SelectButton.Active = true
        SelectButton.AutoButtonColor = true
        if Label then Label.Text = "Select" end
    end
end

-- Renders a single soldier slot. ButtonBackground visuals (color/gradient/image) are baked
-- into Studio via the SETUP_REBIRTH_WIZARD command-bar script — this function ONLY toggles
-- the Select button label/state and the ButtonBackground's clickability.
local function RenderSoldierSlot(SlotKey: string, SlotFrame: Frame)
    local Available = CurrentSoldierAvailability[SlotKey]
    local ButtonBg = SlotFrame:FindFirstChild("ButtonBackground") :: TextButton?
    local SelectBtn = SlotFrame:FindFirstChild("Select") :: TextButton?

    if ButtonBg then
        -- Active controls whether MouseButton1Click fires; AutoButtonColor controls the hover tint.
        ButtonBg.Active = Available == true
        ButtonBg.AutoButtonColor = Available == true
    end

    if not SelectBtn then return end
    SelectBtn.Visible = true

    if not Available then
        SetSelectButtonPresentation(SelectBtn, "AlreadyOwned")
    elseif SelectedSoldierSlot == SlotKey then
        SetSelectButtonPresentation(SelectBtn, "Selected")
    else
        SetSelectButtonPresentation(SelectBtn, "Select")
    end
end

-- Renders a single boost slot. Same contract as RenderSoldierSlot: never touches the
-- ButtonBackground's color/gradient/image so Studio's bake stays authoritative.
local function RenderBoostSlot(FrameKey: string, SlotFrame: Frame)
    local Available = CurrentBoostAvailability[FrameKey]
    local ButtonBg = SlotFrame:FindFirstChild("ButtonBackground") :: TextButton?
    local SelectBtn = SlotFrame:FindFirstChild("Select") :: TextButton?
    local AmountLabel = SlotFrame:FindFirstChild("Amount") :: TextLabel?

    if ButtonBg then
        ButtonBg.Active = Available == true
        ButtonBg.AutoButtonColor = Available == true
    end

    -- Always show the multiplier — even on already-owned slots it's useful context
    if AmountLabel then AmountLabel.Visible = true end

    if not SelectBtn then return end
    SelectBtn.Visible = true

    if not Available then
        SetSelectButtonPresentation(SelectBtn, "AlreadyOwned")
    elseif SelectedBoostFrame == FrameKey then
        SetSelectButtonPresentation(SelectBtn, "Selected")
    else
        SetSelectButtonPresentation(SelectBtn, "Select")
    end
end

-- Updates the Rebirth commit button color/gradient based on whether both selections are in.
local function RefreshRebirthButton()
    local AtCap = false
    if LatestData then
        AtCap = (LatestData.Rebirths or 0) >= SETTINGS.REBIRTH_CONFIG.MaxRebirths
    end

    local Ready = SelectedSoldierSlot ~= nil and SelectedBoostFrame ~= nil and not AtCap

    if Ready then
        RebirthButton.BackgroundColor3 = SELECTED_BTN
        local Gradient = GetOrCreateGradient(RebirthButton)
        Gradient.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, CLAIM_COLOR1),
            ColorSequenceKeypoint.new(1, CLAIM_COLOR2)
        })
        Gradient.Enabled = true
        RebirthButton.Active = true
        RebirthButton.AutoButtonColor = true
    else
        RebirthButton.BackgroundColor3 = LOCKED_COLOR
        local Gradient = RebirthButton:FindFirstChildOfClass("UIGradient")
        if Gradient then Gradient.Enabled = false end
        RebirthButton.Active = false
        RebirthButton.AutoButtonColor = false
    end
end

-- Finds the cost TextLabel on the frame. Prefers a child named "Cost" (per spec), but falls
-- back to scanning for a "$" prefixed TextLabel since the current Studio hierarchy names it
-- generically. See summary for the recommended Studio rename.
local function FindCostLabel(): TextLabel?
    local ByName = RebirthWizardFrame:FindFirstChild("Cost")
    if ByName and ByName:IsA("TextLabel") then
        return ByName
    end
    for _, Child in ipairs(RebirthWizardFrame:GetChildren()) do
        if Child:IsA("TextLabel") and string.sub(Child.Text, 1, 1) == "$" then
            return Child
        end
    end
    return nil
end
local CostLabel: TextLabel? = FindCostLabel()

-- Updates the cost label to reflect the player's next rebirth cost, or hides it at the cap.
local function RefreshCostLabel()
    if not CostLabel or not LatestData then return end
    local NextRebirth = (LatestData.Rebirths or 0) + 1
    local Costs = SETTINGS.REBIRTH_CONFIG.Costs
    local Cost = Costs[NextRebirth]
    if not Cost then
        CostLabel.Text = "MAX"
    else
        CostLabel.Text = "$" .. FormatNumber(Cost)
    end
end

-- Re-renders every slot + the Rebirth button + the cost label.
local function FullRefresh()
    for SlotKey, SlotFrame in pairs(SoldierSlots) do
        RenderSoldierSlot(SlotKey, SlotFrame)
    end
    for FrameKey, SlotFrame in pairs(BoostSlots) do
        RenderBoostSlot(FrameKey, SlotFrame)
    end
    RefreshRebirthButton()
    RefreshCostLabel()
end

-- Rebuilds availability dicts from fresh PlayerData and re-renders the wizard.
-- Also clears any stale local selection that points at a now-locked option.
local function SeedFromPlayerData(PlayerData: table)
    if not PlayerData then return end
    LatestData = PlayerData

    local PickedSoldiers = (PlayerData.Rebirth and PlayerData.Rebirth.PickedSoldiers) or {}
    local PickedBoosts   = (PlayerData.Rebirth and PlayerData.Rebirth.PickedBoosts)   or {}

    CurrentSoldierAvailability = {}
    for SlotKey, SoldierType in pairs(SETTINGS.REBIRTH_SOLDIERS) do
        CurrentSoldierAvailability[SlotKey] = not (PickedSoldiers[SoldierType] == true)
    end

    CurrentBoostAvailability = {}
    for FrameKey, BoostConfig in pairs(SETTINGS.REBIRTH_BOOSTS) do
        CurrentBoostAvailability[FrameKey] = not (PickedBoosts[BoostConfig.Type] == true)
    end

    -- Drop any prior selection that became locked between opens
    if SelectedSoldierSlot and not CurrentSoldierAvailability[SelectedSoldierSlot] then
        SelectedSoldierSlot = nil
    end
    if SelectedBoostFrame and not CurrentBoostAvailability[SelectedBoostFrame] then
        SelectedBoostFrame = nil
    end

    FullRefresh()
end

-- // Selection handlers

-- Toggles a soldier slot selection (only one selection at a time across the three soldier slots).
local function OnSoldierClicked(SlotKey: string)
    if not CurrentSoldierAvailability[SlotKey] then return end
    SOUND_MANAGER:PlayClick()
    SelectedSoldierSlot = (SelectedSoldierSlot == SlotKey) and nil or SlotKey
    FullRefresh()
end

-- Toggles a boost slot selection (only one selection at a time across the three boost slots).
local function OnBoostClicked(FrameKey: string)
    if not CurrentBoostAvailability[FrameKey] then return end
    SOUND_MANAGER:PlayClick()
    SelectedBoostFrame = (SelectedBoostFrame == FrameKey) and nil or FrameKey
    FullRefresh()
end

-- Sends the rebirth request to the server. Server re-validates everything and responds via
-- PerformRebirthEvent. On success it also fires LoadPlayerEvent("Rebirth") which will re-seed.
local function OnRebirthClicked()
    if CommitDebounce then return end
    if not SelectedSoldierSlot or not SelectedBoostFrame then
        NotifyBindable:Fire("Select a soldier and a boost!", 1, Color3.fromRGB(255, 100, 100))
        return
    end
    if not LatestData then
        NotifyBindable:Fire("Loading...", 0.8, Color3.fromRGB(255, 255, 0))
        return
    end
    if (LatestData.Rebirths or 0) >= SETTINGS.REBIRTH_CONFIG.MaxRebirths then
        NotifyBindable:Fire("Max rebirths!", 1, Color3.fromRGB(255, 255, 0))
        return
    end

    CommitDebounce = true
    SOUND_MANAGER:PlayClick()
    PerformRebirthEvent:FireServer(SelectedSoldierSlot, SelectedBoostFrame)

    -- Auto-clear the debounce after the round-trip window (server returns same remote)
    task.delay(2, function()
        CommitDebounce = false
    end)
end

-- // Wiring

for SlotKey, SlotFrame in pairs(SoldierSlots) do
    local ButtonBg = SlotFrame:FindFirstChild("ButtonBackground")
    local SelectBtn = SlotFrame:FindFirstChild("Select")
    if ButtonBg and ButtonBg:IsA("TextButton") then
        ButtonBg.MouseButton1Click:Connect(function() OnSoldierClicked(SlotKey) end)
    end
    if SelectBtn and SelectBtn:IsA("TextButton") then
        SelectBtn.MouseButton1Click:Connect(function() OnSoldierClicked(SlotKey) end)
    end
end

for FrameKey, SlotFrame in pairs(BoostSlots) do
    local ButtonBg = SlotFrame:FindFirstChild("ButtonBackground")
    local SelectBtn = SlotFrame:FindFirstChild("Select")
    if ButtonBg and ButtonBg:IsA("TextButton") then
        ButtonBg.MouseButton1Click:Connect(function() OnBoostClicked(FrameKey) end)
    end
    if SelectBtn and SelectBtn:IsA("TextButton") then
        SelectBtn.MouseButton1Click:Connect(function() OnBoostClicked(FrameKey) end)
    end
end

RebirthButton.MouseButton1Click:Connect(OnRebirthClicked)

CloseButton.MouseButton1Click:Connect(function()
    SOUND_MANAGER:PlayClick()
    CloseFrameBindable:Fire(RebirthWizardFrame)
end)

-- // Server events

-- Server response handler. Success path is also handled via LoadPlayerEvent("Rebirth") below,
-- so we only act on failure / informational replies here. The Reason string mirrors
-- RebirthManager's return values.
PerformRebirthEvent.OnClientEvent:Connect(function(Reason: string, Success: boolean?)
    CommitDebounce = false

    if Success then
        -- Wait for LoadPlayerEvent to re-seed; clear local selection and close the wizard
        SelectedSoldierSlot = nil
        SelectedBoostFrame = nil
        SOUND_MANAGER:PlayPurchase()
        NotifyBindable:Fire("Rebirthed!", 1.2, Color3.fromRGB(0, 255, 100))
        if RebirthWizardFrame.Visible then
            CloseFrameBindable:Fire(RebirthWizardFrame)
        end
        return
    end

    local Message, Color = "Rebirth failed.", Color3.fromRGB(255, 0, 0)
    if Reason == "Insufficient" then
        Message, Color = "Not enough credits!", Color3.fromRGB(255, 0, 0)
    elseif Reason == "MaxRebirths" then
        Message, Color = "Max rebirths reached!", Color3.fromRGB(255, 255, 0)
    elseif Reason == "Invalid" then
        Message, Color = "Pick a soldier and a boost!", Color3.fromRGB(255, 100, 100)
    elseif Reason == "SoldierUnavailable" then
        Message, Color = "Soldier already picked!", Color3.fromRGB(255, 100, 100)
    elseif Reason == "BoostUnavailable" then
        Message, Color = "Boost already picked!", Color3.fromRGB(255, 100, 100)
    elseif Reason == "RateLimit" then
        Message, Color = "Slow down!", Color3.fromRGB(255, 100, 100)
    end
    NotifyBindable:Fire(Message, 1, Color)
end)

-- Seed from initial data on join and after each rebirth (server pushes the new PlayerData).
LoadPlayerEvent.OnClientEvent:Connect(function(PlayerData: table, EntryName: string?)
    SeedFromPlayerData(PlayerData)
end)
