# HerFrame

An Expo SDK 57 application for validating the HerFrame camera-guidance concept.

## Development

This project uses pnpm and an Expo development build. Expo Go is not part of the
development workflow because the camera layer will use app-local native code.

```bash
pnpm install
pnpm ios
```

After the native app is installed, start Metro with:

```bash
pnpm start
```

## Structure

```text
src/
├── app/          # Expo Router routes and route layouts only
├── profiles/     # Subject profiles and baseline measurements
├── references/   # Reference-image selection and derived data
├── guidance/     # Guidance state and camera instructions
└── shared/       # Cross-feature UI, utilities, types, and configuration
modules/
└── smart-camera/ # App-local native camera boundary
```

Route files should remain thin: they compose and export domain screens. Native
camera processing belongs in a local Expo module under `modules/`; camera frames
and pixel buffers must not cross the React Native bridge.

The generated `ios/` and `android/` directories are intentionally ignored and
must remain reproducible through Expo Prebuild and config plugins.

`modules/smart-camera` is an Apple-only, app-local Expo module skeleton. It is
intentionally behavior-free until the native camera feasibility work begins.
