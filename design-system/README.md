# Framewise Design System Assets

This directory owns the shared visual source files used to keep Framewise's UI
consistent across iOS, Android, and web tooling.

- `fonts/` contains the canonical font binaries.
- `icons/` contains canonical SVG geometry for custom product icons.
- `brand/` contains platform-neutral app icon and logo source images.

Platform projects remain responsible for runtime packaging. For example, iOS
keeps its asset catalog and references the SVG sources from its imagesets, while
Android-specific adaptive and monochrome icon exports live under `android/`.
Platform wrappers and exports must not become independently edited design sources.
