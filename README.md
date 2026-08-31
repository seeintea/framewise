# Framewise

An Expo SDK 57 app that helps people compose better photos with visual templates
overlaid on the live camera preview.

## Development

This project uses pnpm and Expo Go for the initial development workflow.

```bash
pnpm install
pnpm start
```

Open the project in Expo Go from the development server.

## Product scope

- Browse a small set of composition templates.
- Open a template in the camera.
- Align the scene with proportional guides drawn over the preview.
- Take, review, save, or retake the photo.

## Structure

```text
src/
├── app/          # Expo Router routes and route layouts
├── features/     # Templates, camera overlay, and photo review
└── shared/       # Cross-feature UI, utilities, types, and configuration
```

The first version uses Expo Camera and a React Native Skia overlay. Templates
store guide geometry as normalized coordinates so they work across screen sizes
and can later serve as targets for optional on-device guidance.

See [the first-version architecture](./plans/architecture.md) for the product
flow, module boundaries, template model, and implementation order.

See [the MVP plan](./plans/mvp.md) for the first end-to-end validation scope and
acceptance criteria.
