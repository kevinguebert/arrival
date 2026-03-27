cask "arrival" do
  version "1.1.1"
  sha256 "4db26d58a6e7795449ad2166342596978f699ffcf5e0ec21a5a8aba916c850aa"

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
