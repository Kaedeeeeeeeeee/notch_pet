import Foundation
import Supabase
import os.log

/// Best-effort one-way sync of local pet state to Supabase. Every call
/// is fire-and-forget: network failures are logged, never surfaced to
/// the UI, and retried on the next trigger (30s periodic tick or
/// next event). Pull is done only on startup when Apple-linked, so
/// anonymous users never overwrite local state from the cloud.
@MainActor
final class CloudSync {
    static let shared = CloudSync()

    private let log = OSLog(subsystem: "com.notchpet.NotchPet", category: "CloudSync")
    private var client: SupabaseClient { SupabaseClientManager.shared.client }
    private var auth: AuthService { AuthService.shared }

    /// Most recent successful push time — used to rate-limit periodic
    /// writes to ~30s so the app doesn't chatter for every tick.
    private var lastPushAt: Date = .distantPast
    /// Minimum interval between periodic pushes.
    private let pushInterval: TimeInterval = 30

    private init() {}

    // MARK: - Periodic push (called from TimeService)

    /// Rate-limited upsert of the *active* pet row. Cheap and idempotent.
    func pushPetIfDue(_ state: PetState, now: Date = Date()) async {
        guard now.timeIntervalSince(lastPushAt) >= pushInterval else { return }
        lastPushAt = now
        await pushPet(state)
    }

    /// Force-push the active pet state immediately, ignoring the rate
    /// limit. Used for one-shot events like marriage or departure.
    func pushPet(_ state: PetState) async {
        guard let ownerID = auth.currentUserID else { return }
        let payload = CloudPetUpsert(
            id: state.id,
            ownerID: ownerID,
            name: state.name,
            species: state.species.rawValue,
            personality: state.personality?.rawValue,
            generation: state.generation,
            bornAt: state.bornAt,
            departedAt: state.departedAt,
            parents: state.parents,
            feedCount: state.careHistory.feedCount,
            playCount: state.careHistory.playCount,
            weight: state.weight,
            ageActiveSeconds: state.ageActiveSeconds
        )
        do {
            try await client.from("pets")
                .upsert(payload, onConflict: "id")
                .execute()
            AppSettings.shared.lastSyncAt = Date()
        } catch {
            os_log(.error, log: log, "pushPet failed: %@", String(describing: error))
        }
    }

    // MARK: - Event-driven writes

    /// Called from `PetState.marry(with:)` right after a QR scan settles
    /// a partnership. Records the marriage from the local user's side.
    /// Partner pet data is stored as a JSONB snapshot because the
    /// partner is on someone else's Supabase account (or may be entirely
    /// offline).
    func pushMarriage(petState: PetState, partner: PartnerSnapshot) async {
        guard let ownerID = auth.currentUserID else { return }
        let payload = CloudMarriageInsert(
            ownerID: ownerID,
            ownPetID: petState.id,
            partnerPetID: partner.id,
            partnerSnapshot: partner,
            marriedAt: partner.marriedAt
        )
        do {
            try await client.from("marriages")
                .insert(payload)
                .execute()
        } catch {
            os_log(.error, log: log, "pushMarriage failed: %@", String(describing: error))
        }
    }

    /// Called when the pet dies — stamps `departed_at` and captures the
    /// final stats so the memorial book can show them. The row stays in
    /// `pets` forever; a new id is created for the next generation.
    func recordDeparture(of state: PetState) async {
        // Just re-push with departed_at filled; upsert will overwrite
        // the existing row.
        await pushPet(state)
    }

    // MARK: - Pull on start (Apple-linked users only)

    /// Download the most recent live pet for this account. If the local
    /// `PetStateStore`'s pet has an older `ageActiveSeconds`, the cloud
    /// one wins — helps when the user switched Macs.
    func pullOnStart(localState: PetState, store: PetStateStore) async {
        guard auth.isAppleLinked, let ownerID = auth.currentUserID else {
            return
        }
        do {
            // Fetch all pets for this owner ordered newest-first, then
            // filter client-side for "still alive" (departed_at == nil).
            // PostgREST's null filter operator has shifting API surface
            // between SDK versions; a tiny client-side filter is safer.
            let rows: [CloudPet] = try await client.from("pets")
                .select()
                .eq("owner_id", value: ownerID)
                .order("updated_at", ascending: false)
                .execute()
                .value

            guard let cloudPet = rows.first(where: { $0.departedAt == nil })
            else { return }
            // Last-write-wins by age (cloud may have been updated on
            // another device after the local save).
            if cloudPet.ageActiveSeconds > localState.ageActiveSeconds {
                applyCloudPetToLocal(cloudPet, state: localState)
                store.save(localState)
                os_log(.info, log: log, "Pulled fresher pet from cloud: %@",
                       cloudPet.id.uuidString)
            }
        } catch {
            os_log(.error, log: log, "pullOnStart failed: %@", String(describing: error))
        }
    }

    /// Overwrite mutable fields of `state` with the cloud snapshot.
    /// Kept conservative — we don't clobber transient gameplay fields
    /// (position, behavior) with cloud data.
    private func applyCloudPetToLocal(_ cloud: CloudPet, state: PetState) {
        state.id = cloud.id
        state.name = cloud.name
        if let species = Species(rawValue: cloud.species) {
            state.species = species
        }
        state.personality = cloud.personality.flatMap(PersonalityTrait.init(rawValue:))
        state.generation = cloud.generation
        state.bornAt = cloud.bornAt
        state.departedAt = cloud.departedAt
        state.parents = cloud.parents
        state.weight = cloud.weight
        state.ageActiveSeconds = cloud.ageActiveSeconds
        state.careHistory = CareHistory(
            feedCount: cloud.feedCount,
            playCount: cloud.playCount,
            restCount: 0
        )
    }

    // MARK: - Memorial book query

    /// All of this user's departed pets, newest first. Consumed by the
    /// memorial book UI. Returns empty on anon users / network failure.
    func fetchDepartedPets() async -> [CloudPet] {
        guard let ownerID = auth.currentUserID else { return [] }
        do {
            let rows: [CloudPet] = try await client.from("pets")
                .select()
                .eq("owner_id", value: ownerID)
                .order("departed_at", ascending: false)
                .execute()
                .value
            return rows.filter { $0.departedAt != nil }
        } catch {
            os_log(.error, log: log, "fetchDepartedPets failed: %@",
                   String(describing: error))
            return []
        }
    }
}
