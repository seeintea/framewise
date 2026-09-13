export type AspectRatio = {
  width: 1 | 3 | 4 | 9 | 16;
  height: 1 | 3 | 4 | 9 | 16;
};

export type Point = {
  x: number;
  y: number;
};

export type Bounds = Point & {
  width: number;
  height: number;
};

export type LineShape = {
  type: "line" | "dashed-line";
  start: Point;
  end: Point;
};

export type CircleShape = {
  type: "circle" | "dashed-circle";
  center: Point;
  radius: number;
};

export type RectShape = {
  type: "rect";
  bounds: Bounds;
  cornerRadius?: number;
};

export type CompositionShape = LineShape | CircleShape | RectShape;

export type CompositionElement = {
  key: string;
  type: "subject" | "horizon" | "safe-line";
  shape: CompositionShape;
};

export type AnnotationAnchor = {
  key: string;
  position: Point;
  maxWidth?: number;
};

export type TemplateVariantV1 = {
  id: string;
  key: string;
  aspectRatio: AspectRatio;
  elements: CompositionElement[];
  annotations?: AnnotationAnchor[];
};

export type TemplateDefinitionV1 = {
  schemaVersion: 1;
  id: string;
  key: string;
  defaultVariantId: string;
  variants: TemplateVariantV1[];
};

export type VariantLocalizationV1 = {
  variantId: string;
  instruction: string;
  annotations?: Record<string, string>;
};

export type TemplateLocalizationV1 = {
  schemaVersion: 1;
  locale: string;
  templateId: string;
  title: string;
  description: string;
  variants: VariantLocalizationV1[];
};

export type WorkbenchAnnotation = AnnotationAnchor & {
  text: string;
};

export type WorkbenchVariant = Omit<TemplateVariantV1, "annotations"> & {
  instruction: string;
  annotations: WorkbenchAnnotation[];
};

export type WorkbenchTemplate = {
  id: string;
  key: string;
  title: string;
  description: string;
  defaultVariantId: string;
  variants: WorkbenchVariant[];
};

export function formatAspectRatio(aspectRatio: AspectRatio) {
  return `${aspectRatio.width}:${aspectRatio.height}`;
}
