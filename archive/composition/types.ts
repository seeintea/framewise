import type { AspectRatio, Bounds, Point } from '@/types';

export type CompositionElementType = 'subject' | 'horizon' | 'safe-line';

export type LineShape = {
  type: 'line';
  start: Point;
  end: Point;
};

export type DashedLineShape = {
  type: 'dashed-line';
  start: Point;
  end: Point;
};

export type DashedCircleShape = {
  type: 'dashed-circle';
  center: Point;
  radius: number;
};

export type CircleShape = {
  type: 'circle';
  center: Point;
  radius: number;
};

export type RectShape = {
  type: 'rect';
  bounds: Bounds;
  cornerRadius?: number;
};

export type Shape =
  CircleShape | DashedCircleShape | DashedLineShape | LineShape | RectShape;

export type CompositionElement = {
  id: string;
  type: CompositionElementType;
  shape: Shape;
};

export type CompositionAnnotation = {
  id: string;
  text: string;
  position: Point;
  maxWidth?: number;
};

export type CompositionTemplateVariant = {
  id: string;
  aspectRatio: AspectRatio;
  instruction: string;
  defaultFacing: 'back' | 'front';
  elements: CompositionElement[];
  annotations?: CompositionAnnotation[];
};

export type CompositionPreset = {
  id: string;
  title: string;
  description: string;
  origin?: 'ai-generated' | 'human-refined';
  variants: CompositionTemplateVariant[];
};

export type CompositionTemplateDocumentV1 = {
  schemaVersion: 1;
  presets: CompositionPreset[];
};
