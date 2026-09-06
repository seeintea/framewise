import type {
  CompositionElement,
  CompositionTemplateVariant,
} from '@/composition';
import type { ResolvedShape } from './shape';

export type ResolvedCompositionElement = Omit<CompositionElement, 'shape'> & {
  shape: ResolvedShape;
};

export type ResolvedCompositionTemplateVariant = Omit<
  CompositionTemplateVariant,
  'elements'
> & {
  elements: ResolvedCompositionElement[];
};
