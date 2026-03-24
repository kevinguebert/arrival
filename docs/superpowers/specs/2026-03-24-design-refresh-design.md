# Traffic Menubar — Design Refresh Spec

## Overview

A visual redesign of the Traffic Menubar popover and menubar label. The app shifts from a flat, light-mode utility with weather emoji icons to an atmospheric, adaptive-themed experience with a Signal/Pulse icon system, multi-route display, and playful rotating mood copy. The core functionality is unchanged — the redesign targets visual identity, information density, and personality.

## Goals

- Replace weather emojis with a Signal/Pulse icon system that won't collide with future weather integration
- Add atmospheric depth (radial glows, gradients, layered shadows) inspired by Paperclip.ing's visual language
- Support macOS light/dark mode adaptively
- Show multiple routes with traffic conditions per-route, replacing the single-route view
- Lean hard into personality with rotating mood phrases (Claude Code spinner style)
- Add purposeful animations that communicate meaning and match traffic urgency

## Non-Goals

- No new data sources (still MapKit only)
- No "usual route" learning or stored preferences
- No weather integration (that's a future feature)
- No changes to Preferences window design (this spec covers popover + menubar only)
- No changes to the polling/scheduling system

---

## 1. Visual Identity

### Adaptive Theme

The popover follows macOS appearance setting:

**Dark mode (default):**
- Background: linear gradient from `#0f1219` to `#161b26`
- Text: white with varying opacity (0.9 for primary, 0.45 for secondary, 0.3 for tertiary)
- Hero time: gradient text (white → white at 85% opacity) using background-clip
- Borders: `rgba(255,255,255,0.06)`
- Shadows: not prominent (the glow does the work)

**Light mode:**
- Background: linear gradient from `#ffffff` to `#f8fafb`
- Text: `#1a1a2e` with varying opacity
- Hero time: solid `#1a1a2e`
- Borders: `rgba(0,0,0,0.05-0.08)`
- Shadows: layered — `0 2px 12px rgba(0,0,0,0.06)` on the popover, `0 1px 4px rgba(0,0,0,0.03)` on route cards

### Atmospheric Depth

Each mood state produces a radial glow behind the content:
- Positioned top-right of the popover, ~160px diameter in dark / ~120px in light
- Tinted to the current mood color at low opacity (8-12% in dark, 6% in light)
- Creates the sense of ambient light emanating from the mood state
- Transitions smoothly when mood changes

### Mood Colors

| State | Color | Usage |
|-------|-------|-------|
| Clear | `#4ade80` (green) | Accent stripe, pulse dot, route highlight, background glow |
| Moderate | `#fbbf24` (amber) | Same set, amber-tinted |
| Heavy | `#f87171` (red) | Same set, red-tinted |
| Unknown | `#94a3b8` (slate) | Same set, neutral/muted |

Light mode uses slightly darker variants for text: green `#16a34a`, amber `#d97706`, red `#dc2626`, slate `#64748b`.

### Accent Stripe

3px gradient bar at the top of the popover, colored to the current mood. Gradient goes from the mood color to a slightly darker variant (e.g., `#4ade80` → `#22c55e` for clear). Animates color transition when mood changes.

---

## 2. Signal/Pulse Icon System

Replaces weather emojis (☀️ 🌤 🌧 🔮) with glowing orbs in the mood badge:

- **Clear:** 9-10px circle, mood-colored fill, soft box-shadow glow (`0 0 8px` at 50% opacity). Calm, steady presence.
- **Moderate:** Same circle with a slightly larger glow radius. In animation, pulses slightly faster than clear.
- **Heavy:** Circle with intensified glow (`0 0 10px` at 60% opacity). Pulses noticeably faster — draws the eye.
- **Unknown:** Circle with muted glow, gentle fade in/out animation.

The pulse dot appears in the mood badge alongside the rotating phrase text.

---

## 3. Mood Copy System

Rotating playful phrases, randomly selected on each data refresh. ~10-15 phrases per mood:

### Clear
- "Smooth sailing"
- "Open road vibes"
- "Not a car in sight"
- "Cruising along"
- "Highway's all yours"
- "Ghost town out there"
- "Breezing through"
- "Like a Sunday drive"
- "Green lights all day"
- "Wind in your hair"
- "The road is your oyster"

### Moderate
- "A bit sluggish"
- "Dragging a little"
- "Could be worse"
- "Patience, grasshopper"
- "Slow and steady"
- "Taking its sweet time"
- "Not great, not terrible"
- "Hitting some molasses"
- "Rush hour vibes"
- "The scenic pace"
- "Everyone had the same idea"

### Heavy
- "Buckle up, buttercup"
- "Gonna be a minute"
- "Pour another coffee"
- "Yikes on bikes"
- "It's a parking lot"
- "Send snacks"
- "Abandon all hope"
- "Netflix in the car time"
- "Bring a podcast"
- "Might wanna leave early"
- "RIP your ETA"

### Unknown
- "Scouting the roads..."
- "Checking the vibes..."
- "Asking the traffic gods..."
- "Hold tight..."
- "Poking around out there..."
- "Consulting the oracle..."
- "Summoning traffic data..."
- "Warming up the satellites..."
- "One sec, peeking outside..."
- "Phoning a friend..."

### Mood Badge Format

`[pulse dot] [rotating phrase] · +X min`

The delay indicator (`· +X min`) appears when the fastest route has a delay compared to the typical travel time. This ensures the user always sees the impact at a glance alongside the personality.

---

## 4. Route Display System

### Multi-Route Display

The app requests multiple routes from MapKit (`MKDirections` with `requestingAlternateRoutes = true`) and displays the top 2-3.

**Route list layout:**
- Contained in a rounded card (`border-radius: 10px`, subtle border and background)
- Each route is a row with: route name, time, distance, and a stylized traffic line
- Rows separated by 1px dividers
- Footer row: "Tap route to see on map"

**Fastest route (first row):**
- Highlighted background: `rgba(mood_green, 0.04)`
- Route name: 12px semibold, high opacity
- Time: 14px bold, green colored
- Stylized line: full-size dots (10px origin green, 10px destination red), 3px thick line with glow
- Distance shown after route name or time

**Alternative routes:**
- No background highlight
- Route name: 12px medium, 50% opacity
- Time: 14px semibold, 40% opacity
- Delta: `+X min` in small muted text
- Stylized line: smaller dots (6-8px, neutral color), 2px thick line, 50% overall opacity

### Stylized Traffic Lines

Each route gets a horizontal line from origin dot to destination dot. The line's gradient represents traffic conditions along that specific path:

- Green segments = clear flow
- Amber segments = slowdowns
- Red segments = heavy congestion/stoppage

Example gradient for a route with a middle bottleneck:
`linear-gradient(90deg, #4ade80 0%, #fbbf24 30%, #f87171 50%, #fbbf24 70%, #4ade80 100%)`

### Incident Markers

When a route has incidents:
- Orange diamond marker (`#f59e0b`) positioned on the line where the incident is
- Diamond is rotated 45deg, ~8px, with a subtle glow
- INCIDENT badge next to the route name: small pill with diamond icon + "INCIDENT" text in orange
- Incident description text below the route name in muted small text

### Smart Collapse

When MapKit returns only one route, or all routes are within ~2 minutes of each other:
- Fall back to a single stylized route view (no list)
- Shows: origin dot → gradient line → destination dot
- Below the line: "Home" / "via [road] · [distance]" / "Work"
- "Tap to see on map" footer

### Tap to Expand

Tapping any route row expands into the full Apple Maps view (`MKMapView`) with:
- That route highlighted as the primary polyline
- Other routes shown as dimmed overlays
- Smooth height expansion animation
- Tap again or swipe to collapse back to the stylized list

---

## 5. Animations & Transitions

All animations are purposeful — they communicate state, not decorate.

### Mood Transitions
When traffic state changes (e.g., clear → moderate):
- Accent stripe color: `easeInOut` over 0.4s
- Background glow color and opacity: `easeInOut` over 0.6s
- Pulse dot color: `easeInOut` over 0.3s
- Mood badge text: crossfade to new phrase

### Pulse Dot Breathing
The signal orb in the mood badge has a continuous scale/opacity animation:
- Clear: 3s cycle, scale 1.0 → 1.08, very subtle
- Moderate: 2s cycle, scale 1.0 → 1.12
- Heavy: 1.2s cycle, scale 1.0 → 1.15, more noticeable
- Unknown: 2.5s cycle, opacity fade 0.4 → 1.0

### Route Line Draw-In
When routes load or refresh:
- Lines draw from left (origin) to right (destination) using a trim animation
- Fastest route draws first (~0.5s)
- Alternatives fade in after with a 0.15s stagger

### Time Value Updates
When the travel time changes on refresh:
- Number crossfades (old → new) over 0.3s
- If the change is significant (>5 min), a brief scale bump (1.0 → 1.05 → 1.0) draws attention

### Incident Markers
- New incidents: diamond fades in with a single pulse (scale 1.0 → 1.3 → 1.0)
- Removed incidents: diamond fades out over 0.3s

### Map Expand/Collapse
- Tapping a route: the route card smoothly expands height to reveal the MKMapView below (~0.35s spring animation)
- The map fades in as the height expands
- Collapse reverses the animation

---

## 6. Menubar Label

### Format
`[time][symbol]` — e.g., `"32m"`, `"47m ●"`, `"58m ▲"`

### Severity Indicators
- **Clear:** `"32m"` — no suffix, clean. The absence of a symbol IS the signal.
- **Moderate:** `"47m ●"` — `circle.fill` SF Symbol, amber tinted if MenuBarExtra supports it
- **Heavy:** `"58m ▲"` — `exclamationmark.triangle.fill` SF Symbol, red tinted if supported
- **Unknown:** `"--"` — no symbol, placeholder while loading

### Fallback
If `MenuBarExtra` doesn't support tinted SF Symbols in the label, use untinted symbols. The shape difference (circle vs triangle) still communicates severity without color.

---

## 7. Empty States & Error States

All empty/error states use the adaptive theme (dark/light) with the slate mood color palette. No atmospheric glow — neutral and quiet.

### No Route Configured
- Icon: `car.side` SF Symbol
- Title: "Where to?"
- Subtitle: "Set up your addresses in Preferences"

### Loading
- Visual: dashed route line animation (line draws and retraces)
- Title: rotating unknown phrase from the mood copy pool
- Pulse dot: slate, breathing animation

### Error / Offline
- Icon: `cloud.bolt` SF Symbol
- Title: rotating error phrases:
  - "Lost signal"
  - "Can't reach the traffic gods"
  - "The internet took a detour"
  - "Signals crossed, trying again"
- Subtitle: "Will retry automatically"

### No Routes Found
- Icon: `map` SF Symbol
- Title: "Hmm, no routes found"
- Subtitle: "MapKit shrugged. Try different addresses?"

---

## 8. Layout & Typography

### Layout (unchanged)
- Popover width: 320pt
- Popover padding: 20pt
- Corner radius: 12pt (popover), 10pt (route cards), 20pt (mood badge pill), 8pt (secondary elements)

### Typography (unchanged)
All fonts use `.rounded` design:
- Hero time: 44pt bold
- Hero unit ("min"): 18pt medium
- ETA value: 20pt semibold
- Route name: 12pt (semibold for fastest, medium for alternatives)
- Route time: 14pt (bold for fastest, semibold for alternatives)
- Mood badge: 12pt medium
- Labels (TO WORK, ARRIVE BY): 10pt semibold, letter-spacing 1.2px, uppercase
- Caption/footer: 10pt regular
- Incident description: 10pt, low opacity

### Popover Structure (updated)
```
┌─ 3pt mood-colored accent stripe
├─ Header Section:
│   ├─ Direction label + icon ("TO WORK")
│   ├─ Hero time (large "32 min")
│   └─ ETA column ("ARRIVE BY 6:12 PM")
│
├─ Mood Badge:
│   └─ Pulse dot + rotating phrase + delay ("· +5 min")
│
├─ Route List Card:
│   ├─ Fastest route: name, time, stylized traffic line
│   ├─ Alt route 1: name, time, +delta, stylized line (dimmed)
│   ├─ Alt route 2: name, time, +delta, stylized line (dimmed)
│   ├─ [Incident details if applicable]
│   └─ "Tap route to see on map"
│   └─ [Expandable: MKMapView with route overlays]
│
└─ Footer:
    ├─ Update time ("Updated 3m ago")
    ├─ Offline indicator (if error)
    ├─ DEV badge (if dev mode)
    └─ Quick Settings button (ellipsis)
```

---

## 9. Implementation Notes

### MapKit Changes
- `MKDirections.Request`: set `requestingAlternateRoutes = true`
- Parse multiple `MKRoute` objects from the response
- Each route provides: `name`, `expectedTravelTime`, `distance`, `polyline`, `advisoryNotices`
- Sort by `expectedTravelTime`, take top 3

### Data Model Changes
- `RouteResult` needs to support multiple routes (e.g., `routes: [Route]` instead of a single route)
- Each `Route` contains: name, travel time, distance, polyline, incidents
- Traffic mood is determined by the fastest route's travel time

### Design System Changes
- Remove `moodEmoji` from `TrafficMood` enum
- Add `moodPhrases: [String]` array per mood case
- Add `randomPhrase() -> String` method
- Add dark/light color variants
- Add pulse animation parameters per mood (cycle duration, scale range)

### SwiftUI Considerations
- Use `@Environment(\.colorScheme)` for adaptive theming
- Pulse animation: `withAnimation(.easeInOut(duration: cycleDuration).repeatForever(autoreverses: true))`
- Route line draw: `trim(from:to:)` animation on a `Path`
- Map expand: `matchedGeometryEffect` or animated `frame` height change
- Time crossfade: `.contentTransition(.numericText())`

---

## 10. What's NOT Changing

- App architecture (MenuBarExtra → PopoverView → CommuteViewModel → TrafficProvider)
- Preferences window design
- Quick Settings popover (may get minor visual updates to match theme)
- Polling/scheduling system
- Location manager
- Developer settings and overrides (will need new overrides for multi-route testing)
