import { Redirect, router } from 'expo-router';
import { useState } from 'react';
import { Image, Pressable, StyleSheet, Text, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';

import { useCaptureSession } from '@/features/photo-review/model/capture-session';

export default function ReviewScreen() {
  const { session, clearSession } = useCaptureSession();
  const [imageError, setImageError] = useState<string>();

  if (!session) {
    return <Redirect href="/" />;
  }

  function returnToCamera() {
    clearSession();
    router.replace('/');
  }

  return (
    <SafeAreaView style={styles.safeArea}>
      <View style={styles.preview}>
        {imageError ? (
          <View style={styles.errorPanel}>
            <Text style={styles.errorTitle}>照片无法预览</Text>
            <Text style={styles.errorMessage}>{imageError}</Text>
          </View>
        ) : (
          <Image
            accessibilityLabel="刚刚拍摄的照片"
            onError={({ nativeEvent }) => setImageError(nativeEvent.error)}
            resizeMode="contain"
            source={{ uri: session.photoUri }}
            style={styles.photo}
          />
        )}
      </View>
      <View style={styles.actions}>
        <Pressable
          accessibilityRole="button"
          onPress={returnToCamera}
          style={({ pressed }) => [
            styles.secondaryButton,
            pressed && styles.pressed,
          ]}
        >
          <Text style={styles.secondaryButtonText}>重拍</Text>
        </Pressable>
        <Pressable
          accessibilityRole="button"
          onPress={returnToCamera}
          style={({ pressed }) => [
            styles.primaryButton,
            pressed && styles.pressed,
          ]}
        >
          <Text style={styles.primaryButtonText}>完成</Text>
        </Pressable>
      </View>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  safeArea: {
    flex: 1,
    backgroundColor: '#111111',
  },
  preview: {
    flex: 1,
    padding: 16,
  },
  photo: {
    width: '100%',
    height: '100%',
  },
  errorPanel: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
    gap: 8,
  },
  errorTitle: {
    color: '#FFFFFF',
    fontSize: 20,
    fontWeight: '700',
  },
  errorMessage: {
    color: '#FF8A80',
    textAlign: 'center',
  },
  actions: {
    flexDirection: 'row',
    gap: 12,
    padding: 16,
  },
  primaryButton: {
    flex: 1,
    alignItems: 'center',
    paddingVertical: 16,
    borderRadius: 14,
    backgroundColor: '#FFD400',
  },
  primaryButtonText: {
    color: '#111111',
    fontSize: 17,
    fontWeight: '700',
  },
  secondaryButton: {
    flex: 1,
    alignItems: 'center',
    paddingVertical: 16,
    borderWidth: 1,
    borderColor: '#FFFFFF',
    borderRadius: 14,
  },
  secondaryButtonText: {
    color: '#FFFFFF',
    fontSize: 17,
    fontWeight: '600',
  },
  pressed: {
    opacity: 0.75,
  },
});
