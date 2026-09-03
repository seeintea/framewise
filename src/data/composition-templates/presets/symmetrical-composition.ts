import type { CompositionPreset } from '@/canvas';

export const symmetricalComposition = {
  id: 'symmetrical-composition',
  title: '对称构图',
  description: '适合建筑正面、门窗、通道和居中人物等左右对称的场景。',
  variants: [
    {
      id: 'symmetrical-composition-3x4',
      aspectRatio: { width: 3, height: 4 },
      instruction: '让场景中轴贴合虚线，并保持主体两侧留白一致',
      defaultFacing: 'back',
      elements: [
        {
          id: 'subject-area',
          type: 'subject',
          shape: {
            type: 'rect',
            bounds: {
              x: 0.12,
              y: 0.1,
              width: 0.76,
              height: 0.8,
            },
            cornerRadius: 0.02,
          },
        },
        {
          id: 'symmetry-axis',
          type: 'safe-line',
          shape: {
            type: 'dashed-line',
            start: { x: 0.5, y: 0.1 },
            end: { x: 0.5, y: 0.9 },
          },
        },
      ],
    },
  ],
} satisfies CompositionPreset;
