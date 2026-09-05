import { requireNativeViewManager } from 'expo-modules-core';
import {
  forwardRef,
  useImperativeHandle,
  useRef,
  type ComponentType,
  type RefAttributes,
} from 'react';
import type { NativeSyntheticEvent } from 'react-native';

import type {
  CameraCaptureResult,
  CameraViewportHandle,
  CameraViewportProps,
} from './camera-viewport.types';

type NativeCameraViewportProps = Omit<
  CameraViewportProps,
  'onCameraReady' | 'onMountError'
> & {
  onCameraReady: (event: NativeSyntheticEvent<Record<string, never>>) => void;
  onMountError: (event: NativeSyntheticEvent<{ message: string }>) => void;
};

type NativeCameraViewportHandle = {
  takePicture: () => Promise<CameraCaptureResult>;
};

const NativeCameraViewport =
  requireNativeViewManager<NativeCameraViewportProps>(
    'FramewiseCamera',
  ) as ComponentType<
    NativeCameraViewportProps & RefAttributes<NativeCameraViewportHandle>
  >;

export const CameraViewport = forwardRef<
  CameraViewportHandle,
  CameraViewportProps
>(function CameraViewport({ onCameraReady, onMountError, ...viewProps }, ref) {
  const nativeRef = useRef<NativeCameraViewportHandle>(null);

  useImperativeHandle(ref, () => ({
    async takePictureAsync() {
      if (!nativeRef.current) {
        throw new Error('相机尚未就绪');
      }

      return nativeRef.current.takePicture();
    },
  }));

  return (
    <NativeCameraViewport
      {...viewProps}
      onCameraReady={onCameraReady}
      onMountError={({ nativeEvent }) => onMountError(nativeEvent.message)}
      ref={nativeRef}
    />
  );
});
