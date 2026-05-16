-- Boosts.client, initialized by KingCreoo
-- Manages the BoostsDisplay HUD widget: shows active boost cards with live countdown timers.

-- // Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- // Variables
local LocalPlayer = Players.LocalPlayer
local LocalGui = LocalPlayer:WaitForChild("PlayerGui")

local HUD: ScreenGui = LocalGui:WaitForChild("HUD")
local BoostsDisplay: Frame = HUD:WaitForChild("BoostsDisplay")
local BoostList: Frame = BoostsDisplay:WaitForChild("BoostList")

-- Card instances keyed by boost type identifier
local BOOST_CARDS = {
    ["CashMultiplier"]     = BoostList:WaitForChild("CashBoost"),
    ["DamageMultiplier"]   = BoostList:WaitForChild("DamageBoost"),
    ["FireRateMultiplier"] = BoostList:WaitForChild("FirerateBoost"),
    ["TargetMultiplier"]   = BoostList:WaitForChild("TargetBoost"),
}

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local UpdateBoostsEvent: RemoteEvent = Remotes:WaitForChild("UpdateBoosts")
local LoadPlayerEvent: RemoteEvent = Remotes:WaitForChild("LoadPlayer")

-- In-memory active boost state: [BoostType] = { Amount, ExpiresAt }
local ActiveBoosts = {}

-- // Local Functions

-- Formats remaining seconds into a human-readable countdown string.
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
    -- Show one decimal place only if needed
    if Amount == math.floor(Amount) then
        return tostring(math.floor(Amount)) .. "x"
    else
        return string.format("%.1fx", Amount)
    end
end

-- Refreshes the visibility and text of all boost cards based on ActiveBoosts.
-- Called on every state change and every second from the countdown loop.
local function RefreshDisplay()
    local Now = os.time()
    local AnyActive = false

    for BoostType, Card in pairs(BOOST_CARDS) do
        local Entry = ActiveBoosts[BoostType]
        local IsActive = Entry ~= nil and Entry.ExpiresAt > Now

        if IsActive then
            AnyActive = true
            Card.Visible = true

            local AmountLabel = Card:FindFirstChild("Amount")
            local TimeLabel = Card:FindFirstChild("Time")

            if AmountLabel then
                AmountLabel.Text = FormatAmount(Entry.Amount)
            end
            if TimeLabel then
                TimeLabel.Text = FormatCountdown(Entry.ExpiresAt - Now)
            end
        else
            Card.Visible = false
            -- Clean up expired entries from the local table
            if Entry and Entry.ExpiresAt <= Now then
                ActiveBoosts[BoostType] = nil
            end
        end
    end

    -- Show/hide the entire BoostsDisplay (including the BOOSTS label) based on activity
    BoostsDisplay.Visible = AnyActive
end

-- Applies a new boost state table from the server. Replaces the full ActiveBoosts dict.
local function ApplyBoostState(BoostState: table)
    -- Replace entire state (server is authoritative)
    ActiveBoosts = {}
    if BoostState then
        for BoostType, Entry in pairs(BoostState) do
            ActiveBoosts[BoostType] = Entry
        end
    end
    RefreshDisplay()
end

-- // Events

-- Server fires this whenever active boost state changes (boost added, expired, or claimed)
UpdateBoostsEvent.OnClientEvent:Connect(function(BoostState: table)
    ApplyBoostState(BoostState)
end)

-- Seed from PlayerData on join (LoadPlayerEvent carries the full data table)
LoadPlayerEvent.OnClientEvent:Connect(function(PlayerData: table)
    if not PlayerData or not PlayerData.Boosts or not PlayerData.Boosts.Active then return end

    -- Build the client-format state from the raw PlayerData (filter expired entries)
    local Now = os.time()
    local BoostState = {}
    for BoostType, Entry in pairs(PlayerData.Boosts.Active) do
        if Entry.ExpiresAt > Now then
            BoostState[BoostType] = { Amount = Entry.Amount, ExpiresAt = Entry.ExpiresAt }
        end
    end
    ApplyBoostState(BoostState)
end)

-- // Countdown loop — ticks every second to update Time labels and hide expired cards
task.spawn(function()
    while true do
        task.wait(1)
        RefreshDisplay()
    end
end)

-- Initial state: hide everything until LoadPlayerEvent fires
BoostsDisplay.Visible = false
for _, Card in pairs(BOOST_CARDS) do
    Card.Visible = false
end
