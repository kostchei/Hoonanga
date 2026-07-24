# Creator Store Pickup Audit

## Asset

- Name: `Pickup Truck`
- Creator: Roblox
- Asset ID: `6418225759`
- Source: <https://create.roblox.com/store/asset/6418225759/Pickup-Truck>
- Audited in Roblox Studio: 2026-07-25

## Contents

The asset contains three complete colour variants:

- `Pickup Truck (blue)`
- `Pickup Truck (bronze)`
- `Pickup Truck (white)`

Each variant contains a visual `Body`, a physical `Chassis`, suspension and steering
constraints, effects, seats, remotes, prompts, user interface objects, and its own copy
of the vehicle code.

The Creator Store listing reports 12 scripts. That count covers the three server
Scripts and nine LocalScripts. A full Studio inspection also found 30 ModuleScripts,
for 42 `LuaSourceContainer` instances across the three variants.

## Script review

The three variants contain identical copies of these 14 code containers:

- `Vehicle` starts the vehicle package, manages occupants, inserts driver/passenger
  controls into `PlayerGui`, changes character visibility, and transfers network
  ownership to the driver.
- `Chassis` configures the cylindrical motors, springs, steering constraint, wheel
  friction, torque, braking, speed limiting, and vehicle-righting constraints.
- `Driver` captures keyboard, controller, and touch input and continuously updates the
  wheel motors and steering.
- `Effects` runs engine audio, tyre trails, and related effects.
- `VehicleSeating` and `LocalVehicleSeating` implement entry, exit, carjacking,
  proximity prompts, door animation, and anti-trip behaviour.
- `Passenger` supplies passenger exit controls.
- `LocalVehiclePromptGui` and `LocalVehicleGui` create the entry prompts, touch
  controls, and speedometer.
- `Keymap`, `InputImageLibrary`, `Spritesheet`, `XboxOne.Dark`, and `XboxOne.Light`
  provide input mappings and controller artwork.

No numeric `require()` calls, `loadstring`, external HTTP requests, datastores,
teleports, webhooks, or asset-loader backdoors were found. `HttpService` is used only
to generate a unique GUI name.

The package is legitimate, but its scripts are not compatible with Hoonanga's
controls, camera, combat, HUD, fuel, damage, or server validation. It also uses older
`wait()`, `connect()`, and legacy raycasting patterns. None of its code is retained.

## Hoonanga import policy

Hoonanga loads the asset while it is unparented, clones only the selected variant's
`Body` model, then destroys the loaded package. The retained body is sanitized before
use:

- All executable source is excluded.
- The original chassis, seats, constraints, remotes, prompts, GUI, effects, sounds,
  and vehicle logic are excluded.
- Original attachments and welds inside the visual body are removed.
- Only the exterior, cab interior, glass, doors, trim, lights, and visual wheels are
  mounted to Hoonanga's existing chassis.
- Every retained part is non-colliding, massless, and rigidly welded to Hoonanga's
  chassis.

The bronze body is used for player utes and the blue body for enemy utes. The source
asset ID, URL, and selected variant are recorded as model attributes at runtime.
