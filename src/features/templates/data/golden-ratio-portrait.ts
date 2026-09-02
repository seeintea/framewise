import type { CompositionPreset } from '@/canvas';

export const goldenRatioPortrait = {
  id: 'golden-ratio-portrait',
  title: '黄金分割人像',
  description:
    '适合小腿以上的人像，让人物落在画面右侧的黄金分割位置，并保留左侧环境。',
  variants: [
    {
      id: 'golden-ratio-portrait-3x4',
      aspectRatio: { width: 3, height: 4 },
      instruction: '将人物置于画面右下方的圆角矩形内',
      defaultFacing: 'back',
      elements: [
        {
          id: 'subject-area',
          type: 'subject',
          shape: {
            type: 'rect',
            bounds: {
              x: 0.478,
              y: 0.58,
              width: 0.28,
              height: 0.4,
            },
            cornerRadius: 0.04,
          },
        },
      ],
    },
  ],
} satisfies CompositionPreset;
