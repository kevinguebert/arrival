# Dev Address Overrides

**Date:** 2026-03-26
**Status:** Approved

## Problem

When taking screenshots or testing different UIs, we need to view real routes for different cities/commutes without changing the user's actual home and work addresses.

## Solution

Add address override fields to the Developer Settings panel. When dev mode and address overrides are both enabled, the app uses the override addresses for real API calls instead of the user's actual addresses.

## Design

### SettingsStore

New persisted UserDefaults properties:

- `devHomeAddress: String` — override home address string
- `devWorkAddress: String` — override work address string
- `devHomeCoordinate: (lat, lon)?` — geocoded override home coordinates
- `devWorkCoordinate: (lat, lon)?` — geocoded override work coordinates
- `devAddressOverrideEnabled: Bool` — toggle for address overrides

New computed properties:

- `effectiveHomeAddress` — returns dev address when dev mode + override enabled, else real address
- `effectiveWorkAddress` — returns dev address when dev mode + override enabled, else real address
- `effectiveHomeCoordinate` — returns dev coordinate when dev mode + override enabled, else real coordinate
- `effectiveWorkCoordinate` — returns dev coordinate when dev mode + override enabled, else real coordinate

The `isConfigured` check uses effective coordinates.

### DeveloperSettingsView

New "Address Overrides" section containing:

- Toggle to enable/disable address overrides
- Home address text field with geocoding (press Return to geocode, shows checkmark/error)
- Work address text field with same behavior
- Same UX patterns as the existing Addresses tab in Preferences
- When override is enabled, polling pause is automatically turned off so real API calls happen

### CommuteViewModel & Providers

All consumers that currently read `homeCoordinate`/`workCoordinate` from SettingsStore switch to reading `effectiveHomeCoordinate`/`effectiveWorkCoordinate`. This is the only data-flow change needed.

### BaselineFetcher

Uses effective coordinates. Baseline recalculates when dev addresses change.

## Scope

- Reuses existing `GeocodingService` for address resolution
- No new dependencies
- No changes to the real Addresses tab or its behavior
- Dev address data is completely separate from real address data
