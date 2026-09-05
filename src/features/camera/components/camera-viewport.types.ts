import type { ViewProps } from 'react-native';

export type CameraFacing = 'back' | 'front';

export type CameraCaptureResult = {
  uri: string;
  width: number;
  height: number;
};

export type CameraViewportHandle = {
  takePictureAsync: () => Promise<CameraCaptureResult>;
};

export type CameraViewportProps = ViewProps & {
  facing: CameraFacing;
  flashEnabled: boolean;
  onCameraReady: () => void;
  onMountError: (message: string) => void;
  zoom: number;
};
