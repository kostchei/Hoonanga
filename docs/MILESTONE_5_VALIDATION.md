# Milestone 5 validation

Milestone 5 owns the human multiplayer session foundation. Milestone 7 extends
that foundation with three-to-six total competitors, exactly two AI players,
rival personality traits, the final stretch, finish crossing, and
drop-off-the-back.

## Implemented scope

- Server-authoritative Lobby, Countdown, InRun, and Results phases.
- Deterministic one-to-four-human ready roster with overflow spectators; two
  session-owned AI rivals complete the three-to-six competitor roster.
- Lobby-only class and loadout selection; readying locks the selection.
- Session-owned convoy spawn, elimination, spectating, ranking, and cleanup.
- Shared road and fork geometry for every convoy in the session.
- Versioned persistent profile for credits, wins, races, podiums, DNFs,
  distances, kills, class mastery, owned vehicles, weapons, and cosmetics.
- Legacy Scrap/Biker profile migration into the current schema, save retries, and protection against
  overwriting real data after a failed read.
- Idempotent run rewards using persisted processed run IDs.
- Purchasable/equippable paint presets and persistent starting weapons.
- Server-generated three-choice temporary run upgrades with authoritative
  claim validation and live hull, fuel, speed, grip, and cooling modifiers.
- Server validation and rate limits on lobby, vehicle, weapon, spectate, and
  upgrade requests.
- Phase-owned mouse behavior: unlocked in Lobby, Countdown, Results,
  spectating, and modal selection; locked for active driving.

## Automated acceptance

The following tests pass in authenticated headless Roblox Studio:

| Test | Coverage |
|---|---|
| `milestone5_service_start_test.luau` | Service startup, remotes, lobby state, garage availability |
| `multiplayer_session_test.luau` | Human/AI bounds, deterministic admission, overflow cap |
| `milestone4_session_convoy_integration_test.luau` | Session-owned AI rivals, class coverage, teammates, three/six competitor runtime rosters |
| `progression_datastore_test.luau` | Legacy migration, ownership defaults, untrusted field rejection |
| `milestone5_upgrade_authority_test.luau` | Seeded unique server upgrade offers and offer bounds |
| `milestone5_input_mode_test.luau` | Mouse and gameplay-input policy for every relevant phase |

The existing smoke, combat, convoy composition, control transfer, and convoy
failure tests also pass after the Milestone 5 lifecycle changes.

## Manual exit gate

The GDD exit condition still requires a published-place multiplayer soak under
realistic latency. Validate with one, two, three, and four human clients:

1. Ready/unready during countdown, including a disconnect.
2. Deterministic admission when five clients ready simultaneously.
3. Class/loadout lock throughout the run.
4. Shared fork occupancy and convoy-to-convoy combat under latency.
5. Partial convoy loss, complete elimination, spectate cycling, and results.
6. Rejoin and server restart persistence for rewards and cosmetics.
7. Repeated or malformed remote requests without duplicated rewards/upgrades.
8. Return to Lobby with no stale convoy, camera, mouse, or input state.

Milestone 5 is code-complete when the automated suite passes. Its full exit
condition is accepted only after this manual soak is recorded.
