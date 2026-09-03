import type { CompositionPreset } from '@/canvas';

export const leadingLinesDepth = {
  id: 'leading-lines-depth',
  title: '纵深引导',
  description: '适合道路、走廊和建筑通道等具有明显透视延伸的场景。',
  variants: [
    {
      id: 'leading-lines-depth-3x4',
      aspectRatio: { width: 3, height: 4 },
      instruction: '让道路或建筑边缘沿引导线延伸，并在圆点附近汇聚',
      defaultFacing: 'back',
      elements: [
        {
          id: 'horizon-guide',
          type: 'safe-line',
          shape: {
            type: 'dashed-line',
            start: { x: 0.2, y: 0.5 },
            end: { x: 0.8, y: 0.5 },
          },
        },
        {
          id: 'left-leading-line',
          type: 'safe-line',
          shape: {
            type: 'line',
            start: { x: 0.08, y: 1 },
            end: { x: 0.5, y: 0.5 },
          },
        },
        {
          id: 'right-leading-line',
          type: 'safe-line',
          shape: {
            type: 'line',
            start: { x: 0.92, y: 1 },
            end: { x: 0.5, y: 0.5 },
          },
        },
        {
          id: 'vanishing-point',
          type: 'subject',
          shape: {
            type: 'circle',
            center: { x: 0.5, y: 0.5 },
            radius: 0.025,
          },
        },
      ],
    },
  ],
} satisfies CompositionPreset;
