# AUDIT.md — Combined Code Audits

Two audits were performed on this codebase. The **baseline audit** covers all code written by the developer before AI involvement. The **AI commit audit** covers 14 commits written by Claude Code without developer oversight, from "Switch toggle buttons to gradients" through "Add comprehensive sound system."

Both audits use the same rating system:
- ✅ SOLID / KEEP — no meaningful issues
- ⚠️ REVIEW — works but has issues to be aware of
- 🔴 FIX / REWRITE — has bugs or vulnerabilities that need addressing

---

# Part 1: Baseline Audit (developer-written code)

Audited at commit d18e10b, before any AI commits.

## Critical Issues

### 1. Starting credits = 100,000,000
`SETTINGS.DEFAULT_DATA.leaderstats.Credits` at init.luau:8. Every new player starts with enough to buy the whole game. Set to a real value.

### 2. Silent data wipe on DataStore load failure
Data.luau:42-49. On `GetAsync` failure, falls through to `DEFAULT_DATA`. On player leave, overwrites previous save with blank data. This is the classic Roblox data-wipe bug. Fix: kick the player on failed load.

### 3. SyncTables leaks all player data
RewardLoop.luau:381. `OnServerInvoke` returns every player's `Soldiers/Targets/Timers/PendingRewards` to any client that calls it. If unused by any client file, delete. If used, filter to calling player only.

### 4. PurchaseSoldier crashes on invalid Type
init.server.luau:181. `CurrentStock[Type]` — if client sends a nonexistent soldier name, indexes nil and errors. Add `if not SETTINGS.SOLDIER_DATA[Type] then return end` guard. Same issue in SellSoldier.

### 5. Settings button toggle bug
UI.client.luau:281. `if ActiveFrame == SettingsDB` compares a Frame instance to a boolean debounce variable. Always false. Settings button never closes the frame on second click — causes flicker.

## File-by-File Verdicts

### ReplicatedStorage/init.luau (SETTINGS) — 🔴 FIX
- Line 8: Credits = 100M (debug leftover)
- Line 14: DataStore key is keyboard-mash string. Use named versioned key.
- Line 22: ActiveSoldiers as array + sparse holes = DataStore foot-gun
- Line 167: `[7] = "VIP"` stringly-typed sentinel in numeric price table
- Instance references (Color3, CFrame) in SETTINGS won't serialize if written back

### ReplicatedStorage/SoundManager.luau — ⚠️ REVIEW
- Dead `LocalPlayer` reference never used
- Colon syntax on plain table (works, misleading)
- `PlayHitmarker` creates new Part per shot — perf issue under heavy fire
- `Sound.TimeLength` is 0 until loaded — first call fires cleanup before sound plays

### ServerScriptService/init.server.luau — 🔴 FIX
- Lines 39, 75, 98: `GetUserIdFromNameAsync(Player.Name)` for a player already in server. Use `Player.UserId`.
- Lines 40-44: Silent fallback to default on load failure = data wipe
- Line 181-213: PurchaseSoldier has no Type validation, no rate limit, race conditions on concurrent calls
- Line 289-313: UpdateSetting `== nil` check breaks on falsy values
- Line 316-350: SellSoldier doesn't validate `SOLDIER_DATA[SoldierType]` exists
- Line 353-399: UnlockSlot has no lock against near-simultaneous invocations
- Line 427-437: Returns raw PlayerData to client (leaks if private fields added)
- Line 268: `SetPrimaryPartCFrame` deprecated, use `PivotTo`
- Line 261: No check if `AssignPlotAnchor()` returns nil (all plots full)

### ServerScriptService/Data.luau — 🔴 FIX
- Line 38-44: Silent fallback to default on load failure
- No retry or queue on save failure
- No `BindToClose` — data lost on server shutdown
- No session locking — rejoin to different server can clobber data
- Should use `UpdateAsync` instead of `SetAsync`
- No schema versioning (`_Version` field)
- `LogOff` and `PendingRewards` only exist after first logoff — unstable shape

### ServerScriptService/Plot.luau — ⚠️ REVIEW
- Lines 72, 79: Stray `print('1')`, `print('2')`
- Line 95: `ClearSoldierEvent:FireAllClients` — N² event traffic at scale
- Line 86-89: `ReindexTable` uses `pairs` which has no defined order in Luau
- Line 157: `tonumber(string.sub(SlotNumber, 5))` scattered across files — fragile
- Line 269: `SetPrimaryPartCFrame` deprecated

### ServerScriptService/RewardLoop.luau — ⚠️ REVIEW
- Line 292-345: Heartbeat iterates every soldier every frame. Fine up to ~30 players.
- Line 93-99: `task.delay(TimeToHit, AddReward)` can crash if player leaves mid-flight — `Targets[PlayerName]` becomes nil
- Line 34-43: Nils `Soldiers/Targets/Timers` immediately on leave, but delayed bullets still reference them
- Line 68: `PendingRewards[PlayerName] + RewardAmount` — nil arithmetic if player between cleanup and rejoin
- Line 118: `FireSoldierEvent:FireClient` sends full SoldierData including functions — Roblox warns on function serialization
- Line 347: Circular dependency workaround with `require(script.Parent.Data)` inside function
- Line 369-371: **SyncTables returns all players' data to any client invoker** 🔴

### ServerScriptService/IdleRewards.luau — ⚠️ REVIEW
- Line 96: `HasVIP = false -- TODO` stubbed
- Line 119-131: Idempotent but no rate limit — spamming FireServer forces Data.Set churn
- Math is consistent (FireRate = seconds between shots everywhere)

### StarterPlayerScripts/PlotVisualizer.luau — ⚠️ REVIEW
- Line 287, 368: Can crash if `Targets[PlayerName]` not yet populated when FireSoldier arrives before SetTarget
- Line 382-449: Client Heartbeat duplicates server fire timing for other players — visual drift
- Line 405: `Workspace.Plots[PlayerName]` can error if plot not created yet
- Line 564: `WaitForChild(SoldierData["Model"])` yields forever on stale model name
- Line 591: `SetPrimaryPartCFrame` deprecated

### StarterPlayerScripts/UI.client.luau — ⚠️ REVIEW
- Line 281: `if ActiveFrame == SettingsDB` — compares Frame to boolean, always false 🔴
- Line 12: `SOUND_MANAGER = nil` initialized then reassigned — unnecessary pattern
- Various debounce and tween coupling issues

### StarterPlayerScripts/SoldierShop.client.luau — ⚠️ REVIEW
- Line 229: Frame name parsing via string.gsub — fragile contract
- Line 125: Full PlayerData broadcast via bindable — multiple caches can desync
- Line 166: "Funds returned" message on cases where funds were never taken

### StarterPlayerScripts/SellSoldiers.client.luau — ✅ SOLID
Clean pattern. Good LoadPlayerEvent race-condition fix.

### StarterPlayerScripts/UnlockSlots.client.luau — ✅ SOLID
Good server-authority pattern. One nit: deprecated SetPrimaryPartCFrame.

### StarterPlayerScripts/SoldierInventory.client.luau — ⚠️ REVIEW
- Line 51: Two BindableEvents both named "DeactivateBindable"
- Line 220: Debounce allows 3 server calls in 1 second — no server-side rate limit
- Line 198-216: Toggle visual logic duplicated with Settings.client.luau

### StarterPlayerScripts/EntityHandler.luau — ⚠️ REVIEW
- Line 43: Pool empty → returns nil → caller crashes on `Entity.CFrame`
- Line 58: O(N) find-and-remove on recycle
- No bullet state reset before reuse

### StarterPlayerScripts/Settings.client.luau — ⚠️ REVIEW
- Same Bounces-pattern rate issue as SoldierInventory

### StarterPlayerScripts/TargetUpgrades.client.luau — ⚠️ REVIEW
- Line 85: SetPrimaryPartCFrame deprecated
- Line 180-204: Response is mixed string sentinel + data — should be enum

## Security Summary

**Overall exploit surface: medium-high.**

Critical: SyncTables leaks all player data. PurchaseSoldier crashes on bad input (DoS vector). Data.luau wipes on transient DataStore failure.

Medium: No rate limiting on any write-path remotes. Data.Get → mutate → Data.Set without locking means concurrent calls can duplicate soldiers.

Low: Leaderstats are Instance-replicated, always reflect server state.

## Scalability Ceiling

First bottleneck is **DataStore write budget** (~20-50 players). Every `Data.Set` is blocking `SetAsync` with no batching. Active play produces writes every few seconds per player. Second bottleneck is **network fan-out** (~20 players) from `FireAllClients` on every soldier/target change. Third is the **server Heartbeat loop** (~30 players) iterating every soldier every frame.

## Top 5 Strengths

1. **Server-authoritative purchase/currency flow.** Client never tells server "I have N credits."
2. **LoadPlayerEvent race-condition pattern.** Connect remote FIRST before WaitForChild.
3. **Clean separation of combat state from persistent state.** RewardLoop = ephemeral, Data = persistent.
4. **Entity pooling.** Pre-warm bullets/explosions instead of Instance.new per shot.
5. **Consistent UI lifecycle abstraction.** Every frame follows same open/close/debounce pattern.

---

# Part 2: AI Commit Audit (14 commits)

From "Switch toggle buttons to gradients" through "Add comprehensive sound system."

## Critical Issues

### 1. TransactionManager acks ProcessReceipt before DataStore confirms save
TransactionManager.luau:141-170. `Data.Set` pcalls SetAsync and swallows failures. `GrantDevProduct` returns true → ProcessReceipt returns PurchaseGranted → Roblox stops retrying. On DataStore throttle, player loses Robux. **Fix: Data.Set must return success boolean, ack only after save lands.**

### 2. SLOT_PRICES[7] = "Commander" vs server check "VIP"
init.luau sets sentinel "Commander" but init.server.luau:637 checks `Price == "VIP"`. Any slot-7 purchase attempt throws a type error at runtime.

### 3. Soldier rename without migration
Commit 72ccf08 renamed "The Grunt" → "Grunt" (and Heavy, Shotgunner, Dual). No migration written. Five sites got `if not X then continue` nil guards instead. Players with legacy saves silently lose those soldiers.

### 4. DataStore key changed inside unrelated commit
c068177 changed DataStore key to "DataStore12123111231" inside a "starter pack" commit. Wipes all existing players if any exist.

### 5. Push + pull both run on join
Commit 1cd12a7 added pull via `GetPlayerDataFunction:InvokeServer()` but didn't remove the existing push. Every client script init runs twice on join. Handler returns nil on 10s timeout, clients index without nil-check → crash on DataStore stall.

## Per-Commit Verdicts

| Commit | Summary | Verdict |
|--------|---------|---------|
| 8d7fb36 | Toggle buttons to gradients | ⚠️ REVIEW — hex colors duplicated, dead commented code |
| 9aaf33d | Health bar nil fix + sell tweens | ⚠️ REVIEW — nil guard missing on RegenerateHealthBar |
| a6829d1 | Fix autoequip on lane unlock | ✅ KEEP |
| 1cd12a7 | Push to pull data load | 🔴 REWRITE — pick one, not both; nil on timeout crashes |
| 15e1e75 | Lock toggling during autoequip | ✅ KEEP (fix bindable name collision) |
| 65a28c5 | Gradient styling on view tiles | 🔴 REWRITE — copy-pasted into 3 files, identical colors across rarities |
| 03561e1 | Damage hitmarkers | 🔴 REWRITE — Instance.new per hit, ~280 BillboardGuis/sec at scale |
| 72ccf08 | Economy data + soldier renames | 🔴 REWRITE — rename without migration, buried 3x idle nerf, credits 100M→100 |
| 1072a5a | Update project docs | ✅ KEEP |
| 22753e5 | Robux transaction system | 🔴 REWRITE TransactionManager (persistence bug); KEEP ProductConfig/TransactionClient |
| 4ce089a | RobuxStore UI + wiring | ⚠️ REVIEW — money path correct, maintenance smells |
| c068177 | Timed starter pack | ⚠️ REVIEW — DataStore key change, window bypass exploit, repeat-purchase bug |
| bc5f002 | Commander pass purchasing | 🔴 REWRITE duplication (~120 lines copy-paste); ⚠️ REVIEW rest |

## Patterns Introduced by AI That Conflict With Developer Patterns

- **Copy-paste instead of shared modules** (ApplyViewTileStyle in 3 files, starter/commander as ~85% twins, soldier insertion duplicated across CreateSoldier/InjectSoldier/ProductConfig.GrantSoldier)
- **String-match dispatch** on LoadPlayerEvent EntryName instead of structured messages
- **Magic numbers** (7s cooldowns, 1s polls, hex colors) instead of SETTINGS constants
- **LoadPlayerEvent as "reload everything" broadcast** — every Robux purchase re-renders every UI module
- **Hallucinated comments** — "for reconnects, etc" referencing code that doesn't exist
- **Nil-guard reflex** — papering over data contract breaks instead of fixing root cause
- **Economy changes buried in maintenance commits** — 3x idle nerf hidden in a "nil guards" commit

## Overall Assessment

About 40% of AI-written code is trustworthy in production. Pure cosmetic changes and small bugfixes (~20% of code) are fine. UI plumbing (~30%) is functional with smells. The Robux transaction system, rename-without-migration, push+pull duplication, and hitmarker perf model (~50%) need real work.

**Single highest-risk item:** ProcessReceipt persistence bug in TransactionManager. Every DataStore throttle during a purchase silently steals Robux from a player.

**The AI's core failure mode:** It writes isolated code. Each commit works in its own bubble but doesn't verify invariants against the rest of the codebase (rename without migration, sentinel change without updating consumer, pull without deleting push, balance change in a "fix" commit).
