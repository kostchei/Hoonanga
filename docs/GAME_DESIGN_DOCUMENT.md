# Hoonanga

## Game Design and Technical Plan

- **Status:** Draft 0.1
- **Date:** 24 July 2026
- **Platform:** Roblox
- **Primary genre:** First-person vehicle combat / endless-road survival
- **Initial target:** Keyboard and mouse, with controller support designed alongside it

---

## 1. Executive summary

Hoonanga is a first-person vehicle-combat game about commanding a small convoy through an endless, hostile road network. The player drives and shoots from one vehicle while AI controls the remaining vehicles in the convoy. Rival convoys may be controlled by other players or by NPCs.

Each convoy uses one of three compositions:

- One roadtrain
- Two utes
- Three bikers

The road is assembled at runtime from handcrafted chunks. Raised highways, narrow canyons, mudflats, dense cactus country, termite mounds, and stony desert tracks create different handling problems and different ways to fail. Fuel, ammunition, vehicle damage, exposed personnel, and route choices create pressure throughout a run.

The intended experience is fast, physical, unpredictable, and readable. Vehicles should ram, slide, burn, become bogged, fall from elevated roads, and collide with terrain in ways that create memorable stories. The simulation supports chaos, but the controls and feedback must remain consistent enough for players to learn from mistakes.

### Locked high-level decisions

- The game is first-person while directly controlling a vehicle.
- One player owns and commands one convoy.
- AI fills all other vehicles in that convoy.
- Convoys contain one roadtrain, two utes, or three bikers.
- The road continues until the convoy is eliminated or stranded.
- Fuel is a shared convoy resource.
- Forks provide route choices but reconverge after a short distance.
- Personnel health and vehicle hull health are separate.
- The first playable uses one ute before convoy classes are implemented.

### Working assumptions

- The first public mode is PvPvE, with player and NPC convoys sharing a run.
- The initial prototype is built for desktop controls. Mobile support is evaluated after the core interaction proves viable.
- Runs target 10-20 minutes for most players, although the road system can continue beyond that.
- Progression unlocks options and cosmetics rather than permanent competitive superiority.

---

## 2. Creative direction

### 2.1 Player fantasy

The player is the leader of a desperate road crew crossing an apparently endless wasteland. Survival depends on aggressive driving, accurate shooting, sensible fuel use, and knowing when to take a dangerous route.

The fantasy is not precision motorsport. It is controlling a barely stable machine at speed while the road, the enemy, and the rest of the convoy are all trying to kill it.

### 2.2 Design pillars

#### Drive angry

Forward momentum is the default. Braking, reversing, and hiding are sometimes useful, but the game should continually pressure the convoy to move.

#### Every road tells a story

Road layouts should produce recognizable situations: a duel on a raised highway, a bottleneck in a canyon, a vehicle sinking in mud while its companions defend it, or two convoys choosing opposite sides of a fork before meeting again.

#### Physical chaos with understandable causes

Large collisions, flips, fire, falling vehicles, and chain reactions are encouraged. Players must still be able to understand why something happened through clear audio, animation, HUD feedback, and consistent rules.

#### Convoy loss is progressive

A multi-vehicle convoy should weaken one vehicle at a time. Losing the currently controlled vehicle transfers the player to a surviving vehicle rather than immediately ending the run.

#### Resource pressure creates decisions

Fuel, ammunition, repairs, and route selection should affect play without turning the game into inventory administration.

### 2.3 Non-goals

- Realistic vehicle simulation at the expense of responsiveness
- Large open-world exploration
- On-foot exploration as a major game mode
- Complex survival crafting
- Detailed crew micromanagement
- Large inventories or dozens of ammunition types
- Pay-to-win vehicle statistics
- Direct replication of another game's names, artwork, rules text, vehicles, or branding

---

## 3. Terminology

| Term | Definition |
|---|---|
| Convoy | One player- or NPC-controlled combat group. |
| Vehicle | A roadtrain, ute, or bike belonging to a convoy. |
| Operator | The driver or rider currently controlling a vehicle. |
| Companion | An AI-controlled vehicle belonging to a player's convoy. |
| Road chunk | A handcrafted modular section placed by the road generator. |
| Road family | A set of chunks sharing an environment and hazard identity. |
| Safe surface | The intended driveable route through a chunk. |
| Soft boundary | Terrain that can be entered but applies penalties, such as mud or loose stone. |
| Hard boundary | Solid collision terrain, such as canyon walls or major termite mounds. |
| Lethal boundary | A fall, crush zone, or other condition that destroys a vehicle. |
| Run | One continuous attempt that ends when the convoy is eliminated or stranded. |
| Director | Server system that selects road chunks, encounters, hazards, and rewards. |

Internally, use `Convoy` instead of `Mob` to avoid confusing the group with an individual NPC.

---

## 4. Core game loop

### 4.1 Moment-to-moment loop

1. Read the upcoming road, enemies, and available routes.
2. Steer, accelerate, brake, and manage traction.
3. Aim and fire the mounted weapon while driving.
4. Avoid, exploit, or force enemies into hazards.
5. Protect companion vehicles and attack exposed enemy vehicles.
6. Collect fuel, ammunition, repairs, and scrap.
7. Choose a route at forks.
8. Continue until the convoy is destroyed or stranded.

### 4.2 Run-level loop

1. Select a convoy class and loadout.
2. Enter a run with player and NPC convoys.
3. Travel through increasingly difficult road families.
4. Recover temporary upgrades and resources.
5. Lose vehicles, transfer control, and continue with survivors.
6. End the run through elimination, fuel loss, or voluntary extraction if that feature is later added.
7. Award scrap, mastery, cosmetics, and unlock progress.
8. Return to the garage and prepare another convoy.

### 4.3 Pressure curve

A run starts with forgiving terrain and clear sightlines. Difficulty grows through:

- More complicated road geometry
- More frequent hazards
- Stronger or more coordinated NPC convoys
- Scarcer fuel and repair opportunities
- Combined hazards, such as combat on a raised highway or fire inside a narrow canyon
- More consequential forks

Difficulty should rise in waves. A severe encounter is followed by a short recovery section so the run does not become continuously exhausting.

---

## 5. Session and game-mode structure

### 5.1 Prototype mode

The prototype is a solo run against one NPC ute. It exists to validate driving, shooting, fuel, damage, and road recycling.

### 5.2 Initial multiplayer mode: Convoy Run

- Two to four player convoys enter the same road.
- NPC convoys and environmental encounters appear during the run.
- Every convoy travels in the same general direction.
- Player convoys may fight, avoid one another, or temporarily benefit from attacking a shared threat.
- An eliminated player receives run results and may spectate remaining convoys.
- Ranking uses survival distance first, then combat and resource accomplishments as secondary measures.

The run does not require one final winner if all players are eliminated at different distances. The furthest surviving distance determines placement.

### 5.3 Potential later modes

- Cooperative expedition against NPC convoys
- Last-convoy-standing short match
- Daily seeded road with global leaderboard
- Escort mode protecting a vulnerable tanker
- Boss pursuit against a single oversized enemy vehicle

These modes are outside the first production scope.

---

## 6. Player controls and camera

### 6.1 Keyboard and mouse

| Input | Action |
|---|---|
| W / S | Throttle and brake/reverse |
| A / D | Steer |
| Mouse | Aim mounted weapon and camera within traverse limits |
| Left mouse | Fire primary weapon |
| Right mouse | Aim/focus or fire secondary weapon, depending on loadout |
| R | Reload |
| F | Use carried throwable or contextual vehicle action |
| Q / E | Look left/right or cycle valid target/vehicle context |
| C | Rear view |
| Space | Handbrake |
| Shift | Temporary boost if equipped |

Final mappings are determined through playtesting. Driving and aiming must not require the player to release either steering or camera control.

### 6.2 Controller

- Left stick controls steering and throttle/brake through a vehicle-oriented mapping.
- Right stick controls view and weapon aim.
- Triggers fire weapons.
- Shoulder buttons handle rear view, reload, and secondary equipment.

Controller aim receives configurable sensitivity and restrained assistance against personnel-sized targets.

### 6.3 First-person camera

The camera sits at a defined attachment inside or immediately above the vehicle. Each vehicle supplies:

- `CameraAttachment`
- Maximum yaw and pitch
- Camera vibration profile
- Impact kick limits
- Optional interior obstruction mask
- Rear-view position

Camera shake communicates suspension movement and impacts but must be filtered to prevent nausea. Large visual vehicle movement should not translate one-to-one into camera rotation.

### 6.4 Control transfer

When the controlled vehicle or operator is lost:

1. Time briefly slows locally or the screen enters a short impact transition.
2. `ConvoyService` selects the best surviving companion.
3. The camera moves to that vehicle.
4. Player input replaces AI input.
5. The abandoned or destroyed vehicle remains physically present.

Transfer should complete within approximately two seconds. If no controllable vehicle remains, the run ends.

---

## 7. Convoy classes

Balancing values below are starting relationships, not final numbers.

### 7.1 Roadtrain convoy

- **Composition:** One roadtrain
- **Role:** Heavy tank and ramming platform
- **Strengths:** Armor, protected operator, fuel capacity, stable weapon mount, mass
- **Weaknesses:** Wide turning radius, slow acceleration, large target, difficulty avoiding blocked routes

The roadtrain is one physical vehicle but may contain multiple damage zones. A pistol generally cannot harm its protected driver unless a window, hatch, or exposed gunner provides a valid personnel hit.

Potential equipment:

- Heavy machine gun
- Flamethrower side mount
- Front ram
- Reinforced fuel tank

### 7.2 Ute convoy

- **Composition:** Two utes
- **Role:** Flexible generalist
- **Strengths:** Balanced handling, useful redundancy, broad loadout choice
- **Weaknesses:** Neither the durability of the roadtrain nor the evasion of bikes

One ute is player-controlled and the second follows as a companion. If the first is lost, control transfers to the second.

Potential equipment:

- Machine gun
- Rocket rack
- Molotov passenger
- Repair or fuel carrier

### 7.3 Biker convoy

- **Composition:** Three bikes
- **Role:** Fast flanker and personnel hunter
- **Strengths:** Acceleration, narrow profile, route access, difficult targeting
- **Weaknesses:** Low hull durability, exposed riders, instability on rough terrain

Bikes are individually fragile. Their power comes from numbers, movement, and attack angles. A pistol is especially effective against exposed riders.

Potential equipment:

- Light machine gun
- Pistol
- Molotov
- Short burst boost

### 7.4 Balance principle

Total convoy value should be comparable:

```text
survivability
+ practical damage output
+ mobility
+ resource efficiency
+ redundancy
+ route access
= approximate convoy power
```

Equal power does not mean equal performance in every road family. The roadtrain should dominate direct canyon clashes, while bikes should perform better on narrow forks and broken routes.

---

## 8. Endless-road system

### 8.1 Design approach

The road is procedural in arrangement but handcrafted in content. Runtime code selects and connects authored chunks rather than generating arbitrary terrain geometry.

This provides:

- Reliable collision and navigation
- Deliberate combat spaces
- Recognizable environmental identity
- Predictable performance
- Easier art direction and testing

### 8.2 Chunk dimensions

Initial chunks should be approximately 384-640 studs long. Width varies by family. Long chunks may contain multiple encounter beats, but should not be so large that recycling them creates visible memory or network spikes.

Every chunk contains:

```text
ChunkModel
  StartSocket
  EndSocket
  RoadSpline
    Node01
    Node02
    ...
  SafeSurface
  SoftBoundary
  HardBoundary
  LethalZones
  HazardSockets
  EncounterSockets
  PickupSockets
  Metadata
```

Recommended metadata attributes:

- `ChunkId`
- `RoadFamily`
- `Difficulty`
- `Length`
- `EntryHeading`
- `ExitHeading`
- `AllowsFork`
- `MinSpeed`
- `MaxActiveEnemies`
- `Weight`

### 8.3 Socket rules

- `StartSocket` aligns to the previous chunk's `EndSocket`.
- Position and heading must match within a defined tolerance.
- Vertical changes remain gentle enough for vehicle suspension unless the chunk is intentionally a ramp or drop.
- Collision bounds are checked before activation.
- A chunk is never selected if its entry requirements do not match the active path.

### 8.4 Active chunk lifecycle

The server normally maintains:

- Three chunks behind the rearmost active convoy
- The occupied chunk
- Five or six chunks ahead
- Additional temporary chunks for both sides of a fork

Lifecycle states:

1. **Reserved:** Selected by the director.
2. **Placed:** Positioned and validated.
3. **Active:** Collision, hazards, encounters, and pickups enabled.
4. **Passed:** No active convoy remains inside.
5. **Retired:** NPCs and temporary objects cleaned up.
6. **Destroyed:** Model removed and memory released.

Chunks use an occupancy count so a slower convoy does not lose the road beneath it.

### 8.5 Deterministic generation

Each run receives a server seed. The director uses a deterministic random stream for:

- Road-family order
- Chunk selection
- Fork options
- Encounter composition
- Hazard placement
- Pickup placement

The seed makes debugging and daily challenge modes reproducible. Runtime player actions remain non-deterministic.

### 8.6 Road-family sequencing

A road family usually lasts four to eight chunks. The director uses transitions between families:

```text
Stony desert -> canyon approach -> narrow canyon
Mudflat edge -> mudflat path -> raised causeway
Cactus scrub -> dense fork -> stony desert
```

The same family should not repeat immediately unless required by a branch reconnection. Difficulty and visual variety both influence selection.

### 8.7 Forks

A fork creates two active paths that reconverge after two or three chunks.

Fork rules:

- Both branches advertise their identity before the decision point.
- Each route has a meaningful tradeoff.
- Neither route is secretly impossible for a valid convoy class.
- Both branches remain active while occupied.
- The abandoned branch is retired after all convoys pass the decision boundary.
- Branches reconverge into a wide, readable merge area.
- Encounter difficulty accounts for player convoys being temporarily separated.

Example tradeoffs:

- Short mud route versus longer stony route
- Exposed highway with fuel versus protected canyon without fuel
- Heavy enemy presence versus severe terrain
- Repair cache versus ammunition cache

### 8.8 Long-distance coordinate management

The MVP can use ordinary forward travel because expected runs remain short. If long runs begin reaching distances where coordinate precision affects physics:

- Rebase all active chunks, vehicles, projectiles, hazards, and pickups toward the origin.
- Perform the shift between encounter beats where possible.
- Preserve assembly velocity and road-relative progress.
- Track total run distance separately from world coordinates.

Rebasing is implemented only after profiling shows it is necessary.

---

## 9. Road families and hazards

### 9.1 Raised highway

**Identity:** Speed, exposure, narrow recovery space, lethal falls

Chunk ideas:

- Intact elevated straight
- Missing outer barrier
- Broken lane
- Wrecked tanker obstacle
- Narrow bridge
- Offset carriageway
- Ramp over a collapsed span
- Exposed fork to two levels

Failure conditions:

- Barrier collision
- Enemy ramming near an edge
- Missing road surface
- Falling into a lethal volume

Falling destroys the vehicle after a short dramatic delay. A multi-vehicle convoy continues if another vehicle survives.

### 9.2 Narrow canyon

**Identity:** Choke points, wall impacts, ambushes, limited overtaking

Chunk ideas:

- Gentle winding canyon
- Blind corner
- Fallen boulder slalom
- One-vehicle choke
- Rockfall trigger
- High ledge ambush
- Split around a stone pillar

Failure conditions:

- High-speed wall collision
- Crushing between a heavy vehicle and terrain
- Blocked escape during fire
- Falling rock impact

Canyon walls use real collision geometry. Impact damage depends on relative speed, contact direction, and vehicle mass.

### 9.3 Mudflats

**Identity:** Route reading, momentum management, progressive bogging

Chunk ideas:

- Clearly marked firm path
- Multiple faint tracks
- Deep central pool
- Dry islands connected by soft mud
- Abandoned vehicles marking a dangerous line
- Raised causeway

Failure conditions:

- Loss of grip
- Increased fuel consumption
- Progressive sinking
- Full bogging

Each wheel contributes to a vehicle's `BogLevel`. High throttle with low movement increases bogging quickly. Reaching firmer ground, easing throttle, or receiving a tow reduces it.

### 9.4 Dense cactus and termite mounds

**Identity:** Forking routes, obstructed sightlines, collision traps

Chunk ideas:

- Symmetrical fork
- False-looking but valid narrow path
- Termite-mound maze
- Dense cactus corridor
- Ambush clearing
- Rejoining S-bends

Failure conditions:

- Collision damage
- Impalement-style vehicle damage presented without gore
- Dead-end or blocked branch requiring a risky turn
- Losing sight of companions

Large mounds and dense cactus formations are hard boundaries. Smaller plants may break and apply minor damage or drag.

### 9.5 Worn track through stony desert

**Identity:** Baseline driving, speed, rough off-track terrain

Chunk ideas:

- Wide straight track
- Shallow S-bends
- Rocky wash
- Scattered boulder field
- Low ridge
- Long sightline combat arena
- Transition into another family

Failure conditions:

- Suspension instability
- Tire damage
- Loss of grip on loose stone
- Collision with boulders

This is the first prototype environment because it provides clear visual navigation and space for testing combat.

### 9.6 Cross-family hazards

- Oil slicks
- Wrecked vehicles
- Burning debris
- Fuel barrels
- Ramps and broken surfaces
- Moving enemy blockers
- Rockfalls
- Temporary fire pools

Hazards use tags and attributes so their effects are data-driven rather than embedded independently in every model.

---

## 10. Vehicle simulation and handling

### 10.1 Simulation model

The intended final controller uses raycast suspension:

1. Cast downward from each wheel point.
2. Calculate suspension compression.
3. Apply spring and damping forces.
4. Calculate longitudinal drive/brake force.
5. Calculate lateral tire grip.
6. Modify forces using the contacted surface profile.
7. Apply drag, downforce, and stability assistance.

The gray-box prototype may begin with a simpler controller, but vehicle tuning should move into shared configuration modules immediately.

### 10.2 Vehicle configuration

Each class defines:

- Mass and center of mass
- Engine force and acceleration curve
- Maximum practical speed
- Brake force
- Steering response by speed
- Wheelbase and track width
- Suspension travel, stiffness, and damping
- Lateral grip
- Drift assistance
- Roll stability
- Hull health
- Personnel protection
- Fuel consumption
- Collision multiplier

### 10.3 Handling goals

- Steering is responsive at low speed and calmer at high speed.
- Vehicles communicate grip loss before spinning.
- Handbrake turns are possible but costly.
- Light contact does not randomly launch vehicles.
- Heavy ramming remains powerful and visually dramatic.
- Bikes lean visually without requiring an unforgiving fully physical balance simulation.
- AI and player vehicles use the same basic movement model.

### 10.4 Surface profiles

Initial relative values:

| Surface | Grip | Drag | Fuel use | Special effect |
|---|---:|---:|---:|---|
| Asphalt | 1.00 | 1.00 | 1.00 | Baseline |
| Worn dirt | 0.88 | 1.10 | 1.05 | Mild slide |
| Loose stone | 0.72 | 1.20 | 1.10 | Vibration and tire risk |
| Mud | 0.55 | 1.80 | 1.35 | Builds bogging |
| Sand | 0.68 | 1.50 | 1.25 | Momentum loss |
| Oil | 0.12 | 0.90 | 1.00 | Temporary severe lateral grip loss |

Values are multiplied per wheel and blended across the vehicle. A vehicle with one side in mud should pull and yaw toward that side.

### 10.5 Collision damage

Collision damage considers:

- Relative velocity
- Impact angle
- Effective mass
- Contact region
- Ram equipment
- Recent collision cooldown

Low-speed scraping should not repeatedly drain hull health. Strong frontal rams do more damage than glancing side contact. A brief per-pair cooldown prevents one contact from producing many damage events.

### 10.6 Recovery

The game should prevent common physics failures from ending otherwise valid runs:

- Detect upside-down vehicles.
- Allow a limited recovery action when speed is near zero and no enemy is immediately adjacent.
- Reposition to the nearest valid road spline only when the vehicle is physically stuck due to a simulation defect, not when legitimately bogged or knocked off the road.
- Record automatic recovery events for debugging.

---

## 11. Combat system

### 11.1 Damage channels

| Channel | Primary targets | Examples |
|---|---|---|
| Personnel | Operators and exposed crew | Pistol, direct bullet hit |
| Hull | Vehicle structure | Machine gun, rocket |
| Fire | Personnel and hull over time | Flamethrower, Molotov |
| Impact | Vehicle structure and stability | Ram, explosion force |
| Terrain | Vehicle or instant loss | Falling, crushing, severe bogging |

### 11.2 Hit regions

Vehicles may contain:

- Main hull
- Engine
- Tires or mobility system
- Weapon mount
- Fuel tank
- Personnel hitboxes

Milestone 1 uses only hull and operator hitboxes. Subsystem damage is added after baseline combat is stable.

### 11.3 Mounted aiming

The player aims with the camera. The weapon attempts to converge on the camera ray while respecting:

- Turret yaw limits
- Turret pitch limits
- Muzzle obstruction
- Maximum range
- Weapon spread

The crosshair changes when the desired aim point is outside the mount's traverse range or the muzzle is obstructed.

### 11.4 Weapon definitions

#### Machine gun

- Primary baseline weapon
- Hitscan or extremely fast simulated projectile
- Moderate hull damage
- Strong personnel damage on direct hit
- Sustained fire increases spread or heat
- Clear tracer and impact feedback

#### Rocket launcher

- Slow, visible projectile
- High hull and impact damage
- Splash force
- Low ammunition
- Dangerous to fire into nearby terrain

#### Flamethrower

- Short-range cone or clustered ray/volume test
- Builds heat on valid targets
- Ignites after sustained exposure
- Can deny narrow road space
- Uses limited fuel ammunition separate from convoy driving fuel unless later balancing combines them

#### Molotov cocktail

- Ballistic thrown projectile
- Breaks on valid impact
- Creates a temporary burning area
- Damages personnel quickly and hull slowly
- Useful at choke points and forks
- Can ignite already leaking or vulnerable targets

#### Pistol

- Personnel damage only
- Cannot damage ordinary hull
- Strong against bikers and exposed ute occupants
- Weak against protected roadtrain crew
- Limited practical range from a moving vehicle

#### Ram

- Not an inventory weapon
- Damage derives from collision physics
- Ram equipment modifies dealt and received impact damage

### 11.5 Fire state

Fire progresses through:

1. **Heating:** Visual warning; no persistent burn.
2. **Ignited:** Damage over time begins.
3. **Burning:** Strong visual effect and increasing danger.
4. **Critical:** High chance of operator loss or vehicle destruction.
5. **Extinguished:** Heat decays and persistent effects stop.

Mud and water-like terrain can accelerate extinguishing. High speed may reduce small external flames but should not trivially remove a fully developed vehicle fire.

### 11.6 Personnel loss

- Personnel health is separate from hull health.
- A dead bike rider causes the bike to fall or coast.
- A dead ute driver leaves the vehicle uncontrolled.
- A protected roadtrain driver is difficult to target with personnel weapons.
- If the player's operator is killed, control transfers to another valid convoy vehicle.
- A convoy without a valid operator or vehicle is eliminated.

The presentation remains stylized and avoids graphic injury.

---

## 12. Resources and pickups

### 12.1 Shared convoy fuel

Fuel belongs to the convoy rather than individual companion vehicles. Each active vehicle contributes consumption based on:

```text
idle use
+ throttle demand
+ speed/load component
+ vehicle-class multiplier
+ terrain multiplier
+ damage penalty
```

The HUD displays total fuel and estimated time or distance at the recent consumption rate.

At zero fuel:

- Engine force falls to zero.
- Vehicles coast.
- The convoy receives a short final recovery window.
- Collecting or receiving fuel can restore movement.
- The run ends if no vehicle can regain fuel within the allowed period.

Initial tuning target: a fresh convoy travels for approximately four to six minutes without finding fuel.

### 12.2 Ammunition

Weapons have simple, readable ammunition categories:

- Bullets
- Rockets
- Flame fuel
- Throwables

The pistol may use effectively abundant reserve ammunition but still reload, or it may share bullets with the machine gun after balancing tests.

### 12.3 Repairs

Repair pickups restore hull health. Early versions apply repairs instantly to the most damaged surviving vehicle. Later versions may let the player choose a target through a brief contextual input.

Repairs do not resurrect destroyed vehicles during a run unless a special mode explicitly supports it.

### 12.4 Scrap and upgrades

Scrap is earned from:

- Distance
- Enemy vehicle destruction
- Personnel eliminations
- Hazard assists
- Resource recovery
- Surviving vehicles

Temporary run upgrades might include:

- Improved cooling
- Reinforced tires
- Better fuel efficiency
- Larger ammunition reserve
- Fire resistance
- Stronger ram

Permanent progression should favor new choices, loadouts, and visual customization over direct statistical dominance.

---

## 13. AI system

### 13.1 Shared control interface

Player and AI controllers should produce the same logical inputs:

```text
Throttle
Brake
Steering
Handbrake
AimDirection
FirePrimary
FireSecondary
UseEquipment
```

This lets AI use the same vehicle and weapon systems as players.

### 13.2 Companion AI priorities

1. Stay on valid road.
2. Avoid immediate lethal hazards.
3. Maintain formation without colliding with the leader.
4. Catch up when separated.
5. Select and attack valid enemies.
6. Avoid blocking the player's firing line where practical.
7. Follow the player's selected fork.

### 13.3 Formation

Each road spline provides a forward direction and lateral width. Companion targets are offsets relative to the player or convoy leader:

- Rear left
- Rear right
- Side escort
- Single-file canyon formation

Formation compresses automatically in narrow chunks. AI receives limited catch-up acceleration and reduced collision interference when far behind.

### 13.4 Steering

AI steering uses:

- Look-ahead point on the road spline
- Desired lateral offset
- Speed-sensitive steering
- Forward obstacle raycasts
- Side clearance tests
- Hazard cost map

AI should choose an acceptable route rather than calculate a perfect one. Small deliberate errors keep NPC driving readable and fallible.

### 13.5 Combat AI

Target scoring considers:

- Distance
- Aim angle
- Target exposure
- Target convoy relationship
- Remaining health
- Weapon suitability
- Immediate collision threat

NPC difficulty changes reaction time, aim error, risk tolerance, and route choice. It should not grant impossible traction, knowledge, or weapon fire rates.

### 13.6 NPC convoy behavior

NPC convoys can:

- Pursue
- Overtake
- Ram
- Screen a damaged companion
- Set up a canyon ambush
- Retreat toward a fuel pickup
- Choose a fork based on current needs

The first NPC uses only road following, obstacle avoidance, and direct firing.

---

## 14. Multiplayer and security architecture

### 14.1 Authority model

The server owns:

- Convoy membership and state
- Fuel, ammunition, health, and damage
- Road generation
- Encounter spawning
- Pickup collection
- Weapon validation
- Run distance and rewards
- AI decisions

The client owns or predicts:

- Input
- Camera
- Crosshair
- Local weapon feedback
- HUD
- Cosmetic recoil and shake
- Local audio and particles

### 14.2 Vehicle networking

For responsiveness, the controlling player's client may receive physics network ownership of its vehicle assembly. The server audits:

- Maximum reasonable speed and acceleration
- Teleport distance
- Position relative to active road
- Impossible orientation changes
- Collision and damage requests

AI vehicles remain server-owned unless profiling demonstrates a better controlled arrangement.

### 14.3 Weapon validation

The client sends an intent containing weapon, origin, direction, and timing. The server validates:

- The player controls the firing vehicle.
- The weapon is equipped and operational.
- Fire rate and reload state permit the shot.
- Ammunition is available.
- Origin is near the actual muzzle.
- Direction is within allowed camera and mount limits.
- Static geometry does not block the shot.
- The target is valid and not part of the same convoy.

Damage is always applied by the server.

### 14.4 Remote-event boundaries

Remote events should represent intent rather than outcomes:

```text
RequestFire
RequestReload
RequestEquipment
RequestRecovery
SelectFork
SetInputState
```

Avoid remotes such as `DealDamage`, `GiveFuel`, or `DestroyVehicle`.

---

## 15. User interface and feedback

### 15.1 Driving HUD

The normal HUD shows:

- Crosshair and weapon state
- Speed
- Shared convoy fuel
- Controlled vehicle hull
- Operator health
- Companion vehicle status
- Ammunition
- Fire/heat warning
- Bogging meter when relevant
- Distance travelled
- Upcoming fork or major hazard

The center of the screen should remain relatively clear.

### 15.2 Convoy status

Each vehicle is represented by a compact portrait or silhouette:

- Healthy
- Damaged
- Burning
- Bogged
- Operator lost
- Destroyed
- Currently controlled

### 15.3 Hazard feedback

- Mud produces wheel spray, deeper engine load, and a visible bog meter.
- Oil changes tire sound and adds a brief grip warning.
- Loose stone creates suspension noise and camera vibration.
- A lethal edge uses environmental composition rather than a constant invisible-wall warning.
- Critical fire produces escalating audio and a strong but readable HUD warning.

### 15.4 Route feedback

Forks are signalled early through:

- Visible road geometry
- Silhouettes and landmark colors
- Short labels such as `FUEL / EXPOSED` or `MUD / SHORT`
- Companion acknowledgement

The UI describes the obvious tradeoff but does not reveal every encounter.

### 15.5 Accessibility

- Adjustable camera shake
- Adjustable field of view
- Separate aim and steering sensitivity
- Color-independent vehicle and hazard states
- Subtitles for important radio information
- Remappable controls where supported
- Toggle and hold alternatives for aim
- Reduced flashing option
- Strong audio cues supplemented by visual cues

---

## 16. Audio and visual direction

### 16.1 Visual language

- Stylized post-collapse vehicles and environments
- Strong silhouettes at high speed
- Warm desert palette with biome-specific accents
- Dust, smoke, and fire used for feedback as well as atmosphere
- Moving vehicles throw dust from their rear contact points on dry dirt,
  stone, sand, and salt surfaces. Mud and asphalt never emit this dust.
- Avoid excessive small debris that obscures targets or harms performance

Each road family needs a distinct distant silhouette:

- Raised highway: pillars and broken spans
- Canyon: tall rock walls
- Mudflats: broad horizon and reflective dark ground
- Cactus country: dense vertical plants and termite towers
- Stony desert: low ridges and scattered boulders

### 16.2 Audio layers

- Engine RPM and load
- Surface-dependent tire sound
- Suspension and chassis stress
- Wind speed
- Weapon report and mechanical cycle
- Incoming fire
- Impact weight
- Companion radio callouts
- Fuel, bogging, and fire warnings

Engine sound should respond to actual demand, not only vehicle speed. A bogged vehicle should sound heavily loaded while barely moving.

---

## 17. Progression and garage

### 17.1 Garage functions

- Choose convoy class
- Select starting weapons
- Equip one or two class-compatible upgrades
- Apply cosmetic body, paint, decal, and exhaust options
- Review class mastery
- Enter a run

### 17.2 Unlock philosophy

Unlocks should create lateral variety:

- A flamethrower is powerful at short range but not strictly better than a machine gun.
- Reinforced tires trade speed or weight for terrain resistance.
- Larger tanks may reduce acceleration.
- Stronger armor may increase fuel use.

New players must be competitively viable with baseline equipment.

### 17.3 Monetization boundaries

Potential monetization:

- Vehicle cosmetics
- Paint and decal packs
- Non-gameplay garage presentation
- Emotes or victory poses
- Optional cosmetic progression track

Avoid selling:

- Direct damage advantages
- Exclusive superior vehicle statistics
- Fuel or repair advantages inside competitive runs
- Paid recovery from normal elimination

---

## 18. Technical project structure

Proposed Rojo-oriented layout:

```text
src
  ReplicatedStorage
    Shared
      Config
        ConvoyConfig.lua
        SurfaceProfiles.lua
        VehicleConfig.lua
        WeaponConfig.lua
      Types
      Util
      Remotes
  ServerScriptService
    Services
      AIService.lua
      CombatService.lua
      ConvoyService.lua
      FuelService.lua
      PickupService.lua
      RoadService.lua
      SessionService.lua
      VehicleService.lua
  ServerStorage
    RoadChunks
    Vehicles
    Hazards
    Pickups
  StarterPlayer
    StarterPlayerScripts
      Controllers
        CameraController.lua
        HUDController.lua
        InputController.lua
        VehicleController.lua
        WeaponController.lua
```

### 18.1 Service responsibilities

| Service | Responsibility |
|---|---|
| `RoadService` | Selects, places, activates, and retires chunks and forks. |
| `SessionService` | Owns run state, distance, difficulty, and completion. |
| `ConvoyService` | Creates convoys, tracks membership, and transfers control. |
| `VehicleService` | Spawns vehicles and manages server-side vehicle state. |
| `CombatService` | Validates attacks and applies damage/fire/impact. |
| `FuelService` | Calculates consumption and zero-fuel behavior. |
| `PickupService` | Spawns and awards fuel, ammo, repair, and scrap. |
| `AIService` | Produces driving and combat inputs for NPCs and companions. |

### 18.2 Data-driven content

Vehicles, surfaces, weapons, road chunks, and hazards should be configured through modules, attributes, and tags. Art models should not contain unrelated gameplay scripts when a central service can manage the behavior.

### 18.3 Tags

Suggested `CollectionService` tags:

- `RoadSafeSurface`
- `RoadSoftBoundary`
- `RoadHardBoundary`
- `RoadLethalZone`
- `HazardOil`
- `HazardMud`
- `HazardFire`
- `HazardRockfall`
- `PickupFuel`
- `PickupAmmo`
- `PickupRepair`
- `PersonnelHitbox`
- `VehicleHitbox`

---

## 19. First playable milestone

### 19.1 Scope

- One driveable ute
- First-person camera
- Keyboard and mouse controls
- Mouse-aimed machine gun
- One enemy ute
- Vehicle hull health and destruction
- Basic operator hitbox
- Fuel consumption
- One fuel pickup
- Asphalt, mud, and oil handling
- Three reusable stony-desert road chunks
- Distance and kill counter
- Five-minute playable run

### 19.2 Deliberately excluded

- Full convoy control
- Roadtrain and bikes
- Multiplayer
- Forks
- Fire weapons
- Persistent progression
- Detailed subsystem damage
- Long-distance coordinate rebasing
- Final art

### 19.3 Acceptance criteria

- The ute can complete repeated five-minute runs without routine physics failure.
- Steering remains controllable at high speed.
- Mud and oil feel immediately different from normal road.
- The machine gun can reliably damage and destroy an enemy ute.
- The server, not the client, applies damage and fuel changes.
- The enemy can follow the road and fire without becoming stuck in ordinary chunks.
- Road chunks recycle without a visible gap or deletion beneath an active vehicle.
- Zero fuel produces a clear and understandable run failure.
- Player death or vehicle destruction returns cleanly to the run result state.
- No severe errors accumulate in the Studio output during repeated tests.

---

## 20. Production roadmap

### Milestone 1: First playable

Build and validate the scope and acceptance criteria in Section 19.

**Exit condition:** Five-minute gray-box runs are consistently fun enough to justify expanding content.

### Milestone 2: Endless road

- Formal chunk sockets and metadata
- Seeded road director
- Chunk lifecycle and occupancy
- Road-family transitions
- Raised-highway falls
- Canyon impact damage
- Mud bogging
- Stony off-track behavior
- One reconverging fork

**Exit condition:** A single ute can drive for 15 minutes through varied, correctly recycled terrain.

### Milestone 3: Combat expansion

- Personnel and hull hitboxes
- Pistol
- Rocket launcher
- Flamethrower
- Molotov cocktail
- Fire and extinguishing
- Collision-based ramming
- Ammunition and repair pickups

**Exit condition:** Every weapon has a clear role and server-validated damage.

### Milestone 4: Convoys

- Two-ute composition
- Three-bike composition
- Roadtrain
- Companion formation AI
- Companion combat AI
- Control transfer
- Shared convoy resources
- Class balance pass

**Exit condition:** Each convoy composition can complete the same seeded run through a distinct but viable playstyle.

**Implementation status (corrected 2026-07-26):** The playable session now
spawns the selected Roadtrain, two-Ute, or three-Bike convoy and runs its
companions through formation/combat AI. The earlier completion claim omitted
this lobby-to-match integration and was corrected with an explicit runtime
acceptance gate.

### Milestone 5: Multiplayer and progression

- One-to-four-human session foundation
- Shared branch occupancy
- Spectating and results
- Garage
- Scrap and mastery
- Temporary run upgrades
- Cosmetic persistence
- Anti-exploit audit

**Exit condition:** Complete multiplayer runs remain stable and fair under realistic latency.

**Implementation status (2026-07-26):** The Milestone 5 code path and automated
acceptance checks are complete. The realistic-latency multiplayer soak remains
a manual release validation gate; it is not replaced by headless tests.

### Milestone 6: Content and launch preparation

- Full initial chunk library
- Environment art pass
- Reference-driven armored eight-wheel Roadtrain visual pass
- Distinct open ammunition-crate and handled fuel-jerrycan pickup props
- Rear vehicle dust on dry surfaces, suppressed on mud and asphalt
- Audio pass
- Onboarding
- Controller support
- Accessibility settings
- Device and performance testing
- Analytics
- Economy tuning
- Compliance and publication preparation

**Implementation status (2026-07-26):** Milestone 6 code paths and automated
acceptance coverage are implemented. Published-place analytics, representative
device/MicroProfiler evidence, asset-permission verification, and Creator
Dashboard compliance remain manual launch gates.

### Milestone 7: Rival convoy endgame

- Three-to-six total competitors
- Exactly two server-owned AI players
- AI selection of convoy classes humans did not choose
- Per-vehicle speed, accuracy, aggression, and vendetta
- Proactive AI ammunition use and voluntary attacks
- Damage-triggered taunts and vendetta retaliation
- Final stretch after the first complete competitor elimination
- Finish line in the next ungenerated road chunk
- Server-authoritative finish crossing
- Bounded drop-off-the-back warning, grace, and DNF
- Six-competitor and fifteen-vehicle match validation

**Exit condition:** Repeated three-to-six-competitor matches, with exactly two AI
players and all three convoy classes represented, reliably produce one
server-confirmed winner at the reserved finish chunk, apply fair drop-off rules,
and preserve correct results under realistic latency.

**Implementation status (2026-07-26):** The three-to-six roster, exactly two
session-owned AI rivals, missing-class allocation, and independent per-vehicle
trait rolls are operational. Taunt/vendetta reactions, finish reservation,
finish crossing, drop-off DNF, AI result integration, and full traversal/soak
gates remain open.

---

## 21. Content targets

Targets for an initial content-complete release:

| Content type | Target |
|---|---:|
| Road families | 5 |
| Normal chunks per family | 4-6 |
| Hazard-heavy chunks per family | 2 |
| Transition chunks per family | 2 |
| Fork sets | 4-6 |
| Convoy classes | 3 |
| Weapons | 5 plus ramming |
| Pickup types | 4 |
| NPC convoy archetypes | 4-6 |
| Temporary upgrades | 8-12 |

These are production targets, not MVP requirements.

---

## 22. Balancing framework

### 22.1 Primary measurements

- Median run duration
- Median distance
- Fuel gained and consumed per minute
- Damage dealt by source
- Damage received by source
- Deaths by terrain type
- Weapon accuracy and kill contribution
- Convoy survival by class
- Fork selection rate and survival result
- AI stuck or recovery rate

### 22.2 Initial experience targets

- Most new-player runs last at least five minutes.
- Fuel creates concern before it creates failure.
- A player normally receives enough warning to understand an avoidable lethal hazard.
- No single weapon is optimal at every range and against every convoy class.
- Companion AI contributes without routinely winning fights by itself.
- Environmental deaths remain common enough to define the game but not so common that weapon skill feels irrelevant.

### 22.3 Catch-up and anti-snowballing

Potential systems:

- Damaged convoys encounter slightly more recovery opportunities.
- Leading convoys attract stronger NPC attention.
- Destroyed enemies drop resources accessible to nearby competitors, not automatically to the killer.
- Powerful temporary upgrades carry fuel, heat, or handling costs.

Catch-up systems must be subtle and must not invalidate strong play.

---

## 23. Performance budgets and practices

Initial guidelines:

- Keep active road chunks bounded, including fork branches.
- Keep only nearby combat vehicles in full simulation.
- Pool common effects such as tracers, impacts, fire patches, and shell casings.
- Run fuel and noncritical AI decisions at a lower fixed rate than physics.
- Use level-of-detail models for distant road scenery.
- Keep road collision simpler than visible art.
- Avoid large moving assemblies containing unnecessary parts.
- Profile server physics, replication, and client frame time separately.

Suggested early stress test:

- Four player-equivalent convoys
- Maximum of twelve active combat vehicles
- Ten or more active road chunks including a fork
- Simultaneous machine-gun fire
- Two active fire areas
- Multiple pickups and wrecks

The exact budgets are set after measuring the gray-box implementation on representative devices.

---

## 24. Testing plan

### 24.1 Vehicle tests

- Acceleration and braking distance
- High-speed slalom
- Handbrake recovery
- One-side surface transition
- Head-on and glancing collision
- Upside-down recovery
- Network-latency response

### 24.2 Road tests

- Every socket combination
- Transition slope and heading
- AI completion
- No geometry overlap
- No visible gaps
- Chunk deletion behind slow convoys
- Fork occupancy and reconnection
- Pickup and encounter placement validity

### 24.3 Combat tests

- Fire-rate validation
- Ammunition validation
- Muzzle obstruction
- Personnel-only pistol behavior
- Fire stacking and extinguishing
- Explosion force limits
- Friendly-convoy immunity
- Latency and moving-target validation

### 24.4 Resource tests

- Fuel at idle, speed, mud, and damage states
- Zero-fuel recovery window
- Shared fuel across multiple vehicles
- Pickup contention between convoys
- Repair target selection

### 24.5 Failure and soak tests

- Repeated 30-minute server run
- Convoy elimination during a fork
- Player disconnect while controlling a convoy
- Companion destroyed during control transfer
- Chunk retirement containing projectiles or fire
- Repeated automatic vehicle recovery

---

## 25. Analytics events

Potential events:

```text
RunStarted
ConvoySelected
RoadFamilyEntered
ForkPresented
ForkSelected
FuelPickupCollected
FuelEmpty
WeaponFired
VehicleDamaged
VehicleDestroyed
OperatorKilled
ControlTransferred
HazardEntered
VehicleBogged
VehicleFell
RunEnded
```

Events should include the run seed, distance, convoy class, road family, chunk ID, and relevant source without collecting unnecessary personal data.

---

## 26. Major risks and mitigations

### Driving and aiming overload

**Risk:** Simultaneous steering and precise FPS aiming may be frustrating.

**Mitigation:** Restrained aim assistance, readable weapon spread, broad vehicle targets, independent sensitivity, and weapons that reward sustained tracking rather than pixel-perfect aim.

### Physics instability

**Risk:** High-speed multiplayer vehicles can produce unpredictable collisions.

**Mitigation:** Controlled mass ratios, collision cooldowns, simplified collision hulls, stability assistance, capped forces, and repeated network testing.

### Companion frustration

**Risk:** AI companions may crash, block shots, or fall behind.

**Mitigation:** Formation compression, catch-up assistance, hazard costs, recovery rules, and clear companion status.

### Procedural repetition

**Risk:** A small chunk library becomes recognizable too quickly.

**Mitigation:** Strong chunk variants, encounter sockets, mirrored or alternate dressing where valid, road-family waves, forks, and difficulty-dependent hazard combinations.

### Fork complexity in multiplayer

**Risk:** Players split across branches and multiply active content.

**Mitigation:** Short branches, reconvergence, occupancy counts, active-branch caps, and encounter scaling.

### Personnel weapons feel unfair

**Risk:** A pistol could bypass vehicle investment with a sudden driver kill.

**Mitigation:** Protection by class, difficult moving shots, visible exposure, damage falloff, operator health tuning, and control transfer for multi-vehicle convoys.

### Fire obscures play

**Risk:** Fire particles reduce visibility and performance.

**Mitigation:** Bounded effect counts, transparent readable flames, client-side pooling, simplified distant effects, and a reduced-effects option.

### Scope expansion

**Risk:** Three vehicle classes, five environments, multiplayer, AI, and progression are too large to build together.

**Mitigation:** Do not begin full content production until the agreed first playable passes its exit criteria.

---

## 27. Open design decisions

These decisions do not block Milestone 1:

1. Does the launch mode prioritize competitive PvPvE or cooperative PvE?
2. Can players voluntarily transfer between surviving vehicles, or only transfer after loss?
3. Does the pistol use separate ammunition or a shared bullet reserve?
4. Does flamethrower ammunition share convoy driving fuel?
5. Can a fully bogged vehicle be towed by a companion?
6. Can destroyed convoy vehicles be recovered during a run?
7. Does a roadtrain contain destructible weapon stations or only one primary mount at launch?
8. How much aim assistance should controller and mobile users receive?
9. Is mobile part of initial launch scope or a later adaptation?
10. Are matches ranked by distance only, last survivor, or a combined score?
11. Can player convoys temporarily cooperate without formal teams?
12. What is the final visual tone: severe wasteland, exaggerated action, or dark comedy?

---

## 28. Immediate implementation order

1. Establish the Rojo project structure and shared configuration pattern.
2. Build a gray-box ute with tunable handling.
3. Add first-person camera and input.
4. Build a straight stony-desert test track.
5. Add mud and oil surface profiles.
6. Add server-owned hull health and machine-gun damage.
7. Add one basic road-following enemy ute.
8. Add convoy fuel and a fuel pickup.
9. Build three socket-compatible road chunks.
10. Implement placement, occupancy, and recycling.
11. Add distance, kill, fuel, hull, and ammunition HUD.
12. Run repeated five-minute playtests against the Milestone 1 acceptance criteria.

No roadtrain, bikes, forks, fire weapons, progression, or final environment art should begin before this sequence produces a stable, enjoyable first playable.

---

## 29. Definition of success

Hoonanga succeeds when a player can describe a run as a sequence of specific road stories rather than as a generic driving match:

> We took the fuel route onto the raised highway, lost the second ute when it was rammed over the edge, set the canyon entrance on fire, ran out of ammunition in the mudflats, and made it another kilometre with the last vehicle almost empty.

The systems should consistently create those stories while keeping their causes readable, their outcomes fair enough to learn from, and the next run immediately tempting.
