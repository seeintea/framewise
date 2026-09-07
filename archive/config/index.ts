import type { AspectRatio } from '@/types';

export const ASPECT_RATIOS = {
  portrait: [
    { width: 3, height: 4 },
    { width: 9, height: 16 },
    { width: 1, height: 1 },
  ],
  landscape: [
    { width: 4, height: 3 },
    { width: 16, height: 9 },
    { width: 1, height: 1 },
  ],
} as const satisfies Record<'portrait' | 'landscape', readonly AspectRatio[]>;
