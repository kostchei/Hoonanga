# Milestone 4: Convoys — Implementation Plan

**Status:** Implemented — automated validation complete
**Milestone:** 4 — Convoys  
**Source of truth:** `docs/GAME_DESIGN_DOCUMENT.md`  
**Exit condition:** Each convoy composition can complete the same seeded run through a distinct but viable playstyle.

## Implementation record

Milestone 4 was implemented against baseline commit `838b2c2`. The runtime now
uses a server-owned convoy record as the unit of ownership, fuel, run progress,
control transfer, and final elimination.

| Checkpoint | Result | Automated evidence |
|---|---|---|
| 0 — Integration boundary | Complete | All Milestone 1–3 Studio regressions pass; pinned direct tool binaries execute |
| 1 — Convoy model | Complete | `convoy_composition_test`, `control_transfer_test` |
| 2 — Vehicle classes | Complete | `convoy_composition_test`, `convoy_seed_balance_test` |
| 3 — Control transfer | Complete | `control_transfer_test`, end-to-end smoke test |
| 4 — Operator loss | Complete | `control_transfer_test`, end-to-end smoke test |
| 5 — Formation AI | Complete | `companion_formation_test`, road coverage/curve/recycle tests |
| 6 — Companion combat | Complete | `companion_combat_test`, combat regression test |
| 7 — Shared resources | Complete | `shared_fuel_test`, `convoy_failure_test` |
| 8 — Cross-system lifecycle | Complete | combat, recycle, transfer, and failure gates |
| 9 — Client feedback | Complete | explicit controlled-vehicle lookup, convoy HUD, transfer feedback, class selector |
| 10 — Balance validation | Complete (automated baseline) | fixed seed `4404`, fuel-duration class gate, twelve-vehicle stress gate |

The automated suite covers all three compositions, same- and cross-convoy
hostility, partial and final loss, operator loss with intact hull, shared fuel,
zero-fuel recovery, deterministic repair routing, formation outputs on the
curved road path, validated companion ammunition use, and twelve simultaneous
vehicles. A subjective first-person camera/handling playtest remains advisable
before release, but it is not an unimplemented code checkpoint.

### Delivered defaults

- Class selection: `F1` roadtrain, `F2` two utes, `F3` three bikes.
- Automatic transfer only; voluntary transfer remains deferred.
- Shared convoy fuel; per-vehicle hull, operator, weapons, and ammunition.
- Roadtrain: highest durability and ram authority, lowest speed, protected operator.
- Utes: balanced two-member redundancy.
- Bikes: fastest three-member composition, lowest durability and exposed riders.
- Shared-fuel full-demand baselines are held to approximately four to six minutes.
- Wrecks remain briefly as physical scenery and are removed on a bounded timer.

---

## 1. Scope

Milestone 4 introduces three player convoy compositions:

- One roadtrain
- Two utes
- Three bikes

It also introduces:

- Convoy membership and lifecycle
- Companion formation AI
- Companion combat AI
- Automatic control transfer after vehicle or operator loss
- Shared convoy fuel and convoy-aware pickups
- Convoy status UI
- An initial class balance pass

The milestone is complete only when losing one vehicle no longer necessarily ends
the run and all three compositions can survive the same deterministic road seed.

### Out of scope

Unless required to support the Milestone 4 exit condition, do not include:

- Multiplayer session completion
- Persistent progression or mastery
- Full garage UX
- Cosmetic persistence
- Voluntary control transfer
- Recovery of destroyed vehicles
- Detailed subsystem damage
- Full NPC convoy archetype production
- Final vehicle art

---

## 2. Current architecture assessment

The existing runtime is based on a one-player/one-vehicle model:

- `VehicleService` maps each player to one vehicle.
- `CombatService` treats vehicle or operator loss as run loss.
- `FuelService` stores fuel on individual vehicles.
- `AIService` controls one global enemy ute.
- `VehicleBuilder` only creates utes.
- `VehicleLocator` finds any surviving vehicle owned by a player.
- The HUD and run-result UI read state from one vehicle.

Spawning additional vehicles without first changing these ownership and lifecycle
assumptions would create ambiguous client control, premature run endings, duplicated
fuel pools, and incorrect targeting.

---

## 3. Architectural decisions

These decisions should be treated as Milestone 4 defaults:

1. A convoy is a server-owned gameplay entity with a stable `ConvoyId`.
2. Convoy ownership, faction, and active player control are separate concepts.
3. Vehicles keep individual hull, operator health, weapon state, and ammunition.
4. Fuel is stored once on the convoy and consumed by all operational members.
5. Repairs apply to the most damaged surviving vehicle.
6. Ammunition remains per vehicle unless the design explicitly changes it.
7. Automatic transfer occurs after loss; voluntary transfer remains deferred.
8. Friendly weapon immunity is based on `ConvoyId`, not the broad `Team` value.
9. Physical collisions between friendly convoy vehicles may still cause damage.
10. A run ends only when the convoy has no operational vehicle/operator pair or
    cannot recover from zero fuel within the recovery window.

### Naming decision

Use one canonical set of class identifiers throughout configuration, attributes,
tests, and UI:

- `Roadtrain`
- `Ute`
- `Bike`

Avoid mixing `Bike` and `Biker` as vehicle class IDs.

---

## 4. Checkpoint plan

Each checkpoint must pass its listed completion gate before work begins on the next
checkpoint. Regression tests from earlier milestones remain mandatory throughout.

### Checkpoint 0 — Stabilize the integration boundary

**Goal:** Establish a clean baseline and prevent convoy work from conflicting with
session, garage, progression, or environmental work.

#### Work

- [ ] Review and reconcile any concurrent changes touching:
  - `VehicleService`
  - `VehicleConfig`
  - `RemoteService`
  - `SessionService`
  - Player spawning
- [ ] Confirm service startup order and dependency direction.
- [ ] Restore the pinned Rokit toolchain so `stylua`, `selene`, and `rojo` run.
- [ ] Run the existing smoke, combat, road, seed, recycle, and concurrent-vehicle tests.
- [ ] Record the known-good baseline commit.

#### Completion gate

- [ ] Existing tests pass without convoy code.
- [ ] Formatting, lint, and Rojo build commands execute successfully.
- [ ] No unresolved ownership exists over files Milestone 4 must change.

---

### Checkpoint 1 — Convoy data model and service

**Goal:** Make the convoy, rather than the vehicle, the unit of run ownership.

#### Work

- [ ] Add `src/shared/Config/ConvoyConfig.luau`.
- [ ] Define composition records for one roadtrain, two utes, and three bikes.
- [ ] Add `src/server/Services/ConvoyService.luau`.
- [ ] Create a server registry for:
  - Convoy ID
  - Owner player or NPC controller
  - Faction/team
  - Convoy class
  - Member vehicles
  - Formation slots
  - Controlled vehicle
  - Shared fuel and capacity
  - Active, stranded, and eliminated state
- [ ] Add convoy membership attributes to every spawned vehicle.
- [ ] Add explicit APIs for creating, querying, and removing convoys.
- [ ] Add signals or callbacks for member loss, control change, and convoy elimination.

#### Recommended vehicle attributes

```text
ConvoyId
ConvoyOwnerUserId
Faction
FormationSlot
ControlledByUserId
Operational
```

`OwnerUserId` should not simultaneously mean convoy owner, active driver, faction,
and kill-credit recipient.

#### Completion gate

- [ ] A test can create all three compositions as logical convoy records.
- [ ] Membership is unique and queryable in both directions.
- [ ] Removing one member does not remove the convoy.
- [ ] Removing the final operational member marks the convoy eliminated exactly once.

---

### Checkpoint 2 — Data-driven vehicle classes and builders

**Goal:** Create physically distinct roadtrain, ute, and bike vehicles from shared
configuration.

#### Work

- [ ] Extend `VehicleConfig` with:
  - Contact/wheel positions
  - Mass and centre-of-mass data
  - Dimensions
  - Hull and operator health
  - Personnel protection
  - Fuel-consumption multiplier
  - Collision/ram multipliers
  - Camera placement and traverse limits
  - Weapon muzzle placement
- [ ] Remove ute-specific suspension/contact constants from shared physics.
- [ ] Refactor common setup out of `VehicleBuilder.CreateUte`.
- [ ] Add roadtrain and bike builders.
- [ ] Give every class valid hull, personnel, camera, muzzle, seat, and physics parts.
- [ ] Add stylized bike lean without requiring an unstable fully physical balance model.
- [ ] Spawn compositions with safe deterministic spacing.

#### Completion gate

- [ ] Every class spawns unanchored with valid suspension contacts.
- [ ] Every class can accelerate, brake, steer, reverse, and recover on asphalt.
- [ ] Every class exposes required camera, weapon, hull, and personnel interfaces.
- [ ] Two-ute and three-bike compositions spawn without immediate collisions.
- [ ] Existing ute handling remains within its current regression tolerances.

---

### Checkpoint 3 — Controlled vehicle ownership and transfer

**Goal:** Transfer player control to a surviving companion without ending the run.

#### Work

- [ ] Replace ambiguous player vehicle lookup with an explicit controlled-vehicle lookup.
- [ ] Route driving and weapon remotes through the convoy’s controlled vehicle.
- [ ] Separate physical vehicle destruction from player/convoy elimination.
- [ ] On transfer:
  - Stop input to the previous vehicle.
  - Clear old network ownership.
  - Detach the character from the previous seat.
  - Choose the best operational companion deterministically.
  - Seat or bind the character to the replacement.
  - Grant network ownership to the player.
  - Reset movement validation and physics input state.
  - Update replicated controlled-vehicle state.
- [ ] Prevent character respawn while a valid companion remains.
- [ ] Preserve the destroyed or abandoned vehicle as a bounded wreck.
- [ ] End the run only after final convoy elimination.

#### Transfer selection

Start with a deterministic score using:

1. Operational vehicle and living operator
2. Safe/valid road position
3. Distance from the previous controlled vehicle
4. Remaining hull
5. Stable formation-slot order as a tie-breaker

#### Completion gate

- [ ] Transfer completes within approximately two seconds.
- [ ] Driving, camera, and weapons operate from the replacement vehicle.
- [ ] The old vehicle cannot continue receiving player input.
- [ ] Destroying a companion during transfer cannot create double control or a stuck run.
- [ ] Losing the final member produces one run-ending event.

---

### Checkpoint 4 — Operator-loss behavior

**Goal:** Make personnel damage respect convoy and vehicle class rules.

#### Work

- [ ] Treat operator health separately from hull destruction.
- [ ] A dead ute operator leaves the ute uncontrolled.
- [ ] A dead bike rider makes the bike fall, coast, or safely lose control.
- [ ] A roadtrain operator is protected except through valid exposed hit regions.
- [ ] Trigger player transfer when the controlled operator is lost.
- [ ] Stop companion AI when its operator is no longer valid.
- [ ] Preserve appropriate kill credit for personnel and vehicle losses.

#### Completion gate

- [ ] Personnel loss does not incorrectly set full hull to zero.
- [ ] Pistol behavior remains ineffective against ordinary protected hull.
- [ ] Operator loss transfers control when another member survives.
- [ ] A convoy with vehicles but no valid operators is eliminated.

---

### Checkpoint 5 — Companion formation AI

**Goal:** Keep companions on the road in useful, readable formations.

#### Work

- [ ] Replace the singleton AI state with per-vehicle controller state.
- [ ] Define one shared logical control output for player and AI driving.
- [ ] Publish usable road width or formation capacity from each road chunk.
- [ ] Add formation targets:
  - Rear left
  - Rear right
  - Side escort
  - Single file
- [ ] Compress formation in canyons, highways, forks, and other narrow sections.
- [ ] Add forward obstacle checks and lateral clearance checks.
- [ ] Add hazard cost or avoidance for lethal edges, hard boundaries, mud, and oil.
- [ ] Add bounded catch-up acceleration when separated.
- [ ] Reduce companion collision interference only while legitimately catching up.
- [ ] Ensure companions follow the selected fork.

#### Completion gate

- [ ] Two utes and three bikes traverse every road family without routine separation.
- [ ] Companions do not routinely hit the leader or one another.
- [ ] Companions do not routinely fall from raised highways.
- [ ] Formation compresses before entering narrow chunks.
- [ ] Catch-up assistance does not exceed server movement validation limits.

---

### Checkpoint 6 — Companion combat AI

**Goal:** Make companions helpful without allowing them to dominate encounters.

#### Work

- [ ] Score hostile targets using distance, aim angle, exposure, health, and weapon suitability.
- [ ] Reject targets with the same `ConvoyId`.
- [ ] Use the existing weapon validation and ammunition systems.
- [ ] Add configurable reaction time, aim error, and burst behavior.
- [ ] Avoid blocking the player’s firing line where practical.
- [ ] Prioritize driving safety over firing.
- [ ] Generalize the existing enemy AI so it can target convoy members correctly.
- [ ] Respect per-chunk active-enemy limits if encounter spawning is introduced.

#### Completion gate

- [ ] Companions never intentionally fire on their own convoy.
- [ ] Companion fire consumes ammunition and respects weapon timing.
- [ ] Companions contribute measurably without routinely winning encounters alone.
- [ ] Target selection remains stable as the controlled vehicle changes.
- [ ] Combat does not override hazard avoidance in narrow or lethal chunks.

---

### Checkpoint 7 — Shared convoy resources

**Goal:** Make fuel and recovery decisions operate at convoy level.

#### Work

- [ ] Move `Fuel` and `MaxFuel` to convoy state.
- [ ] Aggregate consumption from every operational member using:
  - Idle use
  - Throttle demand
  - Speed/load
  - Vehicle-class multiplier
  - Terrain multiplier
  - Damage penalty when implemented
- [ ] Replicate the shared fuel state for the HUD.
- [ ] Mark every convoy engine out of fuel when the pool reaches zero.
- [ ] Apply one convoy-level recovery window.
- [ ] Allow any member to collect a fuel pickup for the convoy.
- [ ] End the run only if fuel is not restored within the recovery window.
- [ ] Route repair pickups to the most damaged surviving vehicle.
- [ ] Keep ammunition per vehicle unless a later design decision changes it.

#### Completion gate

- [ ] Fuel consumption increases correctly with active convoy members.
- [ ] One member collecting fuel restores movement for the convoy.
- [ ] Destroyed members stop contributing fuel consumption.
- [ ] Repair selection is deterministic and never resurrects a wreck.
- [ ] Each fresh composition reaches the four-to-six-minute initial fuel target after tuning.

---

### Checkpoint 8 — Convoy-aware combat, scoring, and road lifecycle

**Goal:** Correct cross-system assumptions that become visible with multiple vehicles.

#### Work

- [ ] Base friendly weapon immunity on convoy identity.
- [ ] Keep physical friendly collisions damaging.
- [ ] Award kills and assists to the correct convoy owner.
- [ ] Ensure projectiles, fire, and collision damage handle convoy members consistently.
- [ ] Count all operational vehicles for road occupancy.
- [ ] Keep enough chunks behind the rearmost operational convoy member.
- [ ] Retire wrecks and their effects safely with road chunks or a bounded cleanup policy.
- [ ] Calculate run distance from convoy progress rather than a stale destroyed vehicle.

#### Completion gate

- [ ] One slow companion cannot have its road chunk recycled underneath it.
- [ ] Destroyed wrecks do not hold road chunks forever.
- [ ] Same-convoy weapons do no damage.
- [ ] Different hostile convoys can damage one another regardless of broad faction labels.
- [ ] Transfer does not reset distance or kill statistics.

---

### Checkpoint 9 — Client UI and feedback

**Goal:** Make convoy state and transfer understandable to the player.

#### Work

- [ ] Make `VehicleLocator` return only the explicitly controlled vehicle.
- [ ] Update camera, driving, and weapon controllers when control changes.
- [ ] Add shared convoy fuel to the HUD.
- [ ] Add one compact status item per convoy member:
  - Healthy
  - Damaged
  - Burning
  - Bogged
  - Operator lost
  - Destroyed
  - Currently controlled
- [ ] Add a short control-transfer transition and clear feedback.
- [ ] Make the run-result UI listen for convoy elimination.
- [ ] Provide a minimal class-selection route for testing all compositions.

#### Completion gate

- [ ] The HUD never displays a companion as the controlled vehicle incorrectly.
- [ ] Transfer changes camera and HUD without requiring character respawn.
- [ ] Partial convoy loss does not display the run-result screen.
- [ ] Final elimination displays one accurate result.
- [ ] All three compositions can be selected in a test or pre-run flow.

---

### Checkpoint 10 — Class balance and exit validation

**Goal:** Demonstrate distinct but viable playstyles on identical content.

#### Work

- [ ] Select a fixed representative road seed.
- [ ] Run repeated trials for each class on that seed.
- [ ] Record:
  - Completion distance/time
  - Fuel consumed per minute
  - Damage dealt and received
  - Vehicles and operators lost
  - Control-transfer count
  - Companion stuck/recovery count
  - Terrain deaths
  - Weapon contribution
- [ ] Tune roadtrain armor, mass, fuel, acceleration, and turning radius.
- [ ] Tune ute redundancy and generalist performance.
- [ ] Tune bike speed, evasion, exposure, and instability.
- [ ] Run a twelve-vehicle server stress scenario.
- [ ] Complete manual first-person playtests for camera comfort and transfer clarity.

#### Completion gate

- [ ] Roadtrain, ute, and bike convoys complete the same seed in repeated trials.
- [ ] Each class has a recognizably different successful strategy.
- [ ] No class is universally best across every road family.
- [ ] Companion AI does not create routine run-ending failures.
- [ ] No severe errors accumulate during repeated or soak tests.
- [ ] Milestone 1–3 regression tests still pass.

---

## 5. Planned test additions

Recommended test scripts:

```text
scripts/convoy_composition_test.luau
scripts/control_transfer_test.luau
scripts/shared_fuel_test.luau
scripts/companion_formation_test.luau
scripts/companion_combat_test.luau
scripts/convoy_failure_test.luau
scripts/convoy_seed_balance_test.luau
scripts/convoy_stress_test.luau
```

Important failure cases:

- Controlled vehicle destroyed while a companion survives
- Controlled operator killed with full hull remaining
- Companion destroyed during the transfer delay
- Two vehicles attempting to become player-controlled
- Fuel pickup collected during the zero-fuel recovery window
- Repair pickup touched while one member is destroyed and another is damaged
- Companion separated at a fork
- Companion stuck behind the chunk-recycling boundary
- Last member destroyed while projectiles or fire remain active
- Player disconnect during control transfer

---

## 6. Regression and quality gates

Run at every checkpoint:

```bash
stylua --check src
selene src
rojo build default.project.json --output build/Hoonanga.rbxlx
```

Retain all existing Studio test gates documented in `README.md`. New convoy tests
should use the same headless Studio runner and explicit `PASS` output convention.

No checkpoint is complete when:

- Strict type or lint errors remain
- A prior milestone test regresses
- Server authority is bypassed
- A client can select or damage an arbitrary vehicle
- Control ownership is ambiguous
- A run can end twice
- A road chunk can be removed beneath an operational vehicle

---

## 7. Milestone completion checklist

- [ ] One-roadtrain composition is playable.
- [ ] Two-ute composition is playable.
- [ ] Three-bike composition is playable.
- [ ] Companion formation AI works across every road family.
- [ ] Companion combat AI uses server-validated weapons.
- [ ] Control transfers after vehicle and operator loss.
- [ ] Shared convoy fuel and recovery behavior work.
- [ ] Convoy-aware repairs work.
- [ ] HUD communicates every member’s state.
- [ ] Run ending is based on convoy elimination or stranding.
- [ ] All compositions complete the same fixed seed.
- [ ] Class balance produces distinct, viable playstyles.
- [ ] Twelve-vehicle stress test is stable.
- [ ] Existing milestone tests pass.
- [ ] No severe Studio output errors accumulate during soak testing.

---

## 8. Open decisions requiring design confirmation

These decisions should be recorded before their affected checkpoint begins:

1. Is voluntary control transfer still deferred?
2. Is ammunition per vehicle or shared by the convoy?
3. Does a roadtrain have one primary weapon station or multiple destructible stations?
4. Can a fully bogged vehicle be towed, or does companion AI only defend it?
5. How long should wrecks remain before cleanup?
6. What exact class-selection mechanism is used before the full garage is available?
7. Does an operator kill and later hull destruction award one score event or two?

Until changed, this plan assumes forced transfer only, per-vehicle ammunition, one
roadtrain weapon station, no towing, bounded wreck cleanup, a test-facing class
selector, and separate personnel/vehicle telemetry without double-counting a kill.
