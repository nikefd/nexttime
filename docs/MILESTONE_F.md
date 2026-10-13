# Milestone F — Long-term progressive practice

Date: 2026-10-13

## Goal

Replace the short, repeating seven-day starter loop with a local-first program that can support continued practice without treating “more effort” as progress.

## What changed

- Expanded the active library from 8 to 24 guided courses: 6 each for foundation, relaxation, body confidence, and partner connection.
- Increased every active timed course to 3–12 minutes. Interactive instructions and partner prompts remain untimed so people can proceed at their own pace.
- Added distinct course themes for coordination, sustainable endurance, whole-body release, recovery, flexible pacing, boundaries, repair, and shared choice.
- Replaced the home-screen seven-day loop with a 42-day / six-week progressive plan.
- Added two recovery-focused days per week. Recovery days select relaxation rather than increasing contraction volume.
- Added recent-session avoidance using the four most recently completed program identifiers.
- Added maintenance mode after day 42 so the recommendation rotates through relevant courses instead of remaining stuck on the final day.
- Preserved the milestone E safety override: discomfort, low comfort, high tension, low energy, and warning symptoms can still lower intensity, choose recovery, or pause practice.

## Privacy and safety boundaries

- Planning and recent-session selection run fully on device.
- No diagnosis, treatment claim, cloud profile, or sensitive-data upload was added.
- Progression does not continuously increase contraction force or duration. Later courses emphasize coordination, choice, full release, and recovery.
- Course content remains a product draft pending review by a suitably qualified professional.

## Verification

- Both localization files pass `plutil -lint` and contain no duplicate keys.
- The full app source type-checks for the iOS 16 simulator SDK using the installed Swift compiler.
- A standalone model check confirms 24 unique courses, 6 courses per route, 3–12 minute timed duration, a 42-day plan with 12 recovery days, and maintenance mode after six weeks.
- Unit tests cover library size/duration, six-week structure, recent-session avoidance, and maintenance transition.
- Local `xcodebuild test` remains unavailable until the machine owner accepts the installed Xcode license; GitHub Actions is the authoritative full test run.
