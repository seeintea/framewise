import type { CameraLens } from './components/camera-viewport.types';
import type { ZoomOption } from './components/camera-control.types';

export function createZoomOptions(lenses: readonly CameraLens[]) {
  if (!lenses.length) {
    return [];
  }

  const minimumDisplayRatio = Math.min(
    ...lenses.map((lens) => lens.intrinsicZoomRatio * lens.minimumZoomRatio),
  );
  const targets = [
    ...(minimumDisplayRatio < 1 ? [minimumDisplayRatio] : []),
    ...lenses.map((lens) => lens.intrinsicZoomRatio),
    1,
    2,
  ]
    .filter((ratio) => Number.isFinite(ratio) && ratio > 0)
    .filter(
      (ratio, index, values) =>
        values.findIndex((candidate) => Math.abs(candidate - ratio) < 0.05) ===
        index,
    )
    .sort((first, second) => first - second);

  return targets.flatMap((displayRatio): ZoomOption[] => {
    const option = resolveZoomOption(lenses, displayRatio);
    return option ? [option] : [];
  });
}

export function resolveZoomOption(
  lenses: readonly CameraLens[],
  displayRatio: number,
): ZoomOption | undefined {
  const lens = findBestLens(lenses, displayRatio);

  if (!lens) {
    return undefined;
  }

  return {
    label: `${formatRatio(displayRatio)}×`,
    lensId: lens.id,
    zoomRatio: Math.min(
      lens.maximumZoomRatio,
      Math.max(lens.minimumZoomRatio, displayRatio / lens.intrinsicZoomRatio),
    ),
  };
}

export function getDisplayZoomRatio(lens: CameraLens, zoomRatio: number) {
  return lens.intrinsicZoomRatio * zoomRatio;
}

export function getDisplayZoomRange(lenses: readonly CameraLens[]) {
  return {
    minimum: Math.min(
      ...lenses.map((lens) => lens.intrinsicZoomRatio * lens.minimumZoomRatio),
    ),
    maximum: Math.max(
      ...lenses.map((lens) => lens.intrinsicZoomRatio * lens.maximumZoomRatio),
    ),
  };
}

function findBestLens(lenses: readonly CameraLens[], displayRatio: number) {
  return lenses
    .filter((lens) => {
      const zoomRatio = displayRatio / lens.intrinsicZoomRatio;
      return (
        zoomRatio >= lens.minimumZoomRatio - 0.01 &&
        zoomRatio <= lens.maximumZoomRatio + 0.01
      );
    })
    .sort((first, second) => {
      if (first.isLogicalMultiCamera !== second.isLogicalMultiCamera) {
        return first.isLogicalMultiCamera ? -1 : 1;
      }

      const firstZoomDistance = Math.abs(
        Math.log(displayRatio / first.intrinsicZoomRatio),
      );
      const secondZoomDistance = Math.abs(
        Math.log(displayRatio / second.intrinsicZoomRatio),
      );
      return firstZoomDistance - secondZoomDistance;
    })[0];
}

export function formatRatio(value: number) {
  return Number.isInteger(value) ? value.toFixed(0) : value.toFixed(1);
}
