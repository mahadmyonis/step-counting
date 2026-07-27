# StepCounting

A SwiftUI iOS app that reads your activity from **Apple Health** and turns it into something you'll actually keep doing: streaks that survive a bad day, badges worth chasing, private crews of people you know, and challenges you race them in — including virtual routes like the Camino and Route 66.

No account. No server. No global leaderboard full of strangers.

## Why it's built this way

The feature set is a direct response to what actually retains people in fitness apps:

- **Social beats solo.** Apps with challenges, leaderboards, or friend connections see materially lower monthly churn than solo-experience apps, and competing with people you *know* motivates more than competing with strangers. Hence: small, invite-only crews and no public leaderboard anywhere.
- **Streaks work, but only if they can survive real life.** Streak freezes are the standard fix — one banked freeze a month absorbs a missed day so the flu doesn't end a 60-day run and take the user with it.
- **Templates carry social features.** A blank "create a challenge" form is where these features die; most people won't invent a target. Eight one-tap templates do the inventing.
- **Virtual routes are the differentiator.** "58% of the way to Santiago, next stop Cruz de Ferro" is a reason to walk; "58%" is not.
- **The share moment is the growth loop.** Share cards are offered at the emotional peak — goal hit, badge earned, best day — and carry the user's invite code, so a brag doubles as an invitation.

## Features

### Today
- Layered goal ring with a gold **victory lap** once you pass 100% — beating the goal is the best moment of the day and gets its own visual state.
- Distance, active energy, stairs, and exercise minutes.
- **Streak card** — current run, what's still at risk tonight in steps *and* minutes of walking, banked freezes, and progress to the next milestone.
- Live crew standings for today, plus the exact gap to whoever's leading.
- Hourly "when you moved" chart.
- Pull to refresh; everything recomputes the moment Health hands over new numbers.

### Challenges
- Four formats: **race to target**, **most steps**, **team total**, and **streak duel**.
- Measured in steps, distance, or goal days.
- Eight templates — Weekend Warrior, 100K Week, Marathon Month, Million Step March, Perfect Week, Walk the Camino, Route 66, Climb Everest.
- **Virtual routes** with landmark milestones and a walker that moves along the track.
- Live standings, pace tracking ("3.2k ahead of pace"), and a custom challenge builder.

### Crews
- Private, invite-code based. Create one or join with a 6-character code.
- Today / this-week leaderboards.
- **Activity feed** with one-tap cheers.
- Share sheet built around your invite code.

### Progression
- **25 badges** across bronze / silver / gold / legendary, covering volume, streaks, consistency, distance, stairs, timing (Early Bird, Night Owl), and social milestones. Locked badges stay visible with live progress — a badge you can see yourself approaching is a goal.
- **Levels and XP** derived from steps, goal days, badges, and challenge wins. Levels never go down, which is the counterweight to a streak that can vanish overnight.

### Elsewhere
- Four-screen onboarding that ends with a goal set, Health connected, and a crew to walk against.
- **Share cards** — rendered images carrying your stat, streak, and invite code.
- **Reminders** — at most two, and only when something is at stake: an evening nudge when the goal is genuinely within reach, and a last call when a live streak isn't safe. There is deliberately no generic "come back!" notification.

## About the social data

There is no backend in this build. `SocialService` is the seam one plugs into:

```swift
protocol SocialService: AnyObject {
    func crew(forInviteCode code: String) async throws -> CrewBundle
    func createCrew(name: String, emoji: String, accentIndex: Int, owner: UserProfile) async throws -> CrewBundle
    func publish(history: [DailyActivity], profile: UserProfile) async throws
    func refresh(crew: Crew, knownMembers: [Friend]) async throws -> [Friend]
}
```

`LocalSocialService` implements it entirely on-device: every crew is derived deterministically from its invite code, so two people who type the same code see the same crew name, the same members, and the same histories — the social loop is fully playable offline. **Crew-mates' step numbers are simulated**, which the app states plainly on any crew it generated. When a real backend exists, it fills `Friend.reportedSteps` and nothing else in the app changes.

## Requirements

- Xcode 16 or later
- iOS 17.0+ deployment target
- A device or simulator with Health data (HealthKit isn't available on Mac; use an iPhone simulator or device)

## Getting started

1. Open `StepCounting.xcodeproj` in Xcode.
2. Select the **StepCounting** scheme and an iPhone simulator or device.
3. Set your own signing team on the target (Signing & Capabilities). The **HealthKit** capability, including background delivery, is configured via `StepCounting/StepCounting.entitlements`.
4. Build and run. Grant Health access when prompted, and accept the sample crew in onboarding so the leaderboards have something in them.

> Tip: In the simulator, open the **Health** app and add sample step / walking+running distance / active energy data so the charts have something to show.

## Project structure

```
StepCounting/
├── StepCountingApp.swift            # App entry; owns Health, store, notifications
├── Core/
│   ├── Theme.swift                  # Design tokens, glass cards, aurora background
│   ├── ConfettiView.swift           # Canvas confetti + celebration overlay
│   ├── Randomness.swift             # Seeded PRNG, invite codes
│   └── Formatting.swift             # Number, distance, and countdown formatting
├── Models/
│   ├── DailyActivity.swift          # Per-day metrics + aggregate helpers
│   ├── StatsRange.swift             # Week / month / 90 days
│   ├── Social.swift                 # Profile, levels, friends, crews, feed
│   ├── Challenge.swift              # Formats, metrics, standings, templates
│   ├── VirtualRoute.swift           # Camino, Route 66, Everest + landmarks
│   ├── Achievement.swift            # Badge catalog and requirements
│   └── StreakState.swift            # Streak + freeze state
├── Services/
│   ├── HealthKitManager.swift       # All HealthKit reads and observers
│   ├── AppStore.swift               # Root state, persistence, sync
│   ├── SocialService.swift          # Backend seam + on-device implementation
│   ├── StreakEngine.swift           # Streak and freeze arithmetic
│   ├── ChallengeEngine.swift        # Standings, pace, winners
│   └── NotificationScheduler.swift  # Local reminders
├── Views/
│   ├── RootView.swift               # Tabs, celebrations, reminder scheduling
│   ├── OnboardingView.swift
│   ├── DashboardView.swift
│   ├── ChallengesView.swift / ChallengeDetailView.swift / NewChallengeView.swift
│   ├── CrewsView.swift / CrewDetailView.swift
│   ├── StatsView.swift
│   ├── AchievementsView.swift
│   ├── ProfileView.swift
│   ├── SettingsView.swift
│   └── Components/                  # Ring, tiles, rows, cards, share card
├── Info.plist
└── StepCounting.entitlements
```

## Architecture notes

- **One source of truth per concern.** `HealthKitManager` owns everything from Health; `AppStore` owns everything else and is the only thing that writes to disk. Screens read published state and call intent methods.
- **Engines are pure functions.** `StreakEngine` and `ChallengeEngine` take inputs and return values — no state, no side effects — so the competitive layer is trivially previewable and testable.
- **XP is derived, never incremented**, so it can't drift or double-count.
- **Sync is idempotent.** Running it twice on the same data changes nothing and celebrates nothing twice.
- **Simulation is deterministic.** All generated data comes from a seeded PRNG, so the UI is stable across launches.
- The design system is built from `Material`, gradients, and hairline strokes rather than the iOS 26 glass APIs, so it renders identically on the iOS 17 deployment target.

## Known limitations

- Crews and challenges are device-local; there's no sync between devices and no real friends until a backend implements `SocialService`.
- Streak history is computed from a rolling 90-day window. Longer streaks are carried forward from the persisted value, which requires the app to be opened at least once every 90 days to stay exact.
- Crew-mates in generated crews are simulated. Any crew you create yourself starts with just you in it.

## Before shipping

- Set your own bundle identifier (currently `com.mahadmyonis.StepCounting`) and signing team.
- Decide on App Store metadata: the title and subtitle carry most of the search weight, and the first three screenshots carry most of the conversion. The ring, the streak card, and a crew leaderboard are the three strongest frames in the app.
- Consider a real backend before any paid acquisition — the invite loop is the growth engine, and it can't fire across devices without one.

## Notes

- HealthKit deliberately does not report read-authorization status, so the app infers access from whether queries succeed after the authorization prompt.
- Health data never leaves the device, and neither does anything else — there is no analytics SDK and no network code in the app.
