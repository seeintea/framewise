//
//  CameraPreview.swift
//  Framewise
//
//  Created by Codex on 2026/9/14.
//

@preconcurrency import AVFoundation
import SwiftUI
import UIKit

struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    let position: CameraPosition
    let onFocus: (CGPoint, CGPoint) -> Void
    let onCaptureRotationAngleChanged: (Double) -> Void

    func makeUIView(context: Context) -> CameraPreviewView {
        let view = CameraPreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        view.onFocus = onFocus
        view.onCaptureRotationAngleChanged = onCaptureRotationAngleChanged
        view.updateCamera(position: position)
        return view
    }

    func updateUIView(_ view: CameraPreviewView, context: Context) {
        if view.previewLayer.session !== session {
            view.previewLayer.session = session
        }

        view.onFocus = onFocus
        view.onCaptureRotationAngleChanged = onCaptureRotationAngleChanged
        view.updateCamera(position: position)
    }

    static func dismantleUIView(_ view: CameraPreviewView, coordinator: ()) {
        view.stopObservingRotation()
    }
}

final class CameraPreviewView: UIView {
    var onFocus: ((CGPoint, CGPoint) -> Void)?
    var onCaptureRotationAngleChanged: ((Double) -> Void)?

    private var cameraDeviceID: String?
    private var rotationCoordinator: AVCaptureDevice.RotationCoordinator?
    private var previewRotationObservation: NSKeyValueObservation?
    private var captureRotationObservation: NSKeyValueObservation?

    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        addGestureRecognizer(
            UITapGestureRecognizer(target: self, action: #selector(didTap(_:)))
        )
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        addGestureRecognizer(
            UITapGestureRecognizer(target: self, action: #selector(didTap(_:)))
        )
    }

    var previewLayer: AVCaptureVideoPreviewLayer {
        guard let previewLayer = layer as? AVCaptureVideoPreviewLayer else {
            preconditionFailure("CameraPreviewView must use AVCaptureVideoPreviewLayer")
        }

        return previewLayer
    }

    func updateCamera(position: CameraPosition) {
        let devicePosition: AVCaptureDevice.Position =
            position == .front ? .front : .back
        guard let device = previewLayer.session?.inputs
            .compactMap({ ($0 as? AVCaptureDeviceInput)?.device })
            .first(where: { $0.hasMediaType(.video) && $0.position == devicePosition })
        else {
            return
        }

        configureMirroring(isFrontFacing: position == .front)

        guard cameraDeviceID != device.uniqueID else {
            return
        }

        stopObservingRotation()
        cameraDeviceID = device.uniqueID

        let coordinator = AVCaptureDevice.RotationCoordinator(
            device: device,
            previewLayer: previewLayer
        )
        rotationCoordinator = coordinator
        previewRotationObservation = coordinator.observe(
            \.videoRotationAngleForHorizonLevelPreview,
            options: [.initial, .new]
        ) { [weak self] coordinator, _ in
            Task { @MainActor [weak self] in
                self?.applyPreviewRotation(
                    coordinator.videoRotationAngleForHorizonLevelPreview
                )
            }
        }
        captureRotationObservation = coordinator.observe(
            \.videoRotationAngleForHorizonLevelCapture,
            options: [.initial, .new]
        ) { [weak self] coordinator, _ in
            let angle = coordinator.videoRotationAngleForHorizonLevelCapture
            Task { @MainActor [weak self] in
                self?.onCaptureRotationAngleChanged?(Double(angle))
            }
        }
    }

    func stopObservingRotation() {
        previewRotationObservation?.invalidate()
        captureRotationObservation?.invalidate()
        previewRotationObservation = nil
        captureRotationObservation = nil
        rotationCoordinator = nil
        cameraDeviceID = nil
    }

    private func configureMirroring(isFrontFacing: Bool) {
        guard let connection = previewLayer.connection else {
            return
        }

        connection.automaticallyAdjustsVideoMirroring = false
        if connection.isVideoMirroringSupported {
            connection.isVideoMirrored = isFrontFacing
        }
    }

    private func applyPreviewRotation(_ angle: CGFloat) {
        guard let connection = previewLayer.connection,
              connection.isVideoRotationAngleSupported(angle) else {
            return
        }

        connection.videoRotationAngle = angle
    }

    @objc private func didTap(_ recognizer: UITapGestureRecognizer) {
        let previewPoint = recognizer.location(in: self)
        let devicePoint = previewLayer.captureDevicePointConverted(
            fromLayerPoint: previewPoint
        )
        onFocus?(previewPoint, devicePoint)
    }
}
