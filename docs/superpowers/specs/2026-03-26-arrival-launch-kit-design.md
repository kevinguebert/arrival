# Arrival Launch Kit — Design Spec

## Overview

Launch kit for **Arrival**, a macOS menubar app that shows real-time drive times. Three deliverables ship together: brand identity, distribution packaging, and a marketing website with docs.

**Name:** Arrival
**Tagline:** "Your drive time, at a glance."
**Pricing:** Free with tip jar (architecture ready for future paid tier)
**Target audience:** Anyone who drives regularly on Mac

---

## 1. Brand Identity

### Name & Tagline

- **Product name:** Arrival
- **Tagline:** "Your drive time, at a glance."

### Color Palette

All colors are pulled from the existing `DesignSystem.swift`. The marketing site uses the same palette — no new brand colors.

| Token | Hex | Usage |
|-------|-----|-------|
| Dark BG Top | `#0F1219` | Page background gradient start |
| Dark BG Bottom | `#161B26` | Page background gradient end |
| Clear Green | `#4DAD80` | Primary accent, CTA buttons, clear state |
| Clear Green End | `#21C45E` | Gradient end for accent stripe |
| Moderate Amber | `#FDC021` | Moderate state accent |
| Amber End | `#F59F0A` | Amber gradient end |
| Heavy Red | `#F77070` | Heavy state accent |
| Red End | `#F04545` | Red gradient end |
| Unknown Slate | `#94A3B8` | Disabled/loading states |
| Light BG | `#FFFFFF` → `#F8FBFB` | Light mode gradient (if needed) |
| Dark Text | `#1A1A2D` | Text on light backgrounds |
| Clear Text | `#17A348` | Green text on light backgrounds |
| Moderate Text | `#D97605` | Amber text on light backgrounds |
| Heavy Text | `#DB2626` | Red text on light backgrounds |

### App Icon

Dark rounded-rect background (`#0F1219` → `#161B26` gradient) with:
- 3px accent stripe at top (green gradient: `#4DAD80` → `#21C45E`)
- Curved arc route from bottom-left origin to top-right destination
- Route stroke uses congestion gradient: green → amber → red → amber → green
- Origin and destination shown as filled green dots (`#4DAD80`)
- Destination dot has concentric pulse rings (opacity 0.35 and 0.15) matching the app's `PulseDotView`
- Subtle radial glow behind the route (rgba(77,173,128,0.12))

Sizes needed: 1024px (App Store), 512px, 256px, 128px, 64px, 32px, 16px.

### Typography

The marketing site uses the system font stack: `-apple-system, BlinkMacSystemFont, 'SF Pro Display', system-ui, sans-serif` — matching the app's use of rounded SF Pro.

---

## 2. Distribution

### No Code Signing (v1)

The app will not be signed or notarized for the initial launch. Users will need to right-click → Open on first launch to bypass Gatekeeper. The docs page will include clear instructions with screenshots for this.

**Future:** Apple Developer Program ($99/year) → Developer ID signing → notarization → seamless Gatekeeper experience.

### DMG Packaging

- Build a `.dmg` disk image using `create-dmg` (or similar tool)
- Standard drag-to-Applications layout
- DMG background uses the app's dark gradient with the Arrival icon centered
- Filename format: `Arrival-{version}.dmg` (e.g., `Arrival-1.0.0.dmg`)
- Host on **GitHub Releases** — free, versioned, reliable CDN

### Auto-Updates (Sparkle)

- Integrate the [Sparkle](https://sparkle-project.org/) framework into the app
- Host `appcast.xml` on the marketing site (or GitHub Pages)
- App checks for updates on launch and periodically
- Users get in-app update prompts with release notes

### Homebrew Cask

- Submit a cask formula to `homebrew/homebrew-cask`
- Cask points to the GitHub Releases DMG URL
- Install command: `brew install --cask arrival`
- Added after the first GitHub Release is published

---

## 3. Marketing Website

### Tech Stack

- **Static HTML/CSS/JS** — no framework runtime, but uses a Tailwind build step to compile CSS
- **Tailwind CSS** — utility-first styling, compiled at build time to a static CSS file
- **shadcn/ui design language** — we adopt shadcn's visual patterns and CSS conventions (card styles, badge shapes, button treatments) but implemented as plain HTML + Tailwind classes, NOT as React components. The site has no React dependency.
- Custom Tailwind theme config that maps to the app's DesignSystem.swift colors
- Host on **GitHub Pages**, **Netlify**, or **Vercel** (all free tier)

### Custom Theme (Critical)

The site must NOT look like a default shadcn/Tailwind site. Custom theme requirements:

- **Background:** Dark gradient (`#0F1219` → `#161B26`), not the default slate/zinc
- **Primary color:** Clear green `#4DAD80`, not the default blue
- **Border/ring colors:** Derived from the app's `rgba(255,255,255,0.06-0.12)` pattern, not default gray
- **Card backgrounds:** `rgba(255,255,255,0.02-0.03)` with subtle borders, not the default card style
- **Border radius:** 12px for cards (matching app's `cornerRadius`), not the default 8px
- **Typography:** Tight letter-spacing on headings (-0.03em to -0.04em), generous line-height on body
- **Accent colors per mood:** Green/amber/red used contextually, not as a single accent
- **No default shadcn gray palette** — all neutral tones derived from the app's dark background

### Tailwind Config

```js
// tailwind.config.js
module.exports = {
  theme: {
    extend: {
      colors: {
        background: { DEFAULT: '#0F1219', secondary: '#161B26' },
        foreground: { DEFAULT: '#f5f5f7', muted: 'rgba(255,255,255,0.45)', subtle: 'rgba(255,255,255,0.25)' },
        clear: { DEFAULT: '#4DAD80', end: '#21C45E', text: '#17A348' },
        moderate: { DEFAULT: '#FDC021', end: '#F59F0A', text: '#D97605' },
        heavy: { DEFAULT: '#F77070', end: '#F04545', text: '#DB2626' },
        slate: { DEFAULT: '#94A3B8', text: '#647390' },
        border: 'rgba(255,255,255,0.08)',
      },
      borderRadius: { card: '12px', badge: '20px' },
      fontFamily: { sans: ['-apple-system', 'BlinkMacSystemFont', 'SF Pro Display', 'system-ui', 'sans-serif'] },
    }
  }
}
```

### Site Structure

```
/                  → Landing page
/docs              → Docs/FAQ page
```

### Landing Page Layout (Editorial / Magazine Style)

The layout uses alternating left/right sections with big typography and real app screenshots. Not a generic SaaS template.

**1. Navigation**
- Fixed top bar, max-width 1200px centered
- Left: Arrival logo (SVG icon + wordmark)
- Center/Right: "Features" | "Docs" links
- Right: Green "Download" button

**2. Hero Section (full viewport height)**
- Two-column grid: text left, app screenshot right
- Left column:
  - H1: "Your drive time," (full white) + "at a glance." (muted, 25% opacity) — 4.5rem, -0.04em tracking
  - Subtitle paragraph explaining the app (1.1rem, 35% opacity)
  - Green CTA button: "Download for Mac"
  - Subtext: "macOS 13+ · Free"
- Right column:
  - Real screenshot of the popover in clear/green state
  - Styled with the dark card treatment (border, shadow, accent stripe)
  - Subtle radial glow behind it

**3. Feature: Routes (text left, screenshot right)**
- Label: "ROUTES" in green, small caps
- H2: "Three routes. One glance."
- Body text about multi-route view with congestion
- Screenshot: popover showing 3 routes with congestion colors

**4. Feature: Map (text right, screenshot left — reversed)**
- Label: "MAP" in amber
- H2: "See the full picture."
- Body text about detachable map window
- Screenshot: detached map window with route overlays

**5. Feature: Incidents (text left, screenshot right)**
- Label: "INCIDENTS" in red
- H2: "Know what's ahead."
- Body text about accident/closure alerts
- Screenshot: popover showing incident alerts with delays

**6. Personality Section (centered, full-width)**
- Large stacked text:
  - "Smooth sailing." in green
  - "A bit sluggish." in amber
  - "Buckle up." in red
- Subtitle: "Arrival communicates traffic at a glance through color and personality..."
- Three mood dots (green, amber, red) with labels

**7. Install Section (centered)**
- H2: "Get Arrival."
- Subtitle: "Free. No account required."
- Two cards side by side:
  - Direct Download: DMG filename + download link
  - Homebrew: `brew install --cask arrival` with copy button

**8. Footer**
- Minimal: "Arrival — a free macOS menubar app · GitHub · Docs"

### Screenshots Needed

The user will provide real screenshots of the app. Here is the shot list:

| Screenshot | App State | What to Show |
|-----------|-----------|-------------|
| Hero screenshot | Clear/green mood | Full popover — green accent stripe, "Smooth sailing" badge, 3 routes, ETA |
| Routes screenshot | Clear or moderate | Popover zoomed to route list with congestion-colored route lines |
| Map screenshot | Any mood | Detached map window with route overlays and congestion coloring |
| Incidents screenshot | Heavy/red mood | Popover with red accent stripe, incident alerts showing delays |
| (Optional) Menubar | Any | Menubar area showing the "32m" text in the system tray |
| (Optional) Preferences | N/A | Preferences window showing address setup |

Screenshots should be taken at 2x resolution on a Retina display. Dark mode preferred to match the site.

### Docs Page (`/docs`)

A single-page docs/FAQ section with anchored sections:

**Sections:**
1. **Getting Started** — Download, install, first launch (right-click to open for unsigned app)
2. **Setting Up** — Enter home/work addresses, configure commute hours
3. **Using Arrival** — Reading the popover, understanding moods, routes, incidents
4. **Map Window** — How to open, interact with, and detach the map
5. **Preferences** — Polling intervals, map provider (MapKit vs Mapbox), launch at login
6. **Troubleshooting / FAQ**
   - "macOS says the app is from an unidentified developer" → right-click → Open instructions
   - "The app shows '--' instead of a time" → check addresses, check network
   - "How do I use Mapbox instead of Apple Maps?" → enter API key in preferences
   - "How do I make it launch at startup?" → toggle in preferences
7. **Updates** — How Sparkle auto-updates work

**Docs styling:**
- Same dark theme as landing page
- Left sidebar navigation with section links (sticky on scroll)
- Clean typography, code blocks for terminal commands
- Subtle section dividers

---

## 4. Project Structure

```
arrival-site/
├── index.html              # Landing page
├── docs/
│   └── index.html          # Docs page
├── assets/
│   ├── screenshots/        # App screenshots (user-provided)
│   ├── icon/               # App icon SVGs and PNGs at various sizes
│   └── og-image.png        # Social sharing image
├── css/
│   └── style.css           # Compiled Tailwind output
├── js/
│   └── main.js             # Minimal JS (copy-to-clipboard, smooth scroll)
├── tailwind.config.js
├── package.json            # Tailwind build script only
├── CNAME                   # Custom domain (if applicable)
└── appcast.xml             # Sparkle update feed
```

The build step compiles Tailwind to a static CSS file. The deployed site has no JS framework dependency — just HTML, CSS, and minimal vanilla JS.

---

## 5. Scope & Non-Goals

**In scope:**
- Landing page (editorial layout with real screenshots)
- Docs/FAQ page
- Custom Tailwind + shadcn theme matching the app's design system
- App icon as SVG (for web use; final .icns for the app is a separate task)
- DMG packaging setup
- Sparkle integration
- Homebrew cask formula
- GitHub Releases setup

**Not in scope:**
- App Store submission
- Code signing / notarization (future)
- Blog or changelog page (future)
- Paid tier / tip jar payment integration (future)
- Analytics or tracking
- User accounts
- Custom domain purchase (user decides)
