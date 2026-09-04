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
      instruction: '将人物置于圆角矩形内，使面部边缘贴近黄金分割线',
      defaultFacing: 'back',
      elements: [
        {
          id: 'subject-area',
          type: 'subject',
          shape: {
            type: 'rect',
            bounds: {
              x: 0.338,
              y: 0.5,
              width: 0.36,
              height: 0.48,
            },
            cornerRadius: 0.02,
          },
        },
        {
          id: 'golden-ratio-line',
          type: 'safe-line',
          shape: {
            type: 'dashed-line',
            start: { x: 0.618, y: 0.5 },
            end: { x: 0.618, y: 0.98 },
          },
        },
      ],
      annotations: [
        {
          id: 'person-label',
          text: '人物',
          position: { x: 0.518, y: 0.46 },
        },
        {
          id: 'arm-guidance',
          text: '手臂保持在框内',
          position: { x: 0.82, y: 0.74 },
          maxWidth: 0.15,
        },
      ],
    },
  ],
} satisfies CompositionPreset;
