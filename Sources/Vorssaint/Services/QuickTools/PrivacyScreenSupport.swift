// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

/// Pure message policy for Privacy Share, kept separate so editing behavior
/// can be tested without opening a real capture window.
enum PrivacyScreenSupport {
    static let defaultMessage = "Screen hidden"
    static let maximumMessageLength = 280
    static let distortionStyle = DistortionStyle(
        blurRadius: 18,
        blurLayerCount: 3,
        scale: 1.14,
        saturation: 1.0,
        brightness: 0.08,
        darkeningOpacity: 0.12
    )

    struct DistortionStyle: Equatable {
        let blurRadius: Double
        let blurLayerCount: Int
        let scale: Double
        let saturation: Double
        let brightness: Double
        let darkeningOpacity: Double

        var effectiveBlurRadius: Double {
            blurRadius * sqrt(Double(blurLayerCount))
        }
    }

    static func message(from raw: String?) -> String {
        let trimmed = (raw ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return defaultMessage }
        return String(trimmed.prefix(maximumMessageLength))
    }

    /// Bounds live input without trimming it. Trimming while the field is
    /// being edited removes the space before the user can type another word.
    static func editingMessage(from raw: String) -> String {
        String(raw.prefix(maximumMessageLength))
    }
}
