# IMPLEMENTATION_CONTEXT.md
Reference doc for AI instances working on Batches B–D. Contains only confirmed design decisions.

---

## Batch Plan

| Batch | What | Who writes what |
|---|---|---|
| A | HUD anim rewrite + teleport wiring | Sonnet (client-only, one file: UI.client.luau) |
| B | BoostManager + SETTINGS boost additions + RewardLoop/IdleRewards integration + client UI | Opus → server module; Sonnet → client scripts |
| C | RebirthManager + SETTINGS rebirth additions + lane gate logic + client UI | Opus → server module; Sonnet → client scripts. **Must come after B** (rebirth grants permanent boosts via BoostManager) |
| D | TaskManager + SETTINGS task data + stat hooks in init.server + client UI | Opus → server module; Sonnet → client script |

---

## Boost System

### Types (4 confirmed)
- **CashMultiplier** — affects all reward grants (kills, idle, crates)
- **DamageMultiplier** — multiplies soldier damage
- **FireRateMultiplier** — divides soldier fire interval
- **TargetMultiplier** — faster target spawn + more cash per kill (DPS-gated; only useful if soldiers can handle faster spawns)

### Stacking math (confirmed)
When a new timed boost of the same type arrives, the higher-amount one wins. The lower is converted to bonus time on the higher:
```
bonus_time = lower.remaining_seconds * (lower.amount - 1) / (higher.amount - 1)
```
Discard the lower after conversion. Order of pickup does not matter — result is symmetric.

### Permanent vs timed combine rule (confirmed)
```
effective_multiplier[type] = product(Boosts.Permanent[type]) × merged_timed[type]
```
Permanent boosts (from rebirths) live in `Boosts.Permanent`, never expire, multiply as a flat floor. Timed boosts (tree, crates, store) live in `Boosts.Active`, use merge math, then multiply the permanent floor. The two never merge into each other.

### Economy invariants (confirmed)
- Free sources (boost tree, crates, obbies) **never grant ≥ 3x**. Cap at 2.5x.
- Robux store boosts are **3x or 4x only**. This guarantees a purchased boost always wins the merge and always displays.
- `BoostManager.AddBoost` is **server-side only**. Never exposed via a client→server remote. Dev-product boosts call it inside `MarketplaceService.ProcessReceipt` via `ProductConfig.OnGrant`.

### Offline behavior (confirmed)
Boost `ExpiresAt` = `os.time() + duration`. Clock runs while offline. On rejoin, server walks `Boosts.Active` and drops any with `ExpiresAt <= os.time()`.

---

## Boost Tree

### Slot structure (confirmed)
| Slot | Unlock condition | Boost strength |
|---|---|---|
| Slot1 | Always unlocked (free) | 1.5x |
| Slot2 | Rebirth ≥ 1 | 2x |
| Slot3 | Rebirth ≥ 2 | 2.5x |

- Each slot generates a **random** boost type (Cash, Damage, FireRate, or Target).
- Generation timer per slot: **TBD / tuning target** (not yet confirmed).

### Visual state machine per slot (confirmed)

**Locked** (rebirth prereq not met):
- ButtonBackground: dark purple `(85, 85, 127)`, gradient disabled
- Image: lock icon `rbxassetid://106159424385326`
- Claim: hidden

**Generating** (unlocked, boost in progress):
- ButtonBackground: dark purple `(85, 85, 127)`, gradient disabled
- Image: question mark `rbxassetid://122903592348067`, tweens size up/down (pulse)
- Claim: visible but grayed, text cycles `. → .. → ... → .`

**Ready** (boost generated, awaiting claim):
- ButtonBackground: boost type color + gradient enabled (see colors below)
- Image: boost type asset ID
- Claim: green gradient enabled, text "Claim", Visible=true
- ButtonBackground is also clickable to claim (for toddler UX)
- Amount label shows multiplier

### Boost type visual mappings (from maker_output.txt)
| Type | Background color | Image asset ID | Gradient keypoints |
|---|---|---|---|
| Cash | `(255, 217, 66)` | `rbxassetid://74950070306966` | `(255,253,181)` → `(255,206,92)` |
| Damage | `(255, 0, 0)` | `rbxassetid://107438473232059` | `(255,178,178)` → `(200,72,72)` |
| FireRate | `(85, 255, 0)` | `rbxassetid://111102292815002` | `(255,253,181)` → `(255,206,92)` |
| Target | `(62, 245, 255)` | `rbxassetid://129729627146129` | `(175,251,255)` → `(94,158,255)` |

Claim button always uses green gradient `KP(0.00)=(52,255,37), KP(1.00)=(97,189,143)` when active.

### BoostsDisplay HUD widget (confirmed)
- Whole `BoostsDisplay` frame hidden when no boosts are active (including the BOOSTS label).
- Individual cards (`CashBoost`, `DamageBoost`, `FirerateBoost`, `TargetBoost`) hidden when that type has no active boost.
- No reordering. Cards show/hide in place.
- **Not** part of `HUDElements` — managed independently by boost client code.
- Each card has `Amount` (TextLabel) and `Time` (TextLabel, countdown).

---

## Rebirth System

### Cap and flow (confirmed)
- **2 rebirths maximum.**
- Rebirth is **player-triggered at a wall** (wall = progression gate, not auto-fired).
- Player opens RebirthWizard → picks 1 soldier + 1 boost → **second selection is the commit** (no confirm button, no "are you sure").
- Server performs reset + grant in **one atomic Data.Get → mutate → Data.Set**.
- Leave before both selected = no-op, nothing changes.

### Rebirth wizard selections (confirmed)
- 3 rebirth soldiers available, 3 permanent boosts available.
- Each rebirth: pick 1 soldier + 1 boost. Picked options are **removed from the next rebirth's pool**.
- With cap 2: player ends with 2 of 3 soldiers and 2 of 3 permanent boosts (one of each permanently unobtainable).
- Rebirth soldiers **persist permanently** through all subsequent rebirths.
- All slots start **unselected** (dark purple `(85,85,127)`, gradient disabled, "Select" text).
- Rebirth button starts **gray**; turns green only when both a soldier AND a boost are selected.
- Cost displayed in a TextLabel named `Cost` inside RebirthWizardFrame.

### Permanent boosts from rebirth (confirmed)
All are **global** (buff all soldiers), **multiplicative** with timed boosts:
- **1.5x Damage**
- **1.5x FireRate**
- **1.33x Target** (faster spawn + more reward per kill)
- No permanent Cash boost (cash compounds too aggressively as a flat multiplier).

### Lane gates (confirmed, replaces old design)
| Lane | Unlock condition |
|---|---|
| 1–3 | Free (default) |
| 4–5 | Credits (cash purchase) |
| 6 | Credits + Rebirths ≥ 1 (prereq check + cash) |
| 7 | Credits + Rebirths ≥ 2 (prereq check + cash) |
| 8 | Commander Pass |

`UnlockRebirthLaneRing` is **deleted** — lanes 6/7 use the normal `UnlockLaneRing` with a rebirth prereq check showing "Requires Rebirth 1/2" when unmet.

### What resets on rebirth (confirmed)
- Credits → back to starting value
- Owned soldiers → wiped (except premium/Robux-purchased)
- ActiveSoldiers → cleared
- Lanes 4–6 unlocks → back to false
- ActiveTarget → back to Target1
- Boosts.Active → cleared
- **PendingCash → auto-claimed to credits BEFORE reset** (exploit prevention)

### What persists through rebirth (confirmed)
- Rebirths count + HighestRebirth
- Permanent boosts (Boosts.Permanent)
- Lane 7 unlock once earned (Slot7 stays true)
- Lane 8 unlock (commander pass, always persists)
- Boost tree slot unlocks
- Premium soldiers (Robux purchases)
- Stats (lifetime counters)
- Settings
- Transactions / AppliedPasses

### Pacing targets (confirmed, tuning targets not hard limits)
| Phase | Target duration |
|---|---|
| Act 1 (new player → forced rebirth 1) | ~15 min |
| Post-rebirth-1 catch-up sprint | 7–8 min |
| Mid game → rebirth 2 | 30–60 min |
| Endgame (post-rebirth-2) | 1–2 hr |

### Rebirth soldiers (design decision deferred)
- Single-lane only (multi-lane breaks the per-lane combat architecture).
- Fake-AoE via VFX (missile arc, explosion spread — visual only, mechanically hits own lane).
- Archetypes under consideration: machine gunner / mortar / the gang.
- **No trap soldiers** — all 3 must individually carry the post-rebirth-1 sprint.
- Exact kit not yet confirmed — not a blocker for Batch C UI/server work.

---

## Plot Tasks

### Structure (confirmed)
- Single static hardcoded battlepass-style track.
- Implemented as an ordered list of `{StatKey, Threshold, Reward, Description}` entries in `SETTINGS.TASK_DATA`.
- Counters are **cumulative and lifetime** — never reset between rebirths.
- Only persisted data needed: `PlayerData.Tasks[StatKey] = N` (number of tiers claimed).

### Tier progression (confirmed)
- One card per task category in the UI.
- After claiming a tier, the card advances to the next tier (same card, roman numeral increments: I → II → III → IV…).
- Claim button stays functional for next tier immediately after claiming — no visual indicator that a second claim is available, just stays claimable.
- Label format: `"TASK: Description of task III"` (roman numeral = current tier being shown).
- Claim button invisible until that tier's threshold is met.
- Reward is always in credits (cash).

### Categories, colors, milestones (confirmed)
| Category | StatKey | Background | Progress bar | Milestones (threshold → reward) |
|---|---|---|---|---|
| Targets Killed | TargetsKilled | `(180,220,255)` | `(140,185,225)` | 10→50, 50→250, 250→1k, 1k→5k, 5k→25k, 25k→100k, 100k→500k, 500k→2M |
| Credits Earned | CreditsEarned | `(255,245,180)` | `(225,210,140)` | 1k→50, 25k→250, 500k→1k, 10M→5k, 250M→25k, 5B→100k |
| Soldiers Purchased | SoldiersPurchased | `(190,255,200)` | `(150,210,165)` | 1→50, 5→250, 15→1k, 40→5k, 100→25k |
| Targets Upgraded | TargetsUpgraded | `(255,220,190)` | `(220,180,150)` | 1→100, 3→500, 6→2k, 10→10k |
| Lanes Unlocked | LanesUnlocked | `(220,200,255)` | `(180,160,220)` | 4→500, 5→1k, 6→5k, 7→25k |
| Rebirths | Rebirths | `(255,190,220)` | `(215,150,185)` | 1→10k, 2→50k |
| Playtime (minutes) | PlayTimeMinutes | `(230,220,255)` | `(190,178,220)` | 5→50, 15→250, 45→1k, 120→5k, 300→25k |

*Reward values are placeholders — economy tuning happens post-playtest.*

### Stats that need adding to DEFAULT_DATA (not yet in schema)
- `Stats.TargetsKilled = 0`
- `Stats.CreditsEarned = 0` (lifetime, not current balance)
- `Stats.SoldiersPurchased = 0`
- `Stats.TargetsUpgraded = 0`
- `Stats.LanesUnlocked = 0` (count of lanes purchased, not booleans)
- `Stats.PlayTimeMinutes = 0` (convert from existing PlayTimeSeconds on read, or track separately)

`Stats.Rebirths` already exists as `DEFAULT_DATA.Rebirths`.
`Tasks` table also needs adding to `DEFAULT_DATA`.

---

## HUD & UI

### Teleport wiring (confirmed)
- **Shop teleport**: get `Plot.InteractionRings.SoldierShopRing` pivot, offset toward `ShopAreaBase` center by ~6 studs, Y +5.
- **Home teleport**: average `Plot.Spawns.SoldierSpawn4` and `Plot.Spawns.SoldierSpawn5` positions, then offset `(ShopAreaBase.Position - RangeAreaBase.Position).Unit * 10` (10 studs toward shop from range), Y +5.
- Pure client-side: `HumanoidRootPart.CFrame = CFrame.new(targetPos)`. No remote needed.
- `TeleportsDisplay` is part of `HUDElements` — animates in with the rest of the HUD.

### HUD animation (confirmed)
- Replace sequential stagger (`task.wait(.2)` per element) with simultaneous tween-from-0 for all elements.
- All elements tween from `UDim2.fromScale(0,0)` to their `OriginSize` attribute at the same time.
- Applies to both open and close paths.

### HUDElements membership (confirmed)
- **IN HUDElements**: SoldiersButton, SettingsButton, CommanderPassHUD, StoreContainer, CreditsButton, CreditsText, TeleportsDisplay
- **NOT in HUDElements**: BoostsDisplay (managed independently by boost system)

---

## Key UI Instance Paths

### HUD ScreenGui
```
HUD.BoostsDisplay
  .TextLabel ("BOOSTS" label)
  .BoostList (Frame, horizontal UIListLayout)
    .CashBoost / .DamageBoost / .FirerateBoost / .TargetBoost
      .Image (ImageLabel)
      .Amount (TextLabel)
      .Time (TextLabel)
HUD.TeleportsDisplay
  .Home (Frame) → .Button (TextButton)
  .Shop (Frame) → .Button (TextButton)
```

### Frames ScreenGui
```
Frames.BoostTreeFrame
  .MainFrame, .LabelBar, .Close
  .Slots (Folder)
    .Slot1 / .Slot2 / .Slot3
      .Time (TextLabel — countdown or "Rebirth N" when locked)
      .ButtonBackground (TextButton — main slot button, also claims when ready)
      .Claim (TextButton — Visible=false until ready)
      .Amount (TextLabel — Visible=false until ready)

Frames.RebirthWizardFrame
  .MainFrame, .LabelBar, .Close
  .Soldiers (Folder)
    .Slot1 / .Slot2 / .Slot3
      .ButtonBackground (TextButton)
      .Select (TextButton — starts gray, green gradient when selected)
  .Boosts (Folder)
    .DamageBoost / .FirerateBoost / .TargetBoost
      .ButtonBackground (TextButton)
      .Amount (TextLabel)
      .Select (TextButton — starts gray, green gradient when selected)
  .Rebirth (TextButton — starts gray, green when both selections made)
  .Cost (TextLabel — shows rebirth cost)
  .Hint (TextLabels × 3)

Frames.PlotTasksFrame
  .ScrollingFrame
    .Template (Frame — clone per task)
      .MainFrame
        .ProgressionTile (Frame — background strip, no fill indicator yet)
        .Label (TextLabel — "TASK: Description I")
        .ProgressNumber (TextLabel — "0 / 0")
      .Claim (TextButton — Visible=false until threshold met)
  .Label ("PLOT TASKS" title)
  .LabelBackground
  .Close
```

### Workspace (from maker_workspace_output.txt)
```
workspace.Plots.PlotN.InteractionRings.SoldierShopRing  -- pivot for shop teleport
workspace.Plots.PlotN.Spawns.SoldierSpawn4              -- home teleport lane midpoint
workspace.Plots.PlotN.Spawns.SoldierSpawn5              -- home teleport lane midpoint
workspace.Plots.PlotN.ShopAreaBase                      -- shop floor reference part
workspace.Plots.PlotN.RangeAreaBase                     -- firing range floor reference part
```

---

## Deferred / Not Yet Confirmed
- Boost tree generation times (10/15/20 min was suggested, not ratified)
- Rebirth soldier kit details (open design decision, not a blocker)
- Economy tuning spreadsheet (post-playtest)
- Boost obbies (deferred to later update)
- Playtime gifts + per-player loot crates (trivial, after tasks)
- Commander Pass re-activation (parked)
