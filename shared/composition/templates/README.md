# Per-template authoring packages

Each directory under this path represents one composition template. The pilot
package has the following structure:

```text
centered-subject/
├── template.json
├── variants/
│   ├── 3x4.json
│   └── 1x1.json
└── locales/
    └── zh-Hans.json
```

- `template.json` owns stable identity, content revision, default variant, and
  deterministic variant order. It does not duplicate derived aspect-ratio data.
- `variants/*.json` owns renderable geometry and annotation anchors for one
  independently designed aspect ratio.
- `locales/<locale>.json` owns template copy, variant instructions, and annotation
  text. Variant and annotation maps use stable IDs instead of array position.

The directory name, template ID, variant references, localization references,
and schema versions are checked when the package is assembled. List ordering and
grouping are intentionally outside individual packages because they describe a
collection rather than one template.

`schemaVersion` describes structural compatibility. `revision` describes changes
to the template's content and will eventually support editor drafts and published
history.
