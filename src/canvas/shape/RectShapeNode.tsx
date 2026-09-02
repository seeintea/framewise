import { RoundedRect } from '@shopify/react-native-skia';

import type { ResolvedRectShape } from '@/canvas/types/shape';

type RectShapeNodeProps = {
  shape: ResolvedRectShape;
};

export function RectShapeNode({ shape }: RectShapeNodeProps) {
  const { x, y, width, height } = shape.bounds;

  return (
    <RoundedRect
      height={height}
      r={shape.cornerRadius}
      width={width}
      x={x}
      y={y}
    />
  );
}
