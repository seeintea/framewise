import { useCameraPermissions } from 'expo-camera';
import { Asset } from 'expo-media-library';
import { useEffect, useReducer, useRef, useState } from 'react';
import {
  ActivityIndicator,
  Alert,
  StyleSheet,
  Text,
  useWindowDimensions,
  View,
} from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';

import Canvas, { getViewportSize } from '@/canvas';
import { findPresetById } from '@/composition';
import { logError, logInfo, logNativeEvent } from '@/logging';

import {
  createCameraInfoLabel,
  createLensLabel,
  createZoomOptions,
} from './camera-control-options';
import { cameraReducer, initialCameraState } from './camera-state';
import { CameraErrorLayout } from './components/CameraErrorLayout';
import { CameraControls } from './components/CameraControls';
import { CameraViewport } from './components/CameraViewport';
import type { CameraViewportHandle } from './components/camera-viewport.types';
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
  const [cameraState, dispatchCamera] = useReducer(
    cameraReducer,
    initialCameraState,
  );
  const [isCapturing, setIsCapturing] = useState(false);
  const [captureStatus, setCaptureStatus] = useState<string>();
  const [guidanceVisible, setGuidanceVisible] = useState(true);
  const [measuredPreviewBottom, setMeasuredPreviewBottom] = useState<number>();
  const { latestPhotoUri, openPhotoLibrary, rememberLatestPhoto } =
    usePhotoLibrary();
  const {
    capabilities,
    exposureCompensation,
    flashEnabled,
    isFrontFacing,
    isReady,
    selectedLensId,
    zoomRatio,
  } = cameraState;
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
    logInfo('camera', 'screen_opened', { presetId: presetId ?? null });

    return () => {
      logInfo('camera', 'screen_closed', { presetId: presetId ?? null });
    };
  }, [presetId]);

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
    if (!isReady || captureLockRef.current || !cameraRef.current) {
      return;
    }

    captureLockRef.current = true;
    setIsCapturing(true);
    setCaptureStatus('正在拍摄…');
    setGuidanceVisible(false);
    logInfo('camera', 'capture_requested', {
      presetId: presetId ?? null,
      lensId: activeLens?.id ?? null,
      zoomRatio,
    });

    try {
      const photo = await cameraRef.current.takePictureAsync();

      setCaptureStatus('正在保存到相册…');
      await Asset.create(photo.uri);
      rememberLatestPhoto(photo.uri);
      setCaptureStatus('已保存到相册');
      logInfo('camera', 'photo_saved', {
        width: photo.width,
        height: photo.height,
        lensId: photo.lensId ?? null,
        zoomRatio: photo.zoomRatio ?? null,
      });

      if (captureStatusTimeoutRef.current) {
        clearTimeout(captureStatusTimeoutRef.current);
      }
      captureStatusTimeoutRef.current = setTimeout(
        () => setCaptureStatus(undefined),
        CAPTURE_SUCCESS_DURATION_MS,
      );
    } catch (error) {
      logError('camera', 'capture_or_save_failed', error, {
        presetId: presetId ?? null,
      });
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
              dispatchCamera({
                type: 'capabilities-changed',
                capabilities: nextCapabilities,
              });
            }}
            onCameraReady={() => {
              logInfo('camera', 'ready_received');
              dispatchCamera({ type: 'camera-ready' });
              setCaptureStatus(undefined);
            }}
            onMountError={(message) => {
              logError('camera', 'mount_failed', new Error(message));
              dispatchCamera({ type: 'camera-failed' });
              setCaptureStatus(undefined);
              Alert.alert('相机启动失败', message);
            }}
            ref={cameraRef}
            style={StyleSheet.absoluteFill}
            zoomRatio={zoomRatio}
            onLog={logNativeEvent}
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
                logError('camera', 'focus_failed', error, { x, y });
              });
            }}
            onZoomRatioChange={(nextZoomRatio) =>
              dispatchCamera({
                type: 'zoom-changed',
                zoomRatio: nextZoomRatio,
              })
            }
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
        captureDisabled={!isReady || isCapturing}
        captureStatus={
          captureStatus ?? (!isReady ? '正在启动相机…' : undefined)
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
        onExposureChange={(nextExposureCompensation) =>
          dispatchCamera({
            type: 'exposure-changed',
            exposureCompensation: nextExposureCompensation,
          })
        }
        onFlipCamera={() => dispatchCamera({ type: 'camera-flipped' })}
        onLensChange={(lensId) =>
          dispatchCamera({ type: 'lens-changed', lensId })
        }
        onOpenGallery={() => {
          void openPhotoLibrary().catch((error: unknown) => {
            logError('camera', 'photo_library_open_failed', error);
          });
        }}
        onToggleFlash={() => dispatchCamera({ type: 'flash-toggled' })}
        onToggleGuidance={() => setGuidanceVisible((visible) => !visible)}
        onZoomRatioChange={(nextZoomRatio) =>
          dispatchCamera({
            type: 'zoom-changed',
            zoomRatio: nextZoomRatio,
          })
        }
        previewBottom={previewBottom}
        selectedLensId={selectedLensId}
        selectedZoomRatio={zoomRatio}
        topInset={top}
        zoomOptions={zoomOptions}
      />
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#000000',
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
});
