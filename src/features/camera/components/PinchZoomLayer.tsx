import { Component } from 'react';
import {
  PanResponder,
  StyleSheet,
  View,
  type GestureResponderEvent,
} from 'react-native';

const PINCH_ZOOM_SENSITIVITY = 0.35;
const TAP_MOVEMENT_TOLERANCE = 8;
const FOCUS_INDICATOR_DURATION_MS = 900;

type Point = {
  x: number;
  y: number;
};

type PinchZoomLayerProps = {
  maximumZoomRatio: number;
  minimumZoomRatio: number;
  onFocusAt: (x: number, y: number) => void;
  onZoomRatioChange: (zoomRatio: number) => void;
  supportsFocusMetering: boolean;
  zoomRatio: number;
};

type PinchZoomLayerState = {
  focusPoint?: Point;
};

export class PinchZoomLayer extends Component<
  PinchZoomLayerProps,
  PinchZoomLayerState
> {
  state: PinchZoomLayerState = {};

  private focusIndicatorTimeout?: ReturnType<typeof setTimeout>;
  private layoutSize = { width: 0, height: 0 };
  private startDistance?: number;
  private startZoomRatio = 1;
  private tapStart?: Point;
  private tapMoved = false;

  componentWillUnmount() {
    if (this.focusIndicatorTimeout) {
      clearTimeout(this.focusIndicatorTimeout);
    }
  }

  private readonly responder = PanResponder.create({
    onStartShouldSetPanResponder: () => true,
    onMoveShouldSetPanResponder: () => true,
    onPanResponderGrant: (event) => {
      if (event.nativeEvent.touches.length === 2) {
        this.startDistance = getTouchDistance(event);
        this.startZoomRatio = this.props.zoomRatio;
        this.tapStart = undefined;
        return;
      }

      this.tapStart = {
        x: event.nativeEvent.locationX,
        y: event.nativeEvent.locationY,
      };
      this.tapMoved = false;
    },
    onPanResponderMove: (event) => {
      if (event.nativeEvent.touches.length === 2) {
        const distance = getTouchDistance(event);

        if (!distance || !this.startDistance) {
          return;
        }

        const scaleDelta = distance / this.startDistance - 1;
        const zoomRange =
          this.props.maximumZoomRatio - this.props.minimumZoomRatio;
        const nextZoomRatio = Math.min(
          this.props.maximumZoomRatio,
          Math.max(
            this.props.minimumZoomRatio,
            this.startZoomRatio +
              scaleDelta * zoomRange * PINCH_ZOOM_SENSITIVITY,
          ),
        );

        this.props.onZoomRatioChange(nextZoomRatio);
        return;
      }

      if (this.tapStart) {
        const movement = Math.hypot(
          event.nativeEvent.locationX - this.tapStart.x,
          event.nativeEvent.locationY - this.tapStart.y,
        );
        this.tapMoved ||= movement > TAP_MOVEMENT_TOLERANCE;
      }
    },
    onPanResponderRelease: () => {
      if (
        this.tapStart &&
        !this.tapMoved &&
        this.props.supportsFocusMetering &&
        this.layoutSize.width > 0 &&
        this.layoutSize.height > 0
      ) {
        const focusPoint = this.tapStart;
        this.props.onFocusAt(
          focusPoint.x / this.layoutSize.width,
          focusPoint.y / this.layoutSize.height,
        );
        this.showFocusIndicator(focusPoint);
      }

      this.resetGesture();
    },
    onPanResponderTerminate: () => this.resetGesture(),
  });

  private resetGesture() {
    this.startDistance = undefined;
    this.tapStart = undefined;
    this.tapMoved = false;
  }

  private showFocusIndicator(focusPoint: Point) {
    if (this.focusIndicatorTimeout) {
      clearTimeout(this.focusIndicatorTimeout);
    }
    this.setState({ focusPoint });
    this.focusIndicatorTimeout = setTimeout(
      () => this.setState({ focusPoint: undefined }),
      FOCUS_INDICATOR_DURATION_MS,
    );
  }

  render() {
    const { focusPoint } = this.state;

    return (
      <View
        accessibilityLabel="点击聚焦，双指缩放相机"
        onLayout={({ nativeEvent }) => {
          this.layoutSize = nativeEvent.layout;
        }}
        style={StyleSheet.absoluteFill}
        {...this.responder.panHandlers}
      >
        {focusPoint && (
          <View
            pointerEvents="none"
            style={[
              styles.focusIndicator,
              {
                left: focusPoint.x - 28,
                top: focusPoint.y - 28,
              },
            ]}
          />
        )}
      </View>
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

const styles = StyleSheet.create({
  focusIndicator: {
    position: 'absolute',
    width: 56,
    height: 56,
    borderWidth: 1.5,
    borderColor: '#FFD60A',
    borderRadius: 28,
  },
});
