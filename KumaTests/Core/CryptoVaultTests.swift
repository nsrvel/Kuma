import XCTest
@testable import Kuma

final class CryptoVaultTests: XCTestCase {

    func testEncryptAndDecryptRoundTrip() async throws {
        let vault = CryptoVault.shared
        let originalText = "apiVersion: v1\nkind: Config\nclusters: []"

        let encrypted = try await vault.encrypt(plainText: originalText)
        XCTAssertFalse(encrypted.isEmpty)
        XCTAssertNotEqual(encrypted, originalText)
        XCTAssertTrue(encrypted.contains(":")) // formatted as nonce:tag:ciphertext

        let decrypted = try await vault.decrypt(cipherText: encrypted)
        XCTAssertEqual(decrypted, originalText)
    }

    func testCorruptedPayloadThrows() async {
        let vault = CryptoVault.shared
        let badPayload = "d3Jvbmc=:dGFn:Y2lwaGVy"

        do {
            _ = try await vault.decrypt(cipherText: badPayload)
            XCTFail("Should throw on corrupted payload")
        } catch {
            XCTAssertTrue(error is CryptoVaultError)
        }
    }

    func testInvalidPayloadFormatThrows() async {
        let vault = CryptoVault.shared
        let malformed = "not-enough-colons"

        do {
            _ = try await vault.decrypt(cipherText: malformed)
            XCTFail("Should throw on malformed format")
        } catch {
            XCTAssertTrue(error is CryptoVaultError)
        }
    }
}
