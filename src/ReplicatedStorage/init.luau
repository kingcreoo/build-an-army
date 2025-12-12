-- // Settings, initialized by KingCreoo on 8-19-2025
-- // Holds all basic game data

local SETTINGS = {}

SETTINGS.DEFAULT_DATA = {
    ["leaderstats"] = {
        ["Credits"] = 100000000
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
    }
}

SETTINGS.SOLDIER_DATA = {
	["The Grunt"] = {
		["Price"] = 10,
		["RobuxPrice"] = 3,
		["Rarity"] = 1,
		["Image"] = "rbxassetid://73900105861068",
		["Color"] = Color3.fromRGB(72, 157, 236),
        ["ShopColor"] = Color3.fromRGB(152, 192, 229),
		["Weapon"] = "M4",
		["SellValue"] = 5,
		["Special"] = false,
        ["WeaponType"] = "Automatic",
        ["WeaponInfo"] = {
            ["FireRate"] = 4,
		    ["Damage"] = 1,
		    ["BulletSpeed"] = 40,
            ["SpreadIntensity"] = 1.5
        }
	},
	["The Shotgunner"] = {
		["Price"] = 25,
		["RobuxPrice"] = 5,
		["Rarity"] = 1,
		["Image"] = "rbxassetid://73900105861068",
		["Color"] = Color3.fromRGB(72, 157, 236),
        ["ShopColor"] = Color3.fromRGB(152, 192, 229),
		["Weapon"] = "Pump",
		["SellValue"] = 12,
		["Special"] = false,
        ["WeaponType"] = "Shotgun",
        ["WeaponInfo"] = {
            ["FireRate"] = 8,
		    ["Damage"] = 3,
		    ["BulletSpeed"] = 40,
            ["Pellets"] = 5,
            ["SpreadIntensity"] = 2.5
        }
	},
	["The Heavy"] = {
		["Price"] = 60,
		["RobuxPrice"] = 10,
		["Rarity"] = .9,
		["Image"] = "rbxassetid://73900105861068",
		["Color"] = Color3.fromRGB(72, 157, 236),
        ["ShopColor"] = Color3.fromRGB(152, 192, 229),
		["Weapon"] = "LMG",
		["SellValue"] = 30,
		["Special"] = false,
        ["WeaponType"] = "Burst",
        ["WeaponInfo"] = {
            ["FireRate"] = 3,
		    ["Damage"] = 1,
		    ["BulletSpeed"] = 30,
            ["Bullets"] = 3,
            ["DelayBetweenBullets"] = .2,
            ["SpreadIntensity"] = 1
        }
	},
    ["The Dual"] = {
		["Price"] = 60,
		["RobuxPrice"] = 10,
		["Rarity"] = .9,
		["Image"] = "rbxassetid://73900105861068",
		["Color"] = Color3.fromRGB(72, 157, 236),
        ["ShopColor"] = Color3.fromRGB(152, 192, 229),
		["Weapon"] = "DualM4",
		["SellValue"] = 30,
		["Special"] = false,
        ["WeaponType"] = "Dual",
        ["WeaponInfo"] = {
            ["FireRate"] = 2,
		    ["Damage"] = 1,
		    ["BulletSpeed"] = 30,
            ["DelayBetweenBullets"] = .2,
            ["SpreadIntensity"] = 1
        }
	}
}

SETTINGS.SHOP_ORDER = {"The Grunt", "The Shotgunner", "The Heavy", "The Dual"}

SETTINGS.RATING_ORDER = {"The Dual", "The Heavy", "The Shotgunner", "The Grunt"}

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

SETTINGS.TARGET_DATA = {
    ["Target1"] = {
        ["TotalHealth"] = 3,
        ["TotalRespawnTime"] = 2,
        ["Reward"] = 3,
        ["Color"] = Color3.fromRGB(255, 66, 66),
        ["Price"] = 0
    },
    ["Target2"] = {
        ["TotalHealth"] = 5,
        ["TotalRespawnTime"] = 1.8,
        ["Reward"] = 10,
        ["Color"] = Color3.fromRGB(255, 66, 66),
        ["Price"] = 200
    },
    ["Target3"] = {
        ["TotalHealth"] = 10,
        ["TotalRespawnTime"] = 1.7,
        ["Reward"] = 25,
        ["Color"] = Color3.fromRGB(255, 66, 66),
        ["Price"] = 500
    }
}

SETTINGS.TARGET_ORDER = {
    "Target1", "Target2", "Target3"
}

SETTINGS.SLOT_PRICES = {
    [4] = 20000,
    [5] = 100000,
    [6] = 1000000,
    [7] = "VIP"
}

SETTINGS.DISTANCES = {
    ["Worlds"] = {
        ["Default"] = 55,
    }
}

return SETTINGS