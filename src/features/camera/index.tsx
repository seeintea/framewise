import { useCameraPermissions } from 'expo-camera';
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
import { CameraViewport } from './components/CameraViewport';
import type {
  CameraCapabilities,
  CameraLens,
  CameraViewportHandle,
} from './components/camera-viewport.types';
import { PinchZoomLayer } from './components/PinchZoomLayer';
import { TemplateAnnotations } from './components/TemplateAnnotations';
import { usePhotoLibrary } from './hooks/use-photo-library';

const GUIDANCE_DURATION_MS = 3000;
const CAPTURE_SUCCESS_DURATION_MS = 1500;

type CameraProps = {
  onBack: () => void;
  presetId?: string;
};

export function Camera({ onBack, presetId }: CameraProps) {
  const cameraRef = useRef<CameraViewportHandle>(null);
  const captureLockRef = useRef(false);
  const captureStatusTimeoutRef = useRef<ReturnType<typeof setTimeout> | null>(
    null,
  );
  const windowSize = useWindowDimensions();
  const { top, bottom } = useSafeAreaInsets();
  const [cameraPermission] = useCameraPermissions();
  const [capabilities, setCapabilities] = useState<CameraCapabilities>();
  const [selectedLensId, setSelectedLensId] = useState<string>();
  const [zoomRatio, setZoomRatio] = useState(1);
  const [exposureCompensation, setExposureCompensation] = useState(0);
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
  const activeLens = capabilities?.lenses.find(
    (lens) => lens.id === capabilities.activeLensId,
  );
  const zoomOptions = activeLens ? createZoomOptions(activeLens) : [];
  const lensOptions =
    capabilities?.lenses.map((lens, index) => ({
      id: lens.id,
      label: createLensLabel(lens, index),
    })) ?? [];
  const exposureRange = activeLens?.exposureCompensationRange;

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
      const photo = await cameraRef.current.takePictureAsync();

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
          <CameraViewport
            exposureCompensation={exposureCompensation}
            facing={isFrontFacing ? 'front' : 'back'}
            flashEnabled={flashEnabled}
            lensId={selectedLensId}
            onCapabilitiesChanged={(nextCapabilities) => {
              setCapabilities(nextCapabilities);
              setSelectedLensId(nextCapabilities.activeLensId);
              setZoomRatio(nextCapabilities.zoomRatio);
              setExposureCompensation(nextCapabilities.exposureCompensation);
            }}
            onCameraReady={() => {
              setIsCameraReady(true);
              setCaptureStatus(undefined);
            }}
            onMountError={(message) => {
              setIsCameraReady(false);
              setCaptureStatus(undefined);
              Alert.alert('相机启动失败', message);
            }}
            ref={cameraRef}
            style={StyleSheet.absoluteFill}
            zoomRatio={zoomRatio}
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
          <PinchZoomLayer
            maximumZoomRatio={activeLens?.maximumZoomRatio ?? 1}
            minimumZoomRatio={activeLens?.minimumZoomRatio ?? 1}
            onFocusAt={(x, y) => {
              void cameraRef.current?.focusAt(x, y).catch((error: unknown) => {
                console.error('点击聚焦失败', error);
              });
            }}
            onZoomRatioChange={setZoomRatio}
            supportsFocusMetering={activeLens?.supportsFocusMetering ?? false}
            zoomRatio={zoomRatio}
          />
        </View>
      </View>
      <CameraControls
        bottomInset={bottom}
        cameraInfoLabel={
          activeLens ? createCameraInfoLabel(activeLens) : undefined
        }
        captureDisabled={!isCameraReady || isCapturing}
        captureStatus={
          captureStatus ?? (!isCameraReady ? '正在启动相机…' : undefined)
        }
        exposureCompensation={exposureCompensation}
        exposureMaximum={exposureRange?.maximum ?? 0}
        exposureMinimum={exposureRange?.minimum ?? 0}
        exposureStep={exposureRange?.step ?? 0}
        flashEnabled={flashEnabled}
        flashSupported={activeLens?.supportsFlash ?? false}
        guidanceInstruction={variant.instruction}
        guidanceTitle={preset.title}
        guidanceVisible={guidanceVisible}
        isFrontFacing={isFrontFacing}
        latestPhotoUri={latestPhotoUri}
        lensOptions={lensOptions}
        onBack={onBack}
        onCapture={() => void capturePhoto()}
        onExposureChange={setExposureCompensation}
        onFlipCamera={() => {
          setIsCameraReady(false);
          setCapabilities(undefined);
          setSelectedLensId(undefined);
          setZoomRatio(1);
          setExposureCompensation(0);
          setFlashEnabled(false);
          setIsFrontFacing((current) => !current);
        }}
        onLensChange={(lensId) => {
          setIsCameraReady(false);
          setSelectedLensId(lensId);
          setExposureCompensation(0);
          setFlashEnabled(false);
        }}
        onOpenGallery={() => {
          void openPhotoLibrary().catch((error: unknown) => {
            console.error('打开相册失败', error);
          });
        }}
        onToggleFlash={() => setFlashEnabled((current) => !current)}
        onToggleGuidance={() => setGuidanceVisible((visible) => !visible)}
        onZoomRatioChange={setZoomRatio}
        previewBottom={previewBottom}
        selectedLensId={selectedLensId}
        selectedZoomRatio={zoomRatio}
        topInset={top}
        zoomOptions={zoomOptions}
      />
    </View>
  );
}

function createZoomOptions(lens: CameraLens) {
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

function createLensLabel(lens: CameraLens, index: number) {
  const focalLength = lens.focalLengths[0];
  return focalLength
    ? `${focalLength.toFixed(1)}mm · #${lens.id}`
    : `镜头 ${index + 1} · #${lens.id}`;
}

function createCameraInfoLabel(lens: CameraLens) {
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
