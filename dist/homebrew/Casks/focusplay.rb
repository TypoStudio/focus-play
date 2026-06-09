cask "focusplay" do
  version "1.0.1"
  sha256 "7869d4849919a79e076fc7f786ef43a4202c12cb27633ed8d0ce2212a290662b"

  url "https://github.com/TypoStudio/focus-play/releases/download/v#{version}/FocusPlay-#{version}.zip"
  name "FocusPlay"
  desc "Multi-monitor focus mode menu bar app"
  homepage "https://github.com/TypoStudio/focus-play"

  auto_updates false

  app "FocusPlay.app"

  zap trash: "~/Library/Preferences/com.typostudio.focusplay.plist"
end
