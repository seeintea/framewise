import {
  ChevronLeft,
  CircleDotDashed,
  Ellipsis,
  Images,
  RefreshCw,
  Zap,
  ZapOff,
} from 'lucide-react-native';
import type { ReactNode } from 'react';
import { useState } from 'react';
import { Image, Pressable, StyleSheet, Text, View } from 'react-native';

const ACTION_ROW_HEIGHT = 90;
const ACTIVE_COLOR = '#FFD60A';
const ICON_COLOR = '#FFFFFF';
const SHUTTER_SIZE = 84;
const ZOOM_CANVAS_INSET = 64;
const ZOOM_ROW_HEIGHT = 46;
const ZOOM_SHUTTER_GAP = 12;

type CameraControlsProps = {
  bottomInset: number;
  flashEnabled: boolean;
  isFrontFacing: boolean;
  latestPhotoUri?: string;
  livePhotoEnabled: boolean;
  onBack: () => void;
  onCapture: () => void;
  onFlipCamera: () => void;
  onOpenGallery: () => void;
  onToggleFlash: () => void;
  onToggleLivePhoto: () => void;
  onZoomChange: (zoom: number) => void;
  previewBottom: number;
  selectedZoom: number;
  topInset: number;
  zoomOptions: readonly number[];
};

export function CameraControls({
  bottomInset,
  flashEnabled,
  isFrontFacing,
  latestPhotoUri,
  livePhotoEnabled,
  onBack,
  onCapture,
  onFlipCamera,
  onOpenGallery,
  onToggleFlash,
  onToggleLivePhoto,
  onZoomChange,
  previewBottom,
  selectedZoom,
  topInset,
  zoomOptions,
}: CameraControlsProps) {
  const [controlsHeight, setControlsHeight] = useState(0);
  const actionRowBottom = Math.max(bottomInset + 18, 18);
  const canvasZoomTop = previewBottom - ZOOM_CANVAS_INSET;
  const shutterTop =
    controlsHeight -
    actionRowBottom -
    ACTION_ROW_HEIGHT +
    (ACTION_ROW_HEIGHT - SHUTTER_SIZE) / 2;
  const zoomOverlapsShutter =
    controlsHeight > 0 &&
    canvasZoomTop + ZOOM_ROW_HEIGHT + ZOOM_SHUTTER_GAP > shutterTop;
  const zoomTop = zoomOverlapsShutter
    ? shutterTop - ZOOM_SHUTTER_GAP - ZOOM_ROW_HEIGHT
    : canvasZoomTop;

  return (
    <View
      onLayout={({ nativeEvent }) => {
        setControlsHeight(Math.round(nativeEvent.layout.height));
      }}
      pointerEvents="box-none"
      style={StyleSheet.absoluteFill}
    >
      <View style={[styles.topBar, { top: topInset + 10 }]}>
        <MaterialButton accessibilityLabel="返回" onPress={onBack}>
          <View style={styles.backIcon}>
            <ChevronLeft color={ICON_COLOR} size={24} strokeWidth={1.8} />
          </View>
        </MaterialButton>

        <View style={styles.toolGroup}>
          <ToolButton
            accessibilityLabel={flashEnabled ? '关闭闪光灯' : '打开闪光灯'}
            active={flashEnabled}
            onPress={onToggleFlash}
          >
            {flashEnabled ? (
              <Zap color={ACTIVE_COLOR} size={20} strokeWidth={1.7} />
            ) : (
              <ZapOff color={ICON_COLOR} size={20} strokeWidth={1.7} />
            )}
          </ToolButton>
          <ToolButton
            accessibilityLabel={
              livePhotoEnabled ? '关闭实况照片' : '打开实况照片'
            }
            active={livePhotoEnabled}
            onPress={onToggleLivePhoto}
          >
            <CircleDotDashed
              color={livePhotoEnabled ? ACTIVE_COLOR : ICON_COLOR}
              size={21}
              strokeWidth={1.6}
            />
          </ToolButton>
          <ToolButton accessibilityLabel="更多相机功能">
            <Ellipsis color={ICON_COLOR} size={22} strokeWidth={1.8} />
          </ToolButton>
        </View>
      </View>

      <View style={[styles.zoomRow, { top: zoomTop }]}>
        {zoomOptions.map((zoom) => {
          const selected = zoom === selectedZoom;

          return (
            <Pressable
              key={zoom}
              accessibilityLabel={`${formatZoom(zoom)} 倍率`}
              accessibilityRole="button"
              accessibilityState={{ selected }}
              hitSlop={6}
              onPress={() => onZoomChange(zoom)}
              style={({ pressed }) => [
                styles.zoomButton,
                selected && styles.zoomButtonSelected,
                pressed && styles.controlPressed,
              ]}
            >
              <Text
                style={[styles.zoomLabel, selected && styles.zoomLabelSelected]}
              >
                {formatZoom(zoom)}
              </Text>
            </Pressable>
          );
        })}
      </View>

      <View style={[styles.actionRow, { bottom: actionRowBottom }]}>
        <Pressable
          accessibilityLabel="打开最近照片"
          accessibilityRole="button"
          hitSlop={8}
          onPress={onOpenGallery}
          style={({ pressed }) => [
            styles.galleryButton,
            pressed && styles.controlPressed,
          ]}
        >
          {latestPhotoUri ? (
            <Image
              accessibilityIgnoresInvertColors
              resizeMode="cover"
              source={{ uri: latestPhotoUri }}
              style={styles.galleryImage}
            />
          ) : (
            <View style={styles.galleryPlaceholder}>
              <Images color="#D8D8DC" size={22} strokeWidth={1.6} />
            </View>
          )}
        </Pressable>

        <Pressable
          accessibilityLabel="拍照"
          accessibilityRole="button"
          hitSlop={8}
          onPress={onCapture}
          style={({ pressed }) => [
            styles.shutterOuter,
            pressed && styles.shutterPressed,
          ]}
        >
          <View style={styles.shutterGap}>
            <View style={styles.shutterFace} />
          </View>
        </Pressable>

        <Pressable
          accessibilityLabel="切换前后摄像头"
          accessibilityRole="button"
          hitSlop={8}
          onPress={onFlipCamera}
          style={({ pressed }) => [
            styles.flipButton,
            isFrontFacing && styles.flipButtonFront,
            pressed && styles.controlPressed,
          ]}
        >
          <RefreshCw color={ICON_COLOR} size={29} strokeWidth={1.8} />
        </Pressable>
      </View>
    </View>
  );
}

type MaterialButtonProps = {
  accessibilityLabel: string;
  children: ReactNode;
  onPress?: () => void;
};

function MaterialButton({
  accessibilityLabel,
  children,
  onPress,
}: MaterialButtonProps) {
  return (
    <Pressable
      accessibilityLabel={accessibilityLabel}
      accessibilityRole="button"
      hitSlop={8}
      onPress={onPress}
      style={({ pressed }) => [
        styles.materialButton,
        pressed && styles.controlPressed,
      ]}
    >
      {children}
    </Pressable>
  );
}

type ToolButtonProps = MaterialButtonProps & {
  active?: boolean;
};

function ToolButton({
  accessibilityLabel,
  active = false,
  children,
  onPress,
}: ToolButtonProps) {
  return (
    <Pressable
      accessibilityLabel={accessibilityLabel}
      accessibilityRole="button"
      accessibilityState={{ selected: active }}
      hitSlop={4}
      onPress={onPress}
      style={({ pressed }) => [
        styles.toolButton,
        active && styles.toolButtonActive,
        pressed && styles.controlPressed,
      ]}
    >
      {children}
    </Pressable>
  );
}

function formatZoom(zoom: number): string {
  return zoom < 1 ? zoom.toFixed(1).replace(/^0/, '') : `${zoom}×`;
}

const styles = StyleSheet.create({
  topBar: {
    position: 'absolute',
    right: 16,
    left: 16,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
  },
  materialButton: {
    width: 40,
    height: 40,
    alignItems: 'center',
    justifyContent: 'center',
    borderWidth: StyleSheet.hairlineWidth,
    borderColor: 'rgba(255, 255, 255, 0.09)',
    borderRadius: 20,
    backgroundColor: 'rgba(38, 38, 41, 0.82)',
  },
  backIcon: {
    transform: [{ translateX: -1 }],
  },
  toolGroup: {
    height: 40,
    flexDirection: 'row',
    alignItems: 'center',
    gap: 2,
    paddingHorizontal: 4,
    borderWidth: StyleSheet.hairlineWidth,
    borderColor: 'rgba(255, 255, 255, 0.09)',
    borderRadius: 20,
    backgroundColor: 'rgba(38, 38, 41, 0.82)',
  },
  toolButton: {
    width: 38,
    height: 36,
    alignItems: 'center',
    justifyContent: 'center',
    borderRadius: 18,
  },
  toolButtonActive: {
    backgroundColor: 'rgba(255, 214, 10, 0.1)',
  },
  zoomRow: {
    position: 'absolute',
    alignSelf: 'center',
    height: ZOOM_ROW_HEIGHT,
    flexDirection: 'row',
    alignItems: 'center',
    gap: 4,
    paddingHorizontal: 5,
  },
  zoomButton: {
    minWidth: 36,
    height: 36,
    alignItems: 'center',
    justifyContent: 'center',
    paddingHorizontal: 7,
    borderRadius: 18,
  },
  zoomButtonSelected: {
    backgroundColor: 'rgba(74, 72, 77, 0.96)',
  },
  zoomLabel: {
    color: '#FFFFFF',
    fontSize: 14,
    lineHeight: 18,
    fontWeight: '300',
    letterSpacing: -0.3,
    fontVariant: ['tabular-nums'],
  },
  zoomLabelSelected: {
    color: ACTIVE_COLOR,
    fontWeight: '300',
  },
  actionRow: {
    position: 'absolute',
    right: 24,
    left: 24,
    height: ACTION_ROW_HEIGHT,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
  },
  galleryButton: {
    width: 58,
    height: 58,
    overflow: 'hidden',
    borderWidth: StyleSheet.hairlineWidth,
    borderColor: 'rgba(255, 255, 255, 0.16)',
    borderRadius: 29,
    backgroundColor: '#29292C',
  },
  galleryPlaceholder: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
    margin: 3,
    borderRadius: 25,
    backgroundColor: '#3A3A3E',
  },
  galleryImage: {
    width: '100%',
    height: '100%',
  },
  shutterOuter: {
    position: 'absolute',
    left: '50%',
    width: SHUTTER_SIZE,
    height: SHUTTER_SIZE,
    alignItems: 'center',
    justifyContent: 'center',
    marginLeft: -42,
    borderRadius: 42,
    backgroundColor: 'rgba(235, 235, 240, 0.58)',
  },
  shutterGap: {
    width: 76,
    height: 76,
    alignItems: 'center',
    justifyContent: 'center',
    borderRadius: 38,
    backgroundColor: '#111113',
  },
  shutterFace: {
    width: 68,
    height: 68,
    borderRadius: 34,
    backgroundColor: '#FFFFFF',
  },
  shutterPressed: {
    opacity: 0.86,
    transform: [{ scale: 0.94 }],
  },
  flipButton: {
    width: 58,
    height: 58,
    alignItems: 'center',
    justifyContent: 'center',
    borderWidth: StyleSheet.hairlineWidth,
    borderColor: 'rgba(255, 255, 255, 0.09)',
    borderRadius: 29,
    backgroundColor: '#29292C',
  },
  flipButtonFront: {
    transform: [{ rotate: '180deg' }],
  },
  controlPressed: {
    opacity: 0.7,
    transform: [{ scale: 0.94 }],
  },
});
