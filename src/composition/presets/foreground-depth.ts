import type { CompositionPreset } from '../types';

export const foregroundDepth = {
  id: 'foreground-depth',
  title: '前景纵深',
  description: '适合道路、花田和岸边等具有纹理或引导感的近景。',
  origin: 'ai-generated',
  variants: [
    {
      id: 'foreground-depth-4x3',
      aspectRatio: { width: 4, height: 3 },
      instruction: '将地平线贴合上方三分线，让前景占据约三分之二画面',
      defaultFacing: 'back',
      annotations: [
        {
          id: 'distance-label',
          text: '远景',
          position: { x: 0.5, y: 0.165 },
        },
        {
          id: 'foreground-label',
          text: '前景',
          position: { x: 0.5, y: 0.667 },
        },
      ],
      elements: [
        {
          id: 'high-horizon',
          type: 'horizon',
          shape: {
            type: 'line',
            start: { x: 0, y: 0.333 },
            end: { x: 1, y: 0.333 },
          },
        },
      ],
    },
  ],
} satisfies CompositionPreset;
