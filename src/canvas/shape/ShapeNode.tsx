import { LineShapeNode } from './LineShapeNode';

import type { ResolvedShape } from '@/canvas/types/shape';

type ShapeNodeProps = {
  shape: ResolvedShape;
};

export function ShapeNode({ shape }: ShapeNodeProps) {
  switch (shape.type) {
    case 'line':
      return <LineShapeNode shape={shape} />;
  }
}
