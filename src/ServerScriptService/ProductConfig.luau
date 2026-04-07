-- // ProductConfig, defines all Robux products and gamepasses for this game
-- // Add new entries here. TransactionManager picks them up automatically on startup.

--[[
    ENTRY STRUCTURE
    ----------------
    EntryName = {
        Type = "DevProduct" | "Gamepass",
        Id   = <RobuxProductOrPassId>,

        -- Called when a purchase is granted to a player.
        -- Mutates PlayerData in place; do NOT call Data.Set yourself.
        -- Runs inside a pcall; throwing will cause the purchase to retry.
        OnGrant = function(Player: Player, PlayerData: table)
            -- your grant logic here
        end,
    }

    RULES
    -----
    * Dev products are consumable (can be purchased repeatedly). Each grant runs OnGrant once.
    * Gamepasses are permanent. OnGrant runs exactly once per player across all sessions (first
      time ownership is detected), tracked via PlayerData.Transactions.AppliedPasses.
    * For continuous gamepass effects (e.g. "earn 2x credits forever"), DO NOT put the multiplier
      logic in OnGrant. Instead query TransactionManager:IsPassOwned(Player, "Name") at runtime.
      OnGrant is for one-time grants like "unlock slot 7".

    To register a product, simply add an entry below. To disable one temporarily, set its Id = 0.
]]

-- // Services
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- // Modules
local SETTINGS = require(ReplicatedStorage:WaitForChild("Settings"))

-- // Shared grant helpers

-- Grants a single soldier of the given type by inserting a new instance into the player's inventory
local function GrantSoldier(PlayerData: table, SoldierType: string)
    local SoldierEntry = SETTINGS.SOLDIER_DATA[SoldierType]
    if not SoldierEntry then
        error("GrantSoldier: unknown soldier type '" .. tostring(SoldierType) .. "'")
    end

    local SoldierID = HttpService:GenerateGUID()
    PlayerData.Inventory.SoldierInventory[SoldierID] = {
        ["Model"] = SoldierEntry.Model or SoldierType,
        ["Type"] = SoldierType
    }
end

-- Builds an OnGrant handler that simply gives the player one copy of a specific soldier type
local function MakeSoldierGrant(SoldierType: string)
    return function(_: Player, PlayerData: table)
        GrantSoldier(PlayerData, SoldierType)
    end
end

-- Builds an OnGrant handler that adds a flat credit amount to the player
local function MakeCashGrant(Amount: number)
    return function(_: Player, PlayerData: table)
        PlayerData.leaderstats.Credits += Amount
    end
end

return {
    -- ============================================================
    -- CASH PACKS — Small / Medium / Large
    -- Credit amounts sourced from SETTINGS.CASH_PACKS
    -- ============================================================

    SmallCashPack = {
        Type = "DevProduct",
        Id = 3571886775,
        OnGrant = MakeCashGrant(SETTINGS.CASH_PACKS.Small.Credits),
    },

    MediumCashPack = {
        Type = "DevProduct",
        Id = 3571886874,
        OnGrant = MakeCashGrant(SETTINGS.CASH_PACKS.Medium.Credits),
    },

    LargeCashPack = {
        Type = "DevProduct",
        Id = 3571886955,
        OnGrant = MakeCashGrant(SETTINGS.CASH_PACKS.Large.Credits),
    },

    -- ============================================================
    -- STARTER PACK — Bandit + Raider + bonus credits (one-time forever)
    -- ============================================================

    StarterPack = {
        Type = "DevProduct",
        Id = SETTINGS.STARTER_PACK.ProductId,
        OnGrant = function(_: Player, PlayerData: table)
            if not PlayerData.Offers then
                PlayerData.Offers = {}
            end

            if PlayerData.Offers.StarterPackPurchased then
                return
            end

            for _, SoldierType in ipairs(SETTINGS.STARTER_PACK.Soldiers) do
                GrantSoldier(PlayerData, SoldierType)
            end
            PlayerData.leaderstats.Credits += SETTINGS.STARTER_PACK.Credits
            PlayerData.Offers.StarterPackPurchased = true
        end,
    },

    -- ============================================================
    -- TIER 1 SOLDIERS — Robux purchases bypass nothing (always in stock)
    -- ============================================================

    GruntRobux = {
        Type = "DevProduct",
        Id = 3571890717,
        OnGrant = MakeSoldierGrant("Grunt"),
    },

    ShotgunnerRobux = {
        Type = "DevProduct",
        Id = 3571890784,
        OnGrant = MakeSoldierGrant("Shotgunner"),
    },

    HeavyRobux = {
        Type = "DevProduct",
        Id = 3571890840,
        OnGrant = MakeSoldierGrant("Heavy"),
    },

    SniperRobux = {
        Type = "DevProduct",
        Id = 3571890882,
        OnGrant = MakeSoldierGrant("Sniper"),
    },

    DualieRobux = {
        Type = "DevProduct",
        Id = 3571890933,
        OnGrant = MakeSoldierGrant("Dualie"),
    },

    SprayNPrayRobux = {
        Type = "DevProduct",
        Id = 3571890996,
        OnGrant = MakeSoldierGrant("Spray 'n Pray"),
    },

    -- ============================================================
    -- TIER 2 SOLDIERS — Robux bypasses stock wait
    -- ============================================================

    PirateRobux = {
        Type = "DevProduct",
        Id = 3571891042,
        OnGrant = MakeSoldierGrant("Pirate"),
    },

    BanditRobux = {
        Type = "DevProduct",
        Id = 3571891099,
        OnGrant = MakeSoldierGrant("Bandit"),
    },

    RaiderRobux = {
        Type = "DevProduct",
        Id = 3571891173,
        OnGrant = MakeSoldierGrant("Raider"),
    },

    -- ============================================================
    -- TIER 3 SOLDIERS — Robux skips multi-session stock hunt
    -- ============================================================

    VectorRobux = {
        Type = "DevProduct",
        Id = 3571891260,
        OnGrant = MakeSoldierGrant("Vector"),
    },

    OneShotRobux = {
        Type = "DevProduct",
        Id = 3571891347,
        OnGrant = MakeSoldierGrant("One Shot"),
    },

    AkimboRobux = {
        Type = "DevProduct",
        Id = 3571891397,
        OnGrant = MakeSoldierGrant("Akimbo"),
    },

    -- ============================================================
    -- PREMIUM SOLDIERS — Exclusive, percentage-based passive boosts
    -- Not in SHOP_ORDER; only purchasable via Robux
    -- ============================================================

    HyperSniperRobux = {
        Type = "DevProduct",
        Id = 3571891467,
        OnGrant = MakeSoldierGrant("Hyper Sniper"),
    },

    ShadowOpsRobux = {
        Type = "DevProduct",
        Id = 3571891518,
        OnGrant = MakeSoldierGrant("Shadow Ops"),
    },

    -- ============================================================
    -- GAMEPASSES
    -- ============================================================

    CommanderPass = {
        Type = "Gamepass",
        Id = 0, -- TODO: replace with real gamepass ID
        OnGrant = function(Player: Player, PlayerData: table)
            -- One-time unlock of slot 7 for commander pass owners
            PlayerData.Plot.Unlocks.Slot7 = true
        end,
    },
}
