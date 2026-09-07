import type { CompositionPreset } from '../types';

export const centeredSubject = {
  id: 'centered-subject',
  title: '中心主体',
  description: '用于展示主体，建议选择纯净、不过于杂乱的背景。',
  variants: [
    {
      id: 'centered-subject-3x4',
      aspectRatio: { width: 3, height: 4 },
      instruction: '将主体置于画面中心的圆内',
      defaultFacing: 'back',
      elements: [
        {
          id: 'subject-area',
          type: 'subject',
          shape: {
            type: 'circle',
            center: { x: 0.5, y: 0.5 },
            radius: 0.3,
          },
        },
      ],
      annotations: [
        {
          id: 'subject-label',
          text: '主体',
          position: { x: 0.5, y: 0.5 },
        },
      ],
    },
    {
      id: 'centered-subject-1x1',
      aspectRatio: { width: 1, height: 1 },
      instruction: '将主体置于画面中心的圆内',
      defaultFacing: 'back',
      elements: [
        {
          id: 'subject-area',
          type: 'subject',
          shape: {
            type: 'circle',
            center: { x: 0.5, y: 0.5 },
            radius: 0.3,
          },
        },
      ],
      annotations: [
        {
          id: 'subject-label',
          text: '主体',
          position: { x: 0.5, y: 0.5 },
        },
      ],
    },
  ],
} satisfies CompositionPreset;
