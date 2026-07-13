cask "browserino" do
  # ponytail: tracks the rolling `latest` release, so there's no sha to bump per build.
  # Switch to a pinned version + sha256 if `brew upgrade` needs to detect new builds
  # without --greedy.
  version :latest
  sha256 :no_check

  url "https://github.com/istaiti/Browserino/releases/latest/download/Browserino.zip"
  name "Browserino"
  desc "Browser picker for macOS"
  homepage "https://github.com/istaiti/Browserino"

  depends_on macos: ">= :sonoma"

  app "Browserino.app"

  zap trash: [
    "~/Library/Preferences/xyz.alexstrnik.Browserino.plist",
  ]
end
