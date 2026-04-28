# ROADMAP.md — Build an Army v2

All upcoming work. Redux, fixes, new systems, new features.

---

## Phase 1: REDUX

Get the game working on the new map with current features. No new features until this is done.

### Plot System Refactor
- [ ] Delete `PlotTemplate` reference in Plot.luau (line 18) and `PlotTemplate:Clone()` (line 198)
- [ ] Replace `Plot.new` to find pre-built plot via `workspace.Plots:FindFirstChild(plotName)`
- [ ] Implement `PlotAssignments` / `PlayerPlots` dictionaries in init.server.luau
- [ ] Remove `AssignPlotAnchor()` function and `OccupiedAnchors` table
- [ ] Remove `PlotAnchor` parameter from `PlotManager.new`
- [ ] Delete or refactor `Plot:Create()` method
- [ ] Add "Server full" kick when all plots occupied
- [ ] Delete `workspace.Anchors` folder from Studio
- [ ] Wire plot vacant/active state on join/leave

### Wire Interaction Rings to UIs
- [ ] SoldierShopRing → SoldierShop GUI
- [ ] UpgradeTargetRing → UpgradeTarget GUI
- [ ] TrashCanRing → SellSoldiers GUI
- [ ] UnlockLaneRing → unlock flow (replaces old UnlockSlots shop)
- [ ] UnlockRebirthLaneRing → rebirth unlock flow (placeholder until rebirths exist)
- [ ] UnlockCommanderPassRing → commander pass purchase
- [ ] StarterPackRing → starter pack purchase
- [ ] CommanderPassRing → commander pass info/purchase
- [ ] BoostRing → boost tree GUI (placeholder until boost system exists)
- [ ] RebirthRing → rebirth wizard GUI (placeholder until rebirth system exists)
- [ ] PromptHidden closes associated UI on walk-away
- [ ] Only plot owner can trigger prompts on their plot

### Collect Cash System
- [ ] Add `PendingCash = {}` per lane to player data schema
- [ ] Server: on kill reward, add to `PendingCash[laneNumber]`
- [ ] Server: player steps on CollectCash button → drain PendingCash to credits
- [ ] Enable/disable CollectCash GUIs + particles based on lane activity
- [ ] Update CashPerSecondGui and CashToCollectGui text live
- [ ] Button tween down + white flash + particle burst on collect
- [ ] PendingCash persists between sessions
- [ ] Idle rewards stack on top of PendingCash on rejoin
- [ ] Delete old Collect pad system

### Lane System Update
- [ ] Change ActiveSoldiers from compact array to dict keyed by lane number
- [ ] Delete ReindexTable function
- [ ] Update AutoEquip to fill next empty unlocked slot, skipping gaps
- [ ] Update all code reading/writing ActiveSoldiers for new format
- [ ] Add lane 8 support (SETTINGS, unlock logic, spawn positions)
- [ ] Wire UnlockLaneRing to appear at next unlockable lane (4, 5, or 6)
- [ ] Lane 7 unlock via rebirth token (stub until rebirths)
- [ ] Lane 8 unlock via commander pass

### Data.luau Critical Fixes
- [ ] On load failure: kick player, never fall through to default data — *currently a transient DataStore outage gives the player a blank account and overwrites their real save on leave*
- [ ] Add `game:BindToClose()` to flush saves on shutdown — *currently any data not yet written is lost on server close*
- [ ] Switch from `SetAsync` to `UpdateAsync` — *SetAsync doesn't protect against concurrent writes from multiple write paths*
- [ ] Use `Player.UserId` instead of `GetUserIdFromNameAsync(Player.Name)` — *async web call for a player already in server; can fail and silently skip saves*
- [ ] Change DataStore key to named versioned key (`"PlayerData_v1"`) — *current key is a keyboard-mash string, easy to mistype and orphan all data*
- [ ] Add `_Version = 1` to default player data — *no way to safely migrate schema changes without a version field*
- [ ] Set starting credits to a real value (not 100M) — *every new player can currently buy the entire game instantly*

### Security Fixes
- [ ] Delete `SyncTables` RemoteFunction — *returns every player's combat state to any client that calls it*
- [ ] Add `SOLDIER_DATA[Type] ~= nil` guard on PurchaseSoldier — *client sending garbage type crashes the server (DoS vector)*
- [ ] Add same guard on SellSoldier — *same nil index crash*
- [ ] Add rate limiting on write-path remotes (SellSoldier, UpgradeTarget, UnlockSlot, IdleRewards) — *unlimited spam forces repeated SetAsync calls, blows DataStore write budget*

### Rewrite AI-Written Code
- [ ] TransactionManager.luau — *currently acks ProcessReceipt before DataStore confirms save; DataStore throttle = player loses Robux permanently*
- [ ] Soldier rename migration — *"The Grunt" renamed to "Grunt" with no migration; existing saves silently lose those soldiers behind nil guards*
- [ ] SLOT_PRICES sentinel mismatch — *SETTINGS says "Commander" but server checks "VIP"; slot 7 purchase throws type error at runtime*
- [ ] Push+pull duplication — *AI added pull without removing push; every client init runs twice; nil return on timeout crashes clients*
- [ ] Hitmarker system — *Instance.new per hit; ~280 BillboardGuis/sec at full server = frame drops. Rewrite as pooled ring buffer*
- [ ] Starter pack / commander pass — *~120 lines near-identical in two functions; will drift on any edit. Extract shared helper*
- [ ] ApplyViewTileStyle — *copy-pasted into 3 files with silent drift; all rarities use identical colors so the feature does nothing*

### Misc Fixes
- [ ] Replace all `SetPrimaryPartCFrame` with `PivotTo` (4+ callsites)
- [ ] Fix `UI.client.luau:281` — compares frame to boolean (always false)
- [ ] Remove `print('1')` and `print('2')` from Plot.luau
- [ ] Guard RewardLoop AddReward against player-left-during-bullet-flight
- [ ] Fix PlotVisualizer — add nil guard to `RegenerateHealthBar` matching `DamageHealthBar`

### Commander Pass
- [ ] Grants lane 8 unlock
- [ ] Mid-session purchase handling (PromptGamePassPurchaseFinished)
- [ ] GamePass ownership check on join with retry on API failure
- [ ] Commander pass ring activates for non-owners, hides for owners

### Soldier Art & Polish
- [ ] 12 base-game soldiers: armor, weapon models, icons, animations
  - Tier 1 (6): Grunt, Shotgunner, Heavy, Sniper, Dual Pistol, Spray 'n Pray
  - Tier 2 (3): Captain, Backpack Bandit, Baseball Cap Raider
  - Tier 3 (3): Vector, One-shot, Akimbo
- [ ] 2 premium purchase soldiers with pedestal display models

---

## Phase 2: SYSTEMS

### Boost System
- [ ] Define boost types: cash multiplier, damage multiplier, fire rate multiplier
- [ ] Server-side BoostManager module
- [ ] Stacking behavior: additive or multiplicative (DECISION NEEDED)
- [ ] Integrate with reward calculation and combat
- [ ] Support sources: commander pass, premium soldiers, boost tree, rebirths, crates
- [ ] Data model for active boosts (timed vs permanent, source tracking)

---

## Phase 3: FEATURES

### Boost Tree
- [ ] Design tree structure, progression, costs
- [ ] UI opens from BoostRing prompt
- [ ] Server-side progression tracking

### Boost Obbies
- [ ] Design courses, difficulty, rewards
- [ ] Location: on-plot with teleport or center strip (UNDECIDED)
- [ ] Timed? Repeatable? Cooldown? (UNDECIDED)

### Free Crates
- [ ] Spawn mechanics (UNDECIDED: fixed timer vs random, per-player vs shared)
- [ ] Contents: boosts, coins, sometimes soldiers
- [ ] Visual: crate falls from sky with effects

### Rebirths & Rebirth Wizard
- [ ] Define what rebirth resets (UNDECIDED: full details)
- [ ] Rebirth token earning formula
- [ ] Wizard UI from RebirthRing prompt
- [ ] Temp OP soldiers (don't survive next rebirth)
- [ ] Permanent boosts via rebirth tokens
- [ ] Lane 7 unlock via rebirth token

### Auto-Collect Gamepass
- [ ] Create gamepass
- [ ] Branch in reward logic: auto-collect → credits, else → PendingCash
- [ ] Visual feedback on buttons during auto-collect
- [ ] Ownership check on join + mid-session purchase

### Teleport UI
- [ ] UI above HUD
- [ ] Destinations: homebase, soldier shop

### Leaderboard
- [ ] Physical leaderboard at ends of center strip
- [ ] Metrics (UNDECIDED)

### Best Soldier Pedestal
- [ ] Display at plot entrance
- [ ] Shows highest rarity tier soldier
- [ ] Updates on purchase/rebirth

### Captain's Task NPC
- [ ] Staged quest system (like battle pass structure)
- [ ] Post-rebirths, post-boosts priority — if time permits

---

## Polish & Launch
- [ ] Icons, thumbnails, ads
- [ ] Map polish, music, ambience
- [ ] Economy tuning with playtest data
- [ ] Mobile playtest
- [ ] Game page on Roblox
