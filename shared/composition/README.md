# Composition templates

This directory contains platform-neutral composition template resources shared by
iOS and Android.

- `templates.v1.json` contains stable identifiers, aspect ratios, normalized
  geometry, and annotation anchors. It must not contain user-facing copy.
- `descriptions/<locale>.v1.json` contains localized titles, descriptions,
  instructions, and annotation text, referenced by the same stable identifiers.

Coordinates, radii, bounds, corner radii, and annotation widths are normalized to
the `0...1` range. Presentation metadata such as categories, preview images, and
display order does not belong in either template document.
