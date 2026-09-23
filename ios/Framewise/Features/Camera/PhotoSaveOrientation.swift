import UIKit

enum PhotoSaveOrientation {
    case portrait
    case landscapeAutomatic
    case landscapeLeft
    case landscapeRight

    func quarterTurns(
        deviceOrientation: UIDeviceOrientation,
        lastLandscapeOrientation: UIDeviceOrientation?,
        motionLandscapeOrientation: UIDeviceOrientation?
    ) -> Int {
        guard self != .portrait else { return 0 }
        return resolvedRotation(
            deviceOrientation: deviceOrientation,
            lastLandscapeOrientation: lastLandscapeOrientation,
            motionLandscapeOrientation: motionLandscapeOrientation
        ) == .left ? -1 : 1
    }

    /// Rotates the completed portrait crop; capture and crop geometry stay unchanged.
    func applied(
        to image: UIImage,
        deviceOrientation: UIDeviceOrientation,
        lastLandscapeOrientation: UIDeviceOrientation?,
        motionLandscapeOrientation: UIDeviceOrientation?
    ) -> UIImage {
        Self.applied(
            to: image,
            quarterTurns: quarterTurns(
                deviceOrientation: deviceOrientation,
                lastLandscapeOrientation: lastLandscapeOrientation,
                motionLandscapeOrientation: motionLandscapeOrientation
            )
        )
    }

    nonisolated static func applied(to image: UIImage, quarterTurns: Int) -> UIImage {
        guard quarterTurns != 0 else { return image }

        let outputSize = CGSize(width: image.size.height, height: image.size.width)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: outputSize, format: format)

        return renderer.image { context in
            if quarterTurns < 0 {
                context.cgContext.translateBy(x: 0, y: outputSize.height)
            } else {
                context.cgContext.translateBy(x: outputSize.width, y: 0)
            }
            context.cgContext.rotate(by: CGFloat(quarterTurns) * .pi / 2)
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
