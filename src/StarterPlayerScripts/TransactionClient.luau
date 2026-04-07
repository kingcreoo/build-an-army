-- // TransactionClient, initialized by KingCreoo on 2026-04-04
-- // Client-side helper for triggering Robux purchase prompts from GUI buttons

--[[
    OVERVIEW
    --------
    Reads product metadata from a button's attributes and wires up its click handler
    to call the appropriate MarketplaceService prompt method. No RemoteEvents needed
    because MarketplaceService.PromptProductPurchase and PromptGamePassPurchase are
    callable directly from the client.

    BUTTON SETUP
    ------------
    In Studio, set these attributes on the button you want to make a purchase button:
        ProductId   <number>    - the Robux dev product or gamepass ID
        ProductType <string>    - "DevProduct" or "Gamepass"

    Optional: also add an InvalidSound attribute (Sound instance or rbxassetid) if you
    want a different error sound when ProductId is zero/missing.

    USAGE
    -----
    local TransactionClient = require(path.to.TransactionClient)
    TransactionClient.BindButton(MyPurchaseButton)

    Or bind every descendant button at once:
    TransactionClient.BindDescendants(StoreFrame)

    The helper handles click sounds, debouncing, and missing-attribute validation.
]]

-- // Define
local TransactionClient = {}

-- // Services
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- // Modules
local SOUND_MANAGER = require(ReplicatedStorage:WaitForChild("Settings"):WaitForChild("SoundManager"))

-- // Variables
local LocalPlayer = Players.LocalPlayer
local BoundButtons = {}

-- // Private functions

-- Prompts the correct MarketplaceService method for the given product type
local function PromptPurchase(ProductType: string, ProductId: number)
    if ProductType == "DevProduct" then
        MarketplaceService:PromptProductPurchase(LocalPlayer, ProductId)
    elseif ProductType == "Gamepass" then
        MarketplaceService:PromptGamePassPurchase(LocalPlayer, ProductId)
    end
end

-- Returns true if the button has valid purchase attributes set
local function HasValidAttributes(Button: GuiButton): boolean
    local Id = Button:GetAttribute("ProductId")
    local Type = Button:GetAttribute("ProductType")

    if type(Id) ~= "number" or Id <= 0 then
        return false
    end
    if Type ~= "DevProduct" and Type ~= "Gamepass" then
        return false
    end
    return true
end

-- Handles a purchase button click with debounce and validation
local function OnButtonClicked(Button: GuiButton)
    if BoundButtons[Button] == "debounced" then
        return
    end

    if not HasValidAttributes(Button) then
        SOUND_MANAGER:PlayError()
        warn("[TransactionClient] Button '" .. Button:GetFullName() .. "' missing or invalid ProductId/ProductType attributes")
        return
    end

    SOUND_MANAGER:PlayClick()

    -- Brief debounce so rapid clicks don't spam the prompt
    BoundButtons[Button] = "debounced"
    task.delay(0.5, function()
        if BoundButtons[Button] == "debounced" then
            BoundButtons[Button] = true
        end
    end)

    local ProductId = Button:GetAttribute("ProductId")
    local ProductType = Button:GetAttribute("ProductType")
    PromptPurchase(ProductType, ProductId)
end

-- // Public functions

-- Wires up a single button. Safe to call on the same button twice (idempotent).
function TransactionClient.BindButton(Button: GuiButton)
    if BoundButtons[Button] then
        return
    end
    BoundButtons[Button] = true

    Button.MouseButton1Click:Connect(function()
        OnButtonClicked(Button)
    end)
end

-- Wires up every descendant TextButton/ImageButton that has the ProductId attribute
function TransactionClient.BindDescendants(Root: Instance)
    for _, Descendant in ipairs(Root:GetDescendants()) do
        if (Descendant:IsA("TextButton") or Descendant:IsA("ImageButton")) and Descendant:GetAttribute("ProductId") ~= nil then
            TransactionClient.BindButton(Descendant)
        end
    end

    -- Keep binding new buttons that appear later (e.g. dynamic store listings)
    Root.DescendantAdded:Connect(function(Descendant)
        if (Descendant:IsA("TextButton") or Descendant:IsA("ImageButton")) and Descendant:GetAttribute("ProductId") ~= nil then
            TransactionClient.BindButton(Descendant)
        end
    end)
end

-- // Return
return TransactionClient
