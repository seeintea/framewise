import { useEffect, useMemo, useState } from "react";
import { App as AntdApp, ConfigProvider, Tag } from "antd";
import { PreviewWorkspace } from "./components/PreviewWorkspace";
import { TemplateSidebar } from "./components/TemplateSidebar";
import { templateCatalog } from "./templateCatalog";

export function App() {
  const [query, setQuery] = useState("");
  const [selectedTemplateId, setSelectedTemplateId] = useState(
    templateCatalog[0]?.id ?? "",
  );
  const [selectedVariantId, setSelectedVariantId] = useState(
    templateCatalog[0]?.defaultVariantId ?? "",
  );
  const [imageUrl, setImageUrl] = useState<string | null>(null);

  const visibleTemplates = useMemo(() => {
    const normalizedQuery = query.trim().toLocaleLowerCase();
    if (!normalizedQuery) {
      return templateCatalog;
    }

    return templateCatalog.filter((template) =>
      [template.title, template.key, template.id, template.description]
        .join(" ")
        .toLocaleLowerCase()
        .includes(normalizedQuery),
    );
  }, [query]);

  const selectedTemplate =
    templateCatalog.find((template) => template.id === selectedTemplateId) ??
    templateCatalog[0];
  const selectedVariant =
    selectedTemplate?.variants.find(
      (variant) => variant.id === selectedVariantId,
    ) ??
    selectedTemplate?.variants.find(
      (variant) => variant.id === selectedTemplate.defaultVariantId,
    ) ??
    selectedTemplate?.variants[0];

  useEffect(
    () => () => {
      if (imageUrl) {
        URL.revokeObjectURL(imageUrl);
      }
    },
    [imageUrl],
  );

  if (!selectedTemplate || !selectedVariant) {
    return <p className="p-6">没有可预览的模板数据。</p>;
  }

  function selectTemplate(templateId: string) {
    const nextTemplate = templateCatalog.find(
      (template) => template.id === templateId,
    );
    if (!nextTemplate) {
      return;
    }

    setSelectedTemplateId(nextTemplate.id);
    const matchingVariant = nextTemplate.variants.find(
      (variant) =>
        variant.aspectRatio.width === selectedVariant.aspectRatio.width &&
        variant.aspectRatio.height === selectedVariant.aspectRatio.height,
    );
    setSelectedVariantId(matchingVariant?.id ?? nextTemplate.defaultVariantId);
  }

  function selectImage(file: File | null) {
    setImageUrl(file ? URL.createObjectURL(file) : null);
  }

  return (
    <ConfigProvider
      theme={{
        token: {
          colorPrimary: "#1f211d",
          colorText: "#1b1d19",
          colorTextSecondary: "#74786f",
          colorBorder: "#d5d6ce",
          borderRadius: 8,
          fontFamily:
            'Inter, -apple-system, BlinkMacSystemFont, "SF Pro Text", "PingFang SC", sans-serif',
        },
        components: {
          Button: { controlHeight: 36 },
          Input: { controlHeight: 40 },
          Segmented: {
            itemSelectedBg: "#22251f",
            itemSelectedColor: "#f8f8f2",
          },
        },
      }}
    >
      <AntdApp className="h-screen overflow-hidden">
        <div className="grid h-screen grid-rows-[58px_minmax(0,1fr)] overflow-hidden bg-[#f5f5f1] text-[#1b1d19]">
          <header className="flex items-center justify-between gap-6 border-b border-[#d5d6ce] bg-[#fbfbf8] px-5">
            <div className="flex min-w-0 items-center gap-2.5 text-sm">
              <span className="grid size-7 shrink-0 place-items-center rounded-full bg-[#ddec47] font-bold text-[#171916]">
                F
              </span>
              <strong className="font-semibold">Framewise</strong>
              <span className="text-[#74786f] max-sm:hidden">
                / Template Studio
              </span>
            </div>
            <Tag className="m-0 font-mono text-[10px] uppercase tracking-wider max-sm:hidden">
              {templateCatalog.length} templates · composition data
            </Tag>
          </header>

          <main className="grid min-h-0 grid-cols-[300px_minmax(0,1fr)] overflow-hidden max-md:grid-cols-1 max-md:overflow-y-auto">
            <TemplateSidebar
              templates={visibleTemplates}
              selectedTemplateId={selectedTemplate.id}
              query={query}
              onQueryChange={setQuery}
              onSelectTemplate={selectTemplate}
            />
            <PreviewWorkspace
              template={selectedTemplate}
              variant={selectedVariant}
              imageUrl={imageUrl}
              onVariantChange={setSelectedVariantId}
              onImageChange={selectImage}
            />
          </main>
        </div>
      </AntdApp>
    </ConfigProvider>
  );
}
