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
    let caption = "Choose a connected mouse or trackpad, then adjust only that device."
    let acceleration = "Pointer acceleration"
    let trackingSpeed = "Tracking speed"
    let speed = "Pointer speed"
    let revert = "Revert this device to system defaults"
    let dpiNote = "This changes macOS pointer scaling, not hardware DPI."
    let permissionCaption = "Accessibility is required for scrolling and button controls. Pointer speed does not require it."
    let permission = "Permission"
    let allMice = "All mice"
    let allMiceCaption = "These controls apply to every connected mouse, not trackpads."
    let trackpadControls = "Trackpad"
    let smoothActive = "Smooth scrolling is active now"
}

extension FeatureStrings {
    static func mousePointer(_ language: AppLanguage) -> MousePointerStrings {
        _ = language
        return MousePointerStrings()
    }
}
