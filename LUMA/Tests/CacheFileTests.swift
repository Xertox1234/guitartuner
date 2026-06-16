import Foundation
import Testing
@testable import LUMA

@Suite("CacheFile.write")
struct CacheFileTests {

    // Regression (iOS launch crash, 2026-06-16): Application Support is NOT
    // auto-created on iOS, so writing a cache to a not-yet-existing directory
    // must create the parent dir rather than throwing ENOENT. Before the fix the
    // write threw and the store's catch did `assertionFailure` → SIGTRAP on the
    // very first launch / in Previews on a real device.
    // See docs/solutions/runtime-errors/application-support-not-created-ios-debug-assert-crash-2026-06-16.md
    @Test func createsMissingParentDirectory() throws {
        let root = FileManager.default.temporaryDirectory
            .appending(component: "luma-cachefile-test-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }

        // A nested dir that does NOT exist yet — mirrors a fresh-install
        // Application Support that the OS has not created.
        let url = root
            .appending(component: "Application Support")
            .appending(component: "luma_cache.json")
        #expect(!FileManager.default.fileExists(atPath: url.deletingLastPathComponent().path))

        // Must not throw even though the parent directory is absent.
        try CacheFile.write(["DADGAD", "Drop D"], to: url)

        #expect(FileManager.default.fileExists(atPath: url.path))
        let roundTrip = try JSONDecoder().decode([String].self, from: Data(contentsOf: url))
        #expect(roundTrip == ["DADGAD", "Drop D"])
    }

    // Idempotent + atomic overwrite: createDirectory(withIntermediateDirectories:
    // true) does not throw when the directory already exists, and a second write
    // replaces the file. Guards the steady-state path (every persist after the
    // first) against a regression in the create-dir step.
    @Test func overwritesWhenDirectoryAlreadyExists() throws {
        let root = FileManager.default.temporaryDirectory
            .appending(component: "luma-cachefile-test-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        let url = root.appending(component: "luma_cache.json")

        try CacheFile.write([1, 2, 3], to: url)
        try CacheFile.write([4, 5], to: url)   // dir now exists — must not throw

        let roundTrip = try JSONDecoder().decode([Int].self, from: Data(contentsOf: url))
        #expect(roundTrip == [4, 5])
    }
}
