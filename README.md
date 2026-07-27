# StepCounting

A SwiftUI iOS app that reads your activity from **Apple Health** and turns it into something you'll actually keep doing: streaks that survive a bad day, badges worth chasing, private crews of people you know, and challenges you race them in — including virtual routes like the Camino and Route 66.

No account to create. No server of ours. No global leaderboard full of strangers — crews sync through your own iCloud.

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
- Private and invite-code based, synced through CloudKit. Create one or join with a code.
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

## How crews actually work

HealthKit is device-local by design. There is no API that lets this app read
what's in someone else's Health store — so a crew leaderboard is N phones each
reading **their own** Health data and publishing one number per day, which
everyone else then reads. `CloudKitSocialService` is that transport, and nothing
more. There is no account to create and no server of ours in between.

**One crew is one CloudKit record zone.** Whoever creates it owns the zone in
their private database and puts a zone-wide `CKShare` on it; everyone else sees
that same zone through their shared database. Names and step totals only ever
exist inside that zone, visible to crew members and nobody else.

**The public database holds exactly one thing:** a `CrewInvite` record whose
record *name* is the invite code and whose only field is the share URL. That
preserves six-character invite codes — much better than pasting share links —
without putting a byte of personal data anywhere public. Looking a code up is a
fetch-by-ID, not a query, so there's no index to configure.

Two consequences worth knowing:

- Reads use `recordZoneChanges` rather than `CKQuery`, so the schema CloudKit
  generates on first write is the entire setup. Nothing to configure by hand.
- Publishes diff against what was last sent, so a refresh writes only the days
  that actually changed, and syncs are throttled to 90 seconds — Health fires
  observer callbacks far more often than a leaderboard needs redrawing.

`DemoSocialService` backs one thing only: the optional sample crew in
onboarding, so a brand-new user isn't staring at an empty leaderboard before
they've invited anyone. Its walkers are generated on-device and the app says so
on that crew's screen. Real people never fall back to simulated numbers — a day
someone hasn't published reads as zero.

### What leaves your device

Your Health data doesn't. What a crew sees is your display name, avatar, colour,
and one step total per day. That's the whole payload.

## Requirements

- Xcode 16 or later
- iOS 17.0+ deployment target
- A device or simulator with Health data (HealthKit isn't available on Mac; use an iPhone simulator or device)

## Getting started

1. Open `StepCounting.xcodeproj` in Xcode.
2. Select the **StepCounting** scheme and an iPhone simulator or device.
3. Set your own signing team on the target (Signing & Capabilities). **HealthKit** (including background delivery) and **iCloud → CloudKit** are declared in `StepCounting/StepCounting.entitlements`.
4. Create the CloudKit container `iCloud.com.mahadmyonis.StepCounting` (or change `CloudKitSocialService.defaultContainerIdentifier` and the entitlement to match your own). No schema setup is needed — CloudKit generates it on first write.
5. Build and run. Grant Health access when prompted, and accept the sample crew in onboarding so the leaderboards have something in them.

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
│   ├── SocialService.swift          # Backend protocol + demo implementation
│   ├── CloudKitSocialService.swift  # Real crew sync (shared zones + CKShare)
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

- **CloudKit sync has not been run against a live container.** It compiles, and the design is conventional, but every path that talks to iCloud — creating a share, resolving a code, accepting, publishing, reading a zone — needs a real two-device test before this ships.
- Crews need an iCloud account. Without one, the app degrades to solo tracking and says why; nothing else is affected.
- Challenges are still device-local: a challenge you start is visible only to you, though it scores everyone's real published steps. Syncing the challenge list itself is the obvious next step.
- Streak history is computed from a rolling 90-day window. Longer streaks are carried forward from the persisted value, which requires the app to be opened at least once every 90 days to stay exact.
- Invite codes are 8 characters from a 32-character alphabet (~1.1 × 10¹²). Guessing one is impractical, but the code *is* the only thing protecting a crew, so treat it like a password.

## Before shipping

- Set your own bundle identifier (currently `com.mahadmyonis.StepCounting`), signing team, and CloudKit container.
- Deploy the CloudKit schema from Development to Production in the CloudKit console — dev schema does not carry over to App Store builds, and this is the classic way a working app ships broken.
- Decide on App Store metadata: the title and subtitle carry most of the search weight, and the first three screenshots carry most of the conversion. The ring, the streak card, and a crew leaderboard are the three strongest frames in the app.
- Test the invite loop end to end on two devices with different iCloud accounts. It is the growth engine, and it is the one thing CI cannot check.

## Notes

- HealthKit deliberately does not report read-authorization status, so the app infers access from whether queries succeed after the authorization prompt.
- There is no analytics SDK and no third-party network code. The only thing the app talks to is the user's own iCloud.
