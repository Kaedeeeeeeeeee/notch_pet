import AppKit
import Foundation

/// Drives PetState decay on a 1Hz timer. Tracks whether the computer is
/// "active" — i.e. awake, not sleeping, not locked, not user-switched — and
/// skips decay while paused. Also updates `petState.isAsleep` against the
/// configured nightly sleep schedule.
///
/// Persistence is piggybacked onto the same tick: every `persistInterval`
/// seconds the current state is snapshotted to disk. Actions taken via the
/// UI (feed/play/rest) are also persisted by the caller on next tick.
@MainActor
final class TimeService {
    private let petState: PetState
    private let store: PetStateStore
    private var schedule: NightSleepSchedule
    private let behaviorEngine = PetBehaviorEngine()
    private var timer: Timer?
    private var observers: [NSObjectProtocol] = []

    private var isActive: Bool = true
    private var lastTickAt: Date = Date()
    private var lastPersistedAt: Date = .distantPast

    private let persistInterval: TimeInterval = 30

    init(petState: PetState, store: PetStateStore, schedule: NightSleepSchedule = NightSleepSchedule()) {
        self.petState = petState
        self.store = store
        self.schedule = schedule
    }

    deinit {
        observers.forEach { NSWorkspace.shared.notificationCenter.removeObserver($0) }
    }

    func start() {
        lastTickAt = Date()
        installTimer()
        installWorkspaceObservers()
        // Establish initial asleep flag so UI reflects night immediately.
        petState.isAsleep = schedule.isNightTime(at: Date(), personality: petState.personality)
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        observers.forEach { NSWorkspace.shared.notificationCenter.removeObserver($0) }
        observers.removeAll()
    }

    /// Persists the current state immediately — called on app termination.
    func flush() {
        store.save(petState)
    }

    // MARK: - Tick

    private func installTimer() {
        timer?.invalidate()
        let t = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        RunLoop.main.add(t, forMode: .common)
        self.timer = t
    }

    private func tick() {
        let now = Date()
        let delta = now.timeIntervalSince(lastTickAt)
        lastTickAt = now

        // Nightly sleep toggle — runs even while inactive so UI stays accurate
        // after the machine wakes up during night hours.
        let shouldBeAsleep = schedule.isNightTime(at: now, personality: petState.personality)
        if shouldBeAsleep != petState.isAsleep {
            petState.isAsleep = shouldBeAsleep
        }

        if isActive && !petState.isAsleep {
            petState.applyDecay(activeSeconds: delta)
            petState.runCareTick(now: now, activeSeconds: delta)
            petState.advanceLifecycle(activeSeconds: delta)
            behaviorEngine.tick(petState: petState, dt: delta)
            petState.lastTickAt = now
        }

        // Handle the departed → reborn flow. After the grace window the
        // pet waits for the user to confirm before a new egg drops.
        if petState.stage == .departed, let departedAt = petState.departedAt {
            let elapsed = now.timeIntervalSince(departedAt)
            if elapsed >= LifecycleClock.departGraceSeconds && !petState.awaitingRebornConfirm {
                petState.awaitingRebornConfirm = true
                store.save(petState)
                lastPersistedAt = now
            }
        }

        if now.timeIntervalSince(lastPersistedAt) >= persistInterval {
            store.save(petState)
            lastPersistedAt = now
        }
    }

    // MARK: - Workspace observers

    private func installWorkspaceObservers() {
        let nc = NSWorkspace.shared.notificationCenter
        let pause: @Sendable (Notification) -> Void = { [weak self] _ in
            Task { @MainActor in self?.pause() }
        }
        let resume: @Sendable (Notification) -> Void = { [weak self] _ in
            Task { @MainActor in self?.resume() }
        }
        for name in [
            NSWorkspace.willSleepNotification,
            NSWorkspace.screensDidSleepNotification,
            NSWorkspace.sessionDidResignActiveNotification,
        ] {
            observers.append(nc.addObserver(forName: name, object: nil, queue: .main, using: pause))
        }
        for name in [
            NSWorkspace.didWakeNotification,
            NSWorkspace.screensDidWakeNotification,
            NSWorkspace.sessionDidBecomeActiveNotification,
        ] {
            observers.append(nc.addObserver(forName: name, object: nil, queue: .main, using: resume))
        }
    }

    private func pause() {
        isActive = false
        // Reset lastTickAt on resume — otherwise we'd decay for the whole
        // sleep interval despite pausing. We save on pause so a crash during
        // sleep still leaves a consistent snapshot.
        store.save(petState)
    }

    private func resume() {
        isActive = true
        lastTickAt = Date()
    }
}
