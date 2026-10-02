import AppKit
import Foundation
import os.log

/// Drives PetState decay on a 1Hz timer. Tracks whether the computer is
/// "active" — i.e. awake, not sleeping, not locked, not user-switched — and
/// skips decay while paused. Also updates `petState.isAsleep` against the
/// configured nightly sleep schedule.
///
/// Ambient visual behavior runs on a separate short-interval timer so walking
/// advances in small visible steps instead of jumping once per lifecycle tick.
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
    private var behaviorTimer: Timer?
    private var observers: [NSObjectProtocol] = []
    /// In-flight CloudSync push. Capped at one: when a new tick fires,
    /// we cancel the previous push before starting a new one. Prevents
    /// unbounded task accumulation if the network stalls — otherwise
    /// long idle + flaky network produces a backlog of suspended tasks
    /// that all resume on the main actor when connectivity returns.
    private var cloudPushTask: Task<Void, Never>?

    private var isActive: Bool = true
    private var lastTickAt: Date = Date()
    private var lastBehaviorTickAt: Date = Date()
    private var lastPersistedAt: Date = .distantPast

    private let persistInterval: TimeInterval = 30

    private let log = OSLog(subsystem: "com.notchpet.NotchPet", category: "TimeService")
    /// If more than this many seconds elapse between ticks, we suspect
    /// the run loop was stalled (main-thread blocking) or a wake
    /// notification never arrived. Log a warning and self-heal by
    /// re-asserting isActive + resetting lastTickAt.
    private static let tickGapWatchdog: TimeInterval = 5.0

    init(petState: PetState, store: PetStateStore, schedule: NightSleepSchedule = NightSleepSchedule()) {
        self.petState = petState
        self.store = store
        self.schedule = schedule
    }

    deinit {
        observers.forEach { NSWorkspace.shared.notificationCenter.removeObserver($0) }
        cloudPushTask?.cancel()
    }

    func start() {
        lastTickAt = Date()
        installTimer()
        installWorkspaceObservers()
        // Establish initial asleep flag so UI reflects night immediately.
        petState.isAsleep = petState.observesNightSleep &&
            schedule.isNightTime(at: Date(), personality: petState.personality)
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        behaviorTimer?.invalidate()
        behaviorTimer = nil
        observers.forEach { NSWorkspace.shared.notificationCenter.removeObserver($0) }
        observers.removeAll()
        cloudPushTask?.cancel()
        cloudPushTask = nil
    }

    /// Persists the current state immediately — called on app termination.
    /// Uses the blocking `flushSync` variant so the write lands before
    /// the process exits. Safe here because the app is tearing down
    /// anyway; blocking main briefly is the correct trade-off.
    func flush() {
        store.flushSync(petState)
    }

    // MARK: - Tick

    private func installTimer() {
        timer?.invalidate()
        let t = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        RunLoop.main.add(t, forMode: .common)
        self.timer = t

        behaviorTimer?.invalidate()
        lastBehaviorTickAt = Date()
        let behavior = Timer(timeInterval: 1.0 / 15.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.behaviorTick() }
        }
        RunLoop.main.add(behavior, forMode: .common)
        self.behaviorTimer = behavior
    }

    private func behaviorTick() {
        let now = Date()
        let delta = now.timeIntervalSince(lastBehaviorTickAt)
        lastBehaviorTickAt = now

        guard isActive, !petState.isAsleep else { return }
        behaviorEngine.tick(petState: petState, dt: min(delta, 0.2))
    }

    private func tick() {
        let now = Date()
        let delta = now.timeIntervalSince(lastTickAt)
        lastTickAt = now

        // Watchdog: tick should fire once per second. If we observe a
        // > 5s gap while nothing was supposed to pause us, the run loop
        // was stalled (blocked main thread) or a sleep/wake notification
        // pair got mismatched. Log and self-heal by re-asserting isActive.
        if delta > Self.tickGapWatchdog {
            os_log(.error, log: log,
                   "tick gap: %{public}.2fs (isActive=%{public}@ isAsleep=%{public}@ stage=%{public}@). Re-asserting isActive.",
                   delta,
                   String(isActive),
                   String(petState.isAsleep),
                   petState.stage.rawValue)
            // Self-heal: if we missed a resume notification, force the
            // pet back to live state. If a legitimate willSleep is still
            // ahead, it'll pause us again on the next notification.
            if !isActive { isActive = true }
        }

        // Nightly sleep toggle — runs even while inactive so UI stays accurate
        // after the machine wakes up during night hours. Eggs + freshly
        // hatched children (grace window) opt out via `observesNightSleep`.
        let shouldBeAsleep = petState.observesNightSleep &&
            schedule.isNightTime(at: now, personality: petState.personality)
        if shouldBeAsleep != petState.isAsleep {
            petState.isAsleep = shouldBeAsleep
        }

        if isActive && !petState.isAsleep {
            petState.applyDecay(activeSeconds: delta)
            petState.runCareTick(now: now, activeSeconds: delta)
            petState.advanceLifecycle(activeSeconds: delta)
            advanceMarriage(now: now)
            petState.lastTickAt = now
        }

        // Handle the departed → reborn flow. After the grace window the
        // pet waits for the user to confirm before a new egg drops.
        if petState.stage == .departed {
            // Self-heal: a persisted save could be in an inconsistent
            // state where stage==.departed but departedAt was never
            // recorded (observed in the wild — cause unclear, but the
            // symptom is the memorial card never appears because the
            // grace-period check below can't evaluate elapsed time).
            // Backfill with `now - departGraceSeconds` so the reborn
            // flow fires on the next line instead of waiting forever.
            if petState.departedAt == nil {
                os_log(.error, log: log,
                       "departedAt missing while stage=.departed — backfilling now to unstick reborn flow")
                petState.departedAt = now.addingTimeInterval(-LifecycleClock.departGraceSeconds)
            }
            if let departedAt = petState.departedAt {
                let elapsed = now.timeIntervalSince(departedAt)
                if elapsed >= LifecycleClock.departGraceSeconds && !petState.awaitingRebornConfirm {
                    petState.awaitingRebornConfirm = true
                    store.save(petState)
                    lastPersistedAt = now
                }
            }
        }

        if now.timeIntervalSince(lastPersistedAt) >= persistInterval {
            store.save(petState)
            lastPersistedAt = now
            // Piggyback a best-effort cloud push on the same interval.
            // Cancel any in-flight push first so a stalled network call
            // never accumulates a queue of sync tasks.
            cloudPushTask?.cancel()
            let snapshot = petState
            cloudPushTask = Task { @MainActor in
                await CloudSync.shared.pushPetIfDue(snapshot, now: now)
            }
        }
    }

    // MARK: - Marriage state machine

    /// Walks the marriage → egg → baby → family-farewell timeline. Called
    /// on every active tick after regular lifecycle advancement so newly
    /// accumulated `ageActiveSeconds` is visible here. Only fires for
    /// pets in adult/elder with a live partner; departed pets short-
    /// circuit via `triggerDeath` in `runCareTick`.
    private func advanceMarriage(now: Date) {
        // 1) Marriage → egg (marriedAt + 1 active-day, gated by an adult/
        //    elder partner-alive parent).
        if let marriedAt = petState.marriedAt,
           petState.partner != nil,
           petState.pendingEgg == nil,
           petState.pendingBaby == nil,
           now >= marriedAt.addingTimeInterval(LifecycleClock.activeSecondsPerDay),
           petState.stage == .adult || petState.stage == .elder {
            petState.layEgg()
        }

        // 2) Egg → baby (hatchDueAt reached).
        if let egg = petState.pendingEgg,
           petState.pendingBaby == nil,
           now >= egg.hatchDueAt {
            petState.hatchBaby()
        }

        // 3) Baby grown → family farewell. Parents exit when either 10
        //    active-days old OR 1 active-day after hatching, whichever
        //    is LATER. Guarantees at least one day of family time.
        if petState.pendingBaby != nil,
           let hatchAge = petState.babyHatchedAtAge,
           petState.stage != .departed {
            let oneDay = LifecycleClock.activeSecondsPerDay
            let tenDays = 10.0 * oneDay
            let farewellAge = max(tenDays, hatchAge + oneDay)
            if petState.ageActiveSeconds >= farewellAge {
                petState.triggerFamilyFarewell()
            }
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
        if isActive {
            os_log(.info, log: log, "pause → isActive=false")
        }
        isActive = false
        // Reset lastTickAt on resume — otherwise we'd decay for the whole
        // sleep interval despite pausing. We save on pause so a crash during
        // sleep still leaves a consistent snapshot.
        store.save(petState)
    }

    private func resume() {
        if !isActive {
            os_log(.info, log: log, "resume → isActive=true")
        }
        isActive = true
        lastTickAt = Date()
    }
}
