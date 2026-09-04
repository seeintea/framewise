import type { AspectRatio, Point } from '@/types';
import type { ResolvedShape, Shape } from './shape';

export type CompositionElementType = 'subject' | 'horizon' | 'safe-line';

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

export type ResolvedCompositionElement = Omit<CompositionElement, 'shape'> & {
  shape: ResolvedShape;
};

export type ResolvedCompositionTemplateVariant = Omit<
  CompositionTemplateVariant,
  'elements'
> & {
  elements: ResolvedCompositionElement[];
};

export type CompositionPreset = {
  id: string;
  title: string;
  description: string;
  variants: CompositionTemplateVariant[];
};

export type CompositionTemplateDocumentV1 = {
  schemaVersion: 1;
  presets: CompositionPreset[];
};
