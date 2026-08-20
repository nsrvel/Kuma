import Foundation

public enum KubeTargetType: String, CaseIterable, Codable, Sendable {
    case pod = "pod"
    case service = "service"
    case deployment = "deployment"

    public var label: String {
        switch self {
        case .pod: return "Pod"
        case .service: return "Service"
        case .deployment: return "Deployment"
        }
    }

    public var description: String {
        switch self {
        case .pod: return "Connect to a specific pod instance or match by pattern"
        case .service: return "Forward traffic to a stable Kubernetes service endpoint"
        case .deployment: return "Forward traffic to a deployment resource"
        }
    }

    public var prefix: String {
        switch self {
        case .pod: return "pod/"
        case .service: return "svc/"
        case .deployment: return "deploy/"
        }
    }

    public var placeholder: String {
        switch self {
        case .pod: return "postgres-pod-6f8d975b"
        case .service: return "postgres-service"
        case .deployment: return "postgres-deployment"
        }
    }

    public func placeholder(usePattern: Bool) -> String {
        if usePattern {
            switch self {
            case .pod: return "postgres-pod-*"
            case .service: return "postgres-*-svc"
            case .deployment: return "postgres-*-deployment"
            }
        } else {
            return placeholder
        }
    }
}
