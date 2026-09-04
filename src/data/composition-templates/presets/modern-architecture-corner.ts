import type { CompositionPreset } from '@/canvas';

export const modernArchitectureCorner = {
  id: 'modern-architecture-corner',
  title: '现代建筑折角',
  description: '适合玻璃幕墙和重复立面的现代建筑，突出棱角与向上延伸感。',
  variants: [
    {
      id: 'modern-architecture-corner-3x4',
      aspectRatio: { width: 3, height: 4 },
      instruction:
        '将建筑最高转角对准圆圈，使主棱线贴合中轴，两侧顶部轮廓沿斜线展开',
      defaultFacing: 'back',
      annotations: [
        {
          id: 'corner-label',
          text: '顶部转角',
          position: { x: 0.46, y: 0.19 },
        },
        {
          id: 'roof-line-label',
          text: '顶部轮廓',
          position: { x: 0.76, y: 0.29 },
        },
        {
          id: 'corner-axis-label',
          text: '建筑棱线',
          position: { x: 0.58, y: 0.65 },
        },
      ],
      elements: [
        {
          id: 'corner-anchor',
          type: 'subject',
          shape: {
            type: 'dashed-circle',
            center: { x: 0.46, y: 0.24 },
            radius: 0.025,
          },
        },
        {
          id: 'left-roof-guide',
          type: 'safe-line',
          shape: {
            type: 'line',
            start: { x: 0, y: 0.48 },
            end: { x: 0.46, y: 0.24 },
          },
        },
        {
          id: 'right-roof-guide',
          type: 'safe-line',
          shape: {
            type: 'line',
            start: { x: 0.46, y: 0.24 },
            end: { x: 1, y: 0.48 },
          },
        },
        {
          id: 'vertical-corner-axis',
          type: 'safe-line',
          shape: {
            type: 'dashed-line',
            start: { x: 0.46, y: 0.24 },
            end: { x: 0.46, y: 1 },
          },
        },
      ],
    },
  ],
} satisfies CompositionPreset;
