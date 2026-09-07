import type { CameraCapabilities } from './components/camera-viewport.types';

export type CameraState = {
  capabilities?: CameraCapabilities;
  exposureCompensation: number;
  flashEnabled: boolean;
  isFrontFacing: boolean;
  isReady: boolean;
  selectedLensId?: string;
  zoomRatio: number;
};

export const initialCameraState: CameraState = {
  exposureCompensation: 0,
  flashEnabled: false,
  isFrontFacing: false,
  isReady: false,
  zoomRatio: 1,
};

export type CameraAction =
  | { type: 'capabilities-changed'; capabilities: CameraCapabilities }
  | { type: 'camera-ready' }
  | { type: 'camera-failed' }
  | { type: 'exposure-changed'; exposureCompensation: number }
  | { type: 'flash-toggled' }
  | { type: 'camera-flipped' }
  | { type: 'zoom-preset-selected'; lensId: string; zoomRatio: number }
  | { type: 'zoom-changed'; zoomRatio: number };

export function cameraReducer(
  state: CameraState,
  action: CameraAction,
): CameraState {
  switch (action.type) {
    case 'capabilities-changed':
      return {
        ...state,
        capabilities: action.capabilities,
        selectedLensId: action.capabilities.activeLensId,
        zoomRatio: action.capabilities.zoomRatio,
        exposureCompensation: action.capabilities.exposureCompensation,
      };
    case 'camera-ready':
      return { ...state, isReady: true };
    case 'camera-failed':
      return { ...state, isReady: false };
    case 'exposure-changed':
      return {
        ...state,
        exposureCompensation: action.exposureCompensation,
      };
    case 'flash-toggled':
      return { ...state, flashEnabled: !state.flashEnabled };
    case 'camera-flipped':
      return {
        ...initialCameraState,
        isFrontFacing: !state.isFrontFacing,
      };
    case 'zoom-preset-selected':
      if (action.lensId === state.selectedLensId) {
        return { ...state, zoomRatio: action.zoomRatio };
      }

      return {
        ...state,
        isReady: false,
        selectedLensId: action.lensId,
        zoomRatio: action.zoomRatio,
        exposureCompensation: 0,
        flashEnabled: false,
      };
    case 'zoom-changed':
      return { ...state, zoomRatio: action.zoomRatio };
  }
}
