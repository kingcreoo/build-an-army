-- // Shared utility: applies a soldier's tier color and gradient to a ViewTile frame
local SETTINGS = require(script.Parent)

return function(ViewTile: Frame, SoldierType: string)
    local Data = SETTINGS.SOLDIER_DATA[SoldierType]
    ViewTile.BackgroundColor3 = Data["ShopColor"]

    local Gradient = ViewTile:FindFirstChildOfClass("UIGradient")
    if not Gradient then
        Gradient = Instance.new("UIGradient")
        Gradient.Parent = ViewTile
    end
    Gradient.Color = ColorSequence.new(Data["ShopGradient1"], Data["ShopGradient2"])
    Gradient.Rotation = 90
end
