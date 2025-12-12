-- // Settings, initialized by KingCreoo on 9-7-2025
-- // Manages UI functions for the client's settings frame :)

-- // Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- // Modules
local SETTINGS = require(ReplicatedStorage:WaitForChild("Settings"))
local SOUND_MANAGER = nil

-- // Variables
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
SOUND_MANAGER = require(ReplicatedStorage:WaitForChild("Settings"):WaitForChild("SoundManager"))

local LoadPlayerEvent: RemoteEvent = Remotes:WaitForChild("LoadPlayer")
local UpdateSettingFunction: RemoteFunction = Remotes:WaitForChild("UpdateSetting")
local UpdateSettingBindable: BindableEvent = Remotes:WaitForChild("UpdateSettingBindable")
local ButtonExpandBindable: BindableEvent = Remotes:WaitForChild("ButtonExpand")
local ButtonDeflateBindable: BindableEvent = Remotes:WaitForChild("ButtonDeflate")
local CloseFrameBindable: BindableEvent = Remotes:WaitForChild("CloseFrame")
local NotifyBindable: BindableEvent = Remotes:WaitForChild("NotifyBindable")

local LocalPlayer = Players.LocalPlayer
local UI = LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("Client"):WaitForChild("UI")

local LocalGui = LocalPlayer:WaitForChild("PlayerGui")
local FramesGui = LocalGui:WaitForChild("Frames")

local SettingsFrame: Frame = FramesGui:WaitForChild("SettingsFrame")

local MainFrame: Frame = SettingsFrame:WaitForChild("MainFrame")
local CloseButton: TextButton = SettingsFrame:WaitForChild("Close")

local AutoEquipFolder = SettingsFrame:WaitForChild("AutoEquip")
local AEButton = AutoEquipFolder:WaitForChild("Button")
local AELabel = AutoEquipFolder:WaitForChild("TextLabel")

local PotatoModeFolder = SettingsFrame:WaitForChild("PotatoMode")
local PMButton = PotatoModeFolder:WaitForChild("Button")
local PMLabel = PotatoModeFolder:WaitForChild("TextLabel")

local Buttons = {CloseButton, AEButton, PMButton}
local Items = {
    ["AutoEquip"] = {["Folder"] = AutoEquipFolder, ["Button"] = AEButton, ["Label"] = AELabel},
    ["PotatoMode"] = {["Folder"] = PotatoModeFolder, ["Button"] = PMButton, ["Label"] = PMLabel}
}

local FrameActive

-- // Functions

local function UpdateItem(Item: string, On: boolean)
    if On then
        local Color1 = Items[Item].Button:GetAttribute("OnColor1")
        local Color2 = Items[Item].Button:GetAttribute("OnColor2")

        Items[Item].Button.BackgroundColor3 = Color1
        Items[Item].Button.UIStroke.Color = Color2
        Items[Item].Button.TextLabel.UIStroke.Color = Color2
        Items[Item].Button.TextLabel.Text = "On"
    else
        local Color1 = Items[Item].Button:GetAttribute("OffColor1")
        local Color2 = Items[Item].Button:GetAttribute("OffColor2")

        Items[Item].Button.BackgroundColor3 = Color1
        Items[Item].Button.UIStroke.Color = Color2
        Items[Item].Button.TextLabel.UIStroke.Color = Color2
        Items[Item].Button.TextLabel.Text = "Off"
    end
end

local function LoadSettings(PlayerData)
    for Item, On in pairs(PlayerData["Settings"]) do
        UpdateItem(Item, On)
        UpdateSettingBindable:Fire(Item, On)
    end
end

local Bounces = 0
local function ChangeSetting(Item: string)
    if Bounces >= 3 then
        NotifyBindable:Fire("Slow down!", .8, Color3.fromRGB(255, 0, 0))
        return
    end

    Bounces += 1

    local Success, On, ErrorMessage = UpdateSettingFunction:InvokeServer(Item)

    if not Success then
        NotifyBindable:Fire(ErrorMessage, .8, Color3.fromRGB(255, 0, 0))

        task.delay(1, function()
            Bounces -= 1
        end)

        return
    end

    UpdateItem(Item, On)
    UpdateSettingBindable:Fire(Item, On)

    task.delay(1, function()
        Bounces -= 1
    end)
end

-- // Events

for _, Button in pairs(Buttons) do
    Button.MouseEnter:Connect(function()
        if FrameActive == false then return end
        ButtonExpandBindable:Fire(Button, 1.1)
    end)
    Button.MouseLeave:Connect(function()
        if FrameActive == false then return end
        ButtonDeflateBindable:Fire(Button)
    end)
end

SettingsFrame:GetPropertyChangedSignal("Visible"):Connect(function()
    FrameActive = SettingsFrame.Visible
end)

CloseButton.MouseButton1Click:Connect(function()
	if FrameActive == false then return end
	SOUND_MANAGER:PlayClick()
	CloseFrameBindable:Fire(SettingsFrame)
end)

AEButton.MouseButton1Click:Connect(function()
	SOUND_MANAGER:PlayClick()
	ChangeSetting("AutoEquip")
end)

PMButton.MouseButton1Click:Connect(function()
	SOUND_MANAGER:PlayClick()
	ChangeSetting("PotatoMode")
end)

LoadPlayerEvent.OnClientEvent:Connect(LoadSettings)

UpdateSettingBindable.Event:Connect(UpdateItem)