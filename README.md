# StepCounting

A SwiftUI iOS app that reads your activity from **Apple Health** and shows your daily steps, distance, and active energy — with a goal ring, history charts, and configurable goals.

## Features

- **Today dashboard** — live daily step count in a circular goal ring, plus distance and active-energy tiles. Pull to refresh.
- **History** — bar charts of the last 7 or 30 days (Swift Charts), with daily average, total, and your best day. Bars turn green on days you hit your goal.
- **Settings** — adjust your daily step goal (stepper or presets), switch distance units between kilometers and miles, and check Health access status.
- **Live updates** — an `HKObserverQuery` refreshes totals as new samples land, with hourly background delivery enabled.
- **Privacy** — data is read from Apple Health and never leaves the device.

## Requirements

- Xcode 16 or later
- iOS 17.0+ deployment target
- A device or simulator with Health data (HealthKit isn't available on Mac; use an iPhone simulator or device)

## Getting started

1. Open `StepCounting.xcodeproj` in Xcode.
2. Select the **StepCounting** scheme and an iPhone simulator or device.
3. Set your own signing team on the target (Signing & Capabilities). The **HealthKit** capability is already configured via `StepCounting/StepCounting.entitlements`.
4. Build and run. Grant Health access when prompted.

> Tip: In the simulator, open the **Health** app and add sample step / walking+running distance / active energy data (or use Features → … ) so the charts have something to show.

## Project structure

```
StepCounting/
├── StepCountingApp.swift        # App entry point; requests Health auth on launch
├── Models/
│   ├── DailyActivity.swift      # Per-day steps / distance / energy
│   └── StatsRange.swift         # Week vs. month history window
├── Services/
│   └── HealthKitManager.swift   # All HealthKit reads + live observers
├── Views/
│   ├── RootView.swift           # Tab bar
│   ├── DashboardView.swift      # Today tab
│   ├── HistoryView.swift        # History tab with Swift Charts
│   ├── SettingsView.swift       # Goal + units + status
│   ├── GoalRing.swift           # Circular progress ring
│   └── StatTile.swift           # Reusable metric card
├── Info.plist                   # Health usage descriptions
└── StepCounting.entitlements    # HealthKit entitlement
```

## Notes

- HealthKit deliberately does not report read-authorization status, so the app infers access from whether queries succeed after the authorization prompt.
- The bundle identifier is `com.mahadmyonis.StepCounting`; change it to your own before distributing.
