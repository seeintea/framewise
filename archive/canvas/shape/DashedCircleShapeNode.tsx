import { Circle, DashPathEffect } from '@shopify/react-native-skia';

import type { ResolvedDashedCircleShape } from '@/canvas/types/shape';

import { DASH_INTERVALS } from './dash-intervals';

type DashedCircleShapeNodeProps = {
  shape: ResolvedDashedCircleShape;
};

export function DashedCircleShapeNode({ shape }: DashedCircleShapeNodeProps) {
  return (
    <Circle c={shape.center} r={shape.radius}>
      <DashPathEffect intervals={DASH_INTERVALS} />
    </Circle>
  );
}
