import { useState } from 'react';
import {
  ActivityIndicator,
  Button,
  Linking,
  StyleSheet,
  Text,
  View,
  type LayoutChangeEvent,
} from 'react-native';
import { useCameraPermissions } from 'expo-camera';
import { router } from 'expo-router';
import { SafeAreaView } from 'react-native-safe-area-context';

import {
  getMaxReferenceWidth,
  getViewportSize,
  type CompositionTemplateDocumentV1,
} from '@/canvas';
import { CameraViewport } from '@/features/camera/components/CameraViewport';
import { useCaptureSession } from '@/features/photo-review/model/capture-session';
import type { Size } from '@/types/geometry';

const templateDocument = {
  schemaVersion: 1,
  presets: [
    {
      id: 'horizon',
      title: '水平线',
      description: '用于验证构图引导线渲染',
      variants: [
        {
          id: 'horizon-3x4',
          aspectRatio: { width: 3, height: 4 },
          instruction: '将主体沿水平线放置',
          defaultFacing: 'back',
          elements: [
            {
              id: 'center-line',
              type: 'horizon',
              shape: {
                type: 'line',
                start: { x: 0.1, y: 0.5 },
                end: { x: 0.9, y: 0.5 },
              },
            },
          ],
        },
      ],
    },
  ],
} satisfies CompositionTemplateDocumentV1;

const variant = templateDocument.presets[0].variants[0];

export default function HomeScreen() {
  const [permission, requestPermission] = useCameraPermissions();
  const [availableSize, setAvailableSize] = useState<Size>();
  const [permissionError, setPermissionError] = useState<string>();
  const { setSession } = useCaptureSession();

  const viewportSize = availableSize
    ? getViewportSize(
        variant.aspectRatio,
        getMaxReferenceWidth(availableSize, variant.aspectRatio),
      )
    : undefined;

  function handleLayout(event: LayoutChangeEvent) {
    const { width, height } = event.nativeEvent.layout;

    setAvailableSize((currentSize) => {
      if (currentSize?.width === width && currentSize.height === height) {
        return currentSize;
      }

      return { width, height };
    });
  }

  async function handlePermissionRequest() {
    setPermissionError(undefined);

    try {
      await requestPermission();
    } catch (error) {
      setPermissionError(
        error instanceof Error ? error.message : '无法请求相机权限',
      );
    }
  }

  function renderContent() {
    if (!permission) {
      return <ActivityIndicator color="#FFD400" size="large" />;
    }

    if (!permission.granted) {
      return (
        <View style={styles.messagePanel}>
          <Text style={styles.title}>需要相机权限</Text>
          <Text style={styles.message}>
            允许访问相机后即可测试构图引导覆盖层。
          </Text>
          <Button
            color="#FFD400"
            onPress={
              permission.canAskAgain
                ? handlePermissionRequest
                : Linking.openSettings
            }
            title={permission.canAskAgain ? '允许访问相机' : '打开系统设置'}
          />
          {permissionError ? (
            <Text style={styles.error}>{permissionError}</Text>
          ) : null}
        </View>
      );
    }

    if (!viewportSize) {
      return null;
    }

    return (
      <View style={styles.previewSection}>
        <CameraViewport
          onPhotoCaptured={({ uri, width, height }) => {
            setSession({
              presetId: templateDocument.presets[0].id,
              variantId: variant.id,
              photoUri: uri,
              width,
              height,
            });
            router.replace('/review');
          }}
          variant={variant}
          viewportSize={viewportSize}
        />
      </View>
    );
  }

  return (
    <SafeAreaView style={styles.safeArea}>
      <View onLayout={handleLayout} style={styles.content}>
        {renderContent()}
      </View>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  safeArea: {
    flex: 1,
    backgroundColor: '#111111',
  },
  content: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
  },
  previewSection: {
    alignItems: 'center',
  },
  messagePanel: {
    maxWidth: 320,
    alignItems: 'center',
    gap: 16,
    paddingHorizontal: 24,
  },
  title: {
    color: '#FFFFFF',
    fontSize: 22,
    fontWeight: '700',
  },
  message: {
    color: '#D1D1D1',
    fontSize: 16,
    lineHeight: 24,
    textAlign: 'center',
  },
  error: {
    color: '#FF8A80',
    textAlign: 'center',
  },
});
