cask "arrival" do
  version "1.0.0"
  sha256 "7f6e35ca0e5f20359c39a156da9991de6d1987a72811f053de8f9c40ae570b5c"

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
