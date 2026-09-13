import { DeleteOutlined, UploadOutlined } from "@ant-design/icons";
import { Button, Segmented, Space, Typography, Upload } from "antd";
import type { AspectRatio, WorkbenchTemplate } from "../types";
import { CompositionPreview } from "./CompositionPreview";

type PreviewWorkspaceProps = {
  template: WorkbenchTemplate;
  aspectRatio: AspectRatio;
  imageUrl: string | null;
  onAspectRatioChange: (aspectRatio: AspectRatio) => void;
  onImageChange: (file: File | null) => void;
};

export function PreviewWorkspace({
  template,
  aspectRatio,
  imageUrl,
  onAspectRatioChange,
  onImageChange,
}: PreviewWorkspaceProps) {
  return (
    <section
      className="grid min-w-0 grid-rows-[auto_1fr] bg-[#dfdfd8]"
      aria-label="模板预览工作区"
    >
      <header className="flex min-h-18 items-center justify-between gap-6 border-b border-[#d5d6ce] bg-[#fbfbf8] px-5 py-3 max-lg:flex-col max-lg:items-start">
        <div className="min-w-0">
          <Typography.Title level={5} className="m-0!">
            {template.title}
          </Typography.Title>
          <Typography.Text
            type="secondary"
            className="mt-1 block max-w-115 truncate text-[11px]!"
          >
            {template.description}
          </Typography.Text>
        </div>

        <div className="flex flex-wrap items-center justify-end gap-3 max-lg:w-full max-lg:justify-start">
          <Space size={8}>
            <Typography.Text type="secondary" className="text-[11px]!">
              尺寸
            </Typography.Text>
            <Segmented
              aria-label="当前模板尺寸"
              options={template.availableSizes}
              value={aspectRatio}
              onChange={(value) => onAspectRatioChange(value as AspectRatio)}
              size="large"
            />
          </Space>

          <Space.Compact>
            <Upload
              accept="image/*"
              beforeUpload={(file) => {
                onImageChange(file);
                return false;
              }}
              maxCount={1}
              showUploadList={false}
            >
              <Button icon={<UploadOutlined />}>
                {imageUrl ? "替换图片" : "套入图片"}
              </Button>
            </Upload>
            {imageUrl ? (
              <Button
                aria-label="移除当前图片"
                icon={<DeleteOutlined />}
                onClick={() => onImageChange(null)}
              />
            ) : null}
          </Space.Compact>
        </div>
      </header>

      <div className="preview-surface grid min-h-140 place-items-center p-8 max-md:min-h-120 max-md:p-4">
        <div className="grid w-full place-items-center">
          <CompositionPreview
            template={template}
            aspectRatio={aspectRatio}
            imageUrl={imageUrl}
          />
          <Typography.Text
            type="secondary"
            className="mt-3.5! font-mono! text-[11px]!"
          >
            当前 UI 演示：{template.id}-{aspectRatio.replace(":", "x")}
          </Typography.Text>
        </div>
      </div>
    </section>
  );
}
