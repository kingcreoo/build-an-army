# DESIGN.md — Build an Army v2

Documentation of how this game works. Reference material for the developer and any AI pair programmer. If something in the code contradicts this doc, this doc wins.

**Code philosophy:** AI never writes code in this repo. All code is hand-typed by Collin. AI is a pair programmer — it discusses, advises, reviews, and explains, but every line comes from human fingers.

---

## Combat

- Soldiers fire straight into targets. No bullet curves, no aiming, no trajectory calculation.
- This is an idle game. Soldiers fire automatically without player input.
- Soldiers work even when the player is offline (idle rewards system).
- Each soldier type has a unique weapon mechanic (shotgun spread, burst fire, dual wield, etc.) but all fire in a straight line down the lane.

## Lanes

- 8 lanes per plot, uniform spacing (17 studs apart on Z axis).
- All 8 lanes are always physically present. Locked lanes are visually gated.
- Lane 1 is always leftmost regardless of plot orientation.
- Lane lengths are uniform across all lanes.
- Lanes are **positional, not sequential**. A player with lanes 1-3 and 8 unlocked has gaps at 4-7. Soldiers equip to specific lane positions.
- Lanes 1-3: unlocked by default.
- Lanes 4-6: unlocked with credits. Do NOT persist through rebirth.
- Lane 7: unlocked with rebirth token.
- Lane 8: unlocked with commander pass.

## Plots

- 6 plots, always loaded in `workspace.Plots` as `Plot1` through `Plot6`.
- Never cloned from a template. They exist in workspace at all times regardless of occupancy.
- Plots are identical in shape but may orient different directions. Never mirrored. Lane 1 is always leftmost.
- Each plot has two main areas: a firing range (higher elevation) and a shop area (a few steps down, connected by stairs).
- Players can see their firing range from the shop area.

### Plot Contents

Each plot folder contains:
- `InteractionRings/` — all ring interaction points
- `Spawns/` — SoldierPlatform/TargetPlatform models + SoldierSpawn1-8 and TargetSpawn1-8 invisible anchor parts
- `Build/` — physical decoration (BoostTree, Fences, NPC shop builds)
- `CashCollectors/` — CollectCash1 through CollectCash8
- `RangeAreaBase` — ground part for the firing range
- `ShopAreaBase` — ground part for the shop area

### Plot Assignment

Server maintains two dictionaries:
```
PlotAssignments = {Plot1 = Player, Plot2 = Player, ...}
PlayerPlots = {Player = "Plot1", ...}
```
On join: assign first unoccupied plot. On leave: clear both entries. If all plots full: kick with "Server full."

Plots stay named Plot1-Plot6 forever. Never renamed to player names.

## Interaction System

Everything uses **ProximityPrompt tap buttons**. No walk-up Touched triggers anywhere in the game. This is a universal rule.

Flow: player approaches → prompt appears → player taps → UI opens. Walking away closes the UI (listen to `PromptHidden`).

### Prompt Settings (all rings)

- `MaxActivationDistance = 10`
- `HoldDuration = 0` (instant tap)
- `RequiresLineOfSight = false`
- `ObjectText = ""` (billboard GUIs handle labeling)
- Prompt lives under `GuiParts` in each ring model

Only the plot owner can interact with their plot's prompts. Other players see shops but cannot interact.

### Ring Instance Structure

```
[Model] RingName
  [Part] FadePart (invisible, CanCollide=false)
    [Decal] (Transparency controlled for on/off)
    [SpecialMesh]
  [Part] GuiParts (invisible anchor for GUIs + prompt)
    [BillboardGui] Label
    [BillboardGui] Info/Price
    [BillboardGui] Icons (optional, rebirth/commander rings)
    [ProximityPrompt] Prompt
  [MeshPart] RingPart (visible ring mesh)
    [ParticleEmitter]
```

### Ring On/Off States

Off state (default for conditional rings):
- All BillboardGuis: `Enabled = false`
- RingPart: `Transparency = 1`
- FadePart Decal: `Transparency = 1`
- ParticleEmitter: `Enabled = false`
- ProximityPrompt: `Enabled = false`
- CanCollide on invisible parts: `false`

On state: flip all to visible/enabled.

**Always-on rings:** SoldierShopRing, UpgradeTargetRing, BoostRing, RebirthRing, TrashCanRing.

**Conditional rings (start off, toggled by code):** UnlockLaneRing, UnlockRebirthLaneRing, UnlockCommanderPassRing, StarterPackRing, CommanderPassRing.

### ActionText per Ring

- Shop/feature rings: "Open"
- Unlock rings: "Unlock"
- TrashCan: "Sell"

## Collect Cash Buttons

Per-lane buttons tied to the **lane**, not the soldier. Located in `CashCollectors/CollectCash1-8`.

### Structure
```
[Model] CollectCashN
  [Part] (0.2 stud thin, invisible, CanCollide=false)
  [Part] (0.5 stud, invisible, CanCollide=false)
    [ParticleEmitter] (idle pulse when active)
  [Part] GuiParts (invisible)
    [BillboardGui] LabelGui — "Collect cash"
    [BillboardGui] CashPerSecondGui — shows lane DPS
    [BillboardGui] CashToCollectGui — shows pending amount
```

All GUIs and particles start `Enabled=false`. Activated when lane has an active soldier.

### Behavior

- Player steps on button → PendingCash drains to zero → added to credits.
- Button tweens down slightly (physical button press feel).
- Button flashes white smoothly.
- Particle emitter bursts with extra particles on collect.
- Idle particle emitter runs slowly when lane is active (visual "cash is here" indicator).
- If soldier deactivated: button stays, shows $0/sec, pending cash remains collectible.
- If soldier swapped: pending cash stays, new soldier starts adding to it.
- Unclaimed cash persists between sessions.
- On rejoin: unclaimed cash sits on the buttons. NOT bundled into the idle earnings popup.
- Idle rewards calculate separately and stack on top of PendingCash.

### Auto-Collect Gamepass

- Cash goes straight to credits, bypassing PendingCash entirely.
- No sweep loop — just a branch in reward logic.
- Buttons still animate visually so player sees money flowing.
- Only runs while player is in-game. Does not apply on logout.

## AutoEquip

- Default: ON. Target audience is mobile players ages 7-13.
- Manual placement is opt-in via settings toggle.
- Fills the next empty **unlocked** slot, skipping gaps.

## Shops

- Soldier shop: GUI-based scroll frame with stock rotation system. Not world-space display.
- Upgrade target: pedestal showcasing the next target.
- Rebirth wizard: NPC behind counter.
- Soldier shop: NPC behind counter.
- TrashCan ring: sells soldiers for cash.

## Spawning

- Players spawn directly into their assigned plot.
- Limbo system: character held in limbo box while data loads, then teleported to plot.

## Server Config

- Max players per server: 6.
- Max plots: 6 (one per player).
- Fixed daytime lighting.
- Third-person camera, default Roblox.

## Soldier Tiers

- Tier 1 (6 soldiers): light blue aesthetic, unique weapon mechanics each.
- Tier 2 (3 soldiers): deep red elite/bandit aesthetic.
- Tier 3 (3 soldiers): techno/art deco aesthetic.
- 2 premium purchase soldiers (Robux).

## Architecture

### Server Files (src/ServerScriptService/)

**init.server.luau** — Main server script. Handles player join/leave lifecycle, character spawning, plot assignment, and hosts all RemoteEvent/RemoteFunction handlers for: PurchaseSoldier, ActivateSoldier, DeactivateSoldier, UpdateSetting, SellSoldier, UnlockSlot, UpgradeTarget. Also runs the stock restock loop. This is the largest and most critical file.

**Data.luau** — DataStore wrapper. Exposes `Data.Get(Player)`, `Data.Set(Player)`, `Data.Initialize(Player)`, `Data.Remove(Player)`. Stores player data in a module-level `Database[PlayerName]` table. All persistent reads/writes go through here.

**Plot.luau** — Plot manager. `Plot.new()` creates a plot instance for a player. Handles soldier activation/deactivation (`SetSoldier`, `ClearSoldier`), target placement (`SetTarget`), and the collect-pad interaction. Fires BindableEvents so RewardLoop can react without circular requires.

**RewardLoop.luau** — Server-side combat loop running on Heartbeat. Iterates every active soldier every frame, manages fire timing, bullet creation, damage calculation, and pending reward accumulation. Stores ephemeral combat state in `Soldiers`, `Targets`, `Timers`, `PendingRewards` tables keyed by player name. Also handles `ClaimRewards` and soldier spawn delay.

**IdleRewards.luau** — Calculates offline earnings when a player joins based on time since last logoff. Estimates what each active soldier would have earned using fire rate and target health math. Wired via `IdleRewardsEvent`.

**TransactionManager.luau** *(AI-written, needs rewrite)* — Handles `MarketplaceService.ProcessReceipt` for dev product purchases. Currently acks before DataStore confirms save.

**ProductConfig.luau** *(AI-written)* — Config table defining what each Robux product grants (soldiers, credits, starter pack contents).

### Client Files (src/StarterPlayerScripts/)

**init.client.luau** — Client entry point. Sets up initial data loading, connects LoadPlayerEvent, manages the PublicAnimations flag.

**PlotVisualizer.luau** — Renders all visual combat for all players. Handles soldier model placement, target model placement, bullet animation, target death/respawn animation, health bars. Runs its own Heartbeat loop for other players' soldier fire timing (visual only, not authoritative).

**EntityHandler.luau** — Object pool for bullets and explosions. Pre-warms 200 of each type. Provides `Get()` and `Recycle()` for reuse instead of `Instance.new` per shot.

**UI.client.luau** — HUD management, frame open/close routing, notification system, button hover effects (ButtonExpand/Deflate). Manages which frame is currently active and handles priority/debounce.

**SoldierShop.client.luau** — Soldier purchase UI. Scroll frame listing available soldiers, stock display, restock timer. Fires `PurchaseSoldier` RemoteFunction.

**SoldierInventory.client.luau** — Soldier inventory management. Displays owned soldiers, handles activate/deactivate toggle. Fires `ActivateSoldier`/`DeactivateSoldier` RemoteFunctions.

**SellSoldiers.client.luau** — Soldier selling UI. Confirmation flow, server-authoritative sell. Fires `SellSoldier` RemoteEvent.

**UnlockSlots.client.luau** — Lane unlock UI. Fires `UnlockSlot` RemoteEvent.

**TargetUpgrades.client.luau** — Target upgrade UI. Shows next target, price, fires `UpgradeTarget` RemoteEvent.

**Settings.client.luau** — Settings toggles (AutoEquip, PotatoMode). Fires `UpdateSetting` RemoteFunction.

**RobuxStore.client.luau** — Robux store UI with cash packs and passes panes.

### Shared (src/ReplicatedStorage/)

**init.luau (SETTINGS)** — The single source of truth for game constants. Contains `DEFAULT_DATA` (player data schema), `SOLDIER_DATA` (stats per soldier type), `TARGET_DATA`, `SLOT_PRICES`, `SHOP_ORDER`, stock amounts, and more. Every server and client file requires this.

**SoundManager.luau** — Sound effect playback (clicks, purchases, errors, hitmarkers).

**Promise.luau** — Third-party roblox-lua-promise library, vendored.

### Remotes (all in ReplicatedStorage.Remotes)

**Client → Server (actions):**
| Remote | Type | Handler |
|--------|------|---------|
| PurchaseSoldier | RemoteFunction | init.server.luau |
| ActivateSoldier | RemoteFunction | init.server.luau |
| DeactivateSoldier | RemoteFunction | init.server.luau |
| UpdateSetting | RemoteFunction | init.server.luau |
| GetStock | RemoteFunction | init.server.luau |
| GetPlayerData | RemoteFunction | init.server.luau |
| SellSoldier | RemoteEvent | init.server.luau |
| UnlockSlot | RemoteEvent | init.server.luau |
| UpgradeTarget | RemoteEvent | init.server.luau |
| IdleRewards | RemoteEvent | IdleRewards.luau |
| SyncTables | RemoteFunction | RewardLoop.luau *(SECURITY BUG — delete this)* |

**Server → Client (broadcasts):**
| Remote | Type | Purpose |
|--------|------|---------|
| SetSoldier | RemoteEvent | Soldier placed on lane (all clients) |
| SetTarget | RemoteEvent | Target placed on lane (all clients) |
| ClearSoldier | RemoteEvent | Soldier removed from lane (all clients) |
| FireSoldier | RemoteEvent | Soldier fired (owner client only) |
| LoadPlayer | RemoteEvent | Push player data to owner on join |
| Restock | RemoteEvent | Shop stock refresh (all clients) |
| UpdateInventoryEvent | RemoteEvent | Inventory changed (owner client) |
| DisplayTarget | RemoteEvent | Target upgrade visual (owner client) |
| Notify | RemoteEvent | Notification to owner client |
| CollectedCredits | RemoteEvent | Credits collected confirmation |

**Internal (BindableEvents, not cross-boundary):**
SetSoldierBindable, SetTargetBindable, ClearSoldierBindable, UpdateInventory, ButtonExpand, ButtonDeflate, CloseFrame, NotifyBindable, UpdateSettingBindable, OpenStoreBindable, HUDBindable.

### Current Player Data Schema (DEFAULT_DATA)

```lua
{
    leaderstats = { Credits = 100000000 },  -- debug value, needs real number
    Plot = {
        Unlocks = {
            Slot1 = true, Slot2 = true, Slot3 = true,
            Slot4 = false, Slot5 = false, Slot6 = false, Slot7 = false
            -- Slot8 missing, needs adding
        }
    },
    Inventory = {
        ActiveSoldiers = {},          -- currently compact array, needs dict-by-lane
        SoldierInventory = {},        -- dict keyed by GUID
        ActiveTarget = "Target1",
        TargetInventory = { Target1 = true },
    },
    Settings = { AutoEquip = false, PotatoMode = false },
    -- Added at save time only (not in defaults):
    -- LogOff = os.time()
    -- PendingRewards = number
}
```

### Data Flow Summary

```
Kill happens (server, RewardLoop Heartbeat)
  → PendingRewards[PlayerName] += reward
  → Player steps on collect pad → ClaimRewards → Data.Set (credits += pending)

Purchase (client fires PurchaseSoldier)
  → Server validates stock + funds → deducts credits → adds to SoldierInventory
  → Data.Set → returns updated data to client

Activate soldier (client fires ActivateSoldier)
  → Server validates ownership + slot available
  → Plot:SetSoldier → fires SetSoldierBindable → RewardLoop picks it up
  → SetSoldierEvent:FireAllClients (visual sync)

Player leaves
  → Data.Remove saves LogOff + PendingRewards to DataStore
  → RewardLoop clears ephemeral tables (5s delay for in-flight bullets)
```

### Trust Boundary

Server is authoritative for all currency, inventory, and combat math. Client never tells server "I have N credits" — it tells server "do this action" and server validates and decides. Credits are mirrored to client via `Player.leaderstats.Credits` NumberValue (auto-replicated by Roblox). Client caches `LatestData` in multiple files (SoldierShop, SoldierInventory, SellSoldiers) via `UpdateInventoryBindable` fanout — these can desync if a fire is missed.

---

## MAKER Script

`MAKER_v2.luau` dumps the Studio hierarchy to `maker_output.txt` via HTTP POST to a local Python receiver (`maker_receiver.py`). Place script in ServerScriptService, run receiver first, then Play in Studio. Output is ground truth for what exists in Studio.
