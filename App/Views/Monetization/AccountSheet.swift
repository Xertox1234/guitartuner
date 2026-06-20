import SwiftUI
import AuthenticationServices
import LumaDesignSystem
import os

/// Registration / sign-in flow. Presented when unauthenticated user tries to save a card.
struct AccountSheet: View {
    private static let logger = Logger(subsystem: "com.luma.app", category: "account")
    @Bindable var accountModel: AccountModel
    @Environment(\.dismiss) private var dismiss

    @State private var email = ""
    @State private var password = ""
    @State private var isRegistering = true
    @State private var showVerificationStep = false
    @State private var marketingOptIn = false
    @State private var errorMessage: String?

    // Dynamic-Type-scaled sizes for inline `Text + Text` runs, where `.lumaUIFont`
    // (which returns `some View`) cannot be used because `+` requires `Text`.
    @ScaledMetric(relativeTo: .body) private var bodySize: CGFloat = LumaFont.Size.body
    @ScaledMetric(relativeTo: .caption2) private var microSize: CGFloat = LumaFont.Size.micro

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
            if let err = errorMessage {
                Section {
                    Text(err)
                        .foregroundStyle(.red)
                        .lumaUIFont(LumaFont.Size.body)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            Section {
                if accountModel.isLoading {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                    .frame(height: 44)
                } else {
                    SignInWithAppleButton(.signIn) { request in
                        request.requestedScopes = [.email, .fullName]
                    } onCompletion: { result in
                        handleAppleResult(result)
                    }
                    .signInWithAppleButtonStyle(.black)
                    .frame(height: 44)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                }
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
                .lumaUIFont(LumaFont.Size.label)
                .foregroundStyle(.secondary)
            }

            Section {
                Text("All audio is analyzed on your device and never sent anywhere. ")
                    .font(LumaFont.ui(microSize))
                    .foregroundStyle(.tertiary)
                + Text("Privacy Policy")
                    .font(LumaFont.ui(microSize))
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
                        .font(LumaFont.display(LumaFont.Size.lg, weight: .semibold, relativeTo: .title3))
                    Text("We sent a verification link to ")
                        .font(LumaFont.ui(bodySize)).foregroundStyle(.secondary)
                    + Text(email)
                        .font(LumaFont.ui(bodySize)).foregroundStyle(Color.lumaInTune)
                }
                .padding(.vertical, 4)
            }

            Section {
                Toggle(isOn: $marketingOptIn) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Get exclusive gear deals")
                            .lumaUIFont(LumaFont.Size.body)
                        Text("Occasional handpicked Sweetwater deals. No spam. Unsubscribe anytime.")
                            .lumaUIFont(LumaFont.Size.cap)
                            .foregroundStyle(.secondary)
                    }
                }
                .tint(.lumaInTune)

                if marketingOptIn {
                    Text("We'll use **\(email)** for gear deal emails.")
                        .lumaUIFont(LumaFont.Size.cap)
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
                    .lumaUIFont(LumaFont.Size.label)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)

                Button("Resend verification email") {
                    Task { try? await accountModel.register(email: email, password: password) }
                }
                .lumaUIFont(LumaFont.Size.cap)
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
            guard let credential = auth.credential as? ASAuthorizationAppleIDCredential else {
                Self.logger.error("Apple sign-in: unexpected credential type")
                return
            }
            Task {
                do {
                    try await accountModel.signInWithApple(credential)
                    Self.logger.notice("Apple sign-in: success")
                    dismiss()
                } catch {
                    Self.logger.error("Apple sign-in: failed — \(String(describing: error), privacy: .private)")
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
