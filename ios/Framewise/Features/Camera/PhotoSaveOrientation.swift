import UIKit

enum PhotoSaveOrientation {
    case portrait
    case landscapeAutomatic
    case landscapeLeft
    case landscapeRight

    /// Rotates the completed portrait crop; capture and crop geometry stay unchanged.
    func applied(
        to image: UIImage,
        deviceOrientation: UIDeviceOrientation,
        lastLandscapeOrientation: UIDeviceOrientation?,
        motionLandscapeOrientation: UIDeviceOrientation?
    ) -> UIImage {
        guard self != .portrait else { return image }

        let outputSize = CGSize(width: image.size.height, height: image.size.width)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: outputSize, format: format)

        return renderer.image { context in
            switch resolvedRotation(
                deviceOrientation: deviceOrientation,
                lastLandscapeOrientation: lastLandscapeOrientation,
                motionLandscapeOrientation: motionLandscapeOrientation
            ) {
            case .left:
                context.cgContext.translateBy(x: 0, y: outputSize.height)
                context.cgContext.rotate(by: -.pi / 2)
            case .right:
                context.cgContext.translateBy(x: outputSize.width, y: 0)
                context.cgContext.rotate(by: .pi / 2)
            }
            image.draw(at: .zero)
        }
    }

    private func resolvedRotation(
        deviceOrientation: UIDeviceOrientation,
        lastLandscapeOrientation: UIDeviceOrientation?,
        motionLandscapeOrientation: UIDeviceOrientation?
    ) -> Rotation {
        switch self {
        case .portrait, .landscapeLeft:
            return .left
        case .landscapeRight:
            return .right
        case .landscapeAutomatic:
            if motionLandscapeOrientation == .landscapeRight { return .right }
            if motionLandscapeOrientation == .landscapeLeft { return .left }
            switch deviceOrientation {
            case .landscapeRight: return .right
            case .landscapeLeft: return .left
            default: return lastLandscapeOrientation == .landscapeRight ? .right : .left
            }
        }
    }

    private enum Rotation {
        case left
        case right
    }
}
