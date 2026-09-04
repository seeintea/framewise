import type { CompositionTemplateDocumentV1 } from '@/canvas';

import { classicRuleOfThirds } from './presets/classic-rule-of-thirds';
import { centeredSubject } from './presets/centered-subject';
import { cityWaterfrontReflection } from './presets/city-waterfront-reflection';
import { environmentalPortrait } from './presets/environmental-portrait';
import { foregroundDepth } from './presets/foreground-depth';
import { gazeSpace } from './presets/gaze-space';
import { goldenRatioPortrait } from './presets/golden-ratio-portrait';
import { landscapeAccent } from './presets/landscape-accent';
import { leadingLinesDepth } from './presets/leading-lines-depth';
import { modernArchitectureCorner } from './presets/modern-architecture-corner';
import { skyDominantLandscape } from './presets/sky-dominant-landscape';
import { symmetricalComposition } from './presets/symmetrical-composition';
import { waterReflection } from './presets/water-reflection';
import { waterfrontCityscape } from './presets/waterfront-cityscape';

export const templateDocument = {
  schemaVersion: 1,
  presets: [
    classicRuleOfThirds,
    environmentalPortrait,
    gazeSpace,
    skyDominantLandscape,
    foregroundDepth,
    landscapeAccent,
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
