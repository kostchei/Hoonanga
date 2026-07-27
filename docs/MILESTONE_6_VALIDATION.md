# Milestone 6 validation

Milestone 6 owns content completeness and launch preparation. Rival AI
personalities, six-competitor stress, final-stretch generation, finish crossing,
and drop-off-the-back remain Milestone 7.

## Implemented scope

- Five-family chunk catalog with four normal, two hazard, and two transition
  definitions per family.
- Four physically distinct fork sets: fuel/mud, ammunition/rock,
  repair/oil, and split supplies.
- Eight temporary run upgrades, meeting the initial 8-12 target.
- Environment horizon, biome palettes, deterministic art sets, curved-road
  metadata, and bounded chunk recycling.
- Pooled rear-contact dust for moving vehicles on dry dirt, stone, sand, and
  salt; explicitly disabled on mud and asphalt and reduced in low-performance
  mode.
- Distinct pickup props: an open handled ammunition crate with visible and
  hanging rounds, plus a handled fuel jerrycan with cap and pouring spout.
- Reference-driven Roadtrain art with eight visible wheels, armored cab and
  cargo body, roof hatches, side pipework, vents, gun shields, and front ram.
- Engine-load audio, weapon/impact/pickup cues, low-fuel and fire warnings,
  spatial rolloff, cleanup, and optional subtitles.
- Persistent onboarding completion using authoritative curved-road distance.
- Complete controller path for driving, camera/aim, firing, reload,
  handbrake, weapon cycling, and settings.
- Persistent FOV, screen shake, color-vision mode, subtitles, and reduced
  flashing settings.
- Adaptive low-performance mode with hysteresis, reduced tracer load, and
  lower-frequency horizon updates.
- Roblox custom/economy analytics transport with sanitized local diagnostics.
- Bounded catch-up pickup bonuses and hard run-reward ceilings.
- Central build/version metadata, asset credits, and publication checklist.

## Automated acceptance

The Milestone 6 suite consists of:

| Test | Coverage |
|---|---|
| `environment_biome_test.luau` | Five biomes and required content-library counts |
| `milestone6_content_runtime_test.luau` | Runtime variants, all four fork sets, active chunk budget |
| `audio_engine_test.luau` | Engine range, weapon cues, warning subtitles |
| `onboarding_flow_test.luau` | Ordered onboarding and curved-distance thresholds |
| `gamepad_input_test.luau` | Bindings, deadzones, drive composition, weapon cycling |
| `analytics_event_test.luau` | Sanitized telemetry and bounded economy tuning |
| `progression_datastore_test.luau` | Schema v3 accessibility/tutorial migration |
| `milestone6_performance_policy_test.luau` | Low-mode hysteresis and stress budgets |
| `milestone6_dust_policy_test.luau` | Rear-contact selection, dry-surface gating, performance scaling |
| `milestone6_pickup_art_test.luau` | Ammo-crate/fuel-can silhouettes, collection roots, collision safety |
| `milestone6_roadtrain_art_test.luau` | Eight-wheel armored silhouette, reference details, texture targets, weld/collision safety |

The prior smoke, combat, road, convoy, and Milestone 5 suites remain regression
requirements.

## Representative-device manual matrix

Capture median and worst one-percent frame rate, client memory, server frame
time, physics time, and network receive rate for at least ten minutes.

| Tier | Representative target | Acceptance |
|---|---|---|
| Low mobile | Lowest supported phone/tablet available | Adaptive mode engages; controls remain responsive; no crash |
| Mid mobile | Common current phone/tablet | Stable 30 FPS target |
| Desktop minimum | Integrated graphics / low settings | Stable 45 FPS target |
| Desktop recommended | Discrete GPU / high settings | Stable 60 FPS target |
| Controller | Xbox-compatible controller on PC/console test | Every gameplay and menu action reachable |

Use the stress composition from the GDD: twelve combat vehicles, at least ten
active chunks including a fork, simultaneous gunfire, two fire areas, pickups,
and wrecks. A manual profile is still required because headless Studio cannot
certify GPU, touch ergonomics, console safe zones, or real network latency.

## Exit status

Milestone 6 is code-complete when its automated suite and regressions pass. Its
launch exit gate remains open until the published-place analytics check,
representative-device matrix, MicroProfiler capture, asset-permission check,
and Creator Dashboard compliance tasks are recorded.
