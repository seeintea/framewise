import { Images, RefreshCw } from 'lucide-react-native';
import { Image, Pressable, StyleSheet, Text, View } from 'react-native';

import type { ZoomOption } from './camera-control.types';

export const ACTION_ROW_HEIGHT = 90;
export const SHUTTER_SIZE = 84;
export const ZOOM_ROW_HEIGHT = 46;
const ACTIVE_COLOR = '#FFD60A';
const ICON_COLOR = '#FFFFFF';

type CameraCaptureControlsProps = {
  actionRowBottom: number;
  captureDisabled: boolean;
  captureStatus?: string;
  isFrontFacing: boolean;
  latestPhotoUri?: string;
  onCapture: () => void;
  onFlipCamera: () => void;
  onOpenGallery: () => void;
  onZoomPresetSelect: (option: ZoomOption) => void;
  selectedLensId?: string;
  selectedZoomRatio: number;
  zoomOptions: readonly ZoomOption[];
  zoomTop: number;
};

export function CameraCaptureControls({
  actionRowBottom,
  captureDisabled,
  captureStatus,
  isFrontFacing,
  latestPhotoUri,
  onCapture,
  onFlipCamera,
  onOpenGallery,
  onZoomPresetSelect,
  selectedLensId,
  selectedZoomRatio,
  zoomOptions,
  zoomTop,
}: CameraCaptureControlsProps) {
  return (
    <>
      <View style={[styles.zoomRow, { top: zoomTop }]}>
        {zoomOptions.map((option) => {
          const selected =
            option.lensId === selectedLensId &&
            Math.abs(option.zoomRatio - selectedZoomRatio) < 0.01;

          return (
            <Pressable
              key={`${option.lensId}:${option.zoomRatio}`}
              accessibilityLabel={`相机缩放 ${option.label}`}
              accessibilityRole="button"
              accessibilityState={{ selected }}
              hitSlop={6}
              onPress={() => onZoomPresetSelect(option)}
              style={({ pressed }) => [
                styles.zoomButton,
                selected && styles.zoomButtonSelected,
                pressed && styles.controlPressed,
              ]}
            >
              <Text
                style={[styles.zoomLabel, selected && styles.zoomLabelSelected]}
              >
                {option.label}
              </Text>
            </Pressable>
          );
        })}
      </View>

      {captureStatus && (
        <View
          pointerEvents="none"
          style={[
            styles.captureStatus,
            { bottom: actionRowBottom + ACTION_ROW_HEIGHT + 8 },
          ]}
        >
          <Text style={styles.captureStatusLabel}>{captureStatus}</Text>
        </View>
      )}

      <View style={[styles.actionRow, { bottom: actionRowBottom }]}>
        <Pressable
          accessibilityLabel="打开相册"
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
          accessibilityState={{ disabled: captureDisabled }}
          disabled={captureDisabled}
          hitSlop={8}
          onPress={onCapture}
          style={({ pressed }) => [
            styles.shutterOuter,
            captureDisabled && styles.shutterDisabled,
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
    </>
  );
}

const styles = StyleSheet.create({
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
  captureStatus: {
    position: 'absolute',
    alignSelf: 'center',
    paddingHorizontal: 14,
    paddingVertical: 8,
    borderRadius: 16,
    backgroundColor: 'rgba(24, 24, 27, 0.82)',
  },
  captureStatusLabel: {
    color: '#FFFFFF',
    fontSize: 13,
    lineHeight: 18,
    fontWeight: '500',
  },
  galleryButton: {
    width: 58,
    height: 58,
    alignItems: 'center',
    justifyContent: 'center',
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
    objectFit: 'cover',
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
  shutterDisabled: {
    opacity: 0.5,
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
