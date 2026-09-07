export type AspectRatio =
  | { width: 3; height: 4 }
  | { width: 4; height: 3 }
  | { width: 9; height: 16 }
  | { width: 16; height: 9 }
  | { width: 1; height: 1 };

export type Point = {
  x: number;
  y: number;
};

export type Bounds = Point & {
  width: number;
  height: number;
};

export type Size = {
  width: number;
  height: number;
};
