# Asset credits

## Machine Gun Turret

- Creator: Etruscis
- Creator Store asset: [Machine Gun Turret](https://create.roblox.com/store/asset/2046384884/Machine-Gun-Turret)
- Asset ID: `2046384884`
- Use: Static visual model for the ute-mounted turret
- Safety: The Creator Store listing reports that the model contains no scripts. Hoonanga
  also removes any executable descendants after loading it and supplies all firing logic
  from the game's own server code.

If Roblox denies access to the external asset, the game substitutes a locally constructed
low-detail turret so that combat remains functional.

## Pickup Truck

- Creator Store asset: [Pickup Truck](https://create.roblox.com/store/asset/6418225759/Pickup-Truck)
- Asset ID: `6418225759`
- Use: Script-free body and interior visual variants for the ute class
- Safety: Hoonanga removes every executable descendant, networking object, and
  unsafe constraint before retaining the audited visual shell. All driving,
  damage, input, and weapon behavior comes from repository-owned code.

If Roblox denies access to the external asset, the game uses its locally
constructed low-detail vehicle body so gameplay remains functional.

## Pickup reference artwork

- Source: Project-owner supplied `ammobox-mini-ink-512x341.png` and
  `plasitc-jerrycan-mini-ink-359x512.png`
- Use: Visual reference for the repository-owned ammunition-crate and fuel-can
  geometry.
- Texture status: Geometry is live. Optional decal hooks are configured in
  `PickupArtConfig.luau`; the PNGs require Roblox asset IDs before they can be
  included in a published place.

## Roadtrain reference photography

- Source: Five project-owner supplied photographs showing left/right side,
  front, rear, and overhead views of an armored eight-wheel miniature.
- Use: Orthographic modeling reference for repository-owned Roadtrain geometry.
- Texture status: The photographs are not UV-ready maps and local JPG paths
  cannot ship in Roblox. Optional per-view decal hooks are configured in
  `RoadtrainArtConfig.luau` for cleaned images after Roblox upload.
