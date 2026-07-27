# Hoonanga Match Flow and Road Endgame Plan

**Status:** Proposed — design review required before implementation  
**Applies to:** Milestones 5, 6, and 7, with acceptance-test follow-up for Milestones 1–4  
**Primary mode:** Three-to-six-competitor Convoy Run with exactly two AI competitors

## 1. Purpose

This plan replaces the current prototype flow of spawning immediately, changing
convoy class with F1/F2/F3 during play, and ending only when every convoy is
eliminated.

The proposed match has:

- A real lobby and ready phase.
- Three to six competing convoys: one to four human players plus exactly two AI
  competitors.
- Roadtrain, Ute, and Bike represented in every match.
- Convoy class locked for the duration of the run.
- A final stretch that begins when the first complete human or AI convoy is
  eliminated.
- A finish line placed in the next road chunk that did not exist when the
  elimination occurred.
- A server-authoritative win when any operational vehicle from a convoy crosses
  that line.
- A generous but bounded drop-off-the-back rule.
- A phase-owned mouse policy that always exposes an unlocked cursor in Lobby and
  Results.
- Two AI convoys whose class choices fill human roster gaps and whose individual
  vehicles receive distinct driving/combat personalities at match start.
- Persistent wins, credits, vehicle inventory, cosmetics, mastery, and statistics.

## 2. Canonical terminology

The existing documents use player, team, convoy, composition, and class in ways
that can overlap. The implementation should use these meanings:

| Term | Meaning |
|---|---|
| Human player | One Roblox player admitted to the active match roster. |
| AI player | One server-owned competitor that follows the same match rules without a Roblox `Player` instance. |
| Convoy | All vehicles controlled by, or assigned to, one human or AI player. |
| Competitor | One human or AI player and that competitor's convoy. |
| Convoy class | `Roadtrain`, `Ute`, or `Bike`. |
| Vehicle type | The physical vehicle model used by a convoy member. |
| Match roster | Three to six competitors: one to four humans and exactly two AI players. |
| Eliminated | A convoy has no operational vehicle/operator pair, or has received a non-combat DNF. |
| Final stretch | The period after the first competitor is eliminated and before a winner is confirmed. |
| Finish chunk | The road chunk containing the finish line. |

For code and saved data, `Bike` is canonical. Existing `Biker` data must be
migrated to `Bike`.

## 3. Decisions proposed by this plan

These defaults allow implementation to proceed without leaving important behavior
implicit:

1. Each human or AI player owns one convoy and competes against every other
   competitor.
2. A match contains at least three and at most six competitors.
3. Every match contains exactly two AI players, leaving room for one to four human
   players.
4. At least one human must ready before a match can start.
5. Human players may choose duplicate classes.
6. The two AI class choices fill classes the humans did not choose first, then
   choose the currently least-represented class if fewer than two classes are
   missing.
7. The final roster must contain at least one Roadtrain, one Ute, and one Bike.
8. The three base convoy classes are always available. Persistent vehicle ownership
   applies to future chassis variants and loadouts, not access to these required
   base classes.
9. Convoy class can be changed only in `Lobby`.
10. The first complete human or AI convoy elimination starts the final stretch.
11. The finish is assigned to the next chunk that has not yet been generated.
12. Crossing requires an operational convoy vehicle. Wrecks, characters,
   projectiles, and detached parts do not count.
13. The first valid crossing wins. Remaining competitors are ranked by crossing
    order, then run distance when the match closes.
14. Drop-off is a DNF, not a combat kill.
15. A drop-off DNF can trigger the final stretch if it is the first elimination.
16. Late joiners and humans beyond the four-human roster spectate until the next
    lobby.
17. AI competitors can win and appear in results, but never receive persistent
    currency or profile writes.
18. Credits and wins are granted only from a server-owned finalized result.

## 4. Match state machine

The session should use explicit states rather than inferring match status from
player or vehicle existence.

```text
Lobby
  -> Countdown
  -> InRun
  -> FinalStretch
  -> Results
  -> Lobby
```

### 4.1 Lobby

- No active match convoys exist.
- Players choose a convoy class through the garage/lobby UI.
- Players may change their selection until they ready up.
- Readying locks that player's current selection.
- Unreadying unlocks it.
- Countdown can begin only when:
  - At least one eligible human player is ready.
  - No more than four humans are admitted to the roster.
  - Exactly two AI slots can be added.
  - The combined human-plus-AI roster contains Roadtrain, Ute, and Bike.
- The UI must explain why countdown is blocked, for example:
  - `Ready to start with 1 human + 2 AI`
  - `AI filling Bike and Roadtrain`
  - `Waiting for Alex to ready`

F1/F2/F3 may remain as lobby-only shortcuts, but they must not directly spawn or
replace a convoy. The visible lobby UI is the primary selection route.

### 4.2 Countdown

- The roster and class selections are snapshotted.
- AI classes are assigned after the human snapshot, filling unchosen classes first.
- Every AI vehicle receives its match-seeded personality rolls.
- Players can cancel readiness, which returns the session to `Lobby`.
- Late joiners are not added to the active roster.
- At zero:
  - Clear stale match entities.
  - Generate the match run ID and seed.
  - Spawn roster convoys at deterministic, collision-safe offsets.
  - Apply persistent cosmetics/loadouts.
  - Reset temporary upgrades and per-run statistics.
  - Transition to `InRun`.

### 4.3 InRun

- Class-selection and loadout-changing remotes are rejected.
- Only roster players can drive, fire, collect, and score.
- Eliminated players enter spectate mode.
- The first complete competitor elimination atomically:
  - Records its DNF reason and elimination time.
  - Transitions the match to `FinalStretch`.
  - Reserves the next ungenerated road chunk as the finish chunk.
  - Announces the final stretch to all players.

### 4.4 FinalStretch

- The endless-road recycler continues normally.
- When the reserved chunk is generated, it receives a finish gate and replicated
  finish metadata.
- Additional eliminations do not move or duplicate the finish.
- The server checks every operational roster vehicle for a forward crossing.
- The first valid crossing:
  - Records the winner exactly once.
  - Freezes competitive scoring.
  - Transitions to `Results`.

If every competitor is eliminated before crossing, the match ends with no finisher
and ranks competitors by greatest authoritative run distance.

### 4.5 Results

- Results contain placement, finish/DNF state, distance, kills, pickups, transfers,
  credits, mastery, and win credit.
- Rewards are calculated once from immutable server results.
- Persistence completes through an idempotent run-result transaction.
- After the results timer, match objects are removed and the state returns to
  `Lobby`.

### 4.6 Mouse and input state

Mouse ownership must come from the match phase, not from whichever UI or camera
controller happened to run most recently.

| State | Mouse behavior | Mouse icon | Gameplay input |
|---|---|---|---|
| `Lobby` | `Enum.MouseBehavior.Default` | Visible | Driving, aiming, and firing disabled |
| `Countdown` | `Enum.MouseBehavior.Default` | Visible | Driving, aiming, and firing disabled |
| `InRun` | `Enum.MouseBehavior.LockCenter` | Hidden | Driving, aiming, and firing enabled |
| `FinalStretch` | `Enum.MouseBehavior.LockCenter` | Hidden | Driving, aiming, and firing enabled |
| Spectating | `Enum.MouseBehavior.Default` | Visible | Spectator controls only |
| `Results` | `Enum.MouseBehavior.Default` | Visible | Gameplay input disabled |

Implementation rules:

- Add one `InputModeController` as the sole authority for `MouseBehavior`,
  `MouseIconEnabled`, and gameplay action binding.
- Lobby and Results must reapply the visible/unlocked state when entered, after
  character respawn, after GUI enable/disable, and after window focus returns.
- `CameraController`, `GarageController`, accessibility UI, onboarding UI, and
  results UI must not force mouse state from `RenderStepped`.
- No controller may recapture the cursor while the authoritative state is Lobby,
  Countdown, Spectating, or Results.
- An in-run overlay that needs a cursor must request a temporary modal input mode
  from `InputModeController`; closing it returns to the current phase's normal
  mode.
- Automated client tests must hold Lobby and Results for several rendered frames
  and prove that no other controller relocks the mouse.

## 5. Finish-line generation

### 5.1 Meaning of “next patch”

The endless-road system calls each generated road section a **chunk**. The requested
rule is therefore:

> When the first competitor convoy is eliminated, reserve the next chunk index that
> RoadService has not created yet. Put the finish line in that chunk when it is
> eventually generated.

This deliberately makes the remaining distance substantial because the road keeps a
large active buffer ahead of the players.

### 5.2 RoadService contract

RoadService should expose server-only APIs similar to:

```text
ReserveFinishChunk(runId) -> finishChunkIndex
GetFinishState() -> Pending | Spawned | Crossed
GetFinishDistance() -> number?
FinishLineSpawnedSignal()
ClearFinish()
```

Reservation must be idempotent. Repeated eliminations return the existing
reservation.

When the reserved index is built:

- Place the line 65–75% through the chunk, not on a socket seam.
- Build a readable gate across every valid lane.
- Publish `FinishChunkIndex`, `FinishDistance`, and `RunId`.
- Ensure the finish does not block vehicles physically.
- Keep the chunk active until results are finalized.
- Do not place ordinary hazards immediately on the crossing line.

### 5.3 Crossing validation

Do not use `Touched` as the scoring authority. It can fire from wreckage, detached
parts, replication jitter, or sideways contact.

On a fixed server interval:

1. Enumerate operational vehicles belonging to active roster convoys.
2. Resolve each vehicle against RoadService's path-distance calculation.
3. Require previous distance below the finish and current distance at or above it.
4. Require plausible forward movement under the existing movement-validation
   limits.
5. Atomically claim the winner for the vehicle's convoy.

The gate can still use local touch effects for sound, particles, and immediate
feedback after the server confirms the crossing.

### 5.4 Edge cases

- The eliminated convoy cannot win with a rolling wreck.
- A vehicle destroyed on the same server step as crossing wins only if the crossing
  is validated first while it is operational.
- Control transfer does not change the convoy's crossing eligibility.
- A disconnected player is treated as eliminated after a short reconnect grace
  only if reconnect support is intentionally added; otherwise disconnect is an
  immediate DNF.
- A server closing before the finish produces no win and must not grant duplicate
  rewards on restart.

## 6. Drop-off-the-back mechanic

### 6.1 Goal

The rule should stop a severely trailing convoy from holding road chunks and match
completion indefinitely without punishing recoverable mistakes, combat loss, or a
normal class-speed difference.

Distance is measured on the road path, not world Z.

### 6.2 Recommended initial values

With the current 512-stud chunks:

| Threshold | Initial value | Purpose |
|---|---:|---|
| Warning distance | 4 chunks / 2,048 studs | HUD and audio warning begins. |
| DNF distance | 6 chunks / 3,072 studs | Considerably behind the leader. |
| DNF grace | 20 seconds continuously beyond threshold | Allows recovery. |
| Recovery threshold | 5 chunks / 2,560 studs | Hysteresis prevents warning flicker. |
| Start grace | First 60 seconds of the run | Prevents spawn/early-crash unfairness. |
| Transfer grace | 15 seconds after control transfer | Protects transfer disruption. |

These are telemetry-driven tuning values, not permanent balance constants.

### 6.3 Measurement

- Leader progress is the greatest `ConvoyRecord.RunDistance` among active
  competitors.
- Trailing progress is that convoy's authoritative maximum run distance.
- A convoy begins its drop timer only while:
  - It is operational.
  - It is beyond the DNF threshold.
  - Start/transfer grace is inactive.
- Moving back inside the recovery threshold clears the timer.

### 6.4 Outcome

When the grace expires:

- End the convoy with reason `DroppedOffBack`.
- Do not award a kill.
- Preserve its result distance and statistics.
- Move its player to spectate.
- Clean up its vehicles after a bounded visual delay.
- Trigger the final stretch if this is the match's first elimination.

The HUD must show both the gap and countdown. Silent drop-off is not acceptable.

## 7. Lobby and class selection

### 7.1 Required UI

The garage/lobby should show:

- The three base class cards with strengths, weaknesses, and member count.
- Current human selections and the two proposed AI selections.
- Which unchosen classes the AI will fill.
- Ready/unready state.
- Owned cosmetics and vehicle variants.
- Persistent credits, wins, and mastery.

### 7.2 Server authority

- `SelectConvoyClass` updates a lobby selection; it never spawns a vehicle.
- The server rejects selection while ready, during countdown, or in a run.
- `SetPlayerReady(true)` succeeds only with a valid selected class.
- SessionService, not the client, chooses the admitted roster.
- Match spawning uses snapshotted human selections plus two server-selected AI
  classes.
- The active roster is capped at four humans and two AI players even if the Roblox
  server contains additional spectators.

### 7.3 Current prototype replacement

`ConvoySelectionController` should be retired or converted into lobby-only shortcut
handling. `VehicleService` should stop creating a convoy on `PlayerAdded`.

VehicleService should instead expose explicit match APIs:

```text
SpawnMatchConvoy(player, classId, spawnCFrame)
RemovePlayerConvoy(player, reason)
GetPlayerConvoy(player)
```

### 7.4 AI class allocation

AI class assignment must be deterministic for a match seed and must prefer
alternatives the humans did not pick:

1. Count the snapshotted human selections for Roadtrain, Ute, and Bike.
2. For AI slot one, choose randomly from classes with a human count of zero.
3. Recount including AI slot one.
4. For AI slot two, again prefer a class with a human count of zero.
5. If no unchosen class remains, choose randomly from the least-represented class
   or classes.

Examples:

| Human selections | AI selections |
|---|---|
| Bike | Roadtrain and Ute |
| Bike, Bike | Roadtrain and Ute |
| Bike, Ute | Roadtrain, then one least-represented class |
| Bike, Ute, Roadtrain | Two least-represented classes, match-seeded tie-break |
| Bike, Bike, Bike, Bike | Roadtrain and Ute |

The two AI players are full competitors: they can eliminate humans, be eliminated,
drop off, cross the finish, and win.

## 8. AI competitors and class-specific behavior

The shared companion controller is a useful base, but a one-step formation test is
not evidence that all classes or server-owned AI competitors can complete a run.

### 8.1 Per-vehicle personality rolls

At match start, every vehicle belonging to an AI player receives a separate roll
for all four traits:

| Trait | Range | Runtime meaning |
|---|---:|---|
| Speed | 90–98% | Multiplier against that vehicle class's configured maximum speed. |
| Accuracy | 50–95% | Reduces aim error and improves lead prediction; it is not client-side hit chance. |
| Aggression | 25–95% | Proactive hostility: how freely it spends ammunition and how often it turns back or leaves the racing line to attack a convoy that did not attack it. |
| Vendetta | 25–95% | Reactive retaliation: how likely it is to ram, return fire, or turn back after validated enemy damage acts as a taunt. |

Roll requirements:

- Use independent rolls per vehicle, including each Bike or Ute in the same AI
  convoy.
- Seed rolls from the match seed, AI roster slot, and vehicle formation slot so a
  recorded match is reproducible.
- Roll once when the match roster is spawned. Control transfer, recovery, or target
  changes must not reroll personality.
- Store the values in server-owned controller state and mirror read-only attributes
  for debugging and telemetry.
- A 95% accuracy vehicle must still have non-zero error and obey weapon spread,
  obstruction, range, ammunition, heat, and fire-rate validation.
- Aggression and vendetta must remain separate inputs. An AI can be peaceful until
  attacked (`low aggression`, `high vendetta`) or start fights but decline a long
  retaliation (`high aggression`, `low vendetta`).

#### Aggression — proactive attack behavior

Aggression does not require provocation. It controls:

- How much ammunition the vehicle is willing to spend instead of conserve.
- Burst length and the delay before beginning another voluntary burst.
- How often it selects a nearby neutral-in-the-current-fight hostile convoy.
- How often it turns around or leaves the ideal racing line to initiate an attack.
- How strongly it prefers ramming when it has a safe approach.
- How long it continues an attack that it initiated.

A low-aggression vehicle primarily races, fires opportunistically, and preserves
scarce ammunition. A high-aggression vehicle attacks frequently and spends more of
its available ammunition.

Aggression may accept ordinary tactical risk, but must never bypass lethal-edge
avoidance, friendly-convoy checks, movement validation, weapon validation, or the
need to finish the race.

#### Vendetta — damage-as-taunt retaliation

Validated damage from an enemy vehicle creates a **taunt** for the damaged AI
vehicle. The taunt records:

```text
source convoy and vehicle
damage channel and amount
time received
relative road position
```

That vehicle evaluates the taunt using its own vendetta roll. A successful vendetta
response may:

- Immediately return fire when the source is targetable.
- Attempt a ram when geometry and road safety permit it.
- Turn back to confront the source when it is behind.
- Retain the taunting source for a bounded retaliation window.

Low vendetta ignores most taunts or responds briefly. High vendetta reacts to most
taunts and is more willing to turn back or ram. A successful taunt response may
temporarily override low aggression's reluctance to engage, but it still obeys
ammunition availability, weapon timing, road safety, and a bounded response
duration.

For the first implementation, taunts are per vehicle: damage to one Bike does not
automatically taunt every other Bike in its convoy. Convoy-wide revenge can be
evaluated later.

Vendetta does not cause unprovoked attacks and must not make the AI chase
indefinitely, ignore the finish, or target a destroyed/non-hostile vehicle.

Suggested target scoring inputs:

```text
distance
forward aim angle
target exposure and health
weapon suitability
proactive aggression opportunity
active taunt source and age
vendetta response strength and remaining window
road and finish priority
```

### 8.2 Required controller layers

- Shared road following and obstacle avoidance.
- Vehicle-class driving profile.
- Convoy-class formation profile.
- Per-vehicle personality profile.
- Weapon/target profile.
- Proactive ammunition/engagement budget for aggression.
- Per-vehicle damage-taunt memory and retaliation state for vendetta.
- Recovery and stuck detection.

### 8.3 Bike behavior

- Wider staggered formation on open road.
- Single-file compression before canyon/highway/fork constraints.
- Earlier steering into curves because of speed.
- Larger avoidance margin around hard boundaries and other bikes.
- Shorter combat bursts and more movement-priority decisions.
- Rider exposure included in target scoring.
- Recovery that does not teleport through hazards or other competitors.

### 8.4 Roadtrain behavior

A player Roadtrain has no companion vehicle, but the class still needs:

- NPC roadtrain steering for enemy archetypes and tests.
- Larger look-ahead distance and earlier braking.
- Turn-radius-aware lane targets.
- Strong resistance to oscillating steering.
- Clearance checks that consider full body/trailer width.
- Ram targeting without routine canyon/highway suicide.
- Protected-operator target rules.

### 8.5 Acceptance tests

For Roadtrain, two-Ute, and three-Bike:

- Complete the same fixed seed for a defined distance.
- Traverse every road family and a fork.
- Record stuck recovery, boundary collisions, friendly collisions, and falls.
- Confirm companion weapon ammunition and server timing.
- Confirm no class routinely drops off under nominal AI control.
- Confirm every AI vehicle has four independently generated values inside the
  configured ranges.
- Confirm identical match seeds reproduce the rolls and different seeds change
  them.
- Confirm high aggression spends measurably more ammunition and initiates more
  unprovoked turn-back attacks than low aggression.
- Confirm aggression changes do not affect damage-triggered taunt creation.
- Apply controlled enemy damage and confirm high vendetta returns fire, rams, or
  turns back more often than low vendetta.
- Confirm vendetta produces no response without a validated taunt.
- Confirm taunt responses expire and never bypass weapon or movement authority.
- Run with six simultaneous competitors.
- Run the worst-case 15-vehicle roster with combat, projectiles, and active fire.

Manual first-person tests remain required for camera comfort and transfer clarity.

## 9. Persistent profile and economy

### 9.1 Profile version 2

The profile should use a schema similar to:

```text
Version
Credits
Wins
Races
Podiums
DNFs
BestDistance
TotalDistance
TotalKills
Mastery = { Roadtrain, Ute, Bike }
OwnedVehicleVariants
OwnedCosmetics
EquippedCosmeticByClass
LoadoutByClass
LifetimeUpgradeUnlocks
LastProcessedRunIds
```

The three base classes remain available so required lobby composition cannot be
blocked by progression.

### 9.2 Migration

- Rename `Scrap` to `Credits`, or explicitly decide to keep `Scrap` as the player
  facing name. Do not maintain two currencies with identical purpose.
- Migrate `Mastery.Biker` to `Mastery.Bike`.
- Preserve unlocked cosmetics and equipped selections.
- Reject malformed values instead of blindly merging every saved key.

### 9.3 Saving

- Use `UpdateAsync`, not `SetAsync`, for profile writes.
- Validate and normalize every loaded profile.
- Add bounded retries with exponential backoff.
- Autosave during long sessions and save on player removal/server close.
- Separate the DataStore adapter so persistence rules can be tested without live
  DataStore access.
- Make run rewards idempotent with a server-generated run ID.

### 9.4 Rewards

Only SessionService can finalize:

- Winner and placements.
- Credits.
- Wins and podiums.
- Mastery by the class actually spawned.
- Distance, kills, pickups, and DNF reason.

AI results use the same authoritative statistics and placement rules, but skip
profile lookup, currency awards, and DataStore writes.

Clients can request purchases and selections, but cannot grant currency, unlocks,
wins, upgrades, or result statistics.

Temporary run upgrades must be earned through a server-owned pickup or choice
event. The current unrestricted `ClaimUpgrade` remote must not directly grant an
arbitrary upgrade.

## 10. Security and fairness requirements

- Every gameplay remote checks session state and roster membership.
- AI actions enter the same server-owned vehicle, weapon, combat, and movement
  validation paths as human actions.
- Class/loadout remotes are lobby-only.
- Driving and weapon remotes target only the player's controlled vehicle.
- Finish claims are server-calculated.
- Reward calculation uses immutable server results.
- Rate-limit selection, ready, purchase, spectate, and upgrade requests.
- Reject NaN, infinite, oversized, and wrong-type numeric inputs.
- Never trust client distance, placement, kills, pickup count, or ownership.
- Store run seed, class, latency summary, DNF reason, and finish evidence in
  telemetry without unnecessary personal data.
- Store the four per-vehicle AI rolls in match telemetry so balance outcomes can be
  reproduced and grouped by personality.

## 11. Implementation sequence

### Phase 0 — Confirm rules

- Approve the proposed decisions in Section 3.
- Confirm whether the player-facing currency is named Credits or Scrap.
- Confirm that first elimination, including drop-off/disconnect, starts the final
  stretch.

### Phase 1 — Milestone 5 session, lobby, and input foundation

- Expand SessionService into the explicit state machine.
- Integrate GarageService readiness and human class selection.
- Add lobby selection UI and human roster status.
- Add the authoritative phase-owned `InputModeController`.
- Guarantee visible, unlocked mouse input throughout Lobby and Results.
- Remove immediate spawning and in-run F1/F2/F3 replacement.
- Add state, roster, and mouse-ownership behavioral tests.

### Phase 2 — Milestone 5 lifecycle and persistence

- Spawn and clean up convoys only through SessionService.
- Wire human convoy elimination to session results and spectating.
- Lock remotes to session state and roster.
- Track authoritative convoy distance and statistics.
- Implement profile v2, migration, UpdateAsync adapter, retries, and autosave.
- Add server-owned reward transactions.
- Add persistent inventory/loadout UI and application.
- Integrate temporary upgrades with real acquisition and stat consumers.

### Phase 3 — Milestone 7 AI roster and behavior

- Add the two permanent AI roster slots and alternate-class allocation.
- Spawn exactly two AI convoys from the match-seeded class allocator.
- Add Bike and Roadtrain driving profiles.
- Add full AI-player support for every convoy class.
- Add independent speed, accuracy, aggression, and vendetta rolls per AI vehicle.
- Add proactive ammunition/engagement budgeting for aggression.
- Convert validated enemy damage into per-vehicle taunts.
- Add bounded vendetta response selection for return fire, ramming, and turn-back.

### Phase 4 — Milestone 7 final stretch

- Add finish reservation and generation to RoadService.
- Add final-stretch state and UI.
- Add authoritative crossing validation.
- Add finish/DNF/results tests.

### Phase 5 — Milestone 7 drop-off

- Add configurable thresholds, warning, grace, and hysteresis.
- Add control-transfer and early-run protection.
- Add deterministic drop-off tests on curved roads.

### Phase 6 — Milestone 7 acceptance

- Replace one-step AI tests with fixed-seed traversal and multi-convoy stress tests.
- Run repeated finish, drop-off, taunt, and aggression scenarios.
- Prove six-competitor and 15-vehicle stability.

### Phase 7 — Milestone 6 production acceptance

- Simulate realistic multiplayer latency.
- Run 30-minute soak tests and repeated full matches.
- Profile the six-competitor, 15-vehicle worst case with physics, fire,
  projectiles, and road generation.
- Complete controller, accessibility, audio, analytics, economy, and publication
  work that remains under Milestone 6.

## 12. Required automated tests

New behavioral tests should include:

```text
lobby_roster_test.luau
mouse_phase_state_test.luau
class_lock_test.luau
ai_class_allocation_test.luau
ai_personality_roll_test.luau
ai_aggression_budget_test.luau
ai_taunt_response_test.luau
session_elimination_test.luau
finish_reservation_test.luau
finish_crossing_test.luau
drop_off_test.luau
bike_ai_traversal_test.luau
roadtrain_ai_traversal_test.luau
profile_migration_test.luau
run_reward_idempotency_test.luau
remote_state_validation_test.luau
full_multiplayer_match_test.luau
six_competitor_stress_test.luau
```

Configuration-only tests must not claim that runtime behavior or DataStore
persistence was validated.

## 13. Effect on the existing milestones

### Milestone 1 — First playable

The basic driving/combat prototype remains valid. Still required:

- Real Play-mode vehicle physics validation.
- Repeated five-minute manual runs.
- Clear runtime error/soak evidence.

### Milestone 2 — Endless road

The road generator remains the foundation. Milestone 7 adds:

- Finish-chunk reservation.
- Finish-chunk lifecycle protection.
- Drop-off so a remote trailer cannot retain old chunks indefinitely.

Still required:

- A real 15-minute driving test.
- A decision on whether the current single-chunk fork is sufficient or full
  diverge/reconverge branches are still required.

### Milestone 3 — Combat expansion

The current server-validated combat suite remains applicable. Add:

- Three-to-six-competitor moving-target latency coverage.
- Kill/assist attribution into authoritative match results.
- No combat kill for drop-off or disconnect.

### Milestone 4 — Convoys

The convoy model remains applicable. Milestone 4 acceptance still needs:

- Full fixed-seed traversal for every class.
- Real worst-case simulation stress, not registry creation alone.
- Confirm reliable control transfer.

Milestone 7 separately adds permanent AI competitors, Bike/Roadtrain rival AI
profiles, personality rolls, and final-stretch transfer coverage.

### Milestone 5 — Multiplayer and progression

The previous “end when everyone is eliminated” assumption is superseded. The
applicable fixes are:

- Real roster/session integration.
- Elimination-to-spectate wiring.
- Garage and class locking.
- Phase-owned mouse/input behavior, especially visible unlocked cursor in Lobby and
  Results.
- Authoritative results and persistence.
- Anti-exploit validation.

Exactly two AI competitors, three-to-six total competitors, finish lines, drop-off,
and personality behavior are assigned to Milestone 7 rather than expanding
Milestone 5.

### Milestone 6 — Content and launch preparation

The earlier gaps still apply, but should follow the match foundation:

- Full controller combat/camera/menu support.
- Accessibility options beyond FOV.
- Gameplay-connected audio and analytics.
- Representative-device and server performance evidence.
- Remaining chunk/fork/NPC/upgrade content targets.
- Economy tuning from real match telemetry.
- Compliance and publication preparation.

### Milestone 7 — Rival convoy endgame

Milestone 7 owns the newly defined competitive mode:

- Three-to-six total competitors.
- Exactly two AI players.
- AI selection of alternatives humans did not choose.
- Per-vehicle speed, accuracy, aggression, and vendetta.
- Proactive aggression and damage-triggered taunts.
- FinalStretch after the first complete competitor elimination.
- Finish reservation in the next ungenerated chunk.
- Server-authoritative crossing and one winner.
- Bounded drop-off warning, grace, and DNF.
- Six-competitor, 15-vehicle validation.

Its detailed checkpoints and completion gates are defined in
`docs/MILESTONE_7_IMPLEMENTATION_PLAN.md`.

## 14. Decisions still needing confirmation

1. Should the currency be called **Credits** or retain **Scrap**?
2. Does a disconnect trigger the final stretch immediately, or after a reconnect
   grace period?
3. Is six chunks plus a 20-second grace sufficiently “considerable” for drop-off?
4. Should a match with no finishers award a win to the greatest-distance convoy, or
   award no win?
5. Is an operational unmanned vehicle ever eligible to cross, or must its operator
   also be alive?
6. Is the current single-chunk fork acceptable for launch, or must Milestone 2 gain
   full multi-chunk branch/reconvergence?
