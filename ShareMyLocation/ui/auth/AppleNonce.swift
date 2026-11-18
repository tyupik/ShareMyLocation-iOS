import CryptoKit
import Foundation

/// Генератор nonce для Sign in with Apple: случайный raw передаётся в Firebase-креденшел,
/// его SHA256-hex уходит в системный запрос (Apple проверяет соответствие — анти-replay).
enum AppleNonce {
    /// - Returns: кортеж `raw` — для OAuthProvider-креденшела в data-слое,
    ///   `hashed` — для ASAuthorizationAppleIDRequest.nonce.
    static func make() -> (raw: String, hashed: String) {
        let raw = UUID().uuidString
        let hashed = SHA256.hash(data: Data(raw.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
        return (raw, hashed)
    }
}
