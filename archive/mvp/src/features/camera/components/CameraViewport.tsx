import { CameraView, type CameraCapturedPicture } from 'expo-camera';
import { useRef, useState } from 'react';
import {
  ActivityIndicator,
  Pressable,
  StyleSheet,
  Text,
  View,
} from 'react-native';

import Canvas from '@/canvas';
import type { CompositionTemplateVariant } from '@/canvas/types';
import { PinchZoomLayer } from '@/features/camera/components/PinchZoomLayer';
import type { Size } from '@/types/geometry';

type CameraViewportProps = {
  onPhotoCaptured: (photo: CameraCapturedPicture) => void;
  variant: CompositionTemplateVariant;
  viewportSize: Size;
};

export function CameraViewport({
  onPhotoCaptured,
  variant,
  viewportSize,
}: CameraViewportProps) {
  const cameraRef = useRef<CameraView>(null);
  const captureLockRef = useRef(false);
  const [isCameraReady, setIsCameraReady] = useState(false);
  const [isTakingPhoto, setIsTakingPhoto] = useState(false);
  const [errorMessage, setErrorMessage] = useState<string>();
  const [zoom, setZoom] = useState(0);

  async function takePicture() {
    if (!isCameraReady || captureLockRef.current || !cameraRef.current) {
      return;
    }

    captureLockRef.current = true;
    setIsTakingPhoto(true);
    setErrorMessage(undefined);

    try {
      const photo = await cameraRef.current.takePictureAsync();
      onPhotoCaptured(photo);
    } catch (error) {
      setErrorMessage(error instanceof Error ? error.message : '拍照失败');
    } finally {
      captureLockRef.current = false;
      setIsTakingPhoto(false);
    }
  }

  return (
    <View style={[styles.container, viewportSize]}>
      <CameraView
        facing={variant.defaultFacing}
        mode="picture"
        onCameraReady={() => {
          setIsCameraReady(true);
          setErrorMessage(undefined);
        }}
        onMountError={(error) => {
          setIsCameraReady(false);
          setErrorMessage(error.message);
        }}
        ratio="4:3"
        ref={cameraRef}
        style={StyleSheet.absoluteFill}
        zoom={zoom}
      />
      <PinchZoomLayer onZoomChange={setZoom} zoom={zoom} />
      <View pointerEvents="none" style={StyleSheet.absoluteFill}>
        <Canvas variant={variant} viewportSize={viewportSize} />
      </View>
      <View style={styles.controls}>
        <Text style={styles.instruction}>{variant.instruction}</Text>
        <Text style={[styles.status, errorMessage && styles.error]}>
          {errorMessage
            ? errorMessage
            : isCameraReady
              ? zoom > 0
                ? `双指缩放 · ${Math.round(zoom * 100)}%`
                : '相机与构图层已就绪 · 双指缩放'
              : '正在启动相机…'}
        </Text>
        <Pressable
          accessibilityLabel="拍照"
          accessibilityRole="button"
          disabled={!isCameraReady || isTakingPhoto}
          onPress={takePicture}
          style={({ pressed }) => [
            styles.shutter,
            (!isCameraReady || isTakingPhoto) && styles.shutterDisabled,
            pressed && styles.shutterPressed,
          ]}
        >
          {isTakingPhoto ? (
            <ActivityIndicator color="#111111" />
          ) : (
            <View style={styles.shutterInner} />
          )}
        </Pressable>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    overflow: 'hidden',
    backgroundColor: '#000000',
  },
  controls: {
    position: 'absolute',
    right: 16,
    bottom: 16,
    left: 16,
    alignItems: 'center',
    gap: 4,
    padding: 12,
    borderRadius: 12,
    backgroundColor: 'rgba(0, 0, 0, 0.6)',
  },
  instruction: {
    color: '#FFFFFF',
    fontSize: 16,
    fontWeight: '600',
  },
  status: {
    color: '#D1D1D1',
    fontSize: 13,
  },
  error: {
    color: '#FF8A80',
  },
  shutter: {
    width: 68,
    height: 68,
    alignItems: 'center',
    justifyContent: 'center',
    marginTop: 8,
    borderRadius: 34,
    backgroundColor: '#FFFFFF',
  },
  shutterInner: {
    width: 56,
    height: 56,
    borderWidth: 2,
    borderColor: '#111111',
    borderRadius: 28,
  },
  shutterDisabled: {
    opacity: 0.5,
  },
  shutterPressed: {
    transform: [{ scale: 0.94 }],
  },
});
