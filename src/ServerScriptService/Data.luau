-- // Data, initialized by KingCreoo on 8-19-2025
-- // Player data persistence: load on join, save on leave, save on shutdown.
-- // All persistent writes go through UpdateAsync with bounded retry.
-- // On load failure the player is kicked rather than handed default data
-- // (avoids the classic Roblox data-wipe bug from a transient outage).

local Data = {}

-- // Services
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

-- // Modules
local Settings = require(ReplicatedStorage:WaitForChild("Settings"))
local RewardLoop = require(ServerScriptService:WaitForChild("Server"):WaitForChild("RewardLoop"))

-- // Variables
local DataStore = DataStoreService:GetDataStore("PlayerData_v5")

local CURRENT_DATA_VERSION = 1
local LOAD_ATTEMPTS = 3
local SAVE_ATTEMPTS = 3
local LOAD_BACKOFFS = {0.5, 1.5} -- seconds between load attempts 1->2 and 2->3
local SAVE_BACKOFFS = {1.0, 3.0} -- seconds between save attempts 1->2 and 2->3
local SHUTDOWN_BUDGET_SECONDS = 25 -- Roblox allows ~30s in BindToClose

local Database = {}

-- // Local helpers

-- Recursively clones a table so callers can mutate without touching the original
local function DeepCopy(Table: any): any
    if type(Table) ~= "table" then
        return Table
    end

    local Copy = {}
    for K, V in pairs(Table) do
        if type(V) == "table" then
            Copy[K] = DeepCopy(V)
        else
            Copy[K] = V
        end
    end
    return Copy
end

-- Merges any missing default keys into loaded player data without overwriting values
local function ApplyDefaults(Target: table, Defaults: table)
    for K, V in pairs(Defaults) do
        if Target[K] == nil then
            if type(V) == "table" then
                Target[K] = DeepCopy(V)
            else
                Target[K] = V
            end
        elseif type(Target[K]) == "table" and type(V) == "table" then
            ApplyDefaults(Target[K], V)
        end
    end
end

-- Bumps any older save to the current schema version. Future migrations slot in here.
local function ApplyMigrations(PlayerData: table)
    local Version = PlayerData._Version or 0

    if Version < 1 then
        -- Soldier rename migration: commit 72ccf08 renamed soldiers without a migration.
        -- Any save written before that commit has the old type strings in SoldierInventory.
        local RenameMap = {
            ["The Grunt"]     = "Grunt",
            ["The Shotgunner"] = "Shotgunner",
            ["The Heavy"]     = "Heavy",
            ["The Dual"]      = "Dualie",
        }
        local Inventory = PlayerData.Inventory and PlayerData.Inventory.SoldierInventory
        if Inventory then
            for _, SoldierData in pairs(Inventory) do
                local NewName = RenameMap[SoldierData.Type]
                if NewName then
                    SoldierData.Type = NewName
                end
            end
        end
        -- Also fix ActiveSoldiers if stored as old compact array (pre-dict format)
        -- ActiveSoldiers was previously a compact array; now it's a dict keyed by lane number.
        -- If we find numeric sequential keys starting at 1 with no gaps, rewrite as dict.
        local Active = PlayerData.Inventory and PlayerData.Inventory.ActiveSoldiers
        if Active then
            local IsCompactArray = Active[1] ~= nil
            if IsCompactArray then
                local NewActive = {}
                for i, SoldierID in ipairs(Active) do
                    NewActive[i] = SoldierID
                end
                PlayerData.Inventory.ActiveSoldiers = NewActive
            end
        end
    end

    PlayerData._Version = CURRENT_DATA_VERSION
end

-- Reads a player's save with bounded retry. Returns (data, errored). data may be nil for a fresh player.
local function LoadWithRetry(UserId: number): (any, boolean, string?)
    local LastErr: string? = nil
    for Attempt = 1, LOAD_ATTEMPTS do
        local Success, Result = pcall(function()
            return DataStore:GetAsync("Player_" .. UserId)
        end)
        if Success then
            return Result, false, nil
        end
        LastErr = tostring(Result)
        if Attempt < LOAD_ATTEMPTS then
            task.wait(LOAD_BACKOFFS[Attempt] or 1)
        end
    end
    return nil, true, LastErr
end

-- Atomic per-key write with bounded retry. Returns (success, error).
local function SaveWithRetry(UserId: number, PlayerData: table): (boolean, string?)
    local LastErr: string? = nil
    for Attempt = 1, SAVE_ATTEMPTS do
        local Success, Result = pcall(function()
            DataStore:UpdateAsync("Player_" .. UserId, function(_OldData)
                -- Transform function must not yield. Wholesale overwrite is intentional:
                -- the in-memory copy is the authoritative version for this session.
                return PlayerData
            end)
        end)
        if Success then
            return true, nil
        end
        LastErr = tostring(Result)
        if Attempt < SAVE_ATTEMPTS then
            task.wait(SAVE_BACKOFFS[Attempt] or 1)
        end
    end
    return false, LastErr
end

-- Pushes leaderstats values from PlayerData onto the player's existing leaderstats folder
local function SyncLeaderstats(Player: Player, PlayerData: table)
    local Leaderstats = Player:FindFirstChild("leaderstats")
    if not Leaderstats then return end

    for Stat, Value in pairs(PlayerData["leaderstats"]) do
        local StatObject = Leaderstats:FindFirstChild(Stat)
        if StatObject then
            StatObject.Value = Value
        end
    end
end

-- // Module functions

-- Loads player data on join. KICKS on load failure so a transient outage never overwrites real data.
-- Returns (PlayerData, NewPlayer). If the kick path runs, returns (nil, false) and caller must bail.
function Data.Initialize(Player: Player): (table?, boolean)
    local LoadedData, Errored, ErrorMessage = LoadWithRetry(Player.UserId)

    if Errored then
        warn("[Data] Load failed for " .. Player.Name .. ": " .. tostring(ErrorMessage))
        Player:Kick("Failed to load your data. Please rejoin in a moment.")
        return nil, false
    end

    local NewPlayer: boolean
    if LoadedData == nil then
        LoadedData = DeepCopy(Settings.DEFAULT_DATA)
        NewPlayer = true
    else
        ApplyDefaults(LoadedData, Settings.DEFAULT_DATA)
        ApplyMigrations(LoadedData)
        NewPlayer = false
    end

    Database[Player.Name] = LoadedData
    return LoadedData, NewPlayer
end

-- Writes player data. Returns (success, error). DontSave=true skips persistence and always returns true.
function Data.Set(Player: Player, PlayerData: table, DontSave: boolean?): (boolean, string?)
    Database[Player.Name] = PlayerData
    SyncLeaderstats(Player, PlayerData)

    if DontSave then
        return true, nil
    end

    local Success, ErrorMessage = SaveWithRetry(Player.UserId, PlayerData)
    if not Success then
        warn("[Data] Save failed for " .. Player.Name .. ": " .. tostring(ErrorMessage))
    end
    return Success, ErrorMessage
end

-- Returns the in-memory player data table (reference, not a copy)
function Data.Get(Player: Player): table?
    return Database[Player.Name]
end

-- Saves and removes a player's data on leave. Captures LogOff + PendingCash before write.
-- Returns (success, error). Database entry is cleared regardless of save outcome.
function Data.Remove(Player: Player): (boolean, string?)
    local Existing = Database[Player.Name]
    if not Existing then
        return true, nil
    end

    -- Deep-clone before mutating so we don't disturb the live in-memory copy if save retries
    local PlayerData = DeepCopy(Existing)
    PlayerData["LogOff"] = os.time()
    -- Deep-clone PendingCash too — RewardLoop wipes its own table 5s after PlayerRemoving
    PlayerData["PendingCash"] = DeepCopy(RewardLoop.GetPendingCash(Player.Name))

    Database[Player.Name] = nil

    local Success, ErrorMessage = SaveWithRetry(Player.UserId, PlayerData)
    if not Success then
        warn("[Data] Final save failed for " .. Player.Name .. ": " .. tostring(ErrorMessage))
    end
    return Success, ErrorMessage
end

-- // Shutdown handler

-- Flushes every in-memory save when the server shuts down. Saves run in parallel within Roblox's budget.
-- In practice this only catches players whose PlayerRemoving hasn't run yet; Data.Remove is idempotent
-- (no-ops when Database entry is already cleared).
game:BindToClose(function()
    local Threads: {thread} = {}
    for PlayerName in pairs(Database) do
        local Player = Players:FindFirstChild(PlayerName)
        if Player then
            local Thread = task.spawn(function()
                Data.Remove(Player)
            end)
            table.insert(Threads, Thread)
        end
    end

    -- Wait for all save threads to finish or our budget to run out
    local Deadline = os.clock() + SHUTDOWN_BUDGET_SECONDS
    while os.clock() < Deadline do
        local AnyAlive = false
        for _, Thread in ipairs(Threads) do
            if coroutine.status(Thread) ~= "dead" then
                AnyAlive = true
                break
            end
        end
        if not AnyAlive then break end
        task.wait(0.1)
    end
end)

return Data
