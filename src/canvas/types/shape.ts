import type { Point } from '@/types/geometry';

export type LineShape = {
  type: 'line';
  start: Point;
  end: Point;
};

export type Shape = LineShape;

export type ResolvedLineShape = {
  type: 'line';
  start: Point;
  end: Point;
};

export type ResolvedShape = ResolvedLineShape;
