import { CircleShapeNode } from './CircleShapeNode';
import { DashedCircleShapeNode } from './DashedCircleShapeNode';
import { DashedLineShapeNode } from './DashedLineShapeNode';
import { LineShapeNode } from './LineShapeNode';
import { RectShapeNode } from './RectShapeNode';

import type { ResolvedShape } from '@/canvas/types/shape';

type ShapeNodeProps = {
  shape: ResolvedShape;
};

export function ShapeNode({ shape }: ShapeNodeProps) {
  switch (shape.type) {
    case 'circle':
      return <CircleShapeNode shape={shape} />;
    case 'dashed-circle':
      return <DashedCircleShapeNode shape={shape} />;
    case 'dashed-line':
      return <DashedLineShapeNode shape={shape} />;
    case 'line':
      return <LineShapeNode shape={shape} />;
    case 'rect':
      return <RectShapeNode shape={shape} />;
  }
}
