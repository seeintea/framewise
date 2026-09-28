# Composition templates

This directory contains platform-neutral composition template data, currently
consumed by iOS and Template Studio. It is also suitable for a future Android app;
the current repository has no Android app implementation. It does not contain
platform runtime objects or UI implementation details.

The files described here are the current data contract. The older
[V1 model draft](../plans/template-data-model.md) contains superseded containers
and names; use the actual JSON and consumers when changing the schema. Project
implementation and remaining work are tracked in [plans](../plans/README.md).

## Layout

Each template is an independent directory named with its stable, human-readable
key:

```text
templates/
└── centered-subject/
    ├── template.v1.json
    └── zh-Hans.v1.json
```

- `template.v1.json` contains template identity, the default variant, every
  aspect-ratio variant, normalized geometry, and annotation anchors.
- `<locale>.v1.json` contains the localized title, description, variant
  instructions, and annotation text.
- Variants remain nested in their template because they do not have an
  independent authoring lifecycle.

## Identity

Templates and variants use lowercase UUID v4 strings as stable entity IDs. Their
previous semantic identifiers are retained as `key` values for directory names,
logs, tests, and authoring. Element and annotation identifiers are local semantic
`key` values because they remain part of the variant geometry document.

UUIDs are generated once and must not change when copy, geometry, filenames, or
template keys are edited. A localization references its template and variants by
UUID.

## Images

Image integration is not implemented yet. When images are added, filenames are
derived directly from the entity they represent:

```text
images/
├── templates/<template-uuid>.webp
└── variants/<variant-uuid>.webp
```

A missing image is valid. Template-level images represent catalog covers, while
aspect-ratio-specific previews use the variant ID. JSON does not store redundant
local image paths while this relationship remains one-to-one.

## Geometry

Coordinates, radii, bounds, corner radii, and annotation widths are normalized to
the `0...1` range. User-facing copy must not appear in `template.v1.json`.
Presentation metadata such as categories and collection ordering is outside the
current template schema.
