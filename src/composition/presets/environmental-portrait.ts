import type { CompositionPreset } from '../types';

export const environmentalPortrait = {
  id: 'environmental-portrait',
  title: '环境人像',
  description: '适合旅行和街拍，在突出人物的同时保留周围环境信息。',
  origin: 'ai-generated',
  variants: [
    {
      id: 'environmental-portrait-3x4',
      aspectRatio: { width: 3, height: 4 },
      instruction: '将面部对准圆圈，身体沿竖线展开，并在左侧保留环境',
      defaultFacing: 'back',
      annotations: [
        {
          id: 'face-label',
          text: '面部',
          position: { x: 0.78, y: 0.3 },
        },
        {
          id: 'environment-label',
          text: '环境',
          position: { x: 0.28, y: 0.52 },
        },
      ],
      elements: [
        {
          id: 'face-anchor',
          type: 'subject',
          shape: {
            type: 'dashed-circle',
            center: { x: 0.667, y: 0.3 },
            radius: 0.035,
          },
        },
        {
          id: 'body-axis',
          type: 'safe-line',
          shape: {
            type: 'dashed-line',
            start: { x: 0.667, y: 0.335 },
            end: { x: 0.667, y: 0.9 },
          },
        },
      ],
    },
  ],
} satisfies CompositionPreset;
