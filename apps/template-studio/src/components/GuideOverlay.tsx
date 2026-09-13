import {
  formatAspectRatio,
  type CompositionElement,
  type WorkbenchVariant,
} from "../types";

type GuideOverlayProps = {
  variant: WorkbenchVariant;
};

type CanvasDimensions = {
  width: number;
  height: number;
  shortSide: number;
};

function dimensions(variant: WorkbenchVariant): CanvasDimensions {
  const width = 300;
  const height =
    (width * variant.aspectRatio.height) / variant.aspectRatio.width;

  return { width, height, shortSide: Math.min(width, height) };
}

function renderElement(
  element: CompositionElement,
  { width, height, shortSide }: CanvasDimensions,
) {
  const { shape } = element;
  const strokeDasharray = shape.type.startsWith("dashed-") ? "7 5" : undefined;

  switch (shape.type) {
    case "line":
    case "dashed-line":
      return (
        <line
          key={element.key}
          x1={shape.start.x * width}
          y1={shape.start.y * height}
          x2={shape.end.x * width}
          y2={shape.end.y * height}
          strokeDasharray={strokeDasharray}
        />
      );
    case "circle":
    case "dashed-circle":
      return (
        <circle
          key={element.key}
          cx={shape.center.x * width}
          cy={shape.center.y * height}
          r={shape.radius * shortSide}
          strokeDasharray={strokeDasharray}
        />
      );
    case "rect":
      return (
        <rect
          key={element.key}
          x={shape.bounds.x * width}
          y={shape.bounds.y * height}
          width={shape.bounds.width * width}
          height={shape.bounds.height * height}
          rx={(shape.cornerRadius ?? 0) * shortSide}
        />
      );
  }
}

export function GuideOverlay({ variant }: GuideOverlayProps) {
  const canvas = dimensions(variant);

  return (
    <svg
      className="guide-overlay"
      viewBox={`0 0 ${canvas.width} ${canvas.height}`}
      role="img"
      aria-label={`${formatAspectRatio(variant.aspectRatio)} 构图线预览`}
    >
      {variant.elements.map((element) => renderElement(element, canvas))}
      {variant.annotations.map((annotation) => (
        <text
          key={annotation.key}
          x={annotation.position.x * canvas.width}
          y={annotation.position.y * canvas.height}
          fill="#ffd60a"
          stroke="none"
          fontSize={Math.max(canvas.shortSide * 0.035, 7)}
          fontWeight="600"
          textAnchor="middle"
          dominantBaseline="middle"
        >
          {annotation.text}
        </text>
      ))}
    </svg>
  );
}
