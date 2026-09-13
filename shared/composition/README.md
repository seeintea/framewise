# Composition templates

This directory contains platform-neutral composition template resources shared by
iOS and Android.

- `templates.v1.json` contains stable identifiers, aspect ratios, normalized
  geometry, and annotation anchors. It must not contain user-facing copy.
- `descriptions/<locale>.v1.json` contains localized titles, descriptions,
  instructions, and annotation text, referenced by the same stable identifiers.

## Per-template authoring pilot

`templates/centered-subject/` is a pilot for treating each template as an
independent authoring package. The package separates template metadata, variant
geometry, and localized copy, while `scripts/assemble-template.mjs` joins them
into a consumer-facing detail object.

The existing aggregate documents remain the compatibility source during this
trial. The pilot can be checked against them with:

```bash
node shared/composition/scripts/assemble-template.mjs \
  centered-subject zh-Hans --check-legacy
```

Omit `--check-legacy` to print the assembled API-style object. If this structure
is adopted for all templates, the aggregate documents should become generated
artifacts rather than a second manually edited source.

Coordinates, radii, bounds, corner radii, and annotation widths are normalized to
the `0...1` range. Presentation metadata such as categories, preview images, and
display order does not belong in either template document.
