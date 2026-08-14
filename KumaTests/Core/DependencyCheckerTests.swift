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
}
