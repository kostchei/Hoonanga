# Hoonanga 🏎️💨

> *"Drive Angry"*

Welcome to **Hoonanga**, a high-octane Roblox driving experience built for speed, chaos, and adrenaline-fueled action!

---

## 🚘 Overview

**Hoonanga** is a Roblox game centered around aggressive driving, custom vehicles, high-stakes chases, and competitive mayhem. Get behind the wheel, channel your fury, and dominate the asphalt.

### 🌟 Key Features
- **High-Octane Vehicle Mechanics**: Responsive driving physics tuned for high speed, drifting, and collisions.
- **Custom Garage & Upgrades**: Unlock, tune, and customize ruthless vehicles.
- **Dynamic Tracks & Arenas**: Action-packed environments designed for chaotic combat and racing.
- **Competitive Action**: Dominate rivals on the road and carve your path to the top.

---

## 🛠️ Project Structure & Setup

This repository uses **Rojo** to sync version-controlled Luau code into Roblox Studio.

### Requirements & Recommended Tools
- [Roblox Studio](https://create.roblox.com/)
- [Rokit](https://github.com/rojo-rbx/rokit) (Pinned Roblox toolchain manager)
- [Rojo](https://rojo.space/) (Filesystem-to-Studio synchronization)

### Development Workflow
1. **Clone the repository**:
   ```bash
   git clone https://github.com/kostchei/Hoonanga.git
   ```
2. **Install the pinned tools**:
   ```bash
   rokit install
   ```
3. **Install the Rojo Studio plugin**:
   ```bash
   rojo plugin install
   ```
4. **Start Rojo live sync**:
   ```bash
   rojo serve
   ```
5. Open **Roblox Studio**, connect the Rojo plugin to `localhost:34872`, and sync.

### Validation

```bash
stylua --check src
selene src
rojo build default.project.json --output build/Hoonanga.rbxlx
```

The Studio tests run headlessly through Roblox Studio's command-line `RunScript`
task. `scripts/run_studio_test.sh` builds the place, runs a test script against
it and fails unless the test prints its success line:

```bash
scripts/run_studio_test.sh default.project.json scripts/studio_smoke_test.luau smoke '^\[SMOKE\] PASS: [0-9]'
```

| Test script | Name | Success pattern |
|---|---|---|
| `scripts/studio_smoke_test.luau` | `smoke` | `^\[SMOKE\] PASS: [0-9]` |
| `scripts/combat_test.luau` | `combat` | `^\[COMBAT\] PASS:` |
| `scripts/road_coverage_test.luau` | `coverage` | `^\[COVERAGE\] PASS:` |
| `scripts/road_curve_test.luau` | `curve` | `^\[CURVE\] PASS:` |
| `scripts/road_recycle_test.luau` | `recycle` | `^\[RECYCLE\] PASS:` |
| `scripts/road_seed_test.luau` | `seed` | `^\[SEED\] PASS:` |
| `scripts/concurrent_vehicle_test.luau` | `concurrent` | `^\[CONCURRENT\] PASS:` |
| `scripts/sky_test.luau` | `sky` | `^\[SKY\] PASS:` |
| `scripts/convoy_composition_test.luau` | `convoy-composition` | `^M4_CONVOY_COMPOSITION_OK$` |
| `scripts/control_transfer_test.luau` | `control-transfer` | `^M4_CONTROL_TRANSFER_OK$` |
| `scripts/shared_fuel_test.luau` | `shared-fuel` | `^M4_SHARED_FUEL_OK$` |
| `scripts/companion_formation_test.luau` | `companion-formation` | `^M4_COMPANION_FORMATION_OK$` |
| `scripts/companion_combat_test.luau` | `companion-combat` | `^M4_COMPANION_COMBAT_OK$` |
| `scripts/convoy_failure_test.luau` | `convoy-failure` | `^M4_CONVOY_FAILURE_OK$` |
| `scripts/convoy_seed_balance_test.luau` | `convoy-balance` | `^M4_CONVOY_BALANCE_OK$` |
| `scripts/convoy_stress_test.luau` | `convoy-stress` | `^M4_CONVOY_STRESS_OK$` |
| `scripts/milestone4_session_convoy_integration_test.luau` | `m4-session-convoy` | `^\[M4_SESSION_CONVOY\] PASS:` |
| `scripts/milestone5_service_start_test.luau` | `m5-start` | `^\[M5_START\] PASS:` |
| `scripts/multiplayer_session_test.luau` | `m5-session` | `^\[SESSION\] PASS:` |
| `scripts/progression_datastore_test.luau` | `m5-progression` | `^\[PROGRESSION\] PASS:` |
| `scripts/milestone5_upgrade_authority_test.luau` | `m5-upgrade` | `^\[M5_UPGRADE\] PASS:` |
| `scripts/milestone5_input_mode_test.luau` | `m5-input` | `^\[M5_INPUT\] PASS:` |
| `scripts/environment_biome_test.luau` | `m6-environment` | `^\[ENVIRONMENT\] PASS:` |
| `scripts/milestone6_content_runtime_test.luau` | `m6-content` | `^\[M6_CONTENT\] PASS:` |
| `scripts/audio_engine_test.luau` | `m6-audio` | `^\[AUDIO\] PASS:` |
| `scripts/onboarding_flow_test.luau` | `m6-onboarding` | `^\[TUTORIAL\] PASS:` |
| `scripts/gamepad_input_test.luau` | `m6-controller` | `^\[GAMEPAD\] PASS:` |
| `scripts/analytics_event_test.luau` | `m6-analytics` | `^\[ANALYTICS\] PASS:` |
| `scripts/milestone6_performance_policy_test.luau` | `m6-performance` | `^\[M6_PERFORMANCE\] PASS:` |
| `scripts/milestone6_service_start_test.luau` | `m6-start` | `^\[M6_START\] PASS:` |
| `scripts/milestone6_dust_policy_test.luau` | `m6-dust` | `^\[M6_DUST\] PASS:` |
| `scripts/milestone6_pickup_art_test.luau` | `m6-pickup-art` | `^\[M6_PICKUP_ART\] PASS:` |
| `scripts/milestone6_roadtrain_art_test.luau` | `m6-roadtrain-art` | `^\[M6_ROADTRAIN_ART\] PASS:` |

### Lobby and match controls

Convoy class, starting primary weapon, and paint preset are selected in the
lobby garage. Readying locks the selection for that match.

- `F1`: select roadtrain while in the lobby
- `F2`: select two-ute convoy while in the lobby
- `F3`: select three-bike convoy while in the lobby
- `G`: show or hide the garage during lobby/countdown
- `Q` / `E`: cycle valid spectate targets after elimination

The mouse is visible and unlocked in Lobby, Countdown, Results, spectating,
and modal upgrade selection. It is locked only for active driving. Control
transfers automatically after vehicle or operator loss.

See [the game design document](docs/GAME_DESIGN_DOCUMENT.md) for the agreed scope and milestone plan.

---

## 📄 License & Contact

- **Catchphrase**: *"Drive Angry"*
- **Platform**: Roblox
