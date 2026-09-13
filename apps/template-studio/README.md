# Framewise Template Studio

Desktop-first UI scaffold for browsing composition templates and previewing their
available sizes against a shared reference image.

The workbench uses Ant Design for reusable controls and interaction patterns, and
Tailwind CSS for layout, responsive behavior, and local visual composition. This
keeps the scaffold suitable for growing into a template editor later.

The current implementation deliberately uses fixtures from `src/demoCatalog.ts`.
It does not read, validate, or modify anything in `composition` yet.

## Run

```bash
cd apps/template-studio
npm install
npm run dev
```

## Build

```bash
npm run build
```

## Current interaction model

- The left sidebar lists each template once, independently of its sizes.
- Selecting a template shows that template's available sizes on the right.
- The current size is preserved when the next template supports it; otherwise,
  the next template's default size is selected.
- A local image can be applied to the selected template preview.
- Uploaded images remain in the browser and are not sent anywhere.

The eventual data adapter should replace `demoCatalog.ts` without changing the
sidebar or preview component contracts.
