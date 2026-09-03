import { type ReactNode, useState } from 'react';
import {
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
import { usePhotoLibrary } from './hooks/use-photo-library';

const ZOOM_OPTIONS = [0.5, 1, 2] as const;

type CameraProps = {
  onBack: () => void;
  presetId?: string;
};

export function Camera({ onBack, presetId }: CameraProps) {
  const windowSize = useWindowDimensions();
  const { top, bottom } = useSafeAreaInsets();
  const [selectedZoom, setSelectedZoom] = useState<number>(1);
  const [flashEnabled, setFlashEnabled] = useState(false);
  const [livePhotoEnabled, setLivePhotoEnabled] = useState(false);
  const [isFrontFacing, setIsFrontFacing] = useState(false);
  const [measuredPreviewBottom, setMeasuredPreviewBottom] = useState<number>();
  const { latestPhotoUri, openPhotoLibrary } = usePhotoLibrary();
  const preset = presetId ? findPresetById(presetId) : undefined;

  if (!preset) {
    return (
      <CameraErrorLayout onBack={onBack} topInset={top}>
        <Text style={styles.message}>未找到所选构图模版</Text>
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
          <View
            style={[
              styles.canvasSurface,
              viewportSize,
              isLandscape && styles.rotatedCanvas,
            ]}
          >
            <Canvas variant={variant} viewportSize={viewportSize} />
          </View>
        </View>
      </View>
      <CameraControls
        bottomInset={bottom}
        flashEnabled={flashEnabled}
        isFrontFacing={isFrontFacing}
        latestPhotoUri={latestPhotoUri}
        livePhotoEnabled={livePhotoEnabled}
        onBack={onBack}
        onCapture={() => undefined}
        onFlipCamera={() => setIsFrontFacing((current) => !current)}
        onOpenGallery={() => {
          void openPhotoLibrary().catch((error: unknown) => {
            console.error('打开相册失败', error);
          });
        }}
        onToggleFlash={() => setFlashEnabled((current) => !current)}
        onToggleLivePhoto={() => setLivePhotoEnabled((current) => !current)}
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
    backgroundColor: '#242427',
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
