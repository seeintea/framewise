import type {
  CompositionTemplateVariant,
  ResolvedCompositionTemplateVariant,
} from '@/canvas/types';
import type { ResolvedShape, Shape } from '@/canvas/types/shape';
import type { Bounds, Point, Size } from '@/types';

function resolvePoint(point: Point, size: Size): Point {
  return {
    x: Math.round(point.x * size.width),
    y: Math.round(point.y * size.height),
  };
}

function resolveBounds(bounds: Bounds, size: Size): Bounds {
  return {
    x: Math.round(bounds.x * size.width),
    y: Math.round(bounds.y * size.height),
    width: Math.round(bounds.width * size.width),
    height: Math.round(bounds.height * size.height),
  };
}

function resolveShape(shape: Shape, size: Size): ResolvedShape {
  switch (shape.type) {
    case 'circle':
      return {
        type: shape.type,
        center: resolvePoint(shape.center, size),
        radius: Math.round(shape.radius * Math.min(size.width, size.height)),
      };
    case 'line':
      return {
        type: shape.type,
        start: resolvePoint(shape.start, size),
        end: resolvePoint(shape.end, size),
      };
    case 'rect':
      return {
        type: shape.type,
        bounds: resolveBounds(shape.bounds, size),
        cornerRadius: Math.round(
          (shape.cornerRadius ?? 0) * Math.min(size.width, size.height),
        ),
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
