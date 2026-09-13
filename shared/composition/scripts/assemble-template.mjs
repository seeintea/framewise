import { readFileSync, readdirSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

const scriptDirectory = dirname(fileURLToPath(import.meta.url));
const compositionDirectory = resolve(scriptDirectory, "..");
const supportedAspectRatios = new Set(["3:4", "4:3", "9:16", "16:9", "1:1"]);

function readJson(path) {
  return JSON.parse(readFileSync(path, "utf8"));
}

function assert(condition, message) {
  if (!condition) {
    throw new Error(message);
  }
}

function assertUnique(values, label) {
  assert(new Set(values).size === values.length, `${label} must be unique`);
}

function sortedJson(value) {
  if (Array.isArray(value)) {
    return value.map(sortedJson);
  }

  if (value && typeof value === "object") {
    return Object.fromEntries(
      Object.entries(value)
        .sort(([left], [right]) => left.localeCompare(right))
        .map(([key, child]) => [key, sortedJson(child)]),
    );
  }

  return value;
}

function validateVariant(template, variant) {
  assert(variant.schemaVersion === template.schemaVersion, `${variant.id}: schemaVersion mismatch`);
  assert(template.variantIds.includes(variant.id), `${variant.id}: not declared by template`);
  assert(variant.id.startsWith(`${template.id}-`), `${variant.id}: must use the template id prefix`);

  const ratio = `${variant.aspectRatio?.width}:${variant.aspectRatio?.height}`;
  assert(supportedAspectRatios.has(ratio), `${variant.id}: unsupported aspect ratio ${ratio}`);
  assert(Array.isArray(variant.elements) && variant.elements.length > 0, `${variant.id}: elements are required`);

  const elementIds = variant.elements.map((element) => element.id);
  const annotationIds = (variant.annotations ?? []).map((annotation) => annotation.id);
  assertUnique(elementIds, `${variant.id}: element ids`);
  assertUnique(annotationIds, `${variant.id}: annotation ids`);
}

function validateLocalization(template, variants, localization, locale) {
  assert(localization.schemaVersion === template.schemaVersion, `${locale}: schemaVersion mismatch`);
  assert(localization.locale === locale, `${locale}: locale does not match the filename`);
  assert(localization.templateId === template.id, `${locale}: templateId mismatch`);
  assert(typeof localization.title === "string" && localization.title.length > 0, `${locale}: title is required`);
  assert(
    typeof localization.description === "string" && localization.description.length > 0,
    `${locale}: description is required`,
  );

  const localizedVariantIds = Object.keys(localization.variants ?? {});
  assertUnique(localizedVariantIds, `${locale}: localized variant ids`);
  assert(
    JSON.stringify([...localizedVariantIds].sort()) === JSON.stringify([...template.variantIds].sort()),
    `${locale}: localized variants must exactly match template.variantIds`,
  );

  for (const variant of variants) {
    const copy = localization.variants[variant.id];
    assert(typeof copy.instruction === "string" && copy.instruction.length > 0, `${variant.id}: instruction is required`);

    const anchorIds = (variant.annotations ?? []).map((annotation) => annotation.id).sort();
    const copyIds = Object.keys(copy.annotations ?? {}).sort();
    assert(
      JSON.stringify(anchorIds) === JSON.stringify(copyIds),
      `${variant.id}: localized annotations must exactly match geometry anchors`,
    );
  }
}

export function assembleTemplate(templateId, locale = "zh-Hans") {
  const templateDirectory = join(compositionDirectory, "templates", templateId);
  const template = readJson(join(templateDirectory, "template.json"));

  assert(template.schemaVersion === 1, `${templateId}: unsupported schemaVersion`);
  assert(template.id === templateId, `${templateId}: directory and template id must match`);
  assert(Number.isInteger(template.revision) && template.revision > 0, `${templateId}: revision must be positive`);
  assert(Array.isArray(template.variantIds) && template.variantIds.length > 0, `${templateId}: variantIds are required`);
  assertUnique(template.variantIds, `${templateId}: variantIds`);
  assert(template.variantIds.includes(template.defaultVariantId), `${templateId}: defaultVariantId must exist`);

  const variantsById = new Map(
    readdirSync(join(templateDirectory, "variants"))
      .filter((name) => name.endsWith(".json"))
      .map((name) => readJson(join(templateDirectory, "variants", name)))
      .map((variant) => [variant.id, variant]),
  );

  assert(variantsById.size === template.variantIds.length, `${templateId}: variant files must exactly match variantIds`);
  const variants = template.variantIds.map((variantId) => {
    const variant = variantsById.get(variantId);
    assert(variant, `${templateId}: missing variant file for ${variantId}`);
    validateVariant(template, variant);
    return variant;
  });

  const localization = readJson(join(templateDirectory, "locales", `${locale}.json`));
  validateLocalization(template, variants, localization, locale);

  return {
    schemaVersion: template.schemaVersion,
    id: template.id,
    revision: template.revision,
    locale,
    title: localization.title,
    description: localization.description,
    defaultVariantId: template.defaultVariantId,
    variants: variants.map(({ schemaVersion: _schemaVersion, ...variant }) => {
      const copy = localization.variants[variant.id];

      return {
        id: variant.id,
        aspectRatio: variant.aspectRatio,
        instruction: copy.instruction,
        elements: variant.elements,
        annotations: (variant.annotations ?? []).map((annotation) => ({
          ...annotation,
          text: copy.annotations[annotation.id],
        })),
      };
    }),
  };
}

export function assertMatchesLegacy(assembledTemplate) {
  const definitions = readJson(join(compositionDirectory, "templates.v1.json"));
  const descriptions = readJson(
    join(compositionDirectory, "descriptions", `${assembledTemplate.locale}.v1.json`),
  );
  const definition = definitions.templates.find(({ id }) => id === assembledTemplate.id);
  const description = descriptions.templates.find(({ id }) => id === assembledTemplate.id);

  assert(definition, `${assembledTemplate.id}: missing from legacy definitions`);
  assert(description, `${assembledTemplate.id}: missing from legacy descriptions`);

  const descriptionByVariantId = new Map(
    description.variants.map((variant) => [variant.id, variant]),
  );
  const expected = {
    id: definition.id,
    title: description.title,
    description: description.description,
    variants: definition.variants.map((variant) => {
      const copy = descriptionByVariantId.get(variant.id);
      assert(copy, `${variant.id}: missing from legacy descriptions`);
      const textByAnnotationId = new Map(
        (copy.annotations ?? []).map((annotation) => [annotation.id, annotation.text]),
      );

      return {
        id: variant.id,
        aspectRatio: variant.aspectRatio,
        instruction: copy.instruction,
        elements: variant.elements,
        annotations: (variant.annotations ?? []).map((annotation) => ({
          ...annotation,
          text: textByAnnotationId.get(annotation.id),
        })),
      };
    }),
  };
  const actual = {
    id: assembledTemplate.id,
    title: assembledTemplate.title,
    description: assembledTemplate.description,
    variants: assembledTemplate.variants,
  };

  assert(
    JSON.stringify(sortedJson(actual)) === JSON.stringify(sortedJson(expected)),
    `${assembledTemplate.id}: package output differs from legacy data`,
  );
}

const isMainModule =
  process.argv[1] && pathToFileURL(resolve(process.argv[1])).href === import.meta.url;

if (isMainModule) {
  const [templateId = "centered-subject", locale = "zh-Hans", ...options] =
    process.argv.slice(2);

  try {
    const assembledTemplate = assembleTemplate(templateId, locale);

    if (options.includes("--check-legacy")) {
      assertMatchesLegacy(assembledTemplate);
      console.log(`${templateId} (${locale}) matches the legacy documents.`);
    } else {
      console.log(JSON.stringify(assembledTemplate, null, 2));
    }
  } catch (error) {
    console.error(error instanceof Error ? error.message : error);
    process.exitCode = 1;
  }
}
