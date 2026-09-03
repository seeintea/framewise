import { templateDocument } from './catalog';

export function listPresets() {
  return templateDocument.presets;
}

export function findPresetById(presetId: string) {
  return templateDocument.presets.find((preset) => preset.id === presetId);
}
