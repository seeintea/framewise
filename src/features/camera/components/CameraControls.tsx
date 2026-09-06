import { useState } from 'react';
import { StyleSheet, View } from 'react-native';

import {
  ACTION_ROW_HEIGHT,
  CameraCaptureControls,
  SHUTTER_SIZE,
  ZOOM_ROW_HEIGHT,
} from './CameraCaptureControls';
import { CameraTopControls } from './CameraTopControls';
import type { LensOption, ZoomOption } from './camera-control.types';

const ZOOM_CANVAS_INSET = 64;
const ZOOM_SHUTTER_GAP = 12;

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

export function CameraControls({
  bottomInset,
  previewBottom,
  ...props
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
      <CameraTopControls {...props} />
      <CameraCaptureControls
        {...props}
        actionRowBottom={actionRowBottom}
        zoomTop={zoomTop}
      />
    </View>
  );
}
