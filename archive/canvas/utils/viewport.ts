import { Dimensions } from 'react-native';

import type { AspectRatio, Size } from '@/types';

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

export function getMaxReferenceWidth(
  availableSize: Size,
  aspectRatio: AspectRatio,
): number {
  const widthScale =
    aspectRatio.width <= aspectRatio.height
      ? 1
      : aspectRatio.width / aspectRatio.height;
  const heightScale =
    aspectRatio.width <= aspectRatio.height
      ? aspectRatio.height / aspectRatio.width
      : 1;

  return Math.floor(
    Math.min(
      availableSize.width / widthScale,
      availableSize.height / heightScale,
    ),
  );
}
