import { CameraView } from 'expo-camera';
import { forwardRef, useImperativeHandle, useRef } from 'react';

import type {
  CameraViewportHandle,
  CameraViewportProps,
} from './camera-viewport.types';

export const CameraViewport = forwardRef<
  CameraViewportHandle,
  CameraViewportProps
>(function CameraViewport(
  { facing, flashEnabled, onCameraReady, onMountError, zoom, ...viewProps },
  ref,
) {
  const cameraRef = useRef<CameraView>(null);

  useImperativeHandle(ref, () => ({
    async takePictureAsync() {
      const photo = await cameraRef.current?.takePictureAsync({ quality: 1 });

      if (!photo) {
        throw new Error('相机没有返回照片');
      }

      return photo;
    },
  }));

  return (
    <CameraView
      {...viewProps}
      facing={facing}
      flash={flashEnabled ? 'on' : 'off'}
      mode="picture"
      onCameraReady={onCameraReady}
      onMountError={({ message }) => onMountError(message)}
      ratio="4:3"
      ref={cameraRef}
      zoom={zoom}
    />
  );
});
