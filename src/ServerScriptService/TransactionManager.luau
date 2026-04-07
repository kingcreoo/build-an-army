-- // TransactionManager, initialized by KingCreoo on 2026-04-04
-- // Config-driven Robux dev product and gamepass handler with strict idempotency

--[[
    OVERVIEW
    --------
    Loads ProductConfig and wires up Roblox's purchase pipeline so every listed
    product/gamepass grants automatically via its OnGrant callback. Safe to call
    from anywhere; the client triggers prompts via MarketplaceService directly
    (no remote events required).

    PUBLIC API
    ----------
    TransactionManager.Initialize()                  -- call once from server bootstrap
    TransactionManager.OnPlayerAdded(Player)         -- call from OnPlayerAdded after data loads
    TransactionManager.IsPassOwned(Player, Name)     -- runtime query for continuous effects
    TransactionManager.GetProductByName(Name)        -- lookup helper (returns config entry or nil)
    TransactionManager.GetProductIdByName(Name)      -- returns numeric id for a registered name

    SECURITY MODEL
    --------------
    * Dev product grants happen exclusively inside MarketplaceService.ProcessReceipt. This is
      the only handler Roblox guarantees delivery for, even across server restarts.
    * Idempotency is enforced via PlayerData.Transactions.GrantedPurchases[PurchaseId]. A
      receipt is only marked granted AFTER its OnGrant runs and PlayerData is persisted.
    * If player data isn't loaded yet (offline purchase, data still fetching), we return
      NotProcessedYet and Roblox will retry the receipt later, preserving the purchase.
    * Unknown product IDs return NotProcessedYet (never PurchaseGranted) so Roblox keeps
      retrying until we register them. This means misconfiguration can't silently eat money.
    * All OnGrant calls are wrapped in pcall; a throwing handler returns NotProcessedYet.
    * Gamepass grants are idempotent via PlayerData.Transactions.AppliedPasses[PassName].
      The manager checks ownership on join and on live purchase, and applies OnGrant exactly
      once regardless of how many servers the player joins.
]]

-- // Define
local TransactionManager = {}

-- // Services
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

-- // Modules
local Data = require(ServerScriptService:WaitForChild("Server"):WaitForChild("Data"))

-- // Remotes
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local LoadPlayerEvent: RemoteEvent = Remotes:WaitForChild("LoadPlayer")

-- // Variables

-- Products indexed by friendly name (source of truth for OnGrant callbacks)
local ProductsByName = {}

-- Products indexed by Roblox product/gamepass ID (used by ProcessReceipt and event handlers)
local ProductsById = {}

-- Cached gamepass ownership per player: { [PlayerName] = { [PassName] = true } }
local OwnershipCache = {}

local Initialized = false

-- // Private functions

-- Ensures a PlayerData table has the Transactions sub-tables we rely on
local function EnsureTransactionsScaffold(PlayerData: table)
    if not PlayerData.Transactions then
        PlayerData.Transactions = {}
    end
    if not PlayerData.Transactions.GrantedPurchases then
        PlayerData.Transactions.GrantedPurchases = {}
    end
    if not PlayerData.Transactions.AppliedPasses then
        PlayerData.Transactions.AppliedPasses = {}
    end
end

-- Validates a single config entry and returns true if it is registerable
local function ValidateConfig(Name: string, Entry: any): boolean
    if type(Entry) ~= "table" then
        warn("[TransactionManager] Config entry '" .. Name .. "' must be a table")
        return false
    end
    if Entry.Type ~= "DevProduct" and Entry.Type ~= "Gamepass" then
        warn("[TransactionManager] Config entry '" .. Name .. "' has invalid Type: " .. tostring(Entry.Type))
        return false
    end
    if type(Entry.Id) ~= "number" then
        warn("[TransactionManager] Config entry '" .. Name .. "' has non-numeric Id")
        return false
    end
    if Entry.Id == 0 then
        -- Placeholder entry; skip silently (user hasn't filled in real ID yet)
        return false
    end
    if type(Entry.OnGrant) ~= "function" then
        warn("[TransactionManager] Config entry '" .. Name .. "' missing OnGrant function")
        return false
    end
    return true
end

-- Registers a single validated config entry into both lookup tables
local function RegisterEntry(Name: string, Entry: table)
    if ProductsById[Entry.Id] then
        warn("[TransactionManager] Duplicate product ID " .. tostring(Entry.Id) .. " between '" .. Name .. "' and '" .. ProductsById[Entry.Id].Name .. "'")
        return
    end

    -- Attach the friendly name to the entry for reverse lookup in handlers
    Entry.Name = Name
    ProductsByName[Name] = Entry
    ProductsById[Entry.Id] = Entry
end

-- Counts keys in a dictionary-style table
local function CountKeys(Table: table): number
    local Count = 0
    for _ in pairs(Table) do
        Count += 1
    end
    return Count
end

-- Loads ProductConfig and registers every valid entry
local function LoadConfig()
    local Config = require(ServerScriptService:WaitForChild("Server"):WaitForChild("ProductConfig"))

    for Name, Entry in pairs(Config) do
        if ValidateConfig(Name, Entry) then
            RegisterEntry(Name, Entry)
        end
    end

    print("[TransactionManager] Registered " .. tostring(CountKeys(ProductsByName)) .. " products")
end

-- Dev product grant handler: runs OnGrant and records the receipt as granted
local function GrantDevProduct(Player: Player, Entry: table, PurchaseId: string): (boolean, string?)
    local PlayerData = Data.Get(Player)
    if not PlayerData then
        return false
    end

    EnsureTransactionsScaffold(PlayerData)

    -- Idempotency: if we've already granted this exact receipt, short-circuit
    if PlayerData.Transactions.GrantedPurchases[PurchaseId] then
        return true
    end

    -- Run the user's handler inside pcall so a bad handler doesn't burn the receipt
    local Success, Err = pcall(Entry.OnGrant, Player, PlayerData)
    if not Success then
        warn("[TransactionManager] OnGrant for '" .. Entry.Name .. "' errored: " .. tostring(Err))
        return false
    end

    -- Mark the receipt as granted BEFORE persisting, so the save includes it atomically
    PlayerData.Transactions.GrantedPurchases[PurchaseId] = true

    -- Persist. Data.Set is synchronous and pcalls internally so it won't throw.
    Data.Set(Player, PlayerData)

    -- Push updated data to client so UI refreshes (inventory, credits, etc.)
    LoadPlayerEvent:FireClient(Player, PlayerData, Entry.Name)
    return true
end

-- Gamepass grant handler: idempotent via AppliedPasses flag
local function ApplyGamepassGrant(Player: Player, Entry: table): boolean
    local PlayerData = Data.Get(Player)
    if not PlayerData then
        return false
    end

    EnsureTransactionsScaffold(PlayerData)

    -- Already applied for this player; nothing to do
    if PlayerData.Transactions.AppliedPasses[Entry.Name] then
        return true
    end

    local Success, Err = pcall(Entry.OnGrant, Player, PlayerData)
    if not Success then
        warn("[TransactionManager] Gamepass OnGrant for '" .. Entry.Name .. "' errored: " .. tostring(Err))
        return false
    end

    PlayerData.Transactions.AppliedPasses[Entry.Name] = true
    Data.Set(Player, PlayerData)
    LoadPlayerEvent:FireClient(Player, PlayerData, Entry.Name)
    return true
end

-- Checks gamepass ownership via Roblox API, with pcall and caching per player
local function CheckGamepassOwnership(Player: Player, PassId: number): boolean
    local CacheKey = Player.Name
    if OwnershipCache[CacheKey] and OwnershipCache[CacheKey][PassId] ~= nil then
        return OwnershipCache[CacheKey][PassId]
    end

    local Success, Owns = pcall(function()
        return MarketplaceService:UserOwnsGamePassAsync(Player.UserId, PassId)
    end)

    if not Success then
        warn("[TransactionManager] UserOwnsGamePassAsync failed for " .. Player.Name .. " pass " .. tostring(PassId))
        return false
    end

    if not OwnershipCache[CacheKey] then
        OwnershipCache[CacheKey] = {}
    end
    OwnershipCache[CacheKey][PassId] = Owns
    return Owns
end

-- ProcessReceipt callback registered with MarketplaceService
local function ProcessReceipt(ReceiptInfo)
    -- Resolve player; if they've left, Roblox retries when they next join
    local Player = Players:GetPlayerByUserId(ReceiptInfo.PlayerId)
    if not Player then
        return Enum.ProductPurchaseDecision.NotProcessedYet
    end

    -- Look up the product. Unknown IDs never ack - they will retry until we register them.
    local Entry = ProductsById[ReceiptInfo.ProductId]
    if not Entry or Entry.Type ~= "DevProduct" then
        warn("[TransactionManager] Unregistered or wrong-type product ID received: " .. tostring(ReceiptInfo.ProductId))
        return Enum.ProductPurchaseDecision.NotProcessedYet
    end

    -- Grant, returning NotProcessedYet on any failure so Roblox retries
    local Granted = GrantDevProduct(Player, Entry, ReceiptInfo.PurchaseId)
    if not Granted then
        return Enum.ProductPurchaseDecision.NotProcessedYet
    end

    return Enum.ProductPurchaseDecision.PurchaseGranted
end

-- Handler for live gamepass purchase completions
local function OnGamepassPurchaseFinished(Player: Player, GamepassId: number, WasPurchased: boolean)
    if not WasPurchased then return end

    local Entry = ProductsById[GamepassId]
    if not Entry or Entry.Type ~= "Gamepass" then
        warn("[TransactionManager] Unregistered gamepass ID purchased: " .. tostring(GamepassId))
        return
    end

    -- Update cache since ownership just changed
    if not OwnershipCache[Player.Name] then
        OwnershipCache[Player.Name] = {}
    end
    OwnershipCache[Player.Name][GamepassId] = true

    ApplyGamepassGrant(Player, Entry)
end

-- // Public functions

-- Wires up MarketplaceService handlers and loads the product config
function TransactionManager.Initialize()
    if Initialized then
        warn("[TransactionManager] Initialize called twice")
        return
    end
    Initialized = true

    LoadConfig()

    -- Connect Roblox's receipt pipeline
    MarketplaceService.ProcessReceipt = ProcessReceipt
    MarketplaceService.PromptGamePassPurchaseFinished:Connect(OnGamepassPurchaseFinished)

    -- Clear ownership cache when players leave to avoid stale data across reconnects
    Players.PlayerRemoving:Connect(function(Player)
        OwnershipCache[Player.Name] = nil
    end)
end

-- Called from main OnPlayerAdded after Data.Initialize has populated the player's data.
-- Checks all registered gamepasses and applies any whose grants haven't run yet.
function TransactionManager.OnPlayerAdded(Player: Player)
    for _, Entry in pairs(ProductsByName) do
        if Entry.Type == "Gamepass" then
            if CheckGamepassOwnership(Player, Entry.Id) then
                ApplyGamepassGrant(Player, Entry)
            end
        end
    end
end

-- Runtime query for continuous gamepass effects. Safe to call every frame (cached).
function TransactionManager.IsPassOwned(Player: Player, PassName: string): boolean
    local Entry = ProductsByName[PassName]
    if not Entry or Entry.Type ~= "Gamepass" then
        return false
    end
    return CheckGamepassOwnership(Player, Entry.Id)
end

-- Lookup helper: returns the config entry for a registered name, or nil
function TransactionManager.GetProductByName(Name: string)
    return ProductsByName[Name]
end

-- Lookup helper: returns the numeric ID for a registered name, or nil
function TransactionManager.GetProductIdByName(Name: string): number?
    local Entry = ProductsByName[Name]
    return Entry and Entry.Id or nil
end

-- // Return
return TransactionManager
