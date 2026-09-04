import { CameraView, useCameraPermissions } from 'expo-camera';
import { Asset } from 'expo-media-library';
import { type ReactNode, useEffect, useRef, useState } from 'react';
import {
  ActivityIndicator,
  Alert,
  Pressable,
  StyleSheet,
  Text,
  useWindowDimensions,
  View,
} from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';

import Canvas, { getViewportSize } from '@/canvas';
import { findPresetById } from '@/data/composition-templates';

import { CameraControls } from './components/CameraControls';
import { PinchZoomLayer } from './components/PinchZoomLayer';
import { TemplateAnnotations } from './components/TemplateAnnotations';
import { usePhotoLibrary } from './hooks/use-photo-library';

const GUIDANCE_DURATION_MS = 3000;
const CAPTURE_SUCCESS_DURATION_MS = 1500;
const ZOOM_OPTIONS = [
  { label: '1×', value: 0 },
  { label: '50%', value: 0.5 },
  { label: 'Max', value: 1 },
] as const;

type CameraProps = {
  onBack: () => void;
  presetId?: string;
};

export function Camera({ onBack, presetId }: CameraProps) {
  const cameraRef = useRef<CameraView>(null);
  const captureLockRef = useRef(false);
  const captureStatusTimeoutRef = useRef<ReturnType<typeof setTimeout> | null>(
    null,
  );
  const windowSize = useWindowDimensions();
  const { top, bottom } = useSafeAreaInsets();
  const [cameraPermission] = useCameraPermissions();
  const [selectedZoom, setSelectedZoom] = useState(0);
  const [flashEnabled, setFlashEnabled] = useState(false);
  const [isFrontFacing, setIsFrontFacing] = useState(false);
  const [isCameraReady, setIsCameraReady] = useState(false);
  const [isCapturing, setIsCapturing] = useState(false);
  const [captureStatus, setCaptureStatus] = useState<string>();
  const [guidanceVisible, setGuidanceVisible] = useState(true);
  const [measuredPreviewBottom, setMeasuredPreviewBottom] = useState<number>();
  const { latestPhotoUri, openPhotoLibrary, rememberLatestPhoto } =
    usePhotoLibrary();
  const preset = presetId ? findPresetById(presetId) : undefined;

  useEffect(() => {
    if (!guidanceVisible) {
      return;
    }

    const timeoutId = setTimeout(
      () => setGuidanceVisible(false),
      GUIDANCE_DURATION_MS,
    );

    return () => clearTimeout(timeoutId);
  }, [guidanceVisible]);

  useEffect(
    () => () => {
      if (captureStatusTimeoutRef.current) {
        clearTimeout(captureStatusTimeoutRef.current);
      }
    },
    [],
  );

  async function capturePhoto() {
    if (!isCameraReady || captureLockRef.current || !cameraRef.current) {
      return;
    }

    captureLockRef.current = true;
    setIsCapturing(true);
    setCaptureStatus('正在拍摄…');
    setGuidanceVisible(false);

    try {
      const photo = await cameraRef.current.takePictureAsync({ quality: 1 });

      if (!photo) {
        throw new Error('相机没有返回照片');
      }

      setCaptureStatus('正在保存到相册…');
      await Asset.create(photo.uri);
      rememberLatestPhoto(photo.uri);
      setCaptureStatus('已保存到相册');

      if (captureStatusTimeoutRef.current) {
        clearTimeout(captureStatusTimeoutRef.current);
      }
      captureStatusTimeoutRef.current = setTimeout(
        () => setCaptureStatus(undefined),
        CAPTURE_SUCCESS_DURATION_MS,
      );
    } catch (error) {
      setCaptureStatus(undefined);
      Alert.alert(
        '照片保存失败',
        error instanceof Error ? error.message : '请稍后重试',
      );
    } finally {
      captureLockRef.current = false;
      setIsCapturing(false);
    }
  }

  if (!preset) {
    return (
      <CameraErrorLayout onBack={onBack} topInset={top}>
        <Text style={styles.message}>未找到所选构图模版</Text>
      </CameraErrorLayout>
    );
  }

  if (!cameraPermission) {
    return (
      <CameraErrorLayout onBack={onBack} topInset={top}>
        <ActivityIndicator color="#FFFFFF" />
      </CameraErrorLayout>
    );
  }

  if (!cameraPermission.granted) {
    return (
      <CameraErrorLayout onBack={onBack} topInset={top}>
        <Text style={styles.message}>相机权限已失效，请返回后重新授权</Text>
      </CameraErrorLayout>
    );
  }

  const variant = preset.variants[0];
  const viewportSize = getViewportSize(
    variant.aspectRatio,
    Math.min(windowSize.width, windowSize.height),
  );
  const isLandscape = variant.aspectRatio.width > variant.aspectRatio.height;
  const displaySize = isLandscape
    ? { width: viewportSize.height, height: viewportSize.width }
    : viewportSize;
  const previewBottom =
    measuredPreviewBottom ??
    Math.round((windowSize.height + displaySize.height) / 2);

  return (
    <View style={styles.container}>
      <View
        pointerEvents="box-none"
        style={[StyleSheet.absoluteFill, styles.stage]}
      >
        <View
          onLayout={({ nativeEvent }) => {
            const { y, height } = nativeEvent.layout;
            setMeasuredPreviewBottom(Math.round(y + height));
          }}
          style={[styles.previewFrame, displaySize]}
        >
          <CameraView
            facing={isFrontFacing ? 'front' : 'back'}
            flash={flashEnabled ? 'on' : 'off'}
            mode="picture"
            onCameraReady={() => {
              setIsCameraReady(true);
              setCaptureStatus(undefined);
            }}
            onMountError={({ message }) => {
              setIsCameraReady(false);
              setCaptureStatus(undefined);
              Alert.alert('相机启动失败', message);
            }}
            ratio="4:3"
            ref={cameraRef}
            style={StyleSheet.absoluteFill}
            zoom={selectedZoom}
          />
          <View
            style={[
              styles.canvasSurface,
              viewportSize,
              isLandscape && styles.rotatedCanvas,
            ]}
          >
            <Canvas variant={variant} viewportSize={viewportSize} />
          </View>
          {guidanceVisible && variant.annotations && (
            <TemplateAnnotations
              annotations={variant.annotations}
              isLandscape={isLandscape}
              viewportSize={displaySize}
            />
          )}
          <PinchZoomLayer onZoomChange={setSelectedZoom} zoom={selectedZoom} />
        </View>
      </View>
      <CameraControls
        bottomInset={bottom}
        captureDisabled={!isCameraReady || isCapturing}
        captureStatus={
          captureStatus ?? (!isCameraReady ? '正在启动相机…' : undefined)
        }
        flashEnabled={flashEnabled}
        guidanceInstruction={variant.instruction}
        guidanceTitle={preset.title}
        guidanceVisible={guidanceVisible}
        isFrontFacing={isFrontFacing}
        latestPhotoUri={latestPhotoUri}
        onBack={onBack}
        onCapture={() => void capturePhoto()}
        onFlipCamera={() => {
          setIsCameraReady(false);
          setIsFrontFacing((current) => !current);
        }}
        onOpenGallery={() => {
          void openPhotoLibrary().catch((error: unknown) => {
            console.error('打开相册失败', error);
          });
        }}
        onToggleFlash={() => setFlashEnabled((current) => !current)}
        onToggleGuidance={() => setGuidanceVisible((visible) => !visible)}
        onZoomChange={setSelectedZoom}
        previewBottom={previewBottom}
        selectedZoom={selectedZoom}
        topInset={top}
        zoomOptions={ZOOM_OPTIONS}
      />
    </View>
  );
}

type CameraErrorLayoutProps = {
  children: ReactNode;
  onBack: () => void;
  topInset: number;
};

function CameraErrorLayout({
  children,
  onBack,
  topInset,
}: CameraErrorLayoutProps) {
  return (
    <View style={styles.container}>
      <View style={[StyleSheet.absoluteFill, styles.stage]}>{children}</View>
      <Pressable
        accessibilityLabel="返回"
        accessibilityRole="button"
        hitSlop={8}
        onPress={onBack}
        style={({ pressed }) => [
          styles.backButton,
          { top: topInset + 10 },
          pressed && styles.backButtonPressed,
        ]}
      >
        <Text style={styles.backLabel}>‹</Text>
      </Pressable>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#000000',
  },
  backButton: {
    position: 'absolute',
    left: 12,
    zIndex: 1,
    width: 40,
    height: 40,
    alignItems: 'center',
    justifyContent: 'center',
  },
  backButtonPressed: {
    opacity: 0.75,
  },
  stage: {
    alignItems: 'center',
    justifyContent: 'center',
    overflow: 'hidden',
  },
  previewFrame: {
    alignItems: 'center',
    justifyContent: 'center',
    overflow: 'hidden',
    backgroundColor: '#242427',
  },
  canvasSurface: {
    backgroundColor: 'transparent',
  },
  rotatedCanvas: {
    transform: [{ rotate: '90deg' }],
  },
  message: {
    color: '#FFFFFF',
    fontSize: 16,
  },
  backLabel: {
    color: '#FFFFFF',
    fontSize: 34,
    lineHeight: 36,
    fontWeight: '300',
  },
});
