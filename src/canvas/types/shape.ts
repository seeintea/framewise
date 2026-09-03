import type { Bounds, Point } from '@/types';

export type LineShape = {
  type: 'line';
  start: Point;
  end: Point;
};

export type DashedLineShape = {
  type: 'dashed-line';
  start: Point;
  end: Point;
};

export type DashedCircleShape = {
  type: 'dashed-circle';
  center: Point;
  radius: number;
};

export type CircleShape = {
  type: 'circle';
  center: Point;
  radius: number;
};

export type RectShape = {
  type: 'rect';
  bounds: Bounds;
  cornerRadius?: number;
};

export type Shape =
  CircleShape | DashedCircleShape | DashedLineShape | LineShape | RectShape;

export type ResolvedLineShape = {
  type: 'line';
  start: Point;
  end: Point;
};

export type ResolvedDashedLineShape = {
  type: 'dashed-line';
  start: Point;
  end: Point;
};

export type ResolvedDashedCircleShape = {
  type: 'dashed-circle';
  center: Point;
  radius: number;
};

export type ResolvedCircleShape = {
  type: 'circle';
  center: Point;
  radius: number;
};

export type ResolvedRectShape = {
  type: 'rect';
  bounds: Bounds;
  cornerRadius: number;
};

export type ResolvedShape =
  | ResolvedCircleShape
  | ResolvedDashedCircleShape
  | ResolvedDashedLineShape
  | ResolvedLineShape
  | ResolvedRectShape;
