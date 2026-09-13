import { RightOutlined, SearchOutlined } from "@ant-design/icons";
import { Empty, Input, Typography } from "antd";
import type { WorkbenchTemplate } from "../types";

type TemplateSidebarProps = {
  templates: WorkbenchTemplate[];
  selectedTemplateId: string;
  query: string;
  onQueryChange: (query: string) => void;
  onSelectTemplate: (templateId: string) => void;
};

export function TemplateSidebar({
  templates,
  selectedTemplateId,
  query,
  onQueryChange,
  onSelectTemplate,
}: TemplateSidebarProps) {
  return (
    <aside
      className="flex min-h-0 min-w-0 flex-col overflow-hidden border-r border-[#d5d6ce] bg-[#eeeee8] p-3.5 pt-5 max-md:max-h-[45vh] max-md:border-r-0 max-md:border-b"
      aria-label="模板列表"
    >
      <div className="flex items-baseline justify-between gap-3 px-1.5 pb-4">
        <Typography.Title level={4} className="m-0! text-xl!">
          模板
        </Typography.Title>
        <Typography.Text type="secondary" className="text-[11px]!">
          {templates.length} 个模板
        </Typography.Text>
      </div>

      <Input
        allowClear
        aria-label="搜索模板"
        prefix={<SearchOutlined className="text-[#92968d]" />}
        placeholder="搜索模板"
        value={query}
        onChange={(event) => onQueryChange(event.target.value)}
      />

      <div
        className="mt-3.5 grid min-h-0 flex-1 content-start gap-1 overflow-y-auto scrollbar-gutter-stable max-md:grid-cols-2"
        role="listbox"
        aria-label="全部模板"
      >
        {templates.map((template) => {
          const isSelected = template.id === selectedTemplateId;

          return (
            <button
              className={`grid min-h-14 w-full cursor-pointer grid-cols-[minmax(0,1fr)_auto] items-center gap-2.5 rounded-lg border-0 px-2.5 py-2 text-left transition-colors ${
                isSelected
                  ? "bg-[#fbfbf8] shadow-sm"
                  : "bg-transparent hover:bg-white/50"
              }`}
              type="button"
              role="option"
              aria-selected={isSelected}
              key={template.id}
              onClick={() => onSelectTemplate(template.id)}
            >
              <span className="min-w-0">
                <strong className="block truncate text-[13px] font-semibold">
                  {template.title}
                </strong>
                <small className="mt-1 block truncate text-[10px] text-[#74786f]">
                  {template.key} · {template.variants.length} 个尺寸
                </small>
              </span>
              <RightOutlined className="text-[10px] text-[#92968d]" aria-hidden="true" />
            </button>
          );
        })}
      </div>

      {templates.length === 0 ? (
        <Empty
          className="my-8"
          image={Empty.PRESENTED_IMAGE_SIMPLE}
          description="没有匹配的模板"
        />
      ) : null}

      <Typography.Text
        type="secondary"
        className="px-1.5! pt-4! text-[11px]! leading-relaxed!"
      >
        已连接 composition 数据，图片资源暂未接入。
      </Typography.Text>
    </aside>
  );
}
