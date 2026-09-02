import type {
  CompositionTemplateVariant,
  ResolvedCompositionTemplateVariant,
} from '@/canvas/types';
import type { ResolvedShape, Shape } from '@/canvas/types/shape';
import type { Point, Size } from '@/types';

function resolvePoint(point: Point, size: Size): Point {
  return {
    x: Math.round(point.x * size.width),
    y: Math.round(point.y * size.height),
  };
}

function resolveShape(shape: Shape, size: Size): ResolvedShape {
  switch (shape.type) {
    case 'line':
      return {
        type: shape.type,
        start: resolvePoint(shape.start, size),
        end: resolvePoint(shape.end, size),
      };
  }
}

export function resolveTemplate(
  template: CompositionTemplateVariant,
  size: Size,
): ResolvedCompositionTemplateVariant {
  return {
    ...template,
    elements: template.elements.map((element) => ({
      ...element,
      shape: resolveShape(element.shape, size),
    })),
  };
}
