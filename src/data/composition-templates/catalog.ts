import type { CompositionTemplateDocumentV1 } from '@/canvas';

import { centeredSubject } from './presets/centered-subject';
import { goldenRatioPortrait } from './presets/golden-ratio-portrait';
import { waterfrontCityscape } from './presets/waterfront-cityscape';

export const templateDocument = {
  schemaVersion: 1,
  presets: [centeredSubject, goldenRatioPortrait, waterfrontCityscape],
} satisfies CompositionTemplateDocumentV1;
