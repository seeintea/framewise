import type { CompositionPreset } from '@/canvas';

export const waterfrontCityscape = {
  id: 'waterfront-cityscape',
  title: '滨水城市',
  description:
    '适合拍摄天空、建筑与水面共同构成的现代滨水城市景观，也适用于远山、低山与湖面的组合。',
  variants: [
    {
      id: 'waterfront-cityscape-16x9',
      aspectRatio: { width: 16, height: 9 },
      instruction: '将建筑控制在两条线之间，为天空和水面保留空间',
      defaultFacing: 'back',
      elements: [
        {
          id: 'skyline-limit',
          type: 'safe-line',
          shape: {
            type: 'line',
            start: { x: 0, y: 0.42 },
            end: { x: 1, y: 0.42 },
          },
        },
        {
          id: 'waterline',
          type: 'horizon',
          shape: {
            type: 'line',
            start: { x: 0, y: 0.68 },
            end: { x: 1, y: 0.68 },
          },
        },
      ],
    },
    {
      id: 'waterfront-cityscape-4x3',
      aspectRatio: { width: 4, height: 3 },
      instruction: '将建筑控制在两条线之间，为天空和水面保留空间',
      defaultFacing: 'back',
      elements: [
        {
          id: 'skyline-limit',
          type: 'safe-line',
          shape: {
            type: 'line',
            start: { x: 0, y: 0.4 },
            end: { x: 1, y: 0.4 },
          },
        },
        {
          id: 'waterline',
          type: 'horizon',
          shape: {
            type: 'line',
            start: { x: 0, y: 0.68 },
            end: { x: 1, y: 0.68 },
          },
        },
      ],
    },
  ],
} satisfies CompositionPreset;
