# Vehicle Upgrades & Performance Specifications

This document records the physical baselines and planned future upgrade paths for vehicles in **Hoonanga**, starting with the **Ute**.

---

## 1. Ute Baseline (Current Active Model)

The active in-game Ute is modeled after a **Stock 1969 Charger-style V8 Ute** with a single driver and light weaponry.

### Stock Performance Baseline
- **Engine:** 440 Magnum V8 (375 hp / 651 Nm)
- **Crew:** Single driver
- **Payload:** Light guns and basic ammo only
- **0–100 km/h Acceleration:** ~6.2 – 6.4 seconds
- **1/4-Mile (402 m):** ~13.9 – 14.3 seconds @ 163 km/h
- **Top Speed:** ~209 – 217 km/h (*Aerodynamically capped by recessed rear window drag and factory drag axle ratio*)
- **In-Game Physics Mapping:**
  - `MaxForwardSpeed`: `112 studs/sec` (~212 km/h scaled)
  - `Acceleration`: `52 studs/sec^2`
  - `MaxHull`: `100`

---

## 2. Planned Future Performance & Gear Upgrades (Not Implemented Yet)

These upgrade paths are documented for future implementation as garage / progression features in Milestone 5+.

### Engine Upgrade Option: 426 Street Hemi V8
- **Specs:** 426 Hemi V8 (425 hp / 664 Nm)
- **0–100 km/h:** ~5.5 – 5.7 seconds
- **1/4-Mile:** ~13.5 seconds @ 169+ km/h
- **Top Speed:** ~225 – 233 km/h
- **Planned Attribute Modifiers:**
  - `Acceleration`: `+15%`
  - `MaxForwardSpeed`: `+8%`
  - `ThrottleFuelPerSecond`: `+20%`

### Rear Axle & Gear Ratio Tuning Options
1. **Drag Racing Axle (High Final Drive Ratio):**
   - **Effect:** Faster 0–100 km/h launch and higher low-speed torque.
   - **Trade-off:** Lower top speed cap due to high engine RPM at speed.
2. **Highway Cruising Axle (Low Final Drive Ratio):**
   - **Effect:** Higher top speed and better fuel efficiency at cruise.
   - **Trade-off:** Slower initial acceleration off the line.

---

## 3. Planned Combat Weight & Payload Scaling (Not Implemented Yet)

Future progression will allow equipping heavy armor and additional crew, which dynamically alters mass and performance:

| Upgrade Component | Mass Impact | Performance Impact | Gameplay Benefit |
|---|---|---|---|
| **Full Crew (3 Passengers)** | +270 kg | -5% Acceleration | Enables 360-degree passenger firing angles |
| **Heavy Rollcage & Armor** | +350 kg | -12% Acceleration, -8% Top Speed | +40% Hull durability (`MaxHull = 140`) |
| **Roof Turrets & Heavy Ammo** | +380 kg | -15% Acceleration, +25% Aero Drag | High firepower, +30% Ramming kinetic energy |
| **Full Combat Ute (Loaded)** | **+1,000 kg total** | **Top Speed ~175 km/h** | High durability, maximum firepower & ramming authority |
