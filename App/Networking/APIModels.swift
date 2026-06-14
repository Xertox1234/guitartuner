import Foundation

// MARK: - Requests

struct RegisterRequest: Encodable {
    let email: String
    let password: String
}

struct LoginRequest: Encodable {
    let email: String
    let password: String
}

struct AppleAuthRequest: Encodable {
    let identityToken: String
}

struct SaveCardRequest: Encodable {
    let name: String
    let notes: String
    let instrument: String
    let a4: Double
    let palette: String
    let stringsJson: String

    enum CodingKeys: String, CodingKey {
        case name, notes, instrument, a4, palette
        case stringsJson = "strings_json"
    }
}

struct SubscribeRequest: Encodable {
    let email: String?
}

// MARK: - Responses

struct MessageResponse: Decodable { let message: String }
struct TokenResponse: Decodable { let token: String }
struct SaveCardResponse: Decodable { let id: String }
// CardsResponse is defined in TuningCardStore.swift (references TuningCard)
// ProductsResponse is defined in GearStoreModel.swift (references GearProduct)
struct BoolResponse: Decodable { let subscribed: Bool?; let unsubscribed: Bool?; let deleted: Bool? }

// MARK: - Error

struct APIErrorBody: Decodable { let error: String }

enum LumaAPIError: LocalizedError {
    case unauthorized
    case server(String, Int)
    case decoding(Error)

    var errorDescription: String? {
        switch self {
        case .unauthorized:          return "Please sign in again."
        case .server(let msg, _):    return msg
        case .decoding(let err):     return "Unexpected response: \(err.localizedDescription)"
        }
    }
}

// Internal empty-body marker
struct EmptyBody: Encodable {}
