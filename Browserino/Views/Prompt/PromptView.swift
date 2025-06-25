//
//  PromptView.swift
//  Browserino
//
//  Created by Aleksandr Strizhnev on 06.06.2024.
//

import AppKit
import SwiftUI

struct PromptView: View {
    @AppStorage("browsers") private var browsers: [BrowserItem] = []
    @AppStorage("hiddenBrowsers") private var hiddenBrowsers: [BrowserItem] = []
    @AppStorage("apps") private var apps: [App] = []
    @AppStorage("shortcuts") private var shortcuts: [String: String] = [:]

    @AppStorage("copy_closeAfterCopy") private var closeAfterCopy: Bool = false
    @AppStorage("copy_alternativeShortcut") private var alternativeShortcut: Bool = false
    @AppStorage("apps_atTop") private var appsAtTop: Bool = true

    let urls: [URL]

    @State private var opacityAnimation = 0.0
    @State private var selected = 0
    @FocusState private var focused: Bool

    private func isChrome(_ bundle: Bundle) -> Bool {
        return bundle.bundleIdentifier == "com.google.Chrome"
    }

    private func shortcutKey(for browser: BrowserItem, bundleId: String) -> String {
        if let profile = browser.profile {
            return "\(bundleId)_\(profile.id)"
        }
        return bundleId
    }

    var appsForUrls: [App] {
        urls.flatMap { url in
            return apps.filter { app in
                url.matchesHost(app.host)
            }
        }
    }

    var visibleBrowsers: [BrowserItem] {
        browsers.filter { !hiddenBrowsers.contains($0) }
    }

    func openUrlsInApp(app: App) {
        let urls =
            if app.schemeOverride.isEmpty {
                urls
            } else {
                urls.map {
                    let url = NSURLComponents.init(
                        url: $0,
                        resolvingAgainstBaseURL: true
                    )
                    url!.scheme = app.schemeOverride

                    return url!.url!
                }
            }

        BrowserUtil.openURL(
            urls,
            app: app.app,
            isIncognito: false
        )
    }

    private func openBrowser(_ browser: BrowserItem, isIncognito: Bool) {
        BrowserUtil.openURL(
            urls,
            app: browser.url,
            isIncognito: isIncognito,
            chromeProfile: browser.profile
        )
    }

    private func displayName(for browser: BrowserItem, bundle: Bundle) -> String? {
        if isChrome(bundle), let profile = browser.profile {
            let baseName = bundle.infoDictionary!["CFBundleName"] as! String
            return "\(baseName) (\(profile.name))"
        }
        return nil
    }

    var body: some View {
        VStack {
            ScrollViewReader { scrollViewProxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 2) {
                        if !appsForUrls.isEmpty && appsAtTop {
                            ForEach(Array(appsForUrls.enumerated()), id: \.offset) { index, app in
                                appItemView(app: app, index: index)
                            }

                            Divider()
                        }

                        ForEach(Array(visibleBrowsers.enumerated()), id: \.offset) {
                            index, browser in
                            if let bundle = Bundle(url: browser.url) {
                                let bundleId = bundle.bundleIdentifier!
                                let baseIndex = index + (appsAtTop ? appsForUrls.count : 0)
                                PromptItem(
                                    browser: browser.url,
                                    urls: urls,
                                    bundle: bundle,
                                    shortcut: shortcuts[shortcutKey(for: browser, bundleId: bundleId)],
                                    displayName: displayName(for: browser, bundle: bundle)
                                ) {
                                    openBrowser(browser, isIncognito: NSEvent.modifierFlags.contains(.shift))
                                }
                                .id(baseIndex)
                                .buttonStyle(
                                    SelectButtonStyle(
                                        selected: selected == baseIndex
                                    )
                                )
                            }
                        }

                        if !appsForUrls.isEmpty && !appsAtTop {
                            Divider()

                            ForEach(Array(appsForUrls.enumerated()), id: \.offset) { index, app in
                                if let bundle = Bundle(url: app.app) {
                                    PromptItem(
                                        browser: app.app,
                                        urls: urls,
                                        bundle: bundle,
                                        shortcut: shortcuts[bundle.bundleIdentifier!]
                                    ) {
                                        openUrlsInApp(app: app)
                                    }
                                    .id(visibleBrowsers.count + index)
                                    .buttonStyle(
                                        SelectButtonStyle(
                                            selected: selected == visibleBrowsers.count + index
                                        )
                                    )
                                }
                            }
                        }
                    }
                }
                .focusable()
                .focusEffectDisabledCompat()
                .focused($focused)
                .onMoveCommand { command in
                    if command == .up {
                        selected = max(0, selected - 1)
                        scrollViewProxy.scrollTo(selected, anchor: .center)
                    } else if command == .down {
                        selected = min(visibleBrowsers.count + appsForUrls.count - 1, selected + 1)
                        scrollViewProxy.scrollTo(selected, anchor: .center)
                    }
                }
                .background {
                    Button(action: {
                        if appsAtTop {
                            if selected < appsForUrls.count {
                                openUrlsInApp(app: appsForUrls[selected])
                            } else {
                                openBrowser(visibleBrowsers[selected - appsForUrls.count], isIncognito: false)
                            }
                        } else {
                            if selected < visibleBrowsers.count {
                                openBrowser(visibleBrowsers[selected], isIncognito: false)
                            } else {
                                openUrlsInApp(app: appsForUrls[selected - visibleBrowsers.count])
                            }
                        }
                    }) {}
                    .opacity(0)
                    .keyboardShortcut(.defaultAction)

                    Button(action: {
                        if appsAtTop {
                            if selected < appsForUrls.count {
                                openUrlsInApp(app: appsForUrls[selected])
                            } else {
                                openBrowser(visibleBrowsers[selected - appsForUrls.count], isIncognito: true)
                            }
                        } else {
                            if selected < visibleBrowsers.count {
                                openBrowser(visibleBrowsers[selected], isIncognito: true)
                            } else {
                                openUrlsInApp(app: appsForUrls[selected - visibleBrowsers.count])
                            }
                        }
                    }) {}
                    .opacity(0)
                    .keyboardShortcut(.return, modifiers: [.shift])

                    Button(action: {
                        NSApplication.shared.keyWindow?.close()
                    }) {}
                    .opacity(0)
                    .keyboardShortcut(.cancelAction)
                }
                .onAppear {
                    focused.toggle()
                    withAnimation(.interactiveSpring(duration: 0.3)) {
                        opacityAnimation = 1
                    }
                }
                .scrollEdgeEffectDisabledCompat()
            }

            Divider()

            if let host = urls.first?.host() {
                Button(action: {
                    let pasteboard = NSPasteboard.general
                    pasteboard.declareTypes([.string], owner: nil)
                    pasteboard.setString(urls.first?.absoluteString ?? "", forType: .string)

                    if closeAfterCopy {
                        NSApplication.shared.keyWindow?.close()
                    }
                }) {
                    Text(
                        host
                    )
                }
                .buttonStyle(.plain)
                .keyboardShortcut(
                    KeyEquivalent("c"),
                    modifiers: alternativeShortcut ? [.command] : [.command, .option]
                )
                .toolTip(urls.first?.absoluteString ?? "")
            }
        }
        .padding(12)
        .frame(
            maxWidth: .infinity,
            maxHeight: .infinity
        )
        .background(BlurredView())
        .opacity(opacityAnimation)
        .edgesIgnoringSafeArea(.all)
    }

    @ViewBuilder
    private func appItemView(app: App, index: Int) -> some View {
        if let bundle = Bundle(url: app.app) {
            PromptItem(
                browser: app.app,
                urls: urls,
                bundle: bundle,
                shortcut: shortcuts[bundle.bundleIdentifier!]
            ) {
                openUrlsInApp(app: app)
            }
            .id(index)
            .buttonStyle(
                SelectButtonStyle(
                    selected: selected == index
                )
            )
        }
    }
}

#Preview {
    PromptView(urls: [])
}
