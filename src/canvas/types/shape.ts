import type { Bounds, Point } from '@/types';

export type LineShape = {
  type: 'line';
  start: Point;
  end: Point;
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

export type Shape = CircleShape | LineShape | RectShape;

export type ResolvedLineShape = {
  type: 'line';
  start: Point;
  end: Point;
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
  ResolvedCircleShape | ResolvedLineShape | ResolvedRectShape;
