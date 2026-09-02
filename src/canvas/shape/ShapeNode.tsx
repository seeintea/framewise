import { CircleShapeNode } from './CircleShapeNode';
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
    case 'line':
      return <LineShapeNode shape={shape} />;
    case 'rect':
      return <RectShapeNode shape={shape} />;
  }
}
