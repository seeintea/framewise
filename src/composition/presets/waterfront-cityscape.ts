import type { CompositionPreset } from '../types';

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
      annotations: [
        {
          id: 'sky-label',
          text: '天空',
          position: { x: 0.5, y: 0.21 },
        },
        {
          id: 'shore-subject-label',
          text: '岸上景物',
          position: { x: 0.5, y: 0.55 },
        },
        {
          id: 'water-label',
          text: '水面',
          position: { x: 0.5, y: 0.84 },
        },
      ],
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
      annotations: [
        {
          id: 'sky-label',
          text: '天空',
          position: { x: 0.5, y: 0.2 },
        },
        {
          id: 'shore-subject-label',
          text: '岸上景物',
          position: { x: 0.5, y: 0.54 },
        },
        {
          id: 'water-label',
          text: '水面',
          position: { x: 0.5, y: 0.84 },
        },
      ],
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
