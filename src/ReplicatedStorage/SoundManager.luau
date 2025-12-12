-- // SoundManager, initialized by KingCreoo on 12-11-2025
-- // Centralized sound system for UI, combat, and purchase sounds

-- // Define
local SoundManager = {}

-- // Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local Players = game:GetService("Players")

-- // Modules
local SETTINGS = require(ReplicatedStorage:WaitForChild("Settings"))

-- // Variables
local LocalPlayer = Players.LocalPlayer
local SoundPools = {}

-- // Functions

-- Creates a pool of Sound instances for a specific sound type
local function CreateSoundPool(SoundId: string, PoolSize: number, Volume: number, Is3D: boolean)
	local Pool = {}
	
	for i = 1, PoolSize do
		local Sound = Instance.new("Sound")
		Sound.SoundId = SoundId
		Sound.Volume = Volume
		
		if Is3D then
			-- 3D positional sound (will be parented to parts in workspace)
			Sound.RollOffMaxDistance = 150
			Sound.RollOffMinDistance = 10
		else
			-- 2D UI sound (parented to SoundService, plays at full volume)
			Sound.Parent = SoundService
		end
		
		table.insert(Pool, Sound)
	end
	
	return Pool
end

-- Gets an available sound from the pool (one that's not currently playing)
local function GetAvailableSound(Pool: table)
	for _, Sound in pairs(Pool) do
		if not Sound.IsPlaying then
			return Sound
		end
	end
	
	-- If all sounds are playing, return the first one (will restart it)
	return Pool[1]
end

-- Initializes all sound pools on first use
local function InitializeSoundPools()
	if next(SoundPools) then return end -- Already initialized
	
	-- UI Sounds (2D, 3 instances for potential overlaps)
	SoundPools.Click = CreateSoundPool(SETTINGS.SOUNDS.UI.Click, 3, 0.3, false)
	
	-- Purchase Sounds (2D, 2 instances)
	SoundPools.Purchase = CreateSoundPool(SETTINGS.SOUNDS.Purchase.Buy, 2, 0.5, false)
	
	-- Error Sounds (2D, 2 instances)
	SoundPools.Error = CreateSoundPool(SETTINGS.SOUNDS.Error.Alert, 2, 0.4, false)
	
	-- Combat Sounds (3D, 10 instances for rapid fire)
	SoundPools.Hitmarker = CreateSoundPool(SETTINGS.SOUNDS.Combat.Hitmarker, 10, 0.25, true)
end

-- Plays a UI click sound
function SoundManager:PlayClick()
	InitializeSoundPools()
	
	local Sound = GetAvailableSound(SoundPools.Click)
	Sound:Play()
end

-- Plays a purchase sound
function SoundManager:PlayPurchase()
	InitializeSoundPools()
	
	local Sound = GetAvailableSound(SoundPools.Purchase)
	Sound:Play()
end

-- Plays an error sound
function SoundManager:PlayError()
	InitializeSoundPools()
	
	local Sound = GetAvailableSound(SoundPools.Error)
	Sound:Play()
end

-- Plays a hitmarker sound at a specific 3D position
function SoundManager:PlayHitmarker(Position: Vector3)
	InitializeSoundPools()
	
	local Sound = GetAvailableSound(SoundPools.Hitmarker)
	
	-- Create temporary part for 3D positioning
	local SoundPart = Instance.new("Part")
	SoundPart.Anchored = true
	SoundPart.CanCollide = false
	SoundPart.Transparency = 1
	SoundPart.Size = Vector3.new(0.1, 0.1, 0.1)
	SoundPart.Position = Position
	SoundPart.Parent = workspace
	
	-- Reparent sound to part temporarily
	Sound.Parent = SoundPart
	Sound:Play()
	
	-- Cleanup after sound finishes
	task.delay(Sound.TimeLength + 0.1, function()
		Sound.Parent = SoundService
		SoundPart:Destroy()
	end)
end

-- // Return
return SoundManager
