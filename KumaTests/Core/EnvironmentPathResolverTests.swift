import Foundation
import Testing
@testable import Kuma

@Suite("Core Engine Tests: EnvironmentPathResolver")
struct EnvironmentPathResolverTests {

    @Test("Resolver resolves non-empty system PATH")
    func testResolvePath() async {
        let resolver = EnvironmentPathResolver()
        let path = await resolver.resolvePath()

        #expect(!path.isEmpty)
        #expect(path.contains("/usr/bin") || path.contains("/bin"))
    }

    @Test("Resolver resolves standard macOS system binaries")
    func testResolveSystemBinaries() async {
        let resolver = EnvironmentPathResolver()

        let whichPath = await resolver.resolveExecutablePath(for: "which")
        #expect(whichPath != nil)
        #expect(whichPath?.hasSuffix("/which") == true)

        let shPath = await resolver.resolveExecutablePath(for: "sh")
        #expect(shPath != nil)
        #expect(shPath?.hasSuffix("/sh") == true)
    }

    @Test("Resolver handles non-existent binary safely")
    func testNonExistentBinary() async {
        let resolver = EnvironmentPathResolver()
        let fakePath = await resolver.resolveExecutablePath(for: "this_binary_does_not_exist_xyz123")
        #expect(fakePath == nil)
    }

    @Test("Resolver handles direct absolute paths")
    func testDirectAbsolutePath() async {
        let resolver = EnvironmentPathResolver()
        let resolved = await resolver.resolveExecutablePath(for: "/bin/zsh")
        #expect(resolved == "/bin/zsh")
    }

    @Test("Resolver handles empty string gracefully")
    func testEmptyString() async {
        let resolver = EnvironmentPathResolver()
        let resolved = await resolver.resolveExecutablePath(for: "   ")
        #expect(resolved == nil)
    }
}
