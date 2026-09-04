import { useState } from 'react';
import { StyleSheet, Text, View } from 'react-native';

import type { CompositionAnnotation } from '@/canvas/types';
import type { Point, Size } from '@/types';

const VIEWPORT_INSET = 8;

type TemplateAnnotationsProps = {
  annotations: CompositionAnnotation[];
  isLandscape: boolean;
  viewportSize: Size;
};

export function TemplateAnnotations({
  annotations,
  isLandscape,
  viewportSize,
}: TemplateAnnotationsProps) {
  return (
    <View pointerEvents="none" style={StyleSheet.absoluteFill}>
      {annotations.map((annotation) => (
        <TemplateAnnotation
          key={annotation.id}
          annotation={annotation}
          position={resolveAnnotationPosition(
            annotation.position,
            viewportSize,
            isLandscape,
          )}
          isLandscape={isLandscape}
          viewportSize={viewportSize}
        />
      ))}
    </View>
  );
}

type TemplateAnnotationProps = {
  annotation: CompositionAnnotation;
  isLandscape: boolean;
  position: Point;
  viewportSize: Size;
};

function TemplateAnnotation({
  annotation,
  isLandscape,
  position,
  viewportSize,
}: TemplateAnnotationProps) {
  const [labelSize, setLabelSize] = useState<Size>();
  const visualSize = labelSize
    ? isLandscape
      ? { width: labelSize.height, height: labelSize.width }
      : labelSize
    : undefined;
  const center = visualSize
    ? {
        x: Math.min(
          Math.max(position.x, VIEWPORT_INSET + visualSize.width / 2),
          viewportSize.width - VIEWPORT_INSET - visualSize.width / 2,
        ),
        y: Math.min(
          Math.max(position.y, VIEWPORT_INSET + visualSize.height / 2),
          viewportSize.height - VIEWPORT_INSET - visualSize.height / 2,
        ),
      }
    : position;
  const maxWidth =
    annotation.maxWidth === undefined
      ? undefined
      : annotation.maxWidth *
        (isLandscape ? viewportSize.height : viewportSize.width);

  return (
    <Text
      numberOfLines={annotation.maxWidth === undefined ? 1 : undefined}
      onLayout={({ nativeEvent }) => {
        const { width, height } = nativeEvent.layout;
        setLabelSize((current) =>
          current?.width === width && current.height === height
            ? current
            : { width, height },
        );
      }}
      style={[
        styles.label,
        {
          left: labelSize ? center.x - labelSize.width / 2 : 0,
          top: labelSize ? center.y - labelSize.height / 2 : 0,
          width: maxWidth,
        },
        isLandscape && styles.landscapeLabel,
        !labelSize && styles.labelMeasuring,
      ]}
    >
      {annotation.text}
    </Text>
  );
}

function resolveAnnotationPosition(
  position: Point,
  viewportSize: Size,
  isLandscape: boolean,
): Point {
  return isLandscape
    ? {
        x: Math.round((1 - position.y) * viewportSize.width),
        y: Math.round(position.x * viewportSize.height),
      }
    : {
        x: Math.round(position.x * viewportSize.width),
        y: Math.round(position.y * viewportSize.height),
      };
}

const styles = StyleSheet.create({
  label: {
    position: 'absolute',
    color: '#FFD400',
    fontSize: 13,
    lineHeight: 18,
    textAlign: 'center',
  },
  labelMeasuring: {
    opacity: 0,
  },
  landscapeLabel: {
    transform: [{ rotate: '90deg' }],
  },
});
