// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

struct MouseAccelerationDeviceIdentity: Codable, Equatable {
    let vendorID: Int64?
    let productID: Int64?
    let locationID: Int64?
    let transport: String?
    let physicalUniqueID: String?
    let serialNumber: String?

    func matches(_ other: MouseAccelerationDeviceIdentity) -> Bool {
        if let physicalUniqueID, let otherID = other.physicalUniqueID {
            return physicalUniqueID == otherID
        }
        if let serialNumber, let otherSerial = other.serialNumber {
            return serialNumber == otherSerial
        }
        return vendorID == other.vendorID
            && productID == other.productID
            && locationID == other.locationID
            && transport == other.transport
    }

    var canMatchAcrossRegistryIDs: Bool {
        physicalUniqueID != nil
            || serialNumber != nil
            || ((vendorID ?? 0) > 0 && (productID ?? 0) > 0 && (locationID ?? 0) > 0)
    }
}

struct MouseAccelerationStoredValue: Codable, Equatable {
    let rawValue: Int64
    let isBoolean: Bool
}

struct MousePointerPreferences: Equatable {
    let disablesAcceleration: Bool
    let acceleration: Double
    let speed: Double
}

struct MouseAccelerationRecoveryEntry: Codable, Equatable {
    let registryID: UInt64
    let identity: MouseAccelerationDeviceIdentity
    let key: String
    let original: MouseAccelerationStoredValue
}

struct MouseAccelerationRecoveryJournal: Codable, Equatable {
    let bootTime: Int64
    var entries: [MouseAccelerationRecoveryEntry]

    func entry(registryID: UInt64,
               identity: MouseAccelerationDeviceIdentity,
               key: String) -> MouseAccelerationRecoveryEntry? {
        entries.first {
            $0.registryID == registryID && $0.identity.matches(identity) && $0.key == key
        }
    }

    func entriesToRestore(preserving connectedDevices: [UInt64: MouseAccelerationDeviceIdentity])
        -> [MouseAccelerationRecoveryEntry] {
        entries.filter { entry in
            guard let identity = connectedDevices[entry.registryID] else { return true }
            return !entry.identity.matches(identity)
        }
    }

    mutating func upsert(_ entry: MouseAccelerationRecoveryEntry) {
        entries.removeAll { $0.registryID == entry.registryID && $0.key == entry.key }
        entries.append(entry)
        entries.sort {
            $0.registryID == $1.registryID ? $0.key < $1.key : $0.registryID < $1.registryID
        }
    }

    mutating func remove(registryID: UInt64, key: String) {
        entries.removeAll { $0.registryID == registryID && $0.key == key }
    }

    func staleEntries(registryID: UInt64,
                      identity: MouseAccelerationDeviceIdentity,
                      preserving keys: [String]) -> [MouseAccelerationRecoveryEntry] {
        let preservedKeys = Set(keys)
        return entries.filter {
            $0.registryID == registryID
                && $0.identity.matches(identity)
                && !preservedKeys.contains($0.key)
        }
    }
}

/// A short settling window after hotplug, never a repeating idle timer.
struct MouseAccelerationReapplySchedule {
    private var generation: UUID?
    private var delays: ArraySlice<TimeInterval> = []

    mutating func restart() -> UUID {
        let token = UUID()
        generation = token
        delays = [0, 0.25, 0.75, 1.5, 2.5]
        return token
    }

    func isCurrent(_ token: UUID) -> Bool {
        generation == token
    }

    mutating func nextDelay(for token: UUID) -> TimeInterval? {
        guard isCurrent(token) else { return nil }
        guard let delay = delays.popFirst() else {
            cancel()
            return nil
        }
        return delay
    }

    mutating func cancel() {
        generation = nil
        delays = []
    }
}

enum MouseAccelerationSupport {
    static let linearScalingKey = "HIDUseLinearScalingMouseAcceleration"
    static let pointerAccelerationTypeKey = "HIDPointerAccelerationType"
    static let pointerAccelerationKey = "HIDPointerAcceleration"
    static let mouseAccelerationKey = "HIDMouseAcceleration"
    static let pointerResolutionKey = "HIDPointerResolution"
    static let trackpadAccelerationType = "HIDTrackpadAcceleration"

    static let accelerationRange = 0.0 ... 40.0
    static let speedRange = 0.0 ... 1.0
    static let defaultAcceleration = 0.6875
    static let defaultResolution = 400.0
    static let pointerResolutionRange = 40.0 ... 1_200.0
    static let defaultSpeed = pointerSpeed(forResolution: defaultResolution)

    static func validatedRegistryID(_ value: UInt64?) -> UInt64? {
        guard let value, value != 0 else { return nil }
        return value
    }

    static func isRestorableKey(_ key: String) -> Bool {
        key == linearScalingKey || key == pointerAccelerationKey
            || key == mouseAccelerationKey || key == pointerResolutionKey
    }

    static func sanitizedAcceleration(_ value: Double) -> Double {
        guard value.isFinite else { return defaultAcceleration }
        return min(max(value, accelerationRange.lowerBound), accelerationRange.upperBound)
    }

    static func sanitizedSpeed(_ value: Double) -> Double {
        guard value.isFinite else { return defaultSpeed }
        return min(max(value, speedRange.lowerBound), speedRange.upperBound)
    }

    /// LinearMouse's useful 0...1 control maps inverse HID resolution from
    /// 1,200 (slow) to 40 (fast). macOS names this value "resolution", but it
    /// is software pointer scaling rather than the mouse sensor's hardware DPI.
    static func pointerResolution(forSpeed speed: Double) -> Double {
        let speed = sanitizedSpeed(speed)
        let minimumReciprocal = 1 / pointerResolutionRange.upperBound
        let maximumReciprocal = 1 / pointerResolutionRange.lowerBound
        return 1 / (minimumReciprocal + speed * (maximumReciprocal - minimumReciprocal))
    }

    static func pointerSpeed(forResolution resolution: Double) -> Double {
        guard resolution.isFinite, resolution > 0 else { return defaultSpeed }
        let minimumReciprocal = 1 / pointerResolutionRange.upperBound
        let maximumReciprocal = 1 / pointerResolutionRange.lowerBound
        return sanitizedSpeed(((1 / resolution) - minimumReciprocal)
            / (maximumReciprocal - minimumReciprocal))
    }

    static func requiredKeys(supportsLinearScaling: Bool,
                             customizesPointer: Bool,
                             accelerationKey: String) -> [String] {
        var keys = supportsLinearScaling ? [linearScalingKey] : []
        if customizesPointer { keys.append(pointerResolutionKey) }
        if customizesPointer || !supportsLinearScaling { keys.append(accelerationKey) }
        return keys
    }

    static func targetValue(for key: String,
                            original: MouseAccelerationStoredValue,
                            preferences: MousePointerPreferences,
                            supportsLinearScaling: Bool) -> MouseAccelerationStoredValue? {
        if key == linearScalingKey {
            return MouseAccelerationStoredValue(rawValue: preferences.disablesAcceleration ? 1 : 0,
                                                isBoolean: original.isBoolean)
        }
        if key == pointerResolutionKey {
            guard !preferences.disablesAcceleration else { return original }
            return fixedPoint(pointerResolution(forSpeed: preferences.speed))
        }
        if preferences.disablesAcceleration && !supportsLinearScaling {
            return fixedPoint(-1)
        }
        return fixedPoint(sanitizedAcceleration(preferences.acceleration))
    }

    private static func fixedPoint(_ value: Double) -> MouseAccelerationStoredValue {
        MouseAccelerationStoredValue(rawValue: Int64((value * 65_536).rounded()),
                                     isBoolean: false)
    }
}
