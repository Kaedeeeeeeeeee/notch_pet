import Foundation

/// Serialized marriage invitation encoded into a QR code. Self-contained
/// so the scanning side can commit a marriage without any network round
/// trip — v1 is fully offline. `v` is the schema version in case we add
/// fields later (always include it as the first key).
struct MarriagePayload: Codable, Equatable {
    let v: Int
    let id: UUID
    let species: Species
    let personality: PersonalityTrait
    let name: String
    let issuedAt: Date

    static let currentVersion: Int = 1

    /// URL-safe identifier prefix so we could later embed as a
    /// `notchpet://` scheme if we ever support file-based invites.
    private static let prefix = "notchpet:marry:v1:"

    init(id: UUID,
         species: Species,
         personality: PersonalityTrait,
         name: String,
         issuedAt: Date = Date()) {
        self.v = Self.currentVersion
        self.id = id
        self.species = species
        self.personality = personality
        self.name = name
        self.issuedAt = issuedAt
    }

    /// Build a payload from the current pet. Requires an adult pet with
    /// a derived personality; returns nil otherwise.
    @MainActor
    static func from(petState: PetState) -> MarriagePayload? {
        guard petState.stage == .adult,
              let personality = petState.personality else { return nil }
        return MarriagePayload(
            id: petState.id,
            species: petState.species,
            personality: personality,
            name: petState.name
        )
    }

    // MARK: - Encoding (payload → QR string)

    /// Encode as `notchpet:marry:v1:<base64url-json>` — the string that
    /// goes into the QR code. Kept compact so low-resolution cameras can
    /// still read it reliably.
    func encode() -> String {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(self) else { return "" }
        return Self.prefix + data.base64URLEncodedString()
    }

    // MARK: - Decoding (QR string → payload)

    /// Parse a scanned string back into a payload. Returns nil if the
    /// string isn't a valid NotchPet marriage invitation.
    static func decode(from string: String) -> MarriagePayload? {
        guard string.hasPrefix(prefix) else { return nil }
        let body = String(string.dropFirst(prefix.count))
        guard let data = Data(base64URLEncoded: body) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(MarriagePayload.self, from: data)
    }

    /// Build a `PartnerSnapshot` ready to hand to `PetState.marry(with:)`.
    func toPartnerSnapshot() -> PartnerSnapshot {
        PartnerSnapshot(
            id: id,
            species: species,
            personality: personality,
            name: name,
            marriedAt: Date()
        )
    }
}

// MARK: - Base64 URL helpers

private extension Data {
    func base64URLEncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    init?(base64URLEncoded string: String) {
        var s = string
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        // Re-pad to a multiple of 4.
        let rem = s.count % 4
        if rem > 0 { s.append(String(repeating: "=", count: 4 - rem)) }
        guard let data = Data(base64Encoded: s) else { return nil }
        self = data
    }
}
