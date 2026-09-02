import { Group, Canvas as SkiaCanvas } from '@shopify/react-native-skia';

import { ShapeNode } from '@/canvas/shape/ShapeNode';
import type { CompositionTemplateVariant } from '@/canvas/types';
import { resolveTemplate } from '@/canvas/utils/resolve-template';
import type { Size } from '@/types';

const GUIDE_COLOR = '#FFD400';
const GUIDE_STROKE_WIDTH = 0.5;

export type CanvasProps = {
  variant: CompositionTemplateVariant;
  viewportSize: Size;
};

export default function Canvas({ variant, viewportSize }: CanvasProps) {
  const resolvedTemplate = resolveTemplate(variant, viewportSize);

  return (
    <SkiaCanvas
      style={{
        width: viewportSize.width,
        height: viewportSize.height,
      }}
      pointerEvents="none"
    >
      <Group
        color={GUIDE_COLOR}
        style="stroke"
        strokeWidth={GUIDE_STROKE_WIDTH}
        strokeCap="round"
        strokeJoin="round"
        antiAlias
      >
        {resolvedTemplate.elements.map((element) => (
          <ShapeNode key={element.id} shape={element.shape} />
        ))}
      </Group>
    </SkiaCanvas>
  );
}
