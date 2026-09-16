// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

enum PrivacyScreenTests {
    static func run(_ suite: TestSuite) {
        suite.expect(PrivacyScreenSupport.message(from: "  Reviewing private data  ")
                        == "Reviewing private data",
                     "privacy message trims surrounding whitespace")
        suite.expect(PrivacyScreenSupport.editingMessage(from: "Nachiketh ") == "Nachiketh ",
                     "editing preserves a trailing space for the next word")
        suite.expect(PrivacyScreenSupport.message(from: "  \n ")
                        == PrivacyScreenSupport.defaultMessage,
                     "a blank privacy message falls back to the safe default")

        let oversized = String(repeating: "private ", count: 80)
        suite.expect(PrivacyScreenSupport.message(from: oversized).count
                        == PrivacyScreenSupport.maximumMessageLength,
                     "privacy message is bounded for a stable full-screen layout")
        suite.expect(PrivacyScreenSupport.editingMessage(from: oversized).count
                        == PrivacyScreenSupport.maximumMessageLength,
                     "editing still bounds oversized privacy messages")

        let distortion = PrivacyScreenSupport.distortionStyle
        suite.expect(distortion.blurLayerCount == 3,
                     "privacy distortion stacks exactly three blur layers")
        suite.expect(distortion.effectiveBlurRadius >= 28,
                     "stacked privacy distortion keeps fine detail unreadable")
        suite.expect(distortion.scale > 1,
                     "privacy distortion overscans to keep blurred edges covered")
        suite.expect((0.08...0.18).contains(distortion.darkeningOpacity),
                     "privacy distortion preserves source color under a light veil")
        suite.expect(distortion.saturation >= 0.90,
                     "privacy distortion lets source colors bleed through")
        suite.expect(distortion.brightness >= 0.05,
                     "privacy distortion lifts dark source colors")

        suite.expect(Defaults.registeredDefaults[DefaultsKey.privacyScreenShortcutEnabled] as? Bool == true,
                     "privacy shortcut starts enabled")
        suite.expect(Defaults.registeredDefaults[DefaultsKey.privacyScreenShortcut] as? String
                        == GlobalShortcut.privacyScreenDefault.storageValue,
                     "privacy shortcut has the documented default")
        suite.expect(SettingsBackupSupport.exportKeys().isSuperset(of: [
            DefaultsKey.privacyScreenShortcutEnabled,
            DefaultsKey.privacyScreenShortcut,
            DefaultsKey.privacyScreenMessage,
        ]), "privacy preferences travel in settings backups")
        suite.expect(GlobalShortcutRole.privacyScreen.feature == .privacyScreen,
                     "privacy shortcut follows privacy feature availability")
        suite.expect(AppFeature.privacyScreen.settingsDestination
                        == FeatureSettingsDestination(.privacyScreen,
                                                      sectionAnchor: .privacyScreen),
                     "privacy feature opens its dedicated Settings page")
        suite.expect(FeatureVisibilitySupport.features(for: .privacyScreen) == [.privacyScreen],
                     "privacy Settings page follows feature installation")

        let settingsSource = try? String(
            contentsOfFile: "Sources/Vorssaint/UI/Settings/QuickToolsSettings.swift",
            encoding: .utf8
        )
        suite.expect(settingsSource != nil,
                     "privacy Settings source is readable")
        suite.expect(settingsSource?.contains("privacyScreen.openShareWindow()") == false
                        && settingsSource?.contains("privacyScreen.toggle()") == false,
                     "privacy Settings relies on the recorded shortcut instead of redundant action buttons")
    }
}
