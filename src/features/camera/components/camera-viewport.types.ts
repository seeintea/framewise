import type { ViewProps } from 'react-native';

export type CameraFacing = 'back' | 'front';

export type CameraCaptureResult = {
  uri: string;
  width: number;
  height: number;
  lensId?: string;
  zoomRatio?: number;
};

export type ExposureCompensationRange = {
  minimum: number;
  maximum: number;
  step: number;
};

export type CameraLens = {
  id: string;
  facing: CameraFacing;
  focalLengths: number[];
  minimumZoomRatio: number;
  maximumZoomRatio: number;
  intrinsicZoomRatio: number;
  supportsFlash: boolean;
  supportsFocusMetering: boolean;
  isLogicalMultiCamera: boolean;
  physicalCameraIds: string[];
  exposureCompensationRange: ExposureCompensationRange | null;
};

export type CameraCapabilities = {
  lenses: CameraLens[];
  activeLensId: string;
  zoomRatio: number;
  exposureCompensation: number;
};

export type FocusResult = {
  focusSuccessful: boolean;
};

export type CameraViewportHandle = {
  focusAt: (x: number, y: number) => Promise<FocusResult>;
  takePictureAsync: () => Promise<CameraCaptureResult>;
};

export type CameraViewportProps = ViewProps & {
  exposureCompensation: number;
  facing: CameraFacing;
  flashEnabled: boolean;
  lensId?: string;
  onCapabilitiesChanged: (capabilities: CameraCapabilities) => void;
  onCameraReady: () => void;
  onMountError: (message: string) => void;
  zoomRatio: number;
};
