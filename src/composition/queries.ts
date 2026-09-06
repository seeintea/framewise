import type { CompositionPreset } from './types';

import { templateDocument } from './catalog';

export function listPresets(): CompositionPreset[] {
  return templateDocument.presets;
}

export function findPresetById(
  presetId: string,
): CompositionPreset | undefined {
  return templateDocument.presets.find((preset) => preset.id === presetId);
}
