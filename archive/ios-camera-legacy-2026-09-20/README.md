# Legacy iOS camera snapshot

This directory preserves the native camera implementation that was removed from
the active iOS target on 2026-09-20 before a full rewrite.

- `Features/Camera/` contains the former SwiftUI camera screen and controls.
- `Core/Camera/` contains the former AVFoundation capture and output pipeline.
- The files are outside `ios/Framewise/`, so Xcode does not compile them.
- Treat this directory as reference material only. New camera code belongs under
  `ios/Framewise/Features/Camera/` and focused domain directories under
  `ios/Framewise/`.

The snapshot was taken from repository revision `e7b40b9`.

## Related archived documents

These documents describe the snapshot rather than the active camera rewrite:

- [`plans/ios-camera-module-phase-1.md`](../../plans/ios-camera-module-phase-1.md)
- [`plans/ios-camera-performance.md`](../../plans/ios-camera-performance.md)
- [`plans/ios-camera-imaging-pipeline.md`](../../plans/ios-camera-imaging-pipeline.md)

The camera-specific parts of
[`plans/ios-single-template-camera-flow.md`](../../plans/ios-single-template-camera-flow.md)
are also archived. Its template catalog and navigation contracts remain active.
