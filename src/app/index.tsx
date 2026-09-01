import { Canvas, Path } from '@shopify/react-native-skia';
import { StyleSheet, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';

export default function HomeScreen() {
  return (
    <SafeAreaView style={styles.safeArea}>
      <View style={styles.content}>
        <View style={{ width: 300, height: 400 }}>
          <Canvas style={{ flex: 1 }}>
            <Path
              path="M 128 0 L 168 80 L 256 93 L 192 155 L 207 244 L 128 202 L 49 244 L 64 155 L 0 93 L 88 80 L 128 0 Z"
              color="lightblue"
              style="stroke"
              strokeJoin="round"
              strokeWidth={2}
              // We trim the first and last quarter of the path
              start={0.25}
              end={0.75}
            />
          </Canvas>
        </View>
      </View>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  safeArea: {
    flex: 1,
    backgroundColor: '#FFFFFF',
  },
  content: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
  },
  title: {
    color: '#111111',
    fontSize: 24,
    fontWeight: '600',
  },
});
