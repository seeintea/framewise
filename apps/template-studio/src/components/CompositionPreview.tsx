import type { CSSProperties } from "react";
import type { WorkbenchVariant } from "../types";
import { GuideOverlay } from "./GuideOverlay";

type CompositionPreviewProps = {
  variant: WorkbenchVariant;
  imageUrl: string | null;
};

const orientationWidths = {
  portrait: "w-[86%] max-w-[470px]",
  square: "w-[86%] max-w-[560px]",
  landscape: "w-[92%] max-w-[780px]",
} as const;

export function CompositionPreview({
  variant,
  imageUrl,
}: CompositionPreviewProps) {
  const { width, height } = variant.aspectRatio;
  const orientation =
    width === height ? "square" : width > height ? "landscape" : "portrait";
  const stageStyle = {
    aspectRatio: `${width} / ${height}`,
    ...(imageUrl ? { backgroundImage: `url("${imageUrl}")` } : {}),
  } as CSSProperties;

  return (
    <div className={`${orientationWidths[orientation]} text-center`}>
      <div
        className="image-stage relative w-full overflow-hidden rounded-lg bg-black bg-cover bg-center shadow-[0_22px_60px_rgba(25,29,23,0.2)]"
        style={stageStyle}
      >
        <GuideOverlay variant={variant} />
      </div>
    </div>
  );
}
