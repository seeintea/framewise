import AVFoundation
import SwiftUI

struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    let viewportSize: CGSize
    var isMirrored = false
    let onTap: (CGPoint, CGPoint) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onTap: onTap) }

    func makeUIView(context: Context) -> PreviewContainerView {
        let view = PreviewContainerView(viewportSize: viewportSize)
        view.previewView.previewLayer.videoGravity = .resizeAspectFill
        view.previewView.previewLayer.session = session
        view.previewView.isMirrored = isMirrored
        let tap = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.didTap(_:))
        )
        view.previewView.addGestureRecognizer(tap)
        return view
    }

    func updateUIView(_ view: PreviewContainerView, context: Context) {
        context.coordinator.onTap = onTap
        if view.previewView.previewLayer.session !== session {
            view.previewView.previewLayer.session = session
        }
        view.previewView.isMirrored = isMirrored
        if view.viewportSize != viewportSize {
            // Match the SwiftUI crop and overlay animation without resizing its hosted UIView.
            context.animate {
                view.viewportSize = viewportSize
                view.setNeedsLayout()
                view.layoutIfNeeded()
            }
        }
    }

    final class Coordinator: NSObject {
        var onTap: (CGPoint, CGPoint) -> Void

        init(onTap: @escaping (CGPoint, CGPoint) -> Void) { self.onTap = onTap }

        @objc func didTap(_ gesture: UITapGestureRecognizer) {
            guard let view = gesture.view as? PreviewView else { return }
            let location = gesture.location(in: view)
            onTap(
                view.previewLayer.captureDevicePointConverted(
                    fromLayerPoint: location
                ),
                location
            )
        }
    }
}

final class PreviewContainerView: UIView {
    let previewView = PreviewView()
    var viewportSize: CGSize

    init(viewportSize: CGSize) {
        self.viewportSize = viewportSize
        super.init(frame: .zero)
        previewView.clipsToBounds = true
        addSubview(previewView)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        previewView.bounds = CGRect(origin: .zero, size: viewportSize)
        previewView.center = CGPoint(x: bounds.midX, y: bounds.midY)
    }
}

final class PreviewView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }

    var isMirrored = false {
        didSet { updateMirroring() }
    }

    var previewLayer: AVCaptureVideoPreviewLayer {
        layer as! AVCaptureVideoPreviewLayer
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        updateMirroring()
    }

    private func updateMirroring() {
        guard let connection = previewLayer.connection,
            connection.isVideoMirroringSupported
        else { return }
        connection.automaticallyAdjustsVideoMirroring = false
        if connection.isVideoMirrored != isMirrored {
            connection.isVideoMirrored = isMirrored
        }
    }
}
