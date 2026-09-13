import type { CSSProperties } from "react";
import type { AspectRatio, WorkbenchTemplate } from "../types";
import { GuideOverlay } from "./GuideOverlay";

type CompositionPreviewProps = {
  template: WorkbenchTemplate;
  aspectRatio: AspectRatio;
  imageUrl: string | null;
};

const orientationWidths = {
  portrait: "w-[86%] max-w-[470px]",
  square: "w-[86%] max-w-[560px]",
  landscape: "w-[92%] max-w-[780px]",
} as const;

export function CompositionPreview({
  template,
  aspectRatio,
  imageUrl,
}: CompositionPreviewProps) {
  const [width, height] = aspectRatio.split(":").map(Number);
  const orientation =
    width === height ? "square" : width > height ? "landscape" : "portrait";
  const stageStyle = {
    aspectRatio: aspectRatio.replace(":", " / "),
    ...(imageUrl ? { backgroundImage: `url("${imageUrl}")` } : {}),
  } as CSSProperties;

  return (
    <div className={`${orientationWidths[orientation]} text-center`}>
      <div
        className="image-stage relative w-full overflow-hidden rounded-lg bg-[#1b211c] bg-cover bg-center shadow-[0_22px_60px_rgba(25,29,23,0.2)]"
        style={stageStyle}
      >
        <div className="demo-scene absolute inset-0 overflow-hidden" aria-hidden="true">
          <span className="demo-sun" />
          <span className="demo-subject" />
          <span className="demo-ground" />
        </div>
        <GuideOverlay guide={template.previewGuide} aspectRatio={aspectRatio} />
      </div>
    </div>
  );
}
