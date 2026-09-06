import {
  ChevronLeft,
  CircleHelp,
  Images,
  Minus,
  Plus,
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
const LENS_ROW_GAP = 38;

type CameraControlsProps = {
  bottomInset: number;
  cameraInfoLabel?: string;
  captureDisabled: boolean;
  captureStatus?: string;
  exposureCompensation: number;
  exposureMaximum: number;
  exposureMinimum: number;
  exposureStep: number;
  flashEnabled: boolean;
  flashSupported: boolean;
  guidanceInstruction: string;
  guidanceTitle: string;
  guidanceVisible: boolean;
  isFrontFacing: boolean;
  latestPhotoUri?: string;
  lensOptions: readonly LensOption[];
  onBack: () => void;
  onCapture: () => void;
  onExposureChange: (index: number) => void;
  onFlipCamera: () => void;
  onLensChange: (lensId: string) => void;
  onOpenGallery: () => void;
  onToggleFlash: () => void;
  onToggleGuidance: () => void;
  onZoomRatioChange: (zoomRatio: number) => void;
  previewBottom: number;
  selectedLensId?: string;
  selectedZoomRatio: number;
  topInset: number;
  zoomOptions: readonly ZoomOption[];
};

type ZoomOption = {
  label: string;
  value: number;
};

type LensOption = {
  id: string;
  label: string;
};

export function CameraControls({
  bottomInset,
  cameraInfoLabel,
  exposureCompensation,
  exposureMaximum,
  exposureMinimum,
  exposureStep,
  flashEnabled,
  flashSupported,
  guidanceInstruction,
  guidanceTitle,
  guidanceVisible,
  isFrontFacing,
  captureDisabled,
  captureStatus,
  latestPhotoUri,
  lensOptions,
  onBack,
  onCapture,
  onExposureChange,
  onFlipCamera,
  onLensChange,
  onOpenGallery,
  onToggleFlash,
  onToggleGuidance,
  onZoomRatioChange,
  previewBottom,
  selectedLensId,
  selectedZoomRatio,
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

        <View style={styles.topActions}>
          {exposureMinimum < exposureMaximum && (
            <View style={styles.toolGroup}>
              <ToolButton
                accessibilityLabel="降低曝光"
                disabled={exposureCompensation <= exposureMinimum}
                onPress={() => onExposureChange(exposureCompensation - 1)}
              >
                <Minus color={ICON_COLOR} size={16} strokeWidth={1.8} />
              </ToolButton>
              <Text style={styles.exposureLabel}>
                {(exposureCompensation * exposureStep).toFixed(1)}
              </Text>
              <ToolButton
                accessibilityLabel="提高曝光"
                disabled={exposureCompensation >= exposureMaximum}
                onPress={() => onExposureChange(exposureCompensation + 1)}
              >
                <Plus color={ICON_COLOR} size={16} strokeWidth={1.8} />
              </ToolButton>
            </View>
          )}

          {flashSupported && (
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
            </View>
          )}

          <MaterialButton
            accessibilityLabel={
              guidanceVisible ? '隐藏构图指引' : '查看构图指引'
            }
            onPress={onToggleGuidance}
          >
            <CircleHelp color={ICON_COLOR} size={21} strokeWidth={1.7} />
          </MaterialButton>
        </View>
      </View>

      {guidanceVisible && (
        <View
          pointerEvents="none"
          style={[styles.guidance, { top: topInset + 62 }]}
        >
          <Text style={styles.guidanceTitle}>{guidanceTitle}</Text>
          <Text style={styles.guidanceInstruction}>{guidanceInstruction}</Text>
        </View>
      )}

      {cameraInfoLabel && (
        <View
          pointerEvents="none"
          style={[
            styles.cameraInfo,
            { top: topInset + (guidanceVisible ? 126 : 62) },
          ]}
        >
          <Text numberOfLines={2} style={styles.cameraInfoLabel}>
            {cameraInfoLabel}
          </Text>
        </View>
      )}

      {lensOptions.length > 1 && (
        <View style={[styles.lensRow, { top: zoomTop - LENS_ROW_GAP }]}>
          {lensOptions.map((option) => {
            const selected = option.id === selectedLensId;

            return (
              <Pressable
                key={option.id}
                accessibilityLabel={`选择镜头 ${option.label}`}
                accessibilityRole="button"
                accessibilityState={{ selected }}
                onPress={() => onLensChange(option.id)}
                style={({ pressed }) => [
                  styles.lensButton,
                  selected && styles.lensButtonSelected,
                  pressed && styles.controlPressed,
                ]}
              >
                <Text
                  style={[
                    styles.lensLabel,
                    selected && styles.lensLabelSelected,
                  ]}
                >
                  {option.label}
                </Text>
              </Pressable>
            );
          })}
        </View>
      )}

      <View style={[styles.zoomRow, { top: zoomTop }]}>
        {zoomOptions.map((option) => {
          const selected = Math.abs(option.value - selectedZoomRatio) < 0.01;

          return (
            <Pressable
              key={option.label}
              accessibilityLabel={`相机缩放 ${option.label}`}
              accessibilityRole="button"
              accessibilityState={{ selected }}
              hitSlop={6}
              onPress={() => onZoomRatioChange(option.value)}
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
  disabled?: boolean;
};

function ToolButton({
  accessibilityLabel,
  active = false,
  children,
  disabled = false,
  onPress,
}: ToolButtonProps) {
  return (
    <Pressable
      accessibilityLabel={accessibilityLabel}
      accessibilityRole="button"
      accessibilityState={{ selected: active }}
      disabled={disabled}
      hitSlop={4}
      onPress={onPress}
      style={({ pressed }) => [
        styles.toolButton,
        active && styles.toolButtonActive,
        disabled && styles.toolButtonDisabled,
        pressed && styles.controlPressed,
      ]}
    >
      {children}
    </Pressable>
  );
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
  topActions: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
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
  toolButtonDisabled: {
    opacity: 0.35,
  },
  exposureLabel: {
    minWidth: 34,
    color: '#FFFFFF',
    fontSize: 11,
    lineHeight: 16,
    textAlign: 'center',
    fontVariant: ['tabular-nums'],
  },
  guidance: {
    position: 'absolute',
    right: 24,
    left: 24,
    alignItems: 'center',
    gap: 2,
    paddingHorizontal: 18,
    paddingVertical: 10,
    borderWidth: StyleSheet.hairlineWidth,
    borderColor: 'rgba(255, 255, 255, 0.1)',
    borderRadius: 14,
    backgroundColor: 'rgba(24, 24, 27, 0.78)',
  },
  guidanceTitle: {
    color: '#FFFFFF',
    fontSize: 13,
    lineHeight: 18,
    fontWeight: '600',
  },
  guidanceInstruction: {
    color: '#E8E8EC',
    fontSize: 13,
    lineHeight: 18,
    textAlign: 'center',
  },
  cameraInfo: {
    position: 'absolute',
    left: 18,
    maxWidth: '82%',
    paddingHorizontal: 9,
    paddingVertical: 5,
    borderRadius: 9,
    backgroundColor: 'rgba(24, 24, 27, 0.68)',
  },
  cameraInfoLabel: {
    color: '#D8D8DC',
    fontSize: 10,
    lineHeight: 14,
    fontVariant: ['tabular-nums'],
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
  lensRow: {
    position: 'absolute',
    alignSelf: 'center',
    flexDirection: 'row',
    alignItems: 'center',
    gap: 6,
    paddingHorizontal: 6,
  },
  lensButton: {
    height: 30,
    justifyContent: 'center',
    paddingHorizontal: 10,
    borderRadius: 15,
    backgroundColor: 'rgba(38, 38, 41, 0.72)',
  },
  lensButtonSelected: {
    backgroundColor: 'rgba(74, 72, 77, 0.96)',
  },
  lensLabel: {
    color: '#FFFFFF',
    fontSize: 11,
    lineHeight: 15,
    fontVariant: ['tabular-nums'],
  },
  lensLabelSelected: {
    color: ACTIVE_COLOR,
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
