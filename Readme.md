# Browserino

![Browserino](images/browserino.png?v2)

Browserino is a tiny browser selector for MacOS written in SwiftUI. Just set as default browser, assign shortcuts, and now you can choose in which application you want to open the link.

Inspired by great [Browserosaurus](https://github.com/will-stone/browserosaurus), but a little bit faster and smaller thanks to native code, and fixes annoying Electron bug.

# Installation

```bash
brew tap istaiti/browserino https://github.com/istaiti/Browserino
brew install --cask --no-quarantine browserino
```

Or download Browserino from the [releases page](https://github.com/istaiti/Browserino/releases).

The build is unsigned, hence `--no-quarantine`. Without it macOS Gatekeeper blocks the
app, and you have to strip the quarantine flag by hand:

```bash
xattr -dr com.apple.quarantine /Applications/Browserino.app
```

If you want to support the app, you can buy it on [Gumroad](https://alexstrnik.gumroad.com/l/browserino).
