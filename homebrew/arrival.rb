cask "arrival" do
  version "1.1.0"
  sha256 "c67b3cb2dec7d9ecb90b9ff5c6c746e137beccf3656979e38791a333b452e00f"

  url "https://github.com/kevinguebert/arrival/releases/download/v#{version}/Arrival-#{version}.dmg"
  name "Arrival"
  desc "Menubar app showing real-time drive time"
  homepage "https://arrival-app.vercel.app/"

  depends_on macos: ">= :ventura"

  app "Arrival.app"

  zap trash: [
    "~/Library/Preferences/com.arrival.app.plist",
  ]
end
