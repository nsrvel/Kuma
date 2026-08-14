//
//  SystemDependencyTests.swift
//  KumaTests
//
//  Created for Kuma Native macOS App.
//

import Testing
@testable import Kuma

@Suite("Domain Model Tests: SystemDependency")
struct SystemDependencyTests {

    @Test("SystemDependency initialization and properties")
    func testInitialization() {
        let dependency = SystemDependency(
            id: "docker",
            name: "Docker Engine",
            iconName: "shippingbox.fill",
            isInstalled: true,
            path: "/opt/homebrew/bin/docker",
            version: "27.0.0",
            category: .engine,
            description: "Enables Docker Compose provider",
            settingsKey: "kuma.custom_docker_path"
        )

        #expect(dependency.id == "docker")
        #expect(dependency.name == "Docker Engine")
        #expect(dependency.iconName == "shippingbox.fill")
        #expect(dependency.isInstalled == true)
        #expect(dependency.path == "/opt/homebrew/bin/docker")
        #expect(dependency.version == "27.0.0")
        #expect(dependency.category == .engine)
        #expect(dependency.description == "Enables Docker Compose provider")
        #expect(dependency.settingsKey == "kuma.custom_docker_path")
    }

    @Test("SystemDependency Equatable conformance")
    func testEquality() {
        let dep1 = SystemDependency(id: "k8s", name: "Kubernetes", iconName: "network", isInstalled: true)
        let dep2 = SystemDependency(id: "k8s", name: "Kubernetes", iconName: "network", isInstalled: true)
        let dep3 = SystemDependency(id: "k8s", name: "Kubernetes", iconName: "network", isInstalled: false)

        #expect(dep1 == dep2)
        #expect(dep1 != dep3)
    }
}
