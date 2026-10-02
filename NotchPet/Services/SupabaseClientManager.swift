import Foundation
import Supabase

/// Process-wide `SupabaseClient` holder. The client is thread-safe and
/// inexpensive to own; we keep a single instance so auth state is
/// shared across the app. Lazy-initialised so the network library
/// doesn't spin up until something actually touches it.
@MainActor
final class SupabaseClientManager {
    static let shared = SupabaseClientManager()

    private(set) lazy var client: SupabaseClient = {
        SupabaseClient(
            supabaseURL: SupabaseConfig.projectURL,
            supabaseKey: SupabaseConfig.anonKey,
            // Opt into the next-major behavior so the SDK stops logging
            // the "Initial session emitted after attempting to refresh…"
            // deprecation warning at launch. Safe for us because we don't
            // subscribe to auth state events — `ensureAuthed()` only
            // reads `currentSession` directly, and the token refresh
            // still happens automatically in the background.
            options: SupabaseClientOptions(
                auth: .init(emitLocalSessionAsInitialSession: true)
            )
        )
    }()

    private init() {}
}
