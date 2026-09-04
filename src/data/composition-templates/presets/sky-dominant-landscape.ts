import type { CompositionPreset } from '@/canvas';

export const skyDominantLandscape = {
  id: 'sky-dominant-landscape',
  title: '天空主导',
  description: '适合云层、晚霞和辽阔天空，让天空成为画面的主要内容。',
  origin: 'ai-generated',
  variants: [
    {
      id: 'sky-dominant-landscape-4x3',
      aspectRatio: { width: 4, height: 3 },
      instruction: '将地平线贴合下方三分线，为天空保留约三分之二画面',
      defaultFacing: 'back',
      annotations: [
        {
          id: 'sky-label',
          text: '天空',
          position: { x: 0.5, y: 0.333 },
        },
        {
          id: 'ground-label',
          text: '地景',
          position: { x: 0.5, y: 0.835 },
        },
      ],
      elements: [
        {
          id: 'low-horizon',
          type: 'horizon',
          shape: {
            type: 'line',
            start: { x: 0, y: 0.667 },
            end: { x: 1, y: 0.667 },
          },
        },
      ],
    },
  ],
} satisfies CompositionPreset;
