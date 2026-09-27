import Foundation
import os

enum CreateServiceSaving {
    private static let logger = Logger(subsystem: "lokastudio.kuma", category: "CreateServiceSheet")

    @MainActor
    static func beginCreate(
        workspaceID: UUID,
        inputs: CreateServicePayloadBuilder.DraftInputs,
        serviceRepository: any ServiceRepositoryProtocol,
        onServiceCreated: (() -> Void)?,
        dismiss: @escaping () -> Void,
        onSavingFailed: @escaping () -> Void
    ) {
        save(
            workspaceID: workspaceID,
            inputs: inputs,
            serviceRepository: serviceRepository,
            onSuccess: {
                onServiceCreated?()
                dismiss()
            },
            onFailure: onSavingFailed
        )
    }

    @MainActor
    static func save(
        workspaceID: UUID,
        inputs: CreateServicePayloadBuilder.DraftInputs,
        serviceRepository: any ServiceRepositoryProtocol,
        onSuccess: @escaping () -> Void,
        onFailure: @escaping () -> Void
    ) {
        Task {
            do {
                let (service, provider, portMappings) = try CreateServicePayloadBuilder.buildPayload(
                    workspaceID: workspaceID,
                    inputs: inputs
                )
                try await serviceRepository.insertService(service, defaultProvider: provider, portMappings: portMappings)
                onSuccess()
            } catch {
                logger.error("Failed to create service: \(error.localizedDescription)")
                onFailure()
            }
        }
    }
}
