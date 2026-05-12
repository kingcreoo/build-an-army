-- // RateLimit, initialized by KingCreoo
-- // Server-side rate limiter for write-path remotes. Prevents spam from blowing the DataStore budget.

local RateLimit = {}

-- Tracks last-call timestamps per player per key: { [PlayerName] = { [Key] = {timestamps} } }
local Buckets = {}

-- Clears a player's bucket on leave so memory doesn't accumulate
local Players = game:GetService("Players")
Players.PlayerRemoving:Connect(function(Player: Player)
    Buckets[Player.Name] = nil
end)

-- Returns true if the call is allowed, false if the player is over the limit.
-- key        — identifies the action (e.g. "SellSoldier", "UnlockSlot")
-- maxCalls   — maximum allowed calls within windowSeconds
-- windowSeconds — rolling window size in seconds (default 5)
function RateLimit.Check(Player: Player, Key: string, MaxCalls: number, WindowSeconds: number?): boolean
    local Window = WindowSeconds or 5
    local Now = os.clock()

    if not Buckets[Player.Name] then
        Buckets[Player.Name] = {}
    end
    if not Buckets[Player.Name][Key] then
        Buckets[Player.Name][Key] = {}
    end

    local Timestamps = Buckets[Player.Name][Key]

    -- Evict timestamps outside the rolling window
    local Cutoff = Now - Window
    local WriteIdx = 1
    for _, T in ipairs(Timestamps) do
        if T > Cutoff then
            Timestamps[WriteIdx] = T
            WriteIdx += 1
        end
    end
    for i = WriteIdx, #Timestamps do
        Timestamps[i] = nil
    end

    -- Reject if already at the limit
    if #Timestamps >= MaxCalls then
        return false
    end

    -- Record this call
    table.insert(Timestamps, Now)
    return true
end

return RateLimit
