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

See [the game design document](docs/GAME_DESIGN_DOCUMENT.md) for the agreed scope and milestone plan.

---

## 📄 License & Contact

- **Catchphrase**: *"Drive Angry"*
- **Platform**: Roblox
