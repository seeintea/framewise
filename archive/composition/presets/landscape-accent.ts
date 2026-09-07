import type { CompositionPreset } from '../types';

export const landscapeAccent = {
  id: 'landscape-accent',
  title: '风景点睛',
  description: '适合用人物、树木或建筑为大面积风景增加明确视觉落点。',
  origin: 'ai-generated',
  variants: [
    {
      id: 'landscape-accent-4x3',
      aspectRatio: { width: 4, height: 3 },
      instruction: '让地平线贴合下方三分位置，并将小主体对准圆圈',
      defaultFacing: 'back',
      annotations: [
        {
          id: 'environment-label',
          text: '环境',
          position: { x: 0.33, y: 0.43 },
        },
        {
          id: 'subject-label',
          text: '小主体',
          position: { x: 0.667, y: 0.57 },
        },
      ],
      elements: [
        {
          id: 'left-horizon',
          type: 'horizon',
          shape: {
            type: 'line',
            start: { x: 0, y: 0.667 },
            end: { x: 0.62, y: 0.667 },
          },
        },
        {
          id: 'right-horizon',
          type: 'horizon',
          shape: {
            type: 'line',
            start: { x: 0.714, y: 0.667 },
            end: { x: 1, y: 0.667 },
          },
        },
        {
          id: 'subject-anchor',
          type: 'subject',
          shape: {
            type: 'dashed-circle',
            center: { x: 0.667, y: 0.667 },
            radius: 0.035,
          },
        },
      ],
    },
  ],
} satisfies CompositionPreset;
