# Arrival Launch Kit Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship the Arrival launch kit — marketing website, distribution packaging, and brand assets — so the app can be downloaded and promoted.

**Architecture:** A separate `arrival-site/` directory at the project root holds the static marketing site. Tailwind CSS compiles to a static file at build time. The app itself gains Sparkle for auto-updates and a build script for DMG creation. Brand assets (icon SVGs) are shared between the site and app.

**Tech Stack:** HTML, Tailwind CSS v4, vanilla JS, Sparkle (Swift), create-dmg (shell), GitHub Releases

**Spec:** `docs/superpowers/specs/2026-03-26-arrival-launch-kit-design.md`

---

### Task 1: Scaffold the Marketing Site Project

**Files:**
- Create: `arrival-site/package.json`
- Create: `arrival-site/tailwind.config.js`
- Create: `arrival-site/src/input.css`
- Create: `arrival-site/.gitignore`

- [ ] **Step 1: Create directory structure**

```bash
cd /Users/kevinguebert/Documents/Development/traffic-menubar
mkdir -p arrival-site/{assets/{screenshots,icon},css,js,docs,src}
```

- [ ] **Step 2: Create package.json with Tailwind build scripts**

Create `arrival-site/package.json`:

```json
{
  "name": "arrival-site",
  "private": true,
  "scripts": {
    "dev": "npx @tailwindcss/cli -i ./src/input.css -o ./css/style.css --watch",
    "build": "npx @tailwindcss/cli -i ./src/input.css -o ./css/style.css --minify"
  },
  "devDependencies": {
    "@tailwindcss/cli": "^4.0.0"
  }
}
```

- [ ] **Step 3: Create Tailwind config with custom Arrival theme**

Create `arrival-site/tailwind.config.js`:

```js
/** @type {import('tailwindcss').Config} */
module.exports = {
  content: ['./**/*.html'],
  theme: {
    extend: {
      colors: {
        background: { DEFAULT: '#0F1219', secondary: '#161B26' },
        foreground: { DEFAULT: '#f5f5f7', muted: 'rgba(255,255,255,0.45)', subtle: 'rgba(255,255,255,0.25)' },
        clear: { DEFAULT: '#4DAD80', end: '#21C45E', text: '#17A348' },
        moderate: { DEFAULT: '#FDC021', end: '#F59F0A', text: '#D97605' },
        heavy: { DEFAULT: '#F77070', end: '#F04545', text: '#DB2626' },
        slate: { DEFAULT: '#94A3B8', text: '#647390' },
        border: { DEFAULT: 'rgba(255,255,255,0.08)', hover: 'rgba(255,255,255,0.12)', strong: 'rgba(255,255,255,0.15)' },
        card: { DEFAULT: 'rgba(255,255,255,0.02)', hover: 'rgba(255,255,255,0.04)' },
      },
      borderRadius: {
        card: '12px',
        badge: '20px',
        button: '10px',
      },
      fontFamily: {
        sans: ['-apple-system', 'BlinkMacSystemFont', 'SF Pro Display', 'system-ui', 'sans-serif'],
      },
      letterSpacing: {
        heading: '-0.03em',
        tight: '-0.04em',
      },
      maxWidth: {
        site: '1200px',
      },
    },
  },
  plugins: [],
}
```

- [ ] **Step 4: Create Tailwind input CSS with custom base styles**

Create `arrival-site/src/input.css`:

```css
@import "tailwindcss";
@config "../tailwind.config.js";

/* Custom base styles that go beyond Tailwind's defaults */
@layer base {
  body {
    background: linear-gradient(180deg, #0F1219 0%, #161B26 100%);
    background-attachment: fixed;
    color: #f5f5f7;
    font-family: -apple-system, BlinkMacSystemFont, 'SF Pro Display', system-ui, sans-serif;
    -webkit-font-smoothing: antialiased;
  }

  ::selection {
    background: rgba(77, 173, 128, 0.3);
    color: #f5f5f7;
  }
}

/* Accent stripe — reusable across hero screenshot frame and cards */
@layer components {
  .accent-stripe {
    height: 3px;
    background: linear-gradient(to right, #4DAD80, #21C45E);
    border-radius: 2px 2px 0 0;
  }

  .accent-stripe-amber {
    height: 3px;
    background: linear-gradient(to right, #FDC021, #F59F0A);
    border-radius: 2px 2px 0 0;
  }

  .accent-stripe-red {
    height: 3px;
    background: linear-gradient(to right, #F77070, #F04545);
    border-radius: 2px 2px 0 0;
  }

  /* Radial glow used behind screenshots */
  .glow-green {
    background: radial-gradient(circle, rgba(77, 173, 128, 0.1) 0%, transparent 70%);
  }

  /* Card style matching app's DesignSystem */
  .arrival-card {
    background: rgba(255, 255, 255, 0.02);
    border: 1px solid rgba(255, 255, 255, 0.06);
    border-radius: 12px;
  }

  .arrival-card:hover {
    border-color: rgba(255, 255, 255, 0.12);
  }

  /* Screenshot frame with accent stripe */
  .screenshot-frame {
    background: linear-gradient(180deg, #161B26, #0F1219);
    border: 1px solid rgba(255, 255, 255, 0.08);
    border-radius: 16px;
    overflow: hidden;
    box-shadow: 0 32px 64px rgba(0, 0, 0, 0.5);
    position: relative;
  }

  .screenshot-frame::before {
    content: '';
    position: absolute;
    top: 0;
    left: 0;
    right: 0;
    height: 3px;
    background: linear-gradient(to right, #4DAD80, #21C45E);
  }

  /* Code block for terminal commands */
  .code-block {
    background: rgba(0, 0, 0, 0.3);
    border-radius: 6px;
    padding: 0.5rem 0.75rem;
    font-family: 'SF Mono', ui-monospace, monospace;
    font-size: 0.8rem;
    color: #4DAD80;
  }
}
```

- [ ] **Step 5: Create .gitignore**

Create `arrival-site/.gitignore`:

```
node_modules/
```

- [ ] **Step 6: Install dependencies and verify build**

```bash
cd /Users/kevinguebert/Documents/Development/traffic-menubar/arrival-site
npm install
npm run build
```

Expected: `css/style.css` is generated with compiled Tailwind output.

- [ ] **Step 7: Commit**

```bash
git add arrival-site/
git commit -m "feat(site): scaffold Arrival marketing site with custom Tailwind theme"
```

---

### Task 2: Create App Icon SVG

**Files:**
- Create: `arrival-site/assets/icon/arrival-icon.svg`

- [ ] **Step 1: Create the icon SVG**

Create `arrival-site/assets/icon/arrival-icon.svg`:

```svg
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024">
  <defs>
    <linearGradient id="bg" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0%" stop-color="#0F1219"/>
      <stop offset="100%" stop-color="#161B26"/>
    </linearGradient>
    <linearGradient id="congestion" x1="0" y1="1" x2="1" y2="0">
      <stop offset="0%" stop-color="#4DAD80"/>
      <stop offset="40%" stop-color="#4DAD80"/>
      <stop offset="55%" stop-color="#FDC021"/>
      <stop offset="70%" stop-color="#F77070"/>
      <stop offset="85%" stop-color="#FDC021"/>
      <stop offset="100%" stop-color="#4DAD80"/>
    </linearGradient>
    <linearGradient id="stripe" x1="0" y1="0" x2="1" y2="0">
      <stop offset="0%" stop-color="#4DAD80"/>
      <stop offset="100%" stop-color="#21C45E"/>
    </linearGradient>
    <radialGradient id="glow" cx="50%" cy="50%" r="50%">
      <stop offset="0%" stop-color="rgba(77,173,128,0.12)"/>
      <stop offset="100%" stop-color="transparent"/>
    </radialGradient>
    <clipPath id="roundrect">
      <rect width="1024" height="1024" rx="228" ry="228"/>
    </clipPath>
  </defs>
  <!-- Background -->
  <g clip-path="url(#roundrect)">
    <rect width="1024" height="1024" fill="url(#bg)"/>
    <!-- Accent stripe -->
    <rect x="0" y="0" width="1024" height="32" fill="url(#stripe)"/>
    <!-- Atmospheric glow -->
    <circle cx="512" cy="512" r="400" fill="url(#glow)"/>
    <!-- Origin dot -->
    <circle cx="213" cy="768" r="59" fill="#4DAD80"/>
    <!-- Route arc with congestion -->
    <path d="M213 768 C213 427, 811 597, 811 256" fill="none" stroke="url(#congestion)" stroke-width="37" stroke-linecap="round"/>
    <!-- Destination dot -->
    <circle cx="811" cy="256" r="59" fill="#4DAD80"/>
    <!-- Pulse ring 1 -->
    <circle cx="811" cy="256" r="107" fill="none" stroke="#4DAD80" stroke-width="13" opacity="0.35"/>
    <!-- Pulse ring 2 -->
    <circle cx="811" cy="256" r="160" fill="none" stroke="#4DAD80" stroke-width="9" opacity="0.15"/>
  </g>
</svg>
```

- [ ] **Step 2: Verify the SVG renders correctly**

Open the SVG in a browser:

```bash
open /Users/kevinguebert/Documents/Development/traffic-menubar/arrival-site/assets/icon/arrival-icon.svg
```

Verify: Dark rounded-rect background, green accent stripe at top, arc route with green→amber→red→amber→green congestion gradient, origin/destination dots, pulse rings at destination.

- [ ] **Step 3: Commit**

```bash
git add arrival-site/assets/icon/
git commit -m "feat(site): add Arrival app icon SVG"
```

---

### Task 3: Build the Landing Page — Navigation and Hero

**Files:**
- Create: `arrival-site/index.html`

- [ ] **Step 1: Create index.html with nav and hero section**

Create `arrival-site/index.html`:

```html
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Arrival — Your drive time, at a glance.</title>
  <meta name="description" content="Arrival is a free macOS menubar app that shows your real-time drive time, route options, and traffic incidents — without ever opening a maps app.">
  <meta property="og:title" content="Arrival — Your drive time, at a glance.">
  <meta property="og:description" content="A free macOS menubar app that shows your real-time drive time.">
  <meta property="og:image" content="assets/og-image.png">
  <meta property="og:type" content="website">
  <link rel="icon" type="image/svg+xml" href="assets/icon/arrival-icon.svg">
  <link rel="stylesheet" href="css/style.css">
</head>
<body class="overflow-x-hidden">

  <!-- Navigation -->
  <nav class="fixed top-0 left-0 right-0 z-50 backdrop-blur-md bg-background/80 border-b border-border">
    <div class="max-w-site mx-auto flex items-center justify-between px-6 lg:px-10 h-14">
      <a href="/" class="flex items-center gap-2 font-semibold text-foreground">
        <svg width="24" height="24" viewBox="0 0 96 96" class="flex-shrink-0">
          <defs>
            <linearGradient id="nav-grad" x1="0" y1="1" x2="1" y2="0">
              <stop offset="0%" stop-color="#4DAD80"/>
              <stop offset="40%" stop-color="#4DAD80"/>
              <stop offset="55%" stop-color="#FDC021"/>
              <stop offset="70%" stop-color="#F77070"/>
              <stop offset="85%" stop-color="#FDC021"/>
              <stop offset="100%" stop-color="#4DAD80"/>
            </linearGradient>
          </defs>
          <circle cx="20" cy="72" r="10" fill="#4DAD80"/>
          <path d="M20 72 C20 40, 76 56, 76 24" fill="none" stroke="url(#nav-grad)" stroke-width="7" stroke-linecap="round"/>
          <circle cx="76" cy="24" r="10" fill="#4DAD80"/>
        </svg>
        Arrival
      </a>
      <div class="flex items-center gap-8">
        <a href="#features" class="text-sm text-foreground-muted hover:text-foreground transition-colors hidden sm:block">Features</a>
        <a href="docs/" class="text-sm text-foreground-muted hover:text-foreground transition-colors hidden sm:block">Docs</a>
        <a href="#install" class="text-sm font-semibold bg-clear text-background px-4 py-2 rounded-button hover:bg-clear-end transition-colors">Download</a>
      </div>
    </div>
  </nav>

  <!-- Hero -->
  <section class="min-h-screen flex items-center pt-14">
    <div class="max-w-site mx-auto px-6 lg:px-10 grid grid-cols-1 lg:grid-cols-2 gap-12 lg:gap-16 items-center py-20 lg:py-0">
      <!-- Text -->
      <div>
        <h1 class="text-5xl lg:text-7xl font-bold tracking-tight leading-none">
          Your drive time,
          <span class="block text-foreground-subtle">at a glance.</span>
        </h1>
        <p class="mt-6 text-lg text-foreground-muted max-w-md leading-relaxed">
          Arrival lives in your Mac's menubar. Real-time commute estimates, route options, and incident alerts — without ever opening a maps app.
        </p>
        <div class="mt-8 flex flex-wrap items-center gap-4">
          <a href="#install" class="inline-flex items-center gap-2 bg-clear text-background font-semibold px-6 py-3 rounded-button hover:bg-clear-end transition-colors">
            <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M21 15v4a2 2 0 01-2 2H5a2 2 0 01-2-2v-4"/><polyline points="7 10 12 15 17 10"/><line x1="12" y1="15" x2="12" y2="3"/></svg>
            Download for Mac
          </a>
          <a href="https://github.com/kevinguebert/traffic-menubar" class="inline-flex items-center gap-2 text-foreground-muted hover:text-foreground transition-colors">
            View on GitHub
            <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><line x1="7" y1="17" x2="17" y2="7"/><polyline points="7 7 17 7 17 17"/></svg>
          </a>
        </div>
        <p class="mt-3 text-xs text-foreground-subtle">macOS 13 Ventura or later · Free</p>
      </div>
      <!-- Screenshot -->
      <div class="relative flex justify-center lg:justify-end">
        <div class="absolute w-[400px] h-[400px] glow-green -top-20 -right-10 pointer-events-none"></div>
        <div class="screenshot-frame w-full max-w-[360px]">
          <img src="assets/screenshots/hero-clear.png" alt="Arrival popover showing 32 min commute with clear traffic" class="w-full" loading="lazy">
        </div>
      </div>
    </div>
  </section>

  <!-- Features -->
  <div id="features"></div>

  <!-- Feature 1: Routes -->
  <section class="py-24 lg:py-32">
    <div class="max-w-site mx-auto px-6 lg:px-10 grid grid-cols-1 lg:grid-cols-2 gap-12 lg:gap-16 items-center">
      <div class="max-w-md">
        <span class="text-xs font-semibold uppercase tracking-widest text-clear">Routes</span>
        <h2 class="mt-3 text-4xl lg:text-5xl font-bold tracking-heading leading-tight">
          Three routes.<br>One glance.
        </h2>
        <p class="mt-4 text-foreground-muted leading-relaxed">
          See the fastest route plus two alternates, each with per-segment congestion data. The best option is always obvious.
        </p>
      </div>
      <div class="relative flex justify-center lg:justify-end">
        <div class="screenshot-frame w-full max-w-[360px]">
          <img src="assets/screenshots/routes.png" alt="Arrival showing three route options with congestion colors" class="w-full" loading="lazy">
        </div>
      </div>
    </div>
  </section>

  <!-- Divider -->
  <div class="max-w-site mx-auto px-6 lg:px-10"><div class="h-px bg-gradient-to-r from-transparent via-border to-transparent"></div></div>

  <!-- Feature 2: Map (reversed) -->
  <section class="py-24 lg:py-32">
    <div class="max-w-site mx-auto px-6 lg:px-10 grid grid-cols-1 lg:grid-cols-2 gap-12 lg:gap-16 items-center">
      <div class="relative flex justify-center lg:justify-start order-2 lg:order-1">
        <div class="screenshot-frame w-full max-w-[420px]">
          <img src="assets/screenshots/map.png" alt="Arrival detached map window with route overlays" class="w-full" loading="lazy">
        </div>
      </div>
      <div class="max-w-md order-1 lg:order-2">
        <span class="text-xs font-semibold uppercase tracking-widest text-moderate">Map</span>
        <h2 class="mt-3 text-4xl lg:text-5xl font-bold tracking-heading leading-tight">
          See the full picture.
        </h2>
        <p class="mt-4 text-foreground-muted leading-relaxed">
          Pop out an interactive map with route overlays and live congestion coloring. Click a route to select it. Resize, move, keep it open.
        </p>
      </div>
    </div>
  </section>

  <!-- Divider -->
  <div class="max-w-site mx-auto px-6 lg:px-10"><div class="h-px bg-gradient-to-r from-transparent via-border to-transparent"></div></div>

  <!-- Feature 3: Incidents -->
  <section class="py-24 lg:py-32">
    <div class="max-w-site mx-auto px-6 lg:px-10 grid grid-cols-1 lg:grid-cols-2 gap-12 lg:gap-16 items-center">
      <div class="max-w-md">
        <span class="text-xs font-semibold uppercase tracking-widest text-heavy">Incidents</span>
        <h2 class="mt-3 text-4xl lg:text-5xl font-bold tracking-heading leading-tight">
          Know what's ahead.
        </h2>
        <p class="mt-4 text-foreground-muted leading-relaxed">
          Accidents, road closures, and advisories — surfaced inline with estimated delay impact. No surprises on the road.
        </p>
      </div>
      <div class="relative flex justify-center lg:justify-end">
        <div class="screenshot-frame w-full max-w-[360px]">
          <img src="assets/screenshots/incidents.png" alt="Arrival showing traffic incidents with delay estimates" class="w-full" loading="lazy">
        </div>
      </div>
    </div>
  </section>

  <!-- Divider -->
  <div class="max-w-site mx-auto px-6 lg:px-10"><div class="h-px bg-gradient-to-r from-transparent via-border to-transparent"></div></div>

  <!-- Personality Section -->
  <section class="py-24 lg:py-32">
    <div class="max-w-3xl mx-auto px-6 text-center">
      <div class="text-4xl lg:text-5xl font-bold tracking-heading leading-snug">
        <span class="text-clear">Smooth sailing.</span><br>
        <span class="text-moderate">A bit sluggish.</span><br>
        <span class="text-heavy">Buckle up.</span>
      </div>
      <p class="mt-6 text-foreground-muted max-w-lg mx-auto leading-relaxed">
        Arrival communicates traffic at a glance through color and personality — so you know the vibe before you read a number.
      </p>
      <div class="mt-8 flex justify-center gap-8">
        <div class="flex flex-col items-center gap-2">
          <div class="w-6 h-6 rounded-full bg-clear"></div>
          <span class="text-xs text-foreground-subtle">Clear</span>
        </div>
        <div class="flex flex-col items-center gap-2">
          <div class="w-6 h-6 rounded-full bg-moderate"></div>
          <span class="text-xs text-foreground-subtle">Moderate</span>
        </div>
        <div class="flex flex-col items-center gap-2">
          <div class="w-6 h-6 rounded-full bg-heavy"></div>
          <span class="text-xs text-foreground-subtle">Heavy</span>
        </div>
      </div>
    </div>
  </section>

  <!-- Divider -->
  <div class="max-w-site mx-auto px-6 lg:px-10"><div class="h-px bg-gradient-to-r from-transparent via-border to-transparent"></div></div>

  <!-- Install Section -->
  <section id="install" class="py-24 lg:py-32">
    <div class="max-w-2xl mx-auto px-6 text-center">
      <h2 class="text-4xl lg:text-5xl font-bold tracking-heading">Get Arrival.</h2>
      <p class="mt-3 text-foreground-muted">Free. No account required.</p>
      <div class="mt-10 grid grid-cols-1 sm:grid-cols-2 gap-4 text-left">
        <div class="arrival-card p-6">
          <h3 class="font-semibold text-sm">Direct Download</h3>
          <p class="mt-1 text-sm text-foreground-muted">Download the DMG, drag to Applications.</p>
          <a href="https://github.com/kevinguebert/traffic-menubar/releases/latest" class="mt-3 inline-flex items-center gap-2 bg-clear text-background font-semibold px-4 py-2 rounded-button text-sm hover:bg-clear-end transition-colors">
            <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M21 15v4a2 2 0 01-2 2H5a2 2 0 01-2-2v-4"/><polyline points="7 10 12 15 17 10"/><line x1="12" y1="15" x2="12" y2="3"/></svg>
            Arrival-1.0.0.dmg
          </a>
        </div>
        <div class="arrival-card p-6">
          <h3 class="font-semibold text-sm">Homebrew</h3>
          <p class="mt-1 text-sm text-foreground-muted">Install via Homebrew cask.</p>
          <div class="mt-3 code-block flex items-center justify-between">
            <span>brew install --cask arrival</span>
            <button onclick="navigator.clipboard.writeText('brew install --cask arrival')" class="text-foreground-subtle hover:text-foreground transition-colors ml-2 flex-shrink-0" aria-label="Copy command">
              <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="9" y="9" width="13" height="13" rx="2" ry="2"/><path d="M5 15H4a2 2 0 01-2-2V4a2 2 0 012-2h9a2 2 0 012 2v1"/></svg>
            </button>
          </div>
        </div>
      </div>
    </div>
  </section>

  <!-- Footer -->
  <footer class="border-t border-border py-8">
    <div class="max-w-site mx-auto px-6 lg:px-10 text-center">
      <p class="text-xs text-foreground-subtle">
        Arrival — a free macOS menubar app ·
        <a href="https://github.com/kevinguebert/traffic-menubar" class="hover:text-foreground transition-colors">GitHub</a> ·
        <a href="docs/" class="hover:text-foreground transition-colors">Docs</a>
      </p>
    </div>
  </footer>

</body>
</html>
```

- [ ] **Step 2: Build CSS and verify in browser**

```bash
cd /Users/kevinguebert/Documents/Development/traffic-menubar/arrival-site
npm run build
open index.html
```

Verify: Nav with logo, hero with two-column layout, all feature sections alternate correctly, personality section has colored mood text, install section shows two cards, footer is minimal. Screenshots will be missing (placeholder broken images) — that's expected.

- [ ] **Step 3: Commit**

```bash
git add arrival-site/index.html
git commit -m "feat(site): add landing page with editorial layout and all sections"
```

---

### Task 4: Build the Docs Page

**Files:**
- Create: `arrival-site/docs/index.html`

- [ ] **Step 1: Create docs page with sidebar navigation**

Create `arrival-site/docs/index.html`:

```html
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Docs — Arrival</title>
  <meta name="description" content="Documentation for Arrival, a macOS menubar traffic app.">
  <link rel="icon" type="image/svg+xml" href="../assets/icon/arrival-icon.svg">
  <link rel="stylesheet" href="../css/style.css">
</head>
<body class="overflow-x-hidden">

  <!-- Navigation (same as landing page) -->
  <nav class="fixed top-0 left-0 right-0 z-50 backdrop-blur-md bg-background/80 border-b border-border">
    <div class="max-w-site mx-auto flex items-center justify-between px-6 lg:px-10 h-14">
      <a href="/" class="flex items-center gap-2 font-semibold text-foreground">
        <svg width="24" height="24" viewBox="0 0 96 96" class="flex-shrink-0">
          <defs>
            <linearGradient id="nav-grad" x1="0" y1="1" x2="1" y2="0">
              <stop offset="0%" stop-color="#4DAD80"/><stop offset="40%" stop-color="#4DAD80"/>
              <stop offset="55%" stop-color="#FDC021"/><stop offset="70%" stop-color="#F77070"/>
              <stop offset="85%" stop-color="#FDC021"/><stop offset="100%" stop-color="#4DAD80"/>
            </linearGradient>
          </defs>
          <circle cx="20" cy="72" r="10" fill="#4DAD80"/>
          <path d="M20 72 C20 40, 76 56, 76 24" fill="none" stroke="url(#nav-grad)" stroke-width="7" stroke-linecap="round"/>
          <circle cx="76" cy="24" r="10" fill="#4DAD80"/>
        </svg>
        Arrival
      </a>
      <div class="flex items-center gap-8">
        <a href="/#features" class="text-sm text-foreground-muted hover:text-foreground transition-colors hidden sm:block">Features</a>
        <a href="/docs/" class="text-sm text-foreground hover:text-foreground transition-colors hidden sm:block">Docs</a>
        <a href="/#install" class="text-sm font-semibold bg-clear text-background px-4 py-2 rounded-button hover:bg-clear-end transition-colors">Download</a>
      </div>
    </div>
  </nav>

  <div class="max-w-site mx-auto px-6 lg:px-10 pt-24 pb-16 grid grid-cols-1 lg:grid-cols-[220px_1fr] gap-12">

    <!-- Sidebar -->
    <aside class="hidden lg:block">
      <div class="sticky top-24 space-y-1">
        <p class="text-xs font-semibold uppercase tracking-widest text-foreground-subtle mb-3">Documentation</p>
        <a href="#getting-started" class="block text-sm text-foreground-muted hover:text-foreground py-1 transition-colors">Getting Started</a>
        <a href="#setting-up" class="block text-sm text-foreground-muted hover:text-foreground py-1 transition-colors">Setting Up</a>
        <a href="#using-arrival" class="block text-sm text-foreground-muted hover:text-foreground py-1 transition-colors">Using Arrival</a>
        <a href="#map-window" class="block text-sm text-foreground-muted hover:text-foreground py-1 transition-colors">Map Window</a>
        <a href="#preferences" class="block text-sm text-foreground-muted hover:text-foreground py-1 transition-colors">Preferences</a>
        <a href="#troubleshooting" class="block text-sm text-foreground-muted hover:text-foreground py-1 transition-colors">Troubleshooting</a>
        <a href="#updates" class="block text-sm text-foreground-muted hover:text-foreground py-1 transition-colors">Updates</a>
      </div>
    </aside>

    <!-- Content -->
    <main class="min-w-0">
      <h1 class="text-3xl font-bold tracking-heading mb-8">Documentation</h1>

      <!-- Getting Started -->
      <section id="getting-started" class="mb-16">
        <h2 class="text-xl font-bold tracking-heading mb-4">Getting Started</h2>
        <div class="space-y-4 text-foreground-muted leading-relaxed">
          <p><strong class="text-foreground">1. Download Arrival</strong> from the <a href="/#install" class="text-clear hover:underline">landing page</a> or install via Homebrew:</p>
          <div class="code-block">brew install --cask arrival</div>
          <p><strong class="text-foreground">2. Open the DMG</strong> and drag Arrival to your Applications folder.</p>
          <p><strong class="text-foreground">3. Launch Arrival.</strong> Since the app is not signed with an Apple Developer certificate, macOS will block the first launch. To open it:</p>
          <ol class="list-decimal list-inside space-y-2 ml-4">
            <li>Right-click (or Control-click) on Arrival in your Applications folder</li>
            <li>Select <strong class="text-foreground">"Open"</strong> from the context menu</li>
            <li>Click <strong class="text-foreground">"Open"</strong> in the dialog that appears</li>
          </ol>
          <p>You only need to do this once. After the first launch, Arrival will open normally.</p>
          <p><strong class="text-foreground">4. Look for Arrival in your menubar</strong> — you'll see a time estimate (e.g., "32m") appear in the top-right of your screen.</p>
        </div>
      </section>

      <div class="h-px bg-gradient-to-r from-transparent via-border to-transparent mb-16"></div>

      <!-- Setting Up -->
      <section id="setting-up" class="mb-16">
        <h2 class="text-xl font-bold tracking-heading mb-4">Setting Up</h2>
        <div class="space-y-4 text-foreground-muted leading-relaxed">
          <p>Click the menubar icon, then the <strong class="text-foreground">gear icon</strong> to open Preferences.</p>
          <p><strong class="text-foreground">Addresses:</strong> Enter your home and work addresses in the Addresses tab. Arrival will geocode them and show the resolved coordinates. Make sure both addresses resolve correctly.</p>
          <p><strong class="text-foreground">Schedule:</strong> Set your morning and evening commute windows. Arrival polls more frequently during these hours (every 3 minutes by default) and less frequently outside them (every 15 minutes).</p>
        </div>
      </section>

      <div class="h-px bg-gradient-to-r from-transparent via-border to-transparent mb-16"></div>

      <!-- Using Arrival -->
      <section id="using-arrival" class="mb-16">
        <h2 class="text-xl font-bold tracking-heading mb-4">Using Arrival</h2>
        <div class="space-y-4 text-foreground-muted leading-relaxed">
          <p><strong class="text-foreground">The menubar icon</strong> shows your current estimated drive time. Click it to open the popover with details.</p>
          <p><strong class="text-foreground">Traffic moods</strong> give you an at-a-glance sense of conditions:</p>
          <ul class="space-y-2 ml-4">
            <li class="flex items-center gap-2"><span class="w-3 h-3 rounded-full bg-clear inline-block"></span> <strong class="text-clear">Clear</strong> — smooth sailing, minimal delays</li>
            <li class="flex items-center gap-2"><span class="w-3 h-3 rounded-full bg-moderate inline-block"></span> <strong class="text-moderate">Moderate</strong> — some slowdowns, consider alternatives</li>
            <li class="flex items-center gap-2"><span class="w-3 h-3 rounded-full bg-heavy inline-block"></span> <strong class="text-heavy">Heavy</strong> — significant delays, check incidents</li>
          </ul>
          <p><strong class="text-foreground">Routes</strong> show up to three options with the fastest highlighted. Each route displays per-segment congestion coloring.</p>
          <p><strong class="text-foreground">Incidents</strong> (accidents, closures, advisories) appear when present, with estimated delay impact.</p>
          <p><strong class="text-foreground">Direction</strong> is detected automatically — Arrival knows whether you're heading to work or home based on your location and time of day. You can override this manually in the popover.</p>
        </div>
      </section>

      <div class="h-px bg-gradient-to-r from-transparent via-border to-transparent mb-16"></div>

      <!-- Map Window -->
      <section id="map-window" class="mb-16">
        <h2 class="text-xl font-bold tracking-heading mb-4">Map Window</h2>
        <div class="space-y-4 text-foreground-muted leading-relaxed">
          <p>Click the <strong class="text-foreground">map preview</strong> in the popover to open a detachable map window. This window shows your routes with congestion-colored overlays.</p>
          <p>You can resize and reposition the map window. Click on a route line to select it. The window stays open even when the popover closes.</p>
        </div>
      </section>

      <div class="h-px bg-gradient-to-r from-transparent via-border to-transparent mb-16"></div>

      <!-- Preferences -->
      <section id="preferences" class="mb-16">
        <h2 class="text-xl font-bold tracking-heading mb-4">Preferences</h2>
        <div class="space-y-4 text-foreground-muted leading-relaxed">
          <p><strong class="text-foreground">Polling intervals:</strong> Control how often Arrival checks for traffic updates. Default is 3 minutes during commute hours, 15 minutes outside.</p>
          <p><strong class="text-foreground">Map provider:</strong> Arrival uses Apple MapKit by default (free, no setup). For more detailed congestion data, you can switch to Mapbox by entering a Mapbox API key in Preferences.</p>
          <p><strong class="text-foreground">Launch at login:</strong> Toggle this in the General tab to have Arrival start automatically when you log in.</p>
          <p><strong class="text-foreground">Preferred maps app:</strong> Choose whether route links open in Apple Maps or Google Maps.</p>
        </div>
      </section>

      <div class="h-px bg-gradient-to-r from-transparent via-border to-transparent mb-16"></div>

      <!-- Troubleshooting -->
      <section id="troubleshooting" class="mb-16">
        <h2 class="text-xl font-bold tracking-heading mb-4">Troubleshooting</h2>
        <div class="space-y-6 text-foreground-muted leading-relaxed">
          <div>
            <p class="font-semibold text-foreground">"macOS says the app is from an unidentified developer"</p>
            <p class="mt-1">Right-click the app in your Applications folder and select "Open." Click "Open" in the dialog. You only need to do this once. See <a href="#getting-started" class="text-clear hover:underline">Getting Started</a> for detailed steps.</p>
          </div>
          <div>
            <p class="font-semibold text-foreground">"The app shows '--' instead of a time"</p>
            <p class="mt-1">Check that both your home and work addresses are entered correctly in Preferences. Also verify you have an internet connection — Arrival needs network access to fetch traffic data.</p>
          </div>
          <div>
            <p class="font-semibold text-foreground">"How do I use Mapbox instead of Apple Maps?"</p>
            <p class="mt-1">Open Preferences → General tab. Enter your Mapbox API key in the Mapbox field. Arrival will switch to using Mapbox for traffic data, which provides more detailed congestion annotations.</p>
          </div>
          <div>
            <p class="font-semibold text-foreground">"How do I make it launch at startup?"</p>
            <p class="mt-1">Open Preferences → General tab. Toggle "Launch at login" on.</p>
          </div>
        </div>
      </section>

      <div class="h-px bg-gradient-to-r from-transparent via-border to-transparent mb-16"></div>

      <!-- Updates -->
      <section id="updates" class="mb-16">
        <h2 class="text-xl font-bold tracking-heading mb-4">Updates</h2>
        <div class="space-y-4 text-foreground-muted leading-relaxed">
          <p>Arrival checks for updates automatically using Sparkle. When a new version is available, you'll see an in-app prompt with release notes and the option to update.</p>
          <p>You can also check for updates manually and download the latest version from <a href="https://github.com/kevinguebert/traffic-menubar/releases" class="text-clear hover:underline">GitHub Releases</a>.</p>
        </div>
      </section>

    </main>
  </div>

  <!-- Footer -->
  <footer class="border-t border-border py-8">
    <div class="max-w-site mx-auto px-6 lg:px-10 text-center">
      <p class="text-xs text-foreground-subtle">
        Arrival — a free macOS menubar app ·
        <a href="https://github.com/kevinguebert/traffic-menubar" class="hover:text-foreground transition-colors">GitHub</a> ·
        <a href="/docs/" class="hover:text-foreground transition-colors">Docs</a>
      </p>
    </div>
  </footer>

</body>
</html>
```

- [ ] **Step 2: Rebuild CSS (docs uses same stylesheet) and verify**

```bash
cd /Users/kevinguebert/Documents/Development/traffic-menubar/arrival-site
npm run build
open docs/index.html
```

Verify: Left sidebar with section links, all 7 sections render, sidebar is sticky on scroll, links jump to correct sections, same nav as landing page.

- [ ] **Step 3: Commit**

```bash
git add arrival-site/docs/
git commit -m "feat(site): add docs page with sidebar navigation and all sections"
```

---

### Task 5: Add Minimal JavaScript

**Files:**
- Create: `arrival-site/js/main.js`
- Modify: `arrival-site/index.html` (add script tag)
- Modify: `arrival-site/docs/index.html` (add script tag)

- [ ] **Step 1: Create main.js with copy-to-clipboard and smooth scroll**

Create `arrival-site/js/main.js`:

```js
// Smooth scroll for anchor links
document.querySelectorAll('a[href^="#"]').forEach(link => {
  link.addEventListener('click', (e) => {
    const target = document.querySelector(link.getAttribute('href'));
    if (target) {
      e.preventDefault();
      target.scrollIntoView({ behavior: 'smooth', block: 'start' });
    }
  });
});

// Copy feedback — briefly replace icon with checkmark
document.querySelectorAll('[aria-label="Copy command"]').forEach(btn => {
  btn.addEventListener('click', () => {
    const original = btn.innerHTML;
    btn.innerHTML = '<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="20 6 9 17 4 12"/></svg>';
    setTimeout(() => { btn.innerHTML = original; }, 1500);
  });
});
```

- [ ] **Step 2: Add script tag to both HTML files**

Add before the closing `</body>` tag in both `arrival-site/index.html` and `arrival-site/docs/index.html`:

```html
  <script src="js/main.js"></script>
</body>
```

For `docs/index.html`, the path is `../js/main.js`.

- [ ] **Step 3: Verify in browser**

```bash
open /Users/kevinguebert/Documents/Development/traffic-menubar/arrival-site/index.html
```

Verify: Clicking "Download" in nav smooth-scrolls to install section. Clicking the copy icon next to the Homebrew command copies to clipboard and shows a checkmark.

- [ ] **Step 4: Commit**

```bash
git add arrival-site/js/ arrival-site/index.html arrival-site/docs/index.html
git commit -m "feat(site): add smooth scroll and copy-to-clipboard JS"
```

---

### Task 6: Create DMG Build Script

**Files:**
- Create: `scripts/build-dmg.sh`

- [ ] **Step 1: Install create-dmg**

```bash
brew install create-dmg
```

- [ ] **Step 2: Create the DMG build script**

Create `scripts/build-dmg.sh`:

```bash
#!/bin/bash
set -euo pipefail

# Build a DMG for Arrival
# Usage: ./scripts/build-dmg.sh [path-to-app-bundle]

APP_PATH="${1:-build/Build/Products/Release/TrafficMenubar.app}"
VERSION=$(defaults read "$APP_PATH/Contents/Info.plist" CFBundleShortVersionString 2>/dev/null || echo "1.0.0")
DMG_NAME="Arrival-${VERSION}.dmg"
OUTPUT_DIR="dist"

if [ ! -d "$APP_PATH" ]; then
  echo "Error: App bundle not found at $APP_PATH"
  echo "Build the app first: xcodebuild -project TrafficMenubar.xcodeproj -scheme TrafficMenubar -configuration Release build"
  exit 1
fi

mkdir -p "$OUTPUT_DIR"

# Remove existing DMG if present
rm -f "$OUTPUT_DIR/$DMG_NAME"

create-dmg \
  --volname "Arrival" \
  --volicon "$APP_PATH/Contents/Resources/AppIcon.icns" \
  --window-pos 200 120 \
  --window-size 600 400 \
  --icon-size 100 \
  --icon "TrafficMenubar.app" 175 190 \
  --app-drop-link 425 190 \
  --hide-extension "TrafficMenubar.app" \
  --no-internet-enable \
  "$OUTPUT_DIR/$DMG_NAME" \
  "$APP_PATH"

echo ""
echo "DMG created: $OUTPUT_DIR/$DMG_NAME"
echo "Size: $(du -h "$OUTPUT_DIR/$DMG_NAME" | cut -f1)"
```

- [ ] **Step 3: Make executable**

```bash
chmod +x scripts/build-dmg.sh
```

- [ ] **Step 4: Commit**

```bash
git add scripts/build-dmg.sh
git commit -m "feat: add DMG build script using create-dmg"
```

---

### Task 7: Add Sparkle for Auto-Updates

**Files:**
- Modify: `project.yml` (add Sparkle dependency)
- Create: `arrival-site/appcast.xml`
- Modify: `TrafficMenubar/TrafficMenubarApp.swift` (add Sparkle updater)

- [ ] **Step 1: Add Sparkle as a Swift Package dependency**

In `project.yml`, add Sparkle to the project's package dependencies. Open `project.yml` and add under the top-level:

```yaml
packages:
  Sparkle:
    url: https://github.com/sparkle-project/Sparkle
    from: "2.6.0"
```

And under the target's `dependencies`:

```yaml
    dependencies:
      - package: Sparkle
        product: Sparkle
```

- [ ] **Step 2: Regenerate the Xcode project**

```bash
cd /Users/kevinguebert/Documents/Development/traffic-menubar
xcodegen generate
```

- [ ] **Step 3: Add SUFeedURL to Info.plist**

In `project.yml` under the target's `info` > `properties`, add:

```yaml
    info:
      properties:
        SUFeedURL: https://kevinguebert.github.io/traffic-menubar/appcast.xml
        SUPublicEDKey: ""
```

Note: `SUPublicEDKey` is left empty for now — EdDSA signing is optional but recommended for security. It can be set up later with `generate_keys` from Sparkle.

- [ ] **Step 4: Add Sparkle updater check to the app**

In `TrafficMenubar/TrafficMenubarApp.swift`, add the Sparkle import and updater. Add at the top of the file:

```swift
import Sparkle
```

Add a property to the App struct:

```swift
private let updaterController = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
```

- [ ] **Step 5: Create a placeholder appcast.xml**

Create `arrival-site/appcast.xml`:

```xml
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle" xmlns:dc="http://purl.org/dc/elements/1.1/">
  <channel>
    <title>Arrival Updates</title>
    <link>https://kevinguebert.github.io/traffic-menubar/appcast.xml</link>
    <description>Updates for Arrival</description>
    <language>en</language>
    <!--
      To add a new release, add an <item> block below:

      <item>
        <title>Version X.Y.Z</title>
        <pubDate>Mon, 01 Jan 2026 00:00:00 +0000</pubDate>
        <sparkle:version>BUILD_NUMBER</sparkle:version>
        <sparkle:shortVersionString>X.Y.Z</sparkle:shortVersionString>
        <description><![CDATA[<ul><li>Release notes here</li></ul>]]></description>
        <enclosure
          url="https://github.com/kevinguebert/traffic-menubar/releases/download/vX.Y.Z/Arrival-X.Y.Z.dmg"
          length="FILE_SIZE_BYTES"
          type="application/octet-stream"
          sparkle:edSignature="SIGNATURE" />
      </item>
    -->
  </channel>
</rss>
```

- [ ] **Step 6: Commit**

```bash
git add project.yml TrafficMenubar/TrafficMenubarApp.swift arrival-site/appcast.xml
git commit -m "feat: integrate Sparkle for auto-updates with appcast feed"
```

---

### Task 8: Create Homebrew Cask Formula (Draft)

**Files:**
- Create: `homebrew/arrival.rb`

- [ ] **Step 1: Create a draft cask formula**

Create `homebrew/arrival.rb`:

```ruby
cask "arrival" do
  version "1.0.0"
  sha256 "PLACEHOLDER_SHA256"

  url "https://github.com/kevinguebert/traffic-menubar/releases/download/v#{version}/Arrival-#{version}.dmg"
  name "Arrival"
  desc "Menubar app showing real-time drive time"
  homepage "https://kevinguebert.github.io/traffic-menubar/"

  depends_on macos: ">= :ventura"

  app "TrafficMenubar.app"

  zap trash: [
    "~/Library/Preferences/com.trafficmenubar.app.plist",
  ]
end
```

Note: The `sha256` will be filled in after the first release is published. This formula lives in the repo as a reference — the actual submission to `homebrew/homebrew-cask` happens after the first GitHub Release.

- [ ] **Step 2: Commit**

```bash
git add homebrew/
git commit -m "feat: add draft Homebrew cask formula for Arrival"
```

---

### Task 9: Create GitHub Release Workflow (Draft)

**Files:**
- Create: `scripts/release.sh`

- [ ] **Step 1: Create the release helper script**

Create `scripts/release.sh`:

```bash
#!/bin/bash
set -euo pipefail

# Release helper for Arrival
# Usage: ./scripts/release.sh <version>
# Example: ./scripts/release.sh 1.0.0

VERSION="${1:?Usage: ./scripts/release.sh <version>}"
DMG_PATH="dist/Arrival-${VERSION}.dmg"

echo "=== Arrival Release v${VERSION} ==="
echo ""

# Check DMG exists
if [ ! -f "$DMG_PATH" ]; then
  echo "Error: DMG not found at $DMG_PATH"
  echo "Run ./scripts/build-dmg.sh first"
  exit 1
fi

# Check gh CLI is available
if ! command -v gh &> /dev/null; then
  echo "Error: GitHub CLI (gh) is required. Install with: brew install gh"
  exit 1
fi

# Compute SHA256 for Homebrew cask
SHA256=$(shasum -a 256 "$DMG_PATH" | awk '{print $1}')
echo "SHA256: $SHA256"
echo ""

# Create git tag
echo "Creating tag v${VERSION}..."
git tag -a "v${VERSION}" -m "Release v${VERSION}"
git push origin "v${VERSION}"

# Create GitHub Release
echo "Creating GitHub Release..."
gh release create "v${VERSION}" "$DMG_PATH" \
  --title "Arrival v${VERSION}" \
  --notes "## Arrival v${VERSION}

Download \`Arrival-${VERSION}.dmg\`, open it, and drag Arrival to your Applications folder.

**First launch:** Right-click → Open (required once for unsigned apps).

**SHA256:** \`${SHA256}\`"

echo ""
echo "=== Release published ==="
echo ""
echo "Next steps:"
echo "  1. Update arrival-site/appcast.xml with the new version"
echo "  2. Update homebrew/arrival.rb sha256 to: ${SHA256}"
echo "  3. Deploy the site"
```

- [ ] **Step 2: Make executable**

```bash
chmod +x scripts/release.sh
```

- [ ] **Step 3: Commit**

```bash
git add scripts/release.sh
git commit -m "feat: add GitHub Release helper script"
```

---

### Task 10: Final Wiring and Verification

**Files:**
- Modify: `arrival-site/index.html` (verify all links)
- Modify: `arrival-site/docs/index.html` (verify all links)

- [ ] **Step 1: Rebuild CSS one final time**

```bash
cd /Users/kevinguebert/Documents/Development/traffic-menubar/arrival-site
npm run build
```

- [ ] **Step 2: Verify the landing page in browser**

```bash
open index.html
```

Walk through the full page. Verify:
- Nav links work (Features scrolls, Docs opens docs page, Download scrolls to install)
- Hero text renders with correct typography (big h1, muted second line)
- All 3 feature sections alternate correctly (left/right/left)
- Personality section shows green/amber/red text
- Install section has both cards with working copy button
- Footer links work

- [ ] **Step 3: Verify the docs page**

```bash
open docs/index.html
```

Verify:
- Sidebar links jump to correct sections
- All 7 sections are present and readable
- Nav links back to landing page work
- Styling matches landing page

- [ ] **Step 4: Add placeholder screenshots so the site isn't broken**

```bash
# Create simple placeholder PNGs (1x1 transparent) so img tags don't break
for name in hero-clear routes map incidents; do
  echo "" > arrival-site/assets/screenshots/${name}.png
done
```

Note: User will replace these with real screenshots before launch.

- [ ] **Step 5: Final commit**

```bash
git add -A arrival-site/ scripts/ homebrew/
git commit -m "feat: finalize Arrival launch kit — site, scripts, and distribution"
```

---

## Screenshot Checklist for User

Before deploying, the user needs to take these screenshots at 2x Retina resolution in dark mode and place them in `arrival-site/assets/screenshots/`:

| Filename | What to Capture |
|----------|----------------|
| `hero-clear.png` | Full popover — green accent stripe, "Smooth sailing" badge, 3 routes, ETA |
| `routes.png` | Popover focused on route list with congestion-colored route lines |
| `map.png` | Detached map window with route overlays and congestion coloring |
| `incidents.png` | Popover with red accent stripe, incident alerts showing delays |

---

## Deployment Checklist

1. User provides screenshots → place in `arrival-site/assets/screenshots/`
2. Run `npm run build` in `arrival-site/`
3. Build the app: `xcodebuild -project TrafficMenubar.xcodeproj -scheme TrafficMenubar -configuration Release build`
4. Package DMG: `./scripts/build-dmg.sh`
5. Create release: `./scripts/release.sh 1.0.0`
6. Deploy site to GitHub Pages (push `arrival-site/` contents to `gh-pages` branch or configure in repo settings)
7. Update `appcast.xml` with the release details
8. Update `homebrew/arrival.rb` with the SHA256
9. Submit cask to `homebrew/homebrew-cask` (optional, can be done later)
