import { Dimensions } from 'react-native';

import type { AspectRatio } from '@/types/aspect-ratio';
import type { Size } from '@/types/geometry';

function getWindowShortSide(): number {
  const { width, height } = Dimensions.get('window');

  return Math.min(width, height);
}

export function getViewportSize(
  aspectRatio: AspectRatio,
  shortSide?: number,
): Size {
  const base = Math.round(shortSide ?? getWindowShortSide());

  if (aspectRatio.width <= aspectRatio.height) {
    return {
      width: base,
      height: Math.round((base * aspectRatio.height) / aspectRatio.width),
    };
  }

  return {
    width: Math.round((base * aspectRatio.width) / aspectRatio.height),
    height: base,
  };
}
