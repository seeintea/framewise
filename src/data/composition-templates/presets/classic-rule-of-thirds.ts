import type { CompositionPreset } from '@/canvas';

export const classicRuleOfThirds = {
  id: 'classic-rule-of-thirds',
  title: '经典三分法',
  description: '适合带有环境空间的人像，让人物与背景形成自然平衡。',
  variants: [
    {
      id: 'classic-rule-of-thirds-3x4',
      aspectRatio: { width: 3, height: 4 },
      instruction: '将主体放在九宫格交点附近，并沿三分线安排画面',
      defaultFacing: 'back',
      elements: [
        {
          id: 'left-third-line',
          type: 'safe-line',
          shape: {
            type: 'line',
            start: { x: 0.333, y: 0 },
            end: { x: 0.333, y: 1 },
          },
        },
        {
          id: 'right-third-line',
          type: 'safe-line',
          shape: {
            type: 'line',
            start: { x: 0.667, y: 0 },
            end: { x: 0.667, y: 1 },
          },
        },
        {
          id: 'top-third-line',
          type: 'safe-line',
          shape: {
            type: 'line',
            start: { x: 0, y: 0.333 },
            end: { x: 1, y: 0.333 },
          },
        },
        {
          id: 'bottom-third-line',
          type: 'safe-line',
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
