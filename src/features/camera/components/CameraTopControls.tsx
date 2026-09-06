import {
  ChevronLeft,
  CircleHelp,
  Minus,
  Plus,
  Zap,
  ZapOff,
} from 'lucide-react-native';
import type { ReactNode } from 'react';
import { Pressable, StyleSheet, Text, View } from 'react-native';

const ACTIVE_COLOR = '#FFD60A';
const ICON_COLOR = '#FFFFFF';

type CameraTopControlsProps = {
  cameraInfoLabel?: string;
  exposureCompensation: number;
  exposureMaximum: number;
  exposureMinimum: number;
  exposureStep: number;
  flashEnabled: boolean;
  flashSupported: boolean;
  guidanceInstruction: string;
  guidanceTitle: string;
  guidanceVisible: boolean;
  onBack: () => void;
  onExposureChange: (index: number) => void;
  onToggleFlash: () => void;
  onToggleGuidance: () => void;
  topInset: number;
};

export function CameraTopControls({
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
  onBack,
  onExposureChange,
  onToggleFlash,
  onToggleGuidance,
  topInset,
}: CameraTopControlsProps) {
  return (
    <>
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
    </>
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
  controlPressed: {
    opacity: 0.7,
    transform: [{ scale: 0.94 }],
  },
});
