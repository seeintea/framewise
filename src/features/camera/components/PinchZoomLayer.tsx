import { Component } from 'react';
import { Sun } from 'lucide-react-native';
import {
  PanResponder,
  StyleSheet,
  View,
  type GestureResponderEvent,
} from 'react-native';

const TAP_MOVEMENT_TOLERANCE = 8;
const FOCUS_INDICATOR_DURATION_MS = 2200;
const FOCUS_INDICATOR_SIZE = 64;
const EXPOSURE_DRAG_DISTANCE = 220;
const EXPOSURE_GESTURE_RADIUS = 88;
const EXPOSURE_TRACK_HEIGHT = 92;
const EXPOSURE_ICON_SIZE = 22;

type Point = {
  x: number;
  y: number;
};

type PinchZoomLayerProps = {
  exposureCompensation: number;
  exposureMaximum: number;
  exposureMinimum: number;
  maximumZoomRatio: number;
  minimumZoomRatio: number;
  onExposureChange: (index: number) => void;
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
  private exposureStart?: number;
  private exposureMoved = false;
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
        this.exposureStart = undefined;
        return;
      }

      const touchPoint = {
        x: event.nativeEvent.locationX,
        y: event.nativeEvent.locationY,
      };
      this.tapStart = touchPoint;
      this.tapMoved = false;
      this.exposureMoved = false;
      this.exposureStart =
        this.state.focusPoint &&
        this.supportsExposureAdjustment() &&
        getPointDistance(touchPoint, this.state.focusPoint) <=
          EXPOSURE_GESTURE_RADIUS
          ? this.props.exposureCompensation
          : undefined;
    },
    onPanResponderMove: (event) => {
      if (event.nativeEvent.touches.length === 2) {
        const distance = getTouchDistance(event);

        if (!distance) {
          return;
        }

        if (!this.startDistance) {
          this.startDistance = distance;
          this.startZoomRatio = this.props.zoomRatio;
          this.tapStart = undefined;
          this.exposureStart = undefined;
          return;
        }

        const nextZoomRatio = Math.min(
          this.props.maximumZoomRatio,
          Math.max(
            this.props.minimumZoomRatio,
            this.startZoomRatio * (distance / this.startDistance),
          ),
        );

        this.props.onZoomRatioChange(nextZoomRatio);
        return;
      }

      if (this.tapStart) {
        const verticalMovement = this.tapStart.y - event.nativeEvent.locationY;
        const movement = Math.hypot(
          event.nativeEvent.locationX - this.tapStart.x,
          event.nativeEvent.locationY - this.tapStart.y,
        );
        this.tapMoved ||= movement > TAP_MOVEMENT_TOLERANCE;

        if (
          this.exposureStart !== undefined &&
          Math.abs(verticalMovement) > TAP_MOVEMENT_TOLERANCE
        ) {
          const exposureRange =
            this.props.exposureMaximum - this.props.exposureMinimum;
          const nextExposure = Math.round(
            this.exposureStart +
              (verticalMovement / EXPOSURE_DRAG_DISTANCE) * exposureRange,
          );
          this.exposureMoved = true;
          const clampedExposure = Math.min(
            this.props.exposureMaximum,
            Math.max(this.props.exposureMinimum, nextExposure),
          );
          if (clampedExposure !== this.props.exposureCompensation) {
            this.props.onExposureChange(clampedExposure);
          }
          this.scheduleFocusIndicatorDismissal();
        }
      }
    },
    onPanResponderRelease: () => {
      if (
        this.tapStart &&
        !this.tapMoved &&
        (this.props.supportsFocusMetering ||
          this.supportsExposureAdjustment()) &&
        this.layoutSize.width > 0 &&
        this.layoutSize.height > 0
      ) {
        const focusPoint = this.tapStart;
        if (this.props.supportsFocusMetering) {
          this.props.onFocusAt(
            focusPoint.x / this.layoutSize.width,
            focusPoint.y / this.layoutSize.height,
          );
        }
        this.showFocusIndicator(focusPoint);
      } else if (this.exposureMoved) {
        this.scheduleFocusIndicatorDismissal();
      }

      this.resetGesture();
    },
    onPanResponderTerminate: () => this.resetGesture(),
  });

  private resetGesture() {
    this.startDistance = undefined;
    this.tapStart = undefined;
    this.tapMoved = false;
    this.exposureStart = undefined;
    this.exposureMoved = false;
  }

  private showFocusIndicator(focusPoint: Point) {
    if (this.focusIndicatorTimeout) {
      clearTimeout(this.focusIndicatorTimeout);
    }
    this.setState({ focusPoint });
    this.scheduleFocusIndicatorDismissal();
  }

  private scheduleFocusIndicatorDismissal() {
    if (this.focusIndicatorTimeout) {
      clearTimeout(this.focusIndicatorTimeout);
    }
    this.focusIndicatorTimeout = setTimeout(
      () => this.setState({ focusPoint: undefined }),
      FOCUS_INDICATOR_DURATION_MS,
    );
  }

  private supportsExposureAdjustment() {
    return this.props.exposureMinimum < this.props.exposureMaximum;
  }

  render() {
    const { focusPoint } = this.state;
    const exposureRange =
      this.props.exposureMaximum - this.props.exposureMinimum;
    const normalizedExposure = exposureRange
      ? (this.props.exposureCompensation - this.props.exposureMinimum) /
        exposureRange
      : 0.5;
    const exposureLeft = focusPoint
      ? focusPoint.x + FOCUS_INDICATOR_SIZE / 2 + 8 + EXPOSURE_ICON_SIZE >
        this.layoutSize.width
        ? focusPoint.x - FOCUS_INDICATOR_SIZE / 2 - 8 - EXPOSURE_ICON_SIZE
        : focusPoint.x + FOCUS_INDICATOR_SIZE / 2 + 8
      : 0;
    const exposureTop = focusPoint
      ? Math.min(
          this.layoutSize.height - EXPOSURE_TRACK_HEIGHT - 6,
          Math.max(6, focusPoint.y - EXPOSURE_TRACK_HEIGHT / 2),
        )
      : 0;

    return (
      <View
        accessibilityLabel="点击对焦，对焦框旁上下拖动调曝光，双指缩放相机"
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
                left: focusPoint.x - FOCUS_INDICATOR_SIZE / 2,
                top: focusPoint.y - FOCUS_INDICATOR_SIZE / 2,
              },
            ]}
          />
        )}
        {focusPoint && this.supportsExposureAdjustment() && (
          <View
            pointerEvents="none"
            style={[
              styles.exposureControl,
              { left: exposureLeft, top: exposureTop },
            ]}
          >
            <View style={styles.exposureTrack} />
            <Sun
              color="#FFD60A"
              size={EXPOSURE_ICON_SIZE}
              strokeWidth={1.8}
              style={[
                styles.exposureIcon,
                {
                  top:
                    (1 - normalizedExposure) *
                    (EXPOSURE_TRACK_HEIGHT - EXPOSURE_ICON_SIZE),
                },
              ]}
            />
          </View>
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

function getPointDistance(first: Point, second: Point) {
  return Math.hypot(second.x - first.x, second.y - first.y);
}

const styles = StyleSheet.create({
  focusIndicator: {
    position: 'absolute',
    width: FOCUS_INDICATOR_SIZE,
    height: FOCUS_INDICATOR_SIZE,
    borderWidth: 1.5,
    borderColor: '#FFD60A',
    borderRadius: 3,
  },
  exposureControl: {
    position: 'absolute',
    width: EXPOSURE_ICON_SIZE,
    height: EXPOSURE_TRACK_HEIGHT,
    alignItems: 'center',
  },
  exposureTrack: {
    position: 'absolute',
    top: EXPOSURE_ICON_SIZE / 2,
    bottom: EXPOSURE_ICON_SIZE / 2,
    width: StyleSheet.hairlineWidth,
    backgroundColor: 'rgba(255, 214, 10, 0.62)',
  },
  exposureIcon: {
    position: 'absolute',
  },
});
