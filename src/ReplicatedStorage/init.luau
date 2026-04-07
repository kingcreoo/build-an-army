-- // Settings, initialized by KingCreoo on 8-19-2025
-- // Holds all basic game data

local SETTINGS = {}

SETTINGS.DEFAULT_DATA = {
    ["leaderstats"] = {
        ["Credits"] = 100
    },
    ["Plot"] = {
        ["Unlocks"] = {
            ["Slot1"] = true,
            ["Slot2"] = true,
            ["Slot3"] = true,
            ["Slot4"] = false,
            ["Slot5"] = false,
            ["Slot6"] = false,
            ["Slot7"] = false
        }
    },
    ["Inventory"] = {
        ["ActiveSoldiers"] = {},
        ["SoldierInventory"] = {},
        ["ActiveTarget"] = "Target1",
        ["TargetInventory"] = {["Target1"] = true},
    },
    ["Settings"] = {
        ["AutoEquip"] = false,
        ["PotatoMode"] = false
    },
    ["Transactions"] = {
        ["GrantedPurchases"] = {},
        ["AppliedPasses"] = {}
    }
}

-- Shared placeholder art references; real assets get swapped per-soldier later
local PLACEHOLDER_IMAGE = "rbxassetid://73900105861068"
local PLACEHOLDER_MODEL = "Grunt" -- every soldier visually spawns as Grunt until real models exist

-- Tier color palettes (T1 blue, T2 bandit-red, T3 techno-gold, Premium = unique)
local T1_COLOR = Color3.fromRGB(72, 157, 236)
local T1_SHOP_COLOR = Color3.fromRGB(64, 204, 255)
local T1_GRADIENT_1 = Color3.fromHex("#b9e7ff")
local T1_GRADIENT_2 = Color3.fromHex("#69cdff")

local T2_COLOR = Color3.fromRGB(200, 40, 40)
local T2_SHOP_COLOR = Color3.fromRGB(220, 50, 50)
local T2_GRADIENT_1 = Color3.fromHex("#ffb9b9")
local T2_GRADIENT_2 = Color3.fromHex("#ff6969")

local T3_COLOR = Color3.fromRGB(236, 180, 72)
local T3_SHOP_COLOR = Color3.fromRGB(255, 204, 64)
local T3_GRADIENT_1 = Color3.fromHex("#fff3b9")
local T3_GRADIENT_2 = Color3.fromHex("#ffcd69")

SETTINGS.SOLDIER_DATA = {
    -- ============================================================
    -- TIER 1 — Starter soldiers, blue aesthetic, high stock
    -- ============================================================

    ["Grunt"] = {
        ["Tier"] = 1,
        ["Model"] = "Grunt",
        ["Price"] = 100,
        ["RobuxPrice"] = 5,
        ["RobuxProductId"] = 3571890717,
        ["Rarity"] = 1.0,
        ["Image"] = PLACEHOLDER_IMAGE,
        ["Color"] = T1_COLOR,
        ["ShopColor"] = T1_SHOP_COLOR,
        ["ShopGradient1"] = T1_GRADIENT_1,
        ["ShopGradient2"] = T1_GRADIENT_2,
        ["Weapon"] = "M4",
        ["SellValue"] = 50,
        ["Special"] = false,
        ["Description"] = "Given in tutorial but can purchase more",
        ["WeaponType"] = "Automatic",
        ["WeaponInfo"] = {
            ["FireRate"] = 0.9,
            ["Damage"] = 10,
            ["BulletSpeed"] = 40,
            ["SpreadIntensity"] = 1.5
        }
    },

    ["Shotgunner"] = {
        ["Tier"] = 1,
        ["Model"] = "Shotgunner",
        ["Price"] = 175,
        ["RobuxPrice"] = 8,
        ["RobuxProductId"] = 3571890784,
        ["Rarity"] = 1.0,
        ["Image"] = PLACEHOLDER_IMAGE,
        ["Color"] = T1_COLOR,
        ["ShopColor"] = T1_SHOP_COLOR,
        ["ShopGradient1"] = T1_GRADIENT_1,
        ["ShopGradient2"] = T1_GRADIENT_2,
        ["Weapon"] = "Pump",
        ["SellValue"] = 88,
        ["Special"] = false,
        ["Description"] = "Given in tutorial but can purchase more",
        ["WeaponType"] = "Shotgun",
        ["WeaponInfo"] = {
            ["FireRate"] = 1.35,
            ["Damage"] = 19,
            ["BulletSpeed"] = 50,
            ["Pellets"] = 5, -- Visual only; server treats shotgun as a slug
            ["SpreadIntensity"] = 2.5
        }
    },

    ["Heavy"] = {
        ["Tier"] = 1,
        ["Model"] = "Heavy",
        ["Price"] = 350,
        ["RobuxPrice"] = 10,
        ["RobuxProductId"] = 3571890840,
        ["Rarity"] = 1.0,
        ["Image"] = PLACEHOLDER_IMAGE,
        ["Color"] = T1_COLOR,
        ["ShopColor"] = T1_SHOP_COLOR,
        ["ShopGradient1"] = T1_GRADIENT_1,
        ["ShopGradient2"] = T1_GRADIENT_2,
        ["Weapon"] = "LMG",
        ["SellValue"] = 175,
        ["Special"] = false,
        ["Description"] = "First purchase",
        ["WeaponType"] = "Burst",
        ["WeaponInfo"] = {
            ["FireRate"] = 1.2,
            ["Damage"] = 4,
            ["BulletSpeed"] = 45,
            ["Bullets"] = 3,
            ["DelayBetweenBullets"] = 0.2,
            ["SpreadIntensity"] = 1
        }
    },

    ["Sniper"] = {
        ["Tier"] = 1,
        ["Model"] = PLACEHOLDER_MODEL,
        ["Price"] = 1000,
        ["RobuxPrice"] = 12,
        ["RobuxProductId"] = 3571890882,
        ["Rarity"] = 0.9,
        ["Image"] = PLACEHOLDER_IMAGE,
        ["Color"] = T1_COLOR,
        ["ShopColor"] = T1_SHOP_COLOR,
        ["ShopGradient1"] = T1_GRADIENT_1,
        ["ShopGradient2"] = T1_GRADIENT_2,
        ["Weapon"] = "M4", -- TODO: replace with real sniper model
        ["SellValue"] = 500,
        ["Special"] = false,
        ["Description"] = "High damage, slow cycle",
        ["WeaponType"] = "Automatic",
        ["WeaponInfo"] = {
            ["FireRate"] = 3.0,
            ["Damage"] = 25,
            ["BulletSpeed"] = 200,
            ["SpreadIntensity"] = 0.5
        }
    },

    ["Dualie"] = {
        ["Tier"] = 1,
        ["Model"] = PLACEHOLDER_MODEL,
        ["Price"] = 1100,
        ["RobuxPrice"] = 13,
        ["RobuxProductId"] = 3571890933,
        ["Rarity"] = 0.85,
        ["Image"] = PLACEHOLDER_IMAGE,
        ["Color"] = T1_COLOR,
        ["ShopColor"] = T1_SHOP_COLOR,
        ["ShopGradient1"] = T1_GRADIENT_1,
        ["ShopGradient2"] = T1_GRADIENT_2,
        ["Weapon"] = "M4", -- TODO: replace with DualM4 when Dualie model exists
        ["SellValue"] = 550,
        ["Special"] = false,
        ["Description"] = "Fast dual fire",
        ["WeaponType"] = "Dual",
        ["WeaponInfo"] = {
            ["FireRate"] = 0.75,
            ["Damage"] = 6,
            ["BulletSpeed"] = 65,
            ["DelayBetweenBullets"] = 0.15,
            ["SpreadIntensity"] = 1
        }
    },

    ["Spray 'n Pray"] = {
        ["Tier"] = 1,
        ["Model"] = PLACEHOLDER_MODEL,
        ["Price"] = 1200,
        ["RobuxPrice"] = 15,
        ["RobuxProductId"] = 3571890996,
        ["Rarity"] = 0.8,
        ["Image"] = PLACEHOLDER_IMAGE,
        ["Color"] = T1_COLOR,
        ["ShopColor"] = T1_SHOP_COLOR,
        ["ShopGradient1"] = T1_GRADIENT_1,
        ["ShopGradient2"] = T1_GRADIENT_2,
        ["Weapon"] = "M4", -- TODO: replace with real spray model
        ["SellValue"] = 600,
        ["Special"] = false,
        ["Description"] = "3-round burst",
        ["WeaponType"] = "Burst",
        ["WeaponInfo"] = {
            ["FireRate"] = 1.05,
            ["Damage"] = 5,
            ["BulletSpeed"] = 55,
            ["Bullets"] = 3,
            ["DelayBetweenBullets"] = 0.15,
            ["SpreadIntensity"] = 1.5
        }
    },

    -- ============================================================
    -- TIER 2 — Bandit theme, deep red, stock-gated
    -- ============================================================

    ["Pirate"] = {
        ["Tier"] = 2,
        ["Model"] = PLACEHOLDER_MODEL,
        ["Price"] = 3500,
        ["RobuxPrice"] = 55,
        ["RobuxProductId"] = 3571891042,
        ["Rarity"] = 0.5,
        ["Image"] = PLACEHOLDER_IMAGE,
        ["Color"] = T2_COLOR,
        ["ShopColor"] = T2_SHOP_COLOR,
        ["ShopGradient1"] = T2_GRADIENT_1,
        ["ShopGradient2"] = T2_GRADIENT_2,
        ["Weapon"] = "M4", -- TODO: replace with revolver model
        ["SellValue"] = 1750,
        ["Special"] = false,
        ["Description"] = "Revolver. Stock-gated.",
        ["WeaponType"] = "Automatic",
        ["WeaponInfo"] = {
            ["FireRate"] = 1.1,
            ["Damage"] = 18,
            ["BulletSpeed"] = 140,
            ["SpreadIntensity"] = 0.8
        }
    },

    ["Bandit"] = {
        ["Tier"] = 2,
        ["Model"] = PLACEHOLDER_MODEL,
        ["Price"] = 7000,
        ["RobuxPrice"] = 75,
        ["RobuxProductId"] = 3571891099,
        ["Rarity"] = 0.35,
        ["Image"] = PLACEHOLDER_IMAGE,
        ["Color"] = T2_COLOR,
        ["ShopColor"] = T2_SHOP_COLOR,
        ["ShopGradient1"] = T2_GRADIENT_1,
        ["ShopGradient2"] = T2_GRADIENT_2,
        ["Weapon"] = "M4", -- TODO: replace with AK model
        ["SellValue"] = 3500,
        ["Special"] = false,
        ["Description"] = "AK. Fast sustained DPS.",
        ["WeaponType"] = "Automatic",
        ["WeaponInfo"] = {
            ["FireRate"] = 0.8,
            ["Damage"] = 14,
            ["BulletSpeed"] = 120,
            ["SpreadIntensity"] = 1.2
        }
    },

    ["Raider"] = {
        ["Tier"] = 2,
        ["Model"] = PLACEHOLDER_MODEL,
        ["Price"] = 10000,
        ["RobuxPrice"] = 105,
        ["RobuxProductId"] = 3571891173,
        ["Rarity"] = 0.25,
        ["Image"] = PLACEHOLDER_IMAGE,
        ["Color"] = T2_COLOR,
        ["ShopColor"] = T2_SHOP_COLOR,
        ["ShopGradient1"] = T2_GRADIENT_1,
        ["ShopGradient2"] = T2_GRADIENT_2,
        ["Weapon"] = "M4", -- TODO: replace with Pump when Raider model exists
        ["SellValue"] = 5000,
        ["Special"] = false,
        ["Description"] = "Shotgun slug. Rare stock.",
        ["WeaponType"] = "Shotgun",
        ["WeaponInfo"] = {
            ["FireRate"] = 1.5,
            ["Damage"] = 20,
            ["BulletSpeed"] = 110,
            ["Pellets"] = 3, -- Visual only; server treats shotgun as a slug
            ["SpreadIntensity"] = 1.5
        }
    },

    -- ============================================================
    -- TIER 3 — Techno / art deco theme, gold, ultra-rare
    -- ============================================================

    ["Vector"] = {
        ["Tier"] = 3,
        ["Model"] = PLACEHOLDER_MODEL,
        ["Price"] = 40000,
        ["RobuxPrice"] = 199,
        ["RobuxProductId"] = 3571891260,
        ["Rarity"] = 0.15,
        ["Image"] = PLACEHOLDER_IMAGE,
        ["Color"] = T3_COLOR,
        ["ShopColor"] = T3_SHOP_COLOR,
        ["ShopGradient1"] = T3_GRADIENT_1,
        ["ShopGradient2"] = T3_GRADIENT_2,
        ["Weapon"] = "M4", -- TODO: replace with Vector SMG
        ["SellValue"] = 20000,
        ["Special"] = false,
        ["Description"] = "SMG burst. Very rare.",
        ["WeaponType"] = "Burst",
        ["WeaponInfo"] = {
            ["FireRate"] = 0.9,
            ["Damage"] = 7,
            ["BulletSpeed"] = 150,
            ["Bullets"] = 3,
            ["DelayBetweenBullets"] = 0.1,
            ["SpreadIntensity"] = 1
        }
    },

    ["One Shot"] = {
        ["Tier"] = 3,
        ["Model"] = PLACEHOLDER_MODEL,
        ["Price"] = 80000,
        ["RobuxPrice"] = 249,
        ["RobuxProductId"] = 3571891347,
        ["Rarity"] = 0.10,
        ["Image"] = PLACEHOLDER_IMAGE,
        ["Color"] = T3_COLOR,
        ["ShopColor"] = T3_SHOP_COLOR,
        ["ShopGradient1"] = T3_GRADIENT_1,
        ["ShopGradient2"] = T3_GRADIENT_2,
        ["Weapon"] = "M4", -- TODO: replace with high-tech sniper
        ["SellValue"] = 40000,
        ["Special"] = false,
        ["Description"] = "Massive hit. Ultra rare.",
        ["WeaponType"] = "Automatic",
        ["WeaponInfo"] = {
            ["FireRate"] = 4.0,
            ["Damage"] = 60,
            ["BulletSpeed"] = 250,
            ["SpreadIntensity"] = 0.2
        }
    },

    ["Akimbo"] = {
        ["Tier"] = 3,
        ["Model"] = PLACEHOLDER_MODEL,
        ["Price"] = 120000,
        ["RobuxPrice"] = 299,
        ["RobuxProductId"] = 3571891397,
        ["Rarity"] = 0.08,
        ["Image"] = PLACEHOLDER_IMAGE,
        ["Color"] = T3_COLOR,
        ["ShopColor"] = T3_SHOP_COLOR,
        ["ShopGradient1"] = T3_GRADIENT_1,
        ["ShopGradient2"] = T3_GRADIENT_2,
        ["Weapon"] = "M4", -- TODO: replace with dual MAC model when Akimbo model exists
        ["SellValue"] = 60000,
        ["Special"] = false,
        ["Description"] = "Dual MACs. Highest DPS.",
        ["WeaponType"] = "Dual",
        ["WeaponInfo"] = {
            ["FireRate"] = 0.7,
            ["Damage"] = 9,
            ["BulletSpeed"] = 140,
            ["DelayBetweenBullets"] = 0.1,
            ["SpreadIntensity"] = 1.2
        }
    },

    -- ============================================================
    -- PREMIUM — Robux-only exclusives with global percentage boosts
    -- Not listed in SHOP_ORDER; purchased via RobuxStore only.
    -- Price=0 + Special=true prevents accidental cash purchase.
    -- ============================================================

    ["Hyper Sniper"] = {
        ["Tier"] = 0,
        ["Model"] = PLACEHOLDER_MODEL,
        ["Price"] = 0,
        ["RobuxPrice"] = 149,
        ["RobuxProductId"] = 3571891467,
        ["Rarity"] = 1.0,
        ["Image"] = PLACEHOLDER_IMAGE,
        ["Color"] = Color3.fromRGB(245, 245, 220),
        ["ShopColor"] = Color3.fromRGB(255, 250, 205),
        ["ShopGradient1"] = Color3.fromHex("#fffacd"),
        ["ShopGradient2"] = Color3.fromHex("#f5dc80"),
        ["Weapon"] = "M4", -- TODO: replace with techno-angelic sniper model
        ["SellValue"] = 0,
        ["Special"] = true,
        ["Description"] = "PREMIUM. Techno/angelic armor. 1.2x cash boost.",
        ["WeaponType"] = "Automatic",
        ["WeaponInfo"] = {
            ["FireRate"] = 1.0,
            ["Damage"] = 20,
            ["BulletSpeed"] = 150,
            ["SpreadIntensity"] = 0.3
        }
    },

    ["Shadow Ops"] = {
        ["Tier"] = 0,
        ["Model"] = PLACEHOLDER_MODEL,
        ["Price"] = 0,
        ["RobuxPrice"] = 109,
        ["RobuxProductId"] = 3571891518,
        ["Rarity"] = 1.0,
        ["Image"] = PLACEHOLDER_IMAGE,
        ["Color"] = Color3.fromRGB(40, 40, 40),
        ["ShopColor"] = Color3.fromRGB(60, 20, 20),
        ["ShopGradient1"] = Color3.fromHex("#8b0000"),
        ["ShopGradient2"] = Color3.fromHex("#1a0000"),
        ["Weapon"] = "M4", -- TODO: replace with dual SMG model when Shadow Ops model exists
        ["SellValue"] = 0,
        ["Special"] = true,
        ["Description"] = "PREMIUM. Black/red armor. 1.2x damage boost.",
        ["WeaponType"] = "Dual",
        ["WeaponInfo"] = {
            ["FireRate"] = 0.8,
            ["Damage"] = 8,
            ["BulletSpeed"] = 160,
            ["DelayBetweenBullets"] = 0.1,
            ["SpreadIntensity"] = 1
        }
    }
}

-- Standard shop order (cash-purchasable soldiers, low tier to high)
SETTINGS.SHOP_ORDER = {
    "Grunt", "Shotgunner", "Heavy", "Sniper", "Dualie", "Spray 'n Pray",
    "Pirate", "Bandit", "Raider",
    "Vector", "One Shot", "Akimbo"
}

-- Soldier strength order (best → worst). Used by AutoEquip (best first) and sell list display.
-- Ordered by RawDPS from the economy spreadsheet so AutoEquip always picks the highest-DPS
-- owned soldiers regardless of how much they cost.
SETTINGS.RATING_ORDER = {
    "Akimbo",        -- 25.71 DPS
    "Vector",        -- 23.33 DPS
    "Hyper Sniper",  -- 20.00 DPS (premium)
    "Shadow Ops",    -- 20.00 DPS (premium)
    "Bandit",        -- 17.50 DPS
    "Pirate",        -- 16.36 DPS
    "One Shot",      -- 15.00 DPS
    "Raider",        -- 13.33 DPS
    "Dualie",        -- 10.00 DPS
    "Spray 'n Pray", -- 8.57 DPS
    "Sniper",        -- 8.33 DPS
    "Shotgunner",    -- 8.33 DPS
    "Heavy",         -- 7.50 DPS
    "Grunt"          -- 6.67 DPS
}

-- Premium soldiers (sold via Robux store, not the standard shop)
SETTINGS.PREMIUM_ORDER = {
    "Hyper Sniper", "Shadow Ops"
}

SETTINGS.WEAPON_DATA = {
    ["M4"] = {
        ["C0"] = CFrame.new(-0.697, -2.093, 0.167) * CFrame.Angles(math.rad(-90), 0, 0),
        ["C1"] = CFrame.new(0, -0.062, -0.489)
    },
    ["DualM4"] = {
        ["C0"] = CFrame.new(-0.697, -2.093, 0.167) * CFrame.Angles(math.rad(-90), 0, 0),
        ["C1"] = CFrame.new(0, -0.062, -0.489)
    },
    ["LMG"] = {
        ["C0"] = CFrame.new(-6.139, -1.442, -5.008) * CFrame.Angles(0, math.rad(-90), 0),
        ["C1"] = CFrame.new(0, 0, 0)
    },
    ["Pump"] = {
        ["C0"] = CFrame.new(1.163, -2.376, -4.896) * CFrame.Angles(0, math.rad(-90), 0),
        ["C1"] = CFrame.new(0, 0, 0)
    }
}

-- Target Model field points to the Instance under ReplicatedStorage.Types.Targets to clone.
-- Targets 1-3 use their own existing models; new tiers 4-7 alias Target1 until real assets land.
SETTINGS.TARGET_DATA = {
    ["Target1"] = {
        ["DisplayName"] = "Practice Target 1",
        ["Model"] = "Target1",
        ["TotalHealth"] = 50,
        ["TotalRespawnTime"] = 4.0,
        ["Reward"] = 15,
        ["Color"] = Color3.fromRGB(255, 66, 66),
        ["Price"] = 0
    },
    ["Target2"] = {
        ["DisplayName"] = "Practice Target 2",
        ["Model"] = "Target2",
        ["TotalHealth"] = 80,
        ["TotalRespawnTime"] = 3.8,
        ["Reward"] = 28,
        ["Color"] = Color3.fromRGB(255, 66, 66),
        ["Price"] = 800
    },
    ["Target3"] = {
        ["DisplayName"] = "Practice Target 3",
        ["Model"] = "Target3",
        ["TotalHealth"] = 130,
        ["TotalRespawnTime"] = 3.5,
        ["Reward"] = 50,
        ["Color"] = Color3.fromRGB(255, 66, 66),
        ["Price"] = 1600
    },
    ["Target4"] = {
        ["DisplayName"] = "Light Armor Dummy",
        ["Model"] = "Target1", -- TODO: replace with real Light Armor Dummy model
        ["TotalHealth"] = 250,
        ["TotalRespawnTime"] = 3.0,
        ["Reward"] = 110,
        ["Color"] = Color3.fromRGB(180, 180, 200),
        ["Price"] = 5000
    },
    ["Target5"] = {
        ["DisplayName"] = "Heavy Armor Dummy",
        ["Model"] = "Target1", -- TODO: replace with real Heavy Armor Dummy model
        ["TotalHealth"] = 500,
        ["TotalRespawnTime"] = 2.5,
        ["Reward"] = 260,
        ["Color"] = Color3.fromRGB(120, 120, 140),
        ["Price"] = 15000
    },
    ["Target6"] = {
        ["DisplayName"] = "Diamond Core",
        ["Model"] = "Target1", -- TODO: replace with real Diamond Core model
        ["TotalHealth"] = 1000,
        ["TotalRespawnTime"] = 2.0,
        ["Reward"] = 650,
        ["Color"] = Color3.fromRGB(150, 230, 255),
        ["Price"] = 50000
    },
    ["Target7"] = {
        ["DisplayName"] = "Emerald Core",
        ["Model"] = "Target1", -- TODO: replace with real Emerald Core model
        ["TotalHealth"] = 1800,
        ["TotalRespawnTime"] = 1.5,
        ["Reward"] = 1500,
        ["Color"] = Color3.fromRGB(80, 230, 120),
        ["Price"] = 150000
    }
}

SETTINGS.TARGET_ORDER = {
    "Target1", "Target2", "Target3", "Target4", "Target5", "Target6", "Target7"
}

SETTINGS.SLOT_PRICES = {
    [4] = 2500,
    [5] = 10000,
    [6] = 100000,
    [7] = "Commander" -- Slot 7 unlocked by Commander Pass
}

SETTINGS.DISTANCES = {
    ["Worlds"] = {
        ["Default"] = 55,
    }
}

-- Idle reward configuration (percentage of live rate earned offline, capped)
SETTINGS.IDLE_CONFIG = {
    ["FreeRate"] = 0.15,        -- 15% of live rate for free players
    ["CommanderRate"] = 0.30,   -- 30% of live rate for Commander Pass owners
    ["FreeCap"] = 43200,        -- 12 hours in seconds
    ["CommanderCap"] = 43200,   -- 12 hours in seconds
    ["MinTimeAway"] = 60        -- Don't bother calculating for sessions under 1 minute
}

-- Stock rotation configuration
SETTINGS.STOCK_CONFIG = {
    ["RotationSeconds"] = 720  -- 12 minutes between shop refreshes
}

-- Cash pack Robux products (credit amounts granted per pack)
SETTINGS.CASH_PACKS = {
    ["Small"] = {["Credits"] = 1500, ["RobuxPrice"] = 29, ["ProductId"] = 3571886775},
    ["Medium"] = {["Credits"] = 5000, ["RobuxPrice"] = 59, ["ProductId"] = 3571886874},
    ["Large"] = {["Credits"] = 15000, ["RobuxPrice"] = 109, ["ProductId"] = 3571886955}
}

-- Starter Pack bundle contents (Robux product)
SETTINGS.STARTER_PACK = {
    ["RobuxPrice"] = 50,
    ["Soldiers"] = {"Sniper", "Spray 'n Pray"},
    ["Credits"] = 500
}

-- Premium soldier passive boosts — applied at runtime when the player owns the soldier
SETTINGS.PREMIUM_BOOSTS = {
    ["Hyper Sniper"] = {["CashMultiplier"] = 1.2},
    ["Shadow Ops"] = {["DamageMultiplier"] = 1.2}
}

SETTINGS.SOUNDS = {
    UI = {
        Click = "rbxassetid://6324790483"
    },
    Purchase = {
        Buy = "rbxassetid://14621507602"
    },
    Error = {
        Alert = "rbxassetid://3779045779"
    },
    Combat = {
        Hitmarker = "rbxassetid://1129547534"
    }
}

return SETTINGS
