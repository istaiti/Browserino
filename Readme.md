# Browserino

![Browserino](images/browserino.png?v2)

Browserino is a tiny browser selector for MacOS written in SwiftUI. Just set as default browser, assign shortcuts, and now you can choose in which application you want to open the link.

Inspired by great [Browserosaurus](https://github.com/will-stone/browserosaurus), but a little bit faster and smaller thanks to native code, and fixes annoying Electron bug.

# Installation

Download the latest build from the [releases page](https://github.com/istaiti/Browserino/releases/latest),
unzip it, and drag `Browserino.app` into `/Applications`.

The build is unsigned, so macOS Gatekeeper will refuse to open it. Strip the quarantine
flag once, and it launches normally from then on:

```bash
xattr -dr com.apple.quarantine /Applications/Browserino.app
```

If you want to support the app, you can buy it on [Gumroad](https://alexstrnik.gumroad.com/l/browserino).
