# UI Refinements — Design Spec

**Date:** 2026-03-24
**Scope:** 6 targeted UI changes to tighten the visual design, improve status communication, unify settings theming, and add Apple Maps integration.

---

## 1. Border Radius Reduction

Reduce all border radii by ~2-4pt for a tighter, crisper feel while retaining rounded character.

### Updated Design System Values

| Token | Current | New |
|---|---|---|
| `cornerRadius` | 12pt | 8pt |
| `routeCardCornerRadius` | 10pt | 6pt |
| `smallCornerRadius` | 8pt | 6pt |
| `moodBadgeCornerRadius` | 20pt (unused — badge uses `Capsule()` directly) | Unchanged |

### Hard-coded Values

| Component | Current | New |
|---|---|---|
| Dev section boxes | 8pt | 6pt |
| Preset/quick settings buttons | 6pt | 4pt |
| Incident badge | 4pt | 3pt |

### Files Affected
- `DesignSystem.swift` — central token updates
- `DeveloperSettingsView.swift` — hard-coded section radii
- `QuickSettingsView.swift` — hard-coded button radii
- `RouteListView.swift` — incident badge radius

---

## 2. Menubar Status Icons

Replace text suffixes in `menuBarText` with a clear escalating symbol set.

### Symbol Mapping

| Mood | Current Suffix | New Suffix |
|---|---|---|
| Clear | *(none)* | ` ●` (filled circle) |
| Moderate | ` ●` (filled circle) | ` ▲` (filled triangle) |
| Heavy | ` ▲` (filled triangle) | ` ‼` (double exclamation) |
| Unknown | *(none)* | *(none, unchanged)* |

### Rationale
- Clear now gets an indicator so users always see at-a-glance status
- Progression ● → ▲ → ‼ escalates in visual urgency
- Double exclamation on heavy provides stronger signal than single bang

### Files Affected
- `DesignSystem.swift` — `menuBarSuffix` property on `TrafficMood` (the suffix switch statement lives here, not in the view model)

---

## 3. Settings Modal (PreferencesView) Redesign

Hybrid approach: dark gradient background matching the popover, keeping tabbed layout and standard form controls.

### Visual Design
- **Background:** Linear gradient `#0F121A` → `#161B26` (matches popover)
- **Accent stripe:** 3px green gradient at top (`mood.darkAccentColor` → `mood.accentGradientEnd`)
- **Tab bar:** Custom styled — active tab has green text + 2px green bottom border; inactive tabs are dimmed white (45% opacity)
- **Form inputs:** Dark styled — `rgba(255,255,255,0.06)` background, `rgba(255,255,255,0.1)` border, 6pt radius
- **Labels:** 11px uppercase, semibold, `rgba(255,255,255,0.5)`
- **Segmented pickers (polling frequency):** Pill-button rows with green highlight for selected option
- **Typography:** System rounded font, matching popover

### Tab Content (unchanged functionality)
- **Addresses:** Home/work text fields with geocoding status indicators
- **Schedule:** Morning/evening time pickers, polling frequency selectors
- **General:** Launch at login toggle, traffic provider (disabled), developer mode toggle

### Files Affected
- `PreferencesView.swift` — full visual overhaul

---

## 4. Developer Settings Redesign

Dark background for visual consistency, but more utilitarian than main settings.

### Visual Design
- **Background:** Same dark gradient as settings/popover
- **No accent stripe** — signals "backstage" rather than main UI
- **Accent color:** Orange (`#FFA500`) for section headers and active states (already used for dev mode)
- **Denser layout:** Tighter padding, smaller section gaps than main settings
- **Section headers:** Orange uppercase text
- **Controls:** Same dark input styling as settings (subtle borders, 6pt radius)
- **Quick presets:** Compact button grid with orange highlight for active preset

### Content (unchanged functionality)
- Master dev mode toggle
- App state forcing (state, direction, failures)
- Route data controls (travel time, normal time)
- Incidents section (toggle, count, severity)
- Design overrides (mood, font scale)
- Quick presets (6 preset buttons)

### Files Affected
- `DeveloperSettingsView.swift` — full visual overhaul

---

## 5. Map Interaction — Route Switching

Clicking routes updates the map to highlight the selected route instead of only toggling open/close.

### Behavior
- **Map closed + click route** → map opens with that route highlighted as primary
- **Map open + click different route** → map updates to highlight newly clicked route; previous becomes alternate
- **Map open + click same route** → map closes

### Visual Treatment
- **Primary (selected) route:** Green solid line, 4pt stroke, 90% opacity
- **Alternate routes:** White dashed line, 3pt stroke, 15% opacity
- Map always shows all routes; only the highlight changes

### Implementation
- Modify the `onRouteTap` handler in `PopoverView.swift` to distinguish between "swap route" (different route clicked while map open) and "close map" (same route clicked)
- The existing `expandedRoute` state and `MapPreviewView` rendering already support primary vs alternate distinction
- When swapping routes, update `expandedRoute` without toggling `showMap`
- **Two code paths exist:** The multi-route `RouteListView` closure and the `singleRouteView` inline tap handler both handle route taps. Both must be updated to use the same three-state logic (open / swap / close).

### Files Affected
- `PopoverView.swift` — both the `RouteListView` closure and `singleRouteView` tap handler

---

## 6. Open in Apple Maps

Add a footer button to open the current route in Apple Maps for turn-by-turn directions.

### Placement
- Footer row, alongside "Updated Xm ago" text and settings (ellipsis) button
- SF Symbol icon: `arrow.triangle.turn.up.right.circle` (navigation icon)
- Small, subtle, matches existing footer style

### Behavior
- Constructs a `maps://` URL: `maps://?saddr=LAT,LNG&daddr=LAT,LNG&dirflg=d`
- Opens Apple Maps with driving directions
- Route selection: uses `expandedRoute` if selected, otherwise fastest route
- Hidden when no route data is available

### Implementation
- Use `NSWorkspace.shared.open(url)` to launch Apple Maps
- Reuse existing `originCoordinate` and `destinationCoordinate` computed properties already in `PopoverView.swift` — these handle the home/work direction logic

### Files Affected
- `PopoverView.swift` — footer section (add button + URL construction using existing coordinate properties)
