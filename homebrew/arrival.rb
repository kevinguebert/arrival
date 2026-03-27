cask "arrival" do
  version "1.1.0"
  sha256 "690b6fbc20bd0227f2181137fb575c12d2c01a4aa35d2ab722054070e44fe8c6"

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
