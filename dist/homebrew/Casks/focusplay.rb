cask "focusplay" do
  version "1.0.2"
  sha256 "8a19a3747c69aa31da64370d7452e6524a3cf876fc3417399bf0f5b524649219"

  url "https://github.com/TypoStudio/focus-play/releases/download/v#{version}/FocusPlay-#{version}.dmg"
  name "FocusPlay"
  desc "Multi-monitor focus mode menu bar app"
  homepage "https://github.com/TypoStudio/focus-play"

  auto_updates false

  app "FocusPlay.app"

  zap trash: "~/Library/Preferences/com.typostudio.focusplay.plist"
end
