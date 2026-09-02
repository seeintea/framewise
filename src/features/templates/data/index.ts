import type { CompositionTemplateDocumentV1 } from '@/canvas';

import { centeredSubject } from './centered-subject';
import { goldenRatioPortrait } from './golden-ratio-portrait';
import { waterfrontCityscape } from './waterfront-cityscape';

export const templateDocument = {
  schemaVersion: 1,
  presets: [centeredSubject, goldenRatioPortrait, waterfrontCityscape],
} satisfies CompositionTemplateDocumentV1;
