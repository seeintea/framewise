import { Component } from 'react';
import {
  PanResponder,
  StyleSheet,
  View,
  type GestureResponderEvent,
} from 'react-native';

const MIN_ZOOM = 0;
const MAX_ZOOM = 1;
const PINCH_ZOOM_SENSITIVITY = 0.2;

function getTouchDistance(event: GestureResponderEvent): number | undefined {
  const [firstTouch, secondTouch] = event.nativeEvent.touches;

  if (!firstTouch || !secondTouch) {
    return undefined;
  }

  return Math.hypot(
    secondTouch.pageX - firstTouch.pageX,
    secondTouch.pageY - firstTouch.pageY,
  );
}

type PinchZoomLayerProps = {
  onZoomChange: (zoom: number) => void;
  zoom: number;
};

export class PinchZoomLayer extends Component<PinchZoomLayerProps> {
  private startDistance: number | undefined;
  private startZoom = 0;

  private readonly responder = PanResponder.create({
    onStartShouldSetPanResponder: (event) =>
      event.nativeEvent.touches.length === 2,
    onMoveShouldSetPanResponder: (event) =>
      event.nativeEvent.touches.length === 2,
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
      const zoom = Math.min(
        MAX_ZOOM,
        Math.max(
          MIN_ZOOM,
          this.startZoom + scaleDelta * PINCH_ZOOM_SENSITIVITY,
        ),
      );

      this.props.onZoomChange(zoom);
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
      <View style={StyleSheet.absoluteFill} {...this.responder.panHandlers} />
    );
  }
}
