import type { CameraLens } from './components/camera-viewport.types';

export function createZoomOptions(lens: CameraLens) {
  const candidates = [
    lens.minimumZoomRatio,
    1,
    2,
    lens.maximumZoomRatio,
  ].filter(
    (zoomRatio) =>
      zoomRatio >= lens.minimumZoomRatio && zoomRatio <= lens.maximumZoomRatio,
  );
  const uniqueRatios = candidates.filter(
    (zoomRatio, index) =>
      candidates.findIndex(
        (candidate) => Math.abs(candidate - zoomRatio) < 0.01,
      ) === index,
  );

  return uniqueRatios.map((value) => ({
    label: `${formatRatio(value)}×`,
    value,
  }));
}

export function createLensLabel(lens: CameraLens, index: number) {
  const focalLength = lens.focalLengths[0];
  return focalLength
    ? `${focalLength.toFixed(1)}mm · #${lens.id}`
    : `镜头 ${index + 1} · #${lens.id}`;
}

export function createCameraInfoLabel(lens: CameraLens) {
  const focalLengths = lens.focalLengths.length
    ? lens.focalLengths.map((value) => `${value.toFixed(1)}mm`).join('/')
    : '焦距未知';
  const physicalIds = lens.physicalCameraIds.length
    ? ` · physical ${lens.physicalCameraIds.join(',')}`
    : '';

  return `Camera ${lens.id} · ${focalLengths} · ${formatRatio(lens.minimumZoomRatio)}–${formatRatio(lens.maximumZoomRatio)}×${physicalIds}`;
}

function formatRatio(value: number) {
  return Number.isInteger(value) ? value.toFixed(0) : value.toFixed(1);
}
