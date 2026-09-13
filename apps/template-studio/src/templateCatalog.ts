import type {
  TemplateDefinitionV1,
  TemplateLocalizationV1,
  WorkbenchTemplate,
} from "./types";

const definitionModules = import.meta.glob<TemplateDefinitionV1>(
  "../../../composition/templates/*/template.v1.json",
  { eager: true, import: "default" },
);
const localizationModules = import.meta.glob<TemplateLocalizationV1>(
  "../../../composition/templates/*/zh-Hans.v1.json",
  { eager: true, import: "default" },
);

function templateKeyFromPath(path: string) {
  const match = path.match(/\/templates\/([^/]+)\//);

  if (!match) {
    throw new Error(`无法从路径识别模板：${path}`);
  }

  return match[1];
}

const localizationByKey = new Map(
  Object.entries(localizationModules).map(([path, localization]) => [
    templateKeyFromPath(path),
    localization,
  ]),
);

export const templateCatalog: WorkbenchTemplate[] = Object.entries(
  definitionModules,
)
  .map(([path, definition]) => {
    const directoryKey = templateKeyFromPath(path);
    const localization = localizationByKey.get(directoryKey);

    if (!localization) {
      throw new Error(`${directoryKey} 缺少 zh-Hans 文案`);
    }
    if (definition.key !== directoryKey) {
      throw new Error(`${directoryKey} 的目录名与模板 key 不一致`);
    }
    if (localization.templateId !== definition.id) {
      throw new Error(`${directoryKey} 的结构与文案 templateId 不一致`);
    }

    const copyByVariantId = new Map(
      localization.variants.map((variant) => [variant.variantId, variant]),
    );
    if (copyByVariantId.size !== definition.variants.length) {
      throw new Error(`${directoryKey} 的结构与文案 variant 数量不一致`);
    }
    const variants = definition.variants.map((variant) => {
      const copy = copyByVariantId.get(variant.id);

      if (!copy) {
        throw new Error(`${variant.key} 缺少 zh-Hans 文案`);
      }

      return {
        ...variant,
        instruction: copy.instruction,
        annotations: (variant.annotations ?? []).map((annotation) => {
          const text = copy.annotations?.[annotation.key];

          if (!text) {
            throw new Error(`${variant.key} 的 ${annotation.key} 缺少文案`);
          }

          return { ...annotation, text };
        }),
      };
    });

    if (!variants.some((variant) => variant.id === definition.defaultVariantId)) {
      throw new Error(`${directoryKey} 的 defaultVariantId 不存在`);
    }

    return {
      id: definition.id,
      key: definition.key,
      title: localization.title,
      description: localization.description,
      defaultVariantId: definition.defaultVariantId,
      variants,
    };
  })
  .sort((left, right) => left.key.localeCompare(right.key));

if (templateCatalog.length !== Object.keys(localizationModules).length) {
  throw new Error("模板结构文件与 zh-Hans 文案文件数量不一致");
}
