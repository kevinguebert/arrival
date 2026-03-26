# Arrival

**Your drive time, at a glance.**

Arrival is a macOS menu bar app that shows your commute traffic in real time. Glance up, know instantly.

![Arrival screenshot](arrival-site/assets/screenshots/hero-clear.png)

## Features

- Live commute duration right in your menu bar
- Color-coded mood indicators (clear, moderate, heavy traffic)
- Route details with congestion visualization
- Traffic incident alerts
- Supports Mapbox Directions API
- Auto-updates via Sparkle

## Requirements

- macOS 13.0+
- A [Mapbox](https://www.mapbox.com/) API key (free tier available)

## Building from Source

Arrival uses [XcodeGen](https://github.com/yonaskolb/XcodeGen) to generate its Xcode project.

```bash
# Install XcodeGen
brew install xcodegen

# Set up secrets (Sentry DSN + TelemetryDeck App ID)
cp Secrets.xcconfig.example Secrets.xcconfig
# Edit Secrets.xcconfig with your values (or leave defaults to build without analytics)

# Generate the Xcode project
xcodegen generate

# Open in Xcode
open TrafficMenubar.xcodeproj
```

Then build and run with **Cmd+R** in Xcode.

## Installing via Homebrew

```bash
brew install --cask homebrew/arrival.rb
```

## Installing via DMG

Download the latest `.dmg` from [Releases](https://github.com/kevinguebert/traffic-menubar/releases), open it, and drag Arrival to your Applications folder.

**First launch:** Right-click the app and select Open (required once for unsigned apps).

## Configuration

On first launch, open Arrival's settings to:

1. Enter your Mapbox API key
2. Set your home and work addresses
3. Customize refresh interval and display preferences

## Creating a Release

Push a version tag to trigger the GitHub Actions release workflow:

```bash
git tag v1.0.0
git push origin v1.0.0
```

This builds the app, creates a DMG, publishes a GitHub Release, and updates the Sparkle appcast.

## License

[MIT](LICENSE)
