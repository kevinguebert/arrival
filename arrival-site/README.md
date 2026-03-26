# Arrival — Marketing Site & Distribution

## Local Development

```bash
cd arrival-site
npm install
npm run dev    # watches for changes
```

Open `index.html` in a browser to preview. The dev script recompiles CSS on file changes.

To build for production:

```bash
npm run build
```

## Screenshots

Replace the placeholder files in `assets/screenshots/` with real app screenshots. Take them at 2x Retina resolution in dark mode.

| Filename | What to capture |
|----------|----------------|
| `hero-clear.png` | Full popover — green accent stripe, "Smooth sailing" badge, 3 routes, ETA |
| `routes.png` | Popover focused on route list with congestion-colored route lines |
| `map.png` | Detached map window with route overlays and congestion coloring |
| `incidents.png` | Popover with red accent stripe, incident alerts showing delays |

## Release Checklist

### First time setup

1. **Regenerate Xcode project** (picks up Sparkle dependency):
   ```bash
   xcodegen generate
   ```

2. **Open in Xcode and resolve packages:**
   ```bash
   open Arrival.xcodeproj
   ```
   Wait for Swift Package Manager to fetch Sparkle. Build once to verify.

3. **(Optional) Generate Sparkle signing keys:**
   ```bash
   # From the Sparkle package's bin/ directory after it's fetched:
   ./generate_keys
   ```
   Add the public key to `SUPublicEDKey` in `project.yml`, then regenerate with `xcodegen generate`.

### Each release

1. **Take screenshots** and place in `arrival-site/assets/screenshots/`.

2. **Build the app:**
   ```bash
   xcodebuild -project Arrival.xcodeproj -scheme Arrival -configuration Release build
   ```

3. **Package the DMG:**
   ```bash
   ./scripts/build-dmg.sh
   ```
   Requires `create-dmg` — install with `brew install create-dmg` if needed.

4. **Publish the release:**
   ```bash
   ./scripts/release.sh 1.0.0
   ```
   This creates a git tag, pushes it, and creates a GitHub Release with the DMG attached. Requires `gh` CLI — install with `brew install gh`.

5. **Update appcast.xml** — add an `<item>` block to `arrival-site/appcast.xml` with the new version, URL, and file size. See the commented template in the file.

6. **Update Homebrew cask** — replace the `sha256` in `homebrew/arrival.rb` with the value printed by the release script.

7. **Build and deploy the site:**
   ```bash
   cd arrival-site
   npm run build
   ```
   Deploy the contents of `arrival-site/` to GitHub Pages, Netlify, or Vercel.

### Homebrew submission

After the first GitHub Release is live:

1. Fork `homebrew/homebrew-cask`
2. Copy `homebrew/arrival.rb` to `Casks/a/arrival.rb` in the fork
3. Fill in the real `sha256`
4. Open a PR

## Gatekeeper (unsigned app)

Since the app is not signed with an Apple Developer certificate, first-time users need to:

1. Right-click Arrival in Applications
2. Select "Open"
3. Click "Open" in the dialog

This is documented on the [docs page](docs/index.html#getting-started). To remove this requirement, join the Apple Developer Program ($99/year), sign with a Developer ID certificate, and notarize.
