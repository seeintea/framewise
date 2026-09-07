import { Circle } from '@shopify/react-native-skia';

import type { ResolvedCircleShape } from '@/canvas/types/shape';

type CircleShapeNodeProps = {
  shape: ResolvedCircleShape;
};

export function CircleShapeNode({ shape }: CircleShapeNodeProps) {
  return <Circle c={shape.center} r={shape.radius} />;
}
