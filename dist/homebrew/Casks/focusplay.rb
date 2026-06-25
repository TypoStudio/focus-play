cask "focusplay" do
  version "1.0.3"
  sha256 "9970bec293e6e114ebd73b42932544a8242cdf8542da8cc35a5f3c4edf42dcf2"

  url "https://github.com/TypoStudio/focus-play/releases/download/v#{version}/FocusPlay-#{version}.dmg"
  name "FocusPlay"
  desc "Multi-monitor focus mode menu bar app"
  homepage "https://github.com/TypoStudio/focus-play"

  auto_updates false

  app "FocusPlay.app"

  zap trash: "~/Library/Preferences/com.typostudio.focusplay.plist"
end
