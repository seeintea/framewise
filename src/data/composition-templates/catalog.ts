import type { CompositionTemplateDocumentV1 } from '@/canvas';

import { classicRuleOfThirds } from './presets/classic-rule-of-thirds';
import { centeredSubject } from './presets/centered-subject';
import { cityWaterfrontReflection } from './presets/city-waterfront-reflection';
import { goldenRatioPortrait } from './presets/golden-ratio-portrait';
import { leadingLinesDepth } from './presets/leading-lines-depth';
import { modernArchitectureCorner } from './presets/modern-architecture-corner';
import { symmetricalComposition } from './presets/symmetrical-composition';
import { waterReflection } from './presets/water-reflection';
import { waterfrontCityscape } from './presets/waterfront-cityscape';

export const templateDocument = {
  schemaVersion: 1,
  presets: [
    classicRuleOfThirds,
    centeredSubject,
    cityWaterfrontReflection,
    goldenRatioPortrait,
    leadingLinesDepth,
    modernArchitectureCorner,
    symmetricalComposition,
    waterfrontCityscape,
    waterReflection,
  ],
} satisfies CompositionTemplateDocumentV1;
