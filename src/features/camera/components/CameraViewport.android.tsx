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
  CameraCapabilities,
  CameraCaptureResult,
  CameraViewportHandle,
  CameraViewportProps,
  FocusResult,
} from './camera-viewport.types';

type NativeCameraViewportProps = Omit<
  CameraViewportProps,
  'onCameraReady' | 'onCapabilitiesChanged' | 'onLog' | 'onMountError'
> & {
  onCameraReady: (event: NativeSyntheticEvent<Record<string, never>>) => void;
  onCapabilitiesChanged: (
    event: NativeSyntheticEvent<CameraCapabilities>,
  ) => void;
  onLog: (
    event: NativeSyntheticEvent<Parameters<CameraViewportProps['onLog']>[0]>,
  ) => void;
  onMountError: (event: NativeSyntheticEvent<{ message: string }>) => void;
};

type NativeCameraViewportHandle = {
  focusAt: (x: number, y: number) => Promise<FocusResult>;
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
>(function CameraViewport(
  { onCameraReady, onCapabilitiesChanged, onLog, onMountError, ...viewProps },
  ref,
) {
  const nativeRef = useRef<NativeCameraViewportHandle>(null);

  useImperativeHandle(ref, () => ({
    async focusAt(x, y) {
      if (!nativeRef.current) {
        throw new Error('相机尚未就绪');
      }

      return nativeRef.current.focusAt(x, y);
    },
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
      onCapabilitiesChanged={({ nativeEvent }) =>
        onCapabilitiesChanged(nativeEvent)
      }
      onLog={({ nativeEvent }) => onLog(nativeEvent)}
      onMountError={({ nativeEvent }) => onMountError(nativeEvent.message)}
      ref={nativeRef}
    />
  );
});
