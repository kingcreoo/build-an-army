# NOTES

## TransactionManager — quick usage guide

Built 2026-04-04 for handling Robux dev products + gamepasses.

### Adding a new product or gamepass

Edit `src/ServerScriptService/ProductConfig.luau`. Add an entry:

```lua
MyNewPack = {
    Type = "DevProduct",        -- or "Gamepass"
    Id = 123456789,             -- the real Roblox product/gamepass ID
    OnGrant = function(Player, PlayerData)
        PlayerData.leaderstats.Credits += 5000
    end,
}
```

That's it. `TransactionManager` picks it up on startup.

### Wiring a purchase button in Studio

On any TextButton or ImageButton in the store UI, set two attributes:
- `ProductId` (number) — the real Roblox ID
- `ProductType` (string) — `"DevProduct"` or `"Gamepass"`

Then from any client script:
```lua
local TransactionClient = require(LocalPlayer.PlayerScripts.Client.TransactionClient)
TransactionClient.BindButton(MyButton)
```

Or wire up every purchase button inside a frame at once (including dynamically-added ones):
```lua
TransactionClient.BindDescendants(StoreFrame)
```

### Querying gamepass ownership at runtime (for continuous effects)

```lua
local TransactionManager = require(ServerScriptService.Server.TransactionManager)
if TransactionManager.IsPassOwned(Player, "CommanderPass") then
    -- apply 2x multiplier, etc
end
```

The `OnGrant` callback in ProductConfig is for **one-time** effects only (e.g. unlock slot 7).
For continuous effects like "earn more credits forever while owning the pass", always query
`IsPassOwned` at runtime instead of putting the logic in `OnGrant`.

### Where granted purchases are tracked

Inside `PlayerData.Transactions`:
- `GrantedPurchases[PurchaseId] = true` — per-receipt dedupe for dev products
- `AppliedPasses[PassName] = true` — one-time gamepass grant flag

This field is lazily created if an old player's data doesn't have it. New players get it
from `DEFAULT_DATA` in `src/ReplicatedStorage/init.luau`.

### Security notes

- Grants happen server-side only, inside `MarketplaceService.ProcessReceipt`
- Unknown product IDs never return `PurchaseGranted` (Roblox retries forever until registered)
- Data-not-loaded scenarios return `NotProcessedYet` (Roblox retries)
- All `OnGrant` calls are pcalled; a throwing handler returns `NotProcessedYet`
- No RemoteEvents in the purchase flow — client calls `MarketplaceService` directly
