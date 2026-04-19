import AuthenticationServices
import CryptoKit
import Foundation
import Supabase
import os.log

/// Owns the app's Supabase auth lifecycle:
///   - `ensureAuthed()` is called on every launch; it signs the user
///     in anonymously if no session exists.
///   - `signInWithApple()` upgrades the current anonymous session to
///     an Apple-linked one. The underlying `auth.users` row keeps its
///     UUID, so all `profiles` / `pets` / `marriages` rows migrate
///     automatically.
///   - `signOut()` clears the local session. Next launch falls back to
///     a brand-new anonymous user.
@MainActor
final class AuthService: NSObject {
    static let shared = AuthService()

    private let log = OSLog(subsystem: "com.notchpet.NotchPet", category: "Auth")
    private var client: SupabaseClient { SupabaseClientManager.shared.client }

    // Apple Sign-in delegate state (needs to survive the async flow).
    private var appleNonceRaw: String?
    private var appleContinuation: CheckedContinuation<String, Error>?

    private override init() { super.init() }

    // MARK: - Session

    /// Current user's id if logged in, nil otherwise.
    var currentUserID: UUID? {
        client.auth.currentUser?.id
    }

    /// True once an anonymous or Apple-linked session is established.
    var isAuthed: Bool {
        client.auth.currentSession != nil
    }

    /// True if the current session has an Apple identity attached.
    var isAppleLinked: Bool {
        guard let user = client.auth.currentUser else { return false }
        return user.identities?.contains(where: { $0.provider == "apple" }) ?? false
    }

    /// Anonymous sign-in on first launch; silent no-op if a session
    /// already exists (persisted by the SDK in the keychain).
    func ensureAuthed() async {
        if client.auth.currentSession != nil {
            AppSettings.shared.isAppleLinked = isAppleLinked
            AppSettings.shared.userEmail = client.auth.currentUser?.email
            return
        }
        do {
            _ = try await client.auth.signInAnonymously()
            AppSettings.shared.isAppleLinked = false
            os_log(.info, log: log, "Anonymous session established")
        } catch {
            os_log(.error, log: log, "Anonymous sign-in failed: %@",
                   String(describing: error))
        }
    }

    // MARK: - Sign in with Apple

    /// Runs the native Apple flow and upgrades the current Supabase
    /// user to one linked to the Apple identity. The anonymous user_id
    /// is preserved, so existing rows stay visible.
    func signInWithApple() async throws {
        let idToken = try await requestAppleIDToken()
        guard let rawNonce = appleNonceRaw else {
            throw AuthError.missingNonce
        }
        appleNonceRaw = nil

        try await client.auth.signInWithIdToken(
            credentials: .init(provider: .apple, idToken: idToken, nonce: rawNonce)
        )
        AppSettings.shared.isAppleLinked = true
        AppSettings.shared.userEmail = client.auth.currentUser?.email
        os_log(.info, log: log, "Apple sign-in succeeded for user %{public}@",
               client.auth.currentUser?.id.uuidString ?? "?")
    }

    /// Clears the session. A new anonymous user will be created on
    /// the next `ensureAuthed()` call (i.e. next app launch).
    func signOut() async {
        try? await client.auth.signOut()
        AppSettings.shared.isAppleLinked = false
        AppSettings.shared.userEmail = nil
    }

    // MARK: - Apple flow internals

    private func requestAppleIDToken() async throws -> String {
        let rawNonce = Self.randomNonce()
        appleNonceRaw = rawNonce

        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.email]
        request.nonce = Self.sha256(rawNonce)

        return try await withCheckedThrowingContinuation { continuation in
            self.appleContinuation = continuation
            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.presentationContextProvider = self
            controller.performRequests()
        }
    }

    private static func randomNonce(length: Int = 32) -> String {
        precondition(length > 0)
        let charset: [Character] =
            Array("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._")
        var remaining = length
        var result = ""
        while remaining > 0 {
            var bytes = [UInt8](repeating: 0, count: 16)
            let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
            precondition(status == errSecSuccess)
            for byte in bytes where remaining > 0 {
                if byte < charset.count {
                    result.append(charset[Int(byte) % charset.count])
                    remaining -= 1
                }
            }
        }
        return result
    }

    private static func sha256(_ input: String) -> String {
        let data = Data(input.utf8)
        let hash = SHA256.hash(data: data)
        return hash.map { String(format: "%02x", $0) }.joined()
    }

    // MARK: - Errors

    enum AuthError: LocalizedError {
        case missingIDToken
        case missingNonce
        case cancelled

        var errorDescription: String? {
            switch self {
            case .missingIDToken: return "Apple did not return an ID token."
            case .missingNonce:   return "Nonce lost during Apple flow."
            case .cancelled:      return "Sign-in cancelled."
            }
        }
    }
}

// MARK: - ASAuthorizationController delegates

extension AuthService: ASAuthorizationControllerDelegate {
    nonisolated func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        Task { @MainActor in
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let tokenData = credential.identityToken,
                  let tokenString = String(data: tokenData, encoding: .utf8) else {
                self.appleContinuation?.resume(throwing: AuthError.missingIDToken)
                self.appleContinuation = nil
                return
            }
            self.appleContinuation?.resume(returning: tokenString)
            self.appleContinuation = nil
        }
    }

    nonisolated func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: Error
    ) {
        Task { @MainActor in
            // Cancellation is a non-error from the user's perspective.
            if (error as NSError).code == ASAuthorizationError.canceled.rawValue {
                self.appleContinuation?.resume(throwing: AuthError.cancelled)
            } else {
                self.appleContinuation?.resume(throwing: error)
            }
            self.appleContinuation = nil
        }
    }
}

extension AuthService: ASAuthorizationControllerPresentationContextProviding {
    nonisolated func presentationAnchor(
        for controller: ASAuthorizationController
    ) -> ASPresentationAnchor {
        // The non-activating notch panel isn't a key window; hand Apple
        // the main screen's key window if any, otherwise a new one.
        MainActor.assumeIsolated {
            NSApplication.shared.keyWindow ?? NSApplication.shared.windows.first ?? NSWindow()
        }
    }
}
