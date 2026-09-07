import type { CompositionPreset } from '../types';

export const waterReflection = {
  id: 'water-reflection',
  title: '水面倒影',
  description: '适合天空与平静水面构成的倒影场景，突出右侧视觉重心。',
  variants: [
    {
      id: 'water-reflection-3x4',
      aspectRatio: { width: 3, height: 4 },
      instruction:
        '让天空占画面上方五分之一，使倒影沿中部水平线延展，并将主体收在右侧三角区域内',
      defaultFacing: 'back',
      annotations: [
        {
          id: 'sky-label',
          text: '天空',
          position: { x: 0.5, y: 0.1 },
        },
        {
          id: 'subject-label',
          text: '主体',
          position: { x: 0.78, y: 0.43 },
        },
        {
          id: 'reflection-label',
          text: '倒影',
          position: { x: 0.78, y: 0.77 },
        },
      ],
      elements: [
        {
          id: 'sky-line',
          type: 'horizon',
          shape: {
            type: 'line',
            start: { x: 0, y: 0.2 },
            end: { x: 1, y: 0.2 },
          },
        },
        {
          id: 'reflection-line',
          type: 'safe-line',
          shape: {
            type: 'dashed-line',
            start: { x: 0, y: 0.6 },
            end: { x: 1, y: 0.6 },
          },
        },
        {
          id: 'triangle-upper-edge',
          type: 'safe-line',
          shape: {
            type: 'line',
            start: { x: 1, y: 0.2 },
            end: { x: 0.28, y: 0.6 },
          },
        },
        {
          id: 'triangle-lower-edge',
          type: 'safe-line',
          shape: {
            type: 'line',
            start: { x: 0.28, y: 0.6 },
            end: { x: 1, y: 1 },
          },
        },
      ],
    },
  ],
} satisfies CompositionPreset;
