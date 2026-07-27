# Milestone 7: Rival Convoy Endgame — Implementation Plan

**Status:** In progress — roster and per-vehicle personality foundations operational  
**Milestone:** 7 — Rival Convoy Endgame  
**Design reference:** `docs/MATCH_FLOW_AND_ROAD_ENDGAME_PLAN.md`  
**Roadmap source of truth:** `docs/GAME_DESIGN_DOCUMENT.md`

## 1. Goal

Turn the endless-road sandbox into a bounded competitive match without replacing
the endless-road generator.

Every match contains three to six competitors:

- One to four human players.
- Exactly two server-owned AI players.
- At least one Roadtrain, one Ute, and one Bike across the combined roster.

The first complete competitor-convoy elimination starts a final stretch. The next
road chunk that did not exist at the moment of elimination becomes the finish
chunk. The first competitor to move any operational convoy vehicle across the
server-authoritative finish distance wins.

## 2. Exit condition

Milestone 7 is complete when:

> Repeated three-to-six-competitor matches, with exactly two distinct AI rivals,
> reliably transition from endless racing into one final stretch, produce one
> server-confirmed winner at the reserved finish chunk, apply fair drop-off rules,
> and preserve correct results under realistic latency.

The exit condition is not satisfied by configuration checks, one-step AI output,
registry-only stress tests, or visual `Touched` events.

## 3. Relationship to earlier milestones

### Milestone 5 remains responsible for

- Authoritative session state.
- Lobby selection and readiness.
- Class locking once a run starts.
- Convoy spawning and cleanup through the session.
- Spectating and results.
- Profile loading/saving, wins, credits, mastery, cosmetics, and vehicles.
- Anti-exploit validation.
- Visible, unlocked mouse in Lobby and Results.

Milestone 7 consumes those systems; it does not create a second lobby, result, or
persistence implementation.

### Milestone 6 remains responsible for

- Launch content.
- Audio and environmental presentation.
- Controller and accessibility coverage.
- Device/performance validation.
- Analytics transport, economy tuning, and publication preparation.

Milestone 7 adds telemetry events and stress scenarios, while Milestone 6 owns the
production telemetry destination and release-quality presentation.

### Milestone 7 adds

- Three-to-six total competitors with exactly two AI players.
- AI selection of alternatives humans did not choose.
- Independently rolled AI personality values per vehicle.
- Proactive aggression behavior.
- Damage-triggered taunt and vendetta responses.
- Final-stretch and finish-chunk reservation.
- Server-authoritative finish crossing.
- Drop-off-the-back warning, grace, and DNF.
- Six-competitor race and 15-vehicle stress validation.

## 4. In scope

- One to four human roster slots.
- Exactly two AI roster slots.
- Match-seeded AI class allocation.
- Match-seeded, per-vehicle Speed, Accuracy, Aggression, and Vendetta.
- AI player support for Roadtrain, Ute, and Bike.
- Final-stretch state.
- Finish reservation in the next ungenerated road chunk.
- Finish gate generation and lifecycle protection.
- Server crossing validation using road-path distance.
- Drop-off distance, warning, hysteresis, grace, and DNF.
- Human and AI result integration.
- Win attribution through Milestone 5's idempotent reward transaction.
- Match telemetry needed to reproduce AI and endgame behavior.

## 5. Out of scope

- New convoy classes.
- New weapons or damage channels.
- Unlocking required base convoy classes.
- A second persistent currency.
- Client-authoritative finish or drop-off claims.
- AI speed, damage, ammunition, or movement cheats.
- Full multi-chunk fork replacement.
- Mobile adaptation beyond Milestone 6's device work.
- New environment-art or audio-content passes.
- Convoy-wide vendetta; the first implementation uses per-vehicle taunts.

## 6. Locked defaults

These values are initial tuning defaults:

| Rule | Default |
|---|---:|
| Minimum total competitors | 3 |
| Maximum total competitors | 6 |
| Human competitors | 1–4 |
| AI competitors | Exactly 2 |
| AI Speed | 90–98% |
| AI Accuracy | 50–95% |
| AI Aggression | 25–95% |
| AI Vendetta | 25–95% |
| Drop-off warning | 4 chunks / 2,048 studs |
| Drop-off DNF threshold | 6 chunks / 3,072 studs |
| Drop-off grace | 20 seconds |
| Drop-off recovery threshold | 5 chunks / 2,560 studs |
| Start grace | 60 seconds |
| Control-transfer grace | 15 seconds |

All road distances use authoritative path distance, never world Z.

## 7. Checkpoint plan

### Checkpoint 0 — Dependency gate

**Goal:** Confirm Milestone 7 is being built on operational Milestone 5 systems.

#### Required evidence

- Lobby-to-results session state works without Milestone 7 endgame rules.
- Convoy elimination reaches session state exactly once.
- Class changes are rejected outside Lobby.
- Lobby and Results keep a visible, unlocked mouse for multiple rendered frames.
- Human results can save one idempotent run transaction.
- RoadService exposes deterministic next-uncreated-chunk state.

#### Completion gate

- No known session-ending, class-lock, mouse-state, or persistence blocker remains.
- Milestone 1–4 regressions still pass.

---

### Checkpoint 1 — Six-competitor roster and AI class allocation

**Goal:** Build the combined human-plus-AI roster deterministically.

#### Work

- Admit one to four ready humans.
- Add exactly two AI players to every active roster.
- Count human Roadtrain, Ute, and Bike selections.
- For each AI slot:
  1. Prefer a class no human selected.
  2. Recount the combined roster.
  3. When all classes are represented, choose among the least-represented classes.
  4. Use the match seed for tie-breaking.
- Give each AI player a stable competitor ID, display name, convoy ID, and result
  record.
- Spawn all competitors at safe deterministic offsets.
- Allow AI competitors to spectate only through debug tooling; they otherwise
  remain server-owned entities.

#### Completion gate

- Total roster size is always three to six.
- Exactly two entries are AI.
- Roadtrain, Ute, and Bike are always represented.
- The same seed and human selections produce the same AI classes.
- AI competitors can be ranked, eliminated, and declared winners.

---

### Checkpoint 2 — Per-vehicle AI personality

**Goal:** Give every AI vehicle a distinct, reproducible driving/combat character.

#### Work

Roll these independently for each vehicle:

```text
Speed      0.90–0.98
Accuracy   0.50–0.95
Aggression 0.25–0.95
Vendetta   0.25–0.95
```

Seed each roll from:

```text
match seed
AI roster slot
convoy class
vehicle formation slot
trait identifier
```

Store values in server controller state and mirror read-only attributes for
debugging and telemetry. Never reroll after control transfer, recovery, target
change, or temporary separation.

#### Trait meanings

- **Speed:** Multiplies the class's configured maximum speed. It never bypasses
  movement validation.
- **Accuracy:** Changes server-side aim error and prediction quality. It never
  bypasses spread, obstruction, range, ammunition, heat, or fire rate.
- **Aggression:** Proactive hostility. It controls ammunition expenditure,
  voluntary burst cadence, unprovoked target acquisition, ramming attempts, and
  how often the vehicle turns back to start an attack.
- **Vendetta:** Reactive retaliation. Validated incoming enemy damage creates a
  taunt; vendetta controls whether the damaged vehicle returns fire, attempts a
  ram, turns back, or retains that attacker for a bounded retaliation window.

#### Completion gate

- Every AI vehicle has all four values in range.
- Vehicles in one convoy have independent rolls.
- Same-seed rolls reproduce exactly.
- Different seeds materially vary the roster.
- No trait bypasses server authority.

---

### Checkpoint 3 — AI driving and combat behavior

**Goal:** Make Roadtrain, Ute, and Bike AI competitors viable without making them
uniform.

#### Work

- Generalize AI state from the singleton enemy Ute to all AI competitor vehicles.
- Add Roadtrain-specific look-ahead, braking, turn radius, width clearance, and
  safe ram approach.
- Add Bike-specific staggered formation, narrow-road compression, early curve
  steering, separation, and exposed-rider behavior.
- Retain Ute as the balanced baseline.
- Implement proactive aggression:
  - Ammunition budget.
  - Voluntary engagement chance.
  - Turn-back attack chance and cooldown.
  - Safe ram preference.
- Convert validated enemy damage into a per-vehicle taunt:
  - Source convoy and vehicle.
  - Damage channel and amount.
  - Time received.
  - Relative road position.
- Implement vendetta responses:
  - Return fire.
  - Safe ram.
  - Turn back.
  - Bounded target retention.
- Keep road progress and finish priority above indefinite combat pursuit.

#### Completion gate

- High aggression spends more ammunition and initiates more attacks than low
  aggression.
- Aggression alone does not create taunts.
- High vendetta responds to controlled damage more frequently than low vendetta.
- Vendetta does nothing without a validated taunt.
- Responses expire and reject destroyed, friendly, or unreachable targets.
- Every class completes fixed-seed traversal within tuned failure limits.

---

### Checkpoint 4 — Final stretch and finish reservation

**Goal:** Convert the endless run into a race to one future finish after the first
complete competitor elimination.

#### Work

- Add `FinalStretch` to SessionService.
- Listen to human and AI convoy elimination through one idempotent path.
- On the first elimination:
  - Freeze the eliminated result.
  - Reserve RoadService's next uncreated chunk index.
  - Publish final-stretch state and finish-pending feedback.
- Repeated eliminations return the existing reservation.
- When the reserved chunk is generated:
  - Add a non-blocking finish gate 65–75% through the chunk.
  - Publish finish chunk index and path distance.
  - Keep the chunk active through Results.
  - Suppress hazards directly on the crossing line.

#### Completion gate

- The reservation always targets a chunk absent at trigger time.
- Exactly one finish is created.
- The same match seed and trigger point produce the same finish index/distance.
- Chunk recycling cannot remove the finish before Results.
- Combat, drop-off, and disconnect eliminations follow the configured trigger rule.

---

### Checkpoint 5 — Authoritative finish crossing

**Goal:** Confirm one winner from actual convoy progress.

#### Work

- Check operational vehicles on a fixed server interval.
- Require previous path distance below and current distance at/above the finish.
- Require plausible forward movement.
- Resolve the vehicle to its competitor and convoy.
- Atomically claim the winner.
- Reject:
  - Wrecks.
  - Dead/unmanned vehicles under the final operator rule.
  - Characters.
  - Detached parts.
  - Projectiles.
  - Client finish claims.
- Use touch only for post-confirmation effects.

#### Completion gate

- Any eligible member of Roadtrain, Ute, or Bike can win.
- One server step containing multiple crossings produces one deterministic winner.
- Control transfer does not reset eligibility or distance.
- The eliminated convoy cannot roll a wreck across the line to win.
- Results and persistent win attribution occur once.

---

### Checkpoint 6 — Drop-off-the-back

**Goal:** Bound extreme trailing distance without punishing recoverable setbacks.

#### Work

- Measure gap from the leading active competitor using convoy path progress.
- Apply start and transfer grace.
- Warn at four chunks.
- Start a continuous timer beyond six chunks.
- Clear the timer only after recovering inside five chunks.
- Show gap and remaining grace in the HUD.
- On expiry:
  - End with `DroppedOffBack`.
  - Award no combat kill.
  - Freeze distance/statistics.
  - Spectate the human, if any.
  - Clean vehicles after a bounded delay.
  - Trigger FinalStretch if this is the first elimination.

#### Completion gate

- Short spikes outside the threshold do not eliminate a competitor.
- Recovery hysteresis prevents timer flicker.
- Control transfer grace works.
- AI and human competitors follow the same rule.
- A dropped competitor cannot retain road chunks indefinitely.

---

### Checkpoint 7 — Results, telemetry, balance, and stress

**Goal:** Prove the entire Milestone 7 match under realistic load.

#### Work

- Include human and AI competitors in the same authoritative ranking.
- Write persistent wins/credits only for humans through Milestone 5's transaction.
- Record:
  - Match seed and run ID.
  - Human and AI class allocation.
  - Per-vehicle AI rolls.
  - Ammunition spent.
  - Voluntary aggression engagements.
  - Taunts received and vendetta responses.
  - Turn-backs and rams.
  - Drop-off warnings/DNFs.
  - Finish reservation, spawn, and crossing evidence.
- Run repeated matches at representative latency.
- Run the worst-case 15-vehicle roster with projectiles and active fire.
- Tune personality outcomes without narrowing the configured roll ranges unless
  evidence requires a design change.

#### Completion gate

- Repeated matches produce no duplicate finish, winner, reward, or result.
- AI can win but does not dominate every class/seed.
- Low/high aggression and vendetta cohorts are measurably distinct.
- No severe Studio errors accumulate in repeated full matches or soak tests.
- Static checks, Rojo build, and all Milestone 1–7 automated regressions pass.

## 8. Planned test additions

```text
ai_class_allocation_test.luau
ai_personality_roll_test.luau
ai_aggression_budget_test.luau
ai_taunt_response_test.luau
roadtrain_ai_traversal_test.luau
bike_ai_traversal_test.luau
finish_reservation_test.luau
finish_crossing_test.luau
drop_off_test.luau
six_competitor_match_test.luau
six_competitor_stress_test.luau
milestone_7_soak_test.luau
```

Each test must exercise runtime behavior rather than only checking that
configuration values exist.

## 9. Completion checklist

- [x] One to four humans can enter a match.
- [x] Exactly two AI competitors always enter.
- [x] Combined roster contains Roadtrain, Ute, and Bike.
- [x] AI chooses unselected human classes first.
- [x] Every AI vehicle gets independent, reproducible personality rolls.
- [ ] Aggression governs proactive attacks and ammunition use.
- [ ] Enemy damage creates per-vehicle taunts.
- [ ] Vendetta governs retaliation to those taunts.
- [ ] Roadtrain, Ute, and Bike AI complete fixed-seed traversal.
- [ ] First complete competitor elimination starts FinalStretch once.
- [ ] The next ungenerated chunk becomes the finish chunk.
- [ ] One eligible operational convoy vehicle crossing produces one winner.
- [ ] Drop-off warning, grace, recovery, and DNF work.
- [ ] AI appears in results but receives no profile write.
- [ ] Human win/credits are persisted exactly once.
- [ ] Six-competitor, 15-vehicle stress is stable.
- [ ] Realistic-latency full matches pass.
- [ ] Earlier milestone regressions pass.

## 10. Remaining design confirmations

1. Does disconnect trigger FinalStretch immediately or after reconnect grace?
2. Is an unmanned but otherwise operational vehicle eligible to cross?
3. Does a no-finisher result award no win or award the greatest-distance
   competitor?
4. Are six chunks and 20 seconds the correct launch values for drop-off?
