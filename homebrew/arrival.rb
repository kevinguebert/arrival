cask "arrival" do
  version "1.0.0"
  sha256 "PLACEHOLDER_SHA256"

  url "https://github.com/kevinguebert/traffic-menubar/releases/download/v#{version}/Arrival-#{version}.dmg"
  name "Arrival"
  desc "Menubar app showing real-time drive time"
  homepage "https://kevinguebert.github.io/traffic-menubar/"

  depends_on macos: ">= :ventura"

  app "Arrival.app"

  zap trash: [
    "~/Library/Preferences/com.arrival.app.plist",
  ]
end
