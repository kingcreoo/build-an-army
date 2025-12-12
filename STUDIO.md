=== WORKSPACE ===
Baseplate [Part]
  » Pos: 0.0, -8.0, 0.0
  » Size: 2048.0, 16.0, 2048.0
  Texture [Texture]
Terrain [Terrain]
  » Pos: 0.0, 0.0, 0.0
  » Size: 2044.0, 252.0, 2044.0
Camera [Camera]
Limbo [Model]
  Part [Part]
    » Pos: 134.0, 151.5, 189.0
    » Size: 1.0, 11.0, 10.0
  Part [Part]
    » Pos: 134.0, 145.5, 183.5
    » Size: 12.0, 1.0, 12.0
  Part [Part]
    » Pos: 139.5, 151.5, 183.5
    » Size: 1.0, 11.0, 12.0
  Part [Part]
    » Pos: 134.0, 157.5, 183.5
    » Size: 12.0, 1.0, 12.0
  Part [Part]
    » Pos: 128.5, 151.5, 183.5
    » Size: 1.0, 11.0, 12.0
  Part [Part]
    » Pos: 134.0, 151.5, 178.0
    » Size: 1.0, 11.0, 10.0
  Spawn [SpawnLocation]
    » Pos: 134.0, 147.5, 183.5
    » Size: 10.0, 1.0, 10.0
Anchors [Folder]
  Anchor1 [Part]
    » Pos: 74.0, 0.5, -151.0
    » Size: 4.0, 1.0, 4.0
  Anchor5 [Part]
    » Pos: -252.0, 0.5, -151.0
    » Size: 4.0, 1.0, 4.0
  Anchor2 [Part]
    » Pos: 74.0, 0.5, 326.0
    » Size: 4.0, 1.0, 4.0
  Anchor3 [Part]
    » Pos: -252.0, 0.5, 326.0
    » Size: 4.0, 1.0, 4.0
  Anchor4 [Part]
    » Pos: -252.0, 0.5, 70.0
    » Size: 4.0, 1.0, 4.0
  Anchor6 [Part]
    » Pos: 74.0, 0.5, 70.0
    » Size: 4.0, 1.0, 4.0

=== REPLICATED STORAGE ===
Settings [ModuleScript]
PlotTemplate [Model]
  Base [Part]
    » Pos: 153.0, 0.5, 38.0
    » Size: 100.0, 1.0, 100.0
  SoldierSlots [Folder]
    Slot1 [Part]
      » Pos: 137.0, 1.5, 4.0
      » Size: 6.0, 1.0, 6.0
    Slot2 [Part]
      » Pos: 137.0, 1.5, 22.0
      » Size: 6.0, 1.0, 6.0
    Slot3 [Part]
      » Pos: 137.0, 1.5, 40.0
      » Size: 6.0, 1.0, 6.0
    Slot4 [Part]
      » Pos: 137.0, 1.5, 58.0
      » Size: 6.0, 1.0, 6.0
    Slot5 [Part]
      » Pos: 137.0, 1.5, 76.0
      » Size: 6.0, 1.0, 6.0
  TargetSlots [Folder]
    Slot1 [Part]
      » Pos: 192.0, 1.5, 4.0
      » Size: 6.0, 1.0, 6.0
    Slot2 [Part]
      » Pos: 192.0, 1.5, 22.0
      » Size: 6.0, 1.0, 6.0
    Slot3 [Part]
      » Pos: 192.0, 1.5, 40.0
      » Size: 6.0, 1.0, 6.0
    Slot4 [Part]
      » Pos: 192.0, 1.5, 58.0
      » Size: 6.0, 1.0, 6.0
    Slot5 [Part]
      » Pos: 192.0, 1.5, 76.0
      » Size: 6.0, 1.0, 6.0
  Spawn [Part]
    » Pos: 110.0, 1.5, 81.0
    » Size: 8.0, 1.0, 8.0
  Collect [Part]
    » Pos: 128.0, 1.5, 32.0
    » Size: 4.0, 1.0, 8.0
    GUI [BillboardGui]
  Manage [Part]
    » Pos: 128.0, 1.5, 44.0
    » Size: 4.0, 1.0, 8.0
Types [Folder]
  Explosions [Folder]
    StandardExplosion [Part]
      » Pos: -112.1, 7.1, -317.5
      » Size: 4.0, 1.0, 4.3
  Bullets [Folder]
    SmallBullet [Part]
      » Pos: -80.0, 0.2, -314.5
      » Size: 1.5, 0.4, 0.5
  Soldiers [Folder]
    Default [Model]
  Targets [Folder]
    Default [Model]
  Weapons [Folder]
    M4 [Model]
Remotes [Folder]
  OpenStoreBindable [BindableEvent]

=== STARTER GUI ===
HUD [ScreenGui]
  Soldiers [TextButton]
  Store [TextButton]
  Settings [TextButton]
  CreditsButton [TextButton]
  CreditsText [TextLabel]
  AdContainer [Frame]
Frames [ScreenGui]
  StoreFrame [Frame]
    Buttons [Folder]
      Credits [TextButton]
      Soldiers [TextButton]
      Passes [TextButton]
    Panes [Folder]
      CreditsPane [Frame]
        Close [TextButton]
      SoldierPane [Frame]
        Close [TextButton]
        LabelBar [Frame]
          ScrollingFrame [ScrollingFrame]
            Template [Frame]
      PassesPane [Frame]
        Close [TextButton]
  SoldierShop [Frame]
  SoldierInventory [Frame]
  SettingsFrame [Frame]
  UpgradeTargetFrame [Frame]
  SellSoldiersFrame [Frame]
  UnlockSlotFrame [Frame]
  IdleRewardsFrame [Frame]
  NotificationFrame [Frame]