// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import Foundation
import HIDEventSystem

/// Applies macOS's per-device pointer speed and acceleration properties to
/// ordinary mouse devices. Trackpads are deliberately excluded.
final class MouseAccelerationService {
    static let shared = MouseAccelerationService()

    private let defaults = UserDefaults.standard
    private var client: IOHIDEventSystemClient?
    private var hidManager: IOHIDManager?
    private var reapplySchedule = MouseAccelerationReapplySchedule()
    private var reapplyWork: DispatchWorkItem?
    private var recoveryGuard: MouseAccelerationGuard.Handle?
    private var lifecycleObservers: [NSObjectProtocol] = []
    private var sessionIsActive = false
    private var systemIsAwake = true

    private init() {}

    static func recoverPendingAtLaunch() {
        guard MouseAccelerationRecovery.hasPendingEntries() else { return }
        _ = shared.pauseAndRestore()
    }

    func syncWithPreferences() {
        guard featureWanted else {
            stop()
            return
        }
        installLifecycleObservers()
        startIfAllowed()
    }

    func revertToSystemDefaults() {
        defaults.set(false, forKey: DefaultsKey.mousePointerCustomized)
        defaults.set(false, forKey: DefaultsKey.mouseAccelerationDisabled)
        stop()
    }

    /// Restores every value owned by this feature before its process goes away.
    @discardableResult
    func stop() -> Bool {
        removeLifecycleObservers()
        return pauseAndRestore()
    }

    private var featureWanted: Bool {
        AppFeature.mouseAcceleration.isAvailable
            && (defaults.bool(forKey: DefaultsKey.mouseAccelerationDisabled)
                || defaults.bool(forKey: DefaultsKey.mousePointerCustomized))
    }

    private var preferences: MousePointerPreferences {
        MousePointerPreferences(
            disablesAcceleration: defaults.bool(forKey: DefaultsKey.mouseAccelerationDisabled),
            acceleration: MouseAccelerationSupport.sanitizedAcceleration(
                defaults.double(forKey: DefaultsKey.mousePointerAcceleration)),
            speed: MouseAccelerationSupport.sanitizedSpeed(
                defaults.double(forKey: DefaultsKey.mousePointerSpeed))
        )
    }

    private func startIfAllowed() {
        guard featureWanted, sessionIsActive, systemIsAwake else {
            pauseAndRestore()
            return
        }
        start()
    }

    private func start() {
        if client != nil {
            applyPointerPreferences()
            return
        }
        guard let client = IOHIDEventSystemClientCreate(kCFAllocatorDefault) else { return }
        _ = MouseAccelerationRecovery.restorePending(using: client)
        self.client = client
        startDeviceObservation()
        applyPointerPreferences()
        scheduleDeviceReapplication()
    }

    @discardableResult
    private func pauseAndRestore() -> Bool {
        stopDeviceObservation()
        if let client {
            _ = MouseAccelerationRecovery.restorePending(using: client)
        } else if MouseAccelerationRecovery.hasPendingEntries() {
            _ = MouseAccelerationRecovery.restorePending()
        }
        client = nil
        if let recoveryGuard {
            _ = recoveryGuard.stop()
            self.recoveryGuard = nil
        }
        let hasPendingRecovery = MouseAccelerationRecovery.hasPendingEntries()
        if hasPendingRecovery {
            recoveryGuard = MouseAccelerationGuard.start()
        }
        return !hasPendingRecovery
    }

    private func applyPointerPreferences() {
        guard let client,
              let services = MouseAccelerationRecovery.services(using: client),
              var journal = MouseAccelerationRecovery.journalForMutation() else {
            return
        }
        let preferences = preferences
        let customizesPointer = defaults.bool(forKey: DefaultsKey.mousePointerCustomized)

        for service in services where MouseAccelerationRecovery.isMouse(service) {
            guard let id = MouseAccelerationRecovery.registryID(of: service),
                  let identity = MouseAccelerationRecovery.identity(of: service) else { continue }

            let supportsLinearScaling = MouseAccelerationRecovery.storedValue(
                for: MouseAccelerationSupport.linearScalingKey, on: service) != nil
            let accelerationKey = MouseAccelerationRecovery.accelerationKey(for: service)
            let keys = MouseAccelerationSupport.requiredKeys(
                supportsLinearScaling: supportsLinearScaling,
                customizesPointer: customizesPointer,
                accelerationKey: accelerationKey
            )

            for staleEntry in journal.staleEntries(registryID: id,
                                                    identity: identity,
                                                    preserving: keys) {
                guard MouseAccelerationRecovery.restore(staleEntry, on: service),
                      MouseAccelerationRecovery.remove(registryID: id,
                                                       key: staleEntry.key,
                                                       from: &journal) else {
                    continue
                }
            }

            for key in keys {
                let entry: MouseAccelerationRecoveryEntry
                if let existing = journal.entry(registryID: id, identity: identity, key: key) {
                    entry = existing
                } else {
                    let unresolvedIdentity = identity.canMatchAcrossRegistryIDs
                        && journal.entries.contains {
                            $0.key == key && $0.identity.matches(identity)
                        }
                    guard !journal.entries.contains(where: {
                              $0.registryID == id && $0.key == key
                          }),
                          !unresolvedIdentity,
                          ensureRecoveryGuard(),
                          let captured = MouseAccelerationRecovery.captureEntry(
                              for: service,
                              registryID: id,
                              identity: identity,
                              key: key
                          ),
                          MouseAccelerationRecovery.record(captured, in: &journal) else {
                        continue
                    }
                    entry = captured
                }

                guard ensureRecoveryGuard() else {
                    pauseAndRestore()
                    return
                }
                guard MouseAccelerationRecovery.applyTarget(
                    for: entry,
                    preferences: preferences,
                    supportsLinearScaling: supportsLinearScaling,
                    to: service
                ) else {
                    if MouseAccelerationRecovery.restore(entry, on: service) {
                        _ = MouseAccelerationRecovery.remove(registryID: id,
                                                             key: key,
                                                             from: &journal)
                    }
                    continue
                }
            }
        }

        if journal.entries.isEmpty, let recoveryGuard {
            _ = recoveryGuard.stop()
            self.recoveryGuard = nil
        }
    }

    private func ensureRecoveryGuard() -> Bool {
        if recoveryGuard != nil { return true }
        recoveryGuard = MouseAccelerationGuard.start()
        return recoveryGuard != nil
    }

    // MARK: - Device lifecycle

    private static let deviceChanged: IOHIDDeviceCallback = { context, _, _, _ in
        guard let context else { return }
        let service = Unmanaged<MouseAccelerationService>.fromOpaque(context).takeUnretainedValue()
        service.scheduleDeviceReapplication()
    }

    private func scheduleDeviceReapplication() {
        guard client != nil, featureWanted, sessionIsActive, systemIsAwake else { return }
        reapplyWork?.cancel()
        scheduleDeviceReapplication(for: reapplySchedule.restart())
    }

    private func scheduleDeviceReapplication(for token: UUID) {
        guard let delay = reapplySchedule.nextDelay(for: token) else { return }
        let work = DispatchWorkItem { [weak self] in
            guard let self, self.reapplySchedule.isCurrent(token) else { return }
            self.reapplyWork = nil
            guard self.client != nil, self.featureWanted,
                  self.sessionIsActive, self.systemIsAwake else { return }
            // Physical-device callbacks can precede the event-system service, and
            // its initial settings can arrive later still. Read a fresh service list.
            guard let client = IOHIDEventSystemClientCreate(kCFAllocatorDefault) else { return }
            self.client = client
            _ = MouseAccelerationRecovery.restorePending(using: client,
                                                          preservingConnectedEntries: true)
            self.applyPointerPreferences()
            self.scheduleDeviceReapplication(for: token)
        }
        reapplyWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    private func startDeviceObservation() {
        guard hidManager == nil else { return }
        let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        let matches: [[String: Any]] = [kHIDUsage_GD_Mouse, kHIDUsage_GD_Pointer].map { usage in
            [
                kIOHIDDeviceUsagePageKey as String: kHIDPage_GenericDesktop,
                kIOHIDDeviceUsageKey as String: usage,
            ]
        }
        IOHIDManagerSetDeviceMatchingMultiple(manager, matches as CFArray)
        let context = Unmanaged.passUnretained(self).toOpaque()
        IOHIDManagerRegisterDeviceMatchingCallback(manager, Self.deviceChanged, context)
        IOHIDManagerRegisterDeviceRemovalCallback(manager, Self.deviceChanged, context)
        IOHIDManagerScheduleWithRunLoop(manager,
                                        CFRunLoopGetMain(),
                                        CFRunLoopMode.commonModes.rawValue)
        guard IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone)) == kIOReturnSuccess else {
            IOHIDManagerUnscheduleFromRunLoop(manager,
                                              CFRunLoopGetMain(),
                                              CFRunLoopMode.commonModes.rawValue)
            return
        }
        hidManager = manager
    }

    private func stopDeviceObservation() {
        reapplyWork?.cancel()
        reapplyWork = nil
        reapplySchedule.cancel()
        guard let manager = hidManager else { return }
        IOHIDManagerUnscheduleFromRunLoop(manager,
                                          CFRunLoopGetMain(),
                                          CFRunLoopMode.commonModes.rawValue)
        IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        hidManager = nil
    }

    // MARK: - Session and sleep lifecycle

    private func installLifecycleObservers() {
        guard lifecycleObservers.isEmpty else { return }
        let center = NSWorkspace.shared.notificationCenter
        lifecycleObservers = [
            center.addObserver(forName: NSWorkspace.sessionDidResignActiveNotification,
                               object: nil, queue: .main) { [weak self] _ in
                self?.sessionIsActive = false
                self?.pauseAndRestore()
            },
            center.addObserver(forName: NSWorkspace.sessionDidBecomeActiveNotification,
                               object: nil, queue: .main) { [weak self] _ in
                self?.sessionIsActive = true
                self?.startIfAllowed()
            },
            center.addObserver(forName: NSWorkspace.willSleepNotification,
                               object: nil, queue: .main) { [weak self] _ in
                self?.systemIsAwake = false
                self?.pauseAndRestore()
            },
            center.addObserver(forName: NSWorkspace.didWakeNotification,
                               object: nil, queue: .main) { [weak self] _ in
                self?.systemIsAwake = true
                self?.startIfAllowed()
            },
        ]
        sessionIsActive = Self.currentSessionIsActive()
    }

    private func removeLifecycleObservers() {
        let center = NSWorkspace.shared.notificationCenter
        for observer in lifecycleObservers { center.removeObserver(observer) }
        lifecycleObservers = []
    }

    private static func currentSessionIsActive() -> Bool {
        SessionActivitySupport.isOnConsole(
            CGSessionCopyCurrentDictionary() as? [String: Any])
    }
}
