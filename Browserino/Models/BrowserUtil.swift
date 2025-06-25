//  BrowserUtil.swift
//  Browserino
//
//  Created by byt3m4st3r.
//

import AppKit
import Foundation
import SwiftUI

struct BrowserItem: Codable, Identifiable, Hashable {
    let id: String
    let url: URL
    let profile: ChromeProfile?

    init(url: URL, profile: ChromeProfile? = nil) {
        self.id = profile?.id ?? url.path
        self.url = url
        self.profile = profile
    }

    static func == (lhs: BrowserItem, rhs: BrowserItem) -> Bool {
        return lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

struct ChromeProfile: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let path: String

    static func == (lhs: ChromeProfile, rhs: ChromeProfile) -> Bool {
        return lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

class BrowserUtil {
    @AppStorage("directories") private static var directories: [Directory] = []
    @AppStorage("privateArgs") private static var privateArgs: [String: String] = [:]
    @AppStorage("enableLogging") private static var enableLogging: Bool = true

    static func log(_ message: String, items: [String] = []) {
        guard enableLogging else { return }
        print(message)
        items.forEach { print($0) }
    }

    static func toggleLogging() {
        enableLogging.toggle()
        log("\n🔄 Logging is now \(enableLogging ? "enabled" : "disabled")")
    }

    static func loadBrowsers(
        oldBrowsers: [BrowserItem] = []
    ) -> [BrowserItem] {
        if directories.isEmpty {
            let defaultDirectory = Directory(directoryPath: "/Applications")
            directories.append(defaultDirectory)
        }

        let validDirectories = directories.map { $0.directoryPath }

        guard let url = URL(string: "https:") else {
            return []
        }

        let urlsForApplications = NSWorkspace.shared.urlsForApplications(toOpen: url)

        var filteredUrlsForApplications = urlsForApplications.filter { urlsForApplication in
            validDirectories.contains { urlsForApplication.path.hasPrefix($0) }
        }

        let excludedBundleIdentifiers: Set<String> = [
            Bundle.main.bundleIdentifier ?? "xyz.alexstrnik.Browserino",
            "com.hegenberg.BetterTouchTool",
            "com.browserosaurus",
            "com.parallels.desktop.appstore"
        ]
        filteredUrlsForApplications.removeAll { browser in
            guard let bundle = Bundle(url: browser) else { return false }
            return excludedBundleIdentifiers.contains(bundle.bundleIdentifier ?? "")
        }

        if let safari = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Safari") {
            if !filteredUrlsForApplications.contains(safari) {
                filteredUrlsForApplications.append(safari)
            }
        }

        var browserItems: [BrowserItem] = []

        for browserURL in filteredUrlsForApplications {
            if let bundle = Bundle(url: browserURL), bundle.bundleIdentifier == "com.google.Chrome" {
                let profiles = getChromeProfiles()
                if profiles.isEmpty {
                    browserItems.append(BrowserItem(url: browserURL))
                } else {
                    for profile in profiles {
                        browserItems.append(BrowserItem(url: browserURL, profile: profile))
                    }
                }
            } else {
                browserItems.append(BrowserItem(url: browserURL))
            }
        }

        var oldPositions: [String: Int] = [:]
        for (index, browser) in oldBrowsers.enumerated() {
            oldPositions[browser.id] = index
        }

        browserItems.sort { browser1, browser2 in
            if let pos1 = oldPositions[browser1.id], let pos2 = oldPositions[browser2.id] {
                return pos1 < pos2
            }
            else if oldPositions[browser1.id] != nil {
                return true
            }
            else if oldPositions[browser2.id] != nil {
                return false
            }

            return true
        }

        return browserItems
    }

    static func getChromeProfiles() -> [ChromeProfile] {
        log("🔍 Getting Chrome profiles...")
        let fileManager = FileManager.default
        let userPath = fileManager.homeDirectoryForCurrentUser.path
        let chromePath = "\(userPath)/Library/Application Support/Google/Chrome"

        log("📁 Chrome path: \(chromePath)")

        guard fileManager.fileExists(atPath: chromePath) else {
            log("❌ Chrome directory not found")
            return []
        }

        let localStatePath = "\(chromePath)/Local State"
        log("📄 Local State path: \(localStatePath)")

        guard fileManager.fileExists(atPath: localStatePath),
              let data = try? Data(contentsOf: URL(fileURLWithPath: localStatePath)),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let info = json["profile"] as? [String: Any],
              let profiles = info["info_cache"] as? [String: [String: Any]] else {
            log("❌ Failed to read or parse Chrome profile data")
            return []
        }

        let chromeProfiles = profiles.compactMap { (id, profile) -> ChromeProfile? in
            guard let name = profile["name"] as? String else { return nil }

            return ChromeProfile(
                id: id,
                name: name,
                path: "\(chromePath)/\(id)"
            )
        }.sorted { $0.name < $1.name }

        log("✅ Found \(chromeProfiles.count) Chrome profiles:")
        chromeProfiles.forEach { profile in
            log("", items: [
                "  - Profile: \(profile.name)",
                "  - Directory: \(profile.id)",
                "  - Path: \(profile.path)"
            ])
        }

        return chromeProfiles
    }

    static func openURL(_ urls: [URL], app: URL, isIncognito: Bool, chromeProfile: ChromeProfile? = nil) {
        log("\n🌐 Opening URLs...")
        log("", items: [
            "📱 App: \(app.path)",
            "🕶 Incognito: \(isIncognito)"
        ])

        if let profile = chromeProfile {
            log("👤 Chrome Profile:", items: [
                "  - Name: \(profile.name)",
                "  - ID: \(profile.id)",
                "  - Path: \(profile.path)"
            ])
        }

        guard let bundle = Bundle(url: app) else {
            log("❌ Failed to get bundle for app")
            return
        }
        log("📦 Bundle ID: \(bundle.bundleIdentifier ?? "unknown")")

        let configuration = NSWorkspace.OpenConfiguration()

        if bundle.bundleIdentifier == "com.google.Chrome" && chromeProfile != nil {
            configuration.createsNewApplicationInstance = true
            let profileArg = "--profile-directory=\(chromeProfile!.id)"
            let args = ["--args"] + [profileArg] + urls.map(\.absoluteString)
            configuration.arguments = args
            log("🔧 Chrome configuration:", items: [
                "  - New instance: true",
                "  - Profile arg: \(profileArg)",
                "  - Arguments: \(args)"
            ])

            NSWorkspace.shared.open(
                [],
                withApplicationAt: app,
                configuration: configuration
            )
        } else if isIncognito, let privateArg = privateArgs[bundle.bundleIdentifier!] {
            configuration.createsNewApplicationInstance = true
            let args = [privateArg] + urls.map(\.absoluteString)
            configuration.arguments = args
            log("🔧 Incognito configuration:", items: [
                "  - New instance: true",
                "  - Arguments: \(args)"
            ])

            NSWorkspace.shared.open(
                [],
                withApplicationAt: app,
                configuration: configuration
            )
        } else {
            log("🔧 Regular browser configuration")
            NSWorkspace.shared.open(
                urls,
                withApplicationAt: app,
                configuration: configuration
            )
        }

        log("✅ Open command sent to system")
    }
}
