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
            supabaseKey: SupabaseConfig.anonKey
        )
    }()

    private init() {}
}
