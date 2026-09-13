import type { WorkbenchTemplate } from "./types";

// UI-only fixtures. Template Studio intentionally does not read composition yet.
export const demoCatalog: WorkbenchTemplate[] = [
  {
    id: "centered-subject",
    title: "中心主体",
    description: "用于展示主体，建议选择纯净、不过于杂乱的背景。",
    availableSizes: ["3:4", "1:1"],
    defaultSize: "3:4",
    previewGuide: "centered",
  },
  {
    id: "environmental-portrait",
    title: "环境人像",
    description: "突出人物的同时，保留周围环境信息。",
    availableSizes: ["3:4"],
    defaultSize: "3:4",
    previewGuide: "portrait",
  },
  {
    id: "classic-rule-of-thirds",
    title: "经典三分法",
    description: "沿三分线安排主体、地平线与留白。",
    availableSizes: ["3:4"],
    defaultSize: "3:4",
    previewGuide: "thirds",
  },
  {
    id: "gaze-space",
    title: "视线留白",
    description: "主体位于一侧，为视线方向保留空间。",
    availableSizes: ["3:4"],
    defaultSize: "3:4",
    previewGuide: "gaze",
  },
  {
    id: "waterfront-cityscape",
    title: "滨水城市",
    description: "在天空、建筑与水面之间保持层次。",
    availableSizes: ["16:9", "4:3"],
    defaultSize: "16:9",
    previewGuide: "waterfront",
  },
  {
    id: "leading-lines-depth",
    title: "纵深引导",
    description: "让道路或建筑边缘向汇聚点延伸。",
    availableSizes: ["3:4"],
    defaultSize: "3:4",
    previewGuide: "depth",
  },
];
