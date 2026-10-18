# Homebrew Cask for Silver Rain Mini — lives in umkasanki/homebrew-tap as
# Casks/silver-rain-mini.rb. The release workflow keeps `version` and `sha256`
# there in step with each release; this copy is the template it started from.
#
# Install (users):
#   brew tap umkasanki/tap
#   brew trust umkasanki/tap        # third-party taps must be trusted once
#   brew install --cask silver-rain-mini
cask "silver-rain-mini" do
  version "1.0.0"
  sha256 "REPLACE_WITH_DMG_SHA256"   # printed by `make dmg`

  url "https://github.com/umkasanki/SilverRainMini/releases/download/v#{version}/SilverRainMini-#{version}.dmg"
  name "Silver Rain Mini"
  desc "Menu bar player for the Silver Rain radio station"
  homepage "https://github.com/umkasanki/SilverRainMini"

  depends_on macos: :tahoe

  app "Silver Rain Mini.app"

  # Self-signed, not notarized: without this Gatekeeper refuses the first launch.
  postflight_steps do
    run "/usr/bin/xattr", args: ["-dr", "com.apple.quarantine", "{{appdir}}/Silver Rain Mini.app"]
  end

  uninstall quit: "local.oleg.SilverRainMini"

  zap trash: "~/Library/Preferences/local.oleg.SilverRainMini.plist"
end
