# Publication and compliance checklist

This checklist separates repository-complete launch preparation from actions
that must be performed against the published Roblox experience.

## Repository-complete

- [x] All Creator Store assets are credited by asset ID and use.
- [x] Imported models are stripped of executable descendants and have local
  gameplay fallbacks.
- [x] Server authority validates vehicle, weapon, lobby, upgrade, profile, and
  reward mutations.
- [x] Persistent data uses versioned normalization, retries, idempotent run
  rewards, and failed-read overwrite protection.
- [x] Monetization design excludes paid combat, fuel, repair, recovery, and
  statistically superior vehicles.
- [x] No paid random-item system exists.
- [x] Subtitles, reduced flashing, color-vision presets, FOV, and camera-shake
  controls are available and persistent.
- [x] Keyboard/mouse and controller gameplay/menu paths are implemented.
- [x] Analytics event names and fields are server-generated and sanitized.
- [x] Release version and profile schema are centralized in `BuildConfig`.

## Creator Dashboard and published-place gate

- [ ] Complete the current experience maturity and compliance questionnaire,
  accurately declaring vehicle combat, weapons, explosions, and stylized
  violence.
- [ ] Confirm the experience title, description, icon, thumbnails, genre, and
  supported devices match the shipped build.
- [ ] Activate Creator Dashboard analytics and confirm `MatchStarted`,
  `ConvoyEliminated`, `MatchCompleted`, `RunRewarded`, `CurrencySource`, and
  `CurrencySink` events arrive from a published server.
- [ ] Enable Studio API access only in a dedicated test universe; never point
  local destructive tests at production profile data.
- [ ] Validate DataStore v1/v2-to-v3 migration with a non-production account.
- [ ] Confirm every referenced audio and Creator Store asset is permitted for
  the publishing owner/group and loads in the published experience.
- [ ] Review text, thumbnails, and audio against Roblox Community Standards
  and regional requirements on the publication date.
- [ ] Run the two-, three-, and four-client Milestone 5 latency soak.
- [ ] Run the representative-device matrix in `MILESTONE_6_VALIDATION.md`.
- [ ] Record server/client MicroProfiler captures for the stress scenario.
- [ ] Set `BuildConfig.ReleaseChannel` to `production` only after every manual
  gate above is signed off.
