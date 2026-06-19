import Foundation
import Testing
@testable import LUMA

/// In-memory KeychainStoring for deterministic, CI-safe tests. Must be a
/// class + lock (NOT an actor): AccountModel.init reads the keychain
/// synchronously, and an actor would force those reads async. @unchecked
/// Sendable is required because the dictionary is mutable; the NSLock makes
/// the concurrent access safe.
final class InMemoryKeychain: KeychainStoring, @unchecked Sendable {
    private let lock = NSLock()
    private var store: [String: String] = [:]

    @discardableResult
    func write(key: String, value: String) -> Bool {
        lock.lock(); defer { lock.unlock() }
        store[key] = value
        return true
    }

    func read(key: String) -> String? {
        lock.lock(); defer { lock.unlock() }
        return store[key]
    }

    func delete(key: String) {
        lock.lock(); defer { lock.unlock() }
        store[key] = nil
    }
}

@Suite("Account deletion purges credentials")
@MainActor
struct AccountPurgeTests {
    // deleteAccount and signOut share the same network-free local purge
    // (api.clearJWT()); the network leg is the server delete and is not
    // relevant to the local-credential guarantee. We test the shared primitive.

    @Test func clearJWTRemovesTokenFromKeychain() async {
        let keychain = InMemoryKeychain()
        keychain.write(key: "jwt", value: "seed-token")
        let api = LumaAPI(keychain: keychain)
        #expect(await api.jwt == "seed-token")

        await api.clearJWT()

        #expect(await api.jwt == nil)
        #expect(keychain.read(key: "jwt") == nil)
    }

    @Test func signOutClearsTokenAndResetsState() async {
        let keychain = InMemoryKeychain()
        keychain.write(key: "jwt", value: "seed-token")
        let api = LumaAPI(keychain: keychain)
        let model = AccountModel(api: api)
        #expect(model.isSignedIn == true)   // init read the seeded token

        await model.signOut()

        #expect(model.isSignedIn == false)
        #expect(keychain.read(key: "jwt") == nil)
    }
}
