import SwiftUI
import AuthenticationServices

/// Registration / sign-in flow. Presented when unauthenticated user tries to save a card.
struct AccountSheet: View {
    @Bindable var accountModel: AccountModel
    @Environment(\.dismiss) private var dismiss

    @State private var email = ""
    @State private var password = ""
    @State private var isRegistering = true
    @State private var showVerificationStep = false
    @State private var marketingOptIn = false
    @State private var marketingEmail = ""
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                if showVerificationStep {
                    verificationView
                } else {
                    authForm
                }
            }
            .navigationTitle(isRegistering ? "Create Account" : "Sign In")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .tint(.lumaInTune)
    }

    // MARK: - Auth form

    private var authForm: some View {
        Form {
            Section {
                SignInWithAppleButton(.signIn) { request in
                    request.requestedScopes = [.email, .fullName]
                } onCompletion: { result in
                    handleAppleResult(result)
                }
                .signInWithAppleButtonStyle(.whiteOutline)
                .frame(height: 44)
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            }

            Section {
                TextField("Email", text: $email)
                    .textContentType(.emailAddress)
                    .autocorrectionDisabled()
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    #endif
                SecureField("Password (8+ characters)", text: $password)
                    .textContentType(isRegistering ? .newPassword : .password)
            }

            if let err = errorMessage ?? accountModel.error {
                Section {
                    Text(err).foregroundStyle(.red).font(.caption)
                }
            }

            Section {
                Button {
                    Task { await submitEmailAuth() }
                } label: {
                    if accountModel.isLoading {
                        ProgressView()
                    } else {
                        Text(isRegistering ? "Create Account" : "Sign In")
                            .frame(maxWidth: .infinity)
                    }
                }
                .disabled(accountModel.isLoading || email.isEmpty || password.isEmpty)
            }

            Section {
                Button(isRegistering ? "Already have an account? Sign in" : "Need an account? Create one") {
                    isRegistering.toggle()
                    errorMessage = nil
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
            }

            Section {
                Text("All audio is analyzed on your device and never sent anywhere. ")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                + Text("Privacy Policy")
                    .font(.caption2)
                    .foregroundStyle(Color.lumaInTune)
            }
        }
    }

    // MARK: - Verification / opt-in screen (email path)

    private var verificationView: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Check your inbox")
                        .font(.headline)
                    Text("We sent a verification link to ")
                        .font(.subheadline).foregroundStyle(.secondary)
                    + Text(email)
                        .font(.subheadline).foregroundStyle(Color.lumaInTune)
                }
                .padding(.vertical, 4)
            }

            Section {
                Toggle(isOn: $marketingOptIn) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Get exclusive gear deals")
                            .font(.subheadline)
                        Text("Occasional handpicked Sweetwater deals. No spam. Unsubscribe anytime.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .tint(.lumaInTune)

                if marketingOptIn {
                    Text("We'll use **\(email)** for gear deal emails.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                Button("Continue") {
                    if marketingOptIn {
                        Task { try? await accountModel.subscribeMarketing(email: email) }
                    }
                    dismiss()
                }
                .frame(maxWidth: .infinity)
            }

            Section {
                Button("I'll skip for now") { dismiss() }
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)

                Button("Resend verification email") {
                    Task { try? await accountModel.register(email: email, password: password) }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Handlers

    private func submitEmailAuth() async {
        errorMessage = nil
        do {
            if isRegistering {
                try await accountModel.register(email: email, password: password)
                showVerificationStep = true
            } else {
                try await accountModel.login(email: email, password: password)
                dismiss()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func handleAppleResult(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let auth):
            guard let credential = auth.credential as? ASAuthorizationAppleIDCredential else { return }
            Task {
                do {
                    try await accountModel.signInWithApple(credential)
                    dismiss()
                } catch {
                    errorMessage = error.localizedDescription
                }
            }
        case .failure(let error):
            // User cancelled — ASAuthorizationError.canceled — ignore silently
            let nsError = error as NSError
            if nsError.code != ASAuthorizationError.canceled.rawValue {
                errorMessage = error.localizedDescription
            }
        }
    }
}
