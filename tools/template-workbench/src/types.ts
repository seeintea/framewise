export type AspectRatio = "3:4" | "4:3" | "9:16" | "16:9" | "1:1";

export type PreviewGuide =
  | "centered"
  | "portrait"
  | "thirds"
  | "gaze"
  | "waterfront"
  | "depth";

export type WorkbenchTemplate = {
  id: string;
  title: string;
  description: string;
  availableSizes: AspectRatio[];
  defaultSize: AspectRatio;
  previewGuide: PreviewGuide;
};
