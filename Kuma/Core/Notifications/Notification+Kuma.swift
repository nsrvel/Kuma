import Foundation

// MARK: - Notification Names

extension NSNotification.Name {
    public static let kumaOpenSettings = NSNotification.Name("kuma.openSettings")
    public static let kumaOpenOnboarding = NSNotification.Name("kuma.openOnboarding")
    public static let kumaServiceCreated = NSNotification.Name("kuma.serviceCreated")
    public static let kumaServiceUpdated = NSNotification.Name("kuma.serviceUpdated")
    public static let kumaServiceDeleted = NSNotification.Name("kuma.serviceDeleted")
    public static let kumaCreateServiceRequested = NSNotification.Name("kuma.createServiceRequested")
    public static let kumaExportWorkspace = NSNotification.Name("kuma.exportWorkspace")
    public static let kumaImportWorkspace = NSNotification.Name("kuma.importWorkspace")
    public static let kumaFocusSearch = NSNotification.Name("kuma.focusSearch")
}

