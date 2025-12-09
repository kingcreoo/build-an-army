-- // SoldierInventory, initialized by KingCreoo on 9-7-2025
-- // Manages UI functions for the client's soldier inventory :)

-- // Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

-- // Modules
local SETTINGS = require(ReplicatedStorage:WaitForChild("Settings"))

-- // Variables
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local GetStockFunction: RemoteFunction = Remotes:WaitForChild("GetStock")
local RestockEvent: RemoteEvent = Remotes:WaitForChild("Restock")
local PurchaseSoldierFunction: RemoteFunction = Remotes:WaitForChild("PurchaseSoldier")
local UpdateInventoryBindable: BindableEvent = Remotes:WaitForChild("UpdateInventory")

local CurrentStock
local TimeOfStock

local UtilityInfo = TweenInfo.new(.065, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
local LogInfo = TweenInfo.new(.1, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
local LogExitInfo = TweenInfo.new(.7, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)

local LocalPlayer = Players.LocalPlayer
local UI = LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("Client"):WaitForChild("UI")

local LocalGui = LocalPlayer:WaitForChild("PlayerGui")
local FramesGui = LocalGui:WaitForChild("Frames")

local SoldierShopFrame: Frame = FramesGui:WaitForChild("SoldierShop")
local CloseButton: TextButton = SoldierShopFrame:WaitForChild("Close")

local StandardFrame: Frame = SoldierShopFrame:WaitForChild("Standard")

local Status: Frame = StandardFrame:WaitForChild("Status")
local Timer: TextLabel = Status:WaitForChild("Timer")
local RefreshButton: TextButton = Status:WaitForChild("Refresh")
local TemplateFrame: Frame = StandardFrame:WaitForChild("ScrollingFrame"):WaitForChild("Template")

local Buttons = {CloseButton, RefreshButton}

local ButtonExpandBindable: BindableEvent = Remotes:WaitForChild("ButtonExpand")
local ButtonDeflateBindable: BindableEvent = Remotes:WaitForChild("ButtonDeflate")
local CloseFrameBindable: BindableEvent = Remotes:WaitForChild("CloseFrame")
local NotifyBindable: BindableEvent = Remotes:WaitForChild("NotifyBindable")

local FrameActive = false

-- // Functions

local function GetNextLogName(logParent: Frame)
    local LowestNumber = 99  -- Start with the highest number we want

    -- Find the current lowest number in existing log names
    for _, child in ipairs(logParent:GetChildren()) do
        if child:IsA("Frame") and child.Name ~= "Template" then
            local numberPart = string.match(child.Name, "^(%d+)")
            if numberPart then
                local number = tonumber(numberPart)
                if number and number < LowestNumber then
                    LowestNumber = number
                end
            end
        end
    end

    -- Return the next number (one less than the current lowest)
    return tostring(LowestNumber - 1) .. "Log"
end

local CDB = false
local function PressCreditsButton(SoldierFrame: Frame, Type: string)
    -- 1) Check debounce
    if CDB then
        NotifyBindable:Fire("Slow down!", .8, Color3.fromRGB(255, 0, 0))
        return
    end
    CDB = true

    -- 2) Check if in stock (considering recent purchases)
    if CurrentStock[Type] <= 0 then
        NotifyBindable:Fire("Not in stock!", .8, Color3.fromRGB(255, 0, 0))
        return
    end

    -- 3) Check if has cash
    if LocalPlayer:WaitForChild("leaderstats"):WaitForChild("Credits").Value < SETTINGS.SOLDIER_DATA[Type]["Price"] then 
        NotifyBindable:Fire("Not enough credits!", .8, Color3.fromRGB(255, 0, 0))
        return
    end

    -- 4) Invoke server, and await response
    local Response, PlayerData = PurchaseSoldierFunction:InvokeServer(Type)

    -- 5) Act on various response types
    if Response == "Purchased" then
        -- 1) Update stock
        CurrentStock[Type] -= 1
        if CurrentStock[Type] <= 0 then
            local Stock: TextLabel = SoldierFrame:WaitForChild("MainFrame"):WaitForChild("Stock")
            local CreditsButton: TextButton = SoldierFrame:WaitForChild("UtilityFrame"):WaitForChild("Credits")

            Stock.Text = "0x Stock"
            Stock.TextColor3 = Color3.fromRGB(255, 0, 0)

            CreditsButton.TextLabel.Text = "NO STOCK"
            CreditsButton.TextLabel.TextColor3 = Color3.fromRGB(255, 0, 0)
            CreditsButton.TextLabel.UIStroke.Color = Color3.fromRGB(0, 0, 0)

            CreditsButton.BackgroundColor3 = Color3.fromRGB(98, 98, 98)
            CreditsButton.UIStroke.Color = Color3.fromRGB(61, 61, 61)
        else
            local Stock: TextLabel = SoldierFrame:WaitForChild("MainFrame"):WaitForChild("Stock")
            Stock.Text = CurrentStock[Type] .. "x Stock"
        end

        -- 2) Update inventory
        UpdateInventoryBindable:Fire(PlayerData)

        -- 3) Animate
        local Log = SoldierFrame.Parent.Parent.Parent:WaitForChild("Log")
        local LogFrame: Frame = Log:WaitForChild("Template"):Clone()

        LogFrame.ViewTile.Image.Image = SETTINGS.SOLDIER_DATA[Type]["Image"]
        LogFrame.Parent = Log
        LogFrame.Size = UDim2.fromScale(0,0)
        LogFrame.Name = GetNextLogName(Log)
        LogFrame.Visible = true

        local LogFrameTween = TweenService:Create(LogFrame, LogInfo, {Size = LogFrame:GetAttribute("StandardSize")})
        LogFrameTween:Play()

        LogFrameTween.Completed:Connect(function()
            task.wait(3)

            local ItemsToFadeOut = {LogFrame:WaitForChild("ViewTile"), LogFrame:WaitForChild("ViewTile"):WaitForChild("Image"), LogFrame:WaitForChild("ViewTile"):WaitForChild("UIStroke"), LogFrame:WaitForChild("TextLabel"), LogFrame:WaitForChild("TextLabel"):WaitForChild("UIStroke")}
            for _, Overlay in pairs(LogFrame:WaitForChild("ViewTile"):WaitForChild("Overlay"):WaitForChild("Frame"):GetChildren()) do
                table.insert(ItemsToFadeOut, Overlay)
            end

            for _, Item in pairs(ItemsToFadeOut) do
                if Item:IsA("ImageLabel") then
                    TweenService:Create(Item, LogExitInfo, {ImageTransparency = 1}):Play()
                elseif Item:IsA("Frame") then
                    TweenService:Create(Item, LogExitInfo, {BackgroundTransparency = 1}):Play()
                elseif Item:IsA("UIStroke") then
                    TweenService:Create(Item, LogExitInfo, {Transparency = 1}):Play()
                elseif Item:IsA("TextLabel") then
                    TweenService:Create(Item, LogExitInfo, {TextTransparency = 1}):Play()
                end
            end

            task.wait(.7)

            LogFrame:Destroy()
        end)

    elseif Response == "Stock" or Response == "Insufficient" then
        NotifyBindable:Fire("Error purchasing, funds returned!", .8, Color3.fromRGB(255, 0, 0))
    end

    task.wait(.075)
    CDB = false
end

local function UpdateTimer()
    while true do
        local TimeRemaining = 180 - (os.time() - TimeOfStock)
        if TimeRemaining < 0 then
            TimeRemaining = 0
        end

        local Minutes = math.floor(TimeRemaining / 60)
        local Seconds = TimeRemaining % 60

        Timer.Text = "Stock resets in " .. string.format("%d:%02d", Minutes, Seconds)

        task.wait(1)
    end
end

local function EnterUtilityMode(SoldierFrame: Frame, MainFrame: Frame, UtilityFrame: Frame, UtilityButton)
    local SoldierFrameTween = TweenService:Create(SoldierFrame, UtilityInfo, {Size = SoldierFrame:GetAttribute("UtilitySize")})
    SoldierFrameTween:Play()

    local MainFrameTween = TweenService:Create(MainFrame, UtilityInfo, {Size = MainFrame:GetAttribute("UtilitySize")})
    MainFrameTween:Play()

    local UtilityButtonTween = TweenService:Create(UtilityButton, UtilityInfo, {Size = UtilityButton:GetAttribute("UtilitySize")})
    UtilityButtonTween:Play()

    local UtilityFrameTween = TweenService:Create(UtilityFrame, UtilityInfo, {Position = UtilityFrame:GetAttribute("UtilityPosition")})
    UtilityFrameTween:Play()

    task.wait(.1)
end

local function ExitUtilityMode(SoldierFrame: Frame, MainFrame: Frame, UtilityFrame: Frame, UtilityButton)
    local SoldierFrameTween = TweenService:Create(SoldierFrame, UtilityInfo, {Size = SoldierFrame:GetAttribute("StandardSize")})
    SoldierFrameTween:Play()

    local MainFrameTween = TweenService:Create(MainFrame, UtilityInfo, {Size = MainFrame:GetAttribute("StandardSize")})
    MainFrameTween:Play()

    local UtilityButtonTween = TweenService:Create(UtilityButton, UtilityInfo, {Size = UtilityButton:GetAttribute("StandardSize")})
    UtilityButtonTween:Play()

    local UtilityFrameTween = TweenService:Create(UtilityFrame, UtilityInfo, {Position = UtilityFrame:GetAttribute("StandardPosition")})
    UtilityFrameTween:Play()

    task.wait(.1)
end

local function StockStandardShop()
    for _, SoldierFrame: Frame in pairs(StandardFrame:WaitForChild("ScrollingFrame"):GetChildren()) do
        if SoldierFrame.Name == "UIListLayout" then continue end

        local Stock: TextLabel = SoldierFrame:WaitForChild("MainFrame"):WaitForChild("Stock")
        local CreditsButton: TextButton = SoldierFrame:WaitForChild("UtilityFrame"):WaitForChild("Credits")

        local Type = string.gsub(SoldierFrame.Name, "^%d+", "")
        local StockedSoldiers = CurrentStock[Type] or 0

        if StockedSoldiers <= 0 then
            Stock.Text = "0x Stock"
            Stock.TextColor3 = Color3.fromRGB(255, 0, 0)

            CreditsButton.TextLabel.Text = "NO STOCK"
            CreditsButton.TextLabel.TextColor3 = Color3.fromRGB(255, 0, 0)
            CreditsButton.TextLabel.UIStroke.Color = Color3.fromRGB(0, 0, 0)

            CreditsButton.BackgroundColor3 = Color3.fromRGB(98, 98, 98)
            CreditsButton.UIStroke.Color = Color3.fromRGB(61, 61, 61)
        else
            Stock.Text = StockedSoldiers .. "x Stock"
            Stock.TextColor3 = Color3.fromRGB(255, 255, 255)

            CreditsButton.TextLabel.Text = "$" .. SETTINGS.SOLDIER_DATA[Type]["Price"]
            CreditsButton.TextLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
            CreditsButton.TextLabel.UIStroke.Color = CreditsButton.UIStroke:GetAttribute("InStockColor")

            CreditsButton.BackgroundColor3 = CreditsButton:GetAttribute("InStockColor")
            CreditsButton.UIStroke.Color = CreditsButton.UIStroke:GetAttribute("InStockColor")
        end
    end
end

local function InitializeStandardShop()
    local ServerCurrentStock, ServerTimeOfStock = GetStockFunction:InvokeServer()
    CurrentStock = ServerCurrentStock
    TimeOfStock = ServerTimeOfStock

    task.spawn(UpdateTimer)

    for Num, Type in ipairs(SETTINGS.SHOP_ORDER) do
        local Data = SETTINGS.SOLDIER_DATA[Type]
        local SoldierFrame = TemplateFrame:Clone()
        SoldierFrame.Name = tostring(Num+1) .. Type

        local MainFrame = SoldierFrame:WaitForChild("MainFrame")
        MainFrame:WaitForChild("Label").Text = string.upper(Type)
        MainFrame:WaitForChild("Price").Text = "$" .. Data["Price"]

        local UtilityFrame = SoldierFrame:WaitForChild("UtilityFrame")
        local CreditsButton: TextButton = UtilityFrame:WaitForChild("Credits")
        local RobuxButton: TextButton = UtilityFrame:WaitForChild("Robux")
        local GiftButton: TextButton = UtilityFrame:WaitForChild("Gift")
        local UtilityButtons = {CreditsButton, RobuxButton, GiftButton}
        CreditsButton.TextLabel.Text = "$" .. Data["Price"]
        RobuxButton.TextLabel.Text = "R$" .. Data["RobuxPrice"]
        local ViewTile = MainFrame:WaitForChild("ViewTile")
        ViewTile.Image.Image = Data["Image"]

        SoldierFrame.Parent = StandardFrame:WaitForChild("ScrollingFrame")

        local Debounce = false
        local Mode = 0
        local UtilityButton = SoldierFrame:WaitForChild("UtilityButton")
        UtilityButton.MouseButton1Click:Connect(function()
            if Debounce then return end
            Debounce = true

            if Mode == 0 then
                EnterUtilityMode(SoldierFrame, MainFrame, UtilityFrame, UtilityButton)
                Mode = 1
            elseif Mode == 1 then
                ExitUtilityMode(SoldierFrame, MainFrame, UtilityFrame, UtilityButton)
                Mode = 0
            end

            task.wait(.1)
            Debounce = false
        end)

        CreditsButton.MouseButton1Click:Connect(function()
            PressCreditsButton(SoldierFrame, Type)
        end)

        table.insert(Buttons, CreditsButton)
        table.insert(Buttons, RobuxButton)
        table.insert(Buttons, GiftButton)
    end

    TemplateFrame:Destroy()
end

-- // Events
CloseButton.MouseButton1Click:Connect(function()
    if FrameActive == false then return end
    CloseFrameBindable:Fire(SoldierShopFrame)
end)

SoldierShopFrame:GetPropertyChangedSignal("Visible"):Connect(function()
    FrameActive = SoldierShopFrame.Visible
end)

RestockEvent.OnClientEvent:Connect(function(NewStock, TimeOfNewStock)
    CurrentStock = NewStock
    TimeOfStock = TimeOfNewStock

    StockStandardShop()
end)

InitializeStandardShop()
StockStandardShop()

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