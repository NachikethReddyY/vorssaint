// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

/// This new surface intentionally ships with one English source definition.
/// Existing app localization remains untouched; future translations belong in
/// the project's localization workflow rather than duplicated Swift literals.
struct MousePointerStrings {
    let section = "Pointer"
    let mouse = "Mouse"
    let trackpad = "Trackpad"
    let noDevices = "No supported pointer devices are connected."
    let customize = "Customize this device"
    let disableAcceleration = "Disable pointer acceleration"
    let caption = "Each connected device keeps its own pointer settings."
    let acceleration = "Pointer acceleration"
    let trackingSpeed = "Tracking speed"
    let speed = "Pointer speed"
    let revert = "Restore defaults"
    let dpiNote = "This changes macOS pointer scaling, not hardware DPI."
    let permissionCaption = "Accessibility is required for scrolling and button controls. Pointer speed does not require it."
    let permission = "Permission"
    let allMice = "Mouse buttons"
    let allMiceCaption = "These button controls apply to connected mice, not trackpads."
    let trackpadControls = "Trackpad gestures"
    let smoothActive = "Smooth scrolling is active now"
}

extension FeatureStrings {
    static func mousePointer(_ language: AppLanguage) -> MousePointerStrings {
        _ = language
        return MousePointerStrings()
    }
}
