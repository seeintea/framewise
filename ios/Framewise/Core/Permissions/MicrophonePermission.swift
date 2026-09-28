//
//  MicrophonePermission.swift
//  Framewise
//
//  Created by yukkuri on 2026/9/21.
//

@preconcurrency import AVFAudio

nonisolated enum MicrophonePermission {
    static var status: PermissionStatus {
        PermissionStatus(AVAudioApplication.shared.recordPermission)
    }

    static var isAuthorized: Bool {
        status.isAuthorized
    }

    static func request() async -> PermissionStatus {
        let currentStatus = status
        guard currentStatus == .notDetermined else {
            return currentStatus
        }

        return await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { _ in
                continuation.resume(returning: status)
            }
        }
    }
}

extension PermissionStatus {
    fileprivate nonisolated init(_ status: AVAudioApplication.recordPermission) {
        switch status {
        case .undetermined:
            self = .notDetermined
        case .denied:
            self = .denied
        case .granted:
            self = .authorized
        @unknown default:
            self = .unknown
        }
    }
}
