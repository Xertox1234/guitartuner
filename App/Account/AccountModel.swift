import Foundation
import AuthenticationServices

@MainActor @Observable
final class AccountModel {
    var isSignedIn: Bool
    var isLoading = false

    let api: LumaAPI

    init(api: LumaAPI = LumaAPI()) {
        self.api = api
        // Synchronously check Keychain on init — no async needed
        self.isSignedIn = api.keychain.read(key: "jwt") != nil
    }

    // MARK: - Email + password

    func register(email: String, password: String) async throws {
        isLoading = true
        defer { isLoading = false }
        let _: MessageResponse = try await api.post("auth/register", body: RegisterRequest(email: email, password: password))
    }

    func login(email: String, password: String) async throws {
        isLoading = true
        defer { isLoading = false }
        let response: TokenResponse = try await api.post("auth/login", body: LoginRequest(email: email, password: password))
        await api.setJWT(response.token)
        isSignedIn = true
    }

    // MARK: - Sign in with Apple

    func signInWithApple(_ credential: ASAuthorizationAppleIDCredential) async throws {
        guard let tokenData = credential.identityToken,
              let token = String(data: tokenData, encoding: .utf8) else {
            throw LumaAPIError.server("No identity token from Apple", 0)
        }
        isLoading = true
        defer { isLoading = false }
        let response: TokenResponse = try await api.post("auth/apple", body: AppleAuthRequest(identityToken: token))
        await api.setJWT(response.token)
        isSignedIn = true
    }

    // MARK: - Email opt-in

    func subscribeMarketing(email: String?) async throws {
        let _: BoolResponse = try await api.post("email/subscribe", body: SubscribeRequest(email: email))
    }

    func unsubscribeMarketing() async throws {
        let _: BoolResponse = try await api.post("email/unsubscribe", body: SubscribeRequest(email: nil))
    }

    // MARK: - Sign out

    func signOut() async {
        await api.clearJWT()
        isSignedIn = false
    }

    func deleteAccount() async throws {
        isLoading = true
        defer { isLoading = false }
        let response: BoolResponse = try await api.delete("auth/account")
        guard response.deleted == true else {
            throw LumaAPIError.server("Account deletion failed", 0)
        }
        await api.clearJWT()
        isSignedIn = false
    }
}
