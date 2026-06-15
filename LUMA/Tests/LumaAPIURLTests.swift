import Foundation
import Testing
@testable import LUMA

@Suite("LumaAPI.buildURL")
struct LumaAPIURLTests {
    private let base = URL(string: "https://example.com")!

    @Test func singleSegmentPath() {
        let url = LumaAPI.buildURL(base: base, path: "health")
        #expect(url.absoluteString == "https://example.com/health")
    }

    // Regression: appending(component:) encoded the slash → auth%2Fapple → 404 on device.
    @Test func multiSegmentPathPreservesSlash() {
        let url = LumaAPI.buildURL(base: base, path: "auth/apple")
        #expect(!url.absoluteString.contains("%2F"))
        #expect(url.absoluteString == "https://example.com/auth/apple")
    }

    @Test func refreshPath() {
        let url = LumaAPI.buildURL(base: base, path: "auth/refresh")
        #expect(url.absoluteString == "https://example.com/auth/refresh")
    }
}
