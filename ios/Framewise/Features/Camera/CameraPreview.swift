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
    let zoomFactor: Double
    let minimumZoomFactor: Double
    let maximumZoomFactor: Double
    let isZoomEnabled: Bool
    let onFocus: (CGPoint, CGPoint) -> Void
    let onZoomFactorChanged: (Double) -> Void
    let onCaptureRotationAngleChanged: (Double) -> Void
    let onControlRotationAngleChanged: (Double) -> Void

    func makeUIView(context: Context) -> CameraPreviewView {
        let view = CameraPreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        view.onFocus = onFocus
        view.onZoomFactorChanged = onZoomFactorChanged
        view.onCaptureRotationAngleChanged = onCaptureRotationAngleChanged
        view.onControlRotationAngleChanged = onControlRotationAngleChanged
        view.updateZoom(
            factor: zoomFactor,
            minimum: minimumZoomFactor,
            maximum: maximumZoomFactor,
            isEnabled: isZoomEnabled
        )
        view.updateCamera(position: position)
        return view
    }

    func updateUIView(_ view: CameraPreviewView, context: Context) {
        if view.previewLayer.session !== session {
            view.previewLayer.session = session
        }

        view.onFocus = onFocus
        view.onZoomFactorChanged = onZoomFactorChanged
        view.onCaptureRotationAngleChanged = onCaptureRotationAngleChanged
        view.onControlRotationAngleChanged = onControlRotationAngleChanged
        view.updateZoom(
            factor: zoomFactor,
            minimum: minimumZoomFactor,
            maximum: maximumZoomFactor,
            isEnabled: isZoomEnabled
        )
        view.updateCamera(position: position)
    }

    static func dismantleUIView(_ view: CameraPreviewView, coordinator: ()) {
        view.stopObservingRotation()
    }
}

final class CameraPreviewView: UIView {
    var onFocus: ((CGPoint, CGPoint) -> Void)?
    var onZoomFactorChanged: ((Double) -> Void)?
    var onCaptureRotationAngleChanged: ((Double) -> Void)?
    var onControlRotationAngleChanged: ((Double) -> Void)?

    private var cameraDeviceID: String?
    private var rotationCoordinator: AVCaptureDevice.RotationCoordinator?
    private var previewRotationObservation: NSKeyValueObservation?
    private var captureRotationObservation: NSKeyValueObservation?
    private var zoomFactor: CGFloat = 1
    private var minimumZoomFactor: CGFloat = 1
    private var maximumZoomFactor: CGFloat = 1
    private var zoomFactorAtPinchStart: CGFloat?
    private var isZoomEnabled = false

    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        installGestureRecognizers()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        installGestureRecognizers()
    }

    private func installGestureRecognizers() {
        addGestureRecognizer(
            UITapGestureRecognizer(target: self, action: #selector(didTap(_:)))
        )
        addGestureRecognizer(
            UIPinchGestureRecognizer(
                target: self,
                action: #selector(didPinch(_:))
            )
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
            let captureAngle =
                coordinator.videoRotationAngleForHorizonLevelCapture
            let previewAngle =
                coordinator.videoRotationAngleForHorizonLevelPreview
            Task { @MainActor [weak self] in
                self?.applyPreviewRotation(
                    previewAngle
                )
                self?.reportControlRotation(
                    captureAngle: captureAngle,
                    previewAngle: previewAngle
                )
            }
        }
        captureRotationObservation = coordinator.observe(
            \.videoRotationAngleForHorizonLevelCapture,
            options: [.initial, .new]
        ) { [weak self] coordinator, _ in
            let captureAngle =
                coordinator.videoRotationAngleForHorizonLevelCapture
            let previewAngle =
                coordinator.videoRotationAngleForHorizonLevelPreview
            Task { @MainActor [weak self] in
                self?.onCaptureRotationAngleChanged?(Double(captureAngle))
                self?.reportControlRotation(
                    captureAngle: captureAngle,
                    previewAngle: previewAngle
                )
            }
        }
    }

    func updateZoom(
        factor: Double,
        minimum: Double,
        maximum: Double,
        isEnabled: Bool
    ) {
        minimumZoomFactor = CGFloat(minimum)
        maximumZoomFactor = CGFloat(max(maximum, minimum))
        self.isZoomEnabled = isEnabled

        guard zoomFactorAtPinchStart == nil else {
            return
        }

        zoomFactor = min(
            max(CGFloat(factor), minimumZoomFactor),
            maximumZoomFactor
        )
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

    private func reportControlRotation(
        captureAngle: CGFloat,
        previewAngle: CGFloat
    ) {
        var angle = (previewAngle - captureAngle)
            .truncatingRemainder(dividingBy: 360)

        if angle > 180 {
            angle -= 360
        } else if angle <= -180 {
            angle += 360
        }

        let snappedAngle = (angle / 90).rounded() * 90
        onControlRotationAngleChanged?(
            Double(snappedAngle == -0 ? 0 : snappedAngle)
        )
    }

    @objc private func didTap(_ recognizer: UITapGestureRecognizer) {
        let previewPoint = recognizer.location(in: self)
        let devicePoint = previewLayer.captureDevicePointConverted(
            fromLayerPoint: previewPoint
        )
        onFocus?(previewPoint, devicePoint)
    }

    @objc private func didPinch(_ recognizer: UIPinchGestureRecognizer) {
        switch recognizer.state {
        case .began:
            guard isZoomEnabled else {
                return
            }
            zoomFactorAtPinchStart = zoomFactor
        case .changed:
            guard isZoomEnabled,
                  let zoomFactorAtPinchStart else {
                return
            }

            let requestedFactor = zoomFactorAtPinchStart * recognizer.scale
            let clampedFactor = min(
                max(requestedFactor, minimumZoomFactor),
                maximumZoomFactor
            )
            zoomFactor = clampedFactor
            onZoomFactorChanged?(Double(clampedFactor))
        case .ended, .cancelled, .failed:
            zoomFactorAtPinchStart = nil
        case .possible:
            break
        @unknown default:
            zoomFactorAtPinchStart = nil
        }
    }
}
