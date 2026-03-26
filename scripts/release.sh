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
