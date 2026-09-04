import type { CompositionPreset } from '@/canvas';

export const gazeSpace = {
  id: 'gaze-space',
  title: '视线留白',
  description: '适合侧脸、行走人物和运动主体，为朝向一侧保留延展空间。',
  origin: 'ai-generated',
  variants: [
    {
      id: 'gaze-space-3x4',
      aspectRatio: { width: 3, height: 4 },
      instruction: '将主体放在圆圈附近，让视线或运动方向沿虚线延伸',
      defaultFacing: 'back',
      annotations: [
        {
          id: 'subject-label',
          text: '主体',
          position: { x: 0.333, y: 0.32 },
        },
        {
          id: 'gaze-space-label',
          text: '视线空间',
          position: { x: 0.66, y: 0.36 },
        },
      ],
      elements: [
        {
          id: 'subject-anchor',
          type: 'subject',
          shape: {
            type: 'dashed-circle',
            center: { x: 0.333, y: 0.42 },
            radius: 0.055,
          },
        },
        {
          id: 'gaze-line',
          type: 'safe-line',
          shape: {
            type: 'dashed-line',
            start: { x: 0.4, y: 0.42 },
            end: { x: 0.9, y: 0.42 },
          },
        },
      ],
    },
  ],
} satisfies CompositionPreset;
