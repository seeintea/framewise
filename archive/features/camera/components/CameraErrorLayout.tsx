import type { ReactNode } from 'react';
import { Pressable, StyleSheet, Text, View } from 'react-native';

type CameraErrorLayoutProps = {
  children: ReactNode;
  onBack: () => void;
  topInset: number;
};

export function CameraErrorLayout({
  children,
  onBack,
  topInset,
}: CameraErrorLayoutProps) {
  return (
    <View style={styles.container}>
      <View style={[StyleSheet.absoluteFill, styles.stage]}>{children}</View>
      <Pressable
        accessibilityLabel="返回"
        accessibilityRole="button"
        hitSlop={8}
        onPress={onBack}
        style={({ pressed }) => [
          styles.backButton,
          { top: topInset + 10 },
          pressed && styles.backButtonPressed,
        ]}
      >
        <Text style={styles.backLabel}>‹</Text>
      </Pressable>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#000000',
  },
  backButton: {
    position: 'absolute',
    left: 12,
    zIndex: 1,
    width: 40,
    height: 40,
    alignItems: 'center',
    justifyContent: 'center',
  },
  backButtonPressed: {
    opacity: 0.75,
  },
  stage: {
    alignItems: 'center',
    justifyContent: 'center',
    overflow: 'hidden',
  },
  backLabel: {
    color: '#FFFFFF',
    fontSize: 34,
    lineHeight: 36,
    fontWeight: '300',
  },
});
