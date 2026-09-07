import type { CompositionPreset } from '../types';

export const cityWaterfrontReflection = {
  id: 'city-waterfront-reflection',
  title: '城市水岸倒影',
  description: '适合近距离拍摄滨水建筑，让建筑与水中倒影形成上下呼应。',
  variants: [
    {
      id: 'city-waterfront-reflection-3x4',
      aspectRatio: { width: 3, height: 4 },
      instruction: '让水岸线略高于画面中央，并完整保留建筑与倒影上下呼应',
      defaultFacing: 'back',
      elements: [
        {
          id: 'building-top-limit',
          type: 'safe-line',
          shape: {
            type: 'dashed-line',
            start: { x: 0, y: 0.14 },
            end: { x: 1, y: 0.14 },
          },
        },
        {
          id: 'waterline',
          type: 'horizon',
          shape: {
            type: 'line',
            start: { x: 0, y: 0.46 },
            end: { x: 1, y: 0.46 },
          },
        },
        {
          id: 'reflection-bottom-limit',
          type: 'safe-line',
          shape: {
            type: 'dashed-line',
            start: { x: 0, y: 0.78 },
            end: { x: 1, y: 0.78 },
          },
        },
      ],
      annotations: [
        {
          id: 'scene-label',
          text: '景物',
          position: { x: 0.5, y: 0.3 },
        },
        {
          id: 'reflection-label',
          text: '倒影',
          position: { x: 0.5, y: 0.62 },
        },
      ],
    },
  ],
} satisfies CompositionPreset;
