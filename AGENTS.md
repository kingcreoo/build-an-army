# AGENTS.md

Guidance for AI agents working in this repo.

## Conventions

- PascalCase for variables/functions, ALLCAPS for module references
- Short clear comment above every function and critical block
- Reusable functions over deep nesting
- Always use PascalCase
- Soldiers ONLY fire at the target in their lane
- Keep responses short and concise

## Project Structure

- `ReplicatedFirst/` — Load screen (currently empty)
- `ReplicatedStorage/init.luau` — SETTINGS module. Single source of truth for ALL game data
- `ServerScriptService/` — Server scripts (combat loop, data, plots, transactions)
- `StarterPlayerScripts/` — Client scripts + UI
- `NOTES.md` — Scratchpad, free to use
- All remotes live in `ReplicatedStorage.Remotes`

## References

- **README.md** — Game concept + feature outline (future tense)
- **TODO.md** — Task outlines. Located at `/home/creoo/Brain/build an army/TODO.md`
- **Economy spreadsheet** — `/home/creoo/Downloads/build_an_army_economy_v6.xlsx` (6 sheets). Source of truth for economy numbers, but code values override where intentionally changed (e.g. cash pack prices are 29/59/109 R$ in code, not spreadsheet's 49/149/399)

## Studio Hierarchy

No static file. Collin pastes hierarchy dumps as needed. Don't assume GUI paths — ask or wait for a dump.

## Read-Only Directories

- **Brain** (`/home/creoo/Brain`) — Obsidian vault. NEVER edit.
- **shoot-the-enemy** — Old project, can read/copy from. NEVER edit.

## Testing

- TestEZ for luau testing: https://roblox.github.io/testez/
- Collin tests in Roblox Studio. AI cannot test directly — always wait for test results before committing.

## Working State

### Uncommitted Changes (all untested)
**Modified:** init.luau (SETTINGS), Data.luau, IdleRewards.luau, init.server.luau, PlotVisualizer.luau, RobuxStore.client.luau, SoldierShop.client.luau
**New files:** TransactionManager.luau, ProductConfig.luau, TransactionClient.luau, NOTES.md

### What Works
- Combat loop, data persistence, plots, soldier shop + stock rotation
- Inventory, selling, target upgrades, slot unlocks, idle rewards
- Damage hitmarkers, sound system, AutoEquip
- Economy data fully pushed (14 soldiers, 7 targets, all config tables)

### What's Built but Untested
- TransactionManager (Robux handler) — config-driven, idempotent, security-first
- ProductConfig — 19 entries, all Id=0 (need real IDs from Creator Dashboard)
- TransactionClient — client button-binding helper
- RobuxStore refactor — fade transitions, new nav button structure

### Blockers
- **RobuxStore GUI**: Script expects specific hierarchy (Buttons.Cash Frame > Button, Panes folder, etc). Need Collin to update Studio and paste hierarchy dump.
- **Product IDs**: All 0. Need Collin to create dev products/gamepasses in Creator Dashboard.
- **Testing**: Everything uncommitted needs Studio testing before commit.

### Known Design Decisions (don't "fix" these)
- Shotgun = visual-pellet, server-slug. Pellets field is cosmetic only. Intentional.
- 100M starting credits = testing value. Intentional.
- Commander Pass scaffolded but NOT implemented. Don't add features without explicit instruction.
- PREMIUM_BOOSTS table exists but nothing reads it yet. Don't wire it without instruction.
- No EffMult field in code — handled structurally via WeaponType branching.

### Flow
1. AI writes/fixes code
2. Collin tests in Studio
3. If it works, commit
4. Repeat
