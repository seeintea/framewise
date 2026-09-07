import { DashPathEffect, Line } from '@shopify/react-native-skia';

import type { ResolvedDashedLineShape } from '@/canvas/types/shape';

import { DASH_INTERVALS } from './dash-intervals';

type DashedLineShapeNodeProps = {
  shape: ResolvedDashedLineShape;
};

export function DashedLineShapeNode({ shape }: DashedLineShapeNodeProps) {
  return (
    <Line p1={shape.start} p2={shape.end}>
      <DashPathEffect intervals={DASH_INTERVALS} />
    </Line>
  );
}
