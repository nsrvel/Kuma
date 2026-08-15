//
//  DependencyCheckerTests.swift
//  KumaTests
//
//  Created for Kuma Native macOS App.
//

import Foundation
import Testing
@testable import Kuma

@Suite("Core Engine Tests: DependencyChecker")
struct DependencyCheckerTests {

    @Test("DependencyChecker checkAll completes non-blocking")
    func testCheckAllExecution() async {
        let status = await DependencyChecker.checkAll()
        // Ensure checkAll returns a valid DependencyStatus instance without crashing
        #expect(type(of: status.kubectlInstalled) == Bool.self)
        #expect(type(of: status.dockerInstalled) == Bool.self)
        #expect(type(of: status.kubeconfigExists) == Bool.self)
    }

    @Test("DependencyChecker resolves valid system command")
    func testResolvedPathForSystemCommand() async {
        let isWhichInstalled = await DependencyChecker.isCommandInstalled("which")
        #expect(isWhichInstalled == true)

        let isFakeInstalled = await DependencyChecker.isCommandInstalled("fake_unknown_cli_999")
        #expect(isFakeInstalled == false)
    }

    @Test("DependencyChecker supports custom path override")
    func testCustomPathOverride() async {
        let isCustomInstalled = await DependencyChecker.isCommandInstalled("sh", customPath: "/bin/sh")
        #expect(isCustomInstalled == true)

        let isFakeCustomInstalled = await DependencyChecker.isCommandInstalled("sh", customPath: "/non/existent/path/sh")
        #expect(isFakeCustomInstalled == false)
    }

    @Test("DependencyChecker validates binary path edge cases")
    func testBinaryValidation() {
        // 1. Empty path
        #expect(DependencyChecker.validateCustomBinary(path: "", expectedCommand: "docker") == .empty)
        #expect(DependencyChecker.validateCustomBinary(path: "   ", expectedCommand: "docker") == .empty)

        // 2. Valid binary (e.g. /bin/sh or /bin/zsh)
        let shResult = DependencyChecker.validateCustomBinary(path: "/bin/sh", expectedCommand: "sh")
        #expect(shResult.isValid == true)
        #expect(shResult.errorMessage == nil)

        // 3. File not found
        let notFound = DependencyChecker.validateCustomBinary(path: "/invalid/path/docker", expectedCommand: "docker")
        #expect(notFound == .fileNotFound)
        #expect(notFound.errorMessage != nil)

        // 4. Directory instead of executable
        let dirResult = DependencyChecker.validateCustomBinary(path: "/bin", expectedCommand: "bin")
        #expect(dirResult == .notExecutable)

        // 5. Binary name mismatch (e.g. selecting /bin/sh when expected docker)
        let mismatch = DependencyChecker.validateCustomBinary(path: "/bin/sh", expectedCommand: "docker")
        #expect(mismatch == .nameMismatch(expected: "docker", actual: "sh"))
        #expect(mismatch.errorMessage != nil)
    }
}
