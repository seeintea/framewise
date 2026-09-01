import { Line } from '@shopify/react-native-skia';

import type { ResolvedLineShape } from '@/canvas/types/shape';

type LineShapeNodeProps = {
  shape: ResolvedLineShape;
};

export function LineShapeNode({ shape }: LineShapeNodeProps) {
  return <Line p1={shape.start} p2={shape.end} />;
}
