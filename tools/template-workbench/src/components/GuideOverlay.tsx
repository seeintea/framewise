import type { AspectRatio, PreviewGuide } from "../types";

type GuideOverlayProps = {
  guide: PreviewGuide;
  aspectRatio: AspectRatio;
};

function dimensions(aspectRatio: AspectRatio) {
  const [widthPart, heightPart] = aspectRatio.split(":").map(Number);
  const width = 300;
  const height = (width * heightPart) / widthPart;

  return { width, height, shortSide: Math.min(width, height) };
}

export function GuideOverlay({ guide, aspectRatio }: GuideOverlayProps) {
  const { width, height, shortSide } = dimensions(aspectRatio);

  return (
    <svg
      className="guide-overlay"
      viewBox={`0 0 ${width} ${height}`}
      role="img"
      aria-label={`${aspectRatio} 构图线预览`}
    >
      {guide === "centered" ? (
        <circle
          cx={width * 0.5}
          cy={height * 0.475}
          r={shortSide * 0.19}
          strokeDasharray="7 5"
        />
      ) : null}

      {guide === "portrait" ? (
        <>
          <circle
            cx={width * 0.667}
            cy={height * 0.3}
            r={shortSide * 0.05}
            strokeDasharray="6 5"
          />
          <line
            x1={width * 0.667}
            y1={height * 0.35}
            x2={width * 0.667}
            y2={height * 0.9}
            strokeDasharray="8 6"
          />
        </>
      ) : null}

      {guide === "thirds" ? (
        <>
          <line x1={width / 3} y1="0" x2={width / 3} y2={height} />
          <line x1={(width * 2) / 3} y1="0" x2={(width * 2) / 3} y2={height} />
          <line x1="0" y1={height / 3} x2={width} y2={height / 3} />
          <line x1="0" y1={(height * 2) / 3} x2={width} y2={(height * 2) / 3} />
        </>
      ) : null}

      {guide === "gaze" ? (
        <>
          <circle
            cx={width / 3}
            cy={height * 0.42}
            r={shortSide * 0.07}
            strokeDasharray="6 5"
          />
          <line
            x1={width * 0.4}
            y1={height * 0.42}
            x2={width * 0.9}
            y2={height * 0.42}
            strokeDasharray="8 6"
          />
        </>
      ) : null}

      {guide === "waterfront" ? (
        <>
          <line x1="0" y1={height * 0.38} x2={width} y2={height * 0.38} />
          <line x1="0" y1={height * 0.67} x2={width} y2={height * 0.67} />
        </>
      ) : null}

      {guide === "depth" ? (
        <>
          <line x1="0" y1={height} x2={width * 0.5} y2={height * 0.45} />
          <line x1={width} y1={height} x2={width * 0.5} y2={height * 0.45} />
          <circle cx={width * 0.5} cy={height * 0.45} r={shortSide * 0.025} />
        </>
      ) : null}
    </svg>
  );
}
