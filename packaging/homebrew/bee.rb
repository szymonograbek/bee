# Template for Casks/bee.rb in szymonograbek/homebrew-tap.
# The release workflow fills in __VERSION__ and __SHA256__ and pushes the result.
cask "bee" do
  version "__VERSION__"
  sha256 "__SHA256__"

  url "https://github.com/szymonograbek/bee/releases/download/v#{version}/Bee.zip"
  name "Bee"
  desc "Menu bar app that keeps your Mac awake"
  homepage "https://github.com/szymonograbek/bee"

  depends_on macos: ">= :sequoia"

  app "Bee.app"

  # Bee is ad-hoc signed, not notarized, so Gatekeeper would refuse to open it.
  postflight do
    system_command "/usr/bin/xattr",
                   args: ["-dr", "com.apple.quarantine", "#{appdir}/Bee.app"]
  end

  uninstall quit: "com.szymonograbek.Bee"

  zap trash: "~/Library/Preferences/com.szymonograbek.Bee.plist"
end
