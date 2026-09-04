import { Component } from 'react';
import {
  PanResponder,
  StyleSheet,
  View,
  type GestureResponderEvent,
} from 'react-native';

const MIN_ZOOM = 0;
const MAX_ZOOM = 1;
const PINCH_ZOOM_SENSITIVITY = 0.35;

type PinchZoomLayerProps = {
  onZoomChange: (zoom: number) => void;
  zoom: number;
};

export class PinchZoomLayer extends Component<PinchZoomLayerProps> {
  private startDistance: number | undefined;
  private startZoom = MIN_ZOOM;

  private readonly responder = PanResponder.create({
    onStartShouldSetPanResponder: ({ nativeEvent }) =>
      nativeEvent.touches.length === 2,
    onMoveShouldSetPanResponder: ({ nativeEvent }) =>
      nativeEvent.touches.length === 2,
    onPanResponderGrant: (event) => {
      this.startDistance = getTouchDistance(event);
      this.startZoom = this.props.zoom;
    },
    onPanResponderMove: (event) => {
      const distance = getTouchDistance(event);

      if (!distance || !this.startDistance) {
        return;
      }

      const scaleDelta = distance / this.startDistance - 1;
      const nextZoom = Math.min(
        MAX_ZOOM,
        Math.max(
          MIN_ZOOM,
          this.startZoom + scaleDelta * PINCH_ZOOM_SENSITIVITY,
        ),
      );

      this.props.onZoomChange(nextZoom);
    },
    onPanResponderRelease: () => {
      this.startDistance = undefined;
    },
    onPanResponderTerminate: () => {
      this.startDistance = undefined;
    },
  });

  render() {
    return (
      <View
        accessibilityLabel="双指缩放相机"
        style={StyleSheet.absoluteFill}
        {...this.responder.panHandlers}
      />
    );
  }
}

function getTouchDistance(event: GestureResponderEvent) {
  const [firstTouch, secondTouch] = event.nativeEvent.touches;

  if (!firstTouch || !secondTouch) {
    return undefined;
  }

  return Math.hypot(
    secondTouch.pageX - firstTouch.pageX,
    secondTouch.pageY - firstTouch.pageY,
  );
}
