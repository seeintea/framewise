import { ChevronLeft } from 'lucide-react-native';
import type { ReactNode } from 'react';
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

type CameraProps = {
  onBack: () => void;
  presetId?: string;
};

export function Camera({ onBack, presetId }: CameraProps) {
  const windowSize = useWindowDimensions();
  const preset = presetId ? findPresetById(presetId) : undefined;

  if (!preset) {
    return (
      <CameraLayout onBack={onBack}>
        <Text style={styles.message}>未找到所选构图模版</Text>
      </CameraLayout>
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

  return (
    <CameraLayout onBack={onBack}>
      <View style={[styles.canvasFrame, displaySize]}>
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
    </CameraLayout>
  );
}

type CameraLayoutProps = {
  children: ReactNode;
  onBack: () => void;
};

function CameraLayout({ children, onBack }: CameraLayoutProps) {
  const { top } = useSafeAreaInsets();

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
          { top: top + 8 },
          pressed && styles.backButtonPressed,
        ]}
      >
        <ChevronLeft color="#FFFFFF" size={28} strokeWidth={2.5} />
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
  canvasFrame: {
    alignItems: 'center',
    justifyContent: 'center',
  },
  canvasSurface: {
    backgroundColor: '#FFFFFF',
  },
  rotatedCanvas: {
    transform: [{ rotate: '90deg' }],
  },
  message: {
    color: '#FFFFFF',
    fontSize: 16,
  },
});
