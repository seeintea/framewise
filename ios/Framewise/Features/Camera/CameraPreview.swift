import AVFoundation
import SwiftUI

struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    let onTap: (CGPoint, CGPoint) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onTap: onTap) }

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.videoGravity = .resizeAspectFill
        view.previewLayer.session = session
        let tap = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.didTap(_:))
        )
        view.addGestureRecognizer(tap)
        return view
    }

    func updateUIView(_ view: PreviewView, context: Context) {
        context.coordinator.onTap = onTap
        if view.previewLayer.session !== session {
            view.previewLayer.session = session
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

final class PreviewView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }

    var previewLayer: AVCaptureVideoPreviewLayer {
        layer as! AVCaptureVideoPreviewLayer
    }
}
